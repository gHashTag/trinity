// Railway: Create deployment via GraphQL (correct mutation)
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 4) {
        std.debug.print("Usage: railway-deploy-create <project-id> <service-id> <token>\n", .{});
        std.process.exit(1);
    }

    const project_id = args[1];
    const service_id = args[2];
    const token = args[3];

    // Use up mutation (trigger build + deploy)
    const query = std.fmt.allocPrint(allocator,
        \\{{"query": "mutation($projectId: String!, $serviceId: String!) {{ up(projectId: $projectId, serviceId: $serviceId) {{ url }} }}", "variables": {{"projectId": "{s}", "serviceId": "{s}"}}}}
    , .{ project_id, service_id }) catch return error.OutOfMemory;
    defer allocator.free(query);

    std.debug.print("🚀 Creating deployment for service {s}...\n", .{service_id});

    const auth_header = std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token}) catch return error.OutOfMemory;
    defer allocator.free(auth_header);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "POST", "-H", auth_header, "-H", "Content-Type: application/json", "-d", query, "https://backboard.railway.com/graphql" },
    });
    defer allocator.free(result.stderr);

    if (std.mem.indexOf(u8, result.stdout, "\"errors\"")) |_| {
        std.debug.print("❌ Error: {s}\n", .{result.stdout});
        return error.RailwayError;
    }

    std.debug.print("✅ Deployment created!\n{s}\n", .{result.stdout});
}
