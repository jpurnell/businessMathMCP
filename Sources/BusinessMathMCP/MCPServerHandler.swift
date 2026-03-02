import Foundation
@preconcurrency import NIOCore
@preconcurrency import NIOPosix
@preconcurrency import NIOHTTP1
import Logging

/// SwiftNIO channel handler for MCP HTTP server
///
/// This handler processes incoming HTTP requests and routes them to appropriate handlers:
/// - GET /health - Health check endpoint
/// - GET /mcp - Server information
/// - GET /mcp/sse - Server-Sent Events connection
/// - POST /mcp - JSON-RPC requests
/// - OPTIONS * - CORS preflight
///
/// ## Topics
///
/// ### Initialization
/// - ``init(transport:authenticator:logger:)``
///
/// ### Channel Handling
/// - ``channelRead(context:data:)``
/// - ``errorCaught(context:error:)``
final class MCPServerHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    /// Reference to the parent transport (for accessing managers and stream)
    private weak var transport: HTTPServerTransport?

    /// API key authenticator (optional)
    private let authenticator: APIKeyAuthenticator?

    /// Logger
    private let logger: Logger

    /// Current request being processed
    private var currentRequest: HTTPRequestHead?
    private var requestBody: ByteBuffer?

    /// Initialize handler
    init(transport: HTTPServerTransport, authenticator: APIKeyAuthenticator?, logger: Logger) {
        self.transport = transport
        self.authenticator = authenticator
        self.logger = logger
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)

        switch reqPart {
        case .head(let head):
            currentRequest = head
            requestBody = nil

        case .body(var buffer):
            if requestBody == nil {
                requestBody = buffer
            } else {
                requestBody!.writeBuffer(&buffer)
            }

        case .end:
            guard let request = currentRequest else { return }

            // Process the complete request directly (synchronously in the event loop)
            handleRequest(context: context, head: request, body: requestBody)

            // Reset for next request
            currentRequest = nil
            requestBody = nil
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("Channel error: \(error.localizedDescription)")
        context.close(promise: nil)
    }

    // MARK: - Request Handling

    private nonisolated func handleRequest(context: ChannelHandlerContext, head: HTTPRequestHead, body: ByteBuffer?) {
        // Create a local binding to avoid capturing non-Sendable ChannelHandlerContext in @Sendable closure.
        // Safety: This class is @unchecked Sendable and the context is only used on its event loop.
        nonisolated(unsafe) let context = context

        // CRITICAL: Capture all context properties synchronously on the EventLoop
        // before creating any Tasks, as Tasks don't preserve EventLoop context
        context.eventLoop.execute {
            // Capture context properties while on EventLoop
            let channel = context.channel
            let eventLoop = context.eventLoop

            Task { [weak self] in
                await self?.processRequest(channel: channel, eventLoop: eventLoop, context: context, head: head, body: body)
            }
        }
    }

    private func processRequest(channel: Channel, eventLoop: EventLoop, context: ChannelHandlerContext, head: HTTPRequestHead, body: ByteBuffer?) async {
        let path = head.uri
        let method = head.method

        // Check authentication for protected endpoints
        let requiresAuth = !["/health", "/mcp"].contains(path) || method == .POST

        if requiresAuth {
            let authorized = await checkAuthorization(headers: head.headers)
            if !authorized {
                sendResponse(context: context, status: .unauthorized, body: "Unauthorized")
                return
            }
        }

        // Handle CORS preflight
        if method == .OPTIONS {
            sendCORSPreflightResponse(context: context)
            return
        }

        // Route request
        switch (method, path) {
        case (.GET, "/health"):
            handleHealthCheck(context: context)

        case (.GET, "/mcp"):
            handleServerInfo(context: context)

        case (.GET, "/mcp/sse"):
            await processSSEConnection(channel: channel, eventLoop: eventLoop, context: context, headers: head.headers)

        case (.POST, "/mcp"):
            await processJSONRPCRequest(channel: channel, context: context, headers: head.headers, body: body)

        case (_, "/health"), (_, "/mcp"), (_, "/mcp/sse"):
            // Path exists but method not allowed
            sendResponse(context: context, status: .methodNotAllowed, body: "Method Not Allowed")

        default:
            sendResponse(context: context, status: .notFound, body: "Not Found")
        }
    }

    // MARK: - Endpoint Handlers

    private func handleHealthCheck(context: ChannelHandlerContext) {
        sendResponse(context: context, status: .ok, body: "OK")
    }

    private func handleServerInfo(context: ChannelHandlerContext) {
        let info = """
        {
          "name": "BusinessMath MCP Server",
          "version": "2.0.0",
          "protocol": "MCP over HTTP + SSE (SwiftNIO)",
          "platform": "cross-platform",
          "endpoints": {
            "sse": "GET /mcp/sse - Open Server-Sent Events stream",
            "rpc": "POST /mcp - Send JSON-RPC request"
          },
          "authentication": "\(authenticator != nil ? "enabled" : "disabled")",
          "cors": "enabled"
        }
        """

        sendResponse(context: context, status: .ok, body: info, contentType: "application/json")
    }

    private func processSSEConnection(channel: Channel, eventLoop: EventLoop, context: ChannelHandlerContext, headers: HTTPHeaders) async {
        guard let transport = transport else { return }

        // Create HTTPConnection from channel
        let connection = NIOHTTPConnection(channel: channel)

        // Create SSE session
        let session = SSESession(connection: connection, logger: logger)
        let sessionId = session.sessionId

        // Register with manager (async operation)
        await transport.sseSessionManager.registerSession(session)

        // Send SSE headers on the EventLoop
        let responseHead = HTTPResponseHead(
            version: .http1_1,
            status: .ok,
            headers: createSSEHeaders(sessionId: sessionId)
        )

        // Use nonisolated(unsafe) to avoid Sendable warning
        nonisolated(unsafe) let unsafeContext = context

        eventLoop.execute {
            unsafeContext.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
            unsafeContext.flush()
        }

        // Connection stays open for SSE events
        // The session will be managed by SSESessionManager
    }

    private func processJSONRPCRequest(channel: Channel, context: ChannelHandlerContext, headers: HTTPHeaders, body: ByteBuffer?) async {
        guard let transport = transport else { return }
        guard let bodyBuffer = body else {
            sendResponse(context: context, status: .badRequest, body: "Missing request body")
            return
        }

        let bodyData = Data(buffer: bodyBuffer)

        // Extract session ID from headers
        let sessionId = headers.first(name: "X-Session-ID")

        // Parse JSON-RPC to get request ID
        guard let requestId = extractRequestId(from: bodyData) else {
            sendResponse(context: context, status: .badRequest, body: "Invalid JSON-RPC request")
            return
        }

        if let sessionId = sessionId {
            // SSE mode: associate request with session
            await transport.sseSessionManager.associateRequest(requestId: requestId, with: sessionId)
        } else {
            // Legacy HTTP mode: register with response manager
            // Use pre-captured channel instead of accessing context.channel after await
            let connection = NIOHTTPConnection(channel: channel)
            await transport.responseManager.registerRequest(requestId: requestId, connection: connection)
        }

        // Forward request to MCP server via receive stream
        transport.receiveContinuation.yield(bodyData)

        // Send immediate acknowledgment (response will come via SSE or HTTP)
        sendResponse(context: context, status: .ok, body: "")
    }

    // MARK: - Authentication

    private func checkAuthorization(headers: HTTPHeaders) async -> Bool {
        guard let authenticator = authenticator else {
            return true  // No authenticator = no auth required
        }

        // Check Authorization header
        let authHeader = headers.first(name: "Authorization")

        return await authenticator.validate(authHeader: authHeader)
    }

    // MARK: - Response Helpers

    private func sendResponse(
        context: ChannelHandlerContext,
        status: HTTPResponseStatus,
        body: String,
        contentType: String = "text/plain"
    ) {
        // Ensure this runs on the EventLoop
        let eventLoop = context.eventLoop
        nonisolated(unsafe) let unsafeContext = context

        eventLoop.execute {
            self._sendResponse(context: unsafeContext, status: status, body: body, contentType: contentType)
        }
    }

    private func _sendResponse(
        context: ChannelHandlerContext,
        status: HTTPResponseStatus,
        body: String,
        contentType: String
    ) {
        let bodyData = body.data(using: .utf8) ?? Data()
        var buffer = context.channel.allocator.buffer(capacity: bodyData.count)
        buffer.writeBytes(bodyData)

        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: contentType)
        headers.add(name: "Content-Length", value: "\(bodyData.count)")
        headers.add(name: "Connection", value: "close")
        addCORSHeaders(to: &headers)

        let responseHead = HTTPResponseHead(
            version: .http1_1,
            status: status,
            headers: headers
        )

        context.write(wrapOutboundOut(.head(responseHead)), promise: nil)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
        context.close(promise: nil)
    }

    private func sendCORSPreflightResponse(context: ChannelHandlerContext) {
        // Ensure this runs on the EventLoop
        let eventLoop = context.eventLoop
        nonisolated(unsafe) let unsafeContext = context

        eventLoop.execute {
            self._sendCORSPreflightResponse(context: unsafeContext)
        }
    }

    private func _sendCORSPreflightResponse(context: ChannelHandlerContext) {
        var headers = HTTPHeaders()
        addCORSHeaders(to: &headers)
        headers.add(name: "Access-Control-Max-Age", value: "86400")

        let responseHead = HTTPResponseHead(
            version: .http1_1,
            status: .noContent,
            headers: headers
        )

        context.write(wrapOutboundOut(.head(responseHead)), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
        context.close(promise: nil)
    }

    private func createSSEHeaders(sessionId: String) -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/event-stream")
        headers.add(name: "Cache-Control", value: "no-cache")
        headers.add(name: "Connection", value: "keep-alive")
        headers.add(name: "X-Session-ID", value: sessionId)
        addCORSHeaders(to: &headers)
        return headers
    }

    private func addCORSHeaders(to headers: inout HTTPHeaders) {
        headers.add(name: "Access-Control-Allow-Origin", value: "*")
        headers.add(name: "Access-Control-Allow-Methods", value: "GET, POST, OPTIONS")
        headers.add(name: "Access-Control-Allow-Headers", value: "Content-Type, Authorization, X-Session-ID")
        headers.add(name: "Access-Control-Expose-Headers", value: "X-Session-ID")
    }

    // MARK: - Utilities

    private func extractRequestId(from data: Data) -> HTTPResponseManager.JSONRPCId? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let idValue = json["id"] else {
            return .null
        }

        if let stringId = idValue as? String {
            return .string(stringId)
        } else if let numberId = idValue as? Int {
            return .number(numberId)
        } else if idValue is NSNull {
            return .null
        }

        return nil
    }
}
