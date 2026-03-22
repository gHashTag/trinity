// Railway: Set service repository
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 4) {
        std.debug.print("Usage: railway-set-repo <service-id> <repo-url> <token>\n", .{});
        std.process.exit(1);
    }

    const service_id = args[1];
    const repo_url = args[2];
    const token = args[3];

    const query = std.fmt.allocPrint(allocator,
        \\{{"query": "mutation($serviceId: String!, $input: ServiceInstanceUpdateInput!) {{ serviceInstanceUpdate(serviceId: $serviceId, input: $input) }}", "variables": {{"serviceId": "{s}", "input": {{"repo": "{s}"}}}}}}
    , .{ service_id, repo_url }) catch return error.OutOfMemory;
    defer allocator.free(query);

    std.debug.print("🔧 Setting repo for service {s}...\n", .{service_id});
    std.debug.print("   Repo: {s}\n", .{repo_url});

    const auth_header = std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token}) catch return error.OutOfMemory;
    defer allocator.free(auth_header);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "POST", "-H", auth_header, "-H", "Content-Type: application/json", "-d", query, "https://railway.com/graphql/v2" },
    });
    defer allocator.free(result.stderr);

    if (std.mem.indexOf(u8, result.stdout, "\"errors\"")) |_| {
        std.debug.print("❌ Error: {s}\n", .{result.stdout});
        return error.RailwayError;
    }

    std.debug.print("✅ Repository updated!\n", .{});
}
