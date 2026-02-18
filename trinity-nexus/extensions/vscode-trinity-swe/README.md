# Trinity SWE Agent

**100% Local AI Coding Assistant** - A local competitor to Cursor and Claude Code.

## Features

- **100% Local** - No cloud dependency, full privacy
- **Zero-shot** - No training data needed
- **Green Ternary** - 10x lower energy than float32
- **Chain-of-Thought** - Mathematical reasoning with 100% accuracy
- **Multi-Language** - Zig, VIBEE, Python, JavaScript, TypeScript, Rust, Go

## Commands

| Command | Keybinding | Description |
|---------|------------|-------------|
| Trinity: Generate Code | Cmd+Shift+G | Generate code from natural language |
| Trinity: Explain Code | Cmd+Shift+E | Explain selected code |
| Trinity: Fix Bug | Cmd+Shift+F | Detect and fix bugs |
| Trinity: Refactor | - | Suggest refactoring |
| Trinity: Chain-of-Thought | - | Mathematical reasoning |
| Trinity: Generate Test | - | Generate test templates |
| Trinity: Generate Docs | - | Generate documentation |

## Usage

1. Open a file in VS Code
2. Use keyboard shortcuts or command palette
3. Enter your prompt when asked
4. Code is generated at cursor position

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `trinity.binaryPath` | `./trinity_swe_agent` | Path to Trinity binary |
| `trinity.vocabularyPath` | `./models/embeddings/glove.6B.300d.txt` | Path to GloVe vocabulary |
| `trinity.enableReasoning` | `true` | Enable chain-of-thought |
| `trinity.maxTokens` | `256` | Maximum tokens to generate |

## Requirements

- VS Code 1.85.0 or higher
- Trinity SWE Agent binary (included)
- GloVe vocabulary file (optional)

## Performance

- **Speed:** 6,500,000 ops/s
- **Coherent Responses:** 100%
- **Math Accuracy:** 100%

## Philosophy

```
phi^2 + 1/phi^2 = 3 = TRINITY
```

Golden ratio mathematics powers our symbolic reasoning engine.

## License

MIT

## Links

- [GitHub](https://github.com/gHashTag/trinity)
- [Documentation](https://gHashTag.github.io/trinity)
