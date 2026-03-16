import Foundation

/// OAuth 2.0 Authorization Server implementation
///
/// Implements RFC 6749 (OAuth 2.0), RFC 7636 (PKCE), RFC 7591 (Dynamic Client Registration),
/// and RFC 8414 (Authorization Server Metadata).
///
/// ## Overview
///
/// `OAuthServer` provides the complete OAuth 2.0 authorization code flow:
/// 1. Client registration (dynamic or pre-configured)
/// 2. Authorization request handling
/// 3. Token issuance and refresh
/// 4. Token validation and revocation
///
/// ## Example
///
/// ```swift
/// let storage = try OAuthStorage(path: "~/.businessmath-mcp/oauth.db")
/// let server = await OAuthServer(storage: storage, issuer: "https://mcp.example.com")
///
/// // Get server metadata
/// let metadata = await server.getMetadata()
///
/// // Register a client
/// let client = try await server.registerClient(request)
///
/// // Handle authorization
/// let authResponse = try await server.handleAuthorizationRequest(authRequest)
///
/// // Exchange code for tokens
/// let tokens = try await server.handleTokenRequest(tokenRequest)
/// ```
public actor OAuthServer {

    // MARK: - Properties

    private let storage: OAuthStorage
    private let issuer: String
    private let accessTokenLifetime: TimeInterval
    private let refreshTokenLifetime: TimeInterval
    private let authorizationCodeLifetime: TimeInterval

    // MARK: - Initialization

    /// Creates a new OAuth server
    ///
    /// - Parameters:
    ///   - storage: Storage backend for clients and tokens
    ///   - issuer: Base URL of this authorization server
    ///   - accessTokenLifetime: Access token lifetime in seconds (default: 24 hours)
    ///   - refreshTokenLifetime: Refresh token lifetime in seconds (default: 90 days)
    ///   - authorizationCodeLifetime: Auth code lifetime in seconds (default: 10 minutes)
    public init(
        storage: OAuthStorage,
        issuer: String,
        accessTokenLifetime: TimeInterval = 86400,        // 24 hours
        refreshTokenLifetime: TimeInterval = 7776000,     // 90 days
        authorizationCodeLifetime: TimeInterval = 600     // 10 minutes
    ) {
        self.storage = storage
        self.issuer = issuer
        self.accessTokenLifetime = accessTokenLifetime
        self.refreshTokenLifetime = refreshTokenLifetime
        self.authorizationCodeLifetime = authorizationCodeLifetime
    }

    // MARK: - Server Metadata (RFC 8414)

    /// Returns OAuth 2.0 Authorization Server Metadata
    public func getMetadata() -> ServerMetadata {
        ServerMetadata(
            issuer: issuer,
            authorizationEndpoint: "\(issuer)/authorize",
            tokenEndpoint: "\(issuer)/token",
            registrationEndpoint: "\(issuer)/register",
            responseTypesSupported: ["code"],
            grantTypesSupported: ["authorization_code", "refresh_token"],
            codeChallengeMethodsSupported: ["S256", "plain"],
            tokenEndpointAuthMethodsSupported: ["client_secret_basic", "client_secret_post", "none"],
            scopesSupported: ["mcp:tools", "mcp:resources", "mcp:prompts"]
        )
    }

    // MARK: - Client Registration (RFC 7591)

    /// Registers a new OAuth client
    ///
    /// - Parameter request: Client registration request
    /// - Returns: Registered client with generated credentials
    /// - Throws: `OAuthError.invalidRequest` if request is invalid
    public func registerClient(_ request: ClientRegistrationRequest) async throws -> ClientRegistrationResponse {
        // Validate request
        guard !request.redirectUris.isEmpty else {
            throw OAuthError.invalidRequest
        }

        // Generate credentials
        let clientId = TokenGenerator.generateClientId()
        let clientSecret: String?

        if request.tokenEndpointAuthMethod == "none" {
            clientSecret = nil
        } else {
            clientSecret = TokenGenerator.generateClientSecret()
        }

        let client = RegisteredClient(
            clientId: clientId,
            clientSecret: clientSecret,
            clientName: request.clientName,
            redirectUris: request.redirectUris,
            grantTypes: request.grantTypes,
            tokenEndpointAuthMethod: request.tokenEndpointAuthMethod,
            registrationDate: Date()
        )

        try await storage.saveClient(client)

        return ClientRegistrationResponse(
            clientId: clientId,
            clientSecret: clientSecret,
            clientName: request.clientName,
            redirectUris: request.redirectUris,
            grantTypes: request.grantTypes,
            tokenEndpointAuthMethod: request.tokenEndpointAuthMethod
        )
    }

    // MARK: - Authorization Endpoint

    /// Handles an authorization request
    ///
    /// - Parameter request: Authorization request parameters
    /// - Returns: Authorization response with code
    /// - Throws: `OAuthError` if request is invalid
    public func handleAuthorizationRequest(_ request: AuthorizationRequest) async throws -> AuthorizationResponse {
        // Validate response type
        guard request.responseType == "code" else {
            throw OAuthError.invalidRequest
        }

        // Validate client
        guard let client = try await storage.getClient(clientId: request.clientId) else {
            throw OAuthError.invalidClient
        }

        // Validate redirect URI
        guard client.redirectUris.contains(request.redirectUri) else {
            throw OAuthError.invalidRequest
        }

        // Validate scope if provided
        if let scope = request.scope {
            let validScopes = Set(["mcp:tools", "mcp:resources", "mcp:prompts"])
            let requestedScopes = Set(scope.split(separator: " ").map(String.init))
            guard requestedScopes.isSubset(of: validScopes) else {
                throw OAuthError.invalidScope
            }
        }

        // Generate authorization code
        let code = TokenGenerator.generateAuthorizationCode()
        let now = Date()

        let authCode = AuthorizationCode(
            code: code,
            clientId: request.clientId,
            redirectUri: request.redirectUri,
            scope: request.scope,
            codeChallenge: request.codeChallenge,
            codeChallengeMethod: request.codeChallengeMethod,
            expiresAt: now.addingTimeInterval(authorizationCodeLifetime),
            createdAt: now
        )

        try await storage.saveAuthorizationCode(authCode)

        return AuthorizationResponse(
            code: code,
            state: request.state
        )
    }

    /// Validates an authorization request without generating a code
    ///
    /// Use this to validate the request before showing the consent page.
    /// Call `handleAuthorizationRequest` after user approves.
    ///
    /// - Parameter request: Authorization request parameters
    /// - Returns: The validated client for display in consent page
    /// - Throws: `OAuthError` if request is invalid
    public func validateAuthorizationRequest(_ request: AuthorizationRequest) async throws -> RegisteredClient {
        // Validate response type
        guard request.responseType == "code" else {
            throw OAuthError.invalidRequest
        }

        // Validate client
        guard let client = try await storage.getClient(clientId: request.clientId) else {
            throw OAuthError.invalidClient
        }

        // Validate redirect URI
        guard client.redirectUris.contains(request.redirectUri) else {
            throw OAuthError.invalidRequest
        }

        // Validate scope if provided
        if let scope = request.scope {
            let validScopes = Set(["mcp:tools", "mcp:resources", "mcp:prompts"])
            let requestedScopes = Set(scope.split(separator: " ").map(String.init))
            guard requestedScopes.isSubset(of: validScopes) else {
                throw OAuthError.invalidScope
            }
        }

        return client
    }

    /// Gets a registered client by ID
    ///
    /// - Parameter clientId: The client ID to look up
    /// - Returns: The client if found, nil otherwise
    public func getClient(clientId: String) async throws -> RegisteredClient? {
        return try await storage.getClient(clientId: clientId)
    }

    // MARK: - CSRF Token Operations

    /// Generates a CSRF token for consent page protection
    ///
    /// - Parameters:
    ///   - clientId: Client requesting authorization
    ///   - redirectUri: Redirect URI from authorization request
    /// - Returns: The generated CSRF token
    public func generateCSRFToken(clientId: String, redirectUri: String) async throws -> String {
        return try await storage.generateCSRFToken(clientId: clientId, redirectUri: redirectUri)
    }

    /// Validates and consumes a CSRF token
    ///
    /// - Parameters:
    ///   - token: The CSRF token to validate
    ///   - clientId: Expected client ID
    ///   - redirectUri: Expected redirect URI
    /// - Returns: Validation result
    public func validateCSRFToken(token: String, clientId: String, redirectUri: String) async throws -> CSRFValidationResult {
        return try await storage.validateCSRFToken(token: token, clientId: clientId, redirectUri: redirectUri)
    }

    // MARK: - Token Endpoint

    /// Handles a token request
    ///
    /// - Parameter request: Token request parameters
    /// - Returns: Token response with access and refresh tokens
    /// - Throws: `OAuthError` if request is invalid
    public func handleTokenRequest(_ request: TokenRequest) async throws -> TokenResponse {
        switch request.grantType {
        case "authorization_code":
            return try await handleAuthorizationCodeGrant(request)
        case "refresh_token":
            return try await handleRefreshTokenGrant(request)
        default:
            throw OAuthError.unsupportedGrantType
        }
    }

    private func handleAuthorizationCodeGrant(_ request: TokenRequest) async throws -> TokenResponse {
        guard let code = request.code else {
            throw OAuthError.invalidRequest
        }

        // Consume the authorization code (single-use)
        guard let authCode = try await storage.consumeAuthorizationCode(code: code) else {
            throw OAuthError.invalidGrant
        }

        // Check expiration
        guard !authCode.isExpired else {
            throw OAuthError.invalidGrant
        }

        // Validate client
        guard authCode.clientId == request.clientId else {
            throw OAuthError.invalidClient
        }

        // Validate redirect URI
        guard authCode.redirectUri == request.redirectUri else {
            throw OAuthError.invalidRequest
        }

        // Validate PKCE if code challenge was provided
        if let codeChallenge = authCode.codeChallenge {
            guard let verifier = request.codeVerifier else {
                throw OAuthError.invalidRequest
            }

            let method: PKCE.ChallengeMethod = authCode.codeChallengeMethod == "plain" ? .plain : .s256

            do {
                let valid = try PKCE.verifyCodeChallenge(
                    verifier: verifier,
                    challenge: codeChallenge,
                    method: method
                )
                guard valid else {
                    throw OAuthError.invalidGrant
                }
            } catch {
                throw OAuthError.invalidGrant
            }
        }

        // Get client to check grant types
        guard let client = try await storage.getClient(clientId: request.clientId) else {
            throw OAuthError.invalidClient
        }

        // Generate tokens
        let accessToken = TokenGenerator.generateAccessToken()
        let refreshToken: String?

        if client.grantTypes.contains("refresh_token") {
            refreshToken = TokenGenerator.generateRefreshToken()
        } else {
            refreshToken = nil
        }

        let now = Date()

        // Store tokens
        try await storage.saveAccessToken(
            token: accessToken,
            clientId: request.clientId,
            scope: authCode.scope,
            expiresAt: now.addingTimeInterval(accessTokenLifetime)
        )

        if let rt = refreshToken {
            try await storage.saveRefreshToken(
                token: rt,
                clientId: request.clientId,
                scope: authCode.scope,
                expiresAt: now.addingTimeInterval(refreshTokenLifetime)
            )
        }

        return TokenResponse(
            accessToken: accessToken,
            tokenType: "Bearer",
            expiresIn: Int(accessTokenLifetime),
            refreshToken: refreshToken,
            scope: authCode.scope
        )
    }

    private func handleRefreshTokenGrant(_ request: TokenRequest) async throws -> TokenResponse {
        // First check if client exists and can use refresh_token grant
        guard let client = try await storage.getClient(clientId: request.clientId) else {
            throw OAuthError.invalidClient
        }

        guard client.grantTypes.contains("refresh_token") else {
            throw OAuthError.unauthorizedClient
        }

        guard let refreshToken = request.refreshToken else {
            throw OAuthError.invalidRequest
        }

        // Validate refresh token
        guard let tokenInfo = try await storage.getRefreshTokenInfo(token: refreshToken) else {
            throw OAuthError.invalidGrant
        }

        guard tokenInfo.clientId == request.clientId else {
            throw OAuthError.invalidGrant
        }

        // Generate new access token
        let newAccessToken = TokenGenerator.generateAccessToken()
        let now = Date()

        try await storage.saveAccessToken(
            token: newAccessToken,
            clientId: request.clientId,
            scope: tokenInfo.scope,
            expiresAt: now.addingTimeInterval(accessTokenLifetime)
        )

        // Optionally rotate refresh token (we'll keep the same one for simplicity)
        return TokenResponse(
            accessToken: newAccessToken,
            tokenType: "Bearer",
            expiresIn: Int(accessTokenLifetime),
            refreshToken: refreshToken, // Return same refresh token
            scope: tokenInfo.scope
        )
    }

    // MARK: - Token Validation

    /// Validates an access token
    ///
    /// - Parameter token: The access token to validate
    /// - Returns: Validation result with client and scope info
    public func validateAccessToken(_ token: String) async throws -> TokenValidationResult {
        try await storage.validateAccessToken(token: token)
    }

    // MARK: - Token Revocation

    /// Revokes an access token
    ///
    /// - Parameter token: The token to revoke
    public func revokeToken(_ token: String) async throws {
        try await storage.revokeAccessToken(token: token)
    }

    // MARK: - Client Authentication

    /// Authenticates a client using various methods
    ///
    /// - Parameters:
    ///   - clientId: The client ID
    ///   - authHeader: Optional Authorization header value
    ///   - bodyClientSecret: Optional client_secret from request body
    /// - Returns: `true` if authentication succeeds
    public func authenticateClient(
        clientId: String,
        authHeader: String?,
        bodyClientSecret: String?
    ) async throws -> Bool {
        guard let client = try await storage.getClient(clientId: clientId) else {
            return false
        }

        switch client.tokenEndpointAuthMethod {
        case "none":
            // Public client - no authentication required
            return true

        case "client_secret_basic":
            // HTTP Basic authentication
            guard let header = authHeader,
                  header.hasPrefix("Basic ") else {
                return false
            }

            let base64 = String(header.dropFirst(6))
            guard let data = Data(base64Encoded: base64),
                  let credentials = String(data: data, encoding: .utf8) else {
                return false
            }

            let parts = credentials.split(separator: ":", maxSplits: 1)
            guard parts.count == 2,
                  String(parts[0]) == clientId,
                  let secret = client.clientSecret else {
                return false
            }

            return TokenGenerator.timingSafeCompare(String(parts[1]), secret)

        case "client_secret_post":
            // Client secret in request body
            guard let providedSecret = bodyClientSecret,
                  let storedSecret = client.clientSecret else {
                return false
            }

            return TokenGenerator.timingSafeCompare(providedSecret, storedSecret)

        default:
            return false
        }
    }
}

// MARK: - Server Metadata

/// OAuth 2.0 Authorization Server Metadata per RFC 8414
public struct ServerMetadata: Codable, Sendable {
    public let issuer: String
    public let authorizationEndpoint: String
    public let tokenEndpoint: String
    public let registrationEndpoint: String?
    public let responseTypesSupported: [String]
    public let grantTypesSupported: [String]
    public let codeChallengeMethodsSupported: [String]
    public let tokenEndpointAuthMethodsSupported: [String]
    public let scopesSupported: [String]?

    private enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case registrationEndpoint = "registration_endpoint"
        case responseTypesSupported = "response_types_supported"
        case grantTypesSupported = "grant_types_supported"
        case codeChallengeMethodsSupported = "code_challenge_methods_supported"
        case tokenEndpointAuthMethodsSupported = "token_endpoint_auth_methods_supported"
        case scopesSupported = "scopes_supported"
    }
}

// MARK: - Client Registration Response

/// Response from dynamic client registration
public struct ClientRegistrationResponse: Codable, Sendable {
    public let clientId: String
    public let clientSecret: String?
    public let clientName: String
    public let redirectUris: [String]
    public let grantTypes: [String]
    public let tokenEndpointAuthMethod: String

    private enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case clientSecret = "client_secret"
        case clientName = "client_name"
        case redirectUris = "redirect_uris"
        case grantTypes = "grant_types"
        case tokenEndpointAuthMethod = "token_endpoint_auth_method"
    }
}

// MARK: - Authorization Request

/// OAuth 2.0 authorization request parameters
public struct AuthorizationRequest: Sendable {
    public let responseType: String
    public let clientId: String
    public let redirectUri: String
    public let scope: String?
    public let state: String?
    public let codeChallenge: String?
    public let codeChallengeMethod: String?

    public init(
        responseType: String,
        clientId: String,
        redirectUri: String,
        scope: String?,
        state: String?,
        codeChallenge: String?,
        codeChallengeMethod: String?
    ) {
        self.responseType = responseType
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.scope = scope
        self.state = state
        self.codeChallenge = codeChallenge
        self.codeChallengeMethod = codeChallengeMethod
    }
}

// MARK: - Authorization Response

/// OAuth 2.0 authorization response
public struct AuthorizationResponse: Sendable {
    public let code: String
    public let state: String?

    public init(code: String, state: String?) {
        self.code = code
        self.state = state
    }
}

// MARK: - Token Request

/// OAuth 2.0 token request parameters
public struct TokenRequest: Sendable {
    public let grantType: String
    public let code: String?
    public let redirectUri: String?
    public let clientId: String
    public let clientSecret: String?
    public let codeVerifier: String?
    public let refreshToken: String?

    public init(
        grantType: String,
        code: String?,
        redirectUri: String?,
        clientId: String,
        clientSecret: String?,
        codeVerifier: String?,
        refreshToken: String?
    ) {
        self.grantType = grantType
        self.code = code
        self.redirectUri = redirectUri
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.codeVerifier = codeVerifier
        self.refreshToken = refreshToken
    }
}
