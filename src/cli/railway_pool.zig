// Railway Pool Management — Control Trinity Training Farm
// Commands: status, create, deploy, list, env
const std = @import("std");

const Account = struct {
    name: []const u8,
    token_env: []const u8,
    project_id: []const u8,
    env_id: []const u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        std.process.exit(1);
    }

    const command = args[1];

    // Load .env
    const env_map = try loadEnv(allocator);
    defer {
        for (env_map.keys()) |k| allocator.free(k);
        for (env_map.values()) |v| allocator.free(v);
        env_map.deinit(allocator);
    }

    // Define all accounts
    const accounts = [_]Account{
        .{ .name = "#1", .token_env = "RAILWAY_API_TOKEN", .project_id = "RAILWAY_PROJECT_ID", .env_id = "RAILWAY_ENVIRONMENT_ID" },
        .{ .name = "#2", .token_env = "RAILWAY_API_TOKEN_2", .project_id = "RAILWAY_PROJECT_ID_2", .env_id = "RAILWAY_ENVIRONMENT_ID_2" },
        .{ .name = "#3", .token_env = "RAILWAY_API_TOKEN_3", .project_id = "RAILWAY_PROJECT_ID_3", .env_id = "RAILWAY_ENVIRONMENT_ID_3" },
        .{ .name = "#8", .token_env = "RAILWAY_API_TOKEN_8", .project_id = "RAILWAY_PROJECT_ID_8", .env_id = "RAILWAY_ENVIRONMENT_ID_8" },
        .{ .name = "#9", .token_env = "RAILWAY_API_TOKEN_9", .project_id = "RAILWAY_PROJECT_ID_9", .env_id = "RAILWAY_ENVIRONMENT_ID_9" },
        .{ .name = "#10", .token_env = "RAILWAY_API_TOKEN_10", .project_id = "RAILWAY_PROJECT_ID_10", .env_id = "RAILWAY_ENVIRONMENT_ID_10" },
        .{ .name = "#11", .token_env = "RAILWAY_API_TOKEN_11", .project_id = "RAILWAY_PROJECT_ID_11", .env_id = "RAILWAY_ENVIRONMENT_ID_11" },
        .{ .name = "#12", .token_env = "RAILWAY_API_TOKEN_12", .project_id = "RAILWAY_PROJECT_ID_12", .env_id = "RAILWAY_ENVIRONMENT_ID_12" },
    };

    if (std.mem.eql(u8, command, "status")) {
        try cmdStatus(allocator, env_map, &accounts);
    } else if (std.mem.eql(u8, command, "create")) {
        if (args.len < 3) {
            std.debug.print("Usage: tri pool create <wave-number>\n", .{});
            std.process.exit(1);
        }
        const wave = args[2];
        try cmdCreate(allocator, env_map, &accounts, wave);
    } else if (std.mem.eql(u8, command, "deploy")) {
        if (args.len < 3) {
            std.debug.print("Usage: tri pool deploy <wave-number>\n", .{});
            std.process.exit(1);
        }
        const wave = args[2];
        try cmdDeploy(allocator, env_map, &accounts, wave);
    } else if (std.mem.eql(u8, command, "list")) {
        try cmdList(allocator, env_map, &accounts);
    } else {
        printUsage();
        std.process.exit(1);
    }
}

fn printUsage() void {
    std.debug.print(
        \\Railway Pool Management — Control Trinity Training Farm
        \\
        \\Usage: tri pool <command> [args]
        \\
        \\Commands:
        \\  status              Show all accounts and service counts
        \\  create <wave>       Create services for a wave (e.g., 9, 10)
        \\  deploy <wave>       Deploy wave with env vars
        \\  list               List all services across all accounts
        \\
        \\Examples:
        \\  tri pool status
        \\  tri pool create 9
        \\  tri pool deploy 9
        \\  tri pool list
        \\
    , .{});
}

fn cmdStatus(allocator: std.mem.Allocator, env_map: std.StringHashMap([]const u8), accounts: []const Account) !void {
    std.debug.print("\n📊 RAILWAY FARM STATUS\n", .{});
    std.debug.print("{s:=<80}\n\n", .{"="});

    var total_services: usize = 0;

    for (accounts) |acc| {
        const token = env_map.get(acc.token_env) orelse {
            std.debug.print("⚠️  Account {s}: NO TOKEN\n", .{acc.name});
            continue;
        };
        const project_id = env_map.get(acc.project_id) orelse {
            std.debug.print("⚠️  Account {s}: NO PROJECT_ID\n", .{acc.name});
            continue;
        };

        const count = try countServices(allocator, token, project_id);
        total_services += count;

        const percent = @as(f64, @floatFromInt(count)) / 48.0 * 100.0;
        const status = if (percent < 20) "🟢 FREE" else if (percent < 60) "🟡 PARTIAL" else "🔴 FULL";

        std.debug.print("{s} Account {s}: {d:3} services ({d:.1}%)\n", .{ status, acc.name, count, percent });
    }

    std.debug.print("\n", .{});
    std.debug.print("TOTAL: {d}/48 services ({d:.1}%)\n", .{ total_services, @as(f64, @floatFromInt(total_services)) / 48.0 * 100.0 });
    std.debug.print("\n", .{});
}

fn cmdCreate(allocator: std.mem.Allocator, env_map: std.StringHashMap([]const u8), accounts: []const Account, wave: []const u8) !void {
    std.debug.print("\n🚀 CREATE WAVE {s}\n", .{wave});
    std.debug.print("{s:=<80}\n\n", .{"="});

    // Find accounts for this wave
    const wave_num = try std.fmt.parseInt(usize, wave, 10);

    // Map wave to accounts (Wave 9 = #9, #10, #11, #12)
    const start_idx = switch (wave_num) {
        9 => 4, // #9
        10 => 5, // #10
        11 => 6, // #11
        12 => 7, // #12
        else => {
            std.debug.print("⚠️  Unknown wave: {s}\n", .{wave});
            return error.UnknownWave;
        },
    };

    const acc = &accounts[start_idx];
    const token = env_map.get(acc.token_env) orelse {
        std.debug.print("⚠️  No token for account {s}\n", .{acc.name});
        return error.NoToken;
    };
    const project_id = env_map.get(acc.project_id) orelse {
        std.debug.print("⚠️  No project_id for account {s}\n", .{acc.name});
        return error.NoProjectId;
    };

    // Create 8 services for this wave
    const service_names = [_][]const u8{ "w9-5", "w9-6", "w9-7", "w9-8", "w10-5", "w10-6", "w10-7", "w10-8" };
    // Adjust names based on wave
    const base = try std.fmt.allocPrint(allocator, "w{s}", .{wave});

    var created: usize = 0;
    for (5..=8) |i| {
        const svc_name = try std.fmt.allocPrint(allocator, "{s}-{d}", .{ base, i });
        defer allocator.free(svc_name);

        std.debug.print("Creating {s}... ", .{svc_name});

        const svc_id = try createService(allocator, token, project_id, svc_name);
        if (svc_id.len > 0) {
            std.debug.print("✅ {s}\n", .{svc_id});
            created += 1;
        } else {
            std.debug.print("❌ FAILED\n", .{});
        }
    }

    std.debug.print("\n✅ Created {d} services for Wave {s}\n\n", .{ created, wave });
}

fn cmdDeploy(allocator: std.mem.Allocator, env_map: std.StringHashMap([]const u8), accounts: []const Account, wave: []const u8) !void {
    std.debug.print("\n🔥 DEPLOY WAVE {s}\n", .{wave});
    std.debug.print("{s:=<80}\n\n", .{"="});

    // Deploy implementation would go here
    std.debug.print("⚠️  Deploy command not yet implemented\n", .{});
    std.debug.print("Use GraphQL API directly for now\n\n", .{});
}

fn cmdList(allocator: std.mem.Allocator, env_map: std.StringHashMap([]const u8), accounts: []const Account) !void {
    std.debug.print("\n📋 ALL SERVICES\n", .{});
    std.debug.print("{s:=<80}\n\n", .{"="});

    for (accounts) |acc| {
        const token = env_map.get(acc.token_env) orelse continue;
        const project_id = env_map.get(acc.project_id) orelse continue;

        std.debug.print("Account {s}:\n", .{acc.name});

        const services = try listServices(allocator, token, project_id);
        defer {
            for (services.items) |svc| {
                allocator.free(svc.id);
                allocator.free(svc.name);
            }
            services.deinit(allocator);
        }

        for (services.items) |svc| {
            std.debug.print("  - {s}\n", .{svc.name});
        }
        std.debug.print("\n", .{});
    }
}

fn countServices(allocator: std.mem.Allocator, token: []const u8, project_id: []const u8) !usize {
    const services = try listServices(allocator, token, project_id);
    defer {
        for (services.items) |svc| {
            allocator.free(svc.id);
            allocator.free(svc.name);
        }
        services.deinit(allocator);
    }
    return services.items.len;
}

const Service = struct {
    id: []const u8,
    name: []const u8,
};

fn listServices(allocator: std.mem.Allocator, token: []const u8, project_id: []const u8) !std.ArrayListUnmanaged(Service) {
    var services = std.ArrayListUnmanaged(Service){};

    const query_fmt = "{{\"query\":\"{{project(id:\\\"{s}\\\"){{services{{edges{{node{{id name}}}}}}}}}}\"}}";
    const query = try std.fmt.allocPrint(allocator, query_fmt, .{project_id});
    defer allocator.free(query);

    const result = try execCurl(allocator, token, query);
    defer allocator.free(result);

    if (std.mem.indexOf(u8, result, "\"errors\"")) |_| {
        return services;
    }

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, result, .{});
    defer parsed.deinit();

    const data = parsed.value.object.get("data") orelse return services;
    const project = data.object.get("project") orelse return services;
    const servs = project.object.get("services").?.object.get("edges").?.array.items orelse &[_]std.json.Value{};

    try services.ensureTotalCapacity(allocator, @intCast(servs.len));

    for (servs) |edge| {
        const node = edge.object.get("node") orelse continue;
        const id = node.object.get("id").?.string orelse continue;
        const name = node.object.get("name").?.string orelse continue;

        services.appendAssumeCapacity(.{
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
        });
    }

    return services;
}

fn createService(allocator: std.mem.Allocator, token: []const u8, project_id: []const u8, name: []const u8) ![]const u8 {
    const mutation_fmt = "{{\"query\":\"mutation {{ serviceCreate(input: {{projectId: \\\"{s}\\\", name: \\\"{s}\\\"}}) {{ id }} }}\"}}";
    const mutation = try std.fmt.allocPrint(allocator, mutation_fmt, .{ project_id, name });
    defer allocator.free(mutation);

    const result = try execCurl(allocator, token, mutation);
    defer allocator.free(result);

    if (std.mem.indexOf(u8, result, "\"errors\"")) |_| {
        return "";
    }

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, result, .{});
    defer parsed.deinit();

    const data = parsed.value.object.get("data") orelse return "";
    const svc = data.object.get("serviceCreate") orelse return "";
    const id = svc.object.get("id").?.string orelse return "";

    return try allocator.dupe(u8, id);
}

fn execCurl(allocator: std.mem.Allocator, token: []const u8, body: []const u8) ![]const u8 {
    const auth_header = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth_header);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "curl", "-s", "-X", "POST",
            "-H",   auth_header,
            "-H",   "Content-Type: application/json",
            "-d",   body,
            "https://railway.com/graphql/v2",
        },
    });
    defer {
        allocator.free(result.stderr);
    }

    if (result.term.Exited != 0) return error.CurlFailed;

    return result.stdout;
}

fn loadEnv(allocator: std.mem.Allocator) !std.StringHashMap([]const u8) {
    var env_map = std.StringHashMap([]const u8).init(allocator);

    const env_path = ".env";
    const content = try std.fs.cwd().readFileAlloc(allocator, env_path, 1_000_000);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (line.len == 0 or line[0] == '#') continue;

        const eq_idx = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = line[0..eq_idx];
        var value = line[eq_idx + 1 ..];

        // Trim whitespace
        while (value.len > 0 and std.ascii.isWhitespace(value[0])) value = value[1..];
        while (value.len > 0 and std.ascii.isWhitespace(value[value.len - 1])) value = value[0 .. value.len - 1];

        if (value.len > 0) {
            try env_map.put(try allocator.dupe(u8, key), try allocator.dupe(u8, value));
        }
    }

    return env_map;
}
