---
sidebar_position: 1
sidebar_label: Overview
---

# API Reference

Complete API documentation for Trinity modules.

## Core Modules

| Module | Description |
|--------|-------------|
| [VSA](/api/vsa) | Vector Symbolic Architecture |
| [VM](/api/vm) | Ternary Virtual Machine |
| [Hybrid](/api/hybrid) | HybridBigInt storage |
| [Firebird](/api/firebird) | LLM inference engine |
| [VIBEE](/api/vibee) | Specification compiler |
| [Plugin](/api/plugin) | Extension system |

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
./bin/vibee gen <spec.vibee>      # Generate code
./bin/vibee run <program.999>     # Execute program
./bin/vibee chat --model <path>   # Interactive chat
./bin/vibee serve --port 8080     # HTTP server
```
