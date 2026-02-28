const std = @import("std");
const moe = @import("vibeec/moe_router.zig");
const enhanced = @import("vibeec/enhanced_moe.zig");
const tools = @import("vibeec/agent_tools.zig");
const dao = @import("vibeec/dao_integration.zig");

// ============================================================================
// TRINITY: COMPETITIVE REPL (PHASE 23) - Eighth Life
// Features: Tab-complete, streaming, verbose reasoning, localization
// ============================================================================

/// Supported languages
pub const Lang = enum {
    EN,
    RU,
    TH,

    pub fn getPrompt(self: Lang) []const u8 {
        return switch (self) {
            .EN => "vibee repl> ",
            .RU => "vibee [CYR:[EN]]> ",
            .TH => "vibee เรพล> ",
        };
    }

    pub fn getWelcome(self: Lang) []const u8 {
        return switch (self) {
            .EN => "Welcome to Trinity REPL - Eighth Life: Competitive Agent",
            .RU => "[CYR:[EN]] by[CYR:[EN]]in[CYR:[EN]] in Trinity REPL - [EN]with[CYR:[EN]] [EN]and[CYR:[EN]]: [CYR:[EN]]to[CYR:[EN]] Agent",
            .TH => "ยินดีต้อนรับสู่ Trinity REPL - ชีวิตที่แปด: ตัวแทนแข่งขัน",
        };
    }
};

/// Tab completion suggestions
pub const TabCompleter = struct {
    commands: []const []const u8,

    pub fn init() TabCompleter {
        return .{
            .commands = &[_][]const u8{
                "infer",
                "stake",
                "vote",
                "jobs",
                "stats",
                "help",
                "exit",
                "benchmark",
                "optimize",
                "generate",
                "lang",
            },
        };
    }

    pub fn suggest(self: TabCompleter, prefix: []const u8) []const []const u8 {
        var count: usize = 0;
        for (self.commands) |cmd| {
            if (std.mem.startsWith(u8, cmd, prefix)) {
                count += 1;
            }
        }

        // Return matching commands (simplified - returns all if prefix empty)
        if (prefix.len == 0) return self.commands;
        return self.commands[0..@min(count, 5)];
    }
};

/// Progress indicator for streaming
pub const ProgressIndicator = struct {
    phases: []const []const u8 = &[_][]const u8{
        "💭 Thinking...",
        "📋 Planning...",
        "⚡ Executing...",
        "👁️ Observing...",
        "✅ Complete",
    },
    current: usize = 0,

    pub fn next(self: *ProgressIndicator) []const u8 {
        const phase = self.phases[self.current];
        if (self.current < self.phases.len - 1) {
            self.current += 1;
        }
        return phase;
    }

    pub fn reset(self: *ProgressIndicator) void {
        self.current = 0;
    }
};

/// Smart error suggestion
pub const ErrorSuggester = struct {
    pub fn suggestFix(error_msg: []const u8) []const u8 {
        if (std.mem.indexOf(u8, error_msg, "InvalidAmount") != null) {
            return "💡 Try: stake 1000 (minimum amount is 1000 TRI)";
        }
        if (std.mem.indexOf(u8, error_msg, "NetworkError") != null) {
            return "💡 Try: Check your connection or enable Ko Samui mode with --low-latency";
        }
        if (std.mem.indexOf(u8, error_msg, "Unknown") != null) {
            return "💡 Try: help (to see available commands)";
        }
        return "💡 Try: --verbose for detailed error info";
    }
};

/// Competitive REPL main struct
pub const CompetitiveRepl = struct {
    allocator: std.mem.Allocator,
    moe_engine: *enhanced.EnhancedMoE,
    agent_tools: tools.AgentTools,
    completer: TabCompleter,
    progress: ProgressIndicator,
    lang: Lang = .EN,
    verbose: bool = true,
    streaming: bool = true,
    running: bool = true,
    total_tasks: u64 = 0,
    total_rewards: f32 = 0.0,
    session_start: i64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, hardware: enhanced.HardwareProfile) !*Self {
        const self = try allocator.create(Self);

        self.* = .{
            .allocator = allocator,
            .moe_engine = try enhanced.EnhancedMoE.init(allocator, hardware),
            .agent_tools = tools.AgentTools.init(allocator),
            .completer = TabCompleter.init(),
            .progress = .{},
            .session_start = std.time.timestamp(),
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.agent_tools.deinit();
        self.moe_engine.deinit();
        self.allocator.destroy(self);
    }

    /// Main REPL loop
    pub fn run(self: *Self) !void {
        const stdin_file = std.fs.File{ .handle = std.posix.STDIN_FILENO };

        const stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
        var writer_buf: [4096]u8 = undefined;
        const stdout_raw = stdout_file.writer(&writer_buf);
        var stdout = struct {
            raw: @TypeOf(stdout_raw),
            pub const Error = anyerror;

            pub fn print(s: *@This(), comptime fmt: []const u8, args: anytype) Error!void {
                // Fallback: use allocPrint to avoid std.io.Writer complexity
                // We need an allocator. We can capture it from outer scope if 'self' is available, or pass it.
                // Since 's' is the wrapper, we don't have allocator.
                // Let's assume we can use a small fixed buffer for typical messages, or panic/error on huge ones?
                // Or better: access 'self.allocator' from outer scope?
                // Wait, 'self' is shadowed. We need to pass allocator or use fixed buffer.
                // Using FixedBufferStreams is safer for std.fmt without allocator.

                var buf: [4096]u8 = undefined;
                var fbs = std.io.fixedBufferStream(&buf);
                try std.fmt.format(fbs.writer(), fmt, args);
                try s.raw.file.writeAll(fbs.getWritten());
            }

            pub fn writeAll(s: *@This(), bytes: []const u8) Error!void {
                try s.raw.file.writeAll(bytes);
            }
        }{ .raw = stdout_raw };

        try self.printBanner(&stdout);

        var input_buf: [4096]u8 = undefined;

        while (self.running) {
            try stdout.print("{s}", .{self.lang.getPrompt()});

            const n = stdin_file.read(&input_buf) catch |err| {
                // Ignore would block
                if (err == error.WouldBlock) continue;
                return err;
            };

            if (n == 0) {
                // EOF
                self.running = false;
                continue;
            }

            const line = input_buf[0..n];
            if (line.len > 0) { // Just process what we read (simple read)
                const trimmed = std.mem.trim(u8, line, " \t\r\n");
                if (trimmed.len == 0) continue;

                try self.processCommand(trimmed, &stdout);
            } else {
                self.running = false;
            }
        }

        try self.printSummary(&stdout);
    }

    /// Print welcome banner
    fn printBanner(self: *Self, writer: anytype) !void {
        try writer.print("\n", .{});
        try writer.print("╔════════════════════════════════════════════════════════════════════╗\n", .{});
        try writer.print("║  🌟 EIGHTH LIFE: COMPETITIVE AGENTIC REPL                         ║\n", .{});
        try writer.print("║  {s: <66}║\n", .{self.lang.getWelcome()});
        try writer.print("║                                                                    ║\n", .{});
        try writer.print("║  Features:                                                         ║\n", .{});
        try writer.print("║  🎯 MoE Routing   │ 🔧 Self-Optimization │ 🌐 NL Parsing          ║\n", .{});
        try writer.print("║  💻 Tab-Complete  │ 📊 Benchmarks        │ 🏝️ Ko Samui Mode       ║\n", .{});
        try writer.print("║                                                                    ║\n", .{});
        try writer.print("║  Type 'help' for commands | Tab for autocomplete | 'exit' to quit ║\n", .{});
        try writer.print("╚════════════════════════════════════════════════════════════════════╝\n", .{});
        try writer.print("\n", .{});
    }

    /// Print session summary
    fn printSummary(self: *Self, writer: anytype) !void {
        const duration = std.time.timestamp() - self.session_start;
        const tool_stats = self.agent_tools.getStats();

        try writer.print("\n", .{});
        try writer.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        try writer.print("📊 Session Summary:\n", .{});
        try writer.print("   Duration: {d}s\n", .{duration});
        try writer.print("   Tasks: {d}\n", .{self.total_tasks});
        try writer.print("   Rewards: {d:.2} $TRI\n", .{self.total_rewards});
        try writer.print("   Tool calls: {d} (success rate: {d:.0}%)\n", .{ tool_stats.total, tool_stats.rate * 100 });
        try writer.print("\n   🎯 MoE Performance:\n", .{});
        self.moe_engine.benchmarkVsCompetitors();
        try writer.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        try writer.print("👋 Goodbye! Eighth Life session ended.\n\n", .{});
    }

    /// Process a command
    fn processCommand(self: *Self, input: []const u8, writer: anytype) !void {
        // Built-in commands
        if (std.mem.eql(u8, input, "exit") or std.mem.eql(u8, input, "quit")) {
            self.running = false;
            return;
        }

        if (std.mem.eql(u8, input, "help")) {
            try self.printHelp(writer);
            return;
        }

        if (std.mem.eql(u8, input, "stats")) {
            try self.printStats(writer);
            return;
        }

        if (std.mem.eql(u8, input, "benchmark")) {
            self.moe_engine.benchmarkVsCompetitors();
            return;
        }

        if (std.mem.startsWith(u8, input, "lang ")) {
            try self.setLanguage(input[5..], writer);
            return;
        }

        // Natural language task
        try self.executeTask(input, writer);
    }

    /// Execute natural language task with streaming
    fn executeTask(self: *Self, input: []const u8, writer: anytype) !void {
        self.total_tasks += 1;
        self.progress.reset();

        // Streaming output
        if (self.streaming) {
            try writer.print("\n{s}\n", .{self.progress.next()});
        }

        // Parse task
        const plan = try self.agent_tools.naturalLanguageParse(input);
        defer self.agent_tools.allocator.free(plan.steps);

        // Route through MoE
        const route = self.moe_engine.routeWithBenchmark(input);

        if (self.verbose) {
            try writer.print("🎯 MoE: {s} {s} (confidence: {d:.0}%)\n", .{
                route.selected[0].getIcon(),
                route.selected[0].getName(),
                plan.confidence * 100,
            });
        }

        if (self.streaming) {
            try writer.print("{s}\n", .{self.progress.next()});
        }

        // Show plan
        try writer.print("📋 Plan ({d} steps):\n", .{plan.steps.len});
        for (plan.steps, 0..) |step, i| {
            try writer.print("   {d}. {s} {s}\n", .{ i + 1, step.tool.getIcon(), step.description });
        }

        if (self.streaming) {
            try writer.print("{s}\n", .{self.progress.next()});
        }

        // Execute steps
        var total_reward: f32 = 0;
        for (plan.steps) |step| {
            const result = try self.agent_tools.callWithCorrection(step.tool, step.getArgs(), self.verbose);
            if (result.success) {
                try writer.print("   ✅ {s}\n", .{result.output});
                total_reward += result.reward;
            } else {
                try writer.print("   ❌ {s}\n", .{result.output});
                try writer.print("   {s}\n", .{ErrorSuggester.suggestFix(result.error_msg orelse "")});
            }
        }

        if (self.streaming) {
            try writer.print("{s}\n", .{self.progress.next()});
        }

        // Observation
        if (self.streaming) {
            try writer.print("{s}\n", .{self.progress.next()});
        }

        self.total_rewards += total_reward;
        try writer.print("💰 Reward: +{d:.2} $TRI (Total: {d:.2})\n\n", .{ total_reward, self.total_rewards });

        // Self-optimize if needed
        if (self.total_tasks % 5 == 0) {
            const action = self.moe_engine.selfOptimize();
            if (action != .NoChange) {
                try writer.print("🔧 Auto-optimization: {s}\n\n", .{@tagName(action)});
            }
        }
    }

    /// Print help
    fn printHelp(self: *Self, writer: anytype) !void {
        _ = self;
        try writer.print("\n📚 Commands:\n", .{});
        try writer.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        try writer.print("  <task>      - Natural language task (NL parsing)\n", .{});
        try writer.print("  help        - Show this help\n", .{});
        try writer.print("  stats       - Session statistics\n", .{});
        try writer.print("  benchmark   - Compare vs Cursor/Claude/Gemini\n", .{});
        try writer.print("  lang en|ru|th - Switch language\n", .{});
        try writer.print("  exit        - Exit REPL\n", .{});
        try writer.print("\n📝 Examples:\n", .{});
        try writer.print("  [CYR:[EN]]with[EN]and and[CYR:[EN]]with on Mistral-7B and [EN]with[CYR:[EN]]to[EN] earnings\n", .{});
        try writer.print("  [CYR:[EN]]and[EN]and[EN]and[CYR:[EN]] inference for Qwen2.5-Coder-7B by[EN] 8-core CPU\n", .{});
        try writer.print("  [EN]towithand[EN]and[EN]and[CYR:[EN]] earnings on [CYR:[EN]] node in Ko Samui\n", .{});
        try writer.print("\n", .{});
    }

    /// Print statistics
    fn printStats(self: *Self, writer: anytype) !void {
        const duration = std.time.timestamp() - self.session_start;
        const tool_stats = self.agent_tools.getStats();
        const moe_stats = self.moe_engine.base_router.getStats();

        try writer.print("\n📊 Session Statistics:\n", .{});
        try writer.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        try writer.print("  Duration:      {d}s\n", .{duration});
        try writer.print("  Tasks:         {d}\n", .{self.total_tasks});
        try writer.print("  Rewards:       {d:.2} $TRI\n", .{self.total_rewards});
        try writer.print("\n  🛠️ Tools:\n", .{});
        try writer.print("     Calls:      {d}\n", .{tool_stats.total});
        try writer.print("     Corrections: {d}\n", .{tool_stats.corrections});
        try writer.print("     Success:    {d:.0}%\n", .{tool_stats.rate * 100});
        try writer.print("\n  🎯 MoE Router:\n", .{});
        try writer.print("     Routes:     {d}\n", .{moe_stats.total});
        try writer.print("     🔮 Inference: {d}\n", .{moe_stats.activations[0]});
        try writer.print("     🌐 Network:   {d}\n", .{moe_stats.activations[1]});
        try writer.print("     💻 CodeGen:   {d}\n", .{moe_stats.activations[2]});
        try writer.print("     🧠 Planning:  {d}\n", .{moe_stats.activations[3]});
        try writer.print("\n", .{});
    }

    /// Set language
    fn setLanguage(self: *Self, lang_str: []const u8, writer: anytype) !void {
        if (std.mem.eql(u8, lang_str, "en")) {
            self.lang = .EN;
            try writer.print("Language set to English\n", .{});
        } else if (std.mem.eql(u8, lang_str, "ru")) {
            self.lang = .RU;
            try writer.print("[CYR:[EN]]to [EN]with[CYR:[EN]]in[CYR:[EN]] on [EN]withwithtoand[EN]\n", .{});
        } else if (std.mem.eql(u8, lang_str, "th")) {
            self.lang = .TH;
            try writer.print("ตั้งค่าภาษาเป็นไทย\n", .{});
        } else {
            try writer.print("Unknown language: {s}. Use: en, ru, th\n", .{lang_str});
        }
    }
};

// ============================================================================
// CLI ENTRY POINT
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var repl = try CompetitiveRepl.init(allocator, .{
        .cores = 8,
        .has_avx2 = true,
        .memory_gb = 16,
        .network_mbps = 10, // Ko Samui mode
    });
    defer repl.deinit();

    try repl.run();
}
