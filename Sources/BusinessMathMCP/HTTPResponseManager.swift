import Foundation
import Logging

/// Manages correlation between JSON-RPC requests and HTTP connections
///
/// The MCP transport protocol is designed for streaming (stdio, WebSocket), but HTTP
/// is request/response based. This manager bridges the gap by:
/// - Tracking which HTTP connection made which JSON-RPC request
/// - Routing MCP server responses back to the correct HTTP connection
/// - Handling timeouts and connection cleanup
///
/// ## Architecture
///
/// ```
/// HTTP POST /mcp → handleRequest(connection, jsonRpcId)
///                      ↓ Store (jsonRpcId → connection)
///                      ↓ Forward to MCP server
/// MCP Server processes request
///                      ↓ Calls transport.send(response)
/// send() extracts jsonRpcId from response
///                      ↓ Lookup connection from registry
///                      ↓ Send HTTP response to client
/// ```
public actor HTTPResponseManager {
    private let logger: Logger

    /// Registry of pending requests: JSON-RPC ID → HTTP connection
    private var pendingRequests: [JSONRPCId: PendingRequest] = [:]

    /// Timeout for pending requests (default: 5 minutes)
    private let requestTimeout: TimeInterval

    /// Cleanup task for expired requests
    private var cleanupTask: Task<Void, Never>?

    /// A pending HTTP request awaiting its JSON-RPC response
    private struct PendingRequest {
        let connection: HTTPConnection
        let receivedAt: Date
        let requestId: JSONRPCId
        var mcpSessionId: String?
    }

    /// JSON-RPC request/response ID (can be string, number, or null)
    public enum JSONRPCId: Hashable, Codable, Sendable {
        case string(String)
        case number(Int)
        case null

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .string(string)
            } else if let number = try? container.decode(Int.self) {
                self = .number(number)
            } else if container.decodeNil() {
                self = .null
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Invalid JSON-RPC ID type"
                    )
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value):
                try container.encode(value)
            case .number(let value):
                try container.encode(value)
            case .null:
                try container.encodeNil()
            }
        }
    }

    /// Initialize the response manager
    /// - Parameters:
    ///   - requestTimeout: Maximum time to wait for a response (default: 30s)
    ///   - logger: Logger instance
    public init(requestTimeout: TimeInterval = 300.0, logger: Logger = Logger(label: "http-response-manager")) {
        self.requestTimeout = requestTimeout
        self.logger = logger
    }

    /// Start the periodic cleanup task for expired requests
    public func startCleanup() {
        guard cleanupTask == nil else { return }

        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                await self?.cleanupExpiredRequests()
            }
        }
    }

    /// Stop the cleanup task
    public func stopCleanup() {
        cleanupTask?.cancel()
        cleanupTask = nil
    }

    deinit {
        cleanupTask?.cancel()
    }

    /// Register a pending request awaiting response
    /// - Parameters:
    ///   - requestId: The JSON-RPC request ID
    ///   - connection: The HTTP connection to send the response to
    public func registerRequest(requestId: JSONRPCId, connection: HTTPConnection) {
        let pending = PendingRequest(
            connection: connection,
            receivedAt: Date(),
            requestId: requestId
        )
        pendingRequests[requestId] = pending
        logger.debug("Registered pending request: \(requestId)")
    }

    /// Attach an Mcp-Session-Id to a pending request so it's included in the response header
    public func setSessionIdForRequest(_ requestId: JSONRPCId, sessionId: String) {
        pendingRequests[requestId]?.mcpSessionId = sessionId
    }

    /// Route a JSON-RPC response back to its HTTP connection
    /// - Parameter responseData: The JSON-RPC response (as Data)
    /// - Returns: Whether the response was successfully routed
    public func routeResponse(_ responseData: Data) -> Bool {
        // Extract the JSON-RPC ID from the response
        guard let requestId = extractRequestId(from: responseData) else {
            logger.warning("Could not extract JSON-RPC ID from response")
            return false
        }

        // Look up the pending request
        guard let pending = pendingRequests.removeValue(forKey: requestId) else {
            logger.warning("No pending request found for JSON-RPC ID: \(requestId)")
            return false
        }

        // Send HTTP response
        sendHTTPResponse(
            connection: pending.connection,
            statusCode: 200,
            body: responseData,
            contentType: "application/json",
            mcpSessionId: pending.mcpSessionId
        )

        logger.debug("Routed response for request: \(requestId)")
        return true
    }

    /// Extract JSON-RPC ID from response data
    private func extractRequestId(from data: Data) -> JSONRPCId? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // JSON-RPC response has either "id" field or is a notification (no id)
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

    /// Send an HTTP response to a connection using proper HTTP framing
    private func sendHTTPResponse(
        connection: HTTPConnection,
        statusCode: Int,
        body: Data,
        contentType: String,
        mcpSessionId: String? = nil
    ) {
        Task {
            // Build headers list
            var headers: [(String, String)] = [
                ("Content-Type", contentType),
                ("Content-Length", "\(body.count)"),
                ("Connection", "close")
            ]
            if let sessionId = mcpSessionId {
                headers.append(("Mcp-Session-Id", sessionId))
            }
            // CORS headers for cross-origin requests
            headers.append(("Access-Control-Allow-Origin", "*"))
            headers.append(("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS"))
            headers.append(("Access-Control-Allow-Headers", "Content-Type, Authorization, Mcp-Session-Id"))
            headers.append(("Access-Control-Expose-Headers", "Mcp-Session-Id"))

            // Send proper HTTP response (.head, .body, .end)
            do {
                try await connection.sendHTTPResponse(statusCode: statusCode, headers: headers, body: body)
                // Close connection after response
                await connection.close()
            } catch {
                self.logger.error("Failed to send HTTP response: \(error.localizedDescription)")
            }
        }
    }

    /// Clean up requests that have timed out
    private func cleanupExpiredRequests() {
        let now = Date()
        let expired = pendingRequests.filter { _, pending in
            now.timeIntervalSince(pending.receivedAt) > requestTimeout
        }

        for (requestId, pending) in expired {
            pendingRequests.removeValue(forKey: requestId)

            // Send timeout error response
            let errorResponse = """
            {
              "jsonrpc": "2.0",
              "id": \(formatJsonRpcId(requestId)),
              "error": {
                "code": -32603,
                "message": "Request timeout",
                "data": "No response received within \(requestTimeout) seconds"
              }
            }
            """

            if let errorData = errorResponse.data(using: .utf8) {
                sendHTTPResponse(
                    connection: pending.connection,
                    statusCode: 504, // Gateway Timeout
                    body: errorData,
                    contentType: "application/json",
                    mcpSessionId: pending.mcpSessionId
                )
            }

            logger.warning("Request timed out: \(requestId)")
        }
    }

    /// Format JSON-RPC ID for inclusion in JSON string
    private func formatJsonRpcId(_ id: JSONRPCId) -> String {
        switch id {
        case .string(let value):
            return "\"\(value)\""
        case .number(let value):
            return "\(value)"
        case .null:
            return "null"
        }
    }

    /// Get count of pending requests (for monitoring)
    public func pendingCount() -> Int {
        return pendingRequests.count
    }
}
