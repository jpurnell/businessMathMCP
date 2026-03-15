import Foundation

/// HTTP request/response handler for OAuth 2.0 endpoints
///
/// Handles HTTP parsing and serialization for OAuth endpoints:
/// - `/.well-known/oauth-authorization-server` - Server metadata
/// - `/register` - Client registration
/// - `/authorize` - Authorization endpoint
/// - `/token` - Token endpoint
///
/// This is a stateless handler that delegates to OAuthServer for business logic.
public struct OAuthHTTPHandler: Sendable {

    private let server: OAuthServer

    /// Creates a new OAuth HTTP handler
    ///
    /// - Parameter server: The OAuth server to delegate to
    public init(server: OAuthServer) {
        self.server = server
    }

    // MARK: - Server Metadata

    /// Handles GET /.well-known/oauth-authorization-server
    ///
    /// - Returns: JSON-encoded server metadata
    public func handleMetadataRequest() async -> OAuthHTTPResponse {
        let metadata = await server.getMetadata()

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(metadata)
            let body = String(data: data, encoding: .utf8) ?? "{}"

            return OAuthHTTPResponse(
                statusCode: 200,
                contentType: "application/json",
                body: body
            )
        } catch {
            return errorResponse(.serverError("Failed to encode metadata"))
        }
    }

    // MARK: - Client Registration

    /// Handles POST /register
    ///
    /// - Parameter body: JSON-encoded ClientRegistrationRequest
    /// - Returns: JSON-encoded ClientRegistrationResponse or error
    public func handleRegistrationRequest(body: String) async -> OAuthHTTPResponse {
        guard let data = body.data(using: .utf8) else {
            return errorResponse(.invalidRequest)
        }

        do {
            let request = try JSONDecoder().decode(ClientRegistrationRequest.self, from: data)
            let response = try await server.registerClient(request)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let responseData = try encoder.encode(response)
            let responseBody = String(data: responseData, encoding: .utf8) ?? "{}"

            return OAuthHTTPResponse(
                statusCode: 201,
                contentType: "application/json",
                body: responseBody
            )
        } catch let error as OAuthError {
            return errorResponse(error)
        } catch {
            return errorResponse(.invalidRequest)
        }
    }

    // MARK: - Authorization Endpoint

    /// Handles GET /authorize
    ///
    /// - Parameter queryParams: Query parameters from the URL
    /// - Returns: Redirect response with authorization code or error
    public func handleAuthorizationRequest(queryParams: [String: String]) async -> OAuthHTTPResponse {
        guard let responseType = queryParams["response_type"],
              let clientId = queryParams["client_id"],
              let redirectUri = queryParams["redirect_uri"] else {
            return errorResponse(.invalidRequest)
        }

        let request = AuthorizationRequest(
            responseType: responseType,
            clientId: clientId,
            redirectUri: redirectUri,
            scope: queryParams["scope"],
            state: queryParams["state"],
            codeChallenge: queryParams["code_challenge"],
            codeChallengeMethod: queryParams["code_challenge_method"]
        )

        do {
            let response = try await server.handleAuthorizationRequest(request)

            // Build redirect URL with code
            var redirectComponents = URLComponents(string: redirectUri)
            var queryItems = redirectComponents?.queryItems ?? []
            queryItems.append(URLQueryItem(name: "code", value: response.code))
            if let state = response.state {
                queryItems.append(URLQueryItem(name: "state", value: state))
            }
            redirectComponents?.queryItems = queryItems

            guard let redirectURL = redirectComponents?.string else {
                return errorResponse(.serverError("Failed to build redirect URL"))
            }

            return OAuthHTTPResponse(
                statusCode: 302,
                contentType: "text/html",
                body: "",
                headers: ["Location": redirectURL]
            )
        } catch let error as OAuthError {
            // For authorization errors, redirect with error
            var redirectComponents = URLComponents(string: redirectUri)
            var queryItems = redirectComponents?.queryItems ?? []
            queryItems.append(URLQueryItem(name: "error", value: error.errorCode))
            if let description = error.errorDescription {
                queryItems.append(URLQueryItem(name: "error_description", value: description))
            }
            if let state = queryParams["state"] {
                queryItems.append(URLQueryItem(name: "state", value: state))
            }
            redirectComponents?.queryItems = queryItems

            if let redirectURL = redirectComponents?.string {
                return OAuthHTTPResponse(
                    statusCode: 302,
                    contentType: "text/html",
                    body: "",
                    headers: ["Location": redirectURL]
                )
            }

            return errorResponse(error)
        } catch {
            return errorResponse(.serverError("Unexpected error"))
        }
    }

    // MARK: - Token Endpoint

    /// Handles POST /token
    ///
    /// - Parameters:
    ///   - body: URL-encoded form body
    ///   - authHeader: Optional Authorization header for client auth
    /// - Returns: JSON-encoded TokenResponse or error
    public func handleTokenRequest(body: String, authHeader: String?) async -> OAuthHTTPResponse {
        // Parse URL-encoded form body
        let params = parseFormBody(body)

        guard let grantType = params["grant_type"],
              let clientId = params["client_id"] else {
            return errorResponse(.invalidRequest)
        }

        // Authenticate client
        do {
            let authenticated = try await server.authenticateClient(
                clientId: clientId,
                authHeader: authHeader,
                bodyClientSecret: params["client_secret"]
            )

            guard authenticated else {
                return errorResponse(.invalidClient)
            }

            let request = TokenRequest(
                grantType: grantType,
                code: params["code"],
                redirectUri: params["redirect_uri"],
                clientId: clientId,
                clientSecret: params["client_secret"],
                codeVerifier: params["code_verifier"],
                refreshToken: params["refresh_token"]
            )

            let response = try await server.handleTokenRequest(request)

            let encoder = JSONEncoder()
            let responseData = try encoder.encode(response)
            let responseBody = String(data: responseData, encoding: .utf8) ?? "{}"

            return OAuthHTTPResponse(
                statusCode: 200,
                contentType: "application/json",
                body: responseBody,
                headers: [
                    "Cache-Control": "no-store",
                    "Pragma": "no-cache"
                ]
            )
        } catch let error as OAuthError {
            return errorResponse(error)
        } catch {
            return errorResponse(.serverError("Token request failed"))
        }
    }

    // MARK: - Token Validation

    /// Validates an access token from the Authorization header
    ///
    /// - Parameter authHeader: The Authorization header value
    /// - Returns: Validation result
    public func validateBearerToken(authHeader: String?) async -> TokenValidationResult {
        guard let header = authHeader,
              header.lowercased().hasPrefix("bearer ") else {
            return .invalid(reason: "Missing or invalid Authorization header")
        }

        let token = String(header.dropFirst(7))

        do {
            return try await server.validateAccessToken(token)
        } catch {
            return .invalid(reason: "Token validation failed")
        }
    }

    // MARK: - Helpers

    private func parseFormBody(_ body: String) -> [String: String] {
        var params: [String: String] = [:]

        for pair in body.split(separator: "&") {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2 {
                let key = String(keyValue[0]).removingPercentEncoding ?? String(keyValue[0])
                let value = String(keyValue[1]).removingPercentEncoding ?? String(keyValue[1])
                params[key] = value
            }
        }

        return params
    }

    private func errorResponse(_ error: OAuthError) -> OAuthHTTPResponse {
        let statusCode: Int
        switch error {
        case .invalidClient:
            statusCode = 401
        case .invalidRequest, .invalidScope:
            statusCode = 400
        case .invalidGrant, .unauthorizedClient, .unsupportedGrantType:
            statusCode = 400
        case .serverError:
            statusCode = 500
        }

        let body: [String: String] = [
            "error": error.errorCode,
            "error_description": error.errorDescription ?? ""
        ]

        do {
            let data = try JSONEncoder().encode(body)
            return OAuthHTTPResponse(
                statusCode: statusCode,
                contentType: "application/json",
                body: String(data: data, encoding: .utf8) ?? "{}"
            )
        } catch {
            return OAuthHTTPResponse(
                statusCode: statusCode,
                contentType: "application/json",
                body: "{\"error\": \"\(error)\"}"
            )
        }
    }
}

// MARK: - OAuth HTTP Response

/// HTTP response from OAuth endpoints
public struct OAuthHTTPResponse: Sendable {
    public let statusCode: Int
    public let contentType: String
    public let body: String
    public let headers: [String: String]

    public init(
        statusCode: Int,
        contentType: String,
        body: String,
        headers: [String: String] = [:]
    ) {
        self.statusCode = statusCode
        self.contentType = contentType
        self.body = body
        self.headers = headers
    }
}
