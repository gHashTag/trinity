---
sidebar_position: 7
---

# Plugin API

Extensible Plugin System for Trinity.

**Module:** `src/vibeec/plugin/`

## Plugin Types

| Type | Loading | Use Case |
|------|---------|----------|
| `comptime_import` | @import | Core |
| `wasm_runtime` | WASM | Community |
| `native_ffi` | .so/.dylib | Performance |

## Creating a Plugin

1. Create `plugin.vibee` specification
2. Implement required exports
3. Build to WASM

## Loading Plugins

```zig
var loader = PluginLoader.init(allocator, &registry, .{});
const result = try loader.loadFromPath("plugin.wasm");
```

## CLI Commands

```bash
vibee plugin list          # List installed
vibee plugin install <url> # Install
vibee plugin init <name>   # Create new
```
