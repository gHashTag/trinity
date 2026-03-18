// Railway: Set service to use existing image from another deployment
// Usage: railway-copy-image <target-service-id> <source-image-digest> <token>

const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 4) {
        std.debug.print("Usage: railway-copy-image <service-id> <image-digest> <token>\n", .{});
        std.debug.print("Example: railway-copy-image 56cd0d31-13be-45de-a6e7-cd7c47cb63d9 sha256:xxx TOKEN\n", .{});
        std.process.exit(1);
    }

    const service_id = args[1];
    const image_digest = args[2];
    const token = args[3];

    // GraphQL mutation for setting image source
    const query = std.fmt.allocPrint(allocator,
        \\{{
        \\  "query": "mutation($id: ID!, $input: ServiceInstanceInput!) {{ serviceInstanceUpdate(id: $id, input: $input) {{ id }} }}"
        \\  "variables": {{
        \\    "id": "{s}",
        \\    "input": {{
        \\      "builder": "DOCKERFILE",
        \\      "dockerfilePath": "Dockerfile.hslm-train",
        \\      "imageDigest": "{s}"
        \\    }}
        \\  }}
        \\}}
    , .{service_id, image_digest}) catch return error.OutOfMemory;
    defer allocator.free(query);

    std.debug.print("🔧 Setting image for service {s}...\n", .{service_id});
    std.debug.print("   Image: {s}\n", .{image_digest});

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

    std.debug.print("✅ Service configured! Trigger redeploy to apply image\n", .{});
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
