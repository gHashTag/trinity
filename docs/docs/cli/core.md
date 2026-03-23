---
sidebar_position: 2
sidebar_label: Core Commands
---

# Core Commands

Chat, code generation, and the SWE (Software Engineering) agent.

## chat

Interactive multi-modal chat with vision, voice, and tool support (v2.1).

```bash
tri chat [message]
tri chat "Explain ternary computing"
tri chat --stream "Tell me about phi"
tri chat --image photo.jpg "What's in this image?"
tri chat --voice recording.wav "Transcribe this"
```

**Options:**

| Flag | Description |
|------|-------------|
| `--stream` | Enable streaming output (typing effect, token-by-token) |
| `--image <path>` | Attach image file for vision analysis |
| `--voice <path>` | Attach audio file for speech-to-text processing |

**Provider priority:** Groq (fastest) > Claude > OpenAI > local GGUF

The chat system integrates with the [TVC corpus](/cli/tvc) — similar queries are served from cache (threshold: $\phi^{-1} = 0.618$) without making an LLM call.

In REPL mode, type any message directly to chat. See [Interactive REPL](/cli/repl) for details.

## code

Generate code from a natural language prompt.

```bash
tri code [prompt]
tri code "Write a Fibonacci function in Zig"
tri code --stream "Implement a binary search"   # Typing effect
```

**Options:**

| Flag | Description |
|------|-------------|
| `--stream` | Enable streaming (character-by-character typing effect) |

The output language is determined by the current language setting (default: Zig). Use `/zig`, `/python`, `/rust`, or `/js` in [REPL mode](/cli/repl) to switch.

## gen

Compile a `.vibee` specification into Zig or Verilog code.

```bash
tri gen <spec.vibee>
tri gen specs/tri/my_module.vibee
```

**Output:** Generated code is placed in `var/trinity/output/` (Zig) or `var/trinity/output/fpga/` (Verilog).

## SWE Agent Commands

The SWE (Software Engineering) Agent provides AI-powered code assistance. All SWE commands use the `TrinitySWEAgent` with multi-language support:

| Language | REPL switch | File extensions |
|----------|------------|-----------------|
| Zig | `/zig` | `.zig` |
| Python | `/python` | `.py` |
| Rust | `/rust` | `.rs` |
| JavaScript | `/js` | `.js`, `.ts` |

### fix

Detect and fix bugs in files.

```bash
tri fix [file] [description]
tri fix src/main.zig "Fix memory leak in allocator"
```

### explain

Explain code or concepts.

```bash
tri explain [file or topic]
tri explain src/vsa.zig
tri explain "How does VSA binding work?"
```

### test

Generate comprehensive tests.

```bash
tri test [file]
tri test src/vsa.zig
```

### doc

Generate documentation for code.

```bash
tri doc [file]
tri doc src/hybrid.zig
```

### refactor

Suggest and apply refactoring improvements.

```bash
tri refactor [file]
tri refactor src/vm.zig
```

### reason

Chain-of-thought reasoning about problems.

```bash
tri reason [prompt]
tri reason "What's the optimal data structure for ternary vectors?"
```

## Info Commands

### info

Display system information — version, platform, architecture, mode, vocabulary, and template counts.

```bash
tri info
```

**Example output:**

```
═══ System Information ═══
  TRI CLI Version: 3.0.0
  Platform: macos
  Architecture: aarch64
  Mode: 100% LOCAL
  Vocabulary: 50000 words
  Code Templates: 50+
  Chat Patterns: 60+

φ² + 1/φ² = 3 = TRINITY
```

### version

Show TRI CLI version.

**Aliases:** `-v`, `--version`

```bash
tri version
```

### help

Show complete command reference.

**Aliases:** `-h`, `--help`

```bash
tri help
```

## REPL Commands

These commands are available inside the interactive REPL (prefix with `/`):

| Command | Description |
|---------|-------------|
| `/chat` | Switch to chat mode |
| `/code` | Switch to code generation mode |
| `/fix` | Switch to bug fix mode |
| `/explain` | Switch to explain mode |
| `/test` | Switch to test generation mode |
| `/doc` | Switch to documentation mode |
| `/refactor` | Switch to refactor mode |
| `/reason` | Switch to reasoning mode |
| `/zig` | Set language to Zig |
| `/python` | Set language to Python |
| `/rust` | Set language to Rust |
| `/js` | Set language to JavaScript (also `/javascript`) |
| `/stats` | Show session statistics |
| `/verbose` | Toggle verbose mode |
| `/help` | Show REPL help |
| `/quit` | Exit REPL |
| `/exit` | Exit REPL (alias for `/quit`) |
| `/q` | Exit REPL (alias for `/quit`) |
