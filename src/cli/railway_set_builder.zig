// Railway builder configuration utility
// Usage: railway-set-builder <service-id> <dockerfile-path> <token>
// Sets builder to DOCKERFILE and specifies dockerfilePath

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
            \\Usage: railway-set-builder <service-id> <dockerfile-path> <token>
            \\Example: railway-set-builder abc123-def456 Dockerfile.hslm-train TOKEN
            \\
        , .{});
        std.process.exit(1);
    }

    const service_id = args[1];
    const dockerfile_path = args[2];
    const token = args[3];

    // GraphQL mutation for serviceUpdate
    const query = std.fmt.allocPrint(allocator,
        \\{{
        \\  "query": "mutation($id: String!, $input: ServiceUpdateInput!) {{ serviceUpdate(id: $id, input: $input) {{ id }} }}"
        \\  "variables": {{
        \\    "id": "{s}",
        \\    "input": {{
        \\      "builder": "DOCKERFILE",
        \\      "dockerfilePath": "{s}"
        \\    }}
        \\  }}
        \\}}
    , .{ service_id, dockerfile_path }) catch return error.OutOfMemory;
    defer allocator.free(query);

    std.debug.print("🔧 Setting builder for service {s}...\n", .{service_id});
    std.debug.print("   Builder: DOCKERFILE\n", .{});
    std.debug.print("   Dockerfile: {s}\n", .{dockerfile_path});

    // Execute GraphQL mutation
    const auth_header = std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token}) catch return error.OutOfMemory;
    defer allocator.free(auth_header);

    const result = execCurl(allocator, &.{
        "curl", "-s",        "-X",                                       "POST",
        "-H",   auth_header, "-H",                                       "Content-Type: application/json",
        "-d",   query,       "https://backboard.railway.app/graphql/v2",
    }) catch |err| {
        std.debug.print("❌ Failed to execute curl: {}\n", .{err});
        return err;
    };
    defer allocator.free(result);

    // Check for errors
    if (std.mem.indexOf(u8, result, "\"errors\"")) |_| {
        std.debug.print("❌ Railway API error:\n{s}\n", .{result});
        return error.RailwayError;
    }

    std.debug.print("✅ Builder configuration updated!\n", .{});
    std.debug.print("\n⚠️  IMPORTANT: Now run redeploy to apply:\n", .{});
    std.debug.print("   railway-redeploy {s} <project-id> TOKEN\n", .{service_id});
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
    switch (result.term) {
        .Exited => |code| {
            if (code != 0) return error.CurlFailed;
        },
        else => return error.CurlFailed,
    }
    return result.stdout;
}
