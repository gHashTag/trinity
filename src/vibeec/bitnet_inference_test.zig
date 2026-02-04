// ═══════════════════════════════════════════════════════════════════════════════
// BITNET b1.58 INFERENCE TEST
// Test coherent text generation with native ternary model
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const bitnet = @import("bitnet_loader.zig");
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
// SIMPLE INFERENCE (Embedding lookup + sampling)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn simpleGenerate(
    model: *bitnet.BitNetModel,
    tokenizer: *Tokenizer,
    prompt_tokens: []const u32,
    max_new_tokens: usize,
    temperature: f32,
) ![]u32 {
    const allocator = model.allocator;
    var generated = std.ArrayList(u32).init(allocator);
    
    // Copy prompt tokens
    for (prompt_tokens) |t| {
        try generated.append(t);
    }
    
    // Simple generation: use embedding similarity
    const hidden_size = model.config.hidden_size;
    const vocab_size = model.config.vocab_size;
    
    var rng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    
    for (0..max_new_tokens) |_| {
        // Get last token embedding
        const last_token = generated.items[generated.items.len - 1];
        const last_embed_start = @as(usize, last_token) * hidden_size;
        const last_embed_end = last_embed_start + hidden_size;
        
        if (last_embed_end > model.embed_tokens.len) {
            break;
        }
        
        const last_embed = model.embed_tokens[last_embed_start..last_embed_end];
        
        // Compute similarity with all embeddings (simplified)
        var logits = try allocator.alloc(f32, vocab_size);
        defer allocator.free(logits);
        
        for (0..vocab_size) |v| {
            const v_start = v * hidden_size;
            const v_end = v_start + hidden_size;
            
            if (v_end > model.embed_tokens.len) {
                logits[v] = -1000.0;
                continue;
            }
            
            const v_embed = model.embed_tokens[v_start..v_end];
            
            // Dot product
            var dot: f32 = 0.0;
            for (last_embed, v_embed) |a, b| {
                dot += a * b;
            }
            logits[v] = dot / temperature;
        }
        
        // Softmax and sample
        var max_logit: f32 = -std.math.inf(f32);
        for (logits) |l| {
            if (l > max_logit) max_logit = l;
        }
        
        var sum: f32 = 0.0;
        for (logits) |*l| {
            l.* = @exp(l.* - max_logit);
            sum += l.*;
        }
        
        for (logits) |*l| {
            l.* /= sum;
        }
        
        // Sample from distribution
        const r = rng.random().float(f32);
        var cumsum: f32 = 0.0;
        var next_token: u32 = 0;
        
        for (logits, 0..) |p, i| {
            cumsum += p;
            if (cumsum >= r) {
                next_token = @intCast(i);
                break;
            }
        }
        
        // Check for EOS
        if (next_token == tokenizer.eos_token_id) {
            break;
        }
        
        try generated.append(next_token);
    }
    
    return generated.toOwnedSlice();
}

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
    std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
    
    // Load model
    std.debug.print("Loading BitNet b1.58-large model...\n", .{});
    var model = try bitnet.BitNetModel.load(
        allocator,
        "../../models/bitnet/model.safetensors",
        "../../models/bitnet/config.json",
    );
    defer model.deinit();
    
    // Load tokenizer
    std.debug.print("\nLoading tokenizer...\n", .{});
    var tokenizer = try Tokenizer.load(allocator, "../../models/bitnet/tokenizer.json");
    defer tokenizer.deinit();
    
    // Test prompts
    const prompts = [_][]const u8{
        "Hello, my name is",
        "The meaning of life is",
        "Artificial intelligence will",
        "The golden ratio phi equals",
        "In the year 2026,",
    };
    
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    GENERATION RESULTS                             \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    
    for (prompts, 0..) |prompt, i| {
        std.debug.print("\n[Test {d}] Prompt: \"{s}\"\n", .{i + 1, prompt});
        
        // Encode prompt
        const prompt_tokens = try tokenizer.encode(prompt);
        defer allocator.free(prompt_tokens);
        
        std.debug.print("  Prompt tokens ({d}): ", .{prompt_tokens.len});
        for (prompt_tokens[0..@min(prompt_tokens.len, 10)]) |t| {
            std.debug.print("{d} ", .{t});
        }
        std.debug.print("\n", .{});
        
        // Generate
        const start_time = std.time.milliTimestamp();
        const generated = try simpleGenerate(&model, &tokenizer, prompt_tokens, 32, 0.8);
        defer allocator.free(generated);
        const end_time = std.time.milliTimestamp();
        
        // Decode
        const text = try tokenizer.decode(generated);
        defer allocator.free(text);
        
        const gen_tokens = generated.len - prompt_tokens.len;
        const time_ms = end_time - start_time;
        const tps = if (time_ms > 0) @as(f32, @floatFromInt(gen_tokens)) / (@as(f32, @floatFromInt(time_ms)) / 1000.0) else 0.0;
        
        std.debug.print("  Generated ({d} tokens in {d}ms = {d:.1} tok/s):\n", .{gen_tokens, time_ms, tps});
        std.debug.print("  \"{s}\"\n", .{text});
    }
    
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    TEST COMPLETE                                  \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\nφ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL\n\n", .{});
}

test "tokenizer load" {
    const allocator = std.testing.allocator;
    
    var tokenizer = Tokenizer.load(allocator, "../../models/bitnet/tokenizer.json") catch |err| {
        std.debug.print("Tokenizer not found: {}\n", .{err});
        return;
    };
    defer tokenizer.deinit();
    
    try std.testing.expect(tokenizer.vocab.count() > 0);
}
