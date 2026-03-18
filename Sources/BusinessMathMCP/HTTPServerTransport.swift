import Foundation
import MCP
import Logging
@preconcurrency import NIOCore
@preconcurrency import NIOPosix
@preconcurrency import NIOHTTP1
@preconcurrency import NIOSSL

// OAuth must be imported after Foundation
// Import OAuth types


/// HTTP server transport for MCP using SwiftNIO (Streamable HTTP, spec 2025-03-26)
///
/// This transport implements MCP Streamable HTTP:
/// - Cross-platform (macOS, Linux) using SwiftNIO
/// - Listens on a specified port
/// - POST /mcp - JSON-RPC requests, returns JSON response with Mcp-Session-Id header
/// - GET /mcp (Accept: text/event-stream) - SSE stream for server-initiated messages
/// - DELETE /mcp - Terminate session
///
/// Architecture:
/// 1. Client POSTs initialize to /mcp, receives JSON response with Mcp-Session-Id
/// 2. Client includes Mcp-Session-Id header on all subsequent requests
/// 3. Server routes responses directly as JSON via HTTPResponseManager
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

    /// SSE session manager (legacy, kept for backward compat)
    internal let sseSessionManager: SSESessionManager

    /// Streamable HTTP session manager (MCP 2025-03-26)
    internal let streamableSessionManager: StreamableSessionManager

    private let authenticator: APIKeyAuthenticator?

    /// OAuth server for OAuth 2.0 authentication (optional)
    internal let oauthServer: OAuthServer?

    /// TLS certificate and key paths (optional, enables HTTPS)
    private let tlsCertPath: String?
    private let tlsKeyPath: String?

    /// Initialize HTTP server transport
    /// - Parameters:
    ///   - port: Port number to listen on (default: 8080)
    ///   - authenticator: Optional API key authenticator (if nil, no auth required)
    ///   - oauthServer: Optional OAuth server for OAuth 2.0 authentication
    ///   - tlsCertPath: Path to TLS certificate chain (PEM format)
    ///   - tlsKeyPath: Path to TLS private key (PEM format)
    ///   - logger: Logger instance
    public init(
        port: UInt16 = 8080,
        authenticator: APIKeyAuthenticator? = nil,
        oauthServer: OAuthServer? = nil,
        tlsCertPath: String? = nil,
        tlsKeyPath: String? = nil,
        logger: Logger = Logger(label: "http-server-transport")
    ) {
        self.port = port
        self.logger = logger
        self.authenticator = authenticator
        self.oauthServer = oauthServer
        self.tlsCertPath = tlsCertPath
        self.tlsKeyPath = tlsKeyPath
        self.responseManager = HTTPResponseManager(logger: logger)
        self.sseSessionManager = SSESessionManager(logger: logger)
        self.streamableSessionManager = StreamableSessionManager(logger: logger)

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

        // Start streamable session maintenance
        await streamableSessionManager.startMaintenance()

        // Create event loop group
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.eventLoopGroup = group

        // Configure TLS if certificate and key paths are provided
        var sslContext: NIOSSLContext? = nil
        if let certPath = tlsCertPath, let keyPath = tlsKeyPath {
            let certificateChain = try NIOSSLCertificate.fromPEMFile(certPath)
            let privateKey = try NIOSSLPrivateKey(file: keyPath, format: .pem)
            var tlsConfig = TLSConfiguration.makeServerConfiguration(
                certificateChain: certificateChain.map { .certificate($0) },
                privateKey: .privateKey(privateKey)
            )
            tlsConfig.minimumTLSVersion = .tlsv12
            sslContext = try NIOSSLContext(configuration: tlsConfig)
            logger.info("TLS enabled with cert: \(certPath)")
        }

        // Configure and bind server with SwiftNIO
        do {
            let bootstrap = NIOPosix.ServerBootstrap(group: group)
                .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .childChannelInitializer { [sslContext] channel in
                    // Manually configure HTTP pipeline without HTTPServerPipelineHandler
                    // (which would close connections after each response, breaking SSE)
                    // Use nonisolated(unsafe) since NIO handlers are bound to a single event loop
                    nonisolated(unsafe) let decoder = ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .dropBytes))
                    nonisolated(unsafe) let encoder = HTTPResponseEncoder()
                    nonisolated(unsafe) let handler = MCPServerHandler(transport: self, authenticator: self.authenticator, oauthServer: self.oauthServer, logger: self.logger)

                    if let sslContext = sslContext {
                        nonisolated(unsafe) let sslHandler = NIOSSLServerHandler(context: sslContext)
                        return channel.pipeline.addHandler(sslHandler).flatMap {
                            channel.pipeline.addHandler(decoder)
                        }.flatMap {
                            channel.pipeline.addHandler(encoder)
                        }.flatMap {
                            channel.pipeline.addHandler(handler)
                        }
                    } else {
                        return channel.pipeline.addHandler(decoder).flatMap {
                            channel.pipeline.addHandler(encoder)
                        }.flatMap {
                            channel.pipeline.addHandler(handler)
                        }
                    }
                }
            let channel: Channel = try await bootstrap.bind(host: "0.0.0.0", port: Int(port)).get()
            self.serverChannel = channel

            let scheme = sslContext != nil ? "HTTPS" : "HTTP"
            logger.info("\(scheme) server listening on port \(port)")
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

        // Shutdown streamable sessions
        await streamableSessionManager.shutdown()

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
        // Parse response for routing
        let responseStr = String(data: data, encoding: .utf8) ?? "binary"

        // Check for "already initialized" error and convert to cached success response
        // This allows multiple Claude Code health checks to succeed
        if responseStr.contains("Server is already initialized"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorId = json["id"] {
            // Create a synthetic success response using cached capabilities
            let successResponse: [String: Any] = [
                "jsonrpc": "2.0",
                "id": errorId,
                "result": [
                    "protocolVersion": "2025-03-26",
                    "serverInfo": [
                        "name": "BusinessMath MCP Server",
                        "version": "2.0.0"
                    ],
                    "capabilities": [
                        "tools": ["listChanged": false],
                        "resources": ["subscribe": false, "listChanged": false],
                        "prompts": ["listChanged": false],
                        "logging": [:]
                    ]
                ]
            ]
            if let successData = try? JSONSerialization.data(withJSONObject: successResponse) {
                logger.debug("Converted 'already initialized' error to success response")
                _ = await responseManager.routeResponse(successData)
                return
            }
        }

        // Primary path: route through HTTP response manager (Streamable HTTP)
        let httpRouted = await responseManager.routeResponse(data)

        if httpRouted {
            return
        }

        // Fallback: broadcast to SSE streams (for server-initiated messages)
        let sseRouted = await streamableSessionManager.broadcastToAllSSE(data)

        if !sseRouted {
            // Try legacy SSE manager as last resort
            let legacyRouted = await sseSessionManager.routeResponse(data)
            if !legacyRouted {
                logger.warning("Failed to route response (\(data.count) bytes) - no pending request found")
            }
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

