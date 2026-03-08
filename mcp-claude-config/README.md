# Trinity MCP Server — Claude Desktop + Cursor Auto-Discovery

Auto-discovery configuration for Claude Desktop and Cursor IDE to connect to Trinity MCP Server v2.1.

## φ² + 1/φ² = 3 = TRINITY

---

## Quick Setup

### Option 1: Claude Desktop (macOS)

1. **Build the MCP server:**
   ```bash
   cd /Users/playra/trinity-w1
   zig build
   ```

2. **Configure Claude Desktop:**
   ```bash
   # Copy the config to Claude Desktop's config directory
   mkdir -p ~/Library/Application\ Support/Claude/claude-desktop-config
   cp mcp-claude-config/trinity-mcp.json ~/Library/Application\ Support/Claude/claude-desktop-config/
   ```

3. **Restart Claude Desktop** and the Trinity MCP server will be auto-discovered.

### Option 2: Cursor IDE

1. **Build the MCP server:**
   ```bash
   cd /Users/playra/trinity-w1
   zig build
   ```

2. **Add to Cursor settings:**
   - Open Cursor → Settings → MCP Servers
   - Add server: `trinity`
   - Command: `/Users/playra/trinity-w1/zig-out/bin/trinity-mcp`

### Option 3: VS Code with Claude Extension

1. **Build the MCP server:**
   ```bash
   cd /Users/playra/trinity-w1
   zig build
   ```

2. **Create/Edit `.vscode/settings.json`:**
   ```json
   {
     "mcp.mcpServers": {
       "trinity": {
         "command": "/Users/playra/trinity-w1/zig-out/bin/trinity-mcp",
         "args": []
       }
     }
   }
   ```

---

## Available Tools

Once connected, you'll have access to **148+ Trinity tools**:

### Sacred Mathematics
- `tri_phi` — Compute φⁿ (golden ratio power)
- `tri_fib` — Fibonacci numbers with BigInt
- `tri_lucas` — Lucas L(n) where L(2)=3=TRINITY
- `tri_constants` — Show φ, π, e, μ, χ, σ, ε
- `tri_formula` — Mathematical formulas
- `tri_gematria` — Gematria analysis

### Development Workflow
- `tri_gen` — Compile VIBEE spec to Zig/Verilog
- `tri_spec_create` — Create .vibee spec template
- `tri_decompose` — Break task into sub-tasks
- `tri_plan` — Generate implementation plan
- `tri_verify` — Run tests + benchmarks
- `tri_commit` — Git commit with message

### Code Analysis
- `tri_fix` — Detect and fix bugs
- `tri_explain` — Explain code or concept
- `tri_status` — Git status --short
- `tri_diff` — Git diff
- `tri_bench` — Run performance benchmarks

### NEEDLE AI Refactoring
- `needle_quality_gates` — Quality gate checks
- `needle_search` — Semantic code search
- `needle_graph_build` — Build call graph
- `needle_graph_refactor` — Safe refactor with VSA
- `needle_omega_init` — Initialize Omega autonomous agent
- ... and 20+ more NEEDLE tools

---

## MCP Capabilities

The Trinity MCP Server implements **full MCP 2025-06-18 spec**:

- **Tools**: 148+ tools with auto-discovery
- **Resources**: 5 static resources (templates, docs, sacred constants)
- **Prompts**: 5 prompt templates for common workflows
- **Operations**: Cancellation support for long-running operations
- **Subscriptions**: Resource update notifications

---

## Example Usage in Claude

```
User: What is φ^10?

Claude: [Uses tri_phi tool]
φ^10 = 122.9918693812442

User: Create a new VIBEE spec for a math module

Claude: [Uses tri_spec_create tool]
Created spec at: specs/tri/math_module.vibee

User: Explain the VSA module

Claude: [Uses tri_explain tool]
The VSA (Vector Symbolic Architecture) module provides...
```

---

## Troubleshooting

### Claude Desktop can't find the server

1. Verify the binary exists:
   ```bash
   ls -la /Users/playra/trinity-w1/zig-out/bin/trinity-mcp
   ```

2. Test the server manually:
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize"}' | ./zig-out/bin/trinity-mcp
   ```

3. Check Claude Desktop logs:
   ```bash
   ~/Library/Logs/Claude/
   ```

### Cursor can't connect

1. Check Cursor's MCP server list in Settings
2. Verify the path is correct
3. Restart Cursor IDE

---

## Production Deployment

For production use, run the MCP server as a background service:

```bash
# Launch MCP server on port 8899
./zig-out/bin/trinity-mcp &

# Or with Docker
docker run -d -p 8899:8899 trinity/mcp:2.1.0
```

Then update the config to use HTTP transport:
```json
{
  "mcpServers": {
    "trinity": {
      "url": "http://localhost:8899/mcp"
    }
  }
}
```

---

## v2.1 Enterprise Features

- **HTTP/SSE Transport**: Real-time updates via Server-Sent Events
- **Prometheus Metrics**: Endpoint at `/metrics`
- **Resource Caching**: LRU cache for 100 entries
- **Input Sanitization**: Security validation against injection
- **Rate Limiting**: 60 requests/minute per client
- **Kubernetes Ready**: Helm chart included

---

## φ² + 1/φ² = 3 = TRINITY

**Not a claim — a theorem. Not a promise — a proof. Not simulated — GPU verified.**
