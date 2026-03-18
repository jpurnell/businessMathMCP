import Foundation
import Logging

/// Manages MCP Streamable HTTP sessions (spec 2025-03-26)
///
/// Each session is created when an `initialize` JSON-RPC request arrives.
/// The session ID is returned via the `Mcp-Session-Id` response header
/// and must be included on all subsequent requests.
public actor StreamableSessionManager {
    private let logger: Logger

    /// Active sessions keyed by Mcp-Session-Id
    private var sessions: [String: StreamableSession] = [:]

    /// Session timeout (default: 5 minutes)
    private let sessionTimeout: TimeInterval

    /// Cleanup task
    private var cleanupTask: Task<Void, Never>?

    /// Heartbeat task for SSE connections
    private var heartbeatTask: Task<Void, Never>?

    /// A Streamable HTTP session
    struct StreamableSession {
        let sessionId: String
        let createdAt: Date
        var lastActivityAt: Date
        /// SSE connections for server-initiated messages (GET /mcp streams)
        var sseConnections: [SSESession] = []
    }

    public init(
        sessionTimeout: TimeInterval = 300.0,
        logger: Logger = Logger(label: "streamable-session-manager")
    ) {
        self.sessionTimeout = sessionTimeout
        self.logger = logger
    }

    // MARK: - Session Lifecycle

    /// Create a new session (called on `initialize` request)
    public func createSession() -> String {
        let sessionId = UUID().uuidString
        sessions[sessionId] = StreamableSession(
            sessionId: sessionId,
            createdAt: Date(),
            lastActivityAt: Date()
        )
        logger.info("Created streamable session: \(sessionId)")
        return sessionId
    }

    /// Validate that a session ID exists and is active
    public func validateSession(_ sessionId: String) -> Bool {
        return sessions[sessionId] != nil
    }

    /// Update last activity time for a session
    public func touchSession(_ sessionId: String) {
        sessions[sessionId]?.lastActivityAt = Date()
    }

    /// Remove a session (called on DELETE /mcp)
    /// - Returns: true if session existed and was removed
    public func removeSession(_ sessionId: String) -> Bool {
        guard let session = sessions.removeValue(forKey: sessionId) else {
            return false
        }
        // Close any SSE connections
        for sse in session.sseConnections {
            Task { await sse.close() }
        }
        logger.info("Removed streamable session: \(sessionId)")
        return true
    }

    /// Add an SSE connection to a session (for GET /mcp streams)
    public func addSSEConnection(_ sseSession: SSESession, to sessionId: String) {
        sessions[sessionId]?.sseConnections.append(sseSession)
        logger.debug("Added SSE connection to session \(sessionId)")
    }

    /// Get active SSE connections for a session (for broadcasting server-initiated messages)
    public func getSSEConnections(for sessionId: String) -> [SSESession] {
        return sessions[sessionId]?.sseConnections ?? []
    }

    /// Broadcast data to all SSE connections across all sessions
    public func broadcastToAllSSE(_ data: Data) async -> Bool {
        guard let jsonString = String(data: data, encoding: .utf8) else { return false }
        var sent = false
        for session in sessions.values {
            for sse in session.sseConnections {
                await sse.sendEvent(event: "message", data: jsonString)
                sent = true
            }
        }
        return sent
    }

    /// Get count of active sessions
    public func activeSessionCount() -> Int {
        return sessions.count
    }

    // MARK: - Maintenance

    public func startMaintenance() {
        guard cleanupTask == nil else { return }

        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await self?.cleanupExpiredSessions()
            }
        }

        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await self?.sendHeartbeats()
            }
        }

        logger.info("Started streamable session maintenance")
    }

    public func stopMaintenance() {
        cleanupTask?.cancel()
        cleanupTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    public func shutdown() {
        stopMaintenance()
        for session in sessions.values {
            for sse in session.sseConnections {
                Task { await sse.close() }
            }
        }
        sessions.removeAll()
        logger.info("Streamable session manager shutdown complete")
    }

    private func cleanupExpiredSessions() {
        let now = Date()
        var expired: [String] = []
        for (id, session) in sessions {
            if now.timeIntervalSince(session.lastActivityAt) > sessionTimeout {
                expired.append(id)
            }
        }
        for id in expired {
            _ = removeSession(id)
            logger.info("Cleaned up expired streamable session: \(id)")
        }
    }

    private func sendHeartbeats() {
        for session in sessions.values {
            for sse in session.sseConnections {
                Task { await sse.sendHeartbeat() }
            }
        }
    }
}
