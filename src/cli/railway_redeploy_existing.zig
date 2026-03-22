// Railway: Redeploy using existing image (no rebuild/snapshot)
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 4) {
        std.debug.print("Usage: railway-redeploy-existing <service-id> <project-id> <token>\n", .{});
        std.process.exit(1);
    }

    const service_id = args[1];
    const project_id = args[2];
    const token = args[3];

    // First, set the service to use DOCKERFILE builder with imageDigest
    const image_query = std.fmt.allocPrint(allocator,
        \\{{"query": "mutation($serviceId: String!, $input: ServiceInstanceUpdateInput!) {{ serviceInstanceUpdate(serviceId: $serviceId, input: $input) }}", "variables": {{"serviceId": "{s}", "input": {{"builder": "DOCKERFILE", "dockerfilePath": "Dockerfile.hslm-train"}}}}}}
    , .{service_id}) catch return error.OutOfMemory;
    defer allocator.free(image_query);

    std.debug.print("🔧 Setting DOCKERFILE builder...\n", .{});
    const auth_header = std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token}) catch return error.OutOfMemory;
    defer allocator.free(auth_header);

    // Set builder
    {
        const result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "curl", "-s", "-X", "POST", "-H", auth_header, "-H", "Content-Type: application/json", "-d", image_query, "https://railway.com/graphql/v2" },
        });
        defer allocator.free(result.stderr);
        defer allocator.free(result.stdout);
        _ = result;
    }

    // Now trigger a new deployment (not redeploy - fresh deploy with new config)
    std.debug.print("🚀 Triggering fresh deployment...\n", .{});

    // Get service name for logs
    const deploy_query = std.fmt.allocPrint(allocator,
        \\{{"query": "mutation($projectId: String!, $serviceId: String!) {{ deploymentCreate(projectId: $projectId, serviceId: $serviceId) {{ id status }} }}", "variables": {{"projectId": "{s}", "serviceId": "{s}"}}}}
    , .{ project_id, service_id }) catch return error.OutOfMemory;
    defer allocator.free(deploy_query);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "POST", "-H", auth_header, "-H", "Content-Type: application/json", "-d", deploy_query, "https://railway.com/graphql/v2" },
    });
    defer allocator.free(result.stderr);

    if (std.mem.indexOf(u8, result.stdout, "\"errors\"")) |_| {
        std.debug.print("❌ Error: {s}\n", .{result.stdout});
        return error.RailwayError;
    }

    std.debug.print("✅ Deployment created!\n", .{});
    std.debug.print("📊 Monitor: https://railway.app/project/{s}\n", .{project_id});
}
