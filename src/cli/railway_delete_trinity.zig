// Railway: Delete "trinity" base service from farm account
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 4) {
        std.debug.print("Usage: railway-delete-trinity <account-name> <project-id> <token>\n", .{});
        std.process.exit(1);
    }

    const account_name = args[1];
    const project_id = args[2];
    const token = args[3];

    std.debug.print("\n🔧 [{s}] Looking for 'trinity' service...\n", .{account_name});

    // Step 1: List services and find "trinity"
    const trinity_id = try findTrinityService(allocator, token, project_id);
    defer allocator.free(trinity_id);

    if (trinity_id.len == 0) {
        std.debug.print("⏭️  No 'trinity' service found\n\n", .{});
        return;
    }

    std.debug.print("📍 Found trinity: {s}\n", .{trinity_id});

    // Step 2: Delete it
    std.debug.print("🗑️  Deleting...\n", .{});
    if (try deleteService(allocator, token, trinity_id)) {
        std.debug.print("✅ [{s}] Deleted 'trinity' → 1 slot freed\n\n", .{account_name});
    } else {
        std.debug.print("❌ Failed to delete\n\n", .{});
    }
}

fn findTrinityService(allocator: std.mem.Allocator, token: []const u8, project_id: []const u8) ![]const u8 {
    const body_str = try std.fmt.allocPrint(allocator,
        \\{{"query": "query($projectId: String!) {{ project(id: $projectId) {{ services {{ edges {{ node {{ id name }} }} }} }} }} }}", "variables": {{"projectId": "{s}"}}}}
    , .{project_id});
    defer allocator.free(body_str);

    const auth_header = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth_header);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "curl", "-s",        "-X",                                    "POST",
            "-H",   auth_header, "-H",                                    "Content-Type: application/json",
            "-d",   body_str,    "https://backboard.railway.com/graphql",
        },
    });
    defer {
        allocator.free(result.stderr);
        allocator.free(result.stdout);
    }

    // Parse JSON
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, result.stdout, .{});
    defer parsed.deinit();

    const data = parsed.value.object.get("data") orelse return allocator.dupe(u8, "");
    const project = data.object.get("project") orelse return allocator.dupe(u8, "");
    const edges = project.object.get("services").?.object.get("edges").?.array.items;

    for (edges) |edge| {
        const node = edge.object.get("node").?;
        const name = node.object.get("name").?.string;
        if (std.mem.eql(u8, name, "trinity")) {
            const id = node.object.get("id").?.string;
            return try allocator.dupe(u8, id);
        }
    }

    return allocator.dupe(u8, "");
}

fn deleteService(allocator: std.mem.Allocator, token: []const u8, service_id: []const u8) !bool {
    const mutation = try std.fmt.allocPrint(allocator,
        \\{{"query": "mutation($id: ID!) {{ serviceDelete(id: $id) {{ id }} }}", "variables": {{"id": "{s}"}}}}
    , .{service_id});
    defer allocator.free(mutation);

    const auth_header = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth_header);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "curl", "-s",        "-X",                                    "POST",
            "-H",   auth_header, "-H",                                    "Content-Type: application/json",
            "-d",   mutation,    "https://backboard.railway.com/graphql",
        },
    });
    defer {
        allocator.free(result.stderr);
        allocator.free(result.stdout);
    }

    if (std.mem.indexOf(u8, result.stdout, "\"errors\"")) |_| {
        return false;
    }

    return true;
}
