// @origin(spec:tri_depin.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI DEPIN — DePIN Node Protocol (Phase 1)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Treats Railway services as DePIN nodes. Phase 1: read-only status + fitness.
//
// Commands:
//   tri depin status   — network overview dashboard
//   tri depin nodes    — list all nodes with type/status/fitness
//   tri depin fitness  — aggregate fitness across node types
//
// Node types:
//   TRAIN — hslm-* services (training workloads)
//   CODE  — agent-* services (code generation agents)
//   INFER — other services (inference/API)
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const railway_api = @import("railway_api.zig");
const RailwayApi = railway_api.RailwayApi;
const farm_accounts_mod = @import("farm_accounts.zig");
const Account = farm_accounts_mod.Account;

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";

const NodeType = enum {
    train,
    code,
    infer,

    pub fn toString(self: NodeType) []const u8 {
        return switch (self) {
            .train => "TRAIN",
            .code => "CODE",
            .infer => "INFER",
        };
    }

    pub fn emoji(self: NodeType) []const u8 {
        return switch (self) {
            .train => "🧠",
            .code => "💻",
            .infer => "⚡",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDepinCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, subcmd, "status")) {
        try runDepinStatus(allocator);
    } else if (std.mem.eql(u8, subcmd, "nodes")) {
        try runDepinNodes(allocator);
    } else if (std.mem.eql(u8, subcmd, "fitness")) {
        try runDepinFitness(allocator);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printHelp();
    } else {
        print("{s}Unknown depin subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON HELPERS (same pattern as tri_farm)
// ═══════════════════════════════════════════════════════════════════════════════

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

fn getEdgesArray(root: std.json.Value) ?[]const std.json.Value {
    const data = getJsonObject(root, "data") orelse return null;
    const instances = getJsonObject(data, "serviceInstances") orelse return null;
    const edges = getJsonObject(instances, "edges") orelse return null;
    if (edges != .array) return null;
    return edges.array.items;
}

fn getNodeName(edge: std.json.Value) []const u8 {
    const node = getJsonObject(edge, "node") orelse return "?";
    return getJsonString(node, "serviceName");
}

fn getNodeStatus(edge: std.json.Value) []const u8 {
    const node = getJsonObject(edge, "node") orelse return "UNKNOWN";
    const dep = getJsonObject(node, "latestDeployment") orelse return "NONE";
    return getJsonString(dep, "status");
}

fn isActiveStatus(status: []const u8) bool {
    return std.mem.eql(u8, status, "SUCCESS") or
        std.mem.eql(u8, status, "DEPLOYING") or
        std.mem.eql(u8, status, "BUILDING");
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS — network overview dashboard
// ═══════════════════════════════════════════════════════════════════════════════

fn runDepinStatus(allocator: Allocator) !void {
    print("\n{s}🌐 DePIN NETWORK STATUS{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var total_nodes: usize = 0;
    var total_active: usize = 0;
    var train_count: usize = 0;
    var code_count: usize = 0;
    var infer_count: usize = 0;
    var accounts_online: usize = 0;

    var acct_buf: [farm_accounts_mod.MAX_ACCOUNTS]Account = undefined;
    const acct_count = farm_accounts_mod.discoverAccounts(allocator, &acct_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &acct_buf, acct_count);
    if (acct_count == 0) {
        print("{s}⚠️  No Railway accounts found. Set RAILWAY_API_TOKEN in .env{s}\n", .{ YELLOW, RESET });
        return;
    }

    for (acct_buf[0..acct_count]) |acct| {
        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch {
            continue;
        };
        defer api.deinit();

        const resp = api.getServiceInstances(acct.env_id) catch continue;
        defer allocator.free(resp);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, resp, .{}) catch continue;
        defer parsed.deinit();

        const items = getEdgesArray(parsed.value) orelse continue;
        accounts_online += 1;

        for (items) |edge| {
            const name = getNodeName(edge);
            const node_type = classifyNode(name);
            const status = getNodeStatus(edge);
            const active = isActiveStatus(status);

            total_nodes += 1;
            if (active) total_active += 1;

            switch (node_type) {
                .train => train_count += 1,
                .code => code_count += 1,
                .infer => infer_count += 1,
            }
        }
    }

    // Dashboard
    print("  {s}Accounts:{s}  {d}/{d} online\n", .{ CYAN, RESET, accounts_online, acct_count });
    print("  {s}Nodes:{s}     {d} total, {s}{d} active{s}\n", .{
        CYAN, RESET, total_nodes, GREEN, total_active, RESET,
    });
    print("\n", .{});

    print("  {s}Node Distribution:{s}\n", .{ BOLD, RESET });
    print("    🧠 TRAIN:  {d}\n", .{train_count});
    print("    💻 CODE:   {d}\n", .{code_count});
    print("    ⚡ INFER:  {d}\n", .{infer_count});
    print("\n", .{});

    // Network health
    const health: f64 = if (total_nodes > 0)
        @as(f64, @floatFromInt(total_active)) / @as(f64, @floatFromInt(total_nodes)) * 100.0
    else
        0.0;

    const health_color = if (health >= 80) GREEN else if (health >= 50) YELLOW else RED;
    const health_grade: []const u8 = if (health >= 80) "HEALTHY" else if (health >= 50) "DEGRADED" else "CRITICAL";

    print("  {s}Network Health:{s} {s}{d:.0}% — {s}{s}\n\n", .{
        BOLD, RESET, health_color, health, health_grade, RESET,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// NODES — list all nodes with details
// ═══════════════════════════════════════════════════════════════════════════════

fn runDepinNodes(allocator: Allocator) !void {
    print("\n{s}🌐 DePIN NODES{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}Type   Status    Account    Name{s}\n", .{ DIM, RESET });
    print("  {s}─────  ────────  ─────────  ────────────────────────────{s}\n", .{ DIM, RESET });

    var acct_buf: [farm_accounts_mod.MAX_ACCOUNTS]Account = undefined;
    const acct_count = farm_accounts_mod.discoverAccounts(allocator, &acct_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &acct_buf, acct_count);
    if (acct_count == 0) {
        print("{s}⚠️  No Railway accounts found. Set RAILWAY_API_TOKEN in .env{s}\n", .{ YELLOW, RESET });
        return;
    }

    for (acct_buf[0..acct_count]) |acct| {
        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch continue;
        defer api.deinit();

        const resp = api.getServiceInstances(acct.env_id) catch continue;
        defer allocator.free(resp);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, resp, .{}) catch continue;
        defer parsed.deinit();

        const items = getEdgesArray(parsed.value) orelse continue;

        for (items) |edge| {
            const name = getNodeName(edge);
            const node_type = classifyNode(name);
            const status = getNodeStatus(edge);
            const active = isActiveStatus(status);
            const is_crashed = std.mem.eql(u8, status, "CRASHED") or std.mem.eql(u8, status, "FAILED");
            const status_color = if (active) GREEN else if (is_crashed) RED else YELLOW;

            print("  {s} {s:<5}  {s}{s:<8}{s}  {s:<9}  {s}\n", .{
                node_type.emoji(),
                node_type.toString(),
                status_color,
                status,
                RESET,
                acct.name,
                name,
            });
        }
    }
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// FITNESS — aggregate fitness across node types
// ═══════════════════════════════════════════════════════════════════════════════

fn runDepinFitness(allocator: Allocator) !void {
    print("\n{s}🏋️ DePIN FITNESS{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var train_active: usize = 0;
    var train_total: usize = 0;
    var code_active: usize = 0;
    var code_total: usize = 0;
    var infer_active: usize = 0;
    var infer_total: usize = 0;

    var acct_buf: [farm_accounts_mod.MAX_ACCOUNTS]Account = undefined;
    const acct_count = farm_accounts_mod.discoverAccounts(allocator, &acct_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &acct_buf, acct_count);
    if (acct_count == 0) {
        print("{s}⚠️  No Railway accounts found. Set RAILWAY_API_TOKEN in .env{s}\n", .{ YELLOW, RESET });
        return;
    }

    for (acct_buf[0..acct_count]) |acct| {
        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch continue;
        defer api.deinit();

        const resp = api.getServiceInstances(acct.env_id) catch continue;
        defer allocator.free(resp);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, resp, .{}) catch continue;
        defer parsed.deinit();

        const items = getEdgesArray(parsed.value) orelse continue;

        for (items) |edge| {
            const name = getNodeName(edge);
            const node_type = classifyNode(name);
            const status = getNodeStatus(edge);
            const active = isActiveStatus(status);

            switch (node_type) {
                .train => {
                    train_total += 1;
                    if (active) train_active += 1;
                },
                .code => {
                    code_total += 1;
                    if (active) code_active += 1;
                },
                .infer => {
                    infer_total += 1;
                    if (active) infer_active += 1;
                },
            }
        }
    }

    const total = train_total + code_total + infer_total;
    const active = train_active + code_active + infer_active;

    printFitnessBar("TRAIN", train_active, train_total);
    printFitnessBar("CODE", code_active, code_total);
    printFitnessBar("INFER", infer_active, infer_total);
    print("  {s}─────────────────────────────────────────{s}\n", .{ DIM, RESET });
    printFitnessBar("TOTAL", active, total);
    print("\n", .{});
}

fn printFitnessBar(label: []const u8, act: usize, total: usize) void {
    const pct: f64 = if (total > 0)
        @as(f64, @floatFromInt(act)) / @as(f64, @floatFromInt(total)) * 100.0
    else
        0.0;

    const color = if (pct >= 80) GREEN else if (pct >= 50) YELLOW else RED;

    print("  {s:<5}  {s}{d:.0}%{s}  ({d}/{d})\n", .{
        label, color, pct, RESET, act, total,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn classifyNode(name: []const u8) NodeType {
    if (std.mem.startsWith(u8, name, "hslm") or std.mem.indexOf(u8, name, "train") != null) {
        return .train;
    }
    if (std.mem.startsWith(u8, name, "agent") or std.mem.indexOf(u8, name, "code") != null) {
        return .code;
    }
    return .infer;
}

fn printHelp() void {
    print("\n{s}🌐 DePIN NODE PROTOCOL{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}status{s}   Network overview dashboard\n", .{ CYAN, RESET });
    print("  {s}nodes{s}    List all nodes with type/status\n", .{ CYAN, RESET });
    print("  {s}fitness{s}  Aggregate fitness by node type\n", .{ CYAN, RESET });
    print("\n  Usage: {s}tri depin <command>{s}\n\n", .{ BOLD, RESET });
}

test "NodeType toString" {
    try std.testing.expectEqualStrings("TRAIN", NodeType.train.toString());
    try std.testing.expectEqualStrings("CODE", NodeType.code.toString());
    try std.testing.expectEqualStrings("INFER", NodeType.infer.toString());
}
