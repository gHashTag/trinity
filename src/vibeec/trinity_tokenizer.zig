const std = @import("std");

/// Character-level tokenizer for Trinity Engine
/// Converts text to normalized float tensors and back
pub const Tokenizer = struct {
    allocator: std.mem.Allocator,

    // Special tokens
    const PAD_TOKEN: f32 = 0.0;
    const UNK_TOKEN: f32 = -1.0;
    const BOS_TOKEN: f32 = 1.0; // Begin of sequence
    const EOS_TOKEN: f32 = 2.0; // End of sequence

    pub fn init(allocator: std.mem.Allocator) Tokenizer {
        return Tokenizer{ .allocator = allocator };
    }

    /// Tokenize text to float tensor
    /// Each character becomes a normalized float in range [-1, 1]
    pub fn tokenize(self: *Tokenizer, text: []const u8) ![]f32 {
        // Allocate: BOS + text + EOS
        var tokens = try self.allocator.alloc(f32, text.len + 2);

        // BOS
        tokens[0] = BOS_TOKEN;

        // Normalize ASCII to [-1, 1] range
        // ASCII 0-127 → [-1, 1]
        for (text, 0..) |char, i| {
            const normalized = (@as(f32, @floatFromInt(char)) / 127.0) * 2.0 - 1.0;
            tokens[i + 1] = normalized;
        }

        // EOS
        tokens[tokens.len - 1] = EOS_TOKEN;

        return tokens;
    }

    /// Detokenize float tensor back to text
    /// Ignores special tokens (BOS, EOS, PAD)
    pub fn detokenize(self: *Tokenizer, tokens: []const f32) ![]const u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(self.allocator);

        for (tokens) |token| {
            // Skip special tokens
            if (token == BOS_TOKEN or token == EOS_TOKEN or token == PAD_TOKEN) continue;
            if (token == UNK_TOKEN) {
                try result.append(self.allocator, '?');
                continue;
            }

            // Denormalize: [-1, 1] → ASCII 0-127
            const denormalized = (token + 1.0) / 2.0 * 127.0;
            const char_val = @as(i16, @intFromFloat(denormalized));

            // Clamp to valid ASCII
            if (char_val >= 0 and char_val < 128) {
                try result.append(self.allocator, @as(u8, @intCast(char_val)));
            } else {
                try result.append(self.allocator, '?');
            }
        }

        return try result.toOwnedSlice(self.allocator);
    }
};

// Test
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tokenizer = Tokenizer.init(allocator);

    const text = "Hello Trinity!";
    std.debug.print("Original: {s}\n", .{text});

    const tokens = try tokenizer.tokenize(text);
    defer allocator.free(tokens);
    std.debug.print("Tokens ({d}): ", .{tokens.len});
    for (tokens) |t| std.debug.print("{d:.2} ", .{t});
    std.debug.print("\n", .{});

    const decoded = try tokenizer.detokenize(tokens);
    defer allocator.free(decoded);
    std.debug.print("Decoded: {s}\n", .{decoded});

    if (std.mem.eql(u8, text, decoded)) {
        std.debug.print("✅ Round-trip successful!\n", .{});
    } else {
        std.debug.print("❌ Round-trip failed!\n", .{});
    }
}
