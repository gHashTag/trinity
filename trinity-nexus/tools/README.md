# trinity-tools

**Development Tools Module** — CLI, benchmarks, utilities, AI agents

```
phi² + 1/phi² = 3 = TRINITY
```

---

## Overview

`trinity-tools` provides **development and operational tooling**:

- **Maxwell Agent** — AI-powered code analysis and generation
- **TRI Commander** — Interactive CLI for Trinity development
- **Benchmarks** — Performance testing suite
- **DevTools** — Debugger, profiler, LSP, validators
- **Utilities** — JSON, HTTP, WebSocket, circuit breakers
- **Phi-Engine** — Quantum-inspired computation engine

---

## Quick Start

```bash
# TRI Commander — Interactive CLI
zig build tri
# Or: zig build cli

# Run benchmarks
zig build bench

# Maxwell agent analysis
zig build maxwell -- analyze src/

# Format code
zig build trinity-format -- src/
```

---

## Module Structure

```
trinity-nexus/tools/src/
├── root.zig                    # Module exports
│
├── Maxwell Agent
├── maxwell/
│   ├── maxwell.zig             # Maxwell agent core
│   ├── agent_loop.zig          # Agent event loop
│   ├── code_analyzer.zig       # Code analysis
│   ├── codebase.zig            # Codebase navigation
│   ├── llm_client.zig          # LLM API client
│   ├── memory_store.zig        # Agent memory
│   └── spec_generator.zig      # .vibee spec generation
│
├── Phi-Engine
├── phi/
│   ├── akashic_records_manual.zig  # Akashic records
│   ├── ouroboros.zig               # Ouroboros cycle
│   ├── ouroboros_v2.zig            # Ouroboros v2
│   ├── quantum_coder_agent_with_akashic.zig
│   └── uroboros_final.zig          # Final uroboros
│
├── CLI / REPL
├── cli/
│   └── tri_cmd.zig             # TRI commander
│
├── Utilities
├── util/
│   ├── json_parser.zig         # JSON parser
│   ├── ffi.zig                 # FFI bindings
│   ├── package_manager.zig     # Package management
│   ├── http_client.zig         # HTTP client
│   ├── websocket.zig           # WebSocket client
│   ├── streaming_sse.zig       # Server-sent events
│   ├── circuit_breaker.zig     # Circuit breaker pattern
│   ├── autoscaling.zig         # Autoscaling logic
│   └── parallel_downloader.zig # Parallel downloads
│
├── Code Generation
├── gen/
│   ├── spec_generator.zig      # Spec generator
│   ├── batch_gen.zig           # Batch generation
│   └── spec_loader.zig         # Spec loader
│
├── DevTools
├── devtools/
│   ├── debugger.zig            # Debugger
│   ├── profiler.zig            # Profiler
│   ├── lsp.zig                 # Language Server Protocol
│   ├── lsp_server.zig          # LSP server
│   ├── error_reporter.zig      # Error reporting
│   ├── antipattern_detector.zig # Anti-pattern detection
│   ├── validate_cmd.zig        # Validation command
│   ├── trinity_format.zig      # Code formatter
│   ├── trinity_validator.zig   # Trinity validator
│   └── validation_engine.zig   # Validation engine
│
└── Benchmarks
    ├── bench/
    │   ├── suite/
    │   │   ├── bench_compression.zig
    │   │   ├── ai_models_comparison.zig
    │   │   ├── continuous_bench.zig
    │   │   ├── run_benchmarks.zig
    │   │   ├── vibee_vs_zig.zig
    │   │   └── ...
    │   ├── benchmark_trinity.zig
    │   ├── full_benchmark.zig
    │   ├── production_benchmark.zig
    │   └── full_matrix_benchmark.zig
```

---

## API Reference

### Maxwell Agent

```zig
pub const Maxwell = struct {
    allocator: Allocator,
    memory: MemoryStore,
    llm_client: LLMClient,

    pub fn init(allocator: Allocator) !Maxwell
    pub fn deinit(self: *Maxwell) void

    pub fn analyze(self: *Maxwell, codebase: []const u8) !Analysis
    pub fn generateSpec(self: *Maxwell, description: []const u8) ![]const u8
    pub fn suggestRefactor(self: *Maxwell, file: []const u8) ![]Suggestion
};
```

### Benchmarks

```zig
pub const Benchmark = struct {
    name: []const u8,
    iterations: usize,
    fn: *const fn (allocator: Allocator) !void,

    pub fn run(self: Benchmark) !Result
    pub fn compare(a: Result, b: Result) Comparison
};

pub fn runBenchmarks(allocator: Allocator, suite: []Benchmark) ![]Result
```

### DevTools

```zig
// LSP Server
pub const LSPServer = struct {
    pub fn init(allocator: Allocator) !LSPServer
    pub fn serve(self: *LSPServer, address: []const u8) !void
};

// Profiler
pub const Profiler = struct {
    pub fn start() Profiler
    pub fn stop(self: *Profiler) !Profile
    pub fn formatReport(profile: Profile, writer: anytype) !void
};
```

---

## TRI Commander

TRI Commander is the **primary CLI** for Trinity development.

```bash
# Interactive mode
zig build tri

# Commands within TRI:
> status              # Show cycle status
> tech-tree           # Show tech tree
> run-test <test>     # Run specific test
> gen <spec.vibee>    # Generate from spec
> format <path>       # Format code
> validate <path>     # Validate spec
> benchmark           # Run benchmarks
> exit                # Exit
```

---

## Benchmarks

### Running Benchmarks

```bash
# Run all benchmarks
zig build bench

# Run specific benchmark
zig test trinity-nexus/tools/bench/suite/bench_compression.zig

# Continuous benchmarking
zig build continuous-bench --interval 60
```

### Benchmark Output

```
Benchmark Results:
==================
VSA bind (n=1024):         12,345 ops/sec  (±2.3%)
VSA bundle (n=1024):       11,234 ops/sec  (±1.8%)
Ternary VM:                45,678 ops/sec  (±3.1%)
TVC operations:            8,765 ops/sec    (±4.2%)
```

---

## Maxwell Agent

Maxwell is an **AI-powered development assistant**.

### Capabilities

- **Code Analysis** — Analyze code structure and patterns
- **Spec Generation** — Generate .vibee specifications
- **Refactoring** — Suggest improvements
- **Bug Detection** — Find potential bugs
- **Documentation** — Generate docs from code

### Usage

```bash
# Analyze codebase
zig build maxwell -- analyze src/vsa/

# Generate spec from description
zig build maxwell -- gen-spec "A ternary neural network with 3 layers"

# Suggest refactorings
zig build maxwell -- refactor src/hybrid.zig
```

---

## DevTools

### LSP Server

Language Server Protocol support for editors (VSCode, neovim, etc.)

```bash
# Start LSP server
zig build lsp-server --stdio
# Or for TCP:
zig build lsp-server --socket 127.0.0.1:9001
```

### Debugger

```zig
const devtools = @import("trinity-tools").devtools;

var debugger = try devtools.debugger.init(allocator);
defer debugger.deinit();

try debugger.setBreakpoint("src/vsa.zig", 42);
try debugger.launch("./zig-out/bin/vibee");
```

### Profiler

```zig
const devtools = @import("trinity-tools").devtools;

var profiler = devtools.profiler.Profiler.start();
// ... code to profile ...
const profile = try profiler.stop();
try devtools.profiler.formatReport(profile, std.io.getStdOut());
```

---

## Utilities

### JSON Parser

```zig
const util = @import("trinity-tools").util;

const json = \\{"name": "Trinity", "version": "1.0.0"};
var parsed = try util.json_parser.parse(allocator, json);
defer parsed.deinit(allocator);

const name = parsed.object.get("name").?.string;
std.debug.print("{s}\n", .{name}); // Trinity
```

### HTTP Client

```zig
const util = @import("trinity-tools").util;

var client = try util.http_client.init(allocator);
defer client.deinit();

const response = try client.get("https://api.trinity.network/status");
std.debug.print("{d}: {s}\n", .{response.status, response.body});
```

### Circuit Breaker

```zig
const util = @import("trinity-tools").util;

var breaker = util.circuit_breaker.CircuitBreaker.init(.{
    .failure_threshold = 5,
    .timeout_ms = 30000,
});

while (breaker.call(someOperation)) {
    // Operation succeeded
}
// After 5 failures, circuit opens
```

---

## Build & Test

```bash
# From workspace root
cd trinity-nexus

# Build tools library
zig build trinity-tools

# Run tools tests
zig build test-tools

# Run TRI commander
zig build tri

# Run benchmarks
zig build bench
```

---

## Dependencies

- **trinity-core** — VSA operations, core types
- **trinity-lang** — VIBEE compiler integration
- **trinity-symb** — Knowledge graphs
- **trinity-network** — P2P networking
- **trinity-canvas** — UI components

---

## Version

```
trinity-tools v0.7.0
```

---

**φ² + 1/phi² = 3**
