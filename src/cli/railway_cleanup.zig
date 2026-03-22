// Railway: Delete base services from farm accounts to free slots for Wave 8
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 4) {
        std.debug.print("Usage: railway-cleanup <account-name> <project-id> <token>\n", .{});
        std.debug.print("Example: railway-cleanup FARM-7 aa0efa7f-95e6-4466-8de6-43945a031365 $TOKEN\n", .{});
        std.process.exit(1);
    }

    const account_name = args[1];
    const project_id = args[2];
    const token = args[3];

    std.debug.print("\n🧹 [{s}] Cleaning up base services...\n", .{account_name});
    std.debug.print("📋 Project: {s}\n", .{project_id});

    // Step 1: List all services
    var services = try listServices(allocator, token, project_id);
    defer {
        for (services.items) |svc| {
            allocator.free(svc.id);
            allocator.free(svc.name);
        }
        services.deinit(allocator);
    }

    std.debug.print("🔍 Found {d} services\n", .{services.items.len});

    // Step 2: Find base services to delete
    var to_delete = std.ArrayListUnmanaged(Service){};
    defer {
        for (to_delete.items) |svc| {
            allocator.free(svc.id);
            allocator.free(svc.name);
        }
        to_delete.deinit(allocator);
    }

    for (services.items) |svc| {
        if (isBaseService(svc.name)) {
            try to_delete.append(allocator, .{
                .id = try allocator.dupe(u8, svc.id),
                .name = try allocator.dupe(u8, svc.name),
            });
        }
    }

    if (to_delete.items.len == 0) {
        std.debug.print("⏭️  No base services to delete\n\n", .{});
        return;
    }

    std.debug.print("🗑️  Deleting {d} base services...\n", .{to_delete.items.len});

    // Step 3: Delete each base service
    var deleted: usize = 0;
    for (to_delete.items) |svc| {
        if (try deleteService(allocator, token, svc.id)) {
            std.debug.print("   ✅ {s}\n", .{svc.name});
            deleted += 1;
        } else {
            std.debug.print("   ❌ {s} (failed)\n", .{svc.name});
        }
    }

    std.debug.print("\n✅ [{s}] Deleted {d}/{d} services → {d} slots freed\n\n", .{
        account_name, deleted, to_delete.items.len, deleted,
    });
}

const Service = struct {
    id: []const u8,
    name: []const u8,
};

fn isBaseService(name: []const u8) bool {
    const base_services = &[_][]const u8{ "trinity", "ssh-bridge", "trinity-arena", "agents" };
    for (base_services) |base| {
        if (std.mem.eql(u8, name, base)) return true;
    }
    return false;
}

fn listServices(allocator: std.mem.Allocator, token: []const u8, project_id: []const u8) !std.ArrayListUnmanaged(Service) {
    var services = std.ArrayListUnmanaged(Service){};

    const query_fmt = "{{\"query\":\"{{project(id:\\\"{s}\\\"){{services{{edges{{node{{id name}}}}}}}}}}\"}}";
    const query = try std.fmt.allocPrint(allocator, query_fmt, .{project_id});
    defer allocator.free(query);

    const result = try execCurl(allocator, token, query);
    defer allocator.free(result);

    // Debug: print result if it looks like an error
    if (std.mem.indexOf(u8, result, "\"errors\"")) |_| {
        std.debug.print("⚠️  API error: {s}\n", .{result});
        return error.ApiError;
    }

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, result, .{});
    defer parsed.deinit();

    const data = parsed.value.object.get("data") orelse {
        std.debug.print("⚠️  No data in response: {s}\n", .{result});
        return error.ApiError;
    };
    const project = data.object.get("project") orelse {
        std.debug.print("⚠️  No project in data: {s}\n", .{result});
        return error.ApiError;
    };
    const servs = project.object.get("services").?.object.get("edges").?.array.items;

    try services.ensureTotalCapacity(allocator, @intCast(servs.len));

    for (servs) |edge| {
        const node = edge.object.get("node").?;
        const id = node.object.get("id").?.string;
        const name = node.object.get("name").?.string;

        services.appendAssumeCapacity(.{
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
        });
    }

    return services;
}

fn deleteService(allocator: std.mem.Allocator, token: []const u8, service_id: []const u8) !bool {
    const mutation_fmt = "{{\"query\":\"mutation($id: ID!) {{ serviceDelete(id: $id) {{ id }} }}\",\"variables\":{{\"id\":\"{s}\"}}}}";
    const mutation = try std.fmt.allocPrint(allocator, mutation_fmt, .{service_id});
    defer allocator.free(mutation);

    const result = try execCurl(allocator, token, mutation);
    defer allocator.free(result);

    // Check for errors
    if (std.mem.indexOf(u8, result, "\"errors\"")) |_| {
        return false;
    }

    return true;
}

fn execCurl(allocator: std.mem.Allocator, token: []const u8, body: []const u8) ![]const u8 {
    const auth_header = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth_header);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "curl", "-s",        "-X",                                       "POST",
            "-H",   auth_header, "-H",                                       "Content-Type: application/json",
            "-d",   body,        "https://railway.com/graphql/v2",
        },
    });
    defer {
        allocator.free(result.stderr);
    }

    if (result.term.Exited != 0) return error.CurlFailed;

    return result.stdout;
}
