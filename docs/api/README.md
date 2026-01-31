# API Reference

## Core APIs

- [Trinity API](TRINITY_API.md) - VSA operations, types, VM instructions
- [VIBEE Spec Format](VIBEE_SPEC_FORMAT.md) - Specification language reference
- [SDK Reference](SDK.md) - High-level SDK documentation

## Quick Reference

### VSA Operations
```zig
trinity.bind(a, b)           // Create association
trinity.bundle(vectors)      // Combine vectors
trinity.permute(v, shift)    // Sequence encoding
trinity.cosineSimilarity(a, b) // Compare vectors
```

### CLI Commands
```bash
./bin/vibee gen <spec.vibee>  # Generate code
./bin/vibee run <program.999> # Execute program
./bin/vibee koschei           # Development cycle
```
