#!/usr/bin/env bash
set -euo pipefail

# Deploy businessmath-mcp-server to roseclub.org
# Usage: ./scripts/deploy.sh [--skip-tag] [--dry-run]

# ── Configuration ────────────────────────────────────────────────────
REMOTE_HOST="roseclub.org"
REMOTE_PROJECT="/Users/jpurnell/businessMathMCP"
REMOTE_BINARY="$REMOTE_PROJECT/.build/release/businessmath-mcp-server"
TLS_CERT="/Users/jpurnell/.businessmath-mcp/certs/fullchain.pem"
TLS_KEY="/Users/jpurnell/.businessmath-mcp/certs/privkey.pem"
SERVER_PORT=8080

BUSINESSMATH_REPO="${BUSINESSMATH_REPO:-$(cd "$(dirname "$0")/../.." && pwd)/BusinessMath}"

# ── Flags ────────────────────────────────────────────────────────────
SKIP_TAG=false
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --skip-tag) SKIP_TAG=true ;;
        --dry-run)  DRY_RUN=true ;;
        -h|--help)
            echo "Usage: $0 [--skip-tag] [--dry-run]"
            echo "  --skip-tag  Skip creating a deploy tag on BusinessMath"
            echo "  --dry-run   Show what would happen without executing"
            exit 0
            ;;
        *) echo "Unknown flag: $arg"; exit 1 ;;
    esac
done

run() {
    echo "  → $*"
    if [ "$DRY_RUN" = false ]; then
        "$@"
    fi
}

remote() {
    if [ "$DRY_RUN" = true ]; then
        echo "  → ssh $REMOTE_HOST \"$1\""
    else
        ssh "$REMOTE_HOST" "$1"
    fi
}

# ── Step 1: Tag BusinessMath ─────────────────────────────────────────
echo "╔══════════════════════════════════════════════════╗"
echo "║  BusinessMath MCP Server Deploy                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo

COMMIT=$(git -C "$BUSINESSMATH_REPO" rev-parse --short HEAD 2>/dev/null || echo "unknown")
COMMIT_FULL=$(git -C "$BUSINESSMATH_REPO" rev-parse HEAD 2>/dev/null || echo "unknown")
echo "[info] BusinessMath HEAD: $COMMIT"

if [ "$SKIP_TAG" = false ]; then
    DATE_TAG="deploy-$(date +%Y%m%d)"
    EXISTING=$(git -C "$BUSINESSMATH_REPO" tag -l "${DATE_TAG}*" | sort -V | tail -1)
    if [ -z "$EXISTING" ]; then
        TAG="${DATE_TAG}"
    else
        SEQ=$(echo "$EXISTING" | grep -oE '\.[0-9]+$' | tr -d '.' || echo "0")
        if [ -z "$SEQ" ]; then
            TAG="${DATE_TAG}.1"
        else
            TAG="${DATE_TAG}.$((SEQ + 1))"
        fi
    fi

    echo "[tag]  Creating $TAG → $COMMIT"
    run git -C "$BUSINESSMATH_REPO" tag "$TAG" HEAD
    run git -C "$BUSINESSMATH_REPO" push origin "$TAG"
    echo
else
    echo "[tag]  Skipped (--skip-tag)"
    echo
fi

# ── Step 2: Verify remote connectivity ──────────────────────────────
echo "[ssh]  Checking $REMOTE_HOST..."
if [ "$DRY_RUN" = false ]; then
    if ! ssh -o ConnectTimeout=10 "$REMOTE_HOST" "echo ok" > /dev/null 2>&1; then
        echo "ERROR: Cannot reach $REMOTE_HOST"
        exit 1
    fi
fi
echo "[ssh]  Connected"
echo

# ── Step 3: Update dependencies on remote ───────────────────────────
echo "[deps] Updating BusinessMath dependency..."
remote "cd $REMOTE_PROJECT && rm -f Package.resolved && swift package purge-cache 2>&1 | tail -1"
remote "cd $REMOTE_PROJECT && swift package resolve 2>&1 | grep -i 'businessMath\|error' || true"

RESOLVED=$(remote "cd $REMOTE_PROJECT && grep -A4 '\"businessmath\"' Package.resolved | grep revision | head -1" 2>/dev/null || echo "")
RESOLVED_SHORT=$(echo "$RESOLVED" | grep -oE '[a-f0-9]{40}' | cut -c1-7 || echo "unknown")
echo "[deps] Resolved BusinessMath at: $RESOLVED_SHORT"

if [ "$RESOLVED_SHORT" != "unknown" ] && [ "$RESOLVED_SHORT" != "${COMMIT:0:7}" ]; then
    echo "WARNING: Resolved commit ($RESOLVED_SHORT) != local HEAD ($COMMIT)"
    echo "         The remote may have cached a stale version."
    echo "         Attempting full cache purge..."
    remote "cd $REMOTE_PROJECT && rm -rf .build Package.resolved && swift package purge-cache 2>/dev/null; swift package resolve 2>&1 | grep -i 'businessMath\|error' || true"
    RESOLVED=$(remote "cd $REMOTE_PROJECT && grep -A4 '\"businessmath\"' Package.resolved | grep revision | head -1" 2>/dev/null || echo "")
    RESOLVED_SHORT=$(echo "$RESOLVED" | grep -oE '[a-f0-9]{40}' | cut -c1-7 || echo "unknown")
    echo "[deps] Re-resolved BusinessMath at: $RESOLVED_SHORT"
fi
echo

# ── Step 4: Build on remote ─────────────────────────────────────────
echo "[build] Release build starting (this takes ~10 minutes on x86_64)..."
if [ "$DRY_RUN" = false ]; then
    BUILD_OUTPUT=$(remote "cd $REMOTE_PROJECT && swift build -c release 2>&1")
    if echo "$BUILD_OUTPUT" | grep -q "Build complete!"; then
        BUILD_TIME=$(echo "$BUILD_OUTPUT" | grep "Build complete!" | grep -oE '[0-9.]+s' || echo "?")
        echo "[build] Success ($BUILD_TIME)"
    else
        echo "[build] FAILED"
        echo "$BUILD_OUTPUT" | grep "error:" | head -10
        exit 1
    fi
else
    echo "  → ssh $REMOTE_HOST \"cd $REMOTE_PROJECT && swift build -c release\""
fi
echo

# ── Step 5: Restart server ──────────────────────────────────────────
echo "[restart] Stopping old server..."
if [ "$DRY_RUN" = false ]; then
    OLD_PID=$(ssh "$REMOTE_HOST" "pgrep -f businessmath-mcp-server" 2>/dev/null || echo "")
    if [ -n "$OLD_PID" ]; then
        echo "[restart] Killing PID $OLD_PID"
        ssh "$REMOTE_HOST" "kill $OLD_PID"
        sleep 2
    else
        echo "[restart] No running server found"
    fi
else
    echo "  → ssh $REMOTE_HOST \"pgrep -f businessmath-mcp-server && kill <PID>\""
fi

echo "[restart] Starting new server..."
if [ "$DRY_RUN" = false ]; then
    ssh "$REMOTE_HOST" "cd $REMOTE_PROJECT && nohup $REMOTE_BINARY --http $SERVER_PORT --tls-cert $TLS_CERT --tls-key $TLS_KEY > /tmp/businessmath-mcp.log 2>&1 &"
    sleep 3
    NEW_PID=$(ssh "$REMOTE_HOST" "pgrep -f businessmath-mcp-server" 2>/dev/null || echo "")
    if [ -n "$NEW_PID" ]; then
        echo "[restart] Server running (PID $NEW_PID)"
    else
        echo "[restart] FAILED — server did not start. Check /tmp/businessmath-mcp.log"
        exit 1
    fi
else
    echo "  → nohup $REMOTE_BINARY --http $SERVER_PORT --tls-cert ... &"
fi
echo

# ── Step 6: Health check ────────────────────────────────────────────
echo "[health] Testing https://$REMOTE_HOST:$SERVER_PORT/mcp ..."
if [ "$DRY_RUN" = false ]; then
    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" -X POST "https://$REMOTE_HOST:$SERVER_PORT/mcp" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"deploy-check","version":"1.0.0"}},"id":1}' \
        --connect-timeout 10 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "000" ]; then
        echo "[health] WARNING — could not connect (server may still be starting)"
    elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "200" ]; then
        echo "[health] OK (HTTP $HTTP_CODE)"
    else
        echo "[health] WARNING — unexpected HTTP $HTTP_CODE"
    fi
fi
echo

# ── Summary ─────────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════"
echo "  Deploy complete"
echo "  BusinessMath: $COMMIT_FULL"
if [ "$SKIP_TAG" = false ]; then
    echo "  Tag:          ${TAG:-n/a}"
fi
echo "  Server:       https://$REMOTE_HOST:$SERVER_PORT/mcp"
echo "══════════════════════════════════════════════════"
