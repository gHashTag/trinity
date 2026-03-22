//! STORM P5 — Model Roulette
//! Intelligent LLM model selection based on task complexity, budget, and performance
//! Supports: Claude Opus/Sonnet/Haiku, GLM-5 (z.ai), Local LLMs

const std = @import("std");
const ct = @import("cost_tracker.zig");

pub const Model = enum {
    claude_opus, // Highest quality, most expensive
    claude_sonnet, // Balanced
    claude_haiku, // Fast, cheap
    glm_5, // z.ai proxy, cost-effective
    local_llm, // Free, no API limits
    custom, // User-defined model

    pub fn jsonStringify(value: Model, allocator: std.mem.Allocator) ![]const u8 {
        const names = .{
            "claude-opus",
            "claude-sonnet",
            "claude-haiku",
            "glm-5",
            "local-llm",
            "custom",
        };
        const name = names[@intFromEnum(value)];
        return allocator.dupe(u8, name);
    }
};

pub const TaskComplexity = enum {
    trivial, // Simple formatting, 1-liners
    simple, // Basic logic, <50 LOC
    medium, // Standard feature, 50-200 LOC
    complex, // Advanced feature, 200-500 LOC
    critical, // Core infrastructure, >500 LOC
};

pub const ModelCapability = struct {
    model: Model,
    max_context: u32, // Max tokens in context
    input_cost: u64, // Cost per 1M input tokens (in cents)
    output_cost: u64, // Cost per 1M output tokens (in cents)
    avg_speed: f64, // Average tokens/second
    code_quality: f64, // 0.0-1.0 score (subjective)
    reliability: f64, // 0.0-1.0 uptime
};

// Capability data (as of 2026-03)
pub const MODEL_CAPABILITIES = [_]ModelCapability{
    // Claude Opus 4.6
    .{
        .model = .claude_opus,
        .max_context = 200_000,
        .input_cost = 1500, // $15.00 per 1M input
        .output_cost = 7500, // $75.00 per 1M output
        .avg_speed = 30.0,
        .code_quality = 0.95,
        .reliability = 0.99,
    },
    // Claude Sonnet 4.6
    .{
        .model = .claude_sonnet,
        .max_context = 200_000,
        .input_cost = 300, // $3.00 per 1M input
        .output_cost = 1500, // $15.00 per 1M output
        .avg_speed = 60.0,
        .code_quality = 0.85,
        .reliability = 0.99,
    },
    // Claude Haiku 4.5
    .{
        .model = .claude_haiku,
        .max_context = 200_000,
        .input_cost = 25, // $0.25 per 1M input
        .output_cost = 128, // $1.28 per 1M output
        .avg_speed = 120.0,
        .code_quality = 0.70,
        .reliability = 0.98,
    },
    // GLM-5 (via z.ai proxy)
    .{
        .model = .glm_5,
        .max_context = 128_000,
        .input_cost = 100, // ~$1.00 per 1M (estimated)
        .output_cost = 200, // ~$2.00 per 1M (estimated)
        .avg_speed = 45.0,
        .code_quality = 0.75,
        .reliability = 0.90,
    },
    // Local LLM (Qwen, Llama, etc.)
    .{
        .model = .local_llm,
        .max_context = 32_768,
        .input_cost = 0,
        .output_cost = 0,
        .avg_speed = 15.0, // Slower on CPU
        .code_quality = 0.60,
        .reliability = 1.0, // No network dependency
    },
};

pub const SelectionCriteria = struct {
    task_complexity: TaskComplexity,
    budget_tokens: u64 = 100_000,
    require_high_quality: bool = false,
    prefer_speed: bool = false,
    context_size: u32 = 8192,
};

pub const ModelRoulette = struct {
    allocator: std.mem.Allocator,
    capabilities: []const ModelCapability = &MODEL_CAPABILITIES,
    usage_stats: std.AutoHashMap(Model, u64),
    cost_tracker: ?*ct.CostTracker,

    pub fn init(allocator: std.mem.Allocator, tracker: ?*ct.CostTracker) !ModelRoulette {
        const usage_stats = std.AutoHashMap(Model, u64).init(allocator);
        return .{
            .allocator = allocator,
            .usage_stats = usage_stats,
            .cost_tracker = tracker,
        };
    }

    pub fn deinit(self: *ModelRoulette) void {
        self.usage_stats.deinit();
    }

    /// Select best model for task based on criteria
    pub fn select(self: *ModelRoulette, criteria: SelectionCriteria) !Model {
        var best_model: Model = .claude_sonnet; // Default
        var best_score: f64 = -1.0;

        for (self.capabilities) |cap| {
            const score = try self.scoreModel(cap, criteria);
            if (score > best_score) {
                best_score = score;
                best_model = cap.model;
            }
        }

        // Track usage
        const count = self.usage_stats.get(best_model) orelse 0;
        try self.usage_stats.put(best_model, count + 1);

        return best_model;
    }

    /// Calculate score for model (0.0 to 1.0)
    fn scoreModel(self: *ModelRoulette, cap: ModelCapability, criteria: SelectionCriteria) !f64 {
        var score = cap.code_quality * 0.4; // Base: quality 40%

        // Complexity matching
        const quality_needed: f64 = switch (criteria.task_complexity) {
            .trivial => 0.5,
            .simple => 0.6,
            .medium => 0.75,
            .complex => 0.85,
            .critical => 0.95,
        };

        if (cap.code_quality >= quality_needed) {
            score += 0.2; // Quality sufficient bonus
        } else if (criteria.require_high_quality) {
            score *= 0.5; // Penalty if quality insufficient but required
        }

        // Speed preference
        if (criteria.prefer_speed) {
            score += (cap.avg_speed / 120.0) * 0.2; // Max speed bonus
        }

        // Budget check
        const est_cost = self.estimateCost(cap, criteria.budget_tokens, criteria.budget_tokens / 2);
        const budget_cents = @as(f64, @floatFromInt(criteria.budget_tokens)) * 0.001; // Rough conversion
        if (est_cost > budget_cents) {
            score *= 0.3; // Heavy penalty if over budget
        }

        // Context size check
        if (cap.max_context < criteria.context_size) {
            score = 0.0; // Disqualify if context too small
        }

        // Reliability bonus
        score += cap.reliability * 0.1;

        return @min(score, 1.0);
    }

    /// Estimate cost in cents
    fn estimateCost(_: *ModelRoulette, cap: ModelCapability, input_tokens: u64, output_tokens: u64) f64 {
        const input_cost = @as(f64, @floatFromInt(input_tokens * cap.input_cost)) / 1_000_000.0;
        const output_cost = @as(f64, @floatFromInt(output_tokens * cap.output_cost)) / 1_000_000.0;
        return input_cost + output_cost;
    }

    /// Get model capability by enum
    pub fn getCapability(_: *ModelRoulette, model: Model) ?ModelCapability {
        for (MODEL_CAPABILITIES) |cap| {
            if (cap.model == model) return cap;
        }
        return null;
    }

    /// Get usage statistics
    pub fn getUsageStats(self: *ModelRoulette) []const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        buf.writer().print("\n📊 MODEL ROULETTE USAGE\n", .{}) catch return "";
        buf.writer().print("══════════════════════════\n", .{}) catch return "";

        var total: u64 = 0;
        var iter = self.usage_stats.iterator();
        while (iter.next()) |entry| {
            total += entry.value_ptr.*;
        }

        iter = self.usage_stats.iterator();
        while (iter.next()) |entry| {
            const percent = if (total > 0)
                @as(f64, @floatFromInt(entry.value_ptr.*)) * 100.0 / @as(f64, @floatFromInt(total))
            else
                0.0;
            buf.writer().print("{s}: {d} ({d:.1}%)\n", .{
                @tagName(entry.key_ptr.*),
                entry.value_ptr.*,
                percent,
            }) catch return "";
        }

        return buf.toOwnedSlice() catch return "";
    }

    /// Select model for specific brain zone
    pub fn selectForBrainZone(self: *ModelRoulette, zone: BrainZone) !Model {
        const complexity = switch (zone) {
            // Strategic zones need highest quality
            .dlpfc, .ofc, .acc => TaskComplexity.critical,

            // Core execution needs reliability
            .cerebellum, .hippocampus, .thalamus => TaskComplexity.complex,

            // Testing can use cheaper models
            .striatum, .coeruleus, .nigra => TaskComplexity.medium,

            // Simple checks can be fast
            .broca, .wernicke, .insula => TaskComplexity.simple,

            // Default to balanced
            else => TaskComplexity.medium,
        };

        // Critical zones require high quality (toxic verdict, security audit)
        const require_high_quality = switch (complexity) {
            .critical, .complex => true,
            else => false,
        };

        return self.select(.{
            .task_complexity = complexity,
            .budget_tokens = 50_000,
            .require_high_quality = require_high_quality,
            .context_size = 32_768,
        });
    }

    /// Get CLI argument string for selected model
    pub fn getModelCliArg(model: Model) []const u8 {
        return switch (model) {
            .claude_opus => "claude-opus-4-6",
            .claude_sonnet => "claude-sonnet-4-6",
            .claude_haiku => "claude-haiku-4-5-20251001",
            .glm_5 => "glm-5",
            .local_llm => "local",
            .custom => "custom",
        };
    }
};

pub const BrainZone = enum {
    cortex,
    dlpfc,
    ofc,
    acc,
    broca,
    wernicke,
    insula,
    hippocampus,
    amygdala,
    accumbens,
    fornix,
    striatum,
    pallidus,
    nigra,
    thalamus,
    hypothalamus,
    habenula,
    colliculus_s,
    colliculus_i,
    ruber,
    pag,
    vta,
    cerebellum,
    vermis,
    pons,
    medulla,
    coeruleus,
    raphe,
};

// ═════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════

test "ModelCapability exists for all models" {
    try std.testing.expectEqual(@as(usize, 5), MODEL_CAPABILITIES.len);
}

test "ModelRoulette init" {
    const allocator = std.testing.allocator;
    var roulette = try ModelRoulette.init(allocator, null);
    defer roulette.deinit();
    try std.testing.expectEqual(@as(usize, 0), roulette.usage_stats.count());
}

test "select for simple task" {
    const allocator = std.testing.allocator;
    var roulette = try ModelRoulette.init(allocator, null);
    defer roulette.deinit();

    const model = try roulette.select(.{
        .task_complexity = .simple,
        .budget_tokens = 10_000,
        .prefer_speed = true,
        .context_size = 4096,
    });

    // Should prefer fast/cheap model
    try std.testing.expect(model == .claude_haiku or model == .glm_5);
}

test "select for critical task" {
    const allocator = std.testing.allocator;
    var roulette = try ModelRoulette.init(allocator, null);
    defer roulette.deinit();

    const model = try roulette.select(.{
        .task_complexity = .critical,
        .budget_tokens = 1_000_000,
        .require_high_quality = true,
        .context_size = 32_768,
    });

    // Should prefer Opus for critical tasks
    try std.testing.expect(model == .claude_opus);
}

test "getCapability" {
    var roulette = try ModelRoulette.init(std.testing.allocator, null);
    defer roulette.deinit();

    const cap = roulette.getCapability(.claude_opus);
    try std.testing.expect(cap != null);
    try std.testing.expectEqual(Model.claude_opus, cap.?.model);
    try std.testing.expectEqual(@as(u32, 200_000), cap.?.max_context);
}

test "estimateCost" {
    var roulette = try ModelRoulette.init(std.testing.allocator, null);
    defer roulette.deinit();

    const opus = roulette.getCapability(.claude_opus).?;
    const cost = roulette.estimateCost(opus, 1000, 500);

    // Opus: $15/1M input, $75/1M output
    // 1000 input = $0.015, 500 output = $0.0375 = $0.0525
    try std.testing.expect(cost > 5.0 and cost < 6.0); // In cents
}

test "getModelCliArg" {
    try std.testing.expectEqualStrings("claude-opus-4-6", ModelRoulette.getModelCliArg(.claude_opus));
    try std.testing.expectEqualStrings("glm-5", ModelRoulette.getModelCliArg(.glm_5));
}

test "selectForBrainZone" {
    const allocator = std.testing.allocator;
    var roulette = try ModelRoulette.init(allocator, null);
    defer roulette.deinit();

    // OFC is critical (toxic verdict)
    const ofc_model = try roulette.selectForBrainZone(.ofc);
    try std.testing.expectEqual(Model.claude_opus, ofc_model);

    // Striatum is testing (can be cheaper)
    const striatum_model = try roulette.selectForBrainZone(.striatum);
    try std.testing.expect(ofc_model != striatum_model or striatum_model == .claude_sonnet);
}
