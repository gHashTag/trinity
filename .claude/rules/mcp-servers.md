---
paths:
  - "tools/mcp/**"
  - "trinity-mcp.py"
  - "trinity-mcp.zig"
  - "mcp/**"
---

# MCP Server Rules

- Protocol version: 2024-11-05 (JSON-RPC over stdio)
- Primary servers: trinity-mcp (Zig, 35+ tools), needle-mcp (Zig, 6 tools)
- Python server (trinity-mcp.py) is the fallback — keep in sync with Zig tools
- All tool responses must be valid JSON with `content` array
- Security: audit log every tool invocation to `.trinity/mcp_audit.log`
- High-risk tools (codegen, fpga, deploy) require confirmation gates
- Error responses: include error code, message, and recovery suggestion
- Test with: `echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | ./zig-out/bin/trinity-mcp`
