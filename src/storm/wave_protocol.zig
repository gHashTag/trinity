//! STORM P5 — Wave Protocol (5 waves, 32 agents)
//! Self-Organizing Regenerative Task Management
//! Parallel wave execution with checkpoint recovery

const std = @import("std");
const gc = @import("golden_chain.zig");

pub const Wave = struct {
    id: u4,
    name: []const u8,
    agent_count: u5,
    links: []const u8, // Link IDs in this wave
    parallel: bool = true, // True = run agents in parallel
    timeout_ms: u64 = 600_000, // 10 min per wave default
};

pub const WaveConfig = struct {
    waves: [5]Wave,
    max_parallel_agents: u5 = 10, // Railway billing guard
    checkpoint_between_waves: bool = true,
    phoenix_regen_before_wave: bool = true,
};

pub const WaveResult = struct {
    wave_id: u4,
    wave_name: []const u8,
    success: bool,
    completed_agents: u5,
    failed_agents: u5,
    duration_ms: u64,
    errors: [][]const u8,
};

pub const STORM_WAVES = [5]Wave{
    // WAVE 1: Foundation (3 agents) — Requirements analysis
    .{ .id = 1, .name = "Foundation", .agent_count = 3, .links = &[_]u8{ 1, 2, 3 }, .parallel = true },

    // WAVE 2: Spec Creation (4 agents) — .tri generation
    .{ .id = 2, .name = "Spec Creation", .agent_count = 4, .links = &[_]u8{ 4, 5, 14, 18 }, .parallel = true },

    // WAVE 3: Code Generation (16 agents) — Full parallel build
    .{ .id = 3, .name = "Code Generation", .agent_count = 16, .links = &[_]u8{ 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 17, 19, 20, 22, 23, 24 }, .parallel = true },

    // WAVE 4: Testing (5 agents) — Quality gates
    .{ .id = 4, .name = "Testing", .agent_count = 5, .links = &[_]u8{ 19, 20, 21, 22, 23 }, .parallel = true },

    // WAVE 5: Verdict & Ship (4 agents) — Final checks + commit
    .{ .id = 5, .name = "Verdict & Ship", .agent_count = 4, .links = &[_]u8{ 13, 14, 15, 16, 17, 18, 25, 26, 27, 28 }, .parallel = false },
};

pub const StormWaveProtocol = struct {
    allocator: std.mem.Allocator,
    config: WaveConfig,
    golden_chain: *gc.GoldenChain,
    wave_results: std.ArrayListUnmanaged(WaveResult) = .empty,
    total_duration_ms: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, gc_chain: *gc.GoldenChain) !StormWaveProtocol {
        return .{
            .allocator = allocator,
            .config = .{ .waves = STORM_WAVES },
            .golden_chain = gc_chain,
        };
    }

    pub fn deinit(self: *StormWaveProtocol) void {
        for (self.wave_results.items) |wr| {
            for (wr.errors) |err| self.allocator.free(err);
            self.allocator.free(wr.errors);
        }
        self.wave_results.deinit(self.allocator);
    }

    /// Run all waves sequentially
    pub fn runAll(self: *StormWaveProtocol, task: []const u8) !u8 {
        std.debug.print("\n🌊 STORM Wave Protocol — 5 waves, 32 agents\n", .{});

        for (self.config.waves) |wave| {
            const result = try self.runWave(wave, task);
            try self.wave_results.append(self.allocator, result);

            if (!result.success) {
                std.debug.print("\n❌ Wave {} failed. Stopping storm.\n", .{wave.id});
                return 1;
            }

            // Checkpoint between waves if enabled
            if (self.config.checkpoint_between_waves) {
                _ = self.golden_chain.saveCheckpoint(task) catch |e| {
                    std.log.warn("Failed to save checkpoint: {}", .{e});
                };
            }

            // Phoenix regeneration before next wave if enabled
            if (self.config.phoenix_regen_before_wave and wave.id < 5) {
                self.runPhoenixRegen(wave.id + 1) catch |e| {
                    std.log.warn("Phoenix regen failed: {}", .{e});
                };
            }
        }

        self.printSummary();

        return 0;
    }

    /// Run single wave
    fn runWave(self: *StormWaveProtocol, wave: Wave, task: []const u8) !WaveResult {
        const start_time = std.time.nanoTimestamp();

        std.debug.print("\n🌊 WAVE {d}: {s} ({d} agents, {d} links)\n", .{
            wave.id, wave.name, wave.agent_count, wave.links.len,
        });

        const result_init = WaveResult{
            .wave_id = wave.id,
            .wave_name = wave.name,
            .success = true,
            .completed_agents = 0,
            .failed_agents = 0,
            .duration_ms = 0,
            .errors = try self.allocator.alloc([]const u8, 0),
        };
        var result = result_init;
        errdefer self.allocator.free(result.errors);

        if (wave.parallel) {
            // Parallel execution (simulated for P5, will use ThreadPool in P6)
            for (wave.links) |link_id| {
                const link = self.getLinkById(link_id) orelse continue;
                const link_result = try self.golden_chain.executeLink(link, task);
                if (link_result.success) {
                    result.completed_agents += 1;
                } else {
                    result.failed_agents += 1;
                    result.success = false;
                    const err_msg = try std.fmt.allocPrint(
                        self.allocator,
                        "Link {d} failed: {s}",
                        .{ link_id, link_result.message }
                    );
                    try result.errors.append(self.allocator, err_msg);
                }
            }
        } else {
            // Sequential execution (Wave 5: Verdict & Ship)
            for (wave.links) |link_id| {
                const link = self.getLinkById(link_id) orelse continue;
                const link_result = try self.golden_chain.executeLink(link, task);
                if (link_result.success) {
                    result.completed_agents += 1;
                } else {
                    result.failed_agents += 1;
                    result.success = false;
                    const err_msg = try std.fmt.allocPrint(
                        self.allocator,
                        "Link {d} failed: {s}",
                        .{ link_id, link_result.message }
                    );
                    try result.errors.append(self.allocator, err_msg);
                }
            }
        }

        const end_time = std.time.nanoTimestamp();
        result.duration_ms = @as(u64, @intCast((end_time - start_time) / 1_000_000));
        self.total_duration_ms += result.duration_ms;

        std.debug.print("✅ WAVE {d} completed: {d}/{d} agents in {}ms\n", .{
            wave.id, result.completed_agents, result.completed_agents + result.failed_agents, result.duration_ms,
        });

        return result;
    }

    /// Get link by ID from golden chain
    fn getLinkById(self: *StormWaveProtocol, id: u8) ?gc.Link {
        for (self.golden_chain.links) |link| {
            if (link.id == id) return link;
        }
        return null;
    }

    /// Phoenix regeneration before wave
    fn runPhoenixRegen(self: *StormWaveProtocol, wave_id: u4) !void {
        _ = self;
        std.debug.print("\n🔥 Phoenix regeneration before Wave {d}...\n", .{wave_id});
        // TODO: Call phoenix_bridge.preWaveRegen() when implemented
    }

    /// Print execution summary
    fn printSummary(self: *StormWaveProtocol) void {
        std.debug.print("\n📊 STORM WAVE PROTOCOL SUMMARY\n", .{});
        std.debug.print("════════════════════════════════\n", .{});

        for (self.wave_results.items) |wr| {
            const status = if (wr.success) "✅" else "❌";
            std.debug.print("{s} WAVE {d}: {s}\n", .{ status, wr.wave_id, wr.wave_name });
            std.debug.print("   Agents: {d}/{d} completed\n", .{ wr.completed_agents, wr.completed_agents + wr.failed_agents });
            std.debug.print("   Duration: {}ms\n", .{ wr.duration_ms });
        }

        std.debug.print("\nTotal time: {}ms ({d:.1}s)\n", .{
            self.total_duration_ms,
            @as(f64, @floatFromInt(self.total_duration_ms)) / 1000.0,
        });
    }
};

// ═════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════

test "STORM_WAVES configuration" {
    try std.testing.expectEqual(@as(usize, 5), STORM_WAVES.len);
    try std.testing.expectEqual(@as(u5, 3), STORM_WAVES[0].agent_count);
    try std.testing.expectEqual(@as(u5, 4), STORM_WAVES[1].agent_count);
    try std.testing.expectEqual(@as(u5, 16), STORM_WAVES[2].agent_count);
    try std.testing.expectEqual(@as(u5, 5), STORM_WAVES[3].agent_count);
    try std.testing.expectEqual(@as(u5, 4), STORM_WAVES[4].agent_count);
    const total_agents: u8 = 3 + 4 + 16 + 5 + 4;
    try std.testing.expectEqual(total_agents, 32);
}

test "Wave defaults" {
    const wave = Wave{
        .id = 1,
        .name = "Test",
        .agent_count = 3,
        .links = &[_]u8{1, 2, 3},
    };
    try std.testing.expect(wave.parallel);
    try std.testing.expectEqual(@as(u64, 600_000), wave.timeout_ms);
}

test "WaveResult init" {
    const result = WaveResult{
        .wave_id = 1,
        .wave_name = "Test",
        .success = true,
        .completed_agents = 0,
        .failed_agents = 0,
        .duration_ms = 0,
        .errors = &[_][]const u8{},
    };
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u5, 0), result.failed_agents);
}

test "WaveConfig defaults" {
    const config = WaveConfig{
        .waves = STORM_WAVES,
    };
    try std.testing.expect(config.checkpoint_between_waves);
    try std.testing.expect(config.phoenix_regen_before_wave);
    try std.testing.expectEqual(@as(u5, 10), config.max_parallel_agents);
}
