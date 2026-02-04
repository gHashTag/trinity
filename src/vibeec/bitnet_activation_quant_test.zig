// ═══════════════════════════════════════════════════════════════════════════════
// BITNET b1.58 ACTIVATION QUANTIZATION TEST
// Test coherent text generation with 8-bit activation quantization
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const full_model = @import("bitnet_full_model.zig");
const json = std.json;

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// TOKENIZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const Tokenizer = struct {
    allocator: std.mem.Allocator,
    vocab: std.StringHashMap(u32),
    id_to_token: std.AutoHashMap(u32, []const u8),
    bos_token_id: u32 = 1,
    eos_token_id: u32 = 2,
    
    pub fn load(allocator: std.mem.Allocator, path: []const u8) !Tokenizer {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        
        const content = try file.readToEndAlloc(allocator, 100 * 1024 * 1024);
        defer allocator.free(content);
        
        var parsed = try json.parseFromSlice(json.Value, allocator, content, .{});
        defer parsed.deinit();
        
        var vocab = std.StringHashMap(u32).init(allocator);
        var id_to_token = std.AutoHashMap(u32, []const u8).init(allocator);
        
        // Parse vocab from model section
        if (parsed.value.object.get("model")) |model| {
            if (model.object.get("vocab")) |vocab_obj| {
                var it = vocab_obj.object.iterator();
                while (it.next()) |entry| {
                    const token = try allocator.dupe(u8, entry.key_ptr.*);
                    const id: u32 = @intCast(entry.value_ptr.*.integer);
                    try vocab.put(token, id);
                    try id_to_token.put(id, token);
                }
            }
        }
        
        std.debug.print("Loaded tokenizer with {d} tokens\n", .{vocab.count()});
        
        return Tokenizer{
            .allocator = allocator,
            .vocab = vocab,
            .id_to_token = id_to_token,
        };
    }
    
    pub fn encode(self: *Tokenizer, text: []const u8) ![]u32 {
        var tokens = std.ArrayList(u32).init(self.allocator);
        
        // Add BOS token
        try tokens.append(self.bos_token_id);
        
        // Simple character-level fallback
        var i: usize = 0;
        while (i < text.len) {
            var found = false;
            
            // Try to match longest token first
            var max_len = @min(text.len - i, 20);
            while (max_len > 0) : (max_len -= 1) {
                const substr = text[i..i + max_len];
                if (self.vocab.get(substr)) |id| {
                    try tokens.append(id);
                    i += max_len;
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                // Unknown token, skip character
                i += 1;
            }
        }
        
        return tokens.toOwnedSlice();
    }
    
    pub fn decode(self: *Tokenizer, tokens: []const u32) ![]u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        
        for (tokens) |id| {
            if (id == self.bos_token_id or id == self.eos_token_id) continue;
            
            if (self.id_to_token.get(id)) |token| {
                // Handle special tokens like Ġ (space prefix)
                for (token) |c| {
                    if (c == 0xC4) continue; // Skip UTF-8 prefix
                    if (c == 0xA0) { // Ġ = space
                        try result.append(' ');
                    } else {
                        try result.append(c);
                    }
                }
            } else {
                try result.appendSlice("[UNK]");
            }
        }
        
        return result.toOwnedSlice();
    }
    
    pub fn deinit(self: *Tokenizer) void {
        var it = self.vocab.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.vocab.deinit();
        self.id_to_token.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN TEST
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     BITNET b1.58 ACTIVATION QUANTIZATION TEST                ║\n", .{});
    std.debug.print("║     8-bit per-token absmax quantization                      ║\n", .{});
    std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
    
    // Initialize model
    std.debug.print("Initializing BitNet b1.58 model with activation quantization...\n", .{});
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
    try model.initKVCache(256);
    
    // Load tokenizer
    std.debug.print("\nLoading tokenizer...\n", .{});
    var tokenizer = Tokenizer.load(allocator, "/workspaces/trinity/models/bitnet/tokenizer.json") catch |err| {
        std.debug.print("Failed to load tokenizer: {}\n", .{err});
        return;
    };
    defer tokenizer.deinit();
    
    // Test prompts (10+ for comprehensive testing)
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
    std.debug.print("     GENERATION RESULTS (with 8-bit activation quantization)       \n", .{});
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
        
        // Generate with full model (includes activation quantization)
        const start_time = std.time.milliTimestamp();
        const generated = model.generate(prompt_tokens, 32, 0.8) catch |err| {
            std.debug.print("  Generation failed: {}\n", .{err});
            continue;
        };
        defer allocator.free(generated);
        const end_time = std.time.milliTimestamp();
        
        // Decode
        const text = try tokenizer.decode(generated);
        defer allocator.free(text);
        
        const gen_tokens = generated.len - prompt_tokens.len;
        const time_ms = end_time - start_time;
        const tps = if (time_ms > 0) @as(f32, @floatFromInt(gen_tokens)) / (@as(f32, @floatFromInt(time_ms)) / 1000.0) else 0.0;
        
        total_tokens += gen_tokens;
        total_time_ms += time_ms;
        
        // Check coherence (simple heuristic: has spaces and reasonable length)
        const is_coherent = text.len > prompt.len + 5 and std.mem.indexOf(u8, text, " ") != null;
        if (is_coherent) coherent_count += 1;
        
        std.debug.print("  Generated ({d} tokens in {d}ms = {d:.1} tok/s):\n", .{gen_tokens, time_ms, tps});
        std.debug.print("  \"{s}\"\n", .{text});
        std.debug.print("  Coherent: {s}\n", .{if (is_coherent) "YES" else "NO"});
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
    std.debug.print("  Activation quantization: 8-bit per-token absmax\n", .{});
    std.debug.print("  Weight quantization: QAT (trained ternary)\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    TEST COMPLETE                                  \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\nφ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL\n\n", .{});
}

test "activation quantization functions" {
    const forward = @import("bitnet_forward.zig");
    
    // Test quantize in place
    var input = [_]f32{ 0.5, -1.0, 0.25, 0.75, -0.5 };
    const scale = forward.quantizeActivationsInPlace(&input);
    _ = scale;
    
    // Values should be close to original (quantization noise)
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), input[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), input[1], 0.01);
}
