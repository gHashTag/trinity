// Railway redeploy trigger via GraphQL API
// Usage: railway-trigger-redeploy <deployment-id> <token>

const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: railway-trigger-redeploy <deployment-id> <token>\n", .{});
        std.process.exit(1);
    }

    const deployment_id = args[1];
    const token = args[2];

    const query = std.fmt.allocPrint(allocator,
        \\{{
        \\  "query": "mutation($id: ID!) {{ deploymentRedeploy(id: $id) {{ id }} }}"
        \\  "variables": {{ "id": "{s}" }}
        \\}}
    , .{deployment_id}) catch return error.OutOfMemory;
    defer allocator.free(query);

    std.debug.print("🔄 Triggering redeploy for {s}...\n", .{deployment_id});

    const auth_header = std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token}) catch return error.OutOfMemory;
    defer allocator.free(auth_header);

    const result = execCurl(allocator, &.{
        "curl", "-s", "-X", "POST",
        "-H", auth_header,
        "-H", "Content-Type: application/json",
        "-d", query,
        "https://backboard.railway.app/graphql/v2",
    }) catch |err| {
        std.debug.print("❌ curl failed: {}\n", .{err});
        return err;
    };
    defer allocator.free(result);

    if (std.mem.indexOf(u8, result, "\"errors\"")) |_| {
        std.debug.print("❌ API error:\n{s}\n", .{result});
        return error.RailwayError;
    }

    std.debug.print("✅ Redeploy triggered!\n", .{});
    std.debug.print("📊 Monitor: https://railway.app/project/aa0efa7f-95e6-4466-8de6-43945a031365\n", .{});
}

fn execCurl(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = args,
    });
    defer allocator.free(result.stderr);
    switch (result.term) {
        .Exited => |code| {
            if (code != 0) return error.CurlFailed;
        },
        else => return error.CurlFailed,
    }
    return result.stdout;
}
