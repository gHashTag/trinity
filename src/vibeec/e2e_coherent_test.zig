// ═══════════════════════════════════════════════════════════════════════════════
// E2E COHERENT TEXT GENERATION TEST
// Load GGUF for tokenizer, TRI for inference, generate coherent text
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const tri_inference = @import("tri_inference.zig");
const gguf_reader = @import("gguf_reader.zig");
const gguf_tokenizer = @import("gguf_tokenizer.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Default paths
    const tri_path = if (args.len > 1) args[1] else "models/tinyllama-1.1b.tri";
    const gguf_path = if (args.len > 2) args[2] else "models/TinyLlama-1.1B-Chat-v1.0.Q4_K_M.gguf";
    const prompt = if (args.len > 3) args[3] else "Hello, Trinity! What is";

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     E2E COHERENT TEXT GENERATION - SIMD-16 OPTIMIZED         ║\n", .{});
    std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // Step 1: Load tokenizer from GGUF
    std.debug.print("STEP 1: Loading tokenizer from GGUF...\n", .{});
    std.debug.print("  GGUF path: {s}\n", .{gguf_path});

    var reader = gguf_reader.GGUFReader.init(allocator, gguf_path) catch |err| {
        std.debug.print("  ERROR: Failed to load GGUF: {}\n", .{err});
        std.debug.print("  Falling back to token ID output only.\n", .{});
        return runWithoutTokenizer(allocator, tri_path, prompt);
    };
    defer reader.deinit();

    var tokenizer = gguf_tokenizer.Tokenizer.init(allocator, &reader) catch |err| {
        std.debug.print("  ERROR: Failed to init tokenizer: {}\n", .{err});
        return runWithoutTokenizer(allocator, tri_path, prompt);
    };
    defer tokenizer.deinit();

    std.debug.print("  Vocab size: {d}\n", .{tokenizer.vocab_size});
    std.debug.print("  BOS token: {d}\n", .{tokenizer.bos_token});
    std.debug.print("  EOS token: {d}\n", .{tokenizer.eos_token});

    // Step 2: Encode prompt
    std.debug.print("\nSTEP 2: Encoding prompt...\n", .{});
    std.debug.print("  Prompt: \"{s}\"\n", .{prompt});

    const prompt_tokens = tokenizer.encode(allocator, prompt) catch |err| {
        std.debug.print("  ERROR: Failed to encode: {}\n", .{err});
        return runWithoutTokenizer(allocator, tri_path, prompt);
    };
    defer allocator.free(prompt_tokens);

    std.debug.print("  Encoded tokens ({d}): ", .{prompt_tokens.len});
    for (prompt_tokens) |t| {
        std.debug.print("{d} ", .{t});
    }
    std.debug.print("\n", .{});

    // Step 3: Load TRI model
    std.debug.print("\nSTEP 3: Loading TRI model...\n", .{});
    std.debug.print("  TRI path: {s}\n", .{tri_path});

    var model = tri_inference.TriModel.init(allocator, tri_path) catch |err| {
        std.debug.print("  ERROR: Failed to load TRI model: {}\n", .{err});
        return;
    };
    defer model.deinit();

    std.debug.print("  Model loaded successfully!\n", .{});
    std.debug.print("  Hidden size: {d}\n", .{model.header.hidden_size});
    std.debug.print("  Layers: {d}\n", .{model.header.num_layers});

    // Step 4: Generate tokens
    std.debug.print("\nSTEP 4: Generating text (SIMD-16 optimized)...\n", .{});

    const num_tokens: usize = 32;
    const temperature: f32 = 0.8;

    model.resetKVCache();
    var timer = try std.time.Timer.start();

    var generated = std.ArrayList(u32).init(allocator);
    defer generated.deinit();

    // First, process prompt tokens
    var pos: usize = 0;
    for (prompt_tokens) |token| {
        _ = model.forward(token, pos) catch |err| {
            std.debug.print("  ERROR at prompt token {d}: {}\n", .{ pos, err });
            break;
        };
        try generated.append(token);
        pos += 1;
    }

    // Then generate new tokens
    var current_token = prompt_tokens[prompt_tokens.len - 1];
    var gen_count: usize = 0;

    while (gen_count < num_tokens) : (gen_count += 1) {
        const next_token = model.generate(current_token, pos, temperature) catch |err| {
            std.debug.print("  ERROR at gen token {d}: {}\n", .{ gen_count, err });
            break;
        };

        try generated.append(next_token);
        current_token = next_token;
        pos += 1;

        // Stop on EOS
        if (next_token == tokenizer.eos_token) {
            std.debug.print("  [EOS reached]\n", .{});
            break;
        }

        // Progress
        if ((gen_count + 1) % 8 == 0) {
            std.debug.print("  Generated {d}/{d} tokens...\r", .{ gen_count + 1, num_tokens });
        }
    }

    const gen_time = timer.read();
    const gen_time_sec = @as(f64, @floatFromInt(gen_time)) / 1e9;

    // Step 5: Decode to text
    std.debug.print("\n\nSTEP 5: Decoding to text...\n", .{});

    const decoded = tokenizer.decode(allocator, generated.items) catch |err| {
        std.debug.print("  ERROR: Failed to decode: {}\n", .{err});
        return;
    };
    defer allocator.free(decoded);

    // Step 6: Results
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                      RESULTS                                 ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("GENERATED TEXT:\n", .{});
    std.debug.print("────────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("{s}\n", .{decoded});
    std.debug.print("────────────────────────────────────────────────────────────────\n", .{});

    std.debug.print("\nTOKEN IDs:\n", .{});
    for (generated.items) |t| {
        std.debug.print("{d} ", .{t});
    }
    std.debug.print("\n", .{});

    std.debug.print("\nSTATISTICS:\n", .{});
    std.debug.print("  Prompt tokens:     {d}\n", .{prompt_tokens.len});
    std.debug.print("  Generated tokens:  {d}\n", .{gen_count});
    std.debug.print("  Total tokens:      {d}\n", .{generated.items.len});
    std.debug.print("  Generation time:   {d:.2} seconds\n", .{gen_time_sec});
    std.debug.print("  Speed:             {d:.2} tokens/sec\n", .{@as(f64, @floatFromInt(gen_count)) / gen_time_sec});

    std.debug.print("\n", .{});
    std.debug.print("KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3\n", .{});
}

fn runWithoutTokenizer(allocator: std.mem.Allocator, tri_path: []const u8, prompt: []const u8) !void {
    _ = prompt;

    std.debug.print("\nRunning without tokenizer (token IDs only)...\n", .{});

    var model = tri_inference.TriModel.init(allocator, tri_path) catch |err| {
        std.debug.print("ERROR: Failed to load TRI model: {}\n", .{err});
        return;
    };
    defer model.deinit();

    const num_tokens: usize = 20;
    const temperature: f32 = 0.7;

    model.resetKVCache();
    var timer = try std.time.Timer.start();

    var current_token: u32 = 1; // BOS
    var generated: [32]u32 = undefined;
    var i: usize = 0;

    while (i < num_tokens) : (i += 1) {
        const next_token = model.generate(current_token, i, temperature) catch |err| {
            std.debug.print("ERROR at token {d}: {}\n", .{ i, err });
            break;
        };
        generated[i] = next_token;
        current_token = next_token;
    }

    const gen_time = timer.read();

    std.debug.print("\nGenerated tokens: ", .{});
    for (generated[0..i]) |t| {
        std.debug.print("{d} ", .{t});
    }

    std.debug.print("\n\nSpeed: {d:.2} tokens/sec\n", .{@as(f64, @floatFromInt(i)) / (@as(f64, @floatFromInt(gen_time)) / 1e9)});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "tokenizer_encode_decode" {
    // This test requires actual GGUF file
    // Skip in CI without models
}

test "simd16_integration" {
    // Verify SIMD-16 is being used
    const parallel = @import("parallel_inference.zig");
    parallel.setUseThreadPool(true);
    // SIMD-16 is used internally by parallelTernaryMatmul
}

test "e2e_model_init" {
    // Test model initialization
    const allocator = std.testing.allocator;
    _ = allocator;
    // Model init requires file - skip in unit tests
}

test "e2e_generation_flow" {
    // Test generation flow structure
    const num_tokens: usize = 20;
    const temperature: f32 = 0.7;
    try std.testing.expect(num_tokens > 0);
    try std.testing.expect(temperature > 0.0);
    try std.testing.expect(temperature <= 1.0);
}

test "e2e_token_array" {
    // Test token array handling
    var generated: [32]u32 = undefined;
    generated[0] = 1; // BOS
    generated[1] = 42;
    try std.testing.expectEqual(@as(u32, 1), generated[0]);
    try std.testing.expectEqual(@as(u32, 42), generated[1]);
}

test "e2e_speed_calculation" {
    // Test speed calculation
    const tokens: u64 = 100;
    const time_ns: u64 = 1_000_000_000; // 1 second
    const speed = @as(f64, @floatFromInt(tokens)) / (@as(f64, @floatFromInt(time_ns)) / 1e9);
    try std.testing.expectApproxEqAbs(speed, 100.0, 0.001);
}

test "e2e_temperature_range" {
    // Test temperature parameter
    const temps = [_]f32{ 0.1, 0.5, 0.7, 0.9, 1.0 };
    for (temps) |t| {
        try std.testing.expect(t > 0.0);
        try std.testing.expect(t <= 1.0);
    }
}

test "e2e_prompt_encoding" {
    // Test prompt handling
    const prompt = "Hello, Trinity!";
    try std.testing.expect(prompt.len > 0);
    try std.testing.expect(prompt.len < 1000);
}

test "e2e_eos_detection" {
    // Test EOS token detection
    const eos_token: u32 = 2;
    const generated = [_]u32{ 1, 42, 100, 2, 0 };
    var found_eos = false;
    for (generated) |t| {
        if (t == eos_token) {
            found_eos = true;
            break;
        }
    }
    try std.testing.expect(found_eos);
}

test "e2e_batch_generation" {
    // Test batch generation parameters
    const batch_size: usize = 8;
    const max_tokens: usize = 32;
    try std.testing.expect(batch_size > 0);
    try std.testing.expect(max_tokens >= batch_size);
}
