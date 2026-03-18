---
sidebar_position: 13
sidebar_label: Interactive REPL
---

# Interactive REPL

The TRI CLI includes a full interactive REPL (Read-Eval-Print Loop) for continuous chat, code generation, and SWE agent operations without restarting the binary.

## Starting the REPL

```bash
# Via zig build
zig build tri

# Or via the binary directly
./zig-out/bin/tri
```

When launched without arguments, TRI enters interactive mode:

```
═══════════════════════════════════════════════════════
  TRI CLI v3.0.0 — Trinity Unified CLI
  100% Local AI | Code | Chat | SWE | Swarm
  phi^2 + 1/phi^2 = 3 = TRINITY
═══════════════════════════════════════════════════════

  Mode: Chat | Language: Zig | Verbose: off
  Type a message or use /command

tri>
```

## REPL Commands

All REPL commands are prefixed with `/`. Typing text without a prefix sends it as a message in the current mode.

### Mode Switching

| Command | Mode | Description |
|---------|------|-------------|
| `/chat` | Chat | General-purpose AI conversation |
| `/code` | Code | Code generation from natural language prompts |
| `/fix` | BugFix | Detect and suggest fixes for bugs |
| `/explain` | Explain | Explain code structure or concepts |
| `/test` | Test | Generate comprehensive test suites |
| `/doc` | Document | Generate API documentation |
| `/refactor` | Refactor | Suggest refactoring improvements |
| `/reason` | Reason | Chain-of-thought reasoning mode |

**Example:**

```
tri> /code
  Mode switched to: Code Generation

tri> Write a function that computes Fibonacci numbers
  [AI generates Fibonacci function in current language]
```

### Language Switching

| Command | Language | Description |
|---------|----------|-------------|
| `/zig` | Zig | Set output language to Zig (default) |
| `/python` | Python | Set output language to Python |
| `/rust` | Rust | Set output language to Rust |
| `/js` | JavaScript | Set output language to JavaScript |
| `/javascript` | JavaScript | Alias for `/js` |

The language setting affects code generation, test generation, and documentation output.

**Example:**

```
tri> /python
  Language switched to: Python

tri> /code
tri> Implement a binary search tree
  [AI generates Python BST implementation]
```

### Utility Commands

| Command | Description |
|---------|-------------|
| `/stats` | Display session statistics |
| `/verbose` | Toggle verbose output on/off |
| `/help` | Show REPL command reference |
| `/quit` | Exit the REPL |
| `/exit` | Exit the REPL (alias for `/quit`) |
| `/q` | Exit the REPL (alias for `/quit`) |

### Session Statistics

The `/stats` command displays accumulated metrics for the current session:

```
tri> /stats

Session Statistics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SWE Requests:     12
  Chat Queries:     34
  TVC Hits:         8
  TVC Misses:       26
  LLM Calls:        18
  Vision Calls:     2
  STT Calls:        1
  Context Messages:  47
  Summarizations:    3
```

**Tracked metrics:**

| Metric | Description |
|--------|-------------|
| SWE Requests | Total fix/explain/test/doc/refactor/reason invocations |
| Chat Queries | Total chat messages sent |
| TVC Hits | Responses served from TVC corpus cache |
| TVC Misses | Responses requiring fresh LLM generation |
| LLM Calls | Total API calls to language models |
| Vision Calls | Image analysis requests (via `--image`) |
| STT Calls | Speech-to-text invocations (via `--voice`) |
| Context Messages | Messages in sliding context window |
| Summarizations | Context window overflow summarizations |

## State Management

The REPL maintains a `CLIState` struct across the session:

| Field | Default | Description |
|-------|---------|-------------|
| Mode | Chat | Current operating mode |
| Language | Zig | Current output language |
| Verbose | Off | Detailed output toggle |
| Stream | Off | Streaming output toggle |
| TVC Corpus | Loaded | 10,000-entry ternary vector cache |

### TVC Corpus Persistence

The TVC (Ternary Vector Corpus) is loaded at startup and saved on exit:

- **File:** `trinity_chat.tvc`
- **Capacity:** 10,000 entries
- **Vector dimension:** 1,000 trits
- **Threshold:** $\phi^{-1} = 0.618$

When you chat, responses are cached in TVC. Subsequent similar queries return cached responses instantly.

## Multi-Modal Support

The REPL supports multi-modal input through the `chat` command flags:

```bash
# In REPL mode, use chat with flags:
tri> chat --image photo.jpg "What's in this image?"
tri> chat --voice recording.wav "Transcribe this"
tri> chat --stream "Explain quantum computing"
```

| Flag | Description |
|------|-------------|
| `--stream` | Enable streaming (typing effect) output |
| `--image <path>` | Attach image for vision analysis |
| `--voice <path>` | Attach audio for speech-to-text |

## Provider Configuration

The REPL auto-detects available API keys from environment variables:

| Variable | Provider | Priority |
|----------|----------|----------|
| `GROQ_API_KEY` | Groq | 1 (fastest) |
| `ANTHROPIC_API_KEY` | Claude | 2 |
| `OPENAI_API_KEY` | OpenAI | 3 |

If no API key is set, TRI falls back to the local GGUF model:

- **Default path:** `models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf`

## Tips

- **Quick mode switch + query:** Type `/code` then your prompt on the next line
- **Direct chat:** Just type any text without `/` to send in current mode
- **History:** The REPL maintains a sliding context window of 20 messages
- **Context overflow:** When context exceeds the window, older messages are summarized automatically
- **Exit:** Use `/quit`, `/exit`, `/q`, or Ctrl+C

## See Also

- [Core Commands](/cli/core) — Chat, code, and SWE agent details
- [TVC Distributed Learning](/cli/tvc) — TVC corpus architecture
- [Sacred Constants](/cli/constants) — Mathematical constants reference
