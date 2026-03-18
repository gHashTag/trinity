---
paths:
  - "tools/mcp/**"
---

# MCP Server Rules

- Protocol version: 2024-11-05 (JSON-RPC over stdio with Content-Length framing)
- Single server: trinity-mcp (Zig, 47+ tools, resources, prompts)
- All tool responses must be valid JSON with `content` array
- Security: audit log every tool invocation to `.trinity/mcp_audit.log`
- High-risk tools (codegen, fpga, deploy) require confirmation gates
- Error responses: include error code, message, and recovery suggestion
- Test with: `echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | ./zig-out/bin/trinity-mcp`
