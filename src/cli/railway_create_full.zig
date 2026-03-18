// Railway: Create service with full config (builder + dockerfile + startCommand=null)
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 5) {
        std.debug.print("Usage: railway-create-full <name> <project-id> <env-id> <token>\n", .{});
        std.process.exit(1);
    }

    const name = args[1];
    const project_id = args[2];
    const env_id = args[3];
    const token = args[4];

    const query = std.fmt.allocPrint(allocator,
        \\{{"query": "mutation($projectId: String!, $envId: String!, $name: String!, $input: ServiceCreateInput!) {{ serviceCreate(projectId: $projectId, envId: $envId, name: $name, input: $input) {{ id name }} }}", "variables": {{"projectId": "{s}", "envId": "{s}", "name": "{s}", "input": {{"buildConfig": {{"builder": "DOCKERFILE", "dockerfilePath": "Dockerfile.hslm-train"}}, "startCommand": null}}}}}}
    , .{project_id, env_id, name}) catch return error.OutOfMemory;
    defer allocator.free(query);

    std.debug.print("🔧 Creating service '{s}' with DOCKERFILE builder...\n", .{name});

    const auth_header = std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token}) catch return error.OutOfMemory;
    defer allocator.free(auth_header);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{"curl", "-s", "-X", "POST", "-H", auth_header, "-H", "Content-Type: application/json", "-d", query, "https://backboard.railway.app/graphql/v2"},
    });
    defer allocator.free(result.stderr);

    if (std.mem.indexOf(u8, result.stdout, "\"errors\"")) |_| {
        std.debug.print("❌ Error: {s}\n", .{result.stdout});
        return error.RailwayError;
    }

    std.debug.print("✅ Service created!\n{s}\n", .{result.stdout});
}
