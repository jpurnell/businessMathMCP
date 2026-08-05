# Design Proposal: OAuth 2.0 Authentication for MCP HTTP Transport

**Status:** SHIPPED
**Date:** 2026-03-14
**Author:** Claude (with user direction)
**Approved:** 2026-03-14
**Completed:** 2026-03-14

---

## Summary

OAuth 2.0 authentication infrastructure for MCP HTTP transport. Implements RFC 6749, RFC 7591 (Dynamic Client Registration), RFC 7636 (PKCE), and RFC 8414 (Authorization Server Metadata).

### Files Created

```
Sources/BusinessMathMCP/OAuth/
├── OAuthServer.swift          # Main OAuth coordinator (actor)
├── OAuthModels.swift          # Token, Client, AuthCode models
├── OAuthStorage.swift         # File-based persistence
├── OAuthHTTPHandler.swift     # HTTP endpoint handlers
├── TokenGenerator.swift       # Secure token generation
└── PKCE.swift                 # Proof Key for Code Exchange

Tests/BusinessMathMCPTests/
├── OAuthServerTests.swift
├── OAuthStorageTests.swift
├── OAuthModelsTests.swift
├── OAuthHTTPHandlerTests.swift
└── OAuthIntegrationTests.swift
```

### HTTP Endpoints Implemented

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/.well-known/oauth-authorization-server` | GET | Server metadata (RFC 8414) |
| `/register` | POST | Dynamic client registration |
| `/authorize` | GET | Authorization endpoint |
| `/token` | POST | Token endpoint |

### Scopes Supported

- `mcp:tools` - Access to MCP tools
- `mcp:resources` - Access to MCP resources
- `mcp:prompts` - Access to MCP prompts

---

## Implementation Notes

### Storage Decision

Used file-based JSON storage (`~/.businessmath-mcp/oauth.db` equivalent) instead of SQLite to minimize dependencies. Storage is actor-isolated for thread safety.

### Security Features

- PKCE support (S256 and plain methods)
- Token hashing with SHA-256
- Timing-safe token comparison
- Configurable token TTL

### Integration with API Keys

OAuth tokens work alongside API key authentication. The authenticator tries API keys first (for Claude Code compatibility), then falls back to OAuth token validation.

---

## Related Documents

- Session Summary: `project/summaries/2026-03-14_ClaudeCodeIntegration.md`
- API Key Integration: `COMPLETED/2026-03-14_ClaudeCodeIntegration.md`

---

## Future Enhancements (Deferred)

- OAuth consent UI for web clients (see `CURRENT_DeveloperExperience.md`)
- Token introspection endpoint
- Token revocation endpoint
- Admin interface

---

**Archived:** 2026-03-15
