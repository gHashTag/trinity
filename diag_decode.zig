// Diagnostic: Decode specific tokens
const std = @import("std");
const model_mod = @import("src/vibeec/gguf_model.zig");
const tokenizer = @import("src/vibeec/gguf_tokenizer.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

    var model = try model_mod.FullModel.init(allocator, path);
    defer model.deinit();

    var tok = try tokenizer.Tokenizer.init(allocator, &model.reader);
    defer tok.deinit();

    // Decode the suspicious tokens
    const tokens_to_decode = [_]u32{ 17994, 24109, 28090, 22819, 27939, 25550, 1, 450, 338, 263, 1243 };

    std.debug.print("Token decodings:\n", .{});
    for (tokens_to_decode) |token_id| {
        const arr = [_]u32{token_id};
        const decoded = tok.decode(allocator, &arr) catch "<error>";
        defer if (decoded.ptr != "<error>".ptr) allocator.free(decoded);
        std.debug.print("  {d}: \"{s}\"\n", .{ token_id, decoded });
    }
}
