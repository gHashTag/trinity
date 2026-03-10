// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLOUD — Native Railway Integration CLI
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri cloud status              Show Railway services + SSH server status
//   tri cloud logs [service]      Get deployment logs (via GraphQL)
//   tri cloud vars [service]      List environment variables
//   tri cloud vars set K=V        Upsert environment variable
//   tri cloud deploy [service]    Trigger redeployment
//   tri cloud exec <command>      Run command on Railway via SSH
//   tri cloud pull                Pull latest code on Railway server
//   tri cloud ssh-status          Quick SSH server status (tmux, git, oracle)
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const railway_api = @import("railway_api.zig");
const railway_ssh = @import("railway_ssh.zig");

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const CYAN = "\x1b[36m";
const GRAY = "\x1b[90m";
const GOLDEN = "\x1b[38;5;220m";

const print = std.debug.print;
const eql = std.mem.eql;

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runCloudCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printUsage();
        return;
    }

    const subcmd = args[0];
    const sub_args = args[1..];

    if (eql(u8, subcmd, "status")) {
        return cloudStatus(allocator);
    } else if (eql(u8, subcmd, "logs")) {
        return cloudLogs(allocator, sub_args);
    } else if (eql(u8, subcmd, "vars")) {
        return cloudVars(allocator, sub_args);
    } else if (eql(u8, subcmd, "deploy")) {
        return cloudDeploy(allocator, sub_args);
    } else if (eql(u8, subcmd, "exec")) {
        return cloudExec(allocator, sub_args);
    } else if (eql(u8, subcmd, "pull")) {
        return cloudPull(allocator);
    } else if (eql(u8, subcmd, "ssh-status")) {
        return cloudSSHStatus(allocator);
    } else {
        print("{s}Unknown subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printUsage();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUBCOMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// tri cloud status — Show Railway services via GraphQL API
fn cloudStatus(allocator: Allocator) !void {
    var api = railway_api.RailwayApi.init(allocator) catch |err| {
        switch (err) {
            error.MissingToken => {
                print("{s}Error: RAILWAY_API_TOKEN not set{s}\n", .{ RED, RESET });
                print("Get your token: https://railway.com/account/tokens\n", .{});
                print("Then: export RAILWAY_API_TOKEN=<token>\n", .{});
            },
            error.MissingProjectId => {
                print("{s}Error: No Railway project configured{s}\n", .{ RED, RESET });
                print("Set RAILWAY_PROJECT_ID or add .railway.json\n", .{});
            },
            else => print("{s}Error initializing Railway API{s}\n", .{ RED, RESET }),
        }
        return;
    };
    defer api.deinit();

    const response = api.getServices() catch |err| {
        print("{s}Failed to fetch services: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(response);

    // Print header
    print("\n{s}{s}", .{ GOLDEN, BOLD });
    print("═══════════════════════════════════════════════════\n", .{});
    print(" TRINITY CLOUD — railway.app\n", .{});
    print("═══════════════════════════════════════════════════{s}\n", .{RESET});

    // Parse and display services from JSON response
    printServicesFromJson(response);

    print("{s}═══════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
}

/// tri cloud logs [service] — Get deployment logs
fn cloudLogs(allocator: Allocator, args: []const []const u8) !void {
    _ = args;

    var api = railway_api.RailwayApi.init(allocator) catch |err| {
        printApiInitError(err);
        return;
    };
    defer api.deinit();

    // Get services first, then deployments for the first/named service
    const services_json = api.getServices() catch |err| {
        print("{s}Failed to fetch services: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(services_json);

    print("{s}Services response:{s}\n{s}\n", .{ GRAY, RESET, services_json });
    print("\n{s}Note: For full logs, use: tri cloud exec \"tail -100 /data/trinity/.ralph/logs/latest_stream.log\"{s}\n", .{ CYAN, RESET });
}

/// tri cloud vars [service] — List or set environment variables
fn cloudVars(allocator: Allocator, args: []const []const u8) !void {
    var api = railway_api.RailwayApi.init(allocator) catch |err| {
        printApiInitError(err);
        return;
    };
    defer api.deinit();

    // Check for "set K=V" subcommand
    if (args.len >= 2 and eql(u8, args[0], "set")) {
        const kv = args[1];
        const eq_idx = std.mem.indexOf(u8, kv, "=") orelse {
            print("{s}Error: Expected KEY=VALUE format{s}\n", .{ RED, RESET });
            return;
        };
        const key = kv[0..eq_idx];
        const value = kv[eq_idx + 1 ..];

        // Need service_id and environment_id — get from args or default
        const service_id = if (args.len >= 3) args[2] else "";
        const env_id = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID") catch "";

        if (service_id.len == 0 or env_id.len == 0) {
            print("{s}Error: Need service ID and RAILWAY_ENVIRONMENT_ID{s}\n", .{ RED, RESET });
            print("Usage: tri cloud vars set KEY=VALUE <service-id>\n", .{});
            return;
        }

        const response = api.upsertVariable(service_id, env_id, key, value) catch |err| {
            print("{s}Failed to set variable: {}{s}\n", .{ RED, err, RESET });
            return;
        };
        defer allocator.free(response);

        print("{s}✓ Set {s}={s}{s}\n", .{ GREEN, key, value, RESET });
        return;
    }

    // List variables
    const service_id = if (args.len >= 1) args[0] else "";
    const env_id = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID") catch "";

    if (service_id.len == 0 or env_id.len == 0) {
        print("{s}Error: Need service ID and RAILWAY_ENVIRONMENT_ID{s}\n", .{ RED, RESET });
        print("Usage: tri cloud vars <service-id>\n", .{});
        print("   or: tri cloud vars set KEY=VALUE <service-id>\n", .{});
        return;
    }

    const response = api.getVariables(service_id, env_id) catch |err| {
        print("{s}Failed to fetch variables: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(response);

    print("{s}{s}Environment Variables:{s}\n", .{ BOLD, CYAN, RESET });
    print("{s}\n", .{response});
}

/// tri cloud deploy [service] — Trigger redeployment
fn cloudDeploy(allocator: Allocator, args: []const []const u8) !void {
    var api = railway_api.RailwayApi.init(allocator) catch |err| {
        printApiInitError(err);
        return;
    };
    defer api.deinit();

    const service_id = if (args.len >= 1) args[0] else "";
    const env_id = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID") catch "";

    if (service_id.len == 0 or env_id.len == 0) {
        print("{s}Error: Need service ID and RAILWAY_ENVIRONMENT_ID{s}\n", .{ RED, RESET });
        print("Usage: tri cloud deploy <service-id>\n", .{});
        return;
    }

    print("{s}Triggering redeployment...{s}\n", .{ YELLOW, RESET });

    const response = api.redeployService(service_id, env_id) catch |err| {
        print("{s}Failed to redeploy: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(response);

    print("{s}✓ Redeployment triggered{s}\n", .{ GREEN, RESET });
}

/// tri cloud exec <command> — Run arbitrary command via SSH
fn cloudExec(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("Usage: tri cloud exec <command>\n", .{});
        return;
    }

    // Join all remaining args into a single command string
    var total_len: usize = 0;
    for (args) |a| {
        total_len += a.len + 1;
    }
    const command = try allocator.alloc(u8, total_len);
    defer allocator.free(command);

    var pos: usize = 0;
    for (args, 0..) |a, i| {
        @memcpy(command[pos .. pos + a.len], a);
        pos += a.len;
        if (i < args.len - 1) {
            command[pos] = ' ';
            pos += 1;
        }
    }
    const cmd = command[0..pos];

    const ssh = railway_ssh.RailwaySSH.initDefault();

    print("{s}$ {s}{s}\n", .{ GRAY, cmd, RESET });

    const output = ssh.exec(allocator, cmd) catch |err| {
        print("{s}SSH exec failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(output);

    print("{s}", .{output});
}

/// tri cloud pull — Pull latest code on Railway
fn cloudPull(allocator: Allocator) !void {
    const ssh = railway_ssh.RailwaySSH.initDefault();

    print("{s}Pulling latest code on Railway...{s}\n", .{ CYAN, RESET });

    const output = ssh.pullCode(allocator) catch |err| {
        print("{s}Pull failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(output);

    print("{s}", .{output});

    if (std.mem.indexOf(u8, output, "---DONE---") != null) {
        print("{s}✓ Code updated on Railway{s}\n", .{ GREEN, RESET });
    }
}

/// tri cloud ssh-status — Quick SSH server status
fn cloudSSHStatus(allocator: Allocator) !void {
    const ssh = railway_ssh.RailwaySSH.initDefault();

    const output = ssh.getStatus(allocator) catch |err| {
        print("{s}SSH status failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(output);

    print("\n{s}{s}", .{ GOLDEN, BOLD });
    print("═══════════════════════════════════════════════════\n", .{});
    print(" RAILWAY SERVER STATUS (SSH)\n", .{});
    print("═══════════════════════════════════════════════════{s}\n", .{RESET});
    print("{s}", .{output});
    print("{s}═══════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn printUsage() void {
    print("\n{s}{s}TRI CLOUD — Railway Integration{s}\n\n", .{ BOLD, CYAN, RESET });
    print("  {s}tri cloud status{s}              Show Railway services\n", .{ GREEN, RESET });
    print("  {s}tri cloud logs{s}                Get deployment logs\n", .{ GREEN, RESET });
    print("  {s}tri cloud vars <svc-id>{s}       List environment variables\n", .{ GREEN, RESET });
    print("  {s}tri cloud vars set K=V <id>{s}   Set environment variable\n", .{ GREEN, RESET });
    print("  {s}tri cloud deploy <svc-id>{s}     Trigger redeployment\n", .{ GREEN, RESET });
    print("  {s}tri cloud exec <command>{s}      Run command via SSH\n", .{ GREEN, RESET });
    print("  {s}tri cloud pull{s}                Pull latest code on Railway\n", .{ GREEN, RESET });
    print("  {s}tri cloud ssh-status{s}          Quick SSH server status\n", .{ GREEN, RESET });
    print("\n  {s}Env vars: RAILWAY_API_TOKEN, RAILWAY_PROJECT_ID, RAILWAY_ENVIRONMENT_ID{s}\n\n", .{ GRAY, RESET });
}

fn printApiInitError(err: anyerror) void {
    switch (err) {
        error.MissingToken => {
            print("{s}Error: RAILWAY_API_TOKEN not set{s}\n", .{ RED, RESET });
            print("Get token: https://railway.com/account/tokens\n", .{});
        },
        error.MissingProjectId => {
            print("{s}Error: No Railway project configured{s}\n", .{ RED, RESET });
            print("Set RAILWAY_PROJECT_ID or add .railway.json\n", .{});
        },
        else => print("{s}Error initializing Railway API: {}{s}\n", .{ RED, err, RESET }),
    }
}

fn printServicesFromJson(json: []const u8) void {
    // Simple line-by-line display of the raw response
    // In production this would parse JSON properly, but Zig std has no JSON writer
    // that makes table formatting easy, so we display raw for now
    print(" {s}Service data (JSON):{s}\n", .{ GRAY, RESET });

    // Try to find service names in the response for a compact view
    var offset: usize = 0;
    var count: u32 = 0;
    while (std.mem.indexOfPos(u8, json, offset, "\"name\":\"")) |idx| {
        const start = idx + 8; // len of "name":"
        const end = std.mem.indexOfPos(u8, json, start, "\"") orelse break;
        const name = json[start..end];
        count += 1;
        print(" {s}●{s} {s}\n", .{ GREEN, RESET, name });
        offset = end + 1;
    }

    if (count == 0) {
        print(" {s}(Could not parse services — raw response below){s}\n", .{ YELLOW, RESET });
        // Print first 500 chars of response
        const max = @min(json.len, 500);
        print(" {s}{s}{s}\n", .{ GRAY, json[0..max], RESET });
    } else {
        print(" {s}{d} service(s) found{s}\n", .{ GRAY, count, RESET });
    }
}
