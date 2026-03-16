import Foundation
import Logging

/// Configuration for verbose debug logging
///
/// `LoggingConfiguration` provides centralized control over logging behavior,
/// including log levels, channel ID tracking, and response content logging.
///
/// ## Overview
///
/// The configuration can be set via:
/// - CLI flags: `--verbose` or `-v`
/// - Environment variable: `LOG_LEVEL=debug`
///
/// ## Example
///
/// ```swift
/// // Parse from command line arguments
/// let config = LoggingConfiguration.parse(arguments: CommandLine.arguments)
///
/// // Create a logger with the configured level
/// let logger = config.makeLogger(label: "my-component")
///
/// // Use verbose convenience factory
/// let verboseConfig = LoggingConfiguration.verbose()
/// ```
///
/// ## Security
///
/// When logging is enabled, sensitive data (API keys, tokens, secrets) is
/// automatically redacted using `sanitizeForLogging(_:)`.
public struct LoggingConfiguration: Sendable {

    // MARK: - Properties

    /// The log level for all loggers
    public var logLevel: Logger.Level

    /// Whether verbose mode is enabled
    public var isVerbose: Bool

    /// Whether to include channel IDs in log output
    public var includeChannelIds: Bool

    /// Whether to include response content in log output
    public var includeResponseContent: Bool

    /// Maximum length for logged content before truncation
    public var maxContentLength: Int

    // MARK: - Initialization

    /// Creates a new logging configuration with default values
    public init() {
        self.logLevel = .info
        self.isVerbose = false
        self.includeChannelIds = false
        self.includeResponseContent = false
        self.maxContentLength = 200
    }

    // MARK: - Factory Methods

    /// Creates a verbose configuration for debugging
    ///
    /// Enables debug log level and all verbose features:
    /// - Channel ID logging
    /// - Response content logging
    ///
    /// - Returns: A configuration with all verbose features enabled
    public static func verbose() -> LoggingConfiguration {
        var config = LoggingConfiguration()
        config.logLevel = .debug
        config.isVerbose = true
        config.includeChannelIds = true
        config.includeResponseContent = true
        return config
    }

    /// Creates a production configuration with minimal logging
    ///
    /// Uses info log level with no verbose features.
    ///
    /// - Returns: A minimal configuration suitable for production
    public static func production() -> LoggingConfiguration {
        return LoggingConfiguration()
    }

    // MARK: - Parsing

    /// Parses configuration from command line arguments
    ///
    /// Recognizes:
    /// - `--verbose` or `-v` flags to enable verbose mode
    ///
    /// - Parameter arguments: Command line arguments (typically `CommandLine.arguments`)
    /// - Returns: Parsed configuration
    public static func parse(arguments: [String]) -> LoggingConfiguration {
        return parse(arguments: arguments, environment: ProcessInfo.processInfo.environment)
    }

    /// Parses configuration from command line arguments and environment
    ///
    /// CLI flags take precedence over environment variables.
    ///
    /// - Parameters:
    ///   - arguments: Command line arguments
    ///   - environment: Environment variables
    /// - Returns: Parsed configuration
    public static func parse(arguments: [String], environment: [String: String]) -> LoggingConfiguration {
        var config = fromEnvironment(environment)

        // CLI flags override environment
        if arguments.contains("--verbose") || arguments.contains("-v") {
            config.logLevel = .debug
            config.isVerbose = true
            config.includeChannelIds = true
            config.includeResponseContent = true
        }

        return config
    }

    /// Parses configuration from environment variables
    ///
    /// Recognizes:
    /// - `LOG_LEVEL`: trace, debug, info, notice, warning, error, critical
    ///
    /// - Parameter environment: Environment variables dictionary
    /// - Returns: Parsed configuration
    public static func fromEnvironment(_ environment: [String: String]) -> LoggingConfiguration {
        var config = LoggingConfiguration()

        if let levelString = environment["LOG_LEVEL"]?.lowercased() {
            switch levelString {
            case "trace":
                config.logLevel = .trace
            case "debug":
                config.logLevel = .debug
                config.isVerbose = true
                config.includeChannelIds = true
                config.includeResponseContent = true
            case "info":
                config.logLevel = .info
            case "notice":
                config.logLevel = .notice
            case "warning":
                config.logLevel = .warning
            case "error":
                config.logLevel = .error
            case "critical":
                config.logLevel = .critical
            default:
                // Invalid level, keep default
                break
            }
        }

        return config
    }

    // MARK: - Logger Factory

    /// Creates a logger with the configured log level
    ///
    /// - Parameter label: The logger label (typically the component name)
    /// - Returns: A configured Logger instance
    public func makeLogger(label: String) -> Logger {
        var logger = Logger(label: label)
        logger.logLevel = logLevel
        return logger
    }

    // MARK: - Content Formatting

    /// Truncates content for logging if it exceeds the maximum length
    ///
    /// - Parameter content: The content to potentially truncate
    /// - Returns: The original content if short enough, or truncated with "..."
    public func truncateForLogging(_ content: String) -> String {
        guard content.count > maxContentLength else {
            return content
        }
        return String(content.prefix(maxContentLength)) + "..."
    }

    /// Sanitizes content for logging by redacting sensitive data
    ///
    /// Redacts:
    /// - API keys (bm_xxx format)
    /// - Bearer tokens
    /// - OAuth access tokens
    /// - Client secrets
    ///
    /// - Parameter content: The content to sanitize
    /// - Returns: Content with sensitive data redacted
    public func sanitizeForLogging(_ content: String) -> String {
        var result = content

        // Redact API keys (bm_xxx format)
        let apiKeyPattern = #"bm_[A-Za-z0-9_\-]{20,}"#
        if let regex = try? NSRegularExpression(pattern: apiKeyPattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "bm_***[REDACTED]")
        }

        // Redact Bearer tokens in Authorization headers
        let bearerPattern = #"Bearer\s+[A-Za-z0-9_\-\.]+"#
        if let regex = try? NSRegularExpression(pattern: bearerPattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "Bearer [REDACTED]")
        }

        // Redact access_token values
        let accessTokenPattern = #"access_token[=:]\s*[A-Za-z0-9_\-\.]+"#
        if let regex = try? NSRegularExpression(pattern: accessTokenPattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "access_token=[REDACTED]")
        }

        // Redact client_secret values
        let clientSecretPattern = #"client_secret[=:]\s*[A-Za-z0-9_\-]+"#
        if let regex = try? NSRegularExpression(pattern: clientSecretPattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "client_secret=[REDACTED]")
        }

        return result
    }

    /// Formats a channel ID as an 8-character hex string
    ///
    /// - Parameter channelId: The channel identifier (typically from ObjectIdentifier.hashValue)
    /// - Returns: Zero-padded 8-character hex string
    public func formatChannelId(_ channelId: Int) -> String {
        return String(format: "%08x", channelId & 0xFFFFFFFF)
    }
}
