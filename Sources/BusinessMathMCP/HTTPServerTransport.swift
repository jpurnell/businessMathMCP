import Foundation
import MCP
import Logging
@preconcurrency import NIOCore
@preconcurrency import NIOPosix
@preconcurrency import NIOHTTP1

/// HTTP server transport for MCP using SwiftNIO
///
/// This transport implements MCP over HTTP with Server-Sent Events (SSE):
/// - Cross-platform (macOS, Linux) using SwiftNIO
/// - Listens on a specified port
/// - GET /mcp/sse - Opens SSE connection for server→client streaming
/// - POST /mcp - Accepts JSON-RPC requests (includes X-Session-ID header)
/// - Routes responses via SSE to correct client
///
/// Architecture:
/// 1. Client opens SSE connection (GET /mcp/sse)
/// 2. Server creates SSESession and returns session ID
/// 3. Client sends requests via POST with X-Session-ID header
/// 4. Server routes responses back via SSE stream
public actor HTTPServerTransport: Transport {
    public let logger: Logger
    private let port: UInt16

    // SwiftNIO server components
    private var serverChannel: Channel?
    private var eventLoopGroup: MultiThreadedEventLoopGroup?

    private let receiveStream: AsyncThrowingStream<Data, Error>

    /// Receive continuation - accessible to handler for forwarding requests
    internal let receiveContinuation: AsyncThrowingStream<Data, Error>.Continuation

    /// Response manager - accessible to handler for routing responses
    internal let responseManager: HTTPResponseManager

    /// SSE session manager - accessible to handler for SSE connections
    internal let sseSessionManager: SSESessionManager

    private let authenticator: APIKeyAuthenticator?

    /// Initialize HTTP server transport
    /// - Parameters:
    ///   - port: Port number to listen on (default: 8080)
    ///   - authenticator: Optional API key authenticator (if nil, no auth required)
    ///   - logger: Logger instance
    public init(
        port: UInt16 = 8080,
        authenticator: APIKeyAuthenticator? = nil,
        logger: Logger = Logger(label: "http-server-transport")
    ) {
        self.port = port
        self.logger = logger
        self.authenticator = authenticator
        self.responseManager = HTTPResponseManager(logger: logger)
        self.sseSessionManager = SSESessionManager(logger: logger)

        // Create receive stream
        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.receiveStream = AsyncThrowingStream { cont in
            continuation = cont
        }
        self.receiveContinuation = continuation
    }

    public func connect() async throws {
        // Start response manager cleanup task
        await responseManager.startCleanup()

        // Start SSE session maintenance (cleanup + heartbeat)
        await sseSessionManager.startMaintenance()

        // Create event loop group
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.eventLoopGroup = group

        // Configure and bind server with SwiftNIO
        do {
            let bootstrap = NIOPosix.ServerBootstrap(group: group)
                .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .childChannelInitializer { channel in
                    // Manually configure HTTP pipeline without HTTPServerPipelineHandler
                    // (which would close connections after each response, breaking SSE)
                    let decoder = ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .dropBytes))
                    let encoder = HTTPResponseEncoder()
                    let handler = MCPServerHandler(transport: self, authenticator: self.authenticator, logger: self.logger)

                    return channel.pipeline.addHandler(decoder).flatMap {
                        channel.pipeline.addHandler(encoder)
                    }.flatMap {
                        channel.pipeline.addHandler(handler)
                    }
                }
            let channel: Channel = try await bootstrap.bind(host: "0.0.0.0", port: Int(port)).get()
            self.serverChannel = channel

            logger.info("HTTP server listening on port \(port)")
        } catch {
            logger.error("Failed to bind to port \(port): \(error)")
            try? await group.shutdownGracefully()
            throw HTTPServerError.failedToCreateListener
        }
    }

    public func disconnect() async {
        // Stop response manager cleanup task
        await responseManager.stopCleanup()

        // Shutdown SSE sessions
        await sseSessionManager.shutdown()

        // Close server channel
        if let channel = serverChannel {
            try? await channel.close()
            serverChannel = nil
        }

        // Shutdown event loop group
        if let group = eventLoopGroup {
            do {
                try await group.shutdownGracefully()
            } catch {
                logger.error("Error shutting down event loop group: \(error.localizedDescription)")
            }
            eventLoopGroup = nil
        }

        // Finish receive stream
        receiveContinuation.finish()
    }

    public func send(_ data: Data) async throws {
        // Try routing through SSE first (for clients using SSE)
        let sseRouted = await sseSessionManager.routeResponse(data)

        if sseRouted {
            return  // Successfully sent via SSE
        }

        // Fall back to HTTP response manager (for legacy non-SSE clients)
        let httpRouted = await responseManager.routeResponse(data)

        if !httpRouted {
            logger.warning("Failed to route response (\(data.count) bytes) - no pending request found")
        }
    }

    public func receive() -> AsyncThrowingStream<Data, Error> {
        return receiveStream
    }
}

// MARK: - Supporting Types

enum HTTPServerError: Error, LocalizedError {
    case failedToCreateListener
    case notConnected

    var errorDescription: String? {
        switch self {
        case .failedToCreateListener:
            return "Failed to create network listener"
        case .notConnected:
            return "HTTP server is not connected"
        }
    }
}

