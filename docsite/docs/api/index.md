---
sidebar_position: 1
sidebar_label: Overview
---

# API Reference

Complete API documentation for Trinity modules.

## Core Modules

| Module | Description |
|--------|-------------|
| [VSA](/docs/api/vsa) | Vector Symbolic Architecture |
| [VM](/docs/api/vm) | Ternary Virtual Machine |
| [Hybrid](/docs/api/hybrid) | HybridBigInt storage |
| [Firebird](/docs/api/firebird) | LLM inference engine |
| [VIBEE](/docs/api/vibee) | Specification compiler |
| [Plugin](/docs/api/plugin) | Extension system |

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
