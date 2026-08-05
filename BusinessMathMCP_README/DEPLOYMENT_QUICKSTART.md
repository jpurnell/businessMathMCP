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

## Verify

```bash
curl -s http://10.0.1.114:8080/health          # → OK
curl -s http://10.0.1.114:8080/mcp             # → server info JSON
```
