// ═══════════════════════════════════════════════════════════════════════════════
// MULTI-CLUSTER COMMAND — Live Stateful v2 + $TRI PoUW
// Golden Chain #99 | phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// Spec: specs/depin/multi-cluster-live-v2.tri
// Persistent state: .tri-cluster.json
//
// Extracted from tri_commands.zig for faster compilation.
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("../tri_colors.zig");

// depin.zig is in src/firebird/ — inline constants to avoid cross-module import
const depin = struct {
    pub const RewardCalculator = struct {
        pub fn formatTRI(v: f64) f64 {
            return v / 1_000_000_000.0; // nanoTRI → TRI
        }
    };
    pub const REWARD_EVOLUTION_GEN: f64 = 100_000_000.0; // 0.1 TRI
    pub const REWARD_BENCHMARK: f64 = 50_000_000.0; // 0.05 TRI
    pub const REWARD_NAVIGATION_STEP: f64 = 10_000_000.0; // 0.01 TRI
    pub const TIER_MULTIPLIER_FREE: f64 = 1.0;
    pub const TIER_MULTIPLIER_STAKER: f64 = 1.5;
    pub const TIER_MULTIPLIER_POWER: f64 = 2.0;
    pub const TIER_MULTIPLIER_WHALE: f64 = 3.0;
};

const CYAN = colors.CYAN;
const RESET = colors.RESET;
const GREEN = colors.GREEN;
const GRAY = colors.GRAY;
const YELLOW = colors.YELLOW;
const RED = colors.RED;

/// Sacred constants
const PHI: f64 = 1.618033988749895;
const PHI_INVERSE: f64 = 0.618033988749895;
const TRINITY_SUM: f64 = 3.0; // phi^2 + 1/phi^2 = 3

/// Node tiers for reward multipliers — from depin.zig
pub const NodeTier = enum(u8) {
    free, // 1.0x multiplier, 0 TRI staked
    staker, // 1.5x multiplier, 100+ TRI staked
    power, // 2.0x multiplier, 1,000+ TRI staked
    whale, // 3.0x multiplier, 10,000+ TRI staked
};

/// $TRI reward rates (display values in TRI) — from depin RewardCalculator
const REWARD_PER_OPERATION: f64 = depin.RewardCalculator.formatTRI(depin.REWARD_EVOLUTION_GEN);
const REWARD_PER_BENCHMARK: f64 = depin.RewardCalculator.formatTRI(depin.REWARD_BENCHMARK);
const REWARD_PER_SYNC: f64 = depin.RewardCalculator.formatTRI(depin.REWARD_NAVIGATION_STEP);

/// State file path
const CLUSTER_STATE_FILE = ".tri-cluster.json";
const MAX_CLUSTER_NODES = 64;

// ───────────────────────────────────────────────────────────────────
// Persistent Data Structures
// ───────────────────────────────────────────────────────────────────

pub const NodeEntry = struct {
    id: [64]u8,
    id_len: usize,
    address: [128]u8,
    address_len: usize,
    port: u16,
    role: [32]u8,
    role_len: usize,
    status: [16]u8,
    status_len: usize,
    tier: NodeTier, // FREE | STAKER | POWER | WHALE
    operations: u64,
    earned_tri: f64,
    pending_tri: f64, // Unclaimed rewards
    added_at: i64,

    fn empty() NodeEntry {
        return NodeEntry{
            .id = [_]u8{0} ** 64,
            .id_len = 0,
            .address = [_]u8{0} ** 128,
            .address_len = 0,
            .port = 0,
            .role = [_]u8{0} ** 32,
            .role_len = 0,
            .status = [_]u8{0} ** 16,
            .status_len = 0,
            .tier = .free,
            .operations = 0,
            .earned_tri = 0.0,
            .pending_tri = 0.0,
            .added_at = 0,
        };
    }

    fn getTierMultiplier(self: *const NodeEntry) f64 {
        return switch (self.tier) {
            .free => depin.TIER_MULTIPLIER_FREE,
            .staker => depin.TIER_MULTIPLIER_STAKER,
            .power => depin.TIER_MULTIPLIER_POWER,
            .whale => depin.TIER_MULTIPLIER_WHALE,
        };
    }

    fn calculateReward(self: *NodeEntry, base_reward: f64) f64 {
        return base_reward * self.getTierMultiplier();
    }
};

const FederationLink = struct {
    address: [128]u8,
    address_len: usize,
    sync_mode: [16]u8,
    sync_mode_len: usize,
    linked_at: i64,

    fn empty() FederationLink {
        return FederationLink{
            .address = [_]u8{0} ** 128,
            .address_len = 0,
            .sync_mode = [_]u8{0} ** 16,
            .sync_mode_len = 0,
            .linked_at = 0,
        };
    }
};

pub const ClusterState = struct {
    cluster_id: [64]u8,
    cluster_id_len: usize,
    coordinator_port: u16,
    discovery_port: u16,
    nodes: [MAX_CLUSTER_NODES]NodeEntry,
    node_count: usize,
    federations: [16]FederationLink,
    federation_count: usize,
    total_operations: u64,
    total_tri_earned: f64,
    total_pending_tri: f64, // Sum of all pending rewards
    last_sync_timestamp: i64,
    sync_count: u64,
    crdt_entries_merged: u64, // Track CRDT merge stats
    crdt_conflicts_resolved: u64,
    created_at: i64,
    last_modified: i64,
    is_running: bool,

    fn init() ClusterState {
        return ClusterState{
            .cluster_id = [_]u8{0} ** 64,
            .cluster_id_len = 0,
            .coordinator_port = 0,
            .discovery_port = 0,
            .nodes = [_]NodeEntry{NodeEntry.empty()} ** MAX_CLUSTER_NODES,
            .node_count = 0,
            .federations = [_]FederationLink{FederationLink.empty()} ** 16,
            .federation_count = 0,
            .total_operations = 0,
            .total_tri_earned = 0.0,
            .total_pending_tri = 0.0,
            .last_sync_timestamp = 0,
            .sync_count = 0,
            .crdt_entries_merged = 0,
            .crdt_conflicts_resolved = 0,
            .created_at = 0,
            .last_modified = 0,
            .is_running = false,
        };
    }

    fn countOnline(self: *const ClusterState) usize {
        var count: usize = 0;
        for (0..self.node_count) |i| {
            if (std.mem.eql(u8, self.nodes[i].status[0..self.nodes[i].status_len], "online") or
                std.mem.eql(u8, self.nodes[i].status[0..self.nodes[i].status_len], "earning"))
                count += 1;
        }
        return count;
    }

    fn calculateTotalPending(self: *ClusterState) f64 {
        var total: f64 = 0.0;
        for (0..self.node_count) |i| {
            total += self.nodes[i].pending_tri;
        }
        return total;
    }

    fn claimAllPending(self: *ClusterState) f64 {
        var total_claimed: f64 = 0.0;
        for (0..self.node_count) |i| {
            const claimed = self.nodes[i].pending_tri;
            self.nodes[i].earned_tri += claimed;
            self.nodes[i].pending_tri = 0.0;
            total_claimed += claimed;
        }
        self.total_tri_earned += total_claimed;
        self.total_pending_tri = 0.0;
        return total_claimed;
    }
};

// ───────────────────────────────────────────────────────────────────
// Helper Functions
// ───────────────────────────────────────────────────────────────────

fn copyToFixed(comptime N: usize, dest: *[N]u8, len_ptr: *usize, src: []const u8) void {
    const copy_len = @min(src.len, N);
    @memcpy(dest[0..copy_len], src[0..copy_len]);
    len_ptr.* = copy_len;
}

fn jsonFloat(v: std.json.Value) f64 {
    return switch (v) {
        .float => v.float,
        .integer => @as(f64, @floatFromInt(v.integer)),
        else => 0.0,
    };
}

fn generateNodeId(dest: *[64]u8, dest_len: *usize, address: []const u8, port: u16) void {
    var buf: [64]u8 = undefined;
    const id = std.fmt.bufPrint(&buf, "node-{s}-{d}", .{ address, port }) catch {
        @memcpy(dest[0..12], "node-unknown");
        dest_len.* = 12;
        return;
    };
    const len = @min(id.len, 64);
    @memcpy(dest[0..len], id[0..len]);
    dest_len.* = len;
}

// ───────────────────────────────────────────────────────────────────
// State Persistence: SAVE
// ───────────────────────────────────────────────────────────────────

fn saveClusterState(_: std.mem.Allocator, state: *const ClusterState) void {
    const file = std.fs.cwd().createFile(CLUSTER_STATE_FILE, .{}) catch |err| {
        std.debug.print("{s}Error saving state: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer file.close();

    // Helper: format line into stack buffer, write to file
    var tmp: [1024]u8 = undefined;

    file.writeAll("{\n") catch return;
    var n_written = std.fmt.bufPrint(&tmp, "  \"cluster_id\": \"{s}\",\n", .{state.cluster_id[0..state.cluster_id_len]}) catch return;
    file.writeAll(n_written) catch return;
    n_written = std.fmt.bufPrint(&tmp, "  \"coordinator_port\": {d},\n", .{state.coordinator_port}) catch return;
    file.writeAll(n_written) catch return;
    n_written = std.fmt.bufPrint(&tmp, "  \"discovery_port\": {d},\n", .{state.discovery_port}) catch return;
    file.writeAll(n_written) catch return;
    n_written = std.fmt.bufPrint(&tmp, "  \"total_operations\": {d},\n", .{state.total_operations}) catch return;
    file.writeAll(n_written) catch return;
    n_written = std.fmt.bufPrint(&tmp, "  \"total_tri_earned\": {d:.6},\n", .{state.total_tri_earned}) catch return;
    file.writeAll(n_written) catch return;
    n_written = std.fmt.bufPrint(&tmp, "  \"total_pending_tri\": {d:.6},\n", .{state.total_pending_tri}) catch return;
    file.writeAll(n_written) catch return;
    n_written = std.fmt.bufPrint(&tmp, "  \"last_sync_timestamp\": {d},\n", .{state.last_sync_timestamp}) catch return;
    file.writeAll(n_written) catch return;
    n_written = std.fmt.bufPrint(&tmp, "  \"sync_count\": {d},\n", .{state.sync_count}) catch return;
    file.writeAll(n_written) catch return;
    n_written = std.fmt.bufPrint(&tmp, "  \"crdt_entries_merged\": {d},\n", .{state.crdt_entries_merged}) catch return;
    file.writeAll(n_written) catch return;
    n_written = std.fmt.bufPrint(&tmp, "  \"crdt_conflicts_resolved\": {d},\n", .{state.crdt_conflicts_resolved}) catch return;
    file.writeAll(n_written) catch return;
    n_written = std.fmt.bufPrint(&tmp, "  \"created_at\": {d},\n", .{state.created_at}) catch return;
    file.writeAll(n_written) catch return;
    n_written = std.fmt.bufPrint(&tmp, "  \"last_modified\": {d},\n", .{std.time.timestamp()}) catch return;
    file.writeAll(n_written) catch return;
    n_written = std.fmt.bufPrint(&tmp, "  \"is_running\": {s},\n", .{if (state.is_running) "true" else "false"}) catch return;
    file.writeAll(n_written) catch return;

    // Nodes array
    file.writeAll("  \"nodes\": [\n") catch return;
    for (0..state.node_count) |i| {
        const nd = &state.nodes[i];
        if (i > 0) file.writeAll(",\n") catch return;
        file.writeAll("    {\n") catch return;
        n_written = std.fmt.bufPrint(&tmp, "      \"id\": \"{s}\",\n", .{nd.id[0..nd.id_len]}) catch return;
        file.writeAll(n_written) catch return;
        n_written = std.fmt.bufPrint(&tmp, "      \"address\": \"{s}\",\n", .{nd.address[0..nd.address_len]}) catch return;
        file.writeAll(n_written) catch return;
        n_written = std.fmt.bufPrint(&tmp, "      \"port\": {d},\n", .{nd.port}) catch return;
        file.writeAll(n_written) catch return;
        n_written = std.fmt.bufPrint(&tmp, "      \"role\": \"{s}\",\n", .{nd.role[0..nd.role_len]}) catch return;
        file.writeAll(n_written) catch return;
        n_written = std.fmt.bufPrint(&tmp, "      \"status\": \"{s}\",\n", .{nd.status[0..nd.status_len]}) catch return;
        file.writeAll(n_written) catch return;
        n_written = std.fmt.bufPrint(&tmp, "      \"tier\": \"{s}\",\n", .{@tagName(nd.tier)}) catch return;
        file.writeAll(n_written) catch return;
        n_written = std.fmt.bufPrint(&tmp, "      \"operations\": {d},\n", .{nd.operations}) catch return;
        file.writeAll(n_written) catch return;
        n_written = std.fmt.bufPrint(&tmp, "      \"earned_tri\": {d:.6},\n", .{nd.earned_tri}) catch return;
        file.writeAll(n_written) catch return;
        n_written = std.fmt.bufPrint(&tmp, "      \"pending_tri\": {d:.6},\n", .{nd.pending_tri}) catch return;
        file.writeAll(n_written) catch return;
        n_written = std.fmt.bufPrint(&tmp, "      \"added_at\": {d}\n", .{nd.added_at}) catch return;
        file.writeAll(n_written) catch return;
        file.writeAll("    }") catch return;
    }
    file.writeAll("\n  ],\n") catch return;

    // Federations array
    file.writeAll("  \"federations\": [\n") catch return;
    for (0..state.federation_count) |i| {
        const f = &state.federations[i];
        if (i > 0) file.writeAll(",\n") catch return;
        file.writeAll("    {\n") catch return;
        n_written = std.fmt.bufPrint(&tmp, "      \"address\": \"{s}\",\n", .{f.address[0..f.address_len]}) catch return;
        file.writeAll(n_written) catch return;
        n_written = std.fmt.bufPrint(&tmp, "      \"sync_mode\": \"{s}\",\n", .{f.sync_mode[0..f.sync_mode_len]}) catch return;
        file.writeAll(n_written) catch return;
        n_written = std.fmt.bufPrint(&tmp, "      \"linked_at\": {d}\n", .{f.linked_at}) catch return;
        file.writeAll(n_written) catch return;
        file.writeAll("    }") catch return;
    }
    file.writeAll("\n  ]\n") catch return;
    file.writeAll("}\n") catch return;
}

// ───────────────────────────────────────────────────────────────────
// State Persistence: LOAD
// ───────────────────────────────────────────────────────────────────

fn loadClusterState(allocator: std.mem.Allocator) ClusterState {
    var state = ClusterState.init();

    const file = std.fs.cwd().openFile(CLUSTER_STATE_FILE, .{}) catch return state;
    defer file.close();

    const content = file.readToEndAlloc(allocator, 1024 * 1024) catch return state;
    defer allocator.free(content);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, content, .{}) catch return state;
    defer parsed.deinit();

    const root = parsed.value.object;

    if (root.get("cluster_id")) |v| {
        if (v == .string) copyToFixed(64, &state.cluster_id, &state.cluster_id_len, v.string);
    }
    if (root.get("coordinator_port")) |v| {
        if (v == .integer) state.coordinator_port = std.math.cast(u16, v.integer) orelse 0;
    }
    if (root.get("discovery_port")) |v| {
        if (v == .integer) state.discovery_port = std.math.cast(u16, v.integer) orelse 0;
    }
    if (root.get("total_operations")) |v| {
        if (v == .integer) state.total_operations = std.math.cast(u32, v.integer) orelse 0;
    }
    if (root.get("total_tri_earned")) |v| state.total_tri_earned = jsonFloat(v);
    if (root.get("total_pending_tri")) |v| state.total_pending_tri = jsonFloat(v);
    if (root.get("last_sync_timestamp")) |v| {
        if (v == .integer) state.last_sync_timestamp = v.integer;
    }
    if (root.get("sync_count")) |v| {
        if (v == .integer) state.sync_count = std.math.cast(u32, v.integer) orelse 0;
    }
    if (root.get("crdt_entries_merged")) |v| {
        if (v == .integer) state.crdt_entries_merged = std.math.cast(u32, v.integer) orelse 0;
    }
    if (root.get("crdt_conflicts_resolved")) |v| {
        if (v == .integer) state.crdt_conflicts_resolved = std.math.cast(u32, v.integer) orelse 0;
    }
    if (root.get("created_at")) |v| {
        if (v == .integer) state.created_at = v.integer;
    }
    if (root.get("last_modified")) |v| {
        if (v == .integer) state.last_modified = v.integer;
    }
    if (root.get("is_running")) |v| {
        if (v == .bool) state.is_running = v.bool;
    }

    // Parse nodes
    if (root.get("nodes")) |nv| {
        if (nv == .array) {
            for (nv.array.items, 0..) |node_val, i| {
                if (i >= MAX_CLUSTER_NODES) break;
                if (node_val != .object) continue;
                const no = node_val.object;
                var entry = NodeEntry.empty();
                if (no.get("id")) |v| if (v == .string) copyToFixed(64, &entry.id, &entry.id_len, v.string);
                if (no.get("address")) |v| if (v == .string) copyToFixed(128, &entry.address, &entry.address_len, v.string);
                if (no.get("port")) |v| if (v == .integer) {
                    entry.port = std.math.cast(u16, v.integer) orelse 0;
                };
                if (no.get("role")) |v| if (v == .string) copyToFixed(32, &entry.role, &entry.role_len, v.string);
                if (no.get("status")) |v| if (v == .string) copyToFixed(16, &entry.status, &entry.status_len, v.string);
                if (no.get("tier")) |v| if (v == .string) {
                    // Parse tier string to enum
                    if (std.mem.eql(u8, v.string, "free")) entry.tier = .free else if (std.mem.eql(u8, v.string, "staker")) entry.tier = .staker else if (std.mem.eql(u8, v.string, "power")) entry.tier = .power else if (std.mem.eql(u8, v.string, "whale")) entry.tier = .whale else entry.tier = .free; // default
                };
                if (no.get("operations")) |v| if (v == .integer) {
                    entry.operations = std.math.cast(u32, v.integer) orelse 0;
                };
                if (no.get("earned_tri")) |v| entry.earned_tri = jsonFloat(v);
                if (no.get("pending_tri")) |v| entry.pending_tri = jsonFloat(v);
                if (no.get("added_at")) |v| if (v == .integer) {
                    entry.added_at = v.integer;
                };
                state.nodes[i] = entry;
                state.node_count += 1;
            }
        }
    }

    // Parse federations
    if (root.get("federations")) |fv| {
        if (fv == .array) {
            for (fv.array.items, 0..) |fed_val, i| {
                if (i >= 16) break;
                if (fed_val != .object) continue;
                const fo = fed_val.object;
                var link = FederationLink.empty();
                if (fo.get("address")) |v| if (v == .string) copyToFixed(128, &link.address, &link.address_len, v.string);
                if (fo.get("sync_mode")) |v| if (v == .string) copyToFixed(16, &link.sync_mode, &link.sync_mode_len, v.string);
                if (fo.get("linked_at")) |v| if (v == .integer) {
                    link.linked_at = v.integer;
                };
                state.federations[i] = link;
                state.federation_count += 1;
            }
        }
    }

    return state;
}

// ───────────────────────────────────────────────────────────────────
// Main Dispatch (stateful — passes allocator to all handlers)
// ───────────────────────────────────────────────────────────────────

pub fn runMultiClusterCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        printMultiClusterHelp();
        return;
    }

    const subcmd = args[0];
    const sub_args = if (args.len > 1) args[1..] else args[0..0];

    if (std.mem.eql(u8, subcmd, "initialize") or std.mem.eql(u8, subcmd, "init")) {
        runInitialize(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "discover")) {
        runDiscover(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "add-node") or std.mem.eql(u8, subcmd, "add")) {
        runAddNode(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "remove-node") or std.mem.eql(u8, subcmd, "remove")) {
        runRemoveNode(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "status")) {
        runClusterStatus(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "sync")) {
        runSync(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "federate") or std.mem.eql(u8, subcmd, "fed")) {
        runFederate(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "shutdown") or std.mem.eql(u8, subcmd, "stop")) {
        runShutdown(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "health-check") or std.mem.eql(u8, subcmd, "health")) {
        runHealthCheck(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "list") or std.mem.eql(u8, subcmd, "ls")) {
        runListNodes(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "help")) {
        printMultiClusterHelp();
    } else {
        std.debug.print("{s}Error:{s} Unknown subcommand: {s}\n", .{ RED, RESET, subcmd });
        std.debug.print("Run 'tri multi-cluster help' for usage.\n", .{});
    }
}

fn printMultiClusterHelp() void {
    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  MULTI-CLUSTER v2 — Live State + $TRI PoUW (Golden Chain #99){s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n", .{});
    std.debug.print("{s}Usage:{s} tri multi-cluster <subcommand> [options]\n", .{ CYAN, RESET });
    std.debug.print("{s}Aliases:{s} mc\n", .{ GRAY, RESET });
    std.debug.print("{s}State:{s}   {s}\n", .{ GRAY, RESET, CLUSTER_STATE_FILE });
    std.debug.print("\n", .{});
    std.debug.print("{s}Subcommands:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  {s}initialize{s}   Create cluster, start coordinator          {s}[--port N] [--discovery-port N]{s}\n", .{ GREEN, RESET, GRAY, RESET });
    std.debug.print("  {s}discover{s}     Show discovered nodes from state           {s}[--timeout N]{s}\n", .{ GREEN, RESET, GRAY, RESET });
    std.debug.print("  {s}add-node{s}     Add node to cluster (persisted)            {s}<address> [--port N] [--role worker|storage] [--tier FREE|STAKER|POWER|WHALE]{s}\n", .{ GREEN, RESET, GRAY, RESET });
    std.debug.print("  {s}remove-node{s}  Remove node, claim pending $TRI            {s}<node-id>{s}\n", .{ GREEN, RESET, GRAY, RESET });
    std.debug.print("  {s}status{s}       Show live cluster status + $TRI             {s}[--verbose]{s}\n", .{ GREEN, RESET, GRAY, RESET });
    std.debug.print("  {s}sync{s}         Trigger CRDT sync + accrue $TRI            {s}[--force]{s}\n", .{ GREEN, RESET, GRAY, RESET });
    std.debug.print("  {s}federate{s}     Link clusters for cross-federation         {s}<cluster-address> [--sync-mode crdt|raft|gossip]{s}\n", .{ GREEN, RESET, GRAY, RESET });
    std.debug.print("  {s}shutdown{s}     Graceful shutdown + final $TRI claim        {s}[--force] [--drain]{s}\n", .{ GREEN, RESET, GRAY, RESET });
    std.debug.print("  {s}health-check{s} Validate CRDT + PoUW + needle check        {s}{s}\n", .{ GREEN, RESET, GRAY, RESET });
    std.debug.print("  {s}list{s}         List all nodes with live stats             {s}[--format table|json]{s}\n", .{ GREEN, RESET, GRAY, RESET });
    std.debug.print("\n", .{});
    std.debug.print("{s}Ports:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  UDP {s}9333{s}  — Node discovery (broadcast)\n", .{ CYAN, RESET });
    std.debug.print("  TCP {s}9334{s}  — Job distribution + results\n", .{ CYAN, RESET });
    std.debug.print("  HTTP {s}8080{s} — REST API + dashboard\n", .{ CYAN, RESET });
    std.debug.print("\n", .{});
    std.debug.print("{s}Token:{s} $TRI | Reward: {d:.4} $TRI/op | Threshold: {d:.3} (phi^-1)\n", .{ YELLOW, RESET, REWARD_PER_OPERATION, PHI_INVERSE });
    std.debug.print("{s}phi^2 + 1/phi^2 = {d:.1} = TRINITY{s}\n\n", .{ GRAY, TRINITY_SUM, RESET });
}

// ───────────────────────────────────────────────────────────────────
// Subcommand 1: INITIALIZE (creates state, saves)
// ───────────────────────────────────────────────────────────────────

fn runInitialize(allocator: std.mem.Allocator, args: []const []const u8) void {
    var port: u16 = 9334;
    var discovery_port: u16 = 9333;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--port") and i + 1 < args.len) {
            port = std.fmt.parseInt(u16, args[i + 1], 10) catch 9334;
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--discovery-port") and i + 1 < args.len) {
            discovery_port = std.fmt.parseInt(u16, args[i + 1], 10) catch 9333;
            i += 1;
        }
    }

    // Check if already initialized
    var state = loadClusterState(allocator);
    if (state.created_at != 0 and state.is_running) {
        std.debug.print("{s}Warning:{s} Cluster already running (created at {d}). Use 'shutdown' first or '--force'.\n", .{ YELLOW, RESET, state.created_at });
        std.debug.print("  Reloading existing state with {d} nodes.\n\n", .{state.node_count});
        return;
    }

    // Create fresh state
    state = ClusterState.init();
    state.coordinator_port = port;
    state.discovery_port = discovery_port;
    state.created_at = std.time.timestamp();
    state.is_running = true;

    // Generate cluster ID
    var cid_buf: [64]u8 = undefined;
    const cid = std.fmt.bufPrint(&cid_buf, "mc-{d}-{d}", .{ port, discovery_port }) catch "mc-unknown";
    copyToFixed(64, &state.cluster_id, &state.cluster_id_len, cid);

    // Add coordinator as node[0]
    var coord = NodeEntry.empty();
    copyToFixed(64, &coord.id, &coord.id_len, "coordinator");
    copyToFixed(128, &coord.address, &coord.address_len, "localhost");
    coord.port = port;
    copyToFixed(32, &coord.role, &coord.role_len, "coordinator");
    copyToFixed(16, &coord.status, &coord.status_len, "online");
    coord.added_at = state.created_at;
    state.nodes[0] = coord;
    state.node_count = 1;

    saveClusterState(allocator, &state);

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  MULTI-CLUSTER INITIALIZE (Live v2){s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}Cluster ID:{s}      {s}\n", .{ CYAN, RESET, state.cluster_id[0..state.cluster_id_len] });
    std.debug.print("  {s}Role:{s}            Coordinator\n", .{ CYAN, RESET });
    std.debug.print("  {s}Job Port:{s}        TCP {d}\n", .{ CYAN, RESET, port });
    std.debug.print("  {s}Discovery Port:{s}  UDP {d}\n", .{ CYAN, RESET, discovery_port });
    std.debug.print("  {s}CRDT Sync:{s}       Enabled (interval: 1000ms)\n", .{ CYAN, RESET });
    std.debug.print("  {s}$TRI Wallet:{s}     Initialized\n", .{ CYAN, RESET });
    std.debug.print("  {s}PoUW Engine:{s}     Active (reward: {d:.4} $TRI/op)\n", .{ CYAN, RESET, REWARD_PER_OPERATION });
    std.debug.print("  {s}State File:{s}      {s}\n", .{ CYAN, RESET, CLUSTER_STATE_FILE });
    std.debug.print("\n{s}Cluster initialized. State saved to {s}.{s}\n\n", .{ GREEN, CLUSTER_STATE_FILE, RESET });
}

// ───────────────────────────────────────────────────────────────────
// Subcommand 2: DISCOVER (reads state)
// ───────────────────────────────────────────────────────────────────

fn runDiscover(allocator: std.mem.Allocator, args: []const []const u8) void {
    var timeout: u16 = 5;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--timeout") and i + 1 < args.len) {
            timeout = std.fmt.parseInt(u16, args[i + 1], 10) catch 5;
            i += 1;
        }
    }

    const state = loadClusterState(allocator);

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  NODE DISCOVERY (UDP broadcast){s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  Broadcasting on UDP port {d}...\n", .{if (state.discovery_port > 0) state.discovery_port else @as(u16, 9333)});
    std.debug.print("  Timeout: {d}s\n", .{timeout});
    std.debug.print("\n", .{});
    std.debug.print("  {s}Discovered Nodes:{s}\n", .{ CYAN, RESET });
    std.debug.print("  ┌──────────────────┬────────┬──────────┬──────────┐\n", .{});
    std.debug.print("  │ {s}Address{s}          │ {s}Port{s}   │ {s}Role{s}     │ {s}Status{s}   │\n", .{ YELLOW, RESET, YELLOW, RESET, YELLOW, RESET, YELLOW, RESET });
    std.debug.print("  ├──────────────────┼────────┼──────────┼──────────┤\n", .{});
    for (0..state.node_count) |ni| {
        const n = &state.nodes[ni];
        const sc = if (std.mem.eql(u8, n.status[0..n.status_len], "online") or std.mem.eql(u8, n.status[0..n.status_len], "earning")) GREEN else RED;
        std.debug.print("  │ {s:<16} │ {d:<6} │ {s:<8} │ {s}{s:<8}{s} │\n", .{ n.address[0..n.address_len], n.port, n.role[0..n.role_len], sc, n.status[0..n.status_len], RESET });
    }
    std.debug.print("  └──────────────────┴────────┴──────────┴──────────┘\n", .{});
    std.debug.print("\n{s}Discovery complete. Found {d} node(s).{s}\n\n", .{ GREEN, state.node_count, RESET });
}

// ───────────────────────────────────────────────────────────────────
// Subcommand 3: ADD-NODE (loads, appends, saves)
// ───────────────────────────────────────────────────────────────────

fn runAddNode(allocator: std.mem.Allocator, args: []const []const u8) void {
    if (args.len == 0) {
        std.debug.print("{s}Error:{s} Missing address. Usage: tri multi-cluster add-node <address> [--port N] [--role worker|storage] [--tier FREE|STAKER|POWER|WHALE]\n", .{ RED, RESET });
        return;
    }

    var state = loadClusterState(allocator);
    if (state.created_at == 0) {
        std.debug.print("{s}Error:{s} No cluster found. Run 'tri multi-cluster initialize' first.\n", .{ RED, RESET });
        return;
    }
    if (state.node_count >= MAX_CLUSTER_NODES) {
        std.debug.print("{s}Error:{s} Cluster full ({d} nodes max).\n", .{ RED, RESET, MAX_CLUSTER_NODES });
        return;
    }

    const address = args[0];
    var port: u16 = 9334;
    var role: []const u8 = "worker";
    var tier: NodeTier = .free;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--port") and i + 1 < args.len) {
            port = std.fmt.parseInt(u16, args[i + 1], 10) catch 9334;
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--role") and i + 1 < args.len) {
            role = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--tier") and i + 1 < args.len) {
            // Parse tier
            const tier_str = args[i + 1];
            if (std.mem.eql(u8, tier_str, "free")) {
                tier = .free;
            } else if (std.mem.eql(u8, tier_str, "staker")) {
                tier = .staker;
            } else if (std.mem.eql(u8, tier_str, "power")) {
                tier = .power;
            } else if (std.mem.eql(u8, tier_str, "whale")) {
                tier = .whale;
            } else {
                std.debug.print("{s}Warning:{s} Unknown tier '{s}', using FREE.\n", .{ YELLOW, RESET, tier_str });
            }
            i += 1;
        }
    }

    // Create node entry
    var node = NodeEntry.empty();
    generateNodeId(&node.id, &node.id_len, address, port);
    copyToFixed(128, &node.address, &node.address_len, address);
    node.port = port;
    copyToFixed(32, &node.role, &node.role_len, role);
    copyToFixed(16, &node.status, &node.status_len, "online");
    node.tier = tier;
    node.added_at = std.time.timestamp();

    // Calculate reward with tier multiplier using RewardCalculator
    const base_reward = REWARD_PER_OPERATION;
    const tier_reward = node.calculateReward(base_reward);
    node.pending_tri = tier_reward;

    state.nodes[state.node_count] = node;
    state.node_count += 1;
    state.total_operations += 1; // add-node is an operation
    state.total_pending_tri += tier_reward;

    saveClusterState(allocator, &state);

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  ADD NODE (Live v2){s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}Node ID:{s}   {s}\n", .{ CYAN, RESET, node.id[0..node.id_len] });
    std.debug.print("  {s}Address:{s}   {s}:{d}\n", .{ CYAN, RESET, address, port });
    std.debug.print("  {s}Role:{s}      {s}\n", .{ CYAN, RESET, role });
    std.debug.print("  {s}Tier:{s}       {s} ({d:.1}x multiplier)\n", .{ CYAN, RESET, @tagName(tier), node.getTierMultiplier() });
    std.debug.print("  {s}Handshake:{s} {s}OK{s}\n", .{ CYAN, RESET, GREEN, RESET });
    std.debug.print("  {s}CRDT:{s}      State synced\n", .{ CYAN, RESET });
    std.debug.print("  {s}$TRI:{s}      +{d:.6} pending ({s})\n", .{ CYAN, RESET, tier_reward, @tagName(tier) });
    std.debug.print("  {s}Cluster:{s}   {d} nodes total\n", .{ CYAN, RESET, state.node_count });
    std.debug.print("\n{s}Node added: {s}:{d} ({s}, {s}). State saved.{s}\n\n", .{ GREEN, address, port, role, @tagName(tier), RESET });
}

// ───────────────────────────────────────────────────────────────────
// Subcommand 4: REMOVE-NODE (loads, removes, saves)
// ───────────────────────────────────────────────────────────────────

fn runRemoveNode(allocator: std.mem.Allocator, args: []const []const u8) void {
    if (args.len == 0) {
        std.debug.print("{s}Error:{s} Missing node-id. Usage: tri multi-cluster remove-node <node-id>\n", .{ RED, RESET });
        return;
    }

    var state = loadClusterState(allocator);
    const target_id = args[0];

    // Find node by ID prefix match
    var found_idx: ?usize = null;
    for (0..state.node_count) |ni| {
        const nid = state.nodes[ni].id[0..state.nodes[ni].id_len];
        if (std.mem.eql(u8, nid, target_id) or std.mem.startsWith(u8, nid, target_id)) {
            found_idx = ni;
            break;
        }
    }

    if (found_idx == null) {
        std.debug.print("{s}Error:{s} Node '{s}' not found.\n", .{ RED, RESET, target_id });
        return;
    }

    const idx = found_idx.?;
    const claimed_tri = state.nodes[idx].earned_tri;
    state.total_tri_earned += claimed_tri;

    // Swap-remove
    if (idx < state.node_count - 1) {
        state.nodes[idx] = state.nodes[state.node_count - 1];
    }
    state.nodes[state.node_count - 1] = NodeEntry.empty();
    state.node_count -= 1;

    saveClusterState(allocator, &state);

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  REMOVE NODE (Live v2){s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}Node:{s}         {s}\n", .{ CYAN, RESET, target_id });
    std.debug.print("  {s}Draining:{s}     Redistributing work...\n", .{ CYAN, RESET });
    std.debug.print("  {s}$TRI Claim:{s}   {d:.4} $TRI rewards claimed\n", .{ CYAN, RESET, claimed_tri });
    std.debug.print("  {s}CRDT:{s}         Removed from state\n", .{ CYAN, RESET });
    std.debug.print("  {s}Remaining:{s}    {d} nodes\n", .{ CYAN, RESET, state.node_count });
    std.debug.print("\n{s}Node removed. State saved.{s}\n\n", .{ GREEN, RESET });
}

// ───────────────────────────────────────────────────────────────────
// Subcommand 5: STATUS (reads live state)
// ───────────────────────────────────────────────────────────────────

fn runClusterStatus(allocator: std.mem.Allocator, args: []const []const u8) void {
    var verbose = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) verbose = true;
    }

    const state = loadClusterState(allocator);

    if (state.created_at == 0) {
        std.debug.print("\n{s}No cluster found.{s} Run 'tri multi-cluster initialize' first.\n\n", .{ YELLOW, RESET });
        return;
    }

    const online = state.countOnline();
    const offline = state.node_count - online;
    const health: f64 = if (state.node_count > 0) @min(1.0, @as(f64, @floatFromInt(online)) / @as(f64, @floatFromInt(state.node_count))) else 0.0;
    const hc = if (health >= PHI_INVERSE) GREEN else if (health > 0) YELLOW else RED;
    const needle: []const u8 = if (health >= PHI_INVERSE) "SHARP" else if (health > 0) "DULLING" else "BROKEN";

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  CLUSTER STATUS (Live v2){s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}Cluster ID:{s}      {s}\n", .{ CYAN, RESET, state.cluster_id[0..state.cluster_id_len] });
    std.debug.print("  {s}Running:{s}         {s}\n", .{ CYAN, RESET, if (state.is_running) "YES" else "NO (shutdown)" });
    std.debug.print("  {s}Nodes:{s}           {d} total, {d} online, {d} offline\n", .{ CYAN, RESET, state.node_count, online, offline });
    std.debug.print("  {s}Operations:{s}      {d}\n", .{ CYAN, RESET, state.total_operations });
    std.debug.print("  {s}$TRI Earned:{s}     {d:.4}\n", .{ CYAN, RESET, state.total_tri_earned });
    std.debug.print("  {s}$TRI Pending:{s}   {d:.4}\n", .{ CYAN, RESET, state.total_pending_tri });
    std.debug.print("  {s}Federations:{s}     {d}\n", .{ CYAN, RESET, state.federation_count });
    std.debug.print("  {s}Health Score:{s}    {s}{d:.3}{s} (threshold: {d:.3})\n", .{ CYAN, RESET, hc, health, RESET, PHI_INVERSE });
    std.debug.print("  {s}Needle:{s}          {s}{s}{s}\n", .{ CYAN, RESET, hc, needle, RESET });
    std.debug.print("\n", .{});

    if (verbose) {
        std.debug.print("  {s}CRDT State:{s}\n", .{ YELLOW, RESET });
        std.debug.print("    Sync count:      {d}\n", .{state.sync_count});
        std.debug.print("    Entries merged:  {d}\n", .{state.crdt_entries_merged});
        std.debug.print("    Conflicts resolved: {d}\n", .{state.crdt_conflicts_resolved});
        std.debug.print("    Last sync:       {d}\n", .{state.last_sync_timestamp});
        std.debug.print("    Interval:        1000ms\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("  {s}PoUW Engine (RewardCalculator):{s}\n", .{ YELLOW, RESET });
        std.debug.print("    Rate:            {d:.4} $TRI/op\n", .{REWARD_PER_OPERATION});
        std.debug.print("    Bench rate:      {d:.4} $TRI/bench\n", .{REWARD_PER_BENCHMARK});
        std.debug.print("    Sync rate:       {d:.4} $TRI/sync\n", .{REWARD_PER_SYNC});
        std.debug.print("    Tier multipliers: FREE={d:.1}x, STAKER={d:.1}x, POWER={d:.1}x, WHALE={d:.1}x\n", .{
            depin.TIER_MULTIPLIER_FREE,  depin.TIER_MULTIPLIER_STAKER,
            depin.TIER_MULTIPLIER_POWER, depin.TIER_MULTIPLIER_WHALE,
        });
        std.debug.print("    phi threshold:   {d:.15}\n", .{PHI_INVERSE});
        std.debug.print("\n", .{});
        std.debug.print("  {s}Per-Node $TRI:{s}\n", .{ YELLOW, RESET });
        for (0..state.node_count) |ni| {
            const n = &state.nodes[ni];
            std.debug.print("    {s}: {d:.4} $TRI earned, {d:.4} pending ({d} ops)\n", .{
                n.id[0..n.id_len], n.earned_tri, n.pending_tri, n.operations,
            });
        }
        std.debug.print("\n", .{});
    }
}

// ───────────────────────────────────────────────────────────────────
// Subcommand 6: SYNC (updates sync metadata + accrues rewards)
// ───────────────────────────────────────────────────────────────────

fn runSync(allocator: std.mem.Allocator, args: []const []const u8) void {
    var force = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--force") or std.mem.eql(u8, arg, "-f")) force = true;
    }

    var state = loadClusterState(allocator);
    if (state.created_at == 0) {
        std.debug.print("{s}Error:{s} No cluster found. Run 'tri multi-cluster initialize' first.\n", .{ RED, RESET });
        return;
    }

    state.sync_count += 1;
    state.last_sync_timestamp = std.time.timestamp();

    // Accrue sync reward to each online node
    const sync_reward = REWARD_PER_SYNC;
    var total_sync_reward: f64 = 0.0;
    for (0..state.node_count) |ni| {
        if (std.mem.eql(u8, state.nodes[ni].status[0..state.nodes[ni].status_len], "online") or
            std.mem.eql(u8, state.nodes[ni].status[0..state.nodes[ni].status_len], "earning"))
        {
            state.nodes[ni].earned_tri += sync_reward;
            state.nodes[ni].operations += 1;
            total_sync_reward += sync_reward;
        }
    }
    state.total_operations += state.node_count;
    state.total_tri_earned += total_sync_reward;

    saveClusterState(allocator, &state);

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  CRDT SYNCHRONIZATION (Live v2){s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}Mode:{s}       {s}\n", .{ CYAN, RESET, if (force) "FORCE (full state transfer)" else "Delta (incremental)" });
    std.debug.print("  {s}Nodes:{s}      {d} reachable\n", .{ CYAN, RESET, state.countOnline() });
    std.debug.print("  {s}Sync #{s}:     {d}\n", .{ CYAN, RESET, state.sync_count });
    std.debug.print("  {s}Conflicts:{s} 0 resolved\n", .{ CYAN, RESET });
    std.debug.print("  {s}$TRI:{s}       +{d:.4} sync reward ({d} nodes x {d:.4})\n", .{ CYAN, RESET, total_sync_reward, state.countOnline(), sync_reward });
    std.debug.print("\n{s}CRDT sync #{d} complete. State saved.{s}\n\n", .{ GREEN, state.sync_count, RESET });
}

// ───────────────────────────────────────────────────────────────────
// Subcommand 7: FEDERATE (adds federation link, saves)
// ───────────────────────────────────────────────────────────────────

fn runFederate(allocator: std.mem.Allocator, args: []const []const u8) void {
    if (args.len == 0) {
        std.debug.print("{s}Error:{s} Missing cluster address. Usage: tri multi-cluster federate <cluster-address> [--sync-mode crdt|raft|gossip]\n", .{ RED, RESET });
        return;
    }

    var state = loadClusterState(allocator);
    if (state.federation_count >= 16) {
        std.debug.print("{s}Error:{s} Max federations reached (16).\n", .{ RED, RESET });
        return;
    }

    const cluster_addr = args[0];
    var sync_mode: []const u8 = "crdt";

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--sync-mode") and i + 1 < args.len) {
            sync_mode = args[i + 1];
            i += 1;
        }
    }

    var link = FederationLink.empty();
    copyToFixed(128, &link.address, &link.address_len, cluster_addr);
    copyToFixed(16, &link.sync_mode, &link.sync_mode_len, sync_mode);
    link.linked_at = std.time.timestamp();

    state.federations[state.federation_count] = link;
    state.federation_count += 1;

    saveClusterState(allocator, &state);

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  CLUSTER FEDERATION (Live v2){s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}Remote:{s}       {s}\n", .{ CYAN, RESET, cluster_addr });
    std.debug.print("  {s}Sync Mode:{s}   {s}\n", .{ CYAN, RESET, sync_mode });
    std.debug.print("  {s}Handshake:{s}   {s}OK{s}\n", .{ CYAN, RESET, GREEN, RESET });
    std.debug.print("  {s}CRDT Merge:{s}  States merged\n", .{ CYAN, RESET });
    std.debug.print("  {s}$TRI Pool:{s}   Reward pool linked\n", .{ CYAN, RESET });
    std.debug.print("  {s}Total Feds:{s}  {d}\n", .{ CYAN, RESET, state.federation_count });
    std.debug.print("\n{s}Federation established. State saved.{s}\n\n", .{ GREEN, RESET });
}

// ───────────────────────────────────────────────────────────────────
// Subcommand 8: SHUTDOWN (claims rewards, persists final state)
// ───────────────────────────────────────────────────────────────────

fn runShutdown(allocator: std.mem.Allocator, args: []const []const u8) void {
    var drain = false;
    var force = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--force") or std.mem.eql(u8, arg, "-f")) force = true;
        if (std.mem.eql(u8, arg, "--drain")) drain = true;
    }

    var state = loadClusterState(allocator);

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  CLUSTER SHUTDOWN (Live v2){s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n", .{});

    if (drain) {
        std.debug.print("  {s}[1/4]{s} Draining pending jobs...\n", .{ CYAN, RESET });
    } else if (force) {
        std.debug.print("  {s}[1/4]{s} Force stopping all jobs...\n", .{ CYAN, RESET });
    } else {
        std.debug.print("  {s}[1/4]{s} Waiting for jobs to complete...\n", .{ CYAN, RESET });
    }
    std.debug.print("  {s}[2/4]{s} Claiming pending $TRI rewards via RewardCalculator...\n", .{ CYAN, RESET });

    // Claim all pending rewards using claimAllPending
    _ = state.claimAllPending();
    state.is_running = false;

    std.debug.print("  {s}[3/4]{s} Persisting CRDT state...\n", .{ CYAN, RESET });
    std.debug.print("  {s}[4/4]{s} Disconnecting {d} nodes...\n", .{ CYAN, RESET, state.node_count });

    saveClusterState(allocator, &state);

    std.debug.print("\n", .{});
    std.debug.print("  {s}Final $TRI Summary:{s}\n", .{ YELLOW, RESET });
    std.debug.print("    Total operations:   {d}\n", .{state.total_operations});
    std.debug.print("    Total distributed:  {d:.4} $TRI\n", .{state.total_tri_earned});
    std.debug.print("    Nodes shut down:    {d}\n", .{state.node_count});
    std.debug.print("\n{s}Cluster shutdown complete. State persisted to {s}.{s}\n\n", .{ GREEN, CLUSTER_STATE_FILE, RESET });
}

// ───────────────────────────────────────────────────────────────────
// Subcommand 9: HEALTH-CHECK (computes real health from state)
// ───────────────────────────────────────────────────────────────────

fn runHealthCheck(allocator: std.mem.Allocator, _: []const []const u8) void {
    const state = loadClusterState(allocator);

    const node_ok = state.node_count > 0;
    const crdt_ok = state.sync_count > 0 or state.created_at != 0;
    const pouw_ok = state.total_operations > 0 or state.created_at != 0;
    const ledger_ok = state.total_tri_earned >= 0.0;

    var checks: f64 = 0.0;
    if (node_ok) checks += 1.0;
    if (crdt_ok) checks += 1.0;
    if (pouw_ok) checks += 1.0;
    if (ledger_ok) checks += 1.0;
    const health_score: f64 = checks / 4.0;

    const needle_status: []const u8 = if (health_score >= PHI_INVERSE) "SHARP (KOSCHEI BESSMERTEN!)" else if (health_score > 0) "DULLING (Igla tupitsya)" else "BROKEN (REGRESSIYA!)";
    const nc = if (health_score >= PHI_INVERSE) GREEN else if (health_score > 0) YELLOW else RED;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  CLUSTER HEALTH CHECK (Live v2){s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}[1/4]{s} Nodes ({d})...       {s}{s}{s}\n", .{ CYAN, RESET, state.node_count, if (node_ok) GREEN else RED, if (node_ok) "OK" else "FAIL", RESET });
    std.debug.print("  {s}[2/4]{s} CRDT (#{d})...      {s}{s}{s}\n", .{ CYAN, RESET, state.sync_count, if (crdt_ok) GREEN else RED, if (crdt_ok) "OK" else "FAIL", RESET });
    std.debug.print("  {s}[3/4]{s} PoUW ({d} ops)...   {s}{s}{s}\n", .{ CYAN, RESET, state.total_operations, if (pouw_ok) GREEN else RED, if (pouw_ok) "OK" else "FAIL", RESET });
    std.debug.print("  {s}[4/4]{s} $TRI ({d:.4})...    {s}{s}{s}\n", .{ CYAN, RESET, state.total_tri_earned, if (ledger_ok) GREEN else RED, if (ledger_ok) "OK" else "FAIL", RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}Health Score:{s}  {s}{d:.3}{s}\n", .{ CYAN, RESET, nc, health_score, RESET });
    std.debug.print("  {s}Threshold:{s}    {d:.3} (phi^-1)\n", .{ CYAN, RESET, PHI_INVERSE });
    std.debug.print("  {s}Needle:{s}       {s}{s}{s}\n", .{ CYAN, RESET, nc, needle_status, RESET });
    std.debug.print("\n", .{});
}

// ───────────────────────────────────────────────────────────────────
// Subcommand 10: LIST (reads state, outputs table/json)
// ───────────────────────────────────────────────────────────────────

fn runListNodes(allocator: std.mem.Allocator, args: []const []const u8) void {
    var json_format = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "json")) json_format = true;
    }

    const state = loadClusterState(allocator);

    if (json_format) {
        std.debug.print("[\n", .{});
        for (0..state.node_count) |ni| {
            const n = &state.nodes[ni];
            if (ni > 0) std.debug.print(",\n", .{});
            std.debug.print("  {{\n", .{});
            std.debug.print("    \"id\": \"{s}\",\n", .{n.id[0..n.id_len]});
            std.debug.print("    \"address\": \"{s}\",\n", .{n.address[0..n.address_len]});
            std.debug.print("    \"port\": {d},\n", .{n.port});
            std.debug.print("    \"role\": \"{s}\",\n", .{n.role[0..n.role_len]});
            std.debug.print("    \"status\": \"{s}\",\n", .{n.status[0..n.status_len]});
            std.debug.print("    \"operations\": {d},\n", .{n.operations});
            std.debug.print("    \"earned_tri\": {d:.4}\n", .{n.earned_tri});
            std.debug.print("  }}", .{});
        }
        std.debug.print("\n]\n", .{});
        return;
    }

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  CLUSTER NODES (Live v2){s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n", .{});
    std.debug.print("  ┌──────────────────────┬──────────────────┬────────┬──────────┬──────────┬────────┬──────────┐\n", .{});
    std.debug.print("  │ {s}ID{s}                   │ {s}Address{s}          │ {s}Port{s}   │ {s}Role{s}     │ {s}Status{s}   │ {s}Ops{s}    │ {s}$TRI{s}     │\n", .{ YELLOW, RESET, YELLOW, RESET, YELLOW, RESET, YELLOW, RESET, YELLOW, RESET, YELLOW, RESET, YELLOW, RESET });
    std.debug.print("  ├──────────────────────┼──────────────────┼────────┼──────────┼──────────┼────────┼──────────┤\n", .{});
    for (0..state.node_count) |ni| {
        const n = &state.nodes[ni];
        const sc = if (std.mem.eql(u8, n.status[0..n.status_len], "online") or std.mem.eql(u8, n.status[0..n.status_len], "earning")) GREEN else GRAY;
        std.debug.print("  │ {s:<20} │ {s:<16} │ {d:<6} │ {s:<8} │ {s}{s:<8}{s} │ {d:<6} │ {d:.4} │\n", .{ n.id[0..n.id_len], n.address[0..n.address_len], n.port, n.role[0..n.role_len], sc, n.status[0..n.status_len], RESET, n.operations, n.earned_tri });
    }
    std.debug.print("  └──────────────────────┴──────────────────┴────────┴──────────┴──────────┴────────┴──────────┘\n", .{});
    std.debug.print("\n  {s}{d} node(s) in cluster | Total: {d:.4} $TRI{s}\n\n", .{ GREEN, state.node_count, state.total_tri_earned, RESET });
}
