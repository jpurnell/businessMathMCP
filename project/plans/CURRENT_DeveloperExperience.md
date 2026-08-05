# Design Proposal: Developer Experience Improvements

| Feature | Priority | Complexity | Status |
| :--- | :--- | :--- | :--- |
| Verbose Debug Logging | High | Low | PROPOSED |
| MCP SSE Integration Tests | Medium | Medium | PROPOSED |
| OAuth Consent UI for Web Clients | Low | Medium | PROPOSED |

**Date:** 2026-03-15
**Author:** Claude Code Session
**Reference:** Previous debug session revealed need for better debugging tools and test coverage

---

## Feature 1: Verbose Debug Logging Mode

### 1. Objective

Add runtime-configurable verbose logging to aid troubleshooting of MCP connections, SSE transport, and authentication flows. The recent 4-hour debug session could have been resolved faster with proper logging infrastructure.

**Pain Points Addressed:**
- Channel ID tracking had to be added manually
- Response content logging was ad-hoc
- No way to enable debug output without code changes

### 2. Proposed Architecture

**Modified Files:**
- `Sources/BusinessMathMCPServer/main.swift` - Add `--verbose` / `-v` flag
- `Sources/BusinessMathMCP/LoggingConfiguration.swift` (new) - Centralized log config

**No New Dependencies:** Uses existing swift-log

### 3. API Surface

```swift
// CLI Usage
businessmath-mcp-server --http 8080 --verbose
businessmath-mcp-server --http 8080 -v

// Environment Variable Alternative
LOG_LEVEL=debug businessmath-mcp-server --http 8080

// Programmatic Configuration
public struct LoggingConfiguration: Sendable {
    public static var logLevel: Logger.Level = .info
    public static var includeChannelIds: Bool = false
    public static var includeResponseContent: Bool = false

    public static func configureFromEnvironment()
    public static func configureVerbose()
}
```

### 4. Verbose Output Categories

When verbose mode is enabled:

| Category | Output |
|----------|--------|
| Connections | Channel ID (hex), remote address, connection state |
| SSE | Session creation/destruction, endpoint events sent |
| Authentication | Auth method tried, success/failure (no secrets logged) |
| Requests | Method name, request ID, session ID |
| Responses | Response size, truncated content (first 200 chars) |
| Errors | Full error context with channel/session correlation |

### 5. Constraints & Compliance

- **Thread Safety:** LoggingConfiguration uses static vars with Sendable types only
- **Security:** Never log API keys, tokens, or secrets
- **Performance:** Debug logging should have minimal overhead when disabled
- **No Force Unwraps:** All logging uses safe string interpolation

### 6. Test Strategy

**Test Categories:**
- Unit: LoggingConfiguration correctly parses environment/flags
- Integration: Verbose output appears when enabled, absent when disabled
- Security: Verify secrets are never logged

**Reference Truth:** Manual verification of log output

### 7. Open Questions

- Should we support log levels beyond info/debug (trace, warning, error)?
- Should verbose mode enable HTTP request/response body logging?

---

## Feature 2: MCP SSE Integration Tests

### 1. Objective

Complete the stubbed integration tests in `SSETransportTests.swift` to prevent regression of the bugs fixed during the debug session. Currently 14 of 15 tests are stubs.

**Bugs This Will Prevent:**
- Session ID not parsed from URL (Bug 4)
- Channel reuse after HTTP close (Bug 5)
- MCP SDK "already initialized" error (Bug 6)

### 2. Proposed Architecture

**Modified Files:**
- `Tests/BusinessMathMCPTests/SSETransportTests.swift` - Complete existing stubs
- `Tests/BusinessMathMCPTests/Helpers/MCPTestClient.swift` (new) - Reusable test client

**Test Infrastructure:**
- Uses real HTTP connections to localhost
- Spins up/tears down server per test
- Timeout handling for async operations

### 3. Test Coverage Matrix

| Test Case | Current | Target |
|-----------|---------|--------|
| SSE Connection Establishment | Implemented | Keep |
| Heartbeat Events | Stub | Implement |
| JSON-RPC Response via SSE | Stub | Implement |
| Multiple Concurrent Clients | Stub | Implement |
| Server-Initiated Notifications | Stub | Implement |
| Session Registration/Lookup | Stub | Implement |
| Session Cleanup on Disconnect | Stub | Implement |
| Session Timeout | Stub | Implement |
| Full Request/Response Cycle | Stub | **Critical** |
| Response Routing to Correct Client | Stub | **Critical** |
| Client Disconnect During Processing | Stub | Implement |
| Network Error Handling | Stub | Implement |
| SSE Event Format Validation | Stub | Implement |
| Multi-line Data Handling | Stub | Implement |
| Repeated Initialize Requests | New | **Critical** |

### 4. MCPTestClient Design

```swift
/// Reusable test client for MCP SSE integration tests
actor MCPTestClient {
    let baseURL: URL
    private var sseTask: URLSessionDataTask?
    private var sessionId: String?
    private var receivedEvents: [SSEEvent] = []

    init(port: Int)

    /// Connect to SSE endpoint and capture session ID
    func connect() async throws -> String

    /// Send JSON-RPC request via POST
    func sendRequest(_ method: String, params: [String: Any]?) async throws -> [String: Any]

    /// Wait for SSE event with timeout
    func waitForEvent(timeout: TimeInterval) async throws -> SSEEvent

    /// Disconnect and cleanup
    func disconnect() async
}

struct SSEEvent: Sendable {
    let type: String
    let data: String
    let id: String?
}
```

### 5. Critical Test: Repeated Initialize Requests

This test specifically validates the fix for Bug 6 (MCP SDK "already initialized"):

```swift
@Test("SSE - Multiple initialize requests succeed (synthetic response)")
func testRepeatedInitialize() async throws {
    let transport = HTTPServerTransport(port: 9200)
    try await transport.connect()

    let client1 = MCPTestClient(port: 9200)
    let client2 = MCPTestClient(port: 9200)

    // First client initializes - should succeed
    let session1 = try await client1.connect()
    let init1 = try await client1.sendRequest("initialize", params: [...])
    #expect(init1["result"] != nil)

    // Second client initializes - should also succeed (synthetic response)
    let session2 = try await client2.connect()
    let init2 = try await client2.sendRequest("initialize", params: [...])
    #expect(init2["result"] != nil)

    // Both should be different sessions
    #expect(session1 != session2)

    await client1.disconnect()
    await client2.disconnect()
    await transport.disconnect()
}
```

### 6. Constraints & Compliance

- **Determinism:** All tests use fixed ports and controlled timing
- **Isolation:** Each test spins up its own server instance
- **Cleanup:** Tests always disconnect/shutdown even on failure
- **Timeouts:** All async operations have explicit timeouts

### 7. Test Strategy

**Reference Truth:** The bugs fixed in commits a697809, d618a18, 675db1f serve as the specification. Tests must verify these behaviors remain correct.

---

## Feature 3: OAuth Consent UI for Web Clients

### 1. Objective

Add a minimal HTML consent page for the OAuth `/authorize` endpoint. Currently, authorization requests auto-approve without user interaction, which is insufficient for web browser clients.

**Current State:**
- OAuth infrastructure is 100% complete (OAuthServer, OAuthStorage, OAuthHTTPHandler)
- All unit tests pass
- Missing: User-facing consent UI

### 2. Proposed Architecture

**New Files:**
- `Sources/BusinessMathMCP/OAuth/ConsentPage.swift` - HTML template generator
- `Sources/BusinessMathMCP/OAuth/OAuthTemplates/` (directory) - Optional external templates

**Modified Files:**
- `Sources/BusinessMathMCP/OAuth/OAuthHTTPHandler.swift` - Return consent page instead of auto-redirect
- `Sources/BusinessMathMCP/MCPServerHandler.swift` - Handle consent form POST

### 3. User Flow

```
1. Client redirects to /authorize?response_type=code&client_id=...&redirect_uri=...
2. Server returns HTML consent page showing:
   - Client name (from registration)
   - Requested scopes (mcp:tools, mcp:resources, mcp:prompts)
   - Approve / Deny buttons
3. User clicks Approve → POST /authorize/consent with CSRF token
4. Server validates, generates auth code, redirects to client redirect_uri
5. User clicks Deny → Redirects with error=access_denied
```

### 4. API Surface

```swift
// Consent page generator
public struct ConsentPage: Sendable {
    public static func render(
        clientName: String,
        scopes: [String],
        csrfToken: String,
        authorizeParams: AuthorizationRequest
    ) -> String
}

// New endpoint
// GET /authorize → Returns consent HTML (instead of auto-redirect)
// POST /authorize/consent → Processes user decision

// OAuthHTTPHandler additions
public func handleConsentPage(queryParams: [String: String]) async -> OAuthHTTPResponse
public func handleConsentSubmission(body: String) async -> OAuthHTTPResponse
```

### 5. Consent Page Design

Minimal, secure HTML page:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Authorize Application</title>
    <style>/* Minimal inline CSS */</style>
</head>
<body>
    <h1>Authorize [Client Name]</h1>
    <p>This application is requesting access to:</p>
    <ul>
        <li>Tools: Execute business math calculations</li>
        <li>Resources: Access available resources</li>
        <li>Prompts: Use available prompts</li>
    </ul>
    <form method="POST" action="/authorize/consent">
        <input type="hidden" name="csrf_token" value="...">
        <input type="hidden" name="client_id" value="...">
        <!-- other hidden params -->
        <button type="submit" name="action" value="approve">Approve</button>
        <button type="submit" name="action" value="deny">Deny</button>
    </form>
</body>
</html>
```

### 6. Security Considerations

- **CSRF Protection:** Generate and validate CSRF token per session
- **No External Resources:** All CSS inline, no JavaScript required
- **Input Validation:** All form parameters validated server-side
- **Timeout:** Consent page expires after 10 minutes
- **Rate Limiting:** Limit consent submissions per IP

### 7. Constraints & Compliance

- **Sendable:** ConsentPage is a static utility, no state
- **No Force Unwraps:** All template rendering uses safe string building
- **Accessibility:** Basic semantic HTML with proper labels

### 8. Test Strategy

**Test Categories:**
- Unit: ConsentPage renders correct HTML for various inputs
- Unit: CSRF token generation and validation
- Integration: Full consent flow (GET → render → POST → redirect)
- Security: CSRF rejection, timeout handling, invalid params

**Reference Truth:** OAuth 2.0 RFC 6749 Section 4.1.1 (Authorization Request)

### 9. Dependencies

**Internal Dependencies:**
- `OAuthServer` - Client lookup, authorization code generation
- `OAuthStorage` - CSRF token storage

**External Dependencies:** None

### 10. Open Questions

- Should we support custom branding (logo, colors)?
- Should consent be remembered for returning users?
- Should we add CAPTCHA for abuse prevention?

---

## Implementation Order

| Order | Feature | Rationale |
|-------|---------|-----------|
| 1 | Verbose Debug Logging | Highest immediate value, simplest to implement |
| 2 | MCP SSE Integration Tests | Prevents regression, medium complexity |
| 3 | OAuth Consent UI | Lowest priority (API key auth works), most complex |

---

## Implementation Checklists

Each feature will have its own checklist created when work begins. See:
- `project/checklists/CURRENT_VerboseLogging.md`
- `project/checklists/CURRENT_SSEIntegrationTests.md`
- `project/checklists/CURRENT_OAuthConsentUI.md`

---

## Approval

- [ ] **Feature 1 (Verbose Logging)** - Design approved
- [ ] **Feature 2 (SSE Tests)** - Design approved
- [ ] **Feature 3 (OAuth Consent)** - Design approved

**Approval Notes:**
[To be filled by reviewer]

---

**Last Updated:** 2026-03-15
