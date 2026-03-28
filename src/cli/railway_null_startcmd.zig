// Railway: Remove startCommand to use Dockerfile ENTRYPOINT
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: railway-null-startcmd <service-id> <token>\n", .{});
        std.process.exit(1);
    }

    const service_id = args[1];
    const token = args[2];

    const query = std.fmt.allocPrint(allocator,
        \\{{"query": "mutation($serviceId: String!, $input: ServiceInstanceUpdateInput!) {{ serviceInstanceUpdate(serviceId: $serviceId, input: $input) }}", "variables": {{"serviceId": "{s}", "input": {{"startCommand": null}}}}}}
    , .{service_id}) catch return error.OutOfMemory;
    defer allocator.free(query);

    std.debug.print("🔧 Removing startCommand from {s}...\n", .{service_id});

    const auth_header = std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token}) catch return error.OutOfMemory;
    defer allocator.free(auth_header);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "-X", "POST", "-H", auth_header, "-H", "Content-Type: application/json", "-d", query, "https://backboard.railway.com/graphql" },
    });
    defer allocator.free(result.stderr);
    defer allocator.free(result.stdout);

    const has_error = result.term.Exited != 0;
    const has_errors_field = std.mem.indexOf(u8, result.stdout, "\"errors\"") != null;
    if (has_error or has_errors_field) {
        std.debug.print("❌ Error: {s}\n", .{result.stdout});
        return error.RailwayError;
    }

    std.debug.print("✅ startCommand removed — will use Dockerfile ENTRYPOINT\n", .{});
}
