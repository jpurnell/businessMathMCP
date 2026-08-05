# Design Proposal: Claude Code Integration

**Status:** SHIPPED (All Phases Complete)
**Created:** 2024-03-14
**Completed:** 2026-03-14

---

## 1. Objective

**Problem:** Claude Code's `mcp add --transport http` command cannot perform OAuth flows. It only supports static headers:

```bash
claude mcp add --transport http --header "Authorization: Bearer <token>" server http://url
```

**Objective:** Make BusinessMathMCP trivially easy to connect from Claude Code with a single command.

**Success Criteria:**
```bash
# User runs this once on the server:
businessmath-mcp-server --http 8080 --generate-key

# Output: "API Key: bm_xxxxxxxxxxxx"
# User adds to Claude Code:
claude mcp add --transport http -H "Authorization: Bearer bm_xxxxxxxxxxxx" businessmath http://10.0.1.114:8080
```

---

## 2. Proposed Architecture

### New Files:
- None (modifications only)

### Modified Files:
- `Sources/BusinessMathMCPServer/main.swift` - Add `--generate-key` flag
- `Sources/BusinessMathMCP/APIKeyAuthenticator.swift` - Add key generation & persistence

### Key Changes:

1. **Persistent API Key Storage** (`~/.businessmath-mcp/api-keys.json`)
   - Server auto-loads keys on startup
   - Keys persist across restarts
   - No environment variables needed for basic use

2. **Key Generation Command**
   ```bash
   businessmath-mcp-server --generate-key [--name "Claude Code"]
   # Outputs: bm_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   # Saves to ~/.businessmath-mcp/api-keys.json
   ```

3. **Simplified Startup**
   ```bash
   # Before (complex):
   MCP_API_KEYS=key1,key2 MCP_OAUTH_ENABLED=true ./server --http 8080

   # After (simple):
   ./businessmath-mcp-server --http 8080
   # Auto-loads keys from ~/.businessmath-mcp/api-keys.json
   ```

---

## 3. API Surface

### CLI Interface

```bash
# Generate a new API key
businessmath-mcp-server --generate-key [--name <label>]

# List existing keys
businessmath-mcp-server --list-keys

# Revoke a key
businessmath-mcp-server --revoke-key <key-prefix>

# Start server (auto-loads saved keys)
businessmath-mcp-server --http 8080
```

### Key Format

```
bm_<32-character-base64url-encoded-random>
```

Example: `bm_7Kx9mPqR2sT4vW6xY8zA0bC3dE5fG7hJ`

Prefix `bm_` makes keys easily identifiable and greppable.

---

## 4. Storage Format

**File:** `~/.businessmath-mcp/api-keys.json`

```json
{
  "keys": [
    {
      "key": "bm_7Kx9mPqR2sT4vW6xY8zA0bC3dE5fG7hJ",
      "name": "Claude Code MacBook",
      "created": "2024-03-14T22:30:00Z",
      "lastUsed": "2024-03-14T23:45:00Z"
    },
    {
      "key": "bm_aB1cD2eF3gH4iJ5kL6mN7oP8qR9sT0uV",
      "name": "Production Server",
      "created": "2024-03-14T20:00:00Z",
      "lastUsed": null
    }
  ]
}
```

---

## 5. Authentication Priority

When a request arrives, authentication is checked in this order:

1. **Bearer Token** - Check against saved API keys
2. **OAuth Token** - Validate if OAuth is enabled
3. **Environment API Keys** - Check `MCP_API_KEYS` (backwards compatible)
4. **No Auth** - Allow if no auth is configured

---

## 6. Constraints & Compliance

| Constraint | Compliance |
|------------|------------|
| **Concurrency** | Key storage uses actor isolation |
| **Security** | Keys stored with restricted file permissions (0600) |
| **Backwards Compatible** | `MCP_API_KEYS` env var still works |
| **Cross-Platform** | Works on macOS and Linux |
| **No External Dependencies** | Uses Foundation only |

---

## 7. User Experience Flow

### First-Time Setup (Server)

```bash
$ businessmath-mcp-server --generate-key --name "Claude Code"
Generated API key for "Claude Code":

  bm_7Kx9mPqR2sT4vW6xY8zA0bC3dE5fG7hJ

Save this key securely - it cannot be retrieved later.

To use with Claude Code:
  claude mcp add --transport http \
    -H "Authorization: Bearer bm_7Kx9mPqR2sT4vW6xY8zA0bC3dE5fG7hJ" \
    businessmath http://<server-ip>:8080

$ businessmath-mcp-server --http 8080
✓ Loaded 1 API key(s) from ~/.businessmath-mcp/api-keys.json
✓ HTTP server listening on port 8080
```

### First-Time Setup (Client)

```bash
$ claude mcp add --transport http \
    -H "Authorization: Bearer bm_7Kx9mPqR2sT4vW6xY8zA0bC3dE5fG7hJ" \
    businessmath http://10.0.1.114:8080

Added HTTP MCP server businessmath
```

---

## 8. Test Strategy

**Test Categories:**
- Key generation produces valid format
- Key persistence survives restart
- Key revocation removes access
- Multiple keys work simultaneously
- Invalid keys rejected with 401
- Backwards compatibility with `MCP_API_KEYS` env var

**Reference Truth:**
- RFC 6750 Bearer Token Usage
- Existing APIKeyAuthenticator behavior

---

## 9. Open Questions

1. **Key rotation:** Should we support automatic key rotation?
   - *Proposed:* No, keep simple for v1. Users can revoke and regenerate.

2. **Key scopes:** Should keys have different permission levels?
   - *Proposed:* No, all keys have full access for v1.

3. **Rate limiting:** Should we add per-key rate limits?
   - *Proposed:* Defer to future version.

---

## 10. Documentation Strategy

**Documentation Type:** Narrative Article Required

**Complexity Check:**
- Combines CLI + config + runtime ✅
- Requires step-by-step instructions ✅
- Multiple deployment scenarios ✅

**Article Name:** `ClaudeCodeSetupGuide.md`

**Sections:**
1. Quick Start (5-minute setup)
2. Server Configuration
3. Claude Code Configuration
4. Troubleshooting
5. Security Considerations

---

## Implementation Phases

### Phase 1: Core Key Management ✅ COMPLETE
- [x] Add `APIKey` model with prefix validation
- [x] Add `APIKeyStore` actor for persistence
- [x] Add `--generate-key` command
- [x] Add `--list-keys` command
- [x] Auto-load keys on server startup

### Phase 2: Enhanced UX ✅ COMPLETE
- [x] Add `--revoke-key` command
- [x] Add key usage tracking (`lastUsed`)
- [x] Print Claude Code setup instructions after key generation

### Phase 3: Documentation ✅ COMPLETE
- [x] Create `ClaudeCodeSetupGuide.md`
- [x] Update README with quick start
- [x] Add troubleshooting guide

---

## Approval

- [ ] Architecture reviewed
- [ ] API design approved
- [ ] Security considerations addressed
- [ ] Ready for TDD implementation
