// @origin(manual) @regen(pending)
// ═════════════════════════════════════════════════════════════════════════
// MAC INSTALLER CLI — Multi-Mac Wave 9 Cluster Installer
// ═════════════════════════════════════════════════════════════════════
//
// tri mac-cluster install <device-id> [--workers N] [--role coordinator|worker]
// tri mac-cluster discover
// tri mac-cluster plan <total-workers>
// tri mac-cluster status
// tri mac-cluster generate-all
//
// Reuses:
// - mac_cluster.zig: MacCluster, MacNode, NodeRole
// - wave9_device.zig: device-specific compose generation
// - local_farm.zig: Docker wrapper functions
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";

// Import modules
const mac_cluster_module = @import("mac_cluster.zig");
const MacCluster = mac_cluster_module.MacCluster;
const MacNode = mac_cluster_module.MacNode;
const NodeRole = mac_cluster_module.NodeRole;
const load = mac_cluster_module.load;
const init = mac_cluster_module.init;
const wave9_device = @import("wave9_device.zig");
const local_farm = @import("local_farm.zig");

// ═════════════════════════════════════════════════════════════════
// INSTALLER STATE — Persistent installer state
// ═════════════════════════════════════════════════════════════════════════

pub const InstallerState = struct {
    /// Device ID (Mac node ID)
    device_id: usize,
    /// Number of workers assigned
    workers_count: usize,
    /// Installation completed
    installed: bool,
    /// Last deployment action
    last_action: []const u8,
    /// Last deployment timestamp
    last_deployed: i64,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .device_id = 0,
            .workers_count = 0,
            .installed = false,
            .last_action = "",
            .last_deployed = 0,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════

pub fn runMacInstallerCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "help";

    if (std.mem.eql(u8, subcmd, "discover")) {
        return runDiscover(allocator);
    } else if (std.mem.eql(u8, subcmd, "install")) {
        return runInstall(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "plan")) {
        return runPlan(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "status")) {
        return runStatus(allocator);
    } else if (std.mem.eql(u8, subcmd, "generate-all")) {
        return runGenerateAll(allocator);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printHelp();
    } else {
        print("{s}Unknown mac-cluster subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════
// DISCOVER — List all Macs in cluster
// ═════════════════════════════════════════════════════════════════════

fn runDiscover(allocator: Allocator) !void {
    print("\n{s}🔍 MAC CLUSTER DISCOVERY{s}\n", .{ BOLD, RESET });
    print("{s}═════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    // Try to load existing cluster state
    var cluster = load(allocator) catch |err| {
        print("  {s}⚠️  Load failed: {s}{s}\n", .{ YELLOW, @errorName(err), RESET });
        print("  Starting fresh discovery...\n", .{});
        var fresh = try init(allocator);
        defer mac_cluster_module.deinit(&fresh, allocator);
        return displayCluster(&fresh);
    };
    defer mac_cluster_module.deinit(&cluster, allocator);

    displayCluster(&cluster);
}

fn displayCluster(cluster: *const MacCluster) void {
    print("{s}Cluster Size:{s} {d} nodes\n", .{ CYAN, cluster.nodes.items.len, RESET });
    print("{s}Total Workers:{s} {d} / {d} capacity\n\n", .{
        CYAN, cluster.total_workers, mac_cluster_module.totalCapacity(cluster), RESET,
    });
    print("{s}Coordinator:{s} {s}\n", .{
        if (cluster.coordinator_id) |cid| cluster.nodes.items[cid].hostname else "None",
        RESET,
    });

    print("\n{s}Nodes:{s}\n", .{ BOLD, RESET });
    for (cluster.nodes.items) |node| {
        const role_emoji = node.role.emoji();
        const status_emoji = if (node.online) "🟢" else "🔴";

        print("  {s}{s} mac-{d:2} {s}{s}\n", .{
            role_emoji, status_emoji, BOLD, node.id, DIM, RESET,
        });

        if (node.workers_count > 0) {
            print("    {s}Workers:{s} {d}-{d} ({d})\n", .{
                DIM, node.workers_start, node.workers_start + node.workers_count - 1, node.workers_count, RESET,
            });
        }
    }
}

// ═════════════════════════════════════════════════════════════════════
// INSTALL — Install on a specific Mac
// ═════════════════════════════════════════════════════════════════════════

fn runInstall(allocator: Allocator, args: []const []const u8) !void {
    var device_id: ?usize = null;
    var workers_count: ?usize = null;
    var role: NodeRole = .worker;

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--role") and i + 1 < args.len) {
            i += 1;
            if (std.mem.eql(u8, args[i], "coordinator")) {
                role = .coordinator;
            } else if (std.mem.eql(u8, args[i], "worker")) {
                role = .worker;
            }
        } else if (std.mem.eql(u8, args[i], "--workers") and i + 1 < args.len) {
            i += 1;
            workers_count = std.fmt.parseInt(usize, args[i], 10) catch null;
        } else if (device_id == null) {
            device_id = std.fmt.parseInt(usize, args[i], 10) catch null;
        }
    }

    const id = device_id orelse {
        print("{s}Usage: tri mac-cluster install <device-id> [--role coordinator|worker] [--workers N]{s}\n", .{ YELLOW, RESET });
        return;
    };

    print("\n{s}📦 MAC CLUSTER INSTALL{s}\n", .{ BOLD, RESET });
    print("{s}═════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    // Load or create cluster
    var cluster = load(allocator) catch |err| {
        print("  {s}⚠️  Load failed: {s}{s}\n", .{ YELLOW, @errorName(err), RESET });
        print("  Creating new cluster...\n", .{});
        var fresh = try init(allocator);
        defer mac_cluster_module.deinit(&fresh, allocator);
        try doInstall(allocator, id, role, workers_count, &fresh);
        return;
    };
    defer mac_cluster_module.deinit(&cluster, allocator);

    try doInstall(allocator, id, role, workers_count, &cluster);
}

fn doInstall(allocator: Allocator, device_id: usize, role: NodeRole, workers_count: ?usize, cluster: *MacCluster) !void {
    const actual_workers = workers_count orelse role.defaultWorkers();

    print("  {s}Device ID:{s} {d}\n", .{ CYAN, RESET, device_id });
    print("  {s}Role:{s} {s} ({d} workers){s}\n", .{ CYAN, RESET, role.toString(), role.defaultWorkers(), actual_workers });
    print("  {s}Workers:{s} {d}\n", .{ CYAN, RESET, actual_workers });

    // Check if device already exists
    if (device_id < cluster.nodes.items.len) {
        const existing = &cluster.nodes.items[device_id];
        print("\n  {s}⚠️  Device mac-{d} already exists as '{s}'{s}\n", .{
            YELLOW, device_id, existing.hostname, RESET,
        });
        print("  Existing config: workers={d}, role={s}\n", .{
            existing.workers_count, existing.role.toString(),
        });
        print("  To reconfigure: edit .trinity/mac_cluster.json manually\n", .{});
        return;
    }

    // Add node to cluster
    const hostname = try std.fmt.allocPrint(allocator, "Mac-{d:2}", .{device_id});
    defer allocator.free(hostname);

    const ip = try std.fmt.allocPrint(allocator, "192.168.1.{d}", .{100 + device_id});
    defer allocator.free(ip);

    try mac_cluster_module.addNode(cluster, allocator, ip, hostname, role);

    // Set coordinator if needed
    if (role == .coordinator and cluster.coordinator_id == null) {
        cluster.coordinator_id = device_id;
        print("  {s}✅{s} Set as coordinator\n", .{ GREEN, RESET });
    }

    // Update worker count
    cluster.nodes.items[device_id].workers_count = actual_workers;

    // Save cluster state
    try mac_cluster_module.save(cluster, allocator);

    print("\n  {s}✅{s} Node configured\n", .{ GREEN, RESET });
    print("\nNext steps:\n", .{});
    print("  1. {s}Run 'tri mac-cluster plan 48' to assign workers\n", .{ CYAN });
    print("  2. {s}Run 'tri mac-cluster generate-all' to create compose files\n", .{ CYAN });
    print("  3. {s}On this Mac: docker-compose -f deploy/docker/docker-compose.wave9-mac-{d}.yml up -d\n", .{ CYAN, device_id });
}

// ═════════════════════════════════════════════════════════════════════
// PLAN — Assign workers to nodes
// ═══════════════════════════════════════════════════════════════════════════

fn runPlan(allocator: Allocator, args: []const []const u8) !void {
    const total_workers = if (args.len > 0)
        std.fmt.parseInt(usize, args[0], 10) catch 48
    else
        48;

    print("\n{s}📋 MAC CLUSTER PLAN — {d} workers{s}\n", .{ BOLD, total_workers, RESET });
    print("{s}═════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var cluster = load(allocator) catch |err| {
        print("  {s}⚠️  Load failed: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return;
    };
    defer mac_cluster_module.deinit(&cluster, allocator);

    if (cluster.nodes.items.len == 0) {
        print("{s}⚠️  No nodes in cluster. Run 'tri mac-cluster discover' first.\n", .{ YELLOW });
        return;
    }

    print("Current cluster:\n", .{});
    mac_cluster_module.displayStatus(&cluster);

    print("\nPlanning worker assignment...\n", .{});

    try mac_cluster_module.assignWorkers(&cluster, total_workers);

    print("\n  {s}✅{s} Workers assigned\n", .{ GREEN, RESET });
    print("  {s}Total:{s} {d} | Capacity: {d}\n", .{
        CYAN, RESET, cluster.total_workers, mac_cluster_module.totalCapacity(&cluster),
    });

    // Save cluster state
    try mac_cluster_module.save(&cluster, allocator);
}

// ═══════════════════════════════════════════════════════════════════════
// STATUS — Show cluster status
// ═════════════════════════════════════════════════════════════════════════

fn runStatus(allocator: Allocator) !void {
    print("\n{s}📊 MAC CLUSTER STATUS{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var cluster = load(allocator) catch |err| {
        print("  {s}⚠️  Load failed: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return;
    };
    defer mac_cluster_module.deinit(&cluster, allocator);

    mac_cluster_module.displayStatus(&cluster);
}

// ═════════════════════════════════════════════════════════════════════
// GENERATE-ALL — Create all compose files
// ═════════════════════════════════════════════════════════════════════════

fn runGenerateAll(allocator: Allocator) !void {
    print("\n{s}🔨 GENERATING COMPOSE FILES{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var cluster = load(allocator) catch |err| {
        print("  {s}⚠️  Load failed: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return;
    };
    defer mac_cluster_module.deinit(&cluster, allocator);

    if (cluster.nodes.items.len == 0) {
        print("{s}⚠️  No nodes in cluster.{s}\n", .{ YELLOW, RESET });
        return;
    }

    try mac_cluster_module.generateComposeFiles(&cluster, allocator);

    print("\n  {s}✅{s} Generated compose files for {d} nodes\n", .{ GREEN, RESET });
    print("\nDeployment commands:\n", .{});
    for (cluster.nodes.items) |node| {
        if (node.workers_count == 0) continue;
        print("  Mac-{d:2}: docker-compose -f deploy/docker/docker-compose.wave9-mac-{d}.yml up -d\n", .{
            node.id, node.id,
        });
    }
}

// ═══════════════════════════════════════════════════════════════════════
// HELP
// ═════════════════════════════════════════════════════════════════════════

fn printHelp() void {
    print(
        \\{}
        \\Usage: tri mac-cluster <command> [options]
        \\
        \\Commands:
        \\  discover           List all Macs in cluster
        \\  install <id>      Install on Mac <id> [--role coordinator|worker] [--workers N]
        \\  plan <N>          Assign N workers across cluster (default: 48)
        \\  status            Show cluster status
        \\  generate-all       Generate all docker-compose files
        \\  help, --help     Show this help
        \\
        \\Install options:
        \\  --role coordinator   Set node as coordinator (max 4 workers)
        \\  --role worker       Set node as worker (6-12 workers, default)
        \\  --workers N        Number of workers (default per role)
        \\
        \\Workflow:
        \\  1. tri mac-cluster install 0 --role coordinator --workers 4
        \\  2. tri mac-cluster install 1 --role worker --workers 12
        \\  3. tri mac-cluster plan 48
        \\  4. tri mac-cluster generate-all
        \\  5. On each Mac: docker-compose -f deploy/docker/docker-compose.wave9-mac-0.yml up -d
        \\
        \\Configuration:
        \\  S3 MultiObj: NTP 50%, JEPA 25%, NCA 25%, ctx=81
        \\  LR: 1e-3, Schedule: cosine, Optimizer: lamb
        \\  Seed: 1000 + worker_id for each worker
        \\
    , .{});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printHelp();
        return;
    }

    // Skip the first argument (program name)
    const cmd_args = args[1..];

    // Check for subcommands
    if (std.mem.eql(u8, cmd_args[0], "discover")) {
        return runDiscover(allocator);
    } else if (std.mem.eql(u8, cmd_args[0], "install")) {
        return runInstall(allocator, cmd_args[1..]);
    } else if (std.mem.eql(u8, cmd_args[0], "plan")) {
        return runPlan(allocator, cmd_args[1..]);
    } else if (std.mem.eql(u8, cmd_args[0], "status")) {
        return runStatus(allocator);
    } else if (std.mem.eql(u8, cmd_args[0], "generate-all")) {
        return runGenerateAll(allocator);
    } else if (std.mem.eql(u8, cmd_args[0], "help") or std.mem.eql(u8, cmd_args[0], "--help")) {
        printHelp();
    } else {
        print("{s}Unknown mac-cluster subcommand: {s}{s}\n", .{ RED, cmd_args[0], RESET });
        printHelp();
    }
}
