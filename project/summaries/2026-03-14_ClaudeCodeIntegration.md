# Session Summary: Claude Code Integration

| Date | Phase | Status |
| :--- | :--- | :--- |
| 2026-03-14 | API Key Implementation | SHIPPED |
| 2026-03-15 | SSE Transport Debug Session | SHIPPED |

## 1. Core Objective

Enable Claude Code integration with BusinessMathMCP server via MCP SSE transport. Claude Code's `mcp add --transport sse` requires static Bearer token authentication.

**Final Solution:** API key management + comprehensive SSE transport fixes including synthetic response handling for MCP SDK limitations.

## 2. What Was Built

### API Key System (2026-03-14)
- `APIKey` model with `bm_` prefix format (35 chars)
- `APIKeyStore` actor for persistent storage (`~/.businessmath-mcp/api-keys.json`)
- CLI commands: `--generate-key`, `--list-keys`, `--revoke-key`, `--help`
- Auto-loading of keys on server startup
- Integration with `APIKeyAuthenticator`

### SSE Transport Fixes (2026-03-15)
- Initial endpoint event per MCP SSE spec
- Session ID extraction from URL query params
- HTTP keep-alive handling for connection reuse
- **Synthetic response for "already initialized" error** (critical fix)

## 3. Current Deployment State

### Server (Ubuntu 10.0.1.114)
```
Status: RUNNING
Port: 8080
API Key: bm_ZSOKlBNtFOx_1Utphiinm-Hk15uitr0t
Tools: 185 available
Log: /tmp/mcp-server.log
```

**To restart server:**
```bash
ssh jpurnell@10.0.1.114
source ~/.profile
cd /home/jpurnell/Documents/development/swift/businessMathMCP
killall businessmath-mcp-server 2>/dev/null
MCP_API_KEYS=bm_ZSOKlBNtFOx_1Utphiinm-Hk15uitr0t nohup .build/release/businessmath-mcp-server --http 8080 > /tmp/mcp-server.log 2>&1 &
```

### Client Configuration
```bash
# Add to user config (available in all sessions)
claude mcp add --transport sse businessmath http://10.0.1.114:8080/mcp/sse \
  --header "Authorization: Bearer bm_ZSOKlBNtFOx_1Utphiinm-Hk15uitr0t" -s user
```

## 4. Bugs Fixed (Chronological)

### Bug 1: Malformed OAuth metadata (commit 17178c0)
- **Symptom:** Claude Code error about invalid OAuth metadata
- **Cause:** Server returned malformed JSON when OAuth disabled
- **Fix:** Return 404 instead, letting clients fall back to Bearer auth

### Bug 2: API key blocked by OAuth (commit a28ed4a)
- **Symptom:** "Unauthorized" even with valid API key when OAuth enabled
- **Cause:** OAuth validation tried first; if Bearer token failed OAuth, API key never tried
- **Fix:** Try API key authentication before OAuth

### Bug 3: SSE missing endpoint event (commit b2fc38c)
- **Symptom:** SSE connection returns 0 bytes
- **Cause:** MCP SSE transport requires initial `endpoint` event with POST URL
- **Fix:** Send `endpoint` event in `processSSEConnection`

### Bug 4: Session ID not parsed from URL (commit a697809)
- **Symptom:** "No session found for request" after POST
- **Cause:** Endpoint event sends `/mcp?sessionId=XXX` but server only checked `X-Session-ID` header
- **Fix:** Added `extractSessionIdFromQuery()` to parse URL params

### Bug 5: Channel reuse after HTTP close (commit d618a18, reverted)
- **Symptom:** First connection works, subsequent fail with channel errors
- **Cause:** POST responses used `Connection: close` and `context.close()`, corrupting channel state for reuse
- **Fix:** Use `Connection: keep-alive` for regular responses, don't close context

### Bug 6: MCP SDK "already initialized" error (commit 675db1f) - ROOT CAUSE
- **Symptom:** First `claude mcp list` succeeds, all subsequent fail
- **Cause:** MCP SDK's `Server` class has `isInitialized` flag that throws error on re-initialization
- **Fix:** Intercept error in `HTTPServerTransport.send()` and return synthetic success response

## 5. Debugging Methodology That Worked

### 1. Add Channel ID Tracking
```swift
let channelId = ObjectIdentifier(channel).hashValue
logger.info("Request on channel: \(String(format: "%08x", channelId))")
```
This revealed that channels were being reused after being closed.

### 2. Log Response Content
```swift
let responseStr = String(data: data, encoding: .utf8) ?? "binary"
logger.info("Response: \(responseStr.prefix(200))")
```
This revealed the "Server is already initialized" error from MCP SDK.

### 3. Test Locally First
Running server on localhost isolated network issues from code issues.

### 4. Compare First vs Subsequent Connections
The pattern "first works, rest fail" pointed to shared state corruption.

## 6. Key Technical Lessons

### MCP SSE Transport Requirements
1. Server must send `endpoint` event immediately after SSE connection
2. Event format: `event: endpoint\ndata: /mcp?sessionId=XXX\n\n`
3. Client POSTs to the URL specified in endpoint event
4. Session ID comes via URL query param, not header

### SwiftNIO HTTP Connection Handling
- Don't call `context.close()` after sending responses if you want connection reuse
- Use `Connection: keep-alive` header for non-SSE responses
- SSE connections need `Connection: keep-alive` and never send `.end` part

### MCP SDK Limitations
- `Server` class is stateful - maintains `isInitialized` flag
- Cannot handle multiple initialize requests from different connections
- Workaround: Intercept error and return synthetic success response

### The Synthetic Response Pattern
```swift
if responseStr.contains("Server is already initialized") {
    let successResponse = [
        "jsonrpc": "2.0",
        "id": extractedId,
        "result": [/* cached capabilities */]
    ]
    // Route synthetic response instead of error
}
```

## 7. Files Modified

### Core Transport
- `Sources/BusinessMathMCP/MCPServerHandler.swift` - SSE handling, channel management
- `Sources/BusinessMathMCP/HTTPServerTransport.swift` - Response routing, synthetic responses
- `Sources/BusinessMathMCP/SSESession.swift` - Event sending
- `Sources/BusinessMathMCP/NIOHTTPConnection.swift` - Data sending

### API Key System
- `Sources/BusinessMathMCP/APIKeyStore.swift` (new)
- `Sources/BusinessMathMCP/APIKeyAuthenticator.swift`
- `Sources/BusinessMathMCPServer/main.swift`

## 8. Git State

```
Branch: main
Last Commit: 675db1f "Fix MCP SSE transport for repeated connections"
Pushed: Yes
```

**All Commits:**
- 17178c0 - Fix malformed OAuth metadata response
- a28ed4a - Fix API key auth when OAuth is enabled
- b2fc38c - Add SSE endpoint event per MCP spec
- a697809 - Fix session ID extraction from URL query params
- d618a18 - Use full URL in SSE endpoint event (later refined)
- 675db1f - Fix MCP SSE transport for repeated connections (final fix)

## 9. Verification

```bash
# Multiple health checks should all succeed
for i in 1 2 3 4 5; do
  claude mcp list 2>&1 | grep businessmath
  sleep 1
done
# Expected: All show "✓ Connected"

# Tool call test
curl -s -X POST http://10.0.1.114:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer bm_ZSOKlBNtFOx_1Utphiinm-Hk15uitr0t" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"calculate_npv","arguments":{"rate":0.1,"cashFlows":[-1000,300,400,500,600]}},"id":1}'
# Expected: NPV = $388.77
```

## 10. Context Recovery Checklist

For a new session debugging MCP issues:
1. Read this file first
2. Check server logs: `ssh jpurnell@10.0.1.114 "tail -50 /tmp/mcp-server.log"`
3. Test locally first to isolate network vs code issues
4. Add channel ID tracking if connection issues suspected
5. Log response content if protocol issues suspected

## 11. Key Technical Details (Don't Forget)

- **APIKeyStore is an actor** - thread-safe, don't refactor to struct
- **MCP SDK Server is stateful** - isInitialized flag prevents re-init
- **SSE needs keep-alive** - don't close channel after endpoint event
- **Session ID in URL** - parse from query params, not just headers
- **Swift path on Ubuntu:** `~/.local/share/swiftly/bin/swift`

---

**Session Duration:** ~3 hours (2026-03-14) + ~4 hours debug session (2026-03-15)
**AI Model Used:** Claude Opus 4.5
**Total Commits:** 6
**Root Cause:** MCP SDK stateful Server class + NIO channel reuse
