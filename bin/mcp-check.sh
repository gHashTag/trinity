#!/usr/bin/env bash
# MCP Server Diagnostic & Fix Script
# Usage: bash bin/mcp-check.sh [--fix] [--test-tool <tool_name>]

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MCP_CONFIG="$PROJECT_ROOT/.mcp.json"
MCP_BIN="$PROJECT_ROOT/zig-out/bin/trinity-mcp"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
info() { echo -e "  ${CYAN}→${NC} $1"; }

MODE="${1:-}"
TOOL_NAME="${2:-tri_status}"

echo "═══════════════════════════════════════════"
echo "  Trinity MCP Diagnostic"
echo "═══════════════════════════════════════════"
echo ""

# 1. Check .mcp.json
echo "1. Configuration (.mcp.json)"
if [[ -f "$MCP_CONFIG" ]]; then
    ok "Config exists: $MCP_CONFIG"
    SERVER_COUNT=$(python3 -c "import json; print(len(json.load(open('$MCP_CONFIG'))['mcpServers']))" 2>/dev/null || echo "0")
    ok "Servers configured: $SERVER_COUNT"
else
    fail "Config missing: $MCP_CONFIG"
    if [[ "$MODE" == "--fix" ]]; then
        info "Creating default .mcp.json..."
        cat > "$MCP_CONFIG" << 'MCPEOF'
{
  "mcpServers": {
    "trinity": {
      "command": "__MCP_BIN__",
      "args": [],
      "env": {"TRINITY_MCP_PORT": "8899"}
    }
  }
}
MCPEOF
        sed -i "s|__MCP_BIN__|$MCP_BIN|g" "$MCP_CONFIG"
        ok "Created .mcp.json"
    fi
fi
echo ""

# 2. Check binary
echo "2. Binary"
if [[ -x "$MCP_BIN" ]]; then
    ok "Binary exists and executable: $MCP_BIN"
    SIZE=$(du -h "$MCP_BIN" | cut -f1)
    ok "Size: $SIZE"
else
    fail "Binary missing or not executable: $MCP_BIN"
    if [[ "$MODE" == "--fix" ]]; then
        info "Building trinity-mcp..."
        cd "$PROJECT_ROOT"
        zig build 2>&1 | tail -5
        if [[ -x "$MCP_BIN" ]]; then
            ok "Build successful"
        else
            fail "Build failed"
            exit 1
        fi
    else
        warn "Run with --fix to rebuild"
    fi
fi
echo ""

# 3. Check dependencies
echo "3. Dependencies"
for cmd in node npx; do
    if command -v "$cmd" &>/dev/null; then
        VER=$($cmd --version 2>/dev/null)
        ok "$cmd: $VER"
    else
        fail "$cmd: not found"
    fi
done
echo ""

# 4. Test JSON-RPC initialize
echo "4. JSON-RPC Protocol Test"
INIT_REQ='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"mcp-check","version":"1.0"}}}'

RESPONSE=$(echo "$INIT_REQ" | timeout 5 "$MCP_BIN" 2>/dev/null || true)

if echo "$RESPONSE" | grep -q '"protocolVersion"'; then
    ok "Initialize handshake OK"
    VERSION=$(echo "$RESPONSE" | grep -o '"version":"[^"]*"' | tail -1 | cut -d'"' -f4)
    ok "Server version: $VERSION"
else
    fail "Initialize handshake failed"
    if [[ -n "$RESPONSE" ]]; then
        warn "Response: $(echo "$RESPONSE" | head -3)"
    fi
fi
echo ""

# 5. List tools
echo "5. Tools Inventory"
TOOLS_REQ=$(printf '%s\n%s' "$INIT_REQ" '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}')
TOOLS_RESPONSE=$(echo "$TOOLS_REQ" | timeout 5 "$MCP_BIN" 2>/dev/null || true)

TRI_TOOLS=$(echo "$TOOLS_RESPONSE" | grep -o '"name":"tri_[^"]*"' | wc -l)
NEEDLE_TOOLS=$(echo "$TOOLS_RESPONSE" | grep -o '"name":"needle_[^"]*"' | wc -l)
TOTAL=$((TRI_TOOLS + NEEDLE_TOOLS))

if [[ $TOTAL -gt 0 ]]; then
    ok "Total tools: $TOTAL (tri: $TRI_TOOLS, needle: $NEEDLE_TOOLS)"
else
    fail "No tools returned"
fi
echo ""

# 6. Test a specific tool call
if [[ "$MODE" == "--test-tool" && -n "$TOOL_NAME" ]] || [[ "$MODE" != "--fix" && $TOTAL -gt 0 ]]; then
    echo "6. Tool Call Test ($TOOL_NAME)"
    CALL_REQ=$(printf '%s\n%s' "$INIT_REQ" "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"$TOOL_NAME\",\"arguments\":{}}}")
    CALL_RESPONSE=$(echo "$CALL_REQ" | timeout 10 "$MCP_BIN" 2>/dev/null || true)

    if echo "$CALL_RESPONSE" | grep -q '"result"'; then
        ok "Tool call succeeded"
        # Extract text content (first 200 chars)
        TEXT=$(echo "$CALL_RESPONSE" | python3 -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line or not line.startswith('{'):
        continue
    try:
        d = json.loads(line)
        if 'result' in d and 'content' in d['result']:
            for c in d['result']['content']:
                if c.get('type') == 'text':
                    print(c['text'][:200])
                    break
            break
    except: pass
" 2>/dev/null || echo "(could not parse)")
        if [[ -n "$TEXT" ]]; then
            info "Response: $TEXT"
        fi
    else
        fail "Tool call failed or timed out"
    fi
    echo ""
fi

# 7. Summary
echo "═══════════════════════════════════════════"
if [[ $TOTAL -gt 0 ]]; then
    echo -e "  ${GREEN}MCP server is healthy${NC}"
    echo ""
    echo "  The server works but Claude Code may not"
    echo "  auto-connect MCP in this environment."
    echo ""
    echo "  Workaround: use tools via bash:"
    echo "    bash bin/mcp-call.sh tri_status"
    echo "    bash bin/mcp-call.sh tri_test '{\"path\":\"src/vsa.zig\"}'"
else
    echo -e "  ${RED}MCP server has issues${NC}"
    echo "  Run: bash bin/mcp-check.sh --fix"
fi
echo "═══════════════════════════════════════════"
