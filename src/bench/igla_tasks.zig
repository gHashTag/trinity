// IGLA TASKS v1.0 — Task Generators for IGLA Bench
//
// 4 Task Types:
//   - IGLA-RETRIEVE: Single needle extraction
//   - IGLA-MULTI: Multi-needle reasoning
//   - IGLA-TERNARY: Ternary fact verification
//   - IGLA-CHAIN: Sequential facts
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL

const std = @import("std");
const igla_bench = @import("igla_bench.zig");
const Allocator = std.mem.Allocator;

pub const TaskType = enum {
    Retrieve,  // Single needle
    Multi,     // Multi-needle
    Ternary,  // Ternary fact
    Chain,     // Sequential facts
};

/// Task configuration for generating test cases
pub const TaskConfig = struct {
    task_type: TaskType,
    context_length: usize,
    num_needles: usize,
    depth_percent: f32,
    format: igla_bench.WeightFormat,
};

/// Generate IGLA-RETRIEVE test case
/// Single needle at specified depth
pub fn generateRetrieveTask(
    allocator: Allocator,
    ctx_len: usize,
    depth_pct: f32,
    format: igla_bench.WeightFormat
) !struct {
    haystack: igla_bench.Haystack,
    questions: []const igla_bench.Question,
} {
    _ = format;
    const haystack = try igla_bench.generateHaystack(
        allocator,
        "retrieve_test",
        ctx_len,
        1,
        depth_pct,
    );

    var questions = try std.ArrayList(igla_bench.Question).initCapacity(allocator, haystack.needles.len);

    for (haystack.needles, 0..) |needle, idx| {
        const q = igla_bench.Question{
            .id = try std.fmt.allocPrint(allocator, "retrieve_{d}", .{idx}),
            .text = try std.fmt.allocPrint(allocator, "What value does neuron {d} have?", .{needle.position}),
            .expected_answer = "-1",
            .type = .retrieve,
            .needle_id = needle.id,
            .difficulty = 1,
        };
        try questions.append(allocator, q);
    }

    return .{
        .haystack = haystack,
        .questions = try questions.toOwnedSlice(allocator),
    };
}

/// Generate IGLA-MULTI test case
/// Multiple needles requiring reasoning across facts
pub fn generateMultiTask(
    allocator: Allocator,
    ctx_len: usize,
    depths: []const f32,
    format: igla_bench.WeightFormat
) !struct {
    haystack: igla_bench.Haystack,
    questions: []const igla_bench.Question,
} {
    _ = format;
    const num_needles = depths.len;
    var needles_list = try std.ArrayList(igla_bench.Needle).initCapacity(allocator, num_needles);

    for (depths, 0..) |depth, idx| {
        const needle_id = try std.fmt.allocPrint(allocator, "multi_needle_{d}", .{idx});
        const needle_content = try std.fmt.allocPrint(allocator,
            "Fact #{d} at depth {d:.0}: neuron {d} = +1", .{idx, @as(u32, @intFromFloat(depth * 100)), idx * 97});

        const position = @as(usize, @intFromFloat(@as(f32, @floatFromInt(ctx_len)) * depth));

        const needle = igla_bench.Needle{
            .id = needle_id,
            .content = needle_content,
            .type = .text,
            .position = position,
            .depth_percent = depth,
        };
        try needles_list.append(allocator, needle);
    }

    // Build haystack
    const filler = "Neural connections form complex representation patterns. ";
    var buffer = try std.ArrayList(u8).initCapacity(allocator, ctx_len * 10);

    const filler_tokens_per_line = 10;
    const lines_needed = ctx_len / filler_tokens_per_line;
    var i: usize = 0;
    while (i < lines_needed) : (i += 1) {
        try buffer.appendSlice(allocator, filler);
        try buffer.append(allocator, '\n');
    }

    // Insert all needles
    for (needles_list.items) |needle| {
        try buffer.appendSlice(allocator, "\n>> FACT: ");
        try buffer.appendSlice(allocator, needle.content);
        try buffer.appendSlice(allocator, " <<\n");
    }

    // Generate reasoning questions
    var questions = try std.ArrayList(igla_bench.Question).initCapacity(allocator, num_needles);

    for (needles_list.items, 0..) |needle, idx| {
        const q = igla_bench.Question{
            .id = try std.fmt.allocPrint(allocator, "multi_q_{d}", .{idx}),
            .text = try std.fmt.allocPrint(allocator,
                "What value does neuron {d} have (depth {d:.0}%)?",
                .{needle.position, @as(u32, @intFromFloat(needle.depth_percent * 100))}),
            .expected_answer = "+1",
            .type = .multi,
            .needle_id = needle.id,
            .difficulty = 2,
        };
        try questions.append(allocator, q);
    }

    const haystack = igla_bench.Haystack{
        .id = "multi_haystack",
        .content = try buffer.toOwnedSlice(allocator),
        .tokens = ctx_len,
        .needles = try needles_list.toOwnedSlice(allocator),
        .questions = try questions.toOwnedSlice(allocator),
    };

    return .{
        .haystack = haystack,
        .questions = try questions.toOwnedSlice(allocator),
    };
}

/// Generate IGLA-TERNARY test case
/// Verify ternary value knowledge
pub fn generateTernaryTask(
    allocator: Allocator,
    ctx_len: usize,
    format: igla_bench.WeightFormat
) !struct {
    haystack: igla_bench.Haystack,
    questions: []const igla_bench.Question,
} {
    _ = format;
    const needle_content = "neuron N=243 in block B=3 stores ternary weight -1";
    const question_text = "What ternary value does neuron 243 in block 3 have?";

    const needle = igla_bench.Needle{
        .id = "ternary_needle_0",
        .content = needle_content,
        .type = .ternary,
        .position = ctx_len / 2,
        .depth_percent = 0.5,
    };

    const question = igla_bench.Question{
        .id = "ternary_q_0",
        .text = question_text,
        .expected_answer = "-1",
        .type = .ternary,
        .needle_id = needle.id,
        .difficulty = 2,
    };

    const haystack = try igla_bench.generateHaystack(allocator, "ternary_test", ctx_len, 1, 0.5);

    return .{
        .haystack = haystack,
        .questions = &.{question},
    };
}

/// Generate IGLA-CHAIN test case
/// Sequential facts requiring multi-step reasoning
pub fn generateChainTask(
    allocator: Allocator,
    ctx_len: usize,
    num_facts: usize,
    format: igla_bench.WeightFormat
) !struct {
    haystack: igla_bench.Haystack,
    questions: []const igla_bench.Question,
} {
    _ = format;
    var needles_list = try std.ArrayList(igla_bench.Needle).initCapacity(allocator, num_facts);

    // Create sequential facts
    for (0..num_facts) |idx| {
        const needle_id = try std.fmt.allocPrint(allocator, "chain_fact_{d}", .{idx});
        const chain_value = if (idx % 2 == 0) "-1" else "+1";
        const fact_content = try std.fmt.allocPrint(allocator,
            "Chain fact #{d}: neuron {d} = {s}", .{idx, idx * 13, chain_value});

        const needle = igla_bench.Needle{
            .id = needle_id,
            .content = fact_content,
            .type = .ternary,
            .position = (idx + 1) * (ctx_len / (num_facts + 2)),
            .depth_percent = @as(f32, @floatFromInt(idx + 1)) / @as(f32, @floatFromInt(num_facts + 2)),
        };
        try needles_list.append(allocator, needle);
    }

    const haystack = try igla_bench.generateHaystack(allocator, "chain_test", ctx_len, num_facts, 0.5);

    // Generate chain reasoning questions
    var questions = try std.ArrayList(igla_bench.Question).initCapacity(allocator, num_facts);

    for (needles_list.items, 0..) |needle, idx| {
        if (idx + 1 < num_facts) {
            const next_needle = needles_list.items[idx + 1];
            const q = igla_bench.Question{
                .id = try std.fmt.allocPrint(allocator, "chain_q_{d}", .{idx}),
                .text = try std.fmt.allocPrint(allocator,
                    "What value does neuron {d} have before {d}?",
                    .{needle.position, next_needle.position}),
                .expected_answer = if (idx % 2 == 0) "-1" else "+1",
                .type = .chain,
                .needle_id = needle.id,
                .difficulty = 3,
            };
            try questions.append(allocator, q);
        }
    }

    // Final question
    const final_q = igla_bench.Question{
        .id = try std.fmt.allocPrint(allocator, "chain_final_q", .{}),
        .text = try std.fmt.allocPrint(allocator,
            "What value does the last neuron in the chain have?",
            .{}),
        .expected_answer = if ((num_facts - 1) % 2 == 0) "-1" else "+1",
        .type = .chain,
        .needle_id = needles_list.items[num_facts - 1].id,
        .difficulty = 3,
    };
    try questions.append(allocator, final_q);

    return .{
        .haystack = haystack,
        .questions = try questions.toOwnedSlice(allocator),
    };
}

test "igla_tasks_generateRetrieveTask" {
    const allocator = std.testing.allocator;

    const result = try generateRetrieveTask(allocator, 243, 0.5, .STD);
    try std.testing.expectEqual(result.haystack.needles.len, 1);
    try std.testing.expect(result.questions.len == 1);
    try std.testing.expect(result.questions[0].type == .retrieve);
}

test "igla_tasks_generateTernaryTask" {
    const allocator = std.testing.allocator;

    const result = try generateTernaryTask(allocator, 81, .GF16);
    try std.testing.expectEqual(result.haystack.tokens, 81);
    try std.testing.expect(result.questions.len == 1);
    try std.testing.expect(result.questions[0].type == .ternary);
}
