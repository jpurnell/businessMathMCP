# BusinessMath MCP Server — Dev/Test Deployment

## Key Paths

| What | Where |
|------|-------|
| Dev server | `10.0.1.114` (Starscream, Ubuntu 25.10 x86_64) |
| Project | `/home/jpurnell/Documents/development/swift/businessMathMCP` |
| Binary | `/home/jpurnell/Documents/development/swift/businessMathMCP/.build/release/businessmath-mcp-server` |
| Systemd service | `/etc/systemd/system/businessmath-mcp.service` |
| Swift (swiftly) | `source ~/.local/share/swiftly/env.sh` |
| Port | `8080` |

## Deploy

```bash
ssh jpurnell@10.0.1.114 'cd /home/jpurnell/Documents/development/swift/businessMathMCP && git pull origin main && source ~/.local/share/swiftly/env.sh && swift build -c release && sudo systemctl restart businessmath-mcp && sleep 2 && curl -s http://localhost:8080/health'
```

## Service Commands

```bash
sudo systemctl stop businessmath-mcp
sudo systemctl start businessmath-mcp
sudo systemctl restart businessmath-mcp
sudo systemctl status businessmath-mcp
sudo journalctl -u businessmath-mcp -f        # tail logs
```

## Bind address

As of SwiftMCPServer 5.0.0 the server listens on `127.0.0.1` unless started with
`--host <address>`. The checks under **Verify** reach it from another machine, so the unit's
`ExecStart` must end `--http 8080 --host 0.0.0.0`. The unit file lives on the server, not in
this repository: it has to be edited there (`sudo systemctl edit --full businessmath-mcp`)
before the first restart on a 5.0.0 build, or the service will start and answer nobody.

## Verify

```bash
curl -s http://10.0.1.114:8080/health          # → OK
curl -s http://10.0.1.114:8080/mcp             # → server info JSON
```
