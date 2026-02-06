// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY CLI v1.1 - Real Interactive Mode
// ═══════════════════════════════════════════════════════════════════════════════
//
// 100% Local AI Coding Assistant - Interactive REPL
// - Real stdin input (not demo simulation)
// - SWE Agent integration (CodeGen, Reason, Explain, Fix, Test)
// - Coherent responses with confidence scores
// - Chain-of-thought reasoning
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const trinity_swe = @import("trinity_swe_agent.zig");

const SWETaskType = trinity_swe.SWETaskType;
const Language = trinity_swe.Language;

// ANSI Colors
const GREEN = "\x1b[38;2;0;229;153m";
const GOLDEN = "\x1b[38;2;255;215;0m";
const WHITE = "\x1b[38;2;255;255;255m";
const GRAY = "\x1b[38;2;156;156;160m";
const RED = "\x1b[38;2;239;68;68m";
const RESET = "\x1b[0m";

const CLIState = struct {
    allocator: std.mem.Allocator,
    agent: trinity_swe.TrinitySWEAgent,
    mode: SWETaskType,
    language: Language,
    verbose: bool,
    running: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .agent = try trinity_swe.TrinitySWEAgent.init(allocator),
            .mode = .Explain,
            .language = .Zig,
            .verbose = true,
            .running = true,
        };
    }

    pub fn deinit(self: *Self) void {
        self.agent.deinit();
    }
};

fn printHeader() void {
    std.debug.print("\n", .{});
    std.debug.print("{s}╔══════════════════════════════════════════════════════════════╗{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}║     TRINITY CLI v1.1 - Interactive Mode                      ║{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}║     100% Local AI | Real Input | Coherent Output             ║{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}║     {s}φ² + 1/φ² = 3 = TRINITY{s}                                   ║{s}\n", .{ GREEN, GOLDEN, GREEN, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════════╝{s}\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});
}

fn printHelp() void {
    std.debug.print("\n{s}Commands:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}/code{s}     - Code generation mode\n", .{ GREEN, RESET });
    std.debug.print("  {s}/reason{s}   - Chain-of-thought reasoning\n", .{ GREEN, RESET });
    std.debug.print("  {s}/explain{s}  - Explain code/concepts\n", .{ GREEN, RESET });
    std.debug.print("  {s}/fix{s}      - Bug detection & fixing\n", .{ GREEN, RESET });
    std.debug.print("  {s}/test{s}     - Generate tests\n", .{ GREEN, RESET });
    std.debug.print("  {s}/doc{s}      - Generate documentation\n", .{ GREEN, RESET });
    std.debug.print("  {s}/refactor{s} - Refactoring suggestions\n", .{ GREEN, RESET });
    std.debug.print("  {s}/search{s}   - Semantic code search\n", .{ GREEN, RESET });
    std.debug.print("  {s}/zig{s}      - Set language to Zig\n", .{ GREEN, RESET });
    std.debug.print("  {s}/vibee{s}    - Set language to VIBEE\n", .{ GREEN, RESET });
    std.debug.print("  {s}/python{s}   - Set language to Python\n", .{ GREEN, RESET });
    std.debug.print("  {s}/stats{s}    - Show agent statistics\n", .{ GREEN, RESET });
    std.debug.print("  {s}/verbose{s}  - Toggle verbose mode\n", .{ GREEN, RESET });
    std.debug.print("  {s}/help{s}     - Show this help\n", .{ GREEN, RESET });
    std.debug.print("  {s}/quit{s}     - Exit CLI\n", .{ GREEN, RESET });
    std.debug.print("\n{s}Just type your prompt to use current mode ({s}explain{s}).{s}\n\n", .{ GRAY, GREEN, GRAY, RESET });
}

fn printPrompt(state: *CLIState) void {
    const mode_name = state.mode.getName();
    const lang_name = state.language.getExtension();
    std.debug.print("{s}[{s}]{s} {s}[{s}]{s} > ", .{ GREEN, mode_name, RESET, GOLDEN, lang_name, RESET });
}

fn processCommand(state: *CLIState, cmd: []const u8) void {
    if (std.mem.eql(u8, cmd, "/code")) {
        state.mode = .CodeGen;
        std.debug.print("{s}Mode: Code Generation{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/reason")) {
        state.mode = .Reason;
        std.debug.print("{s}Mode: Chain-of-Thought Reasoning{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/explain")) {
        state.mode = .Explain;
        std.debug.print("{s}Mode: Explain Code/Concepts{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/fix")) {
        state.mode = .BugFix;
        std.debug.print("{s}Mode: Bug Detection & Fixing{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/test")) {
        state.mode = .Test;
        std.debug.print("{s}Mode: Test Generation{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/doc")) {
        state.mode = .Document;
        std.debug.print("{s}Mode: Documentation Generation{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/refactor")) {
        state.mode = .Refactor;
        std.debug.print("{s}Mode: Refactoring Suggestions{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/search")) {
        state.mode = .Search;
        std.debug.print("{s}Mode: Semantic Search{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/complete")) {
        state.mode = .Complete;
        std.debug.print("{s}Mode: Code Completion{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/zig")) {
        state.language = .Zig;
        std.debug.print("{s}Language: Zig{s}\n", .{ GOLDEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/vibee")) {
        state.language = .VIBEE;
        std.debug.print("{s}Language: VIBEE{s}\n", .{ GOLDEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/python")) {
        state.language = .Python;
        std.debug.print("{s}Language: Python{s}\n", .{ GOLDEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/js") or std.mem.eql(u8, cmd, "/javascript")) {
        state.language = .JavaScript;
        std.debug.print("{s}Language: JavaScript{s}\n", .{ GOLDEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/stats")) {
        printStats(state);
    } else if (std.mem.eql(u8, cmd, "/verbose")) {
        state.verbose = !state.verbose;
        std.debug.print("{s}Verbose: {s}{s}\n", .{ GRAY, if (state.verbose) "ON" else "OFF", RESET });
    } else if (std.mem.eql(u8, cmd, "/help") or std.mem.eql(u8, cmd, "/?")) {
        printHelp();
    } else if (std.mem.eql(u8, cmd, "/quit") or std.mem.eql(u8, cmd, "/exit") or std.mem.eql(u8, cmd, "/q")) {
        state.running = false;
        std.debug.print("{s}Goodbye! φ² + 1/φ² = 3{s}\n", .{ GOLDEN, RESET });
    } else {
        std.debug.print("{s}Unknown command. Type /help for available commands.{s}\n", .{ RED, RESET });
    }
}

fn printStats(state: *CLIState) void {
    const stats = state.agent.getStats();
    std.debug.print("\n{s}═══ Agent Statistics ═══{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Requests: {d}\n", .{stats.total_requests});
    std.debug.print("  Total Time: {d}us ({d:.2}ms)\n", .{ stats.total_time_us, @as(f64, @floatFromInt(stats.total_time_us)) / 1000.0 });
    std.debug.print("  Speed: {s}{d:.1} ops/s{s}\n", .{ GREEN, stats.avg_ops_per_sec, RESET });
    std.debug.print("  Vocabulary: {d} words\n", .{stats.vocab_size});
    std.debug.print("  Mode: 100%% LOCAL\n", .{});
    std.debug.print("\n", .{});
}

fn processQuery(state: *CLIState, query: []const u8) void {
    const request = trinity_swe.SWERequest{
        .task_type = state.mode,
        .prompt = query,
        .language = state.language,
        .reasoning_steps = state.verbose,
    };

    const result = state.agent.process(request) catch |err| {
        std.debug.print("{s}Error: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    // Print output
    std.debug.print("\n", .{});
    if (result.coherent) {
        std.debug.print("{s}{s}{s}\n", .{ GREEN, result.output, RESET });
    } else {
        std.debug.print("{s}{s}{s}\n", .{ GRAY, result.output, RESET });
    }

    // Print reasoning if verbose
    if (state.verbose) {
        if (result.reasoning) |reasoning| {
            std.debug.print("\n{s}Reasoning:{s}\n", .{ GOLDEN, RESET });
            std.debug.print("{s}{s}{s}\n", .{ GRAY, reasoning, RESET });
        }

        // Print metadata
        const conf_color = if (result.confidence >= 0.9) GREEN else if (result.confidence >= 0.7) GOLDEN else GRAY;
        std.debug.print("\n{s}[Confidence: {d:.0}%% | Time: {d}us | Coherent: {s}]{s}\n", .{
            GRAY,
            result.confidence * 100,
            result.elapsed_us,
            if (result.coherent) "YES" else "NO",
            RESET,
        });
        _ = conf_color;
    }

    std.debug.print("\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = try CLIState.init(allocator);
    defer state.deinit();

    // Try to load vocabulary
    state.agent.loadVocabulary("models/embeddings/glove.6B.300d.txt", 50_000) catch {
        // Continue without vocabulary - template mode
    };

    printHeader();
    printHelp();

    const stdin_file = std.fs.File.stdin();
    var buf: [1024]u8 = undefined;

    while (state.running) {
        printPrompt(&state);

        // Read input line using low-level read
        var line_len: usize = 0;
        while (line_len < buf.len - 1) {
            const read_result = stdin_file.read(buf[line_len .. line_len + 1]) catch |err| {
                std.debug.print("{s}Input error: {}{s}\n", .{ RED, err, RESET });
                break;
            };
            if (read_result == 0) {
                // EOF
                state.running = false;
                break;
            }
            if (buf[line_len] == '\n') {
                break;
            }
            line_len += 1;
        }

        if (line_len > 0) {
            const input = buf[0..line_len];
            // Trim whitespace
            const trimmed = std.mem.trim(u8, input, " \t\r\n");

            if (trimmed.len == 0) continue;

            // Check if command
            if (trimmed[0] == '/') {
                processCommand(&state, trimmed);
            } else {
                processQuery(&state, trimmed);
            }
        } else {
            // EOF
            break;
        }
    }

    // Final stats
    printStats(&state);
    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL{s}\n", .{ GOLDEN, RESET });
}

test "cli state init" {
    const allocator = std.testing.allocator;
    var state = try CLIState.init(allocator);
    defer state.deinit();
    try std.testing.expect(state.running);
}
