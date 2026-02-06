// ============================================================================
// MULTI-PROVIDER SELECTOR - Auto-Route to Best LLM
// ============================================================================
// Automatically selects the optimal LLM provider based on:
// - Language detection (Chinese → Zhipu, English/Russian → Groq)
// - Task type (Reasoning → Anthropic, Code → Groq, Chinese → Zhipu)
// - Availability (fallback chain)
//
// Providers:
// - Groq (Llama-3.1-8b) - Fast code gen, English/Russian
// - Zhipu (GLM-4) - Chinese language, long context
// - Anthropic (Claude) - Advanced reasoning, math proofs

const std = @import("std");
const groq = @import("groq_provider.zig");
const zhipu = @import("zhipu_provider.zig");
const anthropic = @import("anthropic_provider.zig");
const trinity_swe = @import("trinity_swe_agent.zig");

pub const MultiProvider = struct {
    allocator: std.mem.Allocator,
    groq_provider: groq.GroqProvider,
    zhipu_provider: zhipu.ZhipuProvider,
    anthropic_provider: anthropic.AnthropicProvider,

    // Statistics
    groq_calls: usize,
    zhipu_calls: usize,
    anthropic_calls: usize,
    fallback_calls: usize,

    const Self = @This();

    pub const ProviderType = enum {
        Groq,
        Zhipu,
        Anthropic,
        IGLA, // Local fallback
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .groq_provider = groq.GroqProvider.init(allocator),
            .zhipu_provider = zhipu.ZhipuProvider.init(allocator),
            .anthropic_provider = anthropic.AnthropicProvider.init(allocator),
            .groq_calls = 0,
            .zhipu_calls = 0,
            .anthropic_calls = 0,
            .fallback_calls = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.groq_provider.deinit();
        self.zhipu_provider.deinit();
        self.anthropic_provider.deinit();
    }

    /// Auto-select best provider based on prompt
    pub fn selectProvider(self: *Self, prompt: []const u8, task_type: TaskType) ProviderType {
        const lang = trinity_swe.TrinitySWEAgent.detectInputLanguage(prompt);

        // Chinese → Zhipu (if configured)
        if (lang == .Chinese and self.zhipu_provider.isConfigured()) {
            return .Zhipu;
        }

        // Reasoning/Math → Anthropic (if configured)
        if ((task_type == .Reasoning or task_type == .Math) and self.anthropic_provider.isConfigured()) {
            return .Anthropic;
        }

        // Default → Groq (fast, general purpose)
        if (self.groq_provider.isConfigured()) {
            return .Groq;
        }

        // Fallback → IGLA local
        return .IGLA;
    }

    /// Generate code with auto-routing
    pub fn generate(self: *Self, prompt: []const u8, task_type: TaskType, context: ?[]const u8) !GenerateResult {
        const provider_type = self.selectProvider(prompt, task_type);
        const start = std.time.microTimestamp();

        const code = switch (provider_type) {
            .Groq => blk: {
                self.groq_calls += 1;
                if (context) |ctx| {
                    break :blk try self.groq_provider.generateWithContext(prompt, ctx);
                } else {
                    break :blk try self.groq_provider.generateZigCode(prompt);
                }
            },
            .Zhipu => blk: {
                self.zhipu_calls += 1;
                if (context) |ctx| {
                    break :blk try self.zhipu_provider.generateWithContext(prompt, ctx);
                } else {
                    break :blk try self.zhipu_provider.generateZigCode(prompt);
                }
            },
            .Anthropic => blk: {
                self.anthropic_calls += 1;
                if (context) |ctx| {
                    break :blk try self.anthropic_provider.generateWithReasoning(prompt, ctx);
                } else {
                    break :blk try self.anthropic_provider.generateZigCode(prompt);
                }
            },
            .IGLA => blk: {
                self.fallback_calls += 1;
                break :blk try self.allocator.dupe(u8, "// IGLA fallback - no LLM configured");
            },
        };

        const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));

        return GenerateResult{
            .code = code,
            .provider = provider_type,
            .elapsed_us = elapsed,
        };
    }

    /// Get available providers status
    pub fn getStatus(self: *const Self) ProviderStatus {
        return ProviderStatus{
            .groq_available = self.groq_provider.isConfigured(),
            .zhipu_available = self.zhipu_provider.isConfigured(),
            .anthropic_available = self.anthropic_provider.isConfigured(),
            .groq_calls = self.groq_calls,
            .zhipu_calls = self.zhipu_calls,
            .anthropic_calls = self.anthropic_calls,
            .fallback_calls = self.fallback_calls,
        };
    }
};

pub const TaskType = enum {
    CodeGen,
    Reasoning,
    Math,
    Explanation,
    BugFix,
    Generic,
};

pub const GenerateResult = struct {
    code: []const u8,
    provider: MultiProvider.ProviderType,
    elapsed_us: u64,
};

pub const ProviderStatus = struct {
    groq_available: bool,
    zhipu_available: bool,
    anthropic_available: bool,
    groq_calls: usize,
    zhipu_calls: usize,
    anthropic_calls: usize,
    fallback_calls: usize,
};

// ============================================================================
// MAIN - Demo
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("============================================================\n", .{});
    std.debug.print("  MULTI-PROVIDER SELECTOR\n", .{});
    std.debug.print("  Auto-Route: Chinese→Zhipu, Reasoning→Anthropic, Code→Groq\n", .{});
    std.debug.print("============================================================\n", .{});

    var provider = MultiProvider.init(allocator);
    defer provider.deinit();

    // Show status
    const status = provider.getStatus();
    std.debug.print("\nProvider Status:\n", .{});
    std.debug.print("  Groq (Llama-3.1): {s}\n", .{if (status.groq_available) "READY" else "NOT CONFIGURED"});
    std.debug.print("  Zhipu (GLM-4): {s}\n", .{if (status.zhipu_available) "READY" else "NOT CONFIGURED"});
    std.debug.print("  Anthropic (Claude): {s}\n", .{if (status.anthropic_available) "READY" else "NOT CONFIGURED"});

    // Test prompts
    const test_cases = [_]struct { prompt: []const u8, task: TaskType }{
        .{ .prompt = "Write hello world in Zig", .task = .CodeGen },
        .{ .prompt = "用Zig写一个hello world", .task = .CodeGen },
        .{ .prompt = "Prove phi^2 + 1/phi^2 = 3", .task = .Math },
        .{ .prompt = "Generate fibonacci function", .task = .CodeGen },
    };

    std.debug.print("\n", .{});
    for (test_cases) |tc| {
        std.debug.print("------------------------------------------------------------\n", .{});
        std.debug.print("Prompt: \"{s}\"\n", .{tc.prompt});
        std.debug.print("Task: {s}\n", .{@tagName(tc.task)});

        const selected = provider.selectProvider(tc.prompt, tc.task);
        std.debug.print("Selected: {s}\n", .{@tagName(selected)});

        if (selected != .IGLA) {
            const result = provider.generate(tc.prompt, tc.task, null) catch |err| {
                std.debug.print("Error: {any}\n\n", .{err});
                continue;
            };
            defer allocator.free(result.code);

            std.debug.print("Provider: {s}\n", .{@tagName(result.provider)});
            std.debug.print("Time: {d}us\n", .{result.elapsed_us});
            std.debug.print("Code:\n{s}\n", .{result.code[0..@min(result.code.len, 200)]});
        } else {
            std.debug.print("Skipping (no LLM configured)\n", .{});
        }
        std.debug.print("\n", .{});
    }

    // Final stats
    const final_status = provider.getStatus();
    std.debug.print("============================================================\n", .{});
    std.debug.print("  STATISTICS\n", .{});
    std.debug.print("============================================================\n", .{});
    std.debug.print("  Groq calls: {d}\n", .{final_status.groq_calls});
    std.debug.print("  Zhipu calls: {d}\n", .{final_status.zhipu_calls});
    std.debug.print("  Anthropic calls: {d}\n", .{final_status.anthropic_calls});
    std.debug.print("  IGLA fallbacks: {d}\n", .{final_status.fallback_calls});
    std.debug.print("============================================================\n", .{});
    std.debug.print("  phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL\n", .{});
    std.debug.print("============================================================\n", .{});
}
