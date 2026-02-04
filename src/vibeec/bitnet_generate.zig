// ═══════════════════════════════════════════════════════════════════════════════
// BITNET b1.58 TEXT GENERATION
// Full inference pipeline with coherent text output
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const json = std.json;
const model_mod = @import("bitnet_full_model.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// SIMPLE TOKENIZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const SimpleTokenizer = struct {
    allocator: std.mem.Allocator,
    vocab: std.StringHashMap(u32),
    id_to_token: std.AutoHashMap(u32, []const u8),
    bos_token_id: u32 = 1,
    eos_token_id: u32 = 2,
    
    pub fn load(allocator: std.mem.Allocator, path: []const u8) !SimpleTokenizer {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        
        const content = try file.readToEndAlloc(allocator, 100 * 1024 * 1024);
        defer allocator.free(content);
        
        var parsed = try json.parseFromSlice(json.Value, allocator, content, .{});
        defer parsed.deinit();
        
        var vocab = std.StringHashMap(u32).init(allocator);
        var id_to_token = std.AutoHashMap(u32, []const u8).init(allocator);
        
        // Parse vocab from model section
        if (parsed.value.object.get("model")) |model_obj| {
            if (model_obj.object.get("vocab")) |vocab_obj| {
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
        
        return SimpleTokenizer{
            .allocator = allocator,
            .vocab = vocab,
            .id_to_token = id_to_token,
        };
    }
    
    pub fn encode(self: *SimpleTokenizer, text: []const u8) ![]u32 {
        var tokens = std.ArrayList(u32).init(self.allocator);
        
        // Add BOS token
        try tokens.append(self.bos_token_id);
        
        // Simple word-level tokenization
        var i: usize = 0;
        while (i < text.len) {
            var found = false;
            
            // Try to match longest token first (up to 15 chars)
            var max_len = @min(text.len - i, 15);
            while (max_len > 0) : (max_len -= 1) {
                const substr = text[i..i + max_len];
                
                // Try with space prefix (Ġ in tokenizer)
                var buf: [20]u8 = undefined;
                const with_space = std.fmt.bufPrint(&buf, "Ġ{s}", .{substr}) catch substr;
                
                if (self.vocab.get(with_space)) |id| {
                    try tokens.append(id);
                    i += max_len;
                    found = true;
                    break;
                }
                
                if (self.vocab.get(substr)) |id| {
                    try tokens.append(id);
                    i += max_len;
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                // Skip unknown character
                i += 1;
            }
        }
        
        return tokens.toOwnedSlice();
    }
    
    pub fn decode(self: *SimpleTokenizer, tokens: []const u32) ![]u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        
        for (tokens) |id| {
            if (id == self.bos_token_id or id == self.eos_token_id) continue;
            
            if (self.id_to_token.get(id)) |token| {
                for (token) |c| {
                    // Handle Ġ (space prefix in LLaMA tokenizer)
                    if (c == 0xC4) continue;
                    if (c == 0xA0) {
                        try result.append(' ');
                    } else {
                        try result.append(c);
                    }
                }
            }
        }
        
        return result.toOwnedSlice();
    }
    
    pub fn deinit(self: *SimpleTokenizer) void {
        var it = self.vocab.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.vocab.deinit();
        self.id_to_token.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     BITNET b1.58 COHERENT TEXT GENERATION                    ║\n", .{});
    std.debug.print("║     Full Inference Pipeline                                  ║\n", .{});
    std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
    
    // Initialize model
    const config = model_mod.BitNetConfig{};
    var model = try model_mod.BitNetFullModel.init(allocator, config);
    defer model.deinit();
    
    // Load weights
    try model.loadFromSafetensors("../../models/bitnet/model.safetensors");
    
    // Load tokenizer
    std.debug.print("\nLoading tokenizer...\n", .{});
    var tokenizer = try SimpleTokenizer.load(allocator, "../../models/bitnet/tokenizer.json");
    defer tokenizer.deinit();
    
    // Test prompts
    const prompts = [_][]const u8{
        "Hello, my name is",
        "The meaning of life is",
        "Artificial intelligence will",
        "The golden ratio equals",
        "In the year 2026,",
        "The best programming language is",
        "Machine learning models can",
        "The future of technology",
        "Climate change is",
        "The universe began with",
    };
    
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    GENERATION RESULTS                             \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    
    var total_tokens: usize = 0;
    var total_time: i64 = 0;
    
    for (prompts, 0..) |prompt, i| {
        std.debug.print("\n[Test {d}] Prompt: \"{s}\"\n", .{i + 1, prompt});
        
        // Encode prompt
        const prompt_tokens = try tokenizer.encode(prompt);
        defer allocator.free(prompt_tokens);
        
        std.debug.print("  Prompt tokens: {d}\n", .{prompt_tokens.len});
        
        // Generate
        const start_time = std.time.milliTimestamp();
        const generated = try model.generate(prompt_tokens, 32, 0.8);
        defer allocator.free(generated);
        const end_time = std.time.milliTimestamp();
        
        // Decode
        const text = try tokenizer.decode(generated);
        defer allocator.free(text);
        
        const gen_tokens = generated.len - prompt_tokens.len;
        const time_ms = end_time - start_time;
        
        total_tokens += gen_tokens;
        total_time += time_ms;
        
        const tps = if (time_ms > 0) @as(f32, @floatFromInt(gen_tokens)) / (@as(f32, @floatFromInt(time_ms)) / 1000.0) else 0.0;
        
        std.debug.print("  Generated: {d} tokens in {d}ms ({d:.2} tok/s)\n", .{gen_tokens, time_ms, tps});
        std.debug.print("  Output: \"{s}\"\n", .{text});
    }
    
    // Summary
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    SUMMARY                                        \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    
    const avg_tps = if (total_time > 0) @as(f32, @floatFromInt(total_tokens)) / (@as(f32, @floatFromInt(total_time)) / 1000.0) else 0.0;
    
    std.debug.print("\n  Total prompts: {d}\n", .{prompts.len});
    std.debug.print("  Total tokens generated: {d}\n", .{total_tokens});
    std.debug.print("  Total time: {d}ms\n", .{total_time});
    std.debug.print("  Average speed: {d:.2} tokens/second\n", .{avg_tps});
    
    std.debug.print("\n", .{});
    std.debug.print("φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL\n", .{});
    std.debug.print("\n", .{});
}

test "tokenizer load" {
    const allocator = std.testing.allocator;
    
    var tokenizer = SimpleTokenizer.load(allocator, "../../models/bitnet/tokenizer.json") catch |err| {
        std.debug.print("Tokenizer not found: {}\n", .{err});
        return;
    };
    defer tokenizer.deinit();
    
    try std.testing.expect(tokenizer.vocab.count() > 0);
}
