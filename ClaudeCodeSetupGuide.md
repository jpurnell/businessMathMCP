# Claude Code Setup Guide

This guide explains how to connect Claude Code to BusinessMathMCP server for financial calculations.

## Quick Start (5 Minutes)

### 1. Generate an API Key (Server)

```bash
# On your server machine
businessmath-mcp-server --generate-key --name "Claude Code"
```

Output:
```
Generated API key for "Claude Code":

  bm_7Kx9mPqR2sT4vW6xY8zA0bC3dE5fG7hJ

Save this key securely - it cannot be retrieved later.
```

### 2. Start the Server

```bash
businessmath-mcp-server --http 8080
```

Output:
```
✓ Loaded 1 API key(s) from ~/.businessmath-mcp/api-keys.json
✓ HTTP server listening on port 8080
```

### 3. Configure Claude Code (Client)

```bash
claude mcp add --transport http businessmath http://<server-ip>:8080 \
  --header "Authorization: Bearer bm_7Kx9mPqR2sT4vW6xY8zA0bC3dE5fG7hJ"
```

Replace `<server-ip>` with your server's IP address (e.g., `10.0.1.114` or `localhost`).

That's it! Claude Code can now use 185+ financial calculation tools.

---

## Server Configuration

### Key Management Commands

```bash
# Generate a new API key
businessmath-mcp-server --generate-key --name "My Key Name"

# List all keys (shows prefix only for security)
businessmath-mcp-server --list-keys

# Revoke a key by its prefix
businessmath-mcp-server --revoke-key bm_7Kx9mP

# Show help
businessmath-mcp-server --help
```

### Key Storage

Keys are stored in `~/.businessmath-mcp/api-keys.json` with restricted permissions (owner read/write only).

### Running as a Background Service

```bash
# Start in background
nohup businessmath-mcp-server --http 8080 > /var/log/mcp-server.log 2>&1 &

# Or use systemd (Linux)
# See DEPLOY_INSTRUCTIONS.md for systemd service configuration
```

### Server Options

| Option | Description |
|--------|-------------|
| `--http <port>` | Run HTTP server on specified port |
| `--generate-key` | Generate a new API key |
| `--name <name>` | Name for the generated key |
| `--list-keys` | List all API keys |
| `--revoke-key <prefix>` | Revoke a key by prefix |
| `--help` | Show help |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MCP_API_KEYS` | Comma-separated API keys (legacy) | - |
| `MCP_AUTH_REQUIRED` | Set to "false" to disable auth | true |
| `MCP_OAUTH_ENABLED` | Enable OAuth 2.0 | false |
| `MCP_OAUTH_ISSUER` | OAuth issuer URL | http://localhost:port |

---

## Claude Code Configuration

### Adding the Server

```bash
# Basic configuration
claude mcp add --transport http businessmath http://server:8080 \
  --header "Authorization: Bearer <your-api-key>"

# With scope (local, user, or project)
claude mcp add --transport http --scope user businessmath http://server:8080 \
  --header "Authorization: Bearer <your-api-key>"
```

### Verifying Configuration

```bash
# List configured servers
claude mcp list

# Remove a server
claude mcp remove businessmath
```

### Configuration Files

Claude Code stores MCP configuration in:
- **Local:** `.claude.json` in project directory
- **User:** `~/.claude.json`

---

## Verification

### Test Server Health

```bash
curl http://<server-ip>:8080/health
# Expected: OK
```

### Test MCP Protocol

```bash
curl -X POST http://<server-ip>:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your-api-key>" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}},"id":1}'
```

Expected: JSON response with server info and 185 tools.

### Test a Tool

```bash
curl -X POST http://<server-ip>:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your-api-key>" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"calculate_npv","arguments":{"rate":0.1,"cashFlows":[-1000,300,400,500,600]}},"id":2}'
```

Expected: NPV calculation result.

---

## Troubleshooting

### "Failed to connect" in `claude mcp list`

This warning may appear even when the server works correctly. Verify with:
```bash
curl http://<server-ip>:8080/health
```

If this returns "OK", the server is working. The `mcp list` health check uses a different mechanism.

### "Request rejected: missing Authorization header"

The API key is not being sent. Check:
1. The `--header` flag was included when adding the server
2. The key format is correct (`Bearer <key>`)

### "Request rejected: invalid API key"

The key doesn't match. Verify:
1. The key matches what was generated
2. The key hasn't been revoked (`--list-keys` to check)
3. You're connecting to the correct server

### Connection Refused

1. Verify server is running: `ps aux | grep businessmath`
2. Check firewall allows port 8080
3. Verify IP address is correct

### Server Won't Start

Check if port is in use:
```bash
lsof -i :8080
```

Kill existing process or use a different port.

---

## Security Considerations

### API Key Best Practices

1. **Use unique keys per client** - Generate separate keys for different machines/users
2. **Rotate keys periodically** - Revoke and regenerate keys regularly
3. **Never commit keys** - Add `.claude.json` to `.gitignore`
4. **Use HTTPS in production** - API keys are sent in headers

### Network Security

- Use a firewall to restrict access to the MCP port
- Consider VPN for remote access
- Run behind a reverse proxy (nginx/caddy) for TLS

### Key Format

Keys use the format `bm_<32-character-base64url>`:
- `bm_` prefix for easy identification
- 32 characters of base64url-encoded random data (192 bits of entropy)
- Total length: 35 characters

---

## Available Tools

BusinessMathMCP provides 185+ financial calculation tools across these categories:

| Category | Tools | Examples |
|----------|-------|----------|
| Time Value of Money | 9 | NPV, IRR, PV, FV, payments |
| Portfolio Optimization | 4 | Mean-variance, risk parity, efficient frontier |
| Options Pricing | 7 | Black-Scholes, Greeks, binomial trees |
| Bond Valuation | 7 | Pricing, duration, YTM |
| Statistical Analysis | 13 | Regression, correlation, confidence intervals |
| Monte Carlo | 7 | Risk simulation, scenario analysis |
| Financial Ratios | 21 | ROE, ROI, liquidity, leverage |
| Forecasting | 8 | Trend analysis, seasonality |
| Optimization | 12 | Linear programming, heuristics |

Use the `tools/list` MCP method or ask Claude to describe available tools.

---

## Example Session

Once configured, you can use BusinessMathMCP tools naturally in Claude Code:

```
You: Calculate the NPV of an investment with initial cost $100,000
     and annual cash flows of $30,000 for 5 years at 10% discount rate.

Claude: [Uses calculate_npv tool]
        The NPV is $13,723.60. Since the NPV is positive, this
        investment would add value and should be considered.
```

---

## Getting Help

- **CLI Help:** `businessmath-mcp-server --help`
- **Issues:** https://github.com/jpurnell/businessMathMCP/issues
- **Documentation:** See `development-guidelines/` for architecture details
