# Ralph Agent Configuration

## Project: Trinity

Ternary computing framework with VSA (Vector Symbolic Architecture), BitNet LLM inference, and VIBEE compiler.

## Build Instructions

```bash
# Build library and executables
zig build

# Build Firebird LLM CLI (ReleaseFast)
zig build firebird

# Cross-platform release builds
zig build release
```

## Test Instructions

```bash
# Run ALL tests
zig build test

# Run specific test files
zig test src/vsa.zig              # VSA tests
zig test src/vm.zig               # VM tests
zig test src/firebird/b2t_integration.zig  # Firebird integration
```

## Run Instructions

```bash
# VIBEE Compiler
./bin/vibee gen <spec.vibee>      # Generate Zig code
./bin/vibee gen-multi <spec> all  # Generate for 42 languages
./bin/vibee koschei               # Show Golden Chain
./bin/vibee chat --model <path>   # Chat with model
./bin/vibee serve --port 8080     # Start HTTP server

# Benchmarks
zig build bench
```

## Code Generation Rules

**CRITICAL: ALL CODE MUST BE GENERATED FROM .vibee SPECIFICATIONS!**

### Allowed to edit
- `specs/tri/*.vibee` - Specifications (SOURCE OF TRUTH)
- `src/vibeec/*.zig` - Compiler source ONLY
- `docs/*.md` - Documentation

### Never edit (auto-generated)
- `trinity/output/*.zig`
- `trinity/output/fpga/*.v`
- `generated/*.zig`

## Golden Chain Cycle

1. Create `.vibee` specification in `specs/tri/`
2. Generate code: `./bin/vibee gen specs/tri/feature.vibee`
3. Test: `zig test trinity/output/feature.zig`
4. Write TOXIC VERDICT (harsh self-criticism)
5. Propose 3 TECH TREE options for next iteration

## Exit Criteria

```
EXIT_SIGNAL = (
    tests_pass AND
    spec_complete AND
    toxic_verdict_written AND
    tech_tree_options_proposed AND
    committed
)
```

## Notes

- Ternary values: {-1, 0, +1}
- Information density: 1.58 bits/trit
- Mathematical foundation: φ² + 1/φ² = 3 (Trinity Identity)
