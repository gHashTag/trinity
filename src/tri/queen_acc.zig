// @origin(manual) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN ACC (Anterior Cingulate Cortex) — Conflict Monitoring
// ═══════════════════════════════════════════════════════════════════════════════
// S³AI Brain Module — Conflict detection, error monitoring, cognitive control
// Neuro: Conflict monitoring, error detection, competition resolution
// Trinity: Detect conflicting decisions from DLPFC, resolve action conflicts
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");
const basal_ganglia = @import("basal_ganglia.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONFLICT TYPES — What kind of conflict is this?
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConflictKind = enum {
    /// Actions cannot run together (mutually exclusive)
    mutual_exclusion,
    /// One action must precede the other (sequential dependency)
    sequential,
    /// Competing for the same resource
    resource_contention,
    /// Different actions with same goal (redundant)
    redundancy,
    /// Unknown conflict type
    unknown,
};

pub const Conflict = struct {
    kind: ConflictKind,
    action1: qt.ActionKind,
    action2: qt.ActionKind,
    reason: []const u8,
    severity: Severity = .medium,

    pub const Severity = enum(u8) {
        low = 0, // Can run concurrently with caution
        medium = 1, // Should suppress one
        high = 2, // Must suppress one
    };

    /// Format conflict as string
    pub fn format(self: *const Conflict, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf, "{s} <-> {s}: {s}", .{
            self.action1.label(),
            self.action2.label(),
            self.reason,
        }) catch buf[0..0];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONFLICT RULES — Predefined conflict patterns
// ═══════════════════════════════════════════════════════════════════════════════

const ConflictRule = struct {
    action1: qt.ActionKind,
    action2: qt.ActionKind,
    kind: ConflictKind,
    reason: []const u8,
    severity: Conflict.Severity = .medium,
};

/// Predefined conflict rules between actions
const CONFLICT_RULES = [_]ConflictRule{
    // Cloud operations: spawn vs kill (mutually exclusive)
    .{
        .action1 = .cloud_spawn,
        .action2 = .cloud_kill,
        .kind = .mutual_exclusion,
        .reason = "Cannot create and destroy containers simultaneously",
        .severity = .high,
    },
    .{
        .action1 = .cloud_spawn,
        .action2 = .cloud_cleanup,
        .kind = .mutual_exclusion,
        .reason = "Cannot spawn during cleanup",
        .severity = .high,
    },

    // Farm operations: recycle vs status (state modification)
    .{
        .action1 = .farm_recycle,
        .action2 = .farm_status,
        .kind = .resource_contention,
        .reason = "Recycle changes farm state, status would be inconsistent",
        .severity = .medium,
    },
    .{
        .action1 = .farm_recycle,
        .action2 = .farm_evolve_step,
        .kind = .mutual_exclusion,
        .reason = "Cannot recycle and evolve simultaneously",
        .severity = .high,
    },

    // Git operations: sequential dependency
    .{
        .action1 = .git_push,
        .action2 = .git_commit_state,
        .kind = .sequential,
        .reason = "Push requires commit first",
        .severity = .high,
    },

    // Doctor operations: redundancy
    .{
        .action1 = .doctor_quick,
        .action2 = .doctor_heal,
        .kind = .redundancy,
        .reason = "Both fix build, pick one",
        .severity = .low,
    },

    // Swarm operations
    .{
        .action1 = .swarm_decompose,
        .action2 = .cloud_spawn,
        .kind = .mutual_exclusion,
        .reason = "Cannot decompose swarm while spawning",
        .severity = .high,
    },

    // Arena operations
    .{
        .action1 = .arena_battle,
        .action2 = .farm_recycle,
        .kind = .resource_contention,
        .reason = "Arena and farm compete for resources",
        .severity = .medium,
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONFLICT DETECTION — Find conflicts between actions
// ═══════════════════════════════════════════════════════════════════════════════

/// Detect all conflicts between candidates
pub fn detectConflicts(
    allocator: Allocator,
    candidates: []const basal_ganglia.ActionCandidate,
) ![]Conflict {
    var conflicts = std.ArrayListAligned(Conflict, null){};
    try conflicts.ensureTotalCapacity(allocator, candidates.len);

    // Check predefined rules
    for (candidates, 0..) |c1, i| {
        for (candidates[i + 1 ..]) |c2| {
            // Check if this pair matches any rule
            for (CONFLICT_RULES) |rule| {
                const match = (rule.action1 == c1.kind and rule.action2 == c2.kind) or
                    (rule.action1 == c2.kind and rule.action2 == c1.kind);
                if (match) {
                    try conflicts.append(allocator, .{
                        .kind = rule.kind,
                        .action1 = c1.kind,
                        .action2 = c2.kind,
                        .reason = rule.reason,
                        .severity = rule.severity,
                    });
                }
            }

            // Check for resource contention (dangerous operations)
            if (isDangerous(c1.kind) and isDangerous(c2.kind)) {
                // Two dangerous operations -> resource contention
                try conflicts.append(allocator, .{
                    .kind = .resource_contention,
                    .action1 = c1.kind,
                    .action2 = c2.kind,
                    .reason = "Multiple dangerous operations compete for resources",
                    .severity = .high,
                });
            }
        }
    }

    return conflicts.toOwnedSlice(allocator);
}

/// Check if an action should be suppressed given the selected action
pub fn shouldSuppress(
    action: qt.ActionKind,
    selected: qt.ActionKind,
    conflicts: []const Conflict,
) bool {
    for (conflicts) |conflict| {
        if (conflict.action1 == selected and conflict.action2 == action) {
            return conflict.severity != .low;
        }
        if (conflict.action2 == selected and conflict.action1 == action) {
            return conflict.severity != .low;
        }
    }
    return false;
}

/// Suppress conflicting actions in the candidate list
pub fn suppressConflicting(
    candidates: []basal_ganglia.ActionCandidate,
    selected: qt.ActionKind,
) !void {
    // Build conflict list for selected action
    var conflicts_buf: [32]Conflict = undefined;
    var conflicts_len: usize = 0;

    for (CONFLICT_RULES) |rule| {
        if (rule.action1 == selected or rule.action2 == selected) {
            conflicts_buf[conflicts_len] = .{
                .kind = rule.kind,
                .action1 = rule.action1,
                .action2 = rule.action2,
                .reason = rule.reason,
                .severity = rule.severity,
            };
            conflicts_len += 1;
            if (conflicts_len >= conflicts_buf.len) break;
        }
    }

    // Suppress conflicting candidates
    for (candidates) |*c| {
        if (c.kind == selected) continue; // Don't suppress selected
        if (shouldSuppress(c.kind, selected, conflicts_buf[0..conflicts_len])) {
            c.suppressed = true;
        }
    }

    // Also suppress other dangerous operations
    if (isDangerous(selected)) {
        for (candidates) |*c| {
            if (c.kind == selected) continue;
            if (isDangerous(c.kind) and !c.suppressed) {
                c.suppressed = true;
            }
        }
    }
}

/// Check if action is dangerous (Level 2)
fn isDangerous(action: qt.ActionKind) bool {
    // Level 2 actions are farm_recycle (22) and above
    return @intFromEnum(action) >= @intFromEnum(qt.ActionKind.farm_recycle);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ERROR MONITORING — Detect error patterns
// ═══════════════════════════════════════════════════════════════════════════════

pub const ErrorSeverity = enum {
    info,
    warning,
    err,
    critical,
};

pub const ErrorSignal = struct {
    source: []const u8,
    message: []const u8,
    severity: ErrorSeverity = .warning,
    timestamp: i64,
};

pub const ErrorMonitor = struct {
    errors: std.ArrayListAligned(ErrorSignal, null),
    allocator: Allocator,
    last_check: i64,

    pub fn init(allocator: Allocator) ErrorMonitor {
        return .{
            .errors = std.ArrayListAligned(ErrorSignal, null){},
            .allocator = allocator,
            .last_check = 0,
        };
    }

    pub fn deinit(self: *ErrorMonitor) void {
        self.errors.deinit(self.allocator);
    }

    /// Add error signal
    pub fn addError(
        self: *ErrorMonitor,
        source: []const u8,
        message: []const u8,
        severity: ErrorSeverity,
    ) !void {
        try self.errors.append(self.allocator, .{
            .source = source,
            .message = message,
            .severity = severity,
            .timestamp = std.time.timestamp(),
        });
    }

    /// Get error count by severity
    pub fn countBySeverity(self: *const ErrorMonitor, severity: ErrorSeverity) usize {
        var count: usize = 0;
        for (self.errors.items) |err| {
            if (err.severity == severity) count += 1;
        }
        return count;
    }

    /// Check if error threshold exceeded
    pub fn thresholdExceeded(self: *const ErrorMonitor) bool {
        const critical_count = self.countBySeverity(.critical);
        const error_count = self.countBySeverity(.err);
        return critical_count > 0 or error_count >= 3;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COGNITIVE CONTROL — Modulate action selection based on state
// ═══════════════════════════════════════════════════════════════════════════════

pub const ControlSignal = struct {
    inhibit: bool = false, // Inhibit action execution
    boost: bool = false, // Boost action priority
    reason: []const u8 = "", // Reason for control signal
};

/// Generate control signals based on conflicts and errors
pub fn generateControlSignals(
    allocator: Allocator,
    candidates: []const basal_ganglia.ActionCandidate,
    error_monitor: *const ErrorMonitor,
) ![]ControlSignal {
    var signals = std.ArrayListAligned(ControlSignal, null){};
    try signals.ensureTotalCapacity(allocator, candidates.len);

    // Detect conflicts
    const conflicts = try detectConflicts(std.testing.allocator, candidates);
    defer std.testing.allocator.free(conflicts);

    // Generate control signal for each candidate
    for (candidates) |c| {
        var signal = ControlSignal{};

        // Check if candidate has high-severity conflicts
        for (conflicts) |conf| {
            if (conf.action1 == c.kind or conf.action2 == c.kind) {
                if (conf.severity == .high) {
                    signal.inhibit = true;
                    signal.reason = conf.reason;
                    break;
                }
            }
        }

        // If error threshold exceeded, inhibit dangerous actions
        if (error_monitor.thresholdExceeded() and isDangerous(c.kind)) {
            signal.inhibit = true;
            signal.reason = "Error threshold exceeded, inhibiting dangerous actions";
        }

        // Boost critical urgency actions during errors
        if (error_monitor.thresholdExceeded() and c.urgency == .critical) {
            signal.boost = true;
            signal.reason = "Error recovery mode: boosting critical actions";
        }

        try signals.append(allocator, signal);
    }

    return signals.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn health() CellHealth {
    return CellHealth{
        .status = .healthy,
        .cycle = 0,
        .last_check = std.time.timestamp(),
    };
}

pub const CellHealth = struct {
    status: Status = .healthy,
    cycle: u32 = 0,
    last_check: i64 = 0,

    pub const Status = enum {
        healthy,
        weak,
        broken,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ACC — detectConflicts finds mutual exclusion" {
    const candidates = [_]basal_ganglia.ActionCandidate{
        .{ .kind = .cloud_spawn, .urgency = .normal },
        .{ .kind = .cloud_kill, .urgency = .normal },
    };

    const conflicts = try detectConflicts(std.testing.allocator, &candidates);
    defer std.testing.allocator.free(conflicts);

    try std.testing.expect(conflicts.len > 0);
    try std.testing.expectEqual(ConflictKind.mutual_exclusion, conflicts[0].kind);
}

test "ACC — detectConflicts finds sequential dependency" {
    const candidates = [_]basal_ganglia.ActionCandidate{
        .{ .kind = .git_commit_state, .urgency = .normal },
        .{ .kind = .git_push, .urgency = .normal },
    };

    const conflicts = try detectConflicts(std.testing.allocator, &candidates);
    defer std.testing.allocator.free(conflicts);

    try std.testing.expect(conflicts.len > 0);
    try std.testing.expectEqual(ConflictKind.sequential, conflicts[0].kind);
}

test "ACC — shouldSuppress works correctly" {
    const conflicts = [_]Conflict{
        .{
            .kind = .mutual_exclusion,
            .action1 = .cloud_spawn,
            .action2 = .cloud_kill,
            .reason = "test",
            .severity = .high,
        },
    };

    try std.testing.expect(shouldSuppress(.cloud_kill, .cloud_spawn, &conflicts));
    try std.testing.expect(shouldSuppress(.cloud_spawn, .cloud_kill, &conflicts));
}

test "ACC — suppressConflicting marks candidates" {
    var candidates = [_]basal_ganglia.ActionCandidate{
        .{ .kind = .cloud_spawn, .urgency = .normal, .suppressed = false },
        .{ .kind = .cloud_kill, .urgency = .normal, .suppressed = false },
        .{ .kind = .farm_status, .urgency = .normal, .suppressed = false },
    };

    try suppressConflicting(&candidates, .cloud_spawn);

    // cloud_kill should be suppressed
    try std.testing.expect(candidates[1].suppressed);
    // farm_status should not be suppressed
    try std.testing.expect(!candidates[2].suppressed);
}

test "ACC — ErrorMonitor tracks errors" {
    var monitor = ErrorMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    try monitor.addError("test", "error1", .err);
    try monitor.addError("test", "error2", .warning);

    try std.testing.expectEqual(@as(usize, 1), monitor.countBySeverity(.err));
    try std.testing.expectEqual(@as(usize, 1), monitor.countBySeverity(.warning));
}

test "ACC — ErrorMonitor threshold check" {
    var monitor = ErrorMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    try std.testing.expect(!monitor.thresholdExceeded());

    try monitor.addError("test", "critical", .critical);
    try std.testing.expect(monitor.thresholdExceeded());
}

test "ACC — generateControlSignals inhibits conflicting" {
    const candidates = [_]basal_ganglia.ActionCandidate{
        .{ .kind = .cloud_spawn, .urgency = .normal },
        .{ .kind = .cloud_kill, .urgency = .normal },
    };

    var monitor = ErrorMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    const signals = try generateControlSignals(std.testing.allocator, &candidates, &monitor);
    defer std.testing.allocator.free(signals);

    // At least one signal should inhibit
    var has_inhibit = false;
    for (signals) |s| {
        if (s.inhibit) has_inhibit = true;
    }
    try std.testing.expect(has_inhibit);
}

test "ACC — Conflict format works" {
    const conflict = Conflict{
        .kind = .mutual_exclusion,
        .action1 = .cloud_spawn,
        .action2 = .cloud_kill,
        .reason = "test reason",
    };

    var buf: [256]u8 = undefined;
    const formatted = conflict.format(&buf);

    try std.testing.expect(formatted.len > 0);
}

test "ACC — isDangerous correctly identifies Level 2 actions" {
    try std.testing.expect(isDangerous(.farm_recycle));
    try std.testing.expect(isDangerous(.cloud_kill));
    try std.testing.expect(!isDangerous(.farm_status));
    try std.testing.expect(!isDangerous(.doctor_scan));
}

test "ACC — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}
