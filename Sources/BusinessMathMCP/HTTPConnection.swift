import Foundation
import NIOCore

/// Protocol abstraction for HTTP connections
///
/// This protocol provides a platform-agnostic interface for HTTP connections,
/// allowing the codebase to work with both Network framework (legacy) and
/// SwiftNIO (current) implementations.
///
/// ## Purpose
///
/// During migration from Network framework to SwiftNIO, this protocol allows
/// incremental migration by providing a common interface that both implementations
/// can conform to.
///
/// ## Usage Example
///
/// ```swift
/// func sendResponse(to connection: HTTPConnection, data: Data) async throws {
///     try await connection.send(data)
/// }
/// ```
///
/// ## Topics
///
/// ### Sending Data
/// - ``send(_:)``
///
/// ### Connection Management
/// - ``close()``
/// - ``isActive``
///
/// ### Connection Information
/// - ``remoteAddress``
/// - ``id``
public protocol HTTPConnection: Sendable {
    /// Unique identifier for this connection
    var id: String { get }

    /// Remote address of the connected client
    var remoteAddress: String { get }

    /// Whether the connection is currently active
    var isActive: Bool { get async }

    /// Send data to the client
    /// - Parameter data: Data to send
    /// - Throws: If the send operation fails
    func send(_ data: Data) async throws

    /// Close the connection
    func close() async
}

/// Errors that can occur during HTTP connection operations
public enum HTTPConnectionError: Error, CustomStringConvertible {
    /// Connection is not active
    case connectionInactive

    /// Failed to write data
    case writeFailed(Error)

    /// Connection closed unexpectedly
    case connectionClosed

    /// Invalid data format
    case invalidData

    public var description: String {
        switch self {
        case .connectionInactive:
            return "Connection is not active"
        case .writeFailed(let error):
            return "Failed to write data: \(error.localizedDescription)"
        case .connectionClosed:
            return "Connection closed unexpectedly"
        case .invalidData:
            return "Invalid data format"
        }
    }
}
