# Contributing to Trinity

Thank you for your interest in contributing to Trinity! This document provides guidelines for contributing to the project.

## Quick Start

1. Fork the repository
2. Create a branch: `git checkout -b feat/issue-{N}`
3. Make your changes
4. Run tests: `zig build test`
5. Format code: `zig fmt src/`
6. Commit: `git commit -m "feat(scope): description (#N)"`
7. Push and create PR

## Development Environment

### Prerequisites

- **Zig 0.15.x** — Required for building the project
- **Git** — For version control
- **GitHub CLI** — Optional, for issue management

### Building

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/trinity.git
cd trinity

# Build TRI CLI
zig build tri

# Run all tests
zig build test

# Build specific components
zig build vibee          # VIBEE compiler
zig build firebird       # Firebird LLM
zig build tri-api        # Agentic loop
```

### Running Tests

```bash
# Run all tests
zig build test

# Run specific test
zig test src/vsa/vsa.zig

# Run with verbose output
zig build test -- -fno-test-exec-time
```

## Code Style

### Formatting

- Use `zig fmt` before committing
- Configure your editor to run `zig fmt` on save
- CI will check formatting automatically

### Naming Conventions

- **Functions**: `camelCase` for public, `snake_case` for private
- **Types**: `PascalCase` for structs, enums, unions
- **Constants**: `UPPER_SNAKE_CASE`
- **Files**: `snake_case.zig`

### Error Handling

```zig
// ✅ Good: Return errors
pub fn doSomething(allocator: Allocator) !void {
    const result = try mightFail();
    // ...
}

// ❌ Bad: Panic on errors
pub fn doSomething(allocator: Allocator) void {
    const result = mightFail() catch unreachable;  // Don't do this
}
```

### Memory Management

- Use explicit allocators
- Document allocator requirements
- Clean up allocations in error paths
- Prefer `defer` for cleanup

## Workflow

### Rigid Process Framework

Trinity uses a state machine for development:

```
IDLE → ACTIVE → DIRTY → TESTED → COMMITTED → SHIPPED
```

**Commands:**
```bash
tri dev start --issue <N>   # Start session for issue
tri dev test                 # Run tests
tri dev commit "msg"         # Commit with issue ID
tri dev ship                 # Mark as delivered
tri dev reset                # Reset changes
```

### Issue-Based Development

All significant changes should be tracked via GitHub issues:

1. Create or claim an issue
2. Create branch: `feat/issue-{N}` or `fix/issue-{N}`
3. Implement following the spec (if `.tri` spec exists)
4. Reference issue in commit: `feat(scope): description (#N)`
5. Create PR with `Closes #N`

### Commit Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description> (#<issue>)

[optional body]

[optional footer]
```

**Types:**
- `feat` — New feature
- `fix` — Bug fix
- `refactor` — Code refactoring
- `docs` — Documentation changes
- `test` — Adding or updating tests
- `chore` — Maintenance tasks

**Examples:**
```
feat(vsa): add hypervector similarity search (#123)
fix(cli): handle empty input in tri command (#456)
docs(readme): update installation instructions (#789)
```

## Testing

### Writing Tests

```zig
test "description of what is being tested" {
    // Arrange
    const allocator = std.testing.allocator;
    
    // Act
    const result = try functionUnderTest(allocator);
    defer allocator.free(result);
    
    // Assert
    try std.testing.expectEqual(expected, result);
}
```

### Test Coverage

- Aim for high test coverage on core modules
- Test error paths explicitly
- Include edge cases and boundary conditions
- Document non-obvious test behavior

## Documentation

### Updating Documentation

- Keep README.md in sync with code changes
- Update command registry when adding commands
- Document new APIs in appropriate `.md` files
- Run `docs-check` workflow to validate

### Code Comments

```zig
/// Brief description of what this does.
///
/// More detailed explanation if needed.
/// Can span multiple lines.
pub fn publicFunction() void {
    // Implementation comments explain WHY, not WHAT
    // (Code itself shows WHAT)
}
```

## Pull Request Process

### Before Submitting

1. **Code Review**: Self-review your changes
2. **Tests**: Ensure all tests pass
3. **Format**: Run `zig fmt src/`
4. **Docs**: Update relevant documentation
5. **Commits**: Squash fix-up commits, write clear messages

### PR Template

```markdown
## Summary
Brief description of changes.

## Related Issue
Closes #N

## Changes
- Change 1
- Change 2

## Testing
- [ ] Tests pass locally
- [ ] Added new tests for new functionality
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
```

## Getting Help

### Resources

- **Documentation**: [docs/DOCUMENTATION_INDEX.md](docs/DOCUMENTATION_INDEX.md)
- **Issues**: [GitHub Issues](https://github.com/gHashTag/trinity/issues)
- **Discussions**: [GitHub Discussions](https://github.com/gHashTag/trinity/discussions)

### Asking Questions

1. Search existing issues and discussions
2. Check documentation index
3. Create an issue with the `question` label

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
