// @origin(manual) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// ARENA JUDGE — LLM Judge for Battle Verdicts
// ═══════════════════════════════════════════════════════════════════════════════
//
// Calls an external LLM to compare responses A vs B
// Outputs: verdict (a_wins/b_wins/tie) + reasoning
// Supports length-bias correction and strength-of-win
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("types.zig");
const external_api = @import("external_api.zig");
const Allocator = std.mem.Allocator;

/// Strength of win (for richer ELO models later)
pub const WinStrength = enum {
    much_better,
    slightly_better,
    tie,

    pub fn toString(self: WinStrength) []const u8 {
        return switch (self) {
            .much_better => "much_better",
            .slightly_better => "slightly_better",
            .tie => "tie",
        };
    }
};

/// Judge result
pub const JudgeResult = struct {
    verdict: types.Verdict,
    strength: WinStrength,
    reasoning: []const u8, // allocated
    raw_response: []const u8, // full judge response, allocated
    judge_model: []const u8, // which model judged, allocated
    latency_ms: u64,
};

/// Length-bias threshold: if winner is >2x longer and strength is only "slightly_better",
/// downgrade to tie (WildBench-style debiasing)
const LENGTH_BIAS_RATIO: f64 = 2.0;

/// Build the judge prompt
fn buildJudgePrompt(allocator: Allocator, task_prompt: []const u8, response_a: []const u8, response_b: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator,
        \\You are an impartial judge evaluating two AI responses to a task.
        \\
        \\## Task
        \\{s}
        \\
        \\## Response A
        \\{s}
        \\
        \\## Response B
        \\{s}
        \\
        \\## Instructions
        \\Compare the two responses on: correctness, completeness, clarity, and reasoning quality.
        \\
        \\Output EXACTLY one JSON object (no markdown, no explanation outside the JSON):
        \\{{"verdict": "a_wins" | "b_wins" | "tie", "strength": "much_better" | "slightly_better" | "tie", "reasoning": "brief explanation"}}
    , .{ task_prompt, response_a, response_b });
}

/// Judge a battle: call external LLM to compare responses
pub fn judgeBattle(
    allocator: Allocator,
    task_prompt: []const u8,
    response_a: []const u8,
    response_b: []const u8,
    judge_kind: types.FighterKind,
    judge_model: ?[]const u8,
) !JudgeResult {
    const prompt = try buildJudgePrompt(allocator, task_prompt, response_a, response_b);
    defer allocator.free(prompt);

    const result = try external_api.complete(
        allocator,
        judge_kind,
        judge_model,
        null, // default endpoint
        prompt,
    );

    const raw = result.response;
    const model_name = result.model;
    const latency = result.latency_ms;

    // Parse verdict from response
    var verdict: types.Verdict = .tie;
    var strength: WinStrength = .tie;
    var reasoning: []const u8 = try allocator.dupe(u8, "Could not parse judge response");

    // Try to extract verdict from JSON
    if (std.mem.indexOf(u8, raw, "\"a_wins\"")) |_| {
        verdict = .a_wins;
    } else if (std.mem.indexOf(u8, raw, "\"b_wins\"")) |_| {
        verdict = .b_wins;
    }

    // Extract strength
    if (std.mem.indexOf(u8, raw, "\"much_better\"")) |_| {
        strength = .much_better;
    } else if (std.mem.indexOf(u8, raw, "\"slightly_better\"")) |_| {
        strength = .slightly_better;
    }

    // Extract reasoning field
    if (extractReasoning(allocator, raw)) |r| {
        allocator.free(reasoning);
        reasoning = r;
    } else |_| {}

    // Length-bias correction
    if (verdict != .tie and strength == .slightly_better) {
        const len_a: f64 = @floatFromInt(response_a.len);
        const len_b: f64 = @floatFromInt(response_b.len);
        const ratio = if (verdict == .a_wins) len_a / @max(len_b, 1.0) else len_b / @max(len_a, 1.0);

        if (ratio > LENGTH_BIAS_RATIO) {
            verdict = .tie;
            strength = .tie;
            const new_reasoning = try std.fmt.allocPrint(
                allocator,
                "[length-bias corrected to tie] {s}",
                .{reasoning},
            );
            allocator.free(reasoning);
            reasoning = new_reasoning;
        }
    }

    return .{
        .verdict = verdict,
        .strength = strength,
        .reasoning = reasoning,
        .raw_response = raw,
        .judge_model = model_name,
        .latency_ms = latency,
    };
}

/// Extract "reasoning" field from JSON response
fn extractReasoning(allocator: Allocator, json: []const u8) ![]const u8 {
    const prefix = "\"reasoning\":\"";
    const start_idx = std.mem.indexOf(u8, json, prefix) orelse return error.FieldNotFound;
    const content_start = start_idx + prefix.len;

    var result = std.array_list.Managed(u8).init(allocator);
    errdefer result.deinit();

    var i = content_start;
    while (i < json.len) : (i += 1) {
        if (json[i] == '\\' and i + 1 < json.len) {
            switch (json[i + 1]) {
                '"' => try result.append('"'),
                '\\' => try result.append('\\'),
                'n' => try result.append('\n'),
                else => {
                    try result.append('\\');
                    try result.append(json[i + 1]);
                },
            }
            i += 1;
        } else if (json[i] == '"') {
            break;
        } else {
            try result.append(json[i]);
        }
    }

    return result.toOwnedSlice();
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

test "build judge prompt" {
    const allocator = std.testing.allocator;
    const prompt = try buildJudgePrompt(allocator, "What is 2+2?", "4", "Five");
    defer allocator.free(prompt);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "What is 2+2?") != null);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "Response A") != null);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "Response B") != null);
}

test "extract reasoning" {
    const allocator = std.testing.allocator;
    const json =
        \\{"verdict":"a_wins","strength":"much_better","reasoning":"A is correct, B is wrong"}
    ;
    const r = try extractReasoning(allocator, json);
    defer allocator.free(r);
    try std.testing.expectEqualStrings("A is correct, B is wrong", r);
}

test "win strength toString" {
    try std.testing.expectEqualStrings("much_better", WinStrength.much_better.toString());
    try std.testing.expectEqualStrings("tie", WinStrength.tie.toString());
}
