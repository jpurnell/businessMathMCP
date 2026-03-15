import Testing
import Foundation
@testable import BusinessMathMCP

/// Integration tests for OAuth 2.0 with HTTP Server
@Suite("OAuth Integration")
struct OAuthIntegrationTests {

    // MARK: - Test Helpers

    static func makeOAuthServer() async throws -> OAuthServer {
        let storage = try OAuthStorage(path: ":memory:")
        return await OAuthServer(storage: storage, issuer: "http://localhost:8080")
    }

    // MARK: - HTTPServerTransport OAuth Configuration

    @Suite("Transport Configuration")
    struct TransportConfigurationTests {

        @Test("Transport accepts OAuth server parameter")
        func transportAcceptsOAuthServer() async throws {
            let oauthServer = try await OAuthIntegrationTests.makeOAuthServer()

            // This should compile and not throw
            let transport = HTTPServerTransport(
                port: 0,  // Use any available port
                authenticator: nil,
                oauthServer: oauthServer
            )

            // Verify transport was created
            #expect(transport != nil)
        }

        @Test("Transport works without OAuth server")
        func transportWorksWithoutOAuth() async throws {
            // This should work exactly as before
            let transport = HTTPServerTransport(port: 0)
            #expect(transport != nil)
        }
    }

    // MARK: - OAuth Endpoint Flow Tests

    @Suite("OAuth Flow")
    struct OAuthFlowTests {

        @Test("Complete authorization code flow")
        func completeAuthorizationCodeFlow() async throws {
            // Create OAuth server and handler
            let storage = try OAuthStorage(path: ":memory:")
            let server = await OAuthServer(storage: storage, issuer: "http://localhost:8080")
            let handler = OAuthHTTPHandler(server: server)

            // Step 1: Register a client
            let registrationBody = """
            {
                "client_name": "Integration Test Client",
                "redirect_uris": ["http://localhost/callback"],
                "grant_types": ["authorization_code", "refresh_token"],
                "token_endpoint_auth_method": "client_secret_post"
            }
            """

            let regResponse = await handler.handleRegistrationRequest(body: registrationBody)
            #expect(regResponse.statusCode == 201)

            // Parse client credentials
            let regData = regResponse.body.data(using: .utf8)!
            let client = try JSONDecoder().decode(ClientRegistrationResponse.self, from: regData)
            #expect(client.clientId.count > 0)
            #expect(client.clientSecret != nil)

            // Step 2: Get authorization code with PKCE
            let verifier = PKCE.generateCodeVerifier()
            let challenge = try PKCE.generateCodeChallenge(verifier: verifier, method: .s256)

            let authParams: [String: String] = [
                "response_type": "code",
                "client_id": client.clientId,
                "redirect_uri": "http://localhost/callback",
                "code_challenge": challenge,
                "code_challenge_method": "S256",
                "scope": "mcp:tools"
            ]

            let authResponse = await handler.handleAuthorizationRequest(queryParams: authParams)
            #expect(authResponse.statusCode == 302)

            // Extract code from redirect
            let location = authResponse.headers["Location"]!
            let code = extractCode(from: location)
            #expect(code != nil)

            // Step 3: Exchange code for tokens
            let tokenBody = buildFormBody([
                "grant_type": "authorization_code",
                "code": code!,
                "redirect_uri": "http://localhost/callback",
                "client_id": client.clientId,
                "client_secret": client.clientSecret!,
                "code_verifier": verifier
            ])

            let tokenResponse = await handler.handleTokenRequest(body: tokenBody, authHeader: nil)
            #expect(tokenResponse.statusCode == 200)

            let tokenData = tokenResponse.body.data(using: .utf8)!
            let tokens = try JSONDecoder().decode(TokenResponse.self, from: tokenData)
            #expect(tokens.accessToken.count > 0)
            #expect(tokens.refreshToken != nil)
            #expect(tokens.tokenType == "Bearer")

            // Step 4: Validate the token
            let validationResult = await handler.validateBearerToken(authHeader: "Bearer \(tokens.accessToken)")
            #expect(validationResult.isValid)

            if case .valid(let validatedClientId, let scope) = validationResult {
                #expect(validatedClientId == client.clientId)
                #expect(scope == "mcp:tools")
            }

            // Step 5: Refresh the token
            let refreshBody = buildFormBody([
                "grant_type": "refresh_token",
                "refresh_token": tokens.refreshToken!,
                "client_id": client.clientId,
                "client_secret": client.clientSecret!
            ])

            let refreshResponse = await handler.handleTokenRequest(body: refreshBody, authHeader: nil)
            #expect(refreshResponse.statusCode == 200)

            let refreshData = refreshResponse.body.data(using: .utf8)!
            let newTokens = try JSONDecoder().decode(TokenResponse.self, from: refreshData)
            #expect(newTokens.accessToken.count > 0)
            #expect(newTokens.accessToken != tokens.accessToken)  // Should be a new token

            // Verify new token works
            let newValidation = await handler.validateBearerToken(authHeader: "Bearer \(newTokens.accessToken)")
            #expect(newValidation.isValid)
        }

        @Test("Public client flow without secret")
        func publicClientFlow() async throws {
            let storage = try OAuthStorage(path: ":memory:")
            let server = await OAuthServer(storage: storage, issuer: "http://localhost:8080")
            let handler = OAuthHTTPHandler(server: server)

            // Register a public client (no secret)
            let registrationBody = """
            {
                "client_name": "Public Client",
                "redirect_uris": ["http://localhost/callback"],
                "token_endpoint_auth_method": "none"
            }
            """

            let regResponse = await handler.handleRegistrationRequest(body: registrationBody)
            #expect(regResponse.statusCode == 201)

            let regData = regResponse.body.data(using: .utf8)!
            let client = try JSONDecoder().decode(ClientRegistrationResponse.self, from: regData)
            #expect(client.clientSecret == nil)  // No secret for public client

            // Get authorization code with PKCE (required for public clients)
            let verifier = PKCE.generateCodeVerifier()
            let challenge = try PKCE.generateCodeChallenge(verifier: verifier, method: .s256)

            let authParams: [String: String] = [
                "response_type": "code",
                "client_id": client.clientId,
                "redirect_uri": "http://localhost/callback",
                "code_challenge": challenge,
                "code_challenge_method": "S256"
            ]

            let authResponse = await handler.handleAuthorizationRequest(queryParams: authParams)
            #expect(authResponse.statusCode == 302)

            let code = extractCode(from: authResponse.headers["Location"]!)!

            // Exchange code for tokens (no client_secret needed)
            let tokenBody = buildFormBody([
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": "http://localhost/callback",
                "client_id": client.clientId,
                "code_verifier": verifier
            ])

            let tokenResponse = await handler.handleTokenRequest(body: tokenBody, authHeader: nil)
            #expect(tokenResponse.statusCode == 200)

            let tokens = try JSONDecoder().decode(TokenResponse.self, from: tokenResponse.body.data(using: .utf8)!)
            #expect(tokens.accessToken.count > 0)
        }
    }

    // MARK: - MCP Scope Tests

    @Suite("MCP Scopes")
    struct MCPScopeTests {

        @Test("Supports mcp:tools scope")
        func supportsMcpToolsScope() async throws {
            let storage = try OAuthStorage(path: ":memory:")
            let server = await OAuthServer(storage: storage, issuer: "http://localhost:8080")
            let handler = OAuthHTTPHandler(server: server)

            // Register client and get token with scope
            let client = try await registerTestClient(handler: handler)
            let tokens = try await getTokensWithScope(
                handler: handler,
                client: client,
                scope: "mcp:tools"
            )

            let result = await handler.validateBearerToken(authHeader: "Bearer \(tokens.accessToken)")
            if case .valid(_, let scope) = result {
                #expect(scope == "mcp:tools")
            }
        }

        @Test("Supports multiple MCP scopes")
        func supportsMultipleMcpScopes() async throws {
            let storage = try OAuthStorage(path: ":memory:")
            let server = await OAuthServer(storage: storage, issuer: "http://localhost:8080")
            let handler = OAuthHTTPHandler(server: server)

            let client = try await registerTestClient(handler: handler)
            let tokens = try await getTokensWithScope(
                handler: handler,
                client: client,
                scope: "mcp:tools mcp:resources"
            )

            let result = await handler.validateBearerToken(authHeader: "Bearer \(tokens.accessToken)")
            if case .valid(_, let scope) = result {
                #expect(scope?.contains("mcp:tools") == true)
                #expect(scope?.contains("mcp:resources") == true)
            }
        }
    }

    // MARK: - Metadata Tests

    @Suite("Server Metadata")
    struct ServerMetadataTests {

        @Test("Metadata includes MCP scopes")
        func metadataIncludesMcpScopes() async throws {
            let storage = try OAuthStorage(path: ":memory:")
            let server = await OAuthServer(storage: storage, issuer: "http://localhost:8080")
            let handler = OAuthHTTPHandler(server: server)

            let response = await handler.handleMetadataRequest()
            #expect(response.statusCode == 200)

            let data = response.body.data(using: .utf8)!
            let metadata = try JSONDecoder().decode(ServerMetadata.self, from: data)

            #expect(metadata.scopesSupported?.contains("mcp:tools") == true)
            #expect(metadata.scopesSupported?.contains("mcp:resources") == true)
            #expect(metadata.scopesSupported?.contains("mcp:prompts") == true)
        }

        @Test("Metadata includes PKCE support")
        func metadataIncludesPkceSupport() async throws {
            let storage = try OAuthStorage(path: ":memory:")
            let server = await OAuthServer(storage: storage, issuer: "http://localhost:8080")
            let handler = OAuthHTTPHandler(server: server)

            let response = await handler.handleMetadataRequest()
            let data = response.body.data(using: .utf8)!
            let metadata = try JSONDecoder().decode(ServerMetadata.self, from: data)

            #expect(metadata.codeChallengeMethodsSupported.contains("S256"))
        }
    }

    // MARK: - Helpers

    static func extractCode(from location: String) -> String? {
        guard let components = URLComponents(string: location),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return nil
        }
        return code
    }

    static func buildFormBody(_ params: [String: String]) -> String {
        params.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
    }

    static func registerTestClient(handler: OAuthHTTPHandler) async throws -> ClientRegistrationResponse {
        let body = """
        {
            "client_name": "Test Client",
            "redirect_uris": ["http://localhost/callback"],
            "grant_types": ["authorization_code", "refresh_token"],
            "token_endpoint_auth_method": "client_secret_post"
        }
        """
        let response = await handler.handleRegistrationRequest(body: body)
        let data = response.body.data(using: .utf8)!
        return try JSONDecoder().decode(ClientRegistrationResponse.self, from: data)
    }

    static func getTokensWithScope(handler: OAuthHTTPHandler, client: ClientRegistrationResponse, scope: String) async throws -> TokenResponse {
        let verifier = PKCE.generateCodeVerifier()
        let challenge = try PKCE.generateCodeChallenge(verifier: verifier, method: .s256)

        let authParams: [String: String] = [
            "response_type": "code",
            "client_id": client.clientId,
            "redirect_uri": "http://localhost/callback",
            "code_challenge": challenge,
            "code_challenge_method": "S256",
            "scope": scope
        ]

        let authResponse = await handler.handleAuthorizationRequest(queryParams: authParams)
        let code = extractCode(from: authResponse.headers["Location"]!)!

        let tokenBody = buildFormBody([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": "http://localhost/callback",
            "client_id": client.clientId,
            "client_secret": client.clientSecret!,
            "code_verifier": verifier
        ])

        let tokenResponse = await handler.handleTokenRequest(body: tokenBody, authHeader: nil)
        let data = tokenResponse.body.data(using: .utf8)!
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
}

// Make helpers accessible to nested types
private func extractCode(from location: String) -> String? {
    OAuthIntegrationTests.extractCode(from: location)
}

private func buildFormBody(_ params: [String: String]) -> String {
    OAuthIntegrationTests.buildFormBody(params)
}

private func registerTestClient(handler: OAuthHTTPHandler) async throws -> ClientRegistrationResponse {
    try await OAuthIntegrationTests.registerTestClient(handler: handler)
}

private func getTokensWithScope(handler: OAuthHTTPHandler, client: ClientRegistrationResponse, scope: String) async throws -> TokenResponse {
    try await OAuthIntegrationTests.getTokensWithScope(handler: handler, client: client, scope: scope)
}
