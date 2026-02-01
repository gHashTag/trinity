const std = @import("std");

/// Trinity Decoder - Temperature sampling with softmax
/// Converts logits to tokens through probabilistic selection
pub const Decoder = struct {
    allocator: std.mem.Allocator,
    temperature: f32,

    // Simple vocabulary for Zig code generation
    pub const VOCAB = [_][]const u8{
        // Zig keywords
        "const ",        "var ",   "pub ",   "fn ",        "struct ", "enum ",   "union ",      "return ",
        "if ",           "else ",  "while ", "for ",       "switch ", "break",   "continue",
        // Common patterns
           "std",
        ".debug",        ".print", ".mem",   ".Allocator", ".fs",     ".io",     "@import",     "@intFromFloat",
        "@floatFromInt", "@as",    "@max",   "@min",
        // Symbols
              "(",       ")",       "{",           "}",
        "[",             "]",      ";",      ":",          ",",       ".",       "=",           "!",
        "+",             "-",      "*",      "/",          "|",       "&",       "^",           "<",
        ">",
        // Literals
                    "0",      "1",      "true",       "false",   "null",    "void",        "u8",
        "i32",           "f32",
        // Whitespace
           " ",      "\n",         "\t",
        // Common strings
             "\"PHI\"", "\"Trinity\"", "main",
        "init",          "deinit", "self",   "allocator",
        // PHI constant
         "1.618",
    };

    pub const END_TOKEN: usize = VOCAB.len;

    pub fn init(allocator: std.mem.Allocator, temperature: f32) Decoder {
        return Decoder{
            .allocator = allocator,
            .temperature = @max(0.1, temperature), // Prevent division by zero
        };
    }

    /// Apply softmax to logits
    pub fn softmax(self: *Decoder, logits: []f32) void {
        _ = self;

        // Find max for numerical stability
        var max_logit: f32 = logits[0];
        for (logits) |l| {
            if (l > max_logit) max_logit = l;
        }

        // Compute exp and sum
        var sum: f32 = 0.0;
        for (logits) |*l| {
            l.* = @exp(l.* - max_logit);
            sum += l.*;
        }

        // Normalize
        if (sum > 0) {
            for (logits) |*l| {
                l.* /= sum;
            }
        }
    }

    /// Sample from probability distribution
    pub fn sample(self: *Decoder, probs: []f32, seed: u64) usize {
        _ = self;

        // Simple deterministic sampling based on seed
        var prng = std.Random.DefaultPrng.init(seed);
        const rand = prng.random();
        const target = rand.float(f32);

        var cumsum: f32 = 0.0;
        for (probs, 0..) |p, i| {
            cumsum += p;
            if (cumsum >= target) {
                return i;
            }
        }

        return probs.len - 1;
    }

    /// Generate text from initial activation
    pub fn generate(self: *Decoder, activation: f32, max_tokens: usize) ![]const u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(self.allocator);

        var state: f32 = activation;
        var token_count: usize = 0;

        while (token_count < max_tokens) {
            // Generate logits for vocabulary
            var logits = try self.allocator.alloc(f32, VOCAB.len + 1);
            defer self.allocator.free(logits);

            for (0..logits.len) |i| {
                // Simple RNN-like state transition
                const fi = @as(f32, @floatFromInt(i));
                logits[i] = state * @sin(fi * 0.1) + @cos(fi * state * 0.01);
            }

            // Apply temperature
            for (logits) |*l| {
                l.* /= self.temperature;
            }

            // Apply softmax
            self.softmax(logits);

            // Sample next token
            const seed = @as(u64, @intFromFloat(@abs(state * 1000000))) + token_count;
            const token_idx = self.sample(logits, seed);

            // Check for end token
            if (token_idx >= VOCAB.len) break;

            // Append token to result
            try result.appendSlice(self.allocator, VOCAB[token_idx]);

            // Update state
            state = state * 0.99 + @as(f32, @floatFromInt(token_idx)) * 0.1;
            token_count += 1;
        }

        return try result.toOwnedSlice(self.allocator);
    }
};

/// Test the decoder
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var decoder = Decoder.init(allocator, 0.7);

    // Test with different activations
    const activations = [_]f32{ 1.0, -0.5, 3.14, 1.618 };

    for (activations) |act| {
        std.debug.print("\n--- Activation: {d:.3} ---\n", .{act});
        const output = try decoder.generate(act, 20);
        defer allocator.free(output);
        std.debug.print("Output: {s}\n", .{output});
    }
}
