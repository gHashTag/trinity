# API Reference

> Complete API documentation for Trinity modules

---

## Core Modules

| Module | Description | Documentation |
|--------|-------------|---------------|
| **VSA** | Vector Symbolic Architecture | [VSA_API.md](VSA_API.md) |
| **VM** | Ternary Virtual Machine | [VM_API.md](VM_API.md) |
| **Hybrid** | HybridBigInt storage | [HYBRID_API.md](HYBRID_API.md) |
| **Firebird** | LLM inference engine | [FIREBIRD_API.md](FIREBIRD_API.md) |
| **VIBEE** | Specification compiler | [VIBEE_API.md](VIBEE_API.md) |
| **Plugin** | Extension system | [PLUGIN_API.md](PLUGIN_API.md) |

---

## Additional References

| Document | Description |
|----------|-------------|
| [TRINITY_API.md](TRINITY_API.md) | Legacy API overview |
| [SDK.md](SDK.md) | High-level SDK |
| [VIBEE_SPEC_FORMAT.md](VIBEE_SPEC_FORMAT.md) | Specification format |

---

## Quick Reference

### VSA Operations

```zig
vsa.bind(a, b)              // Create association
vsa.unbind(bound, key)      // Retrieve from binding
vsa.bundle2(a, b)           // Combine 2 vectors
vsa.bundle3(a, b, c)        // Combine 3 vectors
vsa.cosineSimilarity(a, b)  // Compare vectors [-1, 1]
vsa.hammingDistance(a, b)   // Count differences
vsa.permute(v, count)       // Cyclic shift
```

### HybridBigInt

```zig
var v = HybridBigInt.zero();       // Zero vector
var v = HybridBigInt.random(1000); // Random vector
var v = HybridBigInt.fromI64(42);  // From integer
v.pack();                          // Memory efficient
v.ensureUnpacked();                // Compute efficient
```

### CLI Commands

```bash
./bin/vibee gen <spec.vibee>      # Generate code
./bin/vibee run <program.999>     # Execute program
./bin/vibee chat --model <path>   # Interactive chat
./bin/vibee serve --port 8080     # HTTP server
./bin/vibee koschei               # Development cycle
```

---

## See Also

- [../INDEX.md](../INDEX.md) — Documentation index
- [../getting-started/](../getting-started/) — Tutorials
- [../TROUBLESHOOTING.md](../TROUBLESHOOTING.md) — Common issues
