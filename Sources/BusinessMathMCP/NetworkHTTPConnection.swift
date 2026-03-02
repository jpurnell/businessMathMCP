import Foundation
import Network

/// Temporary wrapper for Network framework's NWConnection to conform to HTTPConnection
///
/// This class bridges the gap during migration from Network framework to SwiftNIO.
/// Once the migration is complete, this file will be deleted.
///
/// ## Lifecycle
///
/// - **Created**: During Network → SwiftNIO migration
/// - **Usage**: Allows existing Network-based code to work with HTTPConnection protocol
/// - **Removal**: Delete this file when HTTPServerTransport is migrated to SwiftNIO
///
/// ## Topics
///
/// ### Creating Connections
/// - ``init(nwConnection:)``
public final class NetworkHTTPConnection: HTTPConnection, @unchecked Sendable {
    private let nwConnection: NWConnection

    /// Unique identifier for this connection
    public let id: String

    /// Remote address of the connected client
    public let remoteAddress: String

    /// Whether the connection is currently active
    public var isActive: Bool {
        get async {
            return nwConnection.state == .ready
        }
    }

    /// Initialize with a Network framework connection
    /// - Parameter nwConnection: The NWConnection to wrap
    public init(nwConnection: NWConnection) {
        self.nwConnection = nwConnection
        self.id = String(format: "%016llx", ObjectIdentifier(nwConnection).hashValue)
        self.remoteAddress = nwConnection.endpoint.debugDescription
    }

    /// Send data to the client
    /// - Parameter data: Data to send
    /// - Throws: HTTPConnectionError if the operation fails
    public func send(_ data: Data) async throws {
        guard nwConnection.state == .ready else {
            throw HTTPConnectionError.connectionInactive
        }

        return try await withCheckedThrowingContinuation { continuation in
            nwConnection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: HTTPConnectionError.writeFailed(error))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    /// Close the connection
    public func close() async {
        nwConnection.cancel()
    }
}
