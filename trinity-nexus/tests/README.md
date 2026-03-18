# Trinity Nexus Test Suite

> V = n × 3^k × π^m × φ^p × e^q
> φ² + 1/φ² = 3 = TRINITY

## Structure

```
tests/
├── core/           # Core VSA engine tests (trit ops, JIT, SIMD)
│   └── test_vsa.zig
├── lang/           # Language frontend tests (lexer, parser, codegen)
│   └── test_compiler.zig
├── network/        # Network layer tests (sharding, storage, consensus)
│   └── test_network.zig
├── symb/           # Symbolic engine tests (knowledge graph, TVC)
│   └── test_symb.zig
├── integration/    # Cross-module integration tests
│   └── test_integration.zig
├── e2e/            # End-to-end pipeline tests
│   └── test_e2e.zig
└── README.md
```

## Running Tests

### All tests
```bash
cd trinity-nexus && zig build test
```

### Module-specific
```bash
zig build test-core
zig build test-lang
zig build test-network
zig build test-symb
```

### Integration & E2E
```bash
zig build test-integration
zig build test-e2e
```

## Test Categories

| Category      | Module   | Description                                     |
|---------------|----------|-------------------------------------------------|
| Unit          | core     | VSA vector ops, trit encoding, JIT compilation  |
| Unit          | lang     | Lexer tokens, AST parsing, codegen output       |
| Unit          | network  | Shard management, storage, protocol handling     |
| Unit          | symb     | Knowledge graph, TVC operations, triples parsing |
| Integration   | cross    | Multi-module interactions, pipeline flows        |
| E2E           | full     | Complete spec-to-execution pipeline              |
| Benchmark     | perf     | See ../benchmarks/ for performance tests         |

## CI Integration

Tests run automatically via `.github/workflows/nexus-build.yml` on:
- Push to `ralph/*` branches
- Push to `main`
- PRs targeting `main`
- Any change under `trinity-nexus/`
