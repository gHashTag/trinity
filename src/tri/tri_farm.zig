// ═══════════════════════════════════════════════════════════════════════════════
// TRI FARM — Railway Training Farm Status (3 accounts)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Native Zig replacement for Python/curl farm queries.
// Uses RailwayApi.initWithSuffix() for multi-account support.
//
// Commands:
//   tri farm status  — table of all services across 3 accounts
//   tri farm idle    — only finished/idle services (for recycling)
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const railway_api = @import("railway_api.zig");
const RailwayApi = railway_api.RailwayApi;

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const DIM = "\x1b[2m";

const Account = struct {
    name: []const u8,
    suffix: []const u8,
    env_id: []const u8,
};

const farm_accounts = [_]Account{
    .{ .name = "PRIMARY", .suffix = "", .env_id = "6748f1ad-9c2f-4b71-9a90-67f40ce34dc9" },
    .{ .name = "FARM-2", .suffix = "_2", .env_id = "d8602284-9bba-48bc-94f5-470f9d1fff48" },
    .{ .name = "FARM-3", .suffix = "_3", .env_id = "912e9084-e1ad-4bf1-aaea-0a77f9b2a158" },
};

pub fn runFarmCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, subcmd, "status")) {
        return runFarmStatus(allocator, false);
    } else if (std.mem.eql(u8, subcmd, "idle")) {
        return runFarmStatus(allocator, true);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printHelp();
    } else {
        print("{s}Unknown farm subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

fn getJsonObject(val: std.json.Value, key: []const u8) ?std.json.Value {
    if (val != .object) return null;
    return val.object.get(key);
}

fn getJsonString(val: std.json.Value, key: []const u8) []const u8 {
    if (val != .object) return "?";
    const v = val.object.get(key) orelse return "?";
    if (v != .string) return "?";
    return v.string;
}

fn runFarmStatus(allocator: Allocator, idle_only: bool) !void {
    print("\n{s}☁️  RAILWAY TRAINING FARM{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var total_services: usize = 0;
    var total_active: usize = 0;
    var total_idle: usize = 0;
    var total_crashed: usize = 0;

    for (farm_accounts) |acct| {
        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch |err| {
            print("{s}=== {s} ==={s}\n", .{ BOLD, acct.name, RESET });
            print("  {s}⚠️  No token ({s} error){s}\n\n", .{ YELLOW, @errorName(err), RESET });
            continue;
        };
        defer api.deinit();

        print("{s}=== {s} ==={s}\n", .{ BOLD, acct.name, RESET });

        const resp = api.getServiceInstances(acct.env_id) catch |err| {
            print("  {s}⚠️  API error: {s}{s}\n\n", .{ RED, @errorName(err), RESET });
            continue;
        };
        defer allocator.free(resp);

        // Parse JSON response
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, resp, .{}) catch {
            print("  {s}⚠️  Invalid JSON response{s}\n\n", .{ RED, RESET });
            continue;
        };
        defer parsed.deinit();

        // Navigate: data.environment.serviceInstances.edges
        const data_val = getJsonObject(parsed.value, "data") orelse {
            // Check for errors
            if (getJsonObject(parsed.value, "errors")) |errors_val| {
                if (errors_val == .array and errors_val.array.items.len > 0) {
                    const msg = getJsonString(errors_val.array.items[0], "message");
                    print("  {s}⚠️  {s}{s}\n\n", .{ RED, msg, RESET });
                    continue;
                }
            }
            print("  {s}⚠️  No data in response{s}\n\n", .{ RED, RESET });
            continue;
        };

        const env_val = getJsonObject(data_val, "environment") orelse {
            print("  {s}⚠️  No environment in response{s}\n\n", .{ RED, RESET });
            continue;
        };
        const si_val = getJsonObject(env_val, "serviceInstances") orelse {
            print("  {s}⚠️  No serviceInstances{s}\n\n", .{ RED, RESET });
            continue;
        };
        const edges_val = getJsonObject(si_val, "edges") orelse {
            print("  {s}⚠️  No edges{s}\n\n", .{ RED, RESET });
            continue;
        };

        if (edges_val != .array) {
            print("  {s}⚠️  edges is not array{s}\n\n", .{ RED, RESET });
            continue;
        }

        const items = edges_val.array.items;

        if (!idle_only) {
            print("  {s}──────────────────────────────────────────────────{s}\n", .{ DIM, RESET });
            print("  {s}SERVICE                   STATUS          REGION{s}\n", .{ DIM, RESET });
            print("  {s}──────────────────────────────────────────────────{s}\n", .{ DIM, RESET });
        }

        var acct_active: usize = 0;
        var acct_idle: usize = 0;
        var acct_crashed: usize = 0;

        for (items) |edge| {
            const node = getJsonObject(edge, "node") orelse continue;

            const name = getJsonString(node, "serviceName");
            const region = getJsonString(node, "region");

            // latestDeployment.status
            var status: []const u8 = "NONE";
            if (getJsonObject(node, "latestDeployment")) |dep| {
                const st = getJsonString(dep, "status");
                if (!std.mem.eql(u8, st, "?")) status = st;
            }

            const is_idle = std.mem.eql(u8, status, "SUCCESS") or
                std.mem.eql(u8, status, "REMOVED") or
                std.mem.eql(u8, status, "NONE");
            const is_crashed = std.mem.eql(u8, status, "CRASHED") or
                std.mem.eql(u8, status, "FAILED");
            const is_building = std.mem.eql(u8, status, "DEPLOYING") or
                std.mem.eql(u8, status, "BUILDING") or
                std.mem.eql(u8, status, "INITIALIZING");

            if (is_idle) {
                acct_idle += 1;
            } else if (is_crashed) {
                acct_crashed += 1;
            } else {
                acct_active += 1;
            }

            if (idle_only and !is_idle) continue;

            const status_icon = if (is_crashed) "🔴" else if (is_idle) "💤" else if (is_building) "🔨" else "🟢";
            const color = if (is_crashed) RED else if (is_idle) YELLOW else GREEN;

            print("  {s} {s}{s}{s}", .{ status_icon, color, name, RESET });
            // Pad name to 25 chars
            const name_len = name.len;
            if (name_len < 25) {
                var pad_i: usize = 0;
                while (pad_i < 25 - name_len) : (pad_i += 1) {
                    print(" ", .{});
                }
            }
            print(" {s}{s}{s}", .{ color, status, RESET });
            const status_len = status.len;
            if (status_len < 15) {
                var pad_i: usize = 0;
                while (pad_i < 15 - status_len) : (pad_i += 1) {
                    print(" ", .{});
                }
            }
            print(" {s}\n", .{region});
        }

        total_services += items.len;
        total_active += acct_active;
        total_idle += acct_idle;
        total_crashed += acct_crashed;

        print("  {s}──────────────────────────────────────────────────{s}\n", .{ DIM, RESET });
        print("  Total: {d} | {s}🟢 {d}{s} | {s}💤 {d}{s} | {s}🔴 {d}{s}\n\n", .{
            items.len,
            GREEN,  acct_active,  RESET,
            YELLOW, acct_idle,    RESET,
            RED,    acct_crashed, RESET,
        });
    }

    // Summary
    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}TOTAL: {d} services | 🟢 {d} active | 💤 {d} idle | 🔴 {d} crashed{s}\n\n", .{
        BOLD,
        total_services,
        total_active,
        total_idle,
        total_crashed,
        RESET,
    });
}

fn printHelp() void {
    print(
        \\
        \\Usage: tri farm <command>
        \\
        \\Commands:
        \\  status    Show all services across 3 Railway accounts (default)
        \\  idle      Show only finished/idle services (for recycling)
        \\  help      Show this help
        \\
        \\Accounts: PRIMARY (RAILWAY_API_TOKEN), FARM-2 (_2), FARM-3 (_3)
        \\Env vars must be set (source .env).
        \\
    , .{});
}

test "farm command help" {
    printHelp();
}
