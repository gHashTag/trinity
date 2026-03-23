// Railway service creation via GraphQL API
// Usage: railway-create-service <service-name> <project-id> <env-id> <token>

const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 5) {
        std.debug.print(
            \\Usage: railway-create-service <service-name> <project-id> <env-id> <token>
            \\Example: railway-create-service hslm-r12 aa0efa7f-95e6-4466-8de6-43945a031365 6748f1ad-9c2f-4b71-9a90-67f40ce34dc9 TOKEN
            \\
        , .{});
        std.process.exit(1);
    }

    const service_name = args[1];
    const project_id = args[2];
    const env_id = args[3];
    const token = args[4];

    // GraphQL mutation for creating service with Dockerfile builder
    const query = std.fmt.allocPrint(allocator,
        \\{{
        \\  "query": "mutation($projectId: String!, $envId: String!, $name: String!, $input: ServiceInput!) {{ serviceCreate(projectId: $projectId, envId: $envId, name: $name, input: $input) {{ id name }} }}"
        \\  "variables": {{
        \\    "projectId": "{s}",
        \\    "envId": "{s}",
        \\    "name": "{s}",
        \\    "input": {{
        \\      "builder": "DOCKERFILE",
        \\      "dockerfilePath": "Dockerfile.hslm-train",
        \\      "dockerContext": "/",
        \\      "startCommand": null
        \\    }}
        \\  }}
        \\}}
    , .{ project_id, env_id, service_name }) catch return error.OutOfMemory;
    defer allocator.free(query);

    std.debug.print("🔧 Creating service '{s}' in project {s}...\n", .{ service_name, project_id });
    std.debug.print("   Builder: DOCKERFILE\n", .{});
    std.debug.print("   Dockerfile: Dockerfile.hslm-train\n", .{});
    std.debug.print("   startCommand: null (uses Dockerfile ENTRYPOINT)\n", .{});

    // Execute GraphQL mutation
    const auth_header = std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token}) catch return error.OutOfMemory;
    defer allocator.free(auth_header);

    const result = execCurl(allocator, &.{
        "curl", "-s",        "-X",                             "POST",
        "-H",   auth_header, "-H",                             "Content-Type: application/json",
        "-d",   query,       "https://railway.com/graphql/v2",
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

    std.debug.print("✅ Service '{s}' created!\n", .{service_name});
    std.debug.print("📊 Monitor: https://railway.app/project/{s}\n", .{project_id});
    std.debug.print("\n⚠️  Next steps:\n", .{});
    std.debug.print("   1. Copy env vars from hslm-v11 to {s}\n", .{service_name});
    std.debug.print("   2. Trigger first deploy: railway-redeploy <deployment-id> {s} TOKEN\n", .{project_id});
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
