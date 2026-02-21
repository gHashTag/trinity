//! μ (Mu) Tracker — Intelligence Gain Monitoring
//!
//! Real-time tracking of AGENT MU intelligence growth.
//! μ = 0.0382 per successful fix (sacred constant = 1/φ²/10)
//!
//! Intelligence projection:
//!   - After 100 fixes: ×47 multiplier
//!   - After 1000 fixes: ×2.1×10^15 multiplier

const std = @import("std");
const ArrayListManaged = std.array_list.Managed;

/// Sacred μ constant: intelligence gain per successful fix
/// μ = 1/φ²/10 where φ = (1 + √5) / 2
pub const SACRED_MU: f64 = 0.0382;

/// φ (golden ratio)
pub const PHI: f64 = 1.6180339887498948482;

/// L(10) = φ¹⁰ + 1/φ¹⁰ = 123 (10th Lucas number)
pub const LUCAS_10: f64 = 123.0;

/// v8.16: Calculate adaptive μ based on success rate and sacred math
/// Formula: μ = 0.0382 × φ^(success_rate - 0.5) × (L(10) / 123)
/// - success_rate = 0.5 → μ = 0.0382 (baseline)
/// - success_rate > 0.5 → μ increases (faster evolution)
/// - success_rate < 0.5 → μ decreases (conservative)
pub fn calculateAdaptiveMu(success_rate: f64) f64 {
    const BASE_MU: f64 = 0.0382;
    const phi_adjustment = std.math.pow(f64, PHI, success_rate - 0.5);
    const lucas_normalization = LUCAS_10 / 123.0; // = 1.0 (identity, future-proof)
    return BASE_MU * phi_adjustment * lucas_normalization;
}

/// Clamp μ to safe range to prevent instability
pub fn clampMu(mu: f64) f64 {
    return @max(0.01, @min(0.1, mu));
}

/// Format a UNIX timestamp as ISO 8601 string into a buffer
fn formatTimestampBuf(buf: []u8, ts: i64) []const u8 {
    const epoch: std.time.epoch.EpochSeconds = .{ .secs = @intCast(ts) };
    const epoch_day = epoch.getEpochDay();
    const day_seconds = epoch.getDaySeconds();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    return std.fmt.bufPrint(buf, "{d:04}-{d:02}-{d:02}T{d:02}:{d:02}:{d:02}Z", .{
        year_day.year,
        @intFromEnum(month_day.month),
        month_day.day_index + 1,
        day_seconds.getHoursIntoDay(),
        day_seconds.getMinutesIntoHour(),
        day_seconds.getSecondsIntoMinute(),
    }) catch "0000-00-00T00:00:00Z";
}

/// Intelligence metrics at a point in time
pub const IntelligenceSnapshot = struct {
    timestamp: i64,
    total_fixes: usize,
    successful_fixes: usize,
    failed_fixes: usize,
    current_mu: f64,
    intelligence_multiplier: f64,
    success_rate: f64,

    pub fn init(
        timestamp: i64,
        total_fixes: usize,
        successful_fixes: usize,
        failed_fixes: usize,
    ) IntelligenceSnapshot {
        const success_rate = if (total_fixes > 0)
            @as(f64, @floatFromInt(successful_fixes)) / @as(f64, @floatFromInt(total_fixes))
        else
            0.0;

        const current_mu = @as(f64, @floatFromInt(successful_fixes)) * SACRED_MU;
        const intelligence_multiplier = std.math.exp(current_mu);

        return IntelligenceSnapshot{
            .timestamp = timestamp,
            .total_fixes = total_fixes,
            .successful_fixes = successful_fixes,
            .failed_fixes = failed_fixes,
            .current_mu = current_mu,
            .intelligence_multiplier = intelligence_multiplier,
            .success_rate = success_rate,
        };
    }

    pub fn format(self: *const IntelligenceSnapshot, writer: anytype) !void {
        var ts_buf: [32]u8 = undefined;
        const ts_str = formatTimestampBuf(&ts_buf, self.timestamp);
        try writer.print(
            \\## Intelligence Snapshot
            \\- Timestamp: {s}
            \\- Total Fixes: {d}
            \\- Successful: {d} ({d:.1}%)
            \\- Failed: {d}
            \\- Current μ: {d:.4}
            \\- Intelligence Multiplier: ×{d:.2}
            \\
        , .{
            ts_str,
            self.total_fixes,
            self.successful_fixes,
            self.success_rate * 100.0,
            self.failed_fixes,
            self.current_mu,
            self.intelligence_multiplier,
        });
    }
};

/// Fix record for tracking individual fixes
pub const FixRecord = struct {
    timestamp: i64,
    fix_type: []const u8,
    success: bool,
    error_message: []const u8,
    duration_ms: u64,
    confidence: f32,

    pub fn init(
        allocator: std.mem.Allocator,
        fix_type: []const u8,
        success: bool,
        error_message: []const u8,
        duration_ms: u64,
        confidence: f32,
    ) !FixRecord {
        return FixRecord{
            .timestamp = std.time.timestamp(),
            .fix_type = try allocator.dupe(u8, fix_type),
            .success = success,
            .error_message = try allocator.dupe(u8, error_message),
            .duration_ms = duration_ms,
            .confidence = confidence,
        };
    }

    pub fn deinit(self: *FixRecord, allocator: std.mem.Allocator) void {
        allocator.free(self.fix_type);
        allocator.free(self.error_message);
    }
};

/// Real-time μ tracker
pub const MuTracker = struct {
    fixes: ArrayListManaged(FixRecord),
    snapshots: ArrayListManaged(IntelligenceSnapshot),
    total_fixes: usize,
    successful_fixes: usize,
    failed_fixes: usize,
    start_time: i64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !MuTracker {
        return MuTracker{
            .fixes = ArrayListManaged(FixRecord).init(allocator),
            .snapshots = ArrayListManaged(IntelligenceSnapshot).init(allocator),
            .total_fixes = 0,
            .successful_fixes = 0,
            .failed_fixes = 0,
            .start_time = std.time.timestamp(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MuTracker) void {
        for (self.fixes.items) |*fix| {
            fix.deinit(self.allocator);
        }
        self.fixes.deinit();
        self.snapshots.deinit();
    }

    /// Record a fix attempt
    pub fn recordFix(
        self: *MuTracker,
        fix_type: []const u8,
        success: bool,
        error_message: []const u8,
        duration_ms: u64,
        confidence: f32,
    ) !void {
        const record = try FixRecord.init(
            self.allocator,
            fix_type,
            success,
            error_message,
            duration_ms,
            confidence,
        );
        try self.fixes.append(record);

        self.total_fixes += 1;
        if (success) {
            self.successful_fixes += 1;
        } else {
            self.failed_fixes += 1;
        }

        // Create snapshot after each fix
        try self.createSnapshot();
    }

    /// Create intelligence snapshot
    pub fn createSnapshot(self: *MuTracker) !void {
        const snapshot = IntelligenceSnapshot.init(
            std.time.timestamp(),
            self.total_fixes,
            self.successful_fixes,
            self.failed_fixes,
        );
        try self.snapshots.append(snapshot);
    }

    /// Get current intelligence multiplier
    pub fn getIntelligenceMultiplier(self: *const MuTracker) f64 {
        const current_mu = @as(f64, @floatFromInt(self.successful_fixes)) * SACRED_MU;
        return std.math.exp(current_mu);
    }

    /// Get current μ value
    pub fn getCurrentMu(self: *const MuTracker) f64 {
        return @as(f64, @floatFromInt(self.successful_fixes)) * SACRED_MU;
    }

    /// Project intelligence for N future fixes
    pub fn projectIntelligence(self: *const MuTracker, additional_fixes: usize) struct {
        projected_mu: f64,
        projected_multiplier: f64,
        gain_from_current: f64,
    } {
        const projected_successful = self.successful_fixes + additional_fixes;
        const projected_mu = @as(f64, @floatFromInt(projected_successful)) * SACRED_MU;
        const projected_multiplier = std.math.exp(projected_mu);
        const current_multiplier = self.getIntelligenceMultiplier();

        return .{
            .projected_mu = projected_mu,
            .projected_multiplier = projected_multiplier,
            .gain_from_current = projected_multiplier / current_multiplier,
        };
    }

    /// Calculate fixes needed to reach target multiplier
    pub fn fixesForMultiplier(self: *const MuTracker, target_multiplier: f64) usize {
        const target_mu = std.math.log(target_multiplier);
        const needed_mu = target_mu - self.getCurrentMu();
        const needed_fixes = @ceil(needed_mu / SACRED_MU);
        return @max(0, @as(usize, @intFromFloat(needed_fixes)));
    }

    /// Get success rate
    pub fn getSuccessRate(self: *const MuTracker) f64 {
        if (self.total_fixes == 0) return 0.0;
        return @as(f64, @floatFromInt(self.successful_fixes)) / @as(f64, @floatFromInt(self.total_fixes));
    }

    /// Get fixes by type
    pub fn getFixesByType(self: *const MuTracker, fix_type: []const u8) usize {
        var count: usize = 0;
        for (self.fixes.items) |fix| {
            if (std.mem.eql(u8, fix.fix_type, fix_type)) {
                count += 1;
            }
        }
        return count;
    }

    /// Get average confidence score
    pub fn getAverageConfidence(self: *const MuTracker) f32 {
        if (self.fixes.items.len == 0) return 0.0;

        var sum: f32 = 0.0;
        for (self.fixes.items) |fix| {
            sum += fix.confidence;
        }
        return sum / @as(f32, @floatFromInt(self.fixes.items.len));
    }

    /// Calculate uptime in seconds
    pub fn getUptimeSeconds(self: *const MuTracker) i64 {
        return std.time.timestamp() - self.start_time;
    }

    /// Calculate fixes per second
    pub fn getFixesPerSecond(self: *const MuTracker) f64 {
        const uptime = @as(f64, @floatFromInt(self.getUptimeSeconds()));
        if (uptime == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_fixes)) / uptime;
    }

    /// v8.16: Get intelligence history for curve visualization
    /// Returns up to count snapshots in reverse chronological order (newest first)
    pub fn getIntelligenceHistory(self: *const MuTracker, allocator: std.mem.Allocator, count: usize) ![]const IntelligenceSnapshot {
        const start = if (self.snapshots.items.len > count)
            self.snapshots.items.len - count
        else
            0;

        const result = try allocator.alloc(IntelligenceSnapshot, self.snapshots.items.len - start);
        @memcpy(result, self.snapshots.items[start..]);

        // Reverse to newest-first order
        std.mem.reverse(IntelligenceSnapshot, result);
        return result;
    }

    /// Export stats as markdown
    pub fn exportMarkdown(self: *const MuTracker, writer: anytype) !void {
        try writer.print(
            \\# AGENT PHI Report — μ Intelligence Tracking
            \\
            \\## Current Status
            \\- **Timestamp**: {s}
            \\- **Uptime**: {d}s ({d:.1} min)
            \\- **Total Fixes**: {d}
            \\- **Successful**: {d}
            \\- **Failed**: {d}
            \\- **Success Rate**: {d:.1}%
            \\- **Fixes/Second**: {d:.2}
            \\
            \\## Intelligence Metrics
            \\- **Current μ**: {d:.4}
            \\- **Intelligence Multiplier**: ×{d:.4}
            \\- **Sacred Constant**: μ = {d:.4} (1/φ²/10)
            \\
            \\## Projections
            \\
        , .{
            blk: {
                var buf: [32]u8 = undefined;
                break :blk formatTimestampBuf(&buf, std.time.timestamp());
            },
            self.getUptimeSeconds(),
            @as(f64, @floatFromInt(self.getUptimeSeconds())) / 60.0,
            self.total_fixes,
            self.successful_fixes,
            self.failed_fixes,
            self.getSuccessRate() * 100.0,
            self.getFixesPerSecond(),
            self.getCurrentMu(),
            self.getIntelligenceMultiplier(),
            SACRED_MU,
        });

        // Projections for 10, 100, 1000 fixes
        for ([_]usize{ 10, 100, 1000 }) |n| {
            const proj = self.projectIntelligence(n);
            try writer.print(
                \\### +{d} Fixes
                \\- Projected μ: {d:.4}
                \\- Projected Multiplier: ×{e:.2}
                \\- Gain from Current: ×{d:.2}
                \\
            , .{ n, proj.projected_mu, proj.projected_multiplier, proj.gain_from_current });
        }

        // Fix type breakdown
        try writer.writeAll("\n## Fix Type Breakdown\n\n");
        var seen_types = ArrayListManaged([]const u8).init(self.allocator);
        defer {
            for (seen_types.items) |t| {
                self.allocator.free(t);
            }
            seen_types.deinit();
        }

        for (self.fixes.items) |fix| {
            var already_seen = false;
            for (seen_types.items) |t| {
                if (std.mem.eql(u8, t, fix.fix_type)) {
                    already_seen = true;
                    break;
                }
            }
            if (!already_seen) {
                try seen_types.append(try self.allocator.dupe(u8, fix.fix_type));
            }
        }

        for (seen_types.items) |fix_type| {
            const count = self.getFixesByType(fix_type);
            try writer.print("- **{s}**: {d} fixes\n", .{ fix_type, count });
        }

        try writer.writeAll(
            \\
            \\---
            \\*Generated by AGENT MU μ Tracker*
        );
    }
};

/// Global tracker instance (initialized once)
var global_tracker: ?MuTracker = null;
var global_init = false;

/// Get or create global tracker
pub fn getGlobalTracker() !*MuTracker {
    if (!global_init) {
        global_tracker = try MuTracker.init(std.heap.page_allocator);
        global_init = true;
    }
    return &global_tracker.?;
}

/// Record fix with global tracker
pub fn recordGlobalFix(
    fix_type: []const u8,
    success: bool,
    error_message: []const u8,
    duration_ms: u64,
    confidence: f32,
) !void {
    const tracker = try getGlobalTracker();
    try tracker.recordFix(fix_type, success, error_message, duration_ms, confidence);
}

test "IntelligenceSnapshot: calculation" {
    const snapshot = IntelligenceSnapshot.init(0, 100, 95, 5);

    try std.testing.expectEqual(@as(usize, 100), snapshot.total_fixes);
    try std.testing.expectEqual(@as(usize, 95), snapshot.successful_fixes);
    try std.testing.expectApproxEqRel(@as(f64, 0.95), snapshot.success_rate, 0.01);

    // μ = 95 * 0.0382 = 3.629
    try std.testing.expectApproxEqRel(@as(f64, 3.629), snapshot.current_mu, 0.01);

    // multiplier = e^3.629 ≈ 37.7
    try std.testing.expect(snapshot.intelligence_multiplier > 30.0);
    try std.testing.expect(snapshot.intelligence_multiplier < 50.0);
}

test "MuTracker: basic tracking" {
    const allocator = std.testing.allocator;
    var tracker = try MuTracker.init(allocator);
    defer tracker.deinit();

    // Record 10 successful fixes
    for (0..10) |i| {
        try tracker.recordFix("TYPE_FIX", true, "test error", 100, 0.9);
        _ = i;
    }

    try std.testing.expectEqual(@as(usize, 10), tracker.total_fixes);
    try std.testing.expectEqual(@as(usize, 10), tracker.successful_fixes);
    try std.testing.expectEqual(@as(usize, 0), tracker.failed_fixes);

    // μ = 10 * 0.0382 = 0.382
    const mu = tracker.getCurrentMu();
    try std.testing.expectApproxEqRel(@as(f64, 0.382), mu, 0.01);
}

test "MuTracker: projection" {
    const allocator = std.testing.allocator;
    var tracker = try MuTracker.init(allocator);
    defer tracker.deinit();

    // Start with 50 successful fixes
    for (0..50) |_| {
        try tracker.recordFix("TYPE_FIX", true, "test", 100, 1.0);
    }

    // Project to 100 total fixes
    const proj = tracker.projectIntelligence(50);

    // Should gain significant intelligence
    try std.testing.expect(proj.gain_from_current > 4.0);
    try std.testing.expect(proj.gain_from_current < 10.0);
}

test "Sacred constants" {
    // Verify sacred constant: μ = 1/φ²/10
    const expected_mu = 1.0 / (PHI * PHI) / 10.0;
    try std.testing.expectApproxEqRel(SACRED_MU, expected_mu, 0.0001);

    // Verify φ² + 1/φ² = 3 (Trinity Identity)
    const phi_squared = PHI * PHI;
    const inv_phi_squared = 1.0 / (PHI * PHI);
    try std.testing.expectApproxEqRel(@as(f64, 3.0), phi_squared + inv_phi_squared, 0.0001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v8.16: Adaptive μ Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "v8.16: Adaptive μ calculation" {
    // Baseline: success_rate = 0.5 → μ = 0.0382
    const mu_50 = calculateAdaptiveMu(0.5);
    try std.testing.expectApproxEqRel(@as(f64, 0.0382), mu_50, 0.001);

    // High success: success_rate = 0.8 → μ > baseline
    const mu_80 = calculateAdaptiveMu(0.8);
    try std.testing.expect(mu_80 > mu_50);

    // Low success: success_rate = 0.3 → μ < baseline
    const mu_30 = calculateAdaptiveMu(0.3);
    try std.testing.expect(mu_30 < mu_50);

    // Verify ordering: high > baseline > low
    try std.testing.expect(mu_80 > mu_30);
}

test "v8.16: μ clamping" {
    // Test that extreme values are clamped to [0.01, 0.1]
    const clamped_low = clampMu(0.001);
    try std.testing.expectApproxEqRel(@as(f64, 0.01), clamped_low, 0.001);

    const clamped_high = clampMu(1.0);
    try std.testing.expectApproxEqRel(@as(f64, 0.1), clamped_high, 0.001);

    // Normal value passes through
    const normal = clampMu(0.0382);
    try std.testing.expectApproxEqRel(@as(f64, 0.0382), normal, 0.001);
}

test "v8.16: Intelligence history retrieval" {
    const allocator = std.testing.allocator;
    var tracker = try MuTracker.init(allocator);
    defer tracker.deinit();

    // Record some fixes to create snapshots
    for (0..5) |_| {
        try tracker.recordFix("TYPE_FIX", true, "test", 100, 0.9);
    }

    // Get last 3 snapshots
    const history = try tracker.getIntelligenceHistory(allocator, 3);
    defer allocator.free(history);

    try std.testing.expectEqual(@as(usize, 3), history.len);

    // Should be in newest-first order
    try std.testing.expect(history[0].timestamp >= history[1].timestamp);
    try std.testing.expect(history[1].timestamp >= history[2].timestamp);
}
