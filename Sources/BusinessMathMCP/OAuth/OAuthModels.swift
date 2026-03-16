import Foundation

// MARK: - RegisteredClient

/// A registered OAuth 2.0 client
///
/// Represents a client application that has been registered with the OAuth server.
/// Clients can be confidential (with a secret) or public (without a secret).
///
/// ## Topics
///
/// ### Creating Clients
/// - ``init(clientId:clientSecret:clientName:redirectUris:grantTypes:tokenEndpointAuthMethod:registrationDate:)``
///
/// ### Client Properties
/// - ``clientId``
/// - ``clientSecret``
/// - ``clientName``
/// - ``redirectUris``
/// - ``grantTypes``
/// - ``tokenEndpointAuthMethod``
/// - ``registrationDate``
///
/// ## MCP Schema
///
/// **REQUIRED STRUCTURE (JSON):**
/// ```json
/// {
///   "client_id": "abc123",
///   "client_secret": "secret456",
///   "client_name": "My MCP Client",
///   "redirect_uris": ["http://localhost:8080/callback"],
///   "grant_types": ["authorization_code", "refresh_token"],
///   "token_endpoint_auth_method": "client_secret_basic",
///   "registration_date": 1710432000
/// }
/// ```
public struct RegisteredClient: Codable, Sendable, Equatable {
    /// Unique identifier for the client
    public let clientId: String

    /// Client secret for confidential clients (nil for public clients)
    public let clientSecret: String?

    /// Human-readable name of the client application
    public let clientName: String

    /// Valid redirect URIs for authorization responses
    public let redirectUris: [String]

    /// OAuth grant types this client is authorized to use
    public let grantTypes: [String]

    /// Authentication method for the token endpoint
    public let tokenEndpointAuthMethod: String

    /// When this client was registered
    public let registrationDate: Date

    /// Creates a new registered client
    /// - Parameters:
    ///   - clientId: Unique identifier for the client
    ///   - clientSecret: Secret for confidential clients (nil for public clients)
    ///   - clientName: Human-readable application name
    ///   - redirectUris: Valid redirect URIs
    ///   - grantTypes: Authorized grant types
    ///   - tokenEndpointAuthMethod: Token endpoint auth method
    ///   - registrationDate: Registration timestamp
    public init(
        clientId: String,
        clientSecret: String?,
        clientName: String,
        redirectUris: [String],
        grantTypes: [String],
        tokenEndpointAuthMethod: String,
        registrationDate: Date
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.clientName = clientName
        self.redirectUris = redirectUris
        self.grantTypes = grantTypes
        self.tokenEndpointAuthMethod = tokenEndpointAuthMethod
        self.registrationDate = registrationDate
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case clientSecret = "client_secret"
        case clientName = "client_name"
        case redirectUris = "redirect_uris"
        case grantTypes = "grant_types"
        case tokenEndpointAuthMethod = "token_endpoint_auth_method"
        case registrationDate = "registration_date"
    }
}

// MARK: - ClientRegistrationRequest

/// Request to register a new OAuth client
///
/// Used by clients to dynamically register with the OAuth server per RFC 7591.
///
/// ## MCP Schema
///
/// **REQUIRED STRUCTURE (JSON):**
/// ```json
/// {
///   "client_name": "My MCP Client",
///   "redirect_uris": ["http://localhost:8080/callback"],
///   "grant_types": ["authorization_code", "refresh_token"],
///   "token_endpoint_auth_method": "client_secret_basic",
///   "scope": "mcp:tools mcp:resources"
/// }
/// ```
public struct ClientRegistrationRequest: Codable, Sendable, Equatable {
    /// Human-readable name for the client
    public let clientName: String

    /// Redirect URIs for authorization responses
    public let redirectUris: [String]

    /// Requested grant types (defaults to ["authorization_code"])
    public let grantTypes: [String]

    /// Requested token endpoint auth method (defaults to "client_secret_basic")
    public let tokenEndpointAuthMethod: String

    /// Requested scope (optional)
    public let scope: String?

    /// Creates a client registration request
    /// - Parameters:
    ///   - clientName: Human-readable name for the client
    ///   - redirectUris: Redirect URIs for authorization responses
    ///   - grantTypes: Requested grant types
    ///   - tokenEndpointAuthMethod: Token endpoint auth method
    ///   - scope: Requested scope
    public init(
        clientName: String,
        redirectUris: [String],
        grantTypes: [String] = ["authorization_code"],
        tokenEndpointAuthMethod: String = "client_secret_basic",
        scope: String? = nil
    ) {
        self.clientName = clientName
        self.redirectUris = redirectUris
        self.grantTypes = grantTypes
        self.tokenEndpointAuthMethod = tokenEndpointAuthMethod
        self.scope = scope
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case clientName = "client_name"
        case redirectUris = "redirect_uris"
        case grantTypes = "grant_types"
        case tokenEndpointAuthMethod = "token_endpoint_auth_method"
        case scope
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.clientName = try container.decode(String.self, forKey: .clientName)
        self.redirectUris = try container.decode([String].self, forKey: .redirectUris)
        self.grantTypes = try container.decodeIfPresent([String].self, forKey: .grantTypes) ?? ["authorization_code"]
        self.tokenEndpointAuthMethod = try container.decodeIfPresent(String.self, forKey: .tokenEndpointAuthMethod) ?? "client_secret_basic"
        self.scope = try container.decodeIfPresent(String.self, forKey: .scope)
    }
}

// MARK: - TokenResponse

/// OAuth 2.0 token response per RFC 6749 §5.1
///
/// Returned by the token endpoint after successful authorization.
///
/// ## MCP Schema
///
/// **REQUIRED STRUCTURE (JSON):**
/// ```json
/// {
///   "access_token": "eyJhbGciOiJIUzI1NiIs...",
///   "token_type": "Bearer",
///   "expires_in": 86400,
///   "refresh_token": "refresh_token_here",
///   "scope": "mcp:tools mcp:resources"
/// }
/// ```
public struct TokenResponse: Codable, Sendable, Equatable {
    /// The access token issued by the authorization server
    public let accessToken: String

    /// The type of token issued (always "Bearer")
    public let tokenType: String

    /// Lifetime of the access token in seconds
    public let expiresIn: Int

    /// Refresh token for obtaining new access tokens (optional)
    public let refreshToken: String?

    /// Scope of the access token (optional)
    public let scope: String?

    /// Creates a token response
    /// - Parameters:
    ///   - accessToken: The access token
    ///   - tokenType: Token type (usually "Bearer")
    ///   - expiresIn: Lifetime in seconds
    ///   - refreshToken: Optional refresh token
    ///   - scope: Optional scope
    public init(
        accessToken: String,
        tokenType: String,
        expiresIn: Int,
        refreshToken: String?,
        scope: String?
    ) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.refreshToken = refreshToken
        self.scope = scope
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - TokenValidationResult

/// Result of validating an access token
public enum TokenValidationResult: Sendable, Equatable {
    /// Token is valid with associated client and scope
    case valid(clientId: String, scope: String?)

    /// Token is invalid with reason
    case invalid(reason: String)

    /// Convenience property to check if token is valid
    public var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
}

// MARK: - OAuthError

/// OAuth 2.0 error codes per RFC 6749 §5.2
///
/// These errors are returned in the error response from token and authorization endpoints.
public enum OAuthError: Error, Codable, Sendable, Equatable {
    /// The request is missing a required parameter or is otherwise malformed
    case invalidRequest

    /// Client authentication failed
    case invalidClient

    /// The provided authorization grant or refresh token is invalid, expired, or revoked
    case invalidGrant

    /// The client is not authorized to use this grant type
    case unauthorizedClient

    /// The authorization server does not support the requested grant type
    case unsupportedGrantType

    /// The requested scope is invalid, unknown, or malformed
    case invalidScope

    /// Server encountered an unexpected error
    case serverError(String)

    /// The RFC 6749 error code string
    public var errorCode: String {
        switch self {
        case .invalidRequest: return "invalid_request"
        case .invalidClient: return "invalid_client"
        case .invalidGrant: return "invalid_grant"
        case .unauthorizedClient: return "unauthorized_client"
        case .unsupportedGrantType: return "unsupported_grant_type"
        case .invalidScope: return "invalid_scope"
        case .serverError: return "server_error"
        }
    }

    /// Human-readable error description
    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "The request is missing a required parameter or is otherwise malformed."
        case .invalidClient:
            return "Client authentication failed."
        case .invalidGrant:
            return "The provided authorization grant or refresh token is invalid, expired, or revoked."
        case .unauthorizedClient:
            return "The client is not authorized to use this grant type."
        case .unsupportedGrantType:
            return "The authorization server does not support the requested grant type."
        case .invalidScope:
            return "The requested scope is invalid, unknown, or malformed."
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let code = try container.decode(String.self, forKey: .error)

        switch code {
        case "invalid_request": self = .invalidRequest
        case "invalid_client": self = .invalidClient
        case "invalid_grant": self = .invalidGrant
        case "unauthorized_client": self = .unauthorizedClient
        case "unsupported_grant_type": self = .unsupportedGrantType
        case "invalid_scope": self = .invalidScope
        default: self = .serverError(code)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(errorCode, forKey: .error)
        try container.encode(errorDescription, forKey: .errorDescription)
    }
}

// MARK: - AuthorizationCode

/// An OAuth authorization code issued during the authorization flow
///
/// Authorization codes are short-lived and single-use.
public struct AuthorizationCode: Codable, Sendable, Equatable {
    /// The authorization code value
    public let code: String

    /// Client that requested this code
    public let clientId: String

    /// Redirect URI used in the request
    public let redirectUri: String

    /// Scope requested (optional)
    public let scope: String?

    /// PKCE code challenge (optional)
    public let codeChallenge: String?

    /// PKCE code challenge method (optional, typically "S256")
    public let codeChallengeMethod: String?

    /// When this code expires
    public let expiresAt: Date

    /// When this code was created
    public let createdAt: Date

    /// Whether this code has expired
    public var isExpired: Bool {
        Date() >= expiresAt
    }

    /// Creates an authorization code
    /// - Parameters:
    ///   - code: The code value
    ///   - clientId: Client that requested this code
    ///   - redirectUri: Redirect URI from the request
    ///   - scope: Requested scope
    ///   - codeChallenge: PKCE code challenge
    ///   - codeChallengeMethod: PKCE method
    ///   - expiresAt: Expiration time
    ///   - createdAt: Creation time
    public init(
        code: String,
        clientId: String,
        redirectUri: String,
        scope: String?,
        codeChallenge: String?,
        codeChallengeMethod: String?,
        expiresAt: Date,
        createdAt: Date
    ) {
        self.code = code
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.scope = scope
        self.codeChallenge = codeChallenge
        self.codeChallengeMethod = codeChallengeMethod
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case code
        case clientId = "client_id"
        case redirectUri = "redirect_uri"
        case scope
        case codeChallenge = "code_challenge"
        case codeChallengeMethod = "code_challenge_method"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

// MARK: - CSRFValidationResult

/// Result of CSRF token validation
///
/// Used by the consent page submission handler to verify
/// that the form submission is legitimate.
public struct CSRFValidationResult: Sendable, Equatable {
    /// Whether the CSRF token is valid
    public let isValid: Bool

    /// Error message if validation failed
    public let error: String?

    /// Creates a validation result
    /// - Parameters:
    ///   - isValid: Whether the token is valid
    ///   - error: Error message if invalid
    public init(isValid: Bool, error: String? = nil) {
        self.isValid = isValid
        self.error = error
    }
}
