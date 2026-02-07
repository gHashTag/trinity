// ═══════════════════════════════════════════════════════════════════════════════
// TEST COHERENT GENERATION - BitNet-2B Local Inference
// ═══════════════════════════════════════════════════════════════════════════════
// Tests real text generation coherence after dimension fixes:
// - head_dim: 32 (fixed from 128)
// - ffn_gate_dim: 1728
// - ffn_down_out: 640
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const model_mod = @import("src/vibeec/gguf_model.zig");
const tokenizer_mod = @import("src/vibeec/gguf_tokenizer.zig");
const inference = @import("src/vibeec/gguf_inference.zig");

const TestPrompt = struct {
    name: []const u8,
    prompt: []const u8,
    max_tokens: u32,
};

const TEST_PROMPTS = [_]TestPrompt{
    .{ .name = "Hello", .prompt = "Hello", .max_tokens = 20 },
    .{ .name = "Phi proof", .prompt = "Prove that phi squared plus one over phi squared equals three:", .max_tokens = 30 },
    .{ .name = "Zig hello", .prompt = "Write Zig code for hello world:\n```zig\n", .max_tokens = 30 },
    .{ .name = "Math", .prompt = "What is 2 + 2?", .max_tokens = 10 },
    .{ .name = "Story", .prompt = "Once upon a time", .max_tokens = 30 },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     TEST: COHERENT TEXT GENERATION - BitNet-2B Local        ║\n", .{});
    std.debug.print("║     Dimensions Fixed | M1 Pro | 100%% LOCAL                  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // Load model
    std.debug.print("Loading BitNet model...\n", .{});
    var model = model_mod.FullModel.init(allocator, "models/bitnet-2b-fixed.gguf") catch |err| {
        std.debug.print("Error loading model: {}\n", .{err});
        return;
    };
    defer model.deinit();

    // Load weights
    var timer = try std.time.Timer.start();
    try model.loadWeights();
    const load_time_ns = timer.read();
    std.debug.print("Model loaded in {d:.2}s\n\n", .{@as(f64, @floatFromInt(load_time_ns)) / 1e9});

    // Initialize tokenizer
    var tokenizer = try tokenizer_mod.Tokenizer.init(allocator, &model.reader);
    defer tokenizer.deinit();

    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    GENERATION TESTS                          ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    var total_tokens: usize = 0;
    var total_time_ms: u64 = 0;

    for (TEST_PROMPTS, 0..) |test_prompt, test_idx| {
        std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
        std.debug.print("TEST {d}: {s}\n", .{ test_idx + 1, test_prompt.name });
        std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
        std.debug.print("Prompt: \"{s}\"\n", .{test_prompt.prompt});
        std.debug.print("───────────────────────────────────────────────────────────────\n", .{});

        // Tokenize prompt
        const tokens = try tokenizer.encode(allocator, test_prompt.prompt);
        defer allocator.free(tokens);

        std.debug.print("Prompt tokens: {d}\n", .{tokens.len});

        // Generate
        const gen_start = std.time.milliTimestamp();

        var output_tokens: [256]u32 = undefined;
        var output_len: usize = 0;
        var pos: usize = 0;

        // Feed prompt
        std.debug.print("Feeding prompt...\n", .{});
        for (tokens) |token| {
            const logits = try model.forward(token, pos);
            allocator.free(logits);
            pos += 1;
        }

        // Sampling parameters for coherent generation
        const sampling_params = inference.SamplingParams{
            .temperature = 0.7,
            .top_p = 0.9,
            .top_k = 40,
            .repeat_penalty = 1.1,
        };

        // Generate new tokens
        std.debug.print("Generating: ", .{});
        var prev_token: u32 = tokens[tokens.len - 1];
        var gen_count: u32 = 0;

        while (gen_count < test_prompt.max_tokens and output_len < output_tokens.len) : (gen_count += 1) {
            const logits = try model.forward(prev_token, pos);
            defer allocator.free(logits);

            // Sample with temperature and top-p
            const max_idx = inference.sampleWithParams(allocator, logits, sampling_params) catch |err| {
                std.debug.print("[sample error: {}]", .{err});
                break;
            };

            // Check EOS
            if (max_idx == tokenizer.eos_token) {
                std.debug.print("[EOS]", .{});
                break;
            }

            output_tokens[output_len] = max_idx;
            output_len += 1;
            prev_token = max_idx;
            pos += 1;

            // Print token as it's generated
            const text = tokenizer.getToken(max_idx);
            if (text.len > 0) {
                std.debug.print("{s}", .{text});
            } else {
                std.debug.print("[{d}]", .{max_idx});
            }
        }

        const gen_time = @as(u64, @intCast(std.time.milliTimestamp() - gen_start));
        total_tokens += output_len;
        total_time_ms += gen_time;

        std.debug.print("\n", .{});
        std.debug.print("───────────────────────────────────────────────────────────────\n", .{});

        // Decode full output
        const output_text = try tokenizer.decode(allocator, output_tokens[0..output_len]);
        defer allocator.free(output_text);

        std.debug.print("Generated text: \"{s}\"\n", .{output_text});
        std.debug.print("Tokens: {d}, Time: {d}ms", .{ output_len, gen_time });
        if (output_len > 0 and gen_time > 0) {
            const tok_per_sec = @as(f64, @floatFromInt(output_len)) / (@as(f64, @floatFromInt(gen_time)) / 1000.0);
            std.debug.print(", Speed: {d:.2} tok/s", .{tok_per_sec});
        }
        std.debug.print("\n\n", .{});
    }

    // Summary
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                      SUMMARY                                 ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Total tests:        {d:>10}                              ║\n", .{TEST_PROMPTS.len});
    std.debug.print("║  Total tokens:       {d:>10}                              ║\n", .{total_tokens});
    std.debug.print("║  Total time:         {d:>10} ms                           ║\n", .{total_time_ms});
    if (total_tokens > 0 and total_time_ms > 0) {
        const avg_speed = @as(f64, @floatFromInt(total_tokens)) / (@as(f64, @floatFromInt(total_time_ms)) / 1000.0);
        std.debug.print("║  Average speed:      {d:>10.2} tok/s                      ║\n", .{avg_speed});
    }
    std.debug.print("║  Source:             100%% LOCAL                             ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL | 100%% LOCAL\n\n", .{});
}
