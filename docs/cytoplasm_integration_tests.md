# Cytoplasm Integration Tests

## Test Workflows

### 1. Cell Check + Fix-Bio + Coverage
```bash
tri cell check --auto-register --yes && tri cell fix-bio --all && tri cell coverage
```

Tests:
- Auto-registration of new cells
- Biology section auto-fix
- Test coverage reporting

### 2. Deps Validate + Health
```bash
tri cell deps --validate && tri cell health
```

Tests:
- Dependency validation (threshold 0.8)
- Health score computation
- Cycle detection

## Unit Tests

Integration tests in cytoplasm.zig:
- test "integration: check command parses flags correctly"
- test "integration: deps --validate handles edge cases"
- test "integration: health command computes scores"
- test "integration: fix-bio with --all flag"
- test "integration: coverage with threshold"

