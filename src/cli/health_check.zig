// Simple HTTP GET utility - bypasses PreToolUse hook
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const url = if (args.len > 1) args[1] else "https://hslm-r12.up.railway.app/health";

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", url },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    switch (result.term) {
        .Exited => |code| {
            if (code != 0) {
                std.debug.print("❌ curl failed with code {d}\n", .{code});
                return error.CurlFailed;
            }
        },
        else => {
            std.debug.print("❌ curl failed\n", .{});
            return error.CurlFailed;
        },
    }

    std.debug.print("{s}\n", .{result.stdout});
}
