// @origin(spec:depin_reputation.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// FIREBIRD REPUTATION — Neuroanatomical Health Scoring
// ═══════════════════════════════════════════════════════════════════════════════
//
// Neuroanatomical health scoring based on brain region contributions:
// - 35% Prefrontal Cortex (executive function)
// - 30% Cerebellum (consistency/reliability)
// - 20% Hippocampus (memory/learning)
// - 15% Basal Ganglia (action selection)
//
// Uses Q16 fixed-point arithmetic for compatibility with TRI-27 VM.
//
// Lock ordering: app_state → reputation → staking
//
// φ² + 1/φ² = 3 = TRINITY | Genesis Block: 26 March 2026, 00:00 UTC
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN REGIONS (Neuroanatomical Model)
// ═══════════════════════════════════════════════════════════════════════════════

pub const BrainRegion = enum(u8) {
    synapse = 0,
    hippocampus = 1,
    basal_ganglia = 2,
    prefrontal = 3,
    thalamus = 4,
    cerebellum = 5,
    amygdala = 6,
    brainstem = 7,

    pub fn toString(self: BrainRegion) []const u8 {
        return switch (self) {
            .synapse => "SYNAPSE",
            .hippocampus => "HIPPOCAMPUS",
            .basal_ganglia => "BASAL_GANGLIA",
            .prefrontal => "PREFRONTAL",
            .thalamus => "THALAMUS",
            .cerebellum => "CEREBELLUM",
            .amygdala => "AMYGDALA",
            .brainstem => "BRAINSTEM",
        };
    }

    pub fn emoji(self: BrainRegion) []const u8 {
        return switch (self) {
            .synapse => "🔗",
            .hippocampus => "🧠",
            .basal_ganglia => "⚙️",
            .prefrontal => "🎯",
            .thalamus => "🔮",
            .cerebellum => "⚖️",
            .amygdala => "😤",
            .brainstem => "🌟",
        };
    }

    pub fn weight(self: BrainRegion) f64 {
        return switch (self) {
            .prefrontal => 0.35, // Executive function
            .cerebellum => 0.30, // Consistency/reliability
            .hippocampus => 0.20, // Memory/learning
            .basal_ganglia => 0.15, // Action selection
            else => 0.0, // Other regions not used in health score
        };
    }

    /// Get Q16 fixed-point weight (1.0 = 65536)
    pub fn weightQ16(self: BrainRegion) u32 {
        return switch (self) {
            .prefrontal => 22937, // 0.35 * 65536
            .cerebellum => 19661, // 0.30 * 65536
            .hippocampus => 13107, // 0.20 * 65536
            .basal_ganglia => 9830, // 0.15 * 65536
            else => 0,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// NODE METRICS (Per-node performance metrics)
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeMetrics = struct {
    /// Node identifier (service name or address)
    node_id: []const u8,
    /// Metrics for each brain region (Q16: 0.0-65536 = 0.0-1.0)
    prefrontal_executive: u32 = 32768, // Default: 0.5
    cerebellum_consistency: u32 = 32768, // Default: 0.5
    hippocampus_memory: u32 = 32768, // Default: 0.5
    basal_action: u32 = 32768, // Default: 0.5
    /// Total operations processed
    operations_count: u64 = 0,
    /// Last update timestamp
    last_update: i64 = 0,
    /// Current health score (cached)
    health_score: u32 = 32768, // Default: 0.5

    pub fn init(node_id: []const u8) NodeMetrics {
        return NodeMetrics{
            .node_id = node_id,
            .last_update = std.time.timestamp(),
        };
    }

    /// Calculate health score from metrics (Q16 fixed-point)
    pub fn calculateHealth(self: *const NodeMetrics) u32 {
        // health = 0.35×prefrontal + 0.30×cerebellum + 0.20×hippocampus + 0.15×basal
        // All in Q16 fixed-point, result needs division by 65536

        const prefrontal_weight = BrainRegion.prefrontal.weightQ16();
        const cerebellum_weight = BrainRegion.cerebellum.weightQ16();
        const hippocampus_weight = BrainRegion.hippocampus.weightQ16();
        const basal_weight = BrainRegion.basal_ganglia.weightQ16();

        // Weighted sum (64-bit to prevent overflow)
        const sum: u64 =
            @as(u64, self.prefrontal_executive) * prefrontal_weight +
            @as(u64, self.cerebellum_consistency) * cerebellum_weight +
            @as(u64, self.hippocampus_memory) * hippocampus_weight +
            @as(u64, self.basal_action) * basal_weight;

        // Normalize back to Q16 (divide by 65536)
        const health: u32 = @intCast(sum >> 16);
        return health;
    }

    /// Update health score cache
    pub fn updateHealth(self: *NodeMetrics) void {
        self.health_score = self.calculateHealth();
        self.last_update = std.time.timestamp();
    }

    /// Get health score as f64 (0.0 - 1.0)
    pub fn getHealthFloat(self: *const NodeMetrics) f64 {
        return @as(f64, @floatFromInt(self.health_score)) / 65536.0;
    }

    /// Get health grade (A-F)
    pub fn getHealthGrade(self: *const NodeMetrics) u8 {
        const health = self.getHealthFloat();
        return if (health >= 0.9)
            @as(u8, 'A')
        else if (health >= 0.8)
            @as(u8, 'B')
        else if (health >= 0.7)
            @as(u8, 'C')
        else if (health >= 0.6)
            @as(u8, 'D')
        else
            @as(u8, 'F');
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REPUTATION REGISTRY
// ═══════════════════════════════════════════════════════════════════════════════

pub const ReputationRegistry = struct {
    allocator: Allocator,
    /// Mutex protects all reputation state
    mutex: std.Thread.Mutex,
    /// Node metrics indexed by node_id
    metrics: std.StringHashMapUnmanaged(NodeMetrics),
    /// Health table for fast lookup (Q16 scores)
    health_table: std.StringHashMapUnmanaged(u32),
    /// Total nodes tracked
    total_nodes: usize,

    pub fn init(allocator: Allocator) ReputationRegistry {
        return ReputationRegistry{
            .allocator = allocator,
            .mutex = .{},
            .metrics = .{},
            .health_table = .{},
            .total_nodes = 0,
        };
    }

    pub fn deinit(self: *ReputationRegistry) void {
        var iter = self.metrics.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.metrics.deinit(self.allocator);
        self.health_table.deinit(self.allocator);
    }

    /// Register or update a node's metrics
    pub fn updateMetrics(self: *ReputationRegistry, node_id: []const u8, metrics: NodeMetrics) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const duped_id = try self.allocator.dupe(u8, node_id);
        errdefer self.allocator.free(duped_id);

        const health = metrics.calculateHealth();

        if (self.metrics.getEntry(duped_id)) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.* = metrics;
            entry.value_ptr.*.node_id = duped_id;
            entry.value_ptr.*.health_score = health; // Update cached health
        } else {
            var new_metrics = metrics;
            new_metrics.health_score = health; // Update cached health
            try self.metrics.put(self.allocator, duped_id, new_metrics);
            self.total_nodes += 1;
        }

        try self.health_table.put(self.allocator, duped_id, health);
    }

    /// Get node metrics
    pub fn getMetrics(self: *ReputationRegistry, node_id: []const u8) ?NodeMetrics {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.metrics.get(node_id);
    }

    /// Get node health score (Q16)
    pub fn getHealth(self: *ReputationRegistry, node_id: []const u8) ?u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.health_table.get(node_id);
    }

    /// Get node health score as f64
    pub fn getHealthFloat(self: *ReputationRegistry, node_id: []const u8) ?f64 {
        const health_q16 = self.getHealth(node_id) orelse return null;
        return @as(f64, @floatFromInt(health_q16)) / 65536.0;
    }

    /// Update a specific brain region metric
    pub fn updateRegion(self: *ReputationRegistry, node_id: []const u8, region: BrainRegion, value: u32) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.metrics.getEntry(node_id) orelse return error.NodeNotFound;

        switch (region) {
            .prefrontal => entry.value_ptr.prefrontal_executive = value,
            .cerebellum => entry.value_ptr.cerebellum_consistency = value,
            .hippocampus => entry.value_ptr.hippocampus_memory = value,
            .basal_ganglia => entry.value_ptr.basal_action = value,
            else => return error.InvalidRegion,
        }

        // Recalculate health
        const health = entry.value_ptr.calculateHealth();
        entry.value_ptr.health_score = health;
        entry.value_ptr.last_update = std.time.timestamp();

        try self.health_table.put(self.allocator, node_id, health);
    }

    /// Get all node IDs sorted by health score
    pub fn getTopNodes(self: *ReputationRegistry, allocator: Allocator, limit: usize) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.metrics.count() == 0) return &[_][]const u8{};

        // Create list of (node_id, health_score) pairs
        const NodeEntry = struct { []const u8, u32 };
        var entries = try std.ArrayList(NodeEntry).initCapacity(allocator, self.metrics.count());
        defer entries.deinit();

        var iter = self.metrics.iterator();
        while (iter.next()) |entry| {
            const health = entry.value_ptr.health_score;
            entries.appendAssumeCapacity(.{ entry.key_ptr.*, health });
        }

        // Sort by health score (descending)
        std.sort.insertion(NodeEntry, entries.items, {}, struct {
            fn lessThan(_: void, a: NodeEntry, b: NodeEntry) bool {
                return a[1] > b[1]; // Descending
            }
        }.lessThan);

        // Take top N
        const count = @min(limit, entries.items.len);
        const result = try allocator.alloc([]const u8, count);
        for (entries.items[0..count], 0..) |entry, i| {
            result[i] = try allocator.dupe(u8, entry[0]);
        }

        return result;
    }

    /// Get aggregate statistics (read-only, thread-safe)
    pub fn getStats(self: *const ReputationRegistry) Stats {
        const self_mut: *ReputationRegistry = @constCast(self);
        self_mut.mutex.lock();
        defer self_mut.mutex.unlock();

        if (self_mut.metrics.count() == 0) {
            return Stats{
                .total_nodes = 0,
                .average_health = 0.0,
                .healthy_nodes = 0,
                .degraded_nodes = 0,
                .critical_nodes = 0,
            };
        }

        var total_health: f64 = 0.0;
        var healthy: usize = 0;
        var degraded: usize = 0;
        var critical: usize = 0;

        var iter = self_mut.metrics.iterator();
        while (iter.next()) |entry| {
            const health = entry.value_ptr.getHealthFloat();
            total_health += health;

            if (health >= 0.7) {
                healthy += 1;
            } else if (health >= 0.5) {
                degraded += 1;
            } else {
                critical += 1;
            }
        }

        return Stats{
            .total_nodes = self_mut.metrics.count(),
            .average_health = total_health / @as(f64, @floatFromInt(self_mut.metrics.count())),
            .healthy_nodes = healthy,
            .degraded_nodes = degraded,
            .critical_nodes = critical,
        };
    }

    pub const Stats = struct {
        total_nodes: usize,
        average_health: f64,
        healthy_nodes: usize,
        degraded_nodes: usize,
        critical_nodes: usize,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BrainRegion weights" {
    try std.testing.expectApproxEqAbs(@as(f64, 0.35), BrainRegion.prefrontal.weight(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.30), BrainRegion.cerebellum.weight(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.20), BrainRegion.hippocampus.weight(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.15), BrainRegion.basal_ganglia.weight(), 0.001);
}

test "BrainRegion weightQ16" {
    try std.testing.expectEqual(@as(u32, 22937), BrainRegion.prefrontal.weightQ16());
    try std.testing.expectEqual(@as(u32, 19661), BrainRegion.cerebellum.weightQ16());
    try std.testing.expectEqual(@as(u32, 13107), BrainRegion.hippocampus.weightQ16());
    try std.testing.expectEqual(@as(u32, 9830), BrainRegion.basal_ganglia.weightQ16());
}

test "NodeMetrics calculateHealth" {
    var metrics = NodeMetrics{
        .node_id = "test_node",
        .prefrontal_executive = 65535, // 1.0
        .cerebellum_consistency = 65535, // 1.0
        .hippocampus_memory = 65535, // 1.0
        .basal_action = 65535, // 1.0
    };

    const health = metrics.calculateHealth();
    // All perfect = should be ~65535 (with small precision loss from >> 16)
    try std.testing.expect(health > 65000);

    // Calculate float directly from the returned health value
    const health_float = @as(f64, @floatFromInt(health)) / 65536.0;
    try std.testing.expect(health_float >= 0.99);
}

test "NodeMetrics calculateHealth with zeros" {
    var metrics = NodeMetrics{
        .node_id = "test_node",
        .prefrontal_executive = 0,
        .cerebellum_consistency = 0,
        .hippocampus_memory = 0,
        .basal_action = 0,
    };

    const health = metrics.calculateHealth();
    try std.testing.expectEqual(@as(u32, 0), health);
}

test "NodeMetrics getHealthGrade" {
    var metrics = NodeMetrics{
        .node_id = "test_node",
        .prefrontal_executive = 65535,
        .cerebellum_consistency = 65535,
        .hippocampus_memory = 65535,
        .basal_action = 65535,
    };
    metrics.updateHealth(); // Update cached health_score

    try std.testing.expectEqual(@as(u8, 'A'), metrics.getHealthGrade());

    // Set all values to 0.5 for F grade
    metrics.prefrontal_executive = 32768;
    metrics.cerebellum_consistency = 32768;
    metrics.hippocampus_memory = 32768;
    metrics.basal_action = 32768;
    metrics.updateHealth();
    try std.testing.expectEqual(@as(u8, 'F'), metrics.getHealthGrade());
}

test "ReputationRegistry update and get" {
    const allocator = std.testing.allocator;
    var registry = ReputationRegistry.init(allocator);
    defer registry.deinit();

    const metrics = NodeMetrics.init("node1");
    try registry.updateMetrics("node1", metrics);

    const retrieved = registry.getMetrics("node1");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("node1", retrieved.?.node_id);
}

test "ReputationRegistry health lookup" {
    const allocator = std.testing.allocator;
    var registry = ReputationRegistry.init(allocator);
    defer registry.deinit();

    var metrics = NodeMetrics.init("node1");
    metrics.prefrontal_executive = 65535;
    metrics.cerebellum_consistency = 65535;
    metrics.hippocampus_memory = 65535;
    metrics.basal_action = 65535;

    try registry.updateMetrics("node1", metrics);

    const health = registry.getHealth("node1");
    try std.testing.expect(health != null);
    try std.testing.expect(health.? > 65000);
}

test "ReputationRegistry updateRegion" {
    const allocator = std.testing.allocator;
    var registry = ReputationRegistry.init(allocator);
    defer registry.deinit();

    const metrics = NodeMetrics.init("node1");
    try registry.updateMetrics("node1", metrics);

    try registry.updateRegion("node1", .prefrontal, 65535);

    const updated = registry.getMetrics("node1").?;
    try std.testing.expectEqual(@as(u32, 65535), updated.prefrontal_executive);
}

test "ReputationRegistry getStats" {
    const allocator = std.testing.allocator;
    var registry = ReputationRegistry.init(allocator);
    defer registry.deinit();

    // Add healthy node
    var metrics1 = NodeMetrics.init("node1");
    metrics1.prefrontal_executive = 65535;
    metrics1.cerebellum_consistency = 65535;
    metrics1.hippocampus_memory = 65535;
    metrics1.basal_action = 65535;
    try registry.updateMetrics("node1", metrics1);

    // Add degraded node
    var metrics2 = NodeMetrics.init("node2");
    metrics2.prefrontal_executive = 32768;
    metrics2.cerebellum_consistency = 32768;
    try registry.updateMetrics("node2", metrics2);

    const stats = registry.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.total_nodes);
    try std.testing.expectEqual(@as(usize, 1), stats.healthy_nodes);
    try std.testing.expect(stats.average_health > 0.5);
}
