// Railway service builder update via GraphQL API
// Usage: railway-set-dockerfile <service-id> <dockerfile-name> <token>

const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 4) {
        std.debug.print("Usage: railway-set-dockerfile <service-id> <dockerfile-name> <token>\n", .{});
        std.debug.print("Example: railway-set-dockerfile 56cd0d31-13be-45de-a6e7-cd7c47cb63d9 Dockerfile.hslm-train TOKEN\n", .{});
        std.process.exit(1);
    }

    const service_id = args[1];
    const dockerfile_name = args[2];
    const token = args[3];

    // GraphQL mutation for updating service builder
    const query = std.fmt.allocPrint(allocator,
        \\{{
        \\  "query": "mutation($id: ID!, $input: ServiceInstanceInput!) {{ serviceInstanceUpdate(id: $id, input: $input) {{ id name }} }}"
        \\  "variables": {{
        \\    "id": "{s}",
        \\    "input": {{
        \\      "builder": "DOCKERFILE",
        \\      "dockerfilePath": "{s}"
        \\    }}
        \\  }}
        \\}}
    , .{ service_id, dockerfile_name }) catch return error.OutOfMemory;
    defer allocator.free(query);

    std.debug.print("🔧 Updating service {s}...\n", .{service_id});
    std.debug.print("   Builder: DOCKERFILE\n", .{});
    std.debug.print("   Dockerfile: {s}\n", .{dockerfile_name});

    const auth_header = std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token}) catch return error.OutOfMemory;
    defer allocator.free(auth_header);

    const result = execCurl(allocator, &.{
        "curl", "-s",        "-X",                             "POST",
        "-H",   auth_header, "-H",                             "Content-Type: application/json",
        "-d",   query,       "https://railway.com/graphql/v2",
    }) catch |err| {
        std.debug.print("❌ curl failed: {}\n", .{err});
        return err;
    };
    defer allocator.free(result);

    if (std.mem.indexOf(u8, result, "\"errors\"")) |_| {
        std.debug.print("❌ API error:\n{s}\n", .{result});
        return error.RailwayError;
    }

    std.debug.print("✅ Service updated! New deployments will use {s}\n", .{dockerfile_name});
    std.debug.print("📊 Trigger redeploy to apply changes\n", .{});
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
