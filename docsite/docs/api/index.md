---
sidebar_position: 1
sidebar_label: Overview
---

# API Reference

Complete API documentation for Trinity modules.

## Core Modules

| Module | Description |
|--------|-------------|
| [VSA](/api/vsa) | Vector Symbolic Architecture (Zig) |
| [VM](/api/vm) | Ternary Virtual Machine |
| [Hybrid](/api/hybrid) | HybridBigInt storage |
| [Firebird](/api/firebird) | LLM inference engine |
| [VIBEE](/api/vibee) | Specification compiler |
| [Plugin](/api/plugin) | Extension system |

## SDK Bindings

| Module | Description |
|--------|-------------|
| [C API (libtrinity-vsa)](/api/c-api) | 22-function C library — SIMD-accelerated, 70 KB |
| [Python SDK](/api/python-sdk) | ctypes binding — NativeVSA + Vector classes |

## Quick Reference

### VSA Operations

```zig
vsa.bind(a, b)              // Create association
vsa.unbind(bound, key)      // Retrieve from binding
vsa.bundle2(a, b)           // Combine 2 vectors
vsa.cosineSimilarity(a, b)  // Compare vectors [-1, 1]
vsa.hammingDistance(a, b)   // Count differences
vsa.permute(v, count)       // Cyclic shift
```

### HybridBigInt

```zig
var v = HybridBigInt.zero();       // Zero vector
var v = HybridBigInt.random(1000); // Random vector
v.pack();                          // Memory efficient
v.ensureUnpacked();                // Compute efficient
```

### CLI Commands

```bash
tri gen <spec.vibee>              # Generate code from spec
tri chat "Hello"                  # Interactive AI chat
tri serve --port 8080             # HTTP API server
tri doctor                        # System health check
tri full-autonomous               # Full system report
```

> **See also:** [TRI CLI Reference](/cli/) for the complete CLI documentation with 190+ commands.
