# Plugin API Reference

> Extensible Plugin System for Trinity

**Module:** `src/vibeec/plugin/`

---

## Overview

The Trinity plugin system enables extending functionality through:
- **Core plugins:** Compiled Zig modules (comptime import)
- **WASM plugins:** Community extensions (sandboxed)
- **Native plugins:** FFI for performance-critical code

---

## Plugin Types

| Type | Loading | Use Case |
|------|---------|----------|
| `comptime_import` | @import (Zig) | Core functionality |
| `wasm_runtime` | WASM interpreter | Community extensions |
| `native_ffi` | .so/.dylib | Performance-critical |

---

## Plugin Interface

### PluginMetadata

```zig
pub const PluginMetadata = struct {
    id: []const u8,
    name: []const u8,
    version: []const u8,
    author: []const u8,
    kind: PluginKind,
    capabilities: []const PluginCapability,
    dependencies: []const []const u8,
    trinity_version: []const u8,
};
```

### PluginKind

```zig
pub const PluginKind = enum {
    core,           // Built-in Trinity functionality
    firebird_ext,   // LLM extensions
    codegen,        // Code generators
    analyzer,       // Analysis tools
    formatter,      // Code formatters
    network,        // Network protocols
    storage,        // Storage backends
};
```

### PluginCapability

```zig
pub const PluginCapability = enum {
    code_generation,
    model_inference,
    syntax_analysis,
    code_formatting,
    file_system,
    network_access,
    gpu_compute,
};
```

---

## Creating a Plugin

### WASM Plugin (Recommended)

1. Create `plugin.vibee`:

```yaml
name: my_plugin
version: "1.0.0"
language: wasm
module: my_plugin

exports:
  - plugin_init
  - plugin_deinit
  - plugin_invoke
  - plugin_metadata
```

2. Implement required exports:

```zig
// Required WASM exports
export fn plugin_init() void { }
export fn plugin_deinit() void { }
export fn plugin_invoke(op: [*]u8, len: u32) i32 { }
export fn plugin_metadata() [*]u8 { }
```

3. Build to WASM:

```bash
zig build-lib -target wasm32-freestanding my_plugin.zig
```

---

## Plugin Loading

### PluginLoader

```zig
const loader = @import("plugin/plugin_loader.zig");

var plugin_loader = loader.PluginLoader.init(allocator, &registry, .{
    .verify_signatures = true,
    .allow_native = false,
    .sandbox_wasm = true,
});

const result = try plugin_loader.loadFromPath("plugin.wasm");
if (result.success) {
    const plugin = result.plugin.?;
    // Use plugin
}
```

### SecurityConfig

```zig
pub const SecurityConfig = struct {
    verify_signatures: bool = true,    // Ed25519 verification
    allow_native: bool = false,        // Allow .so/.dylib
    sandbox_wasm: bool = true,         // Sandbox WASM plugins
    memory_limit_mb: usize = 256,      // Memory limit
    timeout_ms: u32 = 30000,           // Execution timeout
};
```

---

## Plugin Registry

### Registration

```zig
const registry = @import("plugin/plugin_registry.zig");

var reg = try registry.PluginRegistry.init(allocator);

// Register plugin
try reg.register(plugin, .local_wasm, registry.PRIORITY_COMMUNITY);
```

### Discovery

```zig
// Find plugins by capability
const generators = reg.findByCapability(.code_generation);

// Find by kind
const firebird_plugins = reg.findByKind(.firebird_ext);
```

---

## Plugin Manifest

### plugin.vibee Format

```yaml
name: my_extension
version: "1.0.0"
author: "Developer Name"
license: "MIT"

plugin:
  kind: firebird_ext
  capabilities:
    - model_inference
    - code_generation

dependencies:
  - trinity: ">=22.0.0"

exports:
  - name: process
    params: [input: String]
    returns: String
```

---

## CLI Commands

```bash
# List installed plugins
vibee plugin list

# Show plugin info
vibee plugin info <plugin_id>

# Install plugin
vibee plugin install <url_or_path>

# Remove plugin
vibee plugin uninstall <plugin_id>

# Create new plugin
vibee plugin init <name>

# Build plugin to WASM
vibee plugin build
```

---

## Priority Levels

| Priority | Value | Use |
|----------|-------|-----|
| `PRIORITY_CORE` | 100 | Built-in plugins |
| `PRIORITY_OFFICIAL` | 50 | Official extensions |
| `PRIORITY_COMMUNITY` | 10 | Community plugins |

---

## See Also

- [FIREBIRD_API.md](FIREBIRD_API.md) — LLM engine
- [VIBEE_API.md](VIBEE_API.md) — Specification compiler
- [WASM Extension Guide](../architecture/EXTENSION_ARCHITECTURE.md) — WASM details
