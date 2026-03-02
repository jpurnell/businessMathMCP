import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOFoundationCompat

/// SwiftNIO implementation of HTTPConnection
///
/// This class wraps a SwiftNIO `Channel` and provides the `HTTPConnection`
/// interface for sending data and managing the connection lifecycle.
///
/// ## Usage Example
///
/// ```swift
/// let connection = NIOHTTPConnection(channel: channel)
/// try await connection.send(responseData)
/// await connection.close()
/// ```
///
/// ## Topics
///
/// ### Creating Connections
/// - ``init(channel:)``
///
/// ### Connection Properties
/// - ``id``
/// - ``remoteAddress``
/// - ``isActive``
///
/// ### Sending Data
/// - ``send(_:)``
///
/// ### Connection Management
/// - ``close()``
public final class NIOHTTPConnection: HTTPConnection, @unchecked Sendable {
    /// The underlying NIO channel
    private let channel: Channel

    /// Unique identifier for this connection
    public let id: String

    /// Remote address of the connected client
    public let remoteAddress: String

    /// Whether the connection is currently active
    public var isActive: Bool {
        get async {
            return channel.isActive
        }
    }

    /// Initialize with a NIO channel
    /// - Parameter channel: The NIO channel to wrap
    public init(channel: Channel) {
        self.channel = channel
        // Use ObjectIdentifier for unique channel ID
        self.id = String(format: "%016llx", ObjectIdentifier(channel).hashValue)
        self.remoteAddress = channel.remoteAddress?.description ?? "unknown"
    }

    /// Send data to the client
    /// - Parameter data: Data to send
    /// - Throws: HTTPConnectionError if the operation fails
    public func send(_ data: Data) async throws {
        guard channel.isActive else {
            throw HTTPConnectionError.connectionInactive
        }

        do {
            // Convert Data to ByteBuffer
            var buffer = channel.allocator.buffer(capacity: data.count)
            buffer.writeBytes(data)

            // Capture buffer immutably for sendable closure
            let finalBuffer = buffer

            // Ensure write happens on the EventLoop
            // For HTTP channels with HTTPResponseEncoder, we need to wrap in HTTPServerResponsePart.body
            try await channel.eventLoop.submit {
                // Write as HTTPServerResponsePart.body for SSE streaming
                let part = HTTPServerResponsePart.body(.byteBuffer(finalBuffer))
                return self.channel.writeAndFlush(part)
            }.flatMap { $0 }.get()
        } catch {
            throw HTTPConnectionError.writeFailed(error)
        }
    }

    /// Close the connection
    public func close() async {
        do {
            try await channel.close()
        } catch {
            // Log error but don't throw - close is best-effort
        }
    }
}
