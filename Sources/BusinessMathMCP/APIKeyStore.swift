import Foundation
import Crypto

// MARK: - APIKey Model

/// A persistent API key for authentication
///
/// API keys use the format `bm_<32-character-base64url>` for easy identification.
///
/// ## Example
/// ```swift
/// let key = APIKey.generate(name: "Claude Code")
/// print(key.key)  // bm_7Kx9mPqR2sT4vW6xY8zA0bC3dE5fG7hJ
/// ```
public struct APIKey: Codable, Sendable, Equatable {
    /// The full API key string (e.g., "bm_xxxx...")
    public let key: String

    /// Human-readable name for this key
    public let name: String

    /// When this key was created
    public let created: Date

    /// When this key was last used (nil if never used)
    public var lastUsed: Date?

    /// The key prefix for identification (e.g., "bm_7Kx9mP...")
    public var prefix: String {
        String(key.prefix(10)) + "..."
    }

    // MARK: - Key Generation

    /// Generates a new API key with the standard format
    ///
    /// - Parameter name: Human-readable name for the key
    /// - Returns: A new API key
    public static func generate(name: String) -> APIKey {
        let randomBytes = (0..<24).map { _ in UInt8.random(in: 0...255) }
        let base64 = Data(randomBytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        // Take first 32 characters
        let keyValue = "bm_" + String(base64.prefix(32))

        return APIKey(
            key: keyValue,
            name: name,
            created: Date(),
            lastUsed: nil
        )
    }

    // MARK: - Validation

    /// Validates if a string matches the API key format
    ///
    /// - Parameter key: The key string to validate
    /// - Returns: `true` if the format is valid
    public static func isValidFormat(_ key: String) -> Bool {
        guard key.hasPrefix("bm_") else { return false }
        guard key.count == 35 else { return false }  // bm_ (3) + 32 chars

        // Check that remaining characters are base64url-safe
        let suffix = String(key.dropFirst(3))
        let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return suffix.unicodeScalars.allSatisfy { validChars.contains($0) }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case key
        case name
        case created
        case lastUsed = "last_used"
    }
}

// MARK: - APIKeySummary

/// A summary of an API key without exposing the full key value
public struct APIKeySummary: Sendable {
    /// The key prefix (e.g., "bm_7Kx9mP...")
    public let prefix: String

    /// Human-readable name
    public let name: String

    /// Creation date
    public let created: Date

    /// Last used date (nil if never used)
    public let lastUsed: Date?
}

// MARK: - APIKeyStore

/// Actor for managing persistent API keys
///
/// Stores keys in `~/.businessmath-mcp/api-keys.json` by default.
///
/// ## Example
/// ```swift
/// let store = APIKeyStore()
/// let key = try await store.generateKey(name: "Claude Code")
/// print(key.key)  // Use this in Authorization header
/// ```
public actor APIKeyStore {
    /// Directory for storing keys
    private let directory: URL

    /// File path for the keys JSON file
    private var keysFile: URL {
        directory.appendingPathComponent("api-keys.json")
    }

    /// In-memory cache of keys
    private var keys: [APIKey] = []

    /// Whether keys have been loaded from disk
    private var loaded = false

    // MARK: - Initialization

    /// Creates a key store with the default directory (~/.businessmath-mcp)
    public init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.directory = homeDir.appendingPathComponent(".businessmath-mcp")
    }

    /// Creates a key store with a custom directory
    ///
    /// - Parameter directory: Directory to store keys in
    public init(directory: URL) {
        self.directory = directory
    }

    // MARK: - Key Management

    /// Generates and saves a new API key
    ///
    /// - Parameter name: Human-readable name for the key
    /// - Returns: The generated key
    /// - Throws: If the key cannot be saved
    public func generateKey(name: String) throws -> APIKey {
        try ensureLoaded()

        let key = APIKey.generate(name: name)
        keys.append(key)
        try save()

        return key
    }

    /// Lists all stored keys
    ///
    /// - Returns: Array of all keys
    public func listKeys() throws -> [APIKey] {
        try ensureLoaded()
        return keys
    }

    /// Lists key summaries without exposing full key values
    ///
    /// - Returns: Array of key summaries
    public func listKeySummaries() -> [APIKeySummary] {
        do {
            try ensureLoaded()
        } catch {
            return []
        }

        return keys.map { key in
            APIKeySummary(
                prefix: key.prefix,
                name: key.name,
                created: key.created,
                lastUsed: key.lastUsed
            )
        }
    }

    /// Validates if a key exists and is valid
    ///
    /// - Parameter key: The full key string to validate
    /// - Returns: `true` if the key is valid
    public func isValid(key: String) -> Bool {
        do {
            try ensureLoaded()
        } catch {
            return false
        }

        guard let index = keys.firstIndex(where: { $0.key == key }) else {
            return false
        }

        // Update last used timestamp
        var updatedKey = keys[index]
        updatedKey.lastUsed = Date()
        keys[index] = updatedKey

        // Save asynchronously (don't block validation)
        Task {
            try? self.save()
        }

        return true
    }

    /// Revokes a key by its prefix
    ///
    /// - Parameter prefix: The key prefix (at least 6 characters)
    /// - Returns: `true` if a key was revoked
    public func revokeKey(prefix: String) throws -> Bool {
        try ensureLoaded()

        let initialCount = keys.count
        keys.removeAll { $0.key.hasPrefix(prefix) }

        if keys.count != initialCount {
            try save()
            return true
        }

        return false
    }

    /// Returns the number of stored keys
    public func keyCount() -> Int {
        do {
            try ensureLoaded()
        } catch {
            return 0
        }
        return keys.count
    }

    // MARK: - Persistence

    private func ensureLoaded() throws {
        guard !loaded else { return }

        // Create directory if needed
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        // Load existing keys if file exists
        if FileManager.default.fileExists(atPath: keysFile.path) {
            let data = try Data(contentsOf: keysFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let container = try decoder.decode(KeysContainer.self, from: data)
            keys = container.keys
        }

        loaded = true
    }

    private func save() throws {
        let container = KeysContainer(keys: keys)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(container)
        try data.write(to: keysFile, options: .atomic)

        // Set restrictive permissions (owner read/write only)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: keysFile.path
        )
    }

    /// Container for JSON serialization
    private struct KeysContainer: Codable {
        let keys: [APIKey]
    }
}
