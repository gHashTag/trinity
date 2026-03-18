// Railway startCommand update utility
// Usage: railway-set-startcmd <service-id> <command> <token>

const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 4) {
        std.debug.print("Usage: railway-set-startcmd <service-id> <command> <token>\n", .{});
        std.process.exit(1);
    }

    const service_id = args[1];
    const command = args[2];
    const token = args[3];

    const query = std.fmt.allocPrint(allocator,
        \\{{
        \\  "query": "mutation($id: String!, $input: ServiceInstanceUpdateInput!) {{ serviceInstanceUpdate(id: $id, input: $input) {{ id }} }}"
        \\  "variables": {{
        \\    "id": "{s}",
        \\    "input": {{
        \\      "startCommand": "{s}"
        \\    }}
        \\  }}
        \\}}
    , .{service_id, command}) catch return error.OutOfMemory;
    defer allocator.free(query);

    std.debug.print("🔧 Updating startCommand to: {s}\n", .{command});

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

    std.debug.print("✅ startCommand updated!\n", .{});
    std.debug.print("🔄 Now redeploy to apply\n", .{});
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
