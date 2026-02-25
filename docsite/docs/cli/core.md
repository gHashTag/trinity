---
sidebar_position: 2
sidebar_label: Core Commands
---

# Core Commands

Chat, code generation, and the SWE (Software Engineering) agent.

## chat

Interactive chat with vision, voice, and tool support.

```bash
tri chat [message]
tri chat "Explain ternary computing"
```

In REPL mode, type any message directly to chat.

## code

Generate code from a natural language prompt.

```bash
tri code [prompt]
tri code "Write a Fibonacci function in Zig"
tri code --stream "Implement a binary search"   # Typing effect
```

## gen

Compile a `.vibee` specification into Zig or Verilog code.

```bash
tri gen <spec.vibee>
tri gen specs/tri/my_module.vibee
```

**Output:** Generated code is placed in `trinity/output/` (Zig) or `trinity/output/fpga/` (Verilog).

## SWE Agent Commands

The SWE (Software Engineering) Agent provides AI-powered code assistance:

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
