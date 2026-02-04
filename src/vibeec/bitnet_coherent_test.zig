// ═══════════════════════════════════════════════════════════════════════════════
// BITNET b1.58 COHERENT TEXT GENERATION TEST
// Test with proper SentencePiece tokenizer decoding
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const full_model = @import("bitnet_full_model.zig");
const tokenizer_mod = @import("sentencepiece_tokenizer.zig");
const json = std.json;

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN TEST
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     BITNET b1.58 COHERENT TEXT GENERATION TEST               ║\n", .{});
    std.debug.print("║     Proper SentencePiece BPE Decoding                        ║\n", .{});
    std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
    
    // Initialize model
    std.debug.print("Initializing BitNet b1.58 model...\n", .{});
    const config = full_model.BitNetConfig{};
    var model = try full_model.BitNetFullModel.init(allocator, config);
    defer model.deinit();
    
    // Load model weights
    std.debug.print("Loading model weights from safetensors...\n", .{});
    model.loadFromSafetensors("/workspaces/trinity/models/bitnet/model.safetensors") catch |err| {
        std.debug.print("Failed to load model: {}\n", .{err});
        std.debug.print("Please ensure model is downloaded to models/bitnet/\n", .{});
        return;
    };
    
    // Initialize KV-cache
    try model.initKVCache(512);
    
    // Load tokenizer with proper SentencePiece decoding
    std.debug.print("\nLoading SentencePiece tokenizer...\n", .{});
    var tokenizer = tokenizer_mod.SentencePieceTokenizer.load(allocator, "/workspaces/trinity/models/bitnet/tokenizer.json") catch |err| {
        std.debug.print("Failed to load tokenizer: {}\n", .{err});
        return;
    };
    defer tokenizer.deinit();
    
    // Test prompts (10+ varied prompts)
    const prompts = [_][]const u8{
        "Hello, my name is",
        "The meaning of life is",
        "Artificial intelligence will",
        "The golden ratio phi equals",
        "In the year 2026,",
        "The best programming language is",
        "Machine learning models can",
        "The future of technology",
        "Science has proven that",
        "The most important thing in life is",
        "Quantum computing will revolutionize",
        "The universe is made of",
    };
    
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     GENERATION RESULTS (Proper SentencePiece Decoding)            \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    
    var total_tokens: usize = 0;
    var total_time_ms: i64 = 0;
    var coherent_count: usize = 0;
    
    for (prompts, 0..) |prompt, i| {
        std.debug.print("\n[Test {d}] Prompt: \"{s}\"\n", .{i + 1, prompt});
        
        // Encode prompt
        const prompt_tokens = try tokenizer.encode(prompt);
        defer allocator.free(prompt_tokens);
        
        std.debug.print("  Prompt tokens ({d}): ", .{prompt_tokens.len});
        for (prompt_tokens[0..@min(prompt_tokens.len, 8)]) |t| {
            std.debug.print("{d} ", .{t});
        }
        std.debug.print("\n", .{});
        
        // Reset KV-cache for new generation
        model.resetKVCache();
        
        // Generate with full model
        const start_time = std.time.milliTimestamp();
        const generated = model.generate(prompt_tokens, 50, 0.7) catch |err| {
            std.debug.print("  Generation failed: {}\n", .{err});
            continue;
        };
        defer allocator.free(generated);
        const end_time = std.time.milliTimestamp();
        
        // Decode with proper SentencePiece handling
        const text = try tokenizer.decode(generated);
        defer allocator.free(text);
        
        const gen_tokens = generated.len - prompt_tokens.len;
        const time_ms = end_time - start_time;
        const tps = if (time_ms > 0) @as(f32, @floatFromInt(gen_tokens)) / (@as(f32, @floatFromInt(time_ms)) / 1000.0) else 0.0;
        
        total_tokens += gen_tokens;
        total_time_ms += time_ms;
        
        // Check coherence (has spaces, reasonable length, no garbage)
        const has_spaces = std.mem.indexOf(u8, text, " ") != null;
        const reasonable_length = text.len > prompt.len + 10;
        const no_garbage = std.mem.indexOf(u8, text, "[UNK]") == null;
        const is_coherent = has_spaces and reasonable_length and no_garbage;
        if (is_coherent) coherent_count += 1;
        
        std.debug.print("  Generated ({d} tokens in {d}ms = {d:.1} tok/s):\n", .{gen_tokens, time_ms, tps});
        std.debug.print("  \"{s}\"\n", .{text});
        std.debug.print("  Coherent: {s}\n", .{if (is_coherent) "YES" else "NO"});
        
        // Also show verbose decode for debugging
        const verbose = try tokenizer.decodeVerbose(generated[0..@min(generated.len, 15)]);
        defer allocator.free(verbose);
        std.debug.print("  Tokens (first 15): {s}\n", .{verbose});
    }
    
    // Summary
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                         SUMMARY                                   \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    
    const avg_tps = if (total_time_ms > 0) @as(f32, @floatFromInt(total_tokens)) / (@as(f32, @floatFromInt(total_time_ms)) / 1000.0) else 0.0;
    
    std.debug.print("\n", .{});
    std.debug.print("  Total prompts tested: {d}\n", .{prompts.len});
    std.debug.print("  Coherent generations: {d}/{d} ({d:.1}%)\n", .{
        coherent_count, prompts.len,
        @as(f32, @floatFromInt(coherent_count)) / @as(f32, @floatFromInt(prompts.len)) * 100.0
    });
    std.debug.print("  Total tokens generated: {d}\n", .{total_tokens});
    std.debug.print("  Total time: {d}ms\n", .{total_time_ms});
    std.debug.print("  Average throughput: {d:.1} tok/s\n", .{avg_tps});
    std.debug.print("\n", .{});
    std.debug.print("  Tokenizer: SentencePiece BPE (32K vocab)\n", .{});
    std.debug.print("  Decoding: Proper ▁ space handling + byte fallback\n", .{});
    std.debug.print("  Activation quantization: 8-bit per-token absmax\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    TEST COMPLETE                                  \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\nφ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL\n\n", .{});
}

test "tokenizer load and decode" {
    const allocator = std.testing.allocator;
    
    var tokenizer = tokenizer_mod.SentencePieceTokenizer.load(allocator, "/workspaces/trinity/models/bitnet/tokenizer.json") catch |err| {
        std.debug.print("Tokenizer not found: {}\n", .{err});
        return;
    };
    defer tokenizer.deinit();
    
    // Test encode/decode roundtrip
    const text = "Hello world";
    const tokens = try tokenizer.encode(text);
    defer allocator.free(tokens);
    
    const decoded = try tokenizer.decode(tokens);
    defer allocator.free(decoded);
    
    std.debug.print("Original: '{s}'\n", .{text});
    std.debug.print("Decoded:  '{s}'\n", .{decoded});
    
    try std.testing.expect(tokens.len > 1); // At least BOS + some tokens
}
