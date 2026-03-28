// Railway service configuration update utility
// Usage: railway-update-service <service-id> <project-id> <token>
// Removes startCommand to enable Dockerfile ENTRYPOINT (health_server)

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
            \\Usage: railway-update-service <service-id> <project-id> <token>
            \\Example: railway-update-service abc123-def456 aa0efa7f-95e6-4466-8de6-43945a031365 TOKEN
            \\
        , .{});
        std.process.exit(1);
    }

    const service_id = args[1];
    const project_id = args[2];
    const token = args[3];

    // GraphQL mutation for updating service instance
    // This removes startCommand so Dockerfile ENTRYPOINT is used
    const query = std.fmt.allocPrint(allocator,
        \\{{
        \\  "query": "mutation($id: String!, $input: ServiceInstanceUpdateInput!) {{ serviceInstanceUpdate(id: $id, input: $input) {{ id }} }}"
        \\  "variables": {{
        \\    "id": "{s}",
        \\    "input": {{
        \\      "startCommand": ""
        \\    }}
        \\  }}
        \\}}
    , .{service_id}) catch return error.OutOfMemory;
    defer allocator.free(query);

    std.debug.print("🔧 Updating service {s}...\n", .{service_id});
    std.debug.print("   Removing startCommand → Dockerfile ENTRYPOINT will be used\n", .{});

    // Execute GraphQL mutation
    const auth_header = std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token}) catch return error.OutOfMemory;
    defer allocator.free(auth_header);

    const result = execCurl(allocator, &.{
        "curl", "-s",        "-X",                                    "POST",
        "-H",   auth_header, "-H",                                    "Content-Type: application/json",
        "-d",   query,       "https://backboard.railway.com/graphql",
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

    std.debug.print("✅ Service configuration updated!\n", .{});
    std.debug.print("📊 Monitor: https://railway.app/project/{s}\n", .{project_id});
    std.debug.print("\n⚠️  IMPORTANT: Now run redeploy to apply changes:\n", .{});
    std.debug.print("   railway-redeploy {s} {s} TOKEN\n", .{ service_id, project_id });
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
