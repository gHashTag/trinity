// IGLA BENCH v1.0 — Ternary Needle In A Haystack Benchmark
//
// Purpose: Measure retrieval quality of ternary LLMs (HSLM/Trinity) with NIAH-style tests
// Problem: PPL doesn't measure retrieval quality. Worker with PPL=28 but IGLA=60% is worse than PPL=30 but IGLA=95%
// Solution: Add retrieval score to evolution_state.json, used by PBT for worker selection
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const WeightFormat = enum {
    STD, // f32 baseline
    BF16, // Bfloat16
    GF16, // Gaussian Float 16
    TF3, // Ternary Float 3 {-1,0,1}

    pub fn displayName(self: WeightFormat) []const u8 {
        return switch (self) {
            .STD => "STD(f32)",
            .BF16 => "BF16",
            .GF16 => "GF16",
            .TF3 => "TF3",
        };
    }
};

pub const NeedleType = enum {
    ternary, // Three values {-1,0,1}
    numeric, // Numeric facts
    text, // Plain text
};

pub const QuestionType = enum {
    retrieve, // Single needle extraction
    multi, // Multi-needle reasoning
    ternary, // Ternary fact
    chain, // Sequential facts
};

pub const Needle = struct {
    id: []const u8,
    content: []const u8,
    type: NeedleType,
    position: usize,
    depth_percent: f32,
};

pub const Question = struct {
    id: []const u8,
    text: []const u8,
    expected_answer: []const u8,
    type: QuestionType,
    needle_id: ?[]const u8,
    difficulty: u8,
};

pub const Haystack = struct {
    id: []const u8,
    content: []const u8,
    tokens: usize,
    needles: []const Needle,
    questions: []const Question,
};

pub const IGLAResult = struct {
    question_id: []const u8,
    correct: bool,
    answer: []const u8,
    latency_ms: f32,
    tok_per_sec: f32,
};

pub const ConfigResult = struct {
    format: WeightFormat,
    context_length: usize,
    num_needles: usize,
    depth_percent: f32,
    accuracy: f32,
    latency_ms: f32,
    tok_per_sec: f32,
};

/// Generate haystack with context filler text and inserted needles
pub fn generateHaystack(allocator: Allocator, id: []const u8, context_length: usize, num_needles: usize, depth_percent: f32) !Haystack {
    _ = id;

    const filler = "Each neuron in the network represents a mathematical abstraction linking concepts through algebraic structure. ";
    const filler_tokens_per_line = 10;
    const lines_needed = context_length / filler_tokens_per_line;
    var buffer = try std.ArrayList(u8).initCapacity(allocator, context_length * 10);

    var i: usize = 0;
    while (i < lines_needed) : (i += 1) {
        try buffer.appendSlice(allocator, filler);
        try buffer.append(allocator, '\n');
    }

    var needles_list = try std.ArrayList(Needle).initCapacity(allocator, num_needles);
    const base_content_len = buffer.items.len;
    const depth_pos = @as(usize, @intFromFloat(@as(f32, @floatFromInt(context_length)) * depth_percent));

    for (0..num_needles) |n_idx| {
        const needle_id = try std.fmt.allocPrint(allocator, "needle_{d}", .{n_idx});
        const needle_content = try std.fmt.allocPrint(allocator, "Special fact #{d}: neuron {d} has value -1", .{ n_idx, n_idx * 81 });
        const insert_pos = @min(depth_pos, base_content_len - 20);

        const needle_obj = Needle{
            .id = needle_id,
            .content = needle_content,
            .type = .text,
            .position = insert_pos,
            .depth_percent = depth_percent,
        };
        try needles_list.append(allocator, needle_obj);

        try buffer.appendSlice(allocator, "\n>> FACT: ");
        try buffer.appendSlice(allocator, needle_content);
        try buffer.appendSlice(allocator, " <<\n");
    }

    var questions_list = try std.ArrayList(Question).initCapacity(allocator, num_needles);
    for (0..num_needles) |n_idx| {
        const needle_id = try std.fmt.allocPrint(allocator, "needle_{d}", .{n_idx});
        const question = Question{
            .id = try std.fmt.allocPrint(allocator, "q_{d}", .{n_idx}),
            .text = try std.fmt.allocPrint(allocator, "What value does neuron {d} have?", .{n_idx * 81}),
            .expected_answer = "-1",
            .type = .retrieve,
            .needle_id = needle_id,
            .difficulty = 1,
        };
        try questions_list.append(allocator, question);
    }

    return Haystack{
        .id = "haystack_0",
        .content = try buffer.toOwnedSlice(allocator),
        .tokens = context_length,
        .needles = try needles_list.toOwnedSlice(allocator),
        .questions = try questions_list.toOwnedSlice(allocator),
    };
}

/// Insert needle at specific position in haystack
pub fn insertNeedle(haystack: *Haystack, needle: Needle, allocator: Allocator) !void {
    _ = allocator;
    _ = haystack;
    _ = needle;
    // For now, needle insertion is handled during generateHaystack
}

/// Generate ternary-specific questions
pub fn generateTernaryQuestions(allocator: Allocator, needles: []const Needle) ![]Question {
    var questions = try std.ArrayList(Question).initCapacity(allocator, needles.len);

    for (needles, 0..) |needle, idx| {
        const question = Question{
            .id = try std.fmt.allocPrint(allocator, "ternary_q_{d}", .{idx}),
            .text = try std.fmt.allocPrint(allocator, "What ternary value: {s}?", .{needle.content}),
            .expected_answer = "-1",
            .type = .ternary,
            .needle_id = needle.id,
            .difficulty = 2,
        };
        try questions.append(allocator, question);
    }

    return try questions.toOwnedSlice(allocator);
}

/// Run inference (mock for now - will connect to HSLM serve)
pub fn runInference(allocator: Allocator, haystack: Haystack, question: Question, format: WeightFormat) !IGLAResult {
    _ = allocator;
    _ = format;

    const start = std.time.nanoTimestamp();
    // Mock inference - simulate 85% accuracy
    const ts_mod = @abs(@mod(@as(i128, start), 100));
    const truncated: u8 = @truncate(ts_mod);
    const mock_correct = @as(f32, @floatFromInt(truncated)) < 15.0;
    const latency_ns = std.time.nanoTimestamp() - start;

    var tok_per_sec: f32 = 0;
    if (latency_ns > 0) {
        const latency_sec = @as(f32, @floatFromInt(latency_ns)) / 1_000_000_000.0;
        tok_per_sec = @as(f32, @floatFromInt(haystack.tokens)) / latency_sec;
    }

    return IGLAResult{
        .question_id = question.id,
        .correct = mock_correct,
        .answer = if (mock_correct) "-1" else "0",
        .latency_ms = @as(f32, @floatFromInt(@divFloor(latency_ns, 1_000_000))),
        .tok_per_sec = tok_per_sec,
    };
}

/// Score answer by normalizing and comparing
pub fn scoreAnswer(answer: []const u8, expected: []const u8) bool {
    const normalized_answer = std.mem.trim(u8, answer, &std.ascii.whitespace);
    const normalized_expected = std.mem.trim(u8, expected, &std.ascii.whitespace);

    if (std.mem.eql(u8, normalized_answer, normalized_expected)) {
        return true;
    }

    return std.mem.indexOf(u8, normalized_expected, normalized_answer) != null;
}

/// Run full benchmark across format matrix
pub fn runFullBenchmark(allocator: Allocator, formats: []const WeightFormat, context_lengths: []const usize, num_needles_list: []const usize, depths: []const f32) ![]ConfigResult {
    var results = try std.ArrayList(ConfigResult).initCapacity(allocator, formats.len * context_lengths.len * num_needles_list.len * depths.len);

    for (formats) |format| {
        for (context_lengths) |ctx_len| {
            for (num_needles_list) |n_needles| {
                for (depths) |depth| {
                    const result = try runSingleConfig(allocator, format, ctx_len, n_needles, depth);
                    try results.append(allocator, result);
                }
            }
        }
    }

    return try results.toOwnedSlice(allocator);
}

/// Run benchmark for a single configuration
/// Returns ConfigResult with accuracy, latency, and tok_per_sec
pub fn runSingleConfig(allocator: Allocator, format: WeightFormat, context_length: usize, num_needles: usize, depth_percent: f32) !ConfigResult {
    const haystack = try generateHaystack(allocator, "single", context_length, num_needles, depth_percent);
    defer {
        allocator.free(haystack.content);
        allocator.free(haystack.needles);
        allocator.free(haystack.questions);
    }

    const start = std.time.nanoTimestamp();
    var correct_count: usize = 0;
    var total_latency_ms: f32 = 0;

    for (haystack.questions) |q| {
        const result = try runInference(allocator, haystack, q, format);
        if (result.correct) correct_count += 1;
        total_latency_ms += result.latency_ms;
    }

    const elapsed_ms = @as(f32, @floatFromInt(@divFloor(std.time.nanoTimestamp() - start, 1_000_000)));

    const accuracy = if (haystack.questions.len > 0)
        @as(f32, @floatFromInt(correct_count)) / @as(f32, @floatFromInt(haystack.questions.len))
    else
        0;

    const avg_latency_ms = if (haystack.questions.len > 0)
        total_latency_ms / @as(f32, @floatFromInt(haystack.questions.len))
    else
        0;

    const tok_per_sec = if (elapsed_ms > 0)
        @as(f32, @floatFromInt(context_length)) / (elapsed_ms / 1000.0)
    else
        0;

    return ConfigResult{
        .format = format,
        .context_length = context_length,
        .num_needles = num_needles,
        .depth_percent = depth_percent,
        .accuracy = accuracy,
        .latency_ms = avg_latency_ms,
        .tok_per_sec = tok_per_sec,
    };
}

/// Parse format string to WeightFormat (for integration with evolution.zig)
pub fn parseFormatString(format_str: []const u8) WeightFormat {
    if (std.mem.eql(u8, format_str, "bf16")) return .BF16;
    if (std.mem.eql(u8, format_str, "gf16")) return .GF16;
    if (std.mem.eql(u8, format_str, "tf3")) return .TF3;
    if (std.mem.eql(u8, format_str, "gf16tf3")) return .GF16; // Hybrid defaults to GF16
    return .STD; // Default
}

test "igla_bench_generateHaystack" {
    const allocator = std.testing.allocator;

    const haystack = try generateHaystack(allocator, "test", 243, 1, 0.5);
    defer {
        allocator.free(haystack.content);
        allocator.free(haystack.needles);
        allocator.free(haystack.questions);
    }

    try std.testing.expectEqual(haystack.tokens, 243);
    try std.testing.expectEqual(haystack.needles.len, 1);
    try std.testing.expectEqual(haystack.questions.len, 1);
}

test "igla_bench_scoreAnswer" {
    try std.testing.expect(scoreAnswer("-1", "-1") == true);
    try std.testing.expect(scoreAnswer("  -1  ", "-1") == true);
    try std.testing.expect(scoreAnswer("0", "-1") == false);
}

test "igla_bench_runInference" {
    const allocator = std.testing.allocator;

    const haystack = try generateHaystack(allocator, "test", 81, 1, 0.5);
    defer {
        allocator.free(haystack.content);
        allocator.free(haystack.needles);
        allocator.free(haystack.questions);
    }

    const result = try runInference(allocator, haystack, haystack.questions[0], .GF16);
    try std.testing.expect(result.latency_ms >= 0);
}

test "igla_bench_runFullBenchmark" {
    const allocator = std.testing.allocator;

    const formats = [_]WeightFormat{.STD};
    const ctxs = [_]usize{27};
    const needles = [_]usize{1};
    const depths = [_]f32{0.5};

    const results = try runFullBenchmark(allocator, &formats, &ctxs, &needles, &depths);
    defer allocator.free(results);

    try std.testing.expectEqual(results.len, 1);
    try std.testing.expect(results[0].format == .STD);
    try std.testing.expect(results[0].context_length == 27);
}

test "igla_bench_runSingleConfig" {
    const allocator = std.testing.allocator;

    const result = try runSingleConfig(allocator, .GF16, 81, 1, 0.5);

    try std.testing.expectEqual(result.format, .GF16);
    try std.testing.expectEqual(result.context_length, 81);
    try std.testing.expectEqual(result.num_needles, 1);
    try std.testing.expect(result.accuracy >= 0 and result.accuracy <= 1);
    try std.testing.expect(result.latency_ms >= 0);
}

test "igla_bench_parseFormatString" {
    try std.testing.expect(parseFormatString("std") == .STD);
    try std.testing.expect(parseFormatString("bf16") == .BF16);
    try std.testing.expect(parseFormatString("gf16") == .GF16);
    try std.testing.expect(parseFormatString("tf3") == .TF3);
    try std.testing.expect(parseFormatString("gf16tf3") == .GF16);
    try std.testing.expect(parseFormatString("unknown") == .STD);
}
