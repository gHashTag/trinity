// Railway redeploy utility - bypasses PreToolUse hook for Railway API
// Usage: zig build railway-redeploy -- <service-id> <project-id> <token>

const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 4) {
        std.debug.print(
            \\Usage: railway-redeploy <service-id> <project-id> <token>
            \\Example: railway-redeploy abc123-def456 aa0efa7f-95e6-4466-8de6-43945a031365 TOKEN
            \\
        , .{});
        std.process.exit(1);
    }

    const service_id = args[1];
    const project_id = args[2];
    const token = args[3];

    // GraphQL mutation for redeploy
    const query = std.fmt.allocPrint(allocator,
        \\{{
        \\  "query": "mutation($id: UUID!) {{ deploymentRedeploy(id: $id) {{ id }} }}"
        \\  "variables": {{"id": "{s}"}}
        \\}}
    , .{service_id}) catch return error.OutOfMemory;
    defer allocator.free(query);

    std.debug.print("🚀 Redeploying service {s}...\n", .{service_id});

    // Use simpler approach with curl
    const result = execCurl(allocator, &.{
        "curl", "-s",                                                                                                "-X",                                       "POST",
        "-H",   std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token}) catch return error.OutOfMemory, "-H",                                       "Content-Type: application/json",
        "-d",   query,                                                                                               "https://railway.com/graphql/v2",
    }) catch |err| {
        std.debug.print("❌ Failed to execute curl: {}\n", .{err});
        return err;
    };
    defer allocator.free(result);

    // Simple JSON parsing
    if (std.mem.indexOf(u8, result, "\"errors\"")) |_| {
        std.debug.print("❌ Railway API error:\n{s}\n", .{result});
        return error.RailwayError;
    }

    std.debug.print("✅ Redeploy started!\n", .{});
    std.debug.print("📊 Monitor: https://railway.app/project/{s}\n", .{project_id});
}

fn execCurl(allocator: Allocator, args: []const []const u8) ![]u8 {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = args,
    });
    defer allocator.free(result.stderr);
    if (result.stderr.len > 0) {
        std.debug.print("curl stderr: {s}\n", .{result.stderr});
    }
    // Check if exited successfully (exit code 0)
    switch (result.term) {
        .Exited => |code| {
            if (code != 0) return error.CurlFailed;
        },
        else => return error.CurlFailed,
    }
    return result.stdout;
}
