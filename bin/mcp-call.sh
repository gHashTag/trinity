#!/usr/bin/env bash
# Call a Trinity MCP tool directly via JSON-RPC
# Usage: bash bin/mcp-call.sh <tool_name> [json_args]
#
# Examples:
#   bash bin/mcp-call.sh tri_status
#   bash bin/mcp-call.sh tri_test '{"path":"src/vsa.zig"}'
#   bash bin/mcp-call.sh tri_gen '{"spec":"specs/tri/feature.vibee"}'
#   bash bin/mcp-call.sh needle_search '{"query":"bind"}'

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MCP_BIN="$PROJECT_ROOT/zig-out/bin/trinity-mcp"

TOOL="${1:?Usage: mcp-call.sh <tool_name> [json_args]}"
ARGS="${2:-{}}"

# JSON-RPC requests
INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"mcp-call","version":"1.0"}}}'
CALL="{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"$TOOL\",\"arguments\":$ARGS}}"

# Send both requests, parse response
printf '%s\n%s\n' "$INIT" "$CALL" | timeout 30 "$MCP_BIN" 2>/dev/null | python3 -c "
import sys, json

for line in sys.stdin:
    line = line.strip()
    if not line or not line.startswith('{'):
        continue
    try:
        d = json.loads(line)
        if d.get('id') != 2:
            continue
        if 'error' in d:
            print(f\"ERROR: {d['error'].get('message', d['error'])}\")
        elif 'result' in d:
            for c in d['result'].get('content', []):
                if c.get('type') == 'text':
                    print(c['text'])
        break
    except json.JSONDecodeError:
        pass
"
