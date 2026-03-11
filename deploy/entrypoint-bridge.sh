#!/bin/sh
# Trinity Bridge Entrypoint — starts all 3 services
# 1. trinity-mcp (MCP server) — background
# 2. trinity-mcp --oracle (Oracle watchdog) — background
# 3. tri-api --serve (Perplexity bridge) — foreground (main process)

set -e

echo "[entrypoint] Starting trinity-mcp..."
/usr/local/bin/trinity-mcp &
MCP_PID=$!

echo "[entrypoint] Starting oracle watchdog..."
/usr/local/bin/trinity-mcp --oracle &
ORACLE_PID=$!

# Trap signals to clean up background processes
cleanup() {
    echo "[entrypoint] Shutting down..."
    kill "$MCP_PID" "$ORACLE_PID" 2>/dev/null || true
    wait "$MCP_PID" "$ORACLE_PID" 2>/dev/null || true
    exit 0
}
trap cleanup TERM INT

echo "[entrypoint] Starting bridge (tri-api --serve)..."
echo "[entrypoint] MCP PID=$MCP_PID, Oracle PID=$ORACLE_PID"

# Run bridge in foreground — Docker tracks this process
exec /usr/local/bin/tri-api --serve
