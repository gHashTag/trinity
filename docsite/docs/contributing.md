---
sidebar_position: 101
---

# Contributing

Thank you for your interest in contributing!

## Development Workflow

1. **Fork** the repository
2. **Create** a feature branch
3. **Write specification** first (`.vibee`)
4. **Generate code** with VIBEE
5. **Test** thoroughly
6. **Submit** pull request

## Code Style

- Follow Zig style guide
- Use 4-space indentation
- Add doc comments for public functions

## Commit Messages

Use conventional commits:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation

## Testing

```bash
# All tests
zig build test

# Specific module
zig test src/vsa.zig
```

## Getting Help

- [GitHub Issues](https://github.com/gHashTag/trinity/issues)
- Documentation: `/docs`
