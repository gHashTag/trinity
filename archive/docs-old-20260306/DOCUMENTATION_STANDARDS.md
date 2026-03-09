# Documentation Standards

> Guidelines for writing and maintaining Trinity documentation

---

## File Naming

### Conventions

| Pattern | Use |
|---------|-----|
| `UPPERCASE.md` | Main documentation files |
| `lowercase.md` | Chapter/section files |
| `*_API.md` | API reference |
| `*_RU.md` | Russian translations |

### Examples

```
QUICKSTART.md       # Getting started guide
VSA_API.md          # VSA API reference
TROUBLESHOOTING.md  # Troubleshooting guide
ROADMAP.md          # Project roadmap
ROADMAP_RU.md       # Russian translation
```

---

## Document Structure

### Standard Template

```markdown
# Document Title

> Brief one-line description

---

## Overview

Introduction paragraph explaining the topic.

---

## Section 1

### Subsection 1.1

Content...

### Subsection 1.2

Content...

---

## Section 2

Content...

---

## See Also

- [Related Doc 1](path/to/doc1.md)
- [Related Doc 2](path/to/doc2.md)
```

---

## Writing Style

### General

- Use clear, concise language
- Write in present tense
- Use active voice
- Avoid jargon (or define it)

### Headings

- Use sentence case: "Getting started" not "Getting Started"
- Keep headings short (5 words max)
- Use logical hierarchy (H1 → H2 → H3)

### Code Examples

- Always include runnable examples
- Add comments for complex code
- Show expected output

```zig
// Example: Bind two vectors
var a = HybridBigInt.random(100);
var b = HybridBigInt.random(100);
const result = vsa.bind(&a, &b);
// Result: bound vector of length 100
```

---

## Tables

Use tables for:
- Feature comparisons
- API parameters
- Configuration options

```markdown
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `size` | usize | 1000 | Vector dimension |
| `seed` | u64 | random | Random seed |
```

---

## Code Blocks

### Language Tags

| Language | Tag |
|----------|-----|
| Zig | `zig` |
| Bash | `bash` |
| YAML | `yaml` |
| JSON | `json` |
| Markdown | `markdown` |

### Example

~~~markdown
```zig
const result = vsa.bind(&a, &b);
```
~~~

---

## Links

### Internal Links

Use relative paths:
```markdown
[API Reference](../api/VSA_API.md)
[Index](../INDEX.md)
```

### External Links

Use full URLs:
```markdown
[Zig Documentation](https://ziglang.org/documentation/)
```

### Anchor Links

```markdown
[Section Name](#section-name)
```

---

## Images

### Placement

Store in `docs/images/`:
```markdown
![Diagram](images/architecture.png)
```

### Alt Text

Always include descriptive alt text:
```markdown
![VSA bind operation showing two vectors combined](images/vsa-bind.png)
```

---

## API Documentation

### Function Template

```markdown
### functionName(params) → ReturnType

Brief description.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `param1` | Type | Description |

**Returns:** Description of return value.

**Example:**
\`\`\`zig
const result = functionName(arg1, arg2);
\`\`\`

**See Also:** [Related Function](#related)
```

---

## Version History

For documents that change frequently:

```markdown
---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.1 | 2026-02 | Added X section |
| 1.0 | 2026-01 | Initial version |
```

---

## Localization

### File Naming

- English (default): `DOCUMENT.md`
- Russian: `DOCUMENT_RU.md`

### Keeping in Sync

When updating English docs:
1. Note changes needed in `_RU.md` version
2. Update translation or mark as outdated

---

## Review Checklist

Before committing documentation:

- [ ] Spelling and grammar checked
- [ ] Code examples tested
- [ ] Links verified
- [ ] Table of contents updated (if applicable)
- [ ] Cross-references added
- [ ] Consistent formatting

---

## Tools

### Markdown Linting

```bash
# Install markdownlint
npm install -g markdownlint-cli

# Run linter
markdownlint docs/**/*.md
```

### Link Checking

```bash
# Check for broken links
find docs -name "*.md" -exec grep -l "\]\(" {} \;
```

---

## See Also

- [INDEX.md](INDEX.md) — Documentation index
- [CONTRIBUTING.md](../CONTRIBUTING.md) — Contribution guidelines
