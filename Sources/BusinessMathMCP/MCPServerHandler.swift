import Foundation
@preconcurrency import NIOCore
@preconcurrency import NIOPosix
@preconcurrency import NIOHTTP1
import Logging

/// SwiftNIO channel handler for MCP Streamable HTTP server (spec 2025-03-26)
///
/// This handler processes incoming HTTP requests and routes them to appropriate handlers:
/// - GET /health - Health check endpoint
/// - GET /mcp - Server info (no Accept: text/event-stream) or SSE stream (with Accept: text/event-stream)
/// - POST /mcp - JSON-RPC requests (Streamable HTTP)
/// - DELETE /mcp - Terminate session
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

    /// OAuth server for OAuth 2.0 authentication (optional)
    private let oauthServer: OAuthServer?

    /// OAuth HTTP handler (created lazily from OAuth server)
    private var oauthHandler: OAuthHTTPHandler? {
        guard let server = oauthServer else { return nil }
        return OAuthHTTPHandler(server: server)
    }

    /// Logger
    private let logger: Logger

    /// Current request being processed
    private var currentRequest: HTTPRequestHead?
    private var requestBody: ByteBuffer?

    /// Initialize handler
    init(transport: HTTPServerTransport, authenticator: APIKeyAuthenticator?, oauthServer: OAuthServer?, logger: Logger) {
        self.transport = transport
        self.authenticator = authenticator
        self.oauthServer = oauthServer
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
        logger.debug("Channel error: \(error.localizedDescription)")
        // Don't aggressively close - SSE connections should stay open
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
        // Extract path without query string for routing
        let fullUri = head.uri
        let path = fullUri.split(separator: "?").first.map(String.init) ?? fullUri
        let method = head.method


        // OAuth endpoints are always public (they handle their own auth)
        let oauthEndpoints = ["/.well-known/oauth-authorization-server", "/register", "/authorize", "/authorize/consent", "/token"]
        let isOAuthEndpoint = oauthEndpoints.contains(path)

        // Check authentication for protected endpoints
        // Exclude health and OAuth endpoints from auth
        // GET /mcp without SSE Accept header is public (server info); POST/DELETE/GET+SSE require auth
        let isPublicEndpoint = ["/health"].contains(path) || isOAuthEndpoint
        let isMcpGetWithoutSSE = (method == .GET && path == "/mcp" &&
            !(head.headers.first(name: "Accept")?.contains("text/event-stream") ?? false))
        let requiresAuth = !isPublicEndpoint && !isMcpGetWithoutSSE

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
            // Streamable HTTP: Accept: text/event-stream means SSE stream request
            let acceptHeader = head.headers.first(name: "Accept") ?? ""
            if acceptHeader.contains("text/event-stream") {
                await processStreamableSSE(channel: channel, eventLoop: eventLoop, context: context, headers: head.headers)
            } else {
                handleServerInfo(context: context)
            }

        case (.POST, "/mcp"):
            await processStreamablePost(channel: channel, context: context, headers: head.headers, body: body)

        case (.DELETE, "/mcp"):
            await processSessionDelete(context: context, headers: head.headers)

        // Legacy SSE endpoint - maintained for backward compatibility
        case (.GET, "/mcp/sse"):
            await processLegacySSE(channel: channel, eventLoop: eventLoop, context: context)

        // OAuth 2.0 Endpoints
        case (.GET, "/.well-known/oauth-authorization-server"):
            await handleOAuthMetadata(context: context)

        case (.POST, "/register"):
            await handleOAuthRegistration(context: context, body: body)

        case (.GET, "/authorize"):
            await handleOAuthAuthorization(context: context, uri: fullUri)

        case (.POST, "/authorize/consent"):
            await handleOAuthConsent(context: context, body: body)

        case (.POST, "/token"):
            await handleOAuthToken(context: context, body: body, headers: head.headers)

        case (_, "/health"), (_, "/mcp"):
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
          "protocol": "MCP Streamable HTTP (2025-03-26)",
          "platform": "cross-platform",
          "endpoints": {
            "mcp": "POST /mcp - JSON-RPC requests",
            "sse": "GET /mcp (Accept: text/event-stream) - Server-initiated messages",
            "delete": "DELETE /mcp - Terminate session"
          },
          "authentication": "\(authenticator != nil ? "enabled" : "disabled")",
          "cors": "enabled"
        }
        """

        sendResponse(context: context, status: .ok, body: info, contentType: "application/json")
    }

    private func handleNoOAuthMetadata(context: ChannelHandlerContext) {
        // OAuth is not configured - return 404 so clients fall back to other auth methods (e.g., Bearer token)
        sendResponse(context: context, status: .notFound, body: "OAuth not configured. Use Bearer token authentication.")
    }

    // MARK: - OAuth Endpoint Handlers

    private func handleOAuthMetadata(context: ChannelHandlerContext) async {
        if let handler = oauthHandler {
            let response = await handler.handleMetadataRequest()
            sendOAuthResponse(context: context, response: response)
        } else {
            handleNoOAuthMetadata(context: context)
        }
    }

    private func handleOAuthRegistration(context: ChannelHandlerContext, body: ByteBuffer?) async {
        guard let handler = oauthHandler else {
            sendResponse(context: context, status: .notFound, body: "OAuth not configured")
            return
        }

        guard let bodyBuffer = body else {
            sendResponse(context: context, status: .badRequest, body: "Missing request body")
            return
        }

        let bodyString = String(buffer: bodyBuffer)
        let response = await handler.handleRegistrationRequest(body: bodyString)
        sendOAuthResponse(context: context, response: response)
    }

    private func handleOAuthAuthorization(context: ChannelHandlerContext, uri: String) async {
        guard let handler = oauthHandler else {
            sendResponse(context: context, status: .notFound, body: "OAuth not configured")
            return
        }

        // Parse query parameters from URI
        let queryParams = parseQueryParams(from: uri)
        let response = await handler.handleAuthorizationRequest(queryParams: queryParams)
        sendOAuthResponse(context: context, response: response)
    }

    private func handleOAuthConsent(context: ChannelHandlerContext, body: ByteBuffer?) async {
        guard let handler = oauthHandler else {
            sendResponse(context: context, status: .notFound, body: "OAuth not configured")
            return
        }

        guard let bodyBuffer = body else {
            sendResponse(context: context, status: .badRequest, body: "Missing request body")
            return
        }

        let bodyString = String(buffer: bodyBuffer)
        let formParams = parseFormBody(bodyString)
        let response = await handler.handleConsentSubmission(formParams: formParams)
        sendOAuthResponse(context: context, response: response)
    }

    private func handleOAuthToken(context: ChannelHandlerContext, body: ByteBuffer?, headers: HTTPHeaders) async {
        guard let handler = oauthHandler else {
            sendResponse(context: context, status: .notFound, body: "OAuth not configured")
            return
        }

        guard let bodyBuffer = body else {
            sendResponse(context: context, status: .badRequest, body: "Missing request body")
            return
        }

        let bodyString = String(buffer: bodyBuffer)
        let authHeader = headers.first(name: "Authorization")
        let response = await handler.handleTokenRequest(body: bodyString, authHeader: authHeader)
        sendOAuthResponse(context: context, response: response)
    }

    private func sendOAuthResponse(context: ChannelHandlerContext, response: OAuthHTTPResponse) {
        let eventLoop = context.eventLoop
        nonisolated(unsafe) let unsafeContext = context

        eventLoop.execute {
            self._sendOAuthResponse(context: unsafeContext, response: response)
        }
    }

    private func _sendOAuthResponse(context: ChannelHandlerContext, response: OAuthHTTPResponse) {
        let bodyData = response.body.data(using: .utf8) ?? Data()
        var buffer = context.channel.allocator.buffer(capacity: bodyData.count)
        buffer.writeBytes(bodyData)

        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: response.contentType)
        headers.add(name: "Content-Length", value: "\(bodyData.count)")
        addCORSHeaders(to: &headers)

        // Add any custom headers from OAuth response
        for (name, value) in response.headers {
            headers.add(name: name, value: value)
        }

        // Determine if we should close connection (redirects keep-alive, others close)
        let status = HTTPResponseStatus(statusCode: response.statusCode)
        if status == .found || status == .seeOther {
            headers.add(name: "Connection", value: "close")
        } else {
            headers.add(name: "Connection", value: "close")
        }

        let responseHead = HTTPResponseHead(
            version: .http1_1,
            status: status,
            headers: headers
        )

        context.write(wrapOutboundOut(.head(responseHead)), promise: nil)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)

        if status != .found && status != .seeOther {
            context.close(promise: nil)
        }
    }

    private func parseFormBody(_ body: String) -> [String: String] {
        var params: [String: String] = [:]

        for pair in body.split(separator: "&") {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2 {
                let key = String(keyValue[0]).removingPercentEncoding ?? String(keyValue[0])
                let value = String(keyValue[1]).removingPercentEncoding ?? String(keyValue[1])
                params[key] = value
            }
        }

        return params
    }

    private func parseQueryParams(from uri: String) -> [String: String] {
        guard let queryStart = uri.firstIndex(of: "?") else {
            return [:]
        }

        let queryString = String(uri[uri.index(after: queryStart)...])
        var params: [String: String] = [:]

        for pair in queryString.split(separator: "&") {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2 {
                let key = String(keyValue[0]).removingPercentEncoding ?? String(keyValue[0])
                let value = String(keyValue[1]).removingPercentEncoding ?? String(keyValue[1])
                params[key] = value
            }
        }

        return params
    }

    // MARK: - Streamable HTTP Endpoints (MCP 2025-03-26)

    /// Handle POST /mcp — Streamable HTTP JSON-RPC requests
    ///
    /// Per the MCP 2025-03-26 spec:
    /// - `initialize` requests create a new session (Mcp-Session-Id returned in response)
    /// - Notifications (no id) return 202 Accepted
    /// - Regular requests return JSON response directly with Mcp-Session-Id header
    private func processStreamablePost(channel: Channel, context: ChannelHandlerContext, headers: HTTPHeaders, body: ByteBuffer?) async {
        guard let transport = transport else { return }
        guard let bodyBuffer = body else {
            sendResponse(context: context, status: .badRequest, body: "Missing request body")
            return
        }

        let bodyData = Data(buffer: bodyBuffer)

        // Parse JSON-RPC
        guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            sendResponse(context: context, status: .badRequest, body: "Invalid JSON")
            return
        }

        let method = json["method"] as? String
        let hasId = json.keys.contains("id")
        let requestId = extractRequestId(from: bodyData)
        let isInitialize = (method == "initialize")
        let isNotification = !hasId

        // Session ID from header
        let sessionId = headers.first(name: "Mcp-Session-Id")

        if isInitialize {
            // Create new session — don't require Mcp-Session-Id on initialize
            let newSessionId = await transport.streamableSessionManager.createSession()

            if let reqId = requestId, reqId != .null {
                // Register with HTTPResponseManager so response routes back as JSON
                let connection = NIOHTTPConnection(channel: channel)
                await transport.responseManager.registerRequest(requestId: reqId, connection: connection)
                await transport.responseManager.setSessionIdForRequest(reqId, sessionId: newSessionId)
            }

            // Forward to MCP server
            transport.receiveContinuation.yield(bodyData)
            // Response will be sent by HTTPResponseManager.routeResponse() with Mcp-Session-Id header

        } else if isNotification {
            // Notifications have no id — validate session if provided, return 202
            if let sid = sessionId {
                guard await transport.streamableSessionManager.validateSession(sid) else {
                    sendResponse(context: context, status: .notFound, body: "Session not found")
                    return
                }
                await transport.streamableSessionManager.touchSession(sid)
            }

            transport.receiveContinuation.yield(bodyData)
            sendResponse(context: context, status: .accepted, body: "")

        } else {
            // Regular request — validate session
            if let sid = sessionId {
                guard await transport.streamableSessionManager.validateSession(sid) else {
                    sendResponse(context: context, status: .notFound, body: "Session not found")
                    return
                }
                await transport.streamableSessionManager.touchSession(sid)
            }

            // Register with HTTPResponseManager for direct JSON response
            if let reqId = requestId, reqId != .null {
                let connection = NIOHTTPConnection(channel: channel)
                await transport.responseManager.registerRequest(requestId: reqId, connection: connection)
                if let sid = sessionId {
                    await transport.responseManager.setSessionIdForRequest(reqId, sessionId: sid)
                }
            }

            transport.receiveContinuation.yield(bodyData)
            // Response will be sent by HTTPResponseManager.routeResponse()
        }
    }

    /// Handle GET /mcp with Accept: text/event-stream — SSE stream for server-initiated messages
    private func processStreamableSSE(channel: Channel, eventLoop: EventLoop, context: ChannelHandlerContext, headers: HTTPHeaders) async {
        guard let transport = transport else { return }

        // Require Mcp-Session-Id for SSE streams
        guard let sessionId = headers.first(name: "Mcp-Session-Id") else {
            sendResponse(context: context, status: .badRequest, body: "Missing Mcp-Session-Id header")
            return
        }

        guard await transport.streamableSessionManager.validateSession(sessionId) else {
            sendResponse(context: context, status: .notFound, body: "Session not found")
            return
        }

        // Create SSE connection for server-initiated messages
        let connection = NIOHTTPConnection(channel: channel)
        let sseSession = SSESession(connection: connection, logger: logger)

        // Register with session
        await transport.streamableSessionManager.addSSEConnection(sseSession, to: sessionId)

        // Send SSE response headers (no endpoint event — that's the old protocol)
        var sseHeaders = HTTPHeaders()
        sseHeaders.add(name: "Content-Type", value: "text/event-stream")
        sseHeaders.add(name: "Cache-Control", value: "no-cache")
        sseHeaders.add(name: "Connection", value: "keep-alive")
        sseHeaders.add(name: "Mcp-Session-Id", value: sessionId)
        addCORSHeaders(to: &sseHeaders)

        let responseHead = HTTPResponseHead(version: .http1_1, status: .ok, headers: sseHeaders)

        nonisolated(unsafe) let unsafeContext = context
        eventLoop.execute {
            unsafeContext.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
            unsafeContext.flush()
        }

        logger.info("Streamable HTTP SSE stream opened for session \(sessionId)")
    }

    /// Handle GET /mcp/sse — Legacy SSE endpoint for backward compatibility
    ///
    /// This endpoint supports the original MCP SSE transport protocol:
    /// 1. Client GETs /mcp/sse to establish SSE stream
    /// 2. Server sends "endpoint" event with POST URL containing session ID
    /// 3. Client POSTs JSON-RPC requests to the endpoint URL
    /// 4. Server sends responses back via the SSE stream
    private func processLegacySSE(channel: Channel, eventLoop: EventLoop, context: ChannelHandlerContext) async {
        guard let transport = transport else { return }

        let sessionId = UUID().uuidString
        let connection = NIOHTTPConnection(channel: channel)
        let session = SSESession(sessionId: sessionId, connection: connection, logger: logger)

        // Register with legacy SSE session manager
        await transport.sseSessionManager.registerSession(session)

        // Send SSE response headers
        var sseHeaders = HTTPHeaders()
        sseHeaders.add(name: "Content-Type", value: "text/event-stream")
        sseHeaders.add(name: "Cache-Control", value: "no-cache")
        sseHeaders.add(name: "Connection", value: "keep-alive")
        sseHeaders.add(name: "X-Session-ID", value: sessionId)
        addCORSHeaders(to: &sseHeaders)

        let responseHead = HTTPResponseHead(version: .http1_1, status: .ok, headers: sseHeaders)

        nonisolated(unsafe) let unsafeContext = context
        eventLoop.execute {
            unsafeContext.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
            unsafeContext.flush()
        }

        // Send endpoint event with POST URL
        await session.sendEvent(event: "endpoint", data: "/mcp?sessionId=\(sessionId)")

        logger.info("Legacy SSE connection opened with session \(sessionId)")
    }

    /// Handle DELETE /mcp — Terminate session
    private func processSessionDelete(context: ChannelHandlerContext, headers: HTTPHeaders) async {
        guard let transport = transport else { return }

        guard let sessionId = headers.first(name: "Mcp-Session-Id") else {
            sendResponse(context: context, status: .badRequest, body: "Missing Mcp-Session-Id header")
            return
        }

        let removed = await transport.streamableSessionManager.removeSession(sessionId)
        if removed {
            sendResponse(context: context, status: .ok, body: "Session terminated")
        } else {
            sendResponse(context: context, status: .notFound, body: "Session not found")
        }
    }

    // MARK: - Authentication

    private func checkAuthorization(headers: HTTPHeaders) async -> Bool {
        // If no authentication is configured, allow all requests
        if authenticator == nil && oauthServer == nil {
            return true
        }

        let authHeader = headers.first(name: "Authorization")

        // Try API key authentication first (if configured)
        // This allows API keys to work even when OAuth is enabled
        if let authenticator = authenticator {
            if await authenticator.validate(authHeader: authHeader) {
                return true
            }
        }

        // Try OAuth Bearer token validation (if OAuth is configured)
        if let handler = oauthHandler, let header = authHeader, header.lowercased().hasPrefix("bearer ") {
            let result = await handler.validateBearerToken(authHeader: header)
            if result.isValid {
                return true
            }
        }

        // If we get here and either auth method is configured, deny access
        if authenticator != nil || oauthServer != nil {
            return false
        }

        return true
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
        // Don't close - allow HTTP keep-alive for connection reuse
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
        headers.add(name: "Connection", value: "close")

        let responseHead = HTTPResponseHead(
            version: .http1_1,
            status: .noContent,
            headers: headers
        )

        context.write(wrapOutboundOut(.head(responseHead)), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
        // Don't close - allow HTTP keep-alive for connection reuse
    }

    private func addCORSHeaders(to headers: inout HTTPHeaders) {
        headers.add(name: "Access-Control-Allow-Origin", value: "*")
        headers.add(name: "Access-Control-Allow-Methods", value: "GET, POST, DELETE, OPTIONS")
        headers.add(name: "Access-Control-Allow-Headers", value: "Content-Type, Authorization, Mcp-Session-Id")
        headers.add(name: "Access-Control-Expose-Headers", value: "Mcp-Session-Id")
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
