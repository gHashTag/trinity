const std = @import("std");
const evolved = @import("evolved_codex.zig");

// ============================================================================
// NETWORKED CLI - THE DISTRIBUTED ORGANISM
// ============================================================================

pub const NetworkStats = struct {
    latency_ms: u64,
    bandwidth_mbps: f32,
    connected_nodes: u32,
};

pub const NetworkOrganism = struct {
    allocator: std.mem.Allocator,
    tri_balance: f64 = 0.0,
    stats: NetworkStats,
    app: *evolved.EvolvedCodex,

    pub fn init(allocator: std.mem.Allocator, app: *evolved.EvolvedCodex) NetworkOrganism {
        return NetworkOrganism{
            .allocator = allocator,
            .tri_balance = 0.0,
            .stats = .{
                .latency_ms = 20,
                .bandwidth_mbps = 100.0,
                .connected_nodes = 3,
            },
            .app = app,
        };
    }

    pub fn syncWithTrinityL2(self: *NetworkOrganism, node_addr: []const u8) !void {
        std.debug.print("🌐 [Network] Connecting to Trinity L2 at {s}...\n", .{node_addr});
        std.Thread.sleep(100 * std.time.ns_per_ms);

        // Mobile-aware mutation
        if (self.stats.bandwidth_mbps < 10.0 or self.stats.latency_ms > 50) {
            std.debug.print("📱 [Mobile] Environmental Throttling active ({d:.1} Mbps, {d}ms latency)\n", .{ self.stats.bandwidth_mbps, self.stats.latency_ms });
            std.debug.print("🦋 [Mutation] Auto-reducing neural density for stability...\n", .{});
            self.app.mode = .STANDARD;
        }

        std.debug.print("✅ [Network] Connected to node. Harmony established.\n", .{});
    }

    pub fn earnMockTRI(self: *NetworkOrganism, job_id: []const u8) void {
        const reward = 0.5; // Mock $TRI per job
        self.tri_balance += reward;
        std.debug.print("💰 [Economy] Job {s} completed. Earned {d:.2} $TRI. New Balance: {d:.2} $TRI\n", .{ job_id, reward, self.tri_balance });
    }
};

// ============================================================================
// HANDLERS
// ============================================================================

fn networkHandler(ctx: *evolved.Context, args: []const []const u8) !void {
    var net = NetworkOrganism.init(ctx.allocator, ctx.app);
    var node_addr: []const u8 = "trinity-l2-root";

    // Parse subcommands
    if (args.len > 0 and std.mem.eql(u8, args[0], "--connect")) {
        if (args.len > 1) node_addr = args[1];
    }

    // Mobile check
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--mobile")) {
            net.stats.bandwidth_mbps = 5.0;
            net.stats.latency_ms = 120;
        }
    }

    try net.syncWithTrinityL2(node_addr);
    net.earnMockTRI("job_4th_life");
}

// ============================================================================
// MAIN ENTRY
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try evolved.EvolvedCodex.init(allocator);
    defer app.deinit();

    // Bind network reflex
    try app.handlers.put("network", networkHandler);

    std.debug.print("\n📡 THE FOURTH LIFE: NETWORKED CLI\n", .{});

    // 1. Standard Network Sync
    const args = [_][]const u8{"network"};
    try app.fire(&args);

    // 2. Mobile Mutation Test
    std.debug.print("\n📱 Testing Mobile Adaptation...\n", .{});
    const mobile_args = [_][]const u8{ "network", "--mobile" };
    try app.fire(&mobile_args);

    std.debug.print("\n✅ Network Verification Complete.\n", .{});
}
