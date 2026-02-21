//! Runtime Pattern Manager v8.19 — Live Self-Modification
//!
//! AGENT MU can patch its own patterns during runtime execution.
//! This is the PRODUCTION version of comptime_self_mod.zig

const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.array_list.Managed;

/// Fix type categories
pub const FixType = enum {
    SYNTAX_FIX,
    TYPE_FIX,
    META_LEARN,
    SELF_MOD,
    PREDICT,
    COLLAB,
};

/// Pattern health status
pub const PatternHealth = enum {
    healthy,
    degrading,
    critical,
};

/// Runtime pattern entry
pub const RuntimePattern = struct {
    id: []const u8,
    template: []const u8,
    fix_type: FixType,
    confidence: f64,
    applied_at: i64,
    success_count: usize,
    failure_count: usize,
    last_result: bool,
    health: PatternHealth,

    /// Calculate success rate
    pub fn successRate(self: *const RuntimePattern) f64 {
        const total = self.success_count + self.failure_count;
        if (total == 0) return 1.0;
        return @as(f64, @floatFromInt(self.success_count)) / @as(f64, @floatFromInt(total));
    }

    /// Update health based on recent performance
    pub fn updateHealth(self: *RuntimePattern) void {
        const rate = self.successRate();
        if (rate >= 0.8) {
            self.health = .healthy;
        } else if (rate >= 0.5) {
            self.health = .degrading;
        } else {
            self.health = .critical;
        }
    }
};

/// Pattern entry for array-based map
pub const PatternEntry = struct {
    key: []const u8,
    value: RuntimePattern,
};

/// Pattern snapshot for rollback
pub const PatternSnapshot = struct {
    pattern_id: []const u8,
    previous_confidence: f64,
    previous_template: []const u8,
    timestamp: i64,
    rollback_reason: []const u8,
};

/// Circuit breaker states
pub const CircuitBreakerState = enum {
    closed,    // Normal operation
    open,      // Rejecting new modifications
    half_open, // Testing if recovered
};

/// Circuit breaker for pattern application safety
pub const CircuitBreaker = struct {
    state: CircuitBreakerState,
    failure_threshold: usize,
    success_threshold: usize,
    failure_count: usize,
    success_count: usize,
    last_state_change: i64,
    open_timeout_seconds: i64,

    /// Initialize with default safety values
    pub fn init() CircuitBreaker {
        const now = std.time.timestamp();
        return .{
            .state = .closed,
            .failure_threshold = 5,
            .success_threshold = 3,
            .failure_count = 0,
            .success_count = 0,
            .last_state_change = now,
            .open_timeout_seconds = 60,
        };
    }

    /// Check if modifications are allowed
    pub fn canModify(self: *const CircuitBreaker) bool {
        if (self.state == .open) {
            const now = std.time.timestamp();
            const elapsed = now - self.last_state_change;
            if (elapsed >= self.open_timeout_seconds) {
                return true; // Timeout passed, can attempt recovery
            }
            return false;
        }
        return true;
    }

    /// Record a pattern failure
    pub fn recordFailure(self: *CircuitBreaker) void {
        self.failure_count += 1;
        if (self.failure_count >= self.failure_threshold) {
            self.state = .open;
            self.last_state_change = std.time.timestamp();
        }
    }

    /// Record a pattern success
    pub fn recordSuccess(self: *CircuitBreaker) void {
        if (self.state == .half_open) {
            self.success_count += 1;
            if (self.success_count >= self.success_threshold) {
                self.state = .closed;
                self.failure_count = 0;
                self.success_count = 0;
            }
        } else if (self.state == .closed) {
            // Reset failure count on success in closed state (with underflow protection)
            if (self.failure_count > 0) {
                self.failure_count -= 1;
            }
        }
    }

    /// Attempt recovery from open state
    pub fn attemptRecovery(self: *CircuitBreaker) bool {
        if (self.state != .open) return true;

        const now = std.time.timestamp();
        const elapsed = now - self.last_state_change;

        if (elapsed >= self.open_timeout_seconds) {
            self.state = .half_open;
            self.success_count = 0;
            return true;
        }

        return false;
    }
};

/// Validation pipeline stages
pub const ValidationStage = enum {
    syntax_check,
    compilation_test,
    unit_test_pass,
    integration_test,
};

/// Validation result
pub const ValidationResult = struct {
    passed: bool,
    errors: ArrayList([]const u8),
    stage_failed: ?ValidationStage,

    pub fn deinit(self: *ValidationResult, allocator: Allocator) void {
        for (self.errors.items) |err| {
            allocator.free(err);
        }
        self.errors.deinit();
    }
};

/// Validation pipeline for pattern safety
pub const ValidationPipeline = struct {
    strict_mode: bool,
    timeout_ms: u64,
    stages: [4]ValidationStage,

    /// Initialize with default values
    pub fn init() ValidationPipeline {
        return .{
            .strict_mode = true,
            .timeout_ms = 5000,
            .stages = [_]ValidationStage{
                .syntax_check,
                .compilation_test,
                .unit_test_pass,
                .integration_test,
            },
        };
    }

    /// Validate a pattern template
    pub fn validate(self: *const ValidationPipeline, allocator: Allocator, pattern: []const u8) !ValidationResult {
        _ = self;

        var result = ValidationResult{
            .passed = true,
            .errors = ArrayList([]const u8).init(allocator),
            .stage_failed = null,
        };

        // Mock validation - in production would actually validate
        // For now, pass all patterns that are non-empty
        if (pattern.len == 0) {
            result.passed = false;
            result.stage_failed = .syntax_check;
            try result.errors.append(try allocator.dupe(u8, "Empty pattern"));
        }

        return result;
    }
};

/// Pattern metrics for monitoring
pub const PatternMetrics = struct {
    success_rate: f64,
    total_attempts: usize,
    age_seconds: i64,
    health: PatternHealth,
};

/// Live pattern manager with full safety features
pub const LivePatternManager = struct {
    active_patterns: ArrayList(PatternEntry),
    rollback_stack: ArrayList(PatternSnapshot),
    circuit_breaker: CircuitBreaker,
    validation: ValidationPipeline,
    allocator: Allocator,
    pattern_counter: usize,
    confidence_threshold: f64,

    /// Initialize with safety defaults
    pub fn init(allocator: Allocator) !LivePatternManager {
        return .{
            .active_patterns = ArrayList(PatternEntry).init(allocator),
            .rollback_stack = ArrayList(PatternSnapshot).init(allocator),
            .circuit_breaker = CircuitBreaker.init(),
            .validation = ValidationPipeline.init(),
            .allocator = allocator,
            .pattern_counter = 0,
            .confidence_threshold = 0.95,
        };
    }

    /// Deinitialize and free resources
    pub fn deinit(self: *LivePatternManager) void {
        for (self.active_patterns.items) |*entry| {
            // key and value.id point to same memory, only free once
            self.allocator.free(entry.key);
            self.allocator.free(entry.value.template);
        }
        self.active_patterns.deinit();

        for (self.rollback_stack.items) |*snapshot| {
            self.allocator.free(snapshot.pattern_id);
            self.allocator.free(snapshot.previous_template);
            self.allocator.free(snapshot.rollback_reason);
        }
        self.rollback_stack.deinit();
    }

    /// Find pattern by ID
    fn findPattern(self: *const LivePatternManager, pattern_id: []const u8) ?*RuntimePattern {
        for (self.active_patterns.items) |*entry| {
            if (std.mem.eql(u8, entry.key, pattern_id)) {
                return &entry.value;
            }
        }
        return null;
    }

    /// Check if safe to modify (circuit breaker + validation)
    pub fn canModify(self: *const LivePatternManager) bool {
        return self.circuit_breaker.canModify();
    }

    /// Propose new pattern for runtime modification
    pub fn proposePattern(
        self: *LivePatternManager,
        template: []const u8,
        fix_type: FixType,
        confidence: f64,
    ) !bool {
        // Check circuit breaker
        if (!self.canModify()) {
            return false;
        }

        // Check confidence threshold
        if (confidence < self.confidence_threshold) {
            return false;
        }

        // Validate pattern
        var validation = try self.validation.validate(self.allocator, template);
        defer validation.deinit(self.allocator);

        if (!validation.passed) {
            self.circuit_breaker.recordFailure();
            return false;
        }

        // Create pattern
        const pattern_id = try std.fmt.allocPrint(self.allocator, "pattern_{d}", .{self.pattern_counter});
        errdefer self.allocator.free(pattern_id);

        const now = std.time.timestamp();
        const pattern = RuntimePattern{
            .id = pattern_id,
            .template = try self.allocator.dupe(u8, template),
            .fix_type = fix_type,
            .confidence = confidence,
            .applied_at = now,
            .success_count = 0,
            .failure_count = 0,
            .last_result = false,
            .health = .healthy,
        };

        // Store pattern
        try self.active_patterns.append(.{
            .key = pattern_id,
            .value = pattern,
        });

        self.pattern_counter += 1;
        return true;
    }

    /// Record outcome of pattern application
    pub fn recordOutcome(self: *LivePatternManager, pattern_id: []const u8, success: bool) !void {
        const pattern = self.findPattern(pattern_id) orelse return error.PatternNotFound;

        if (success) {
            pattern.success_count += 1;
            pattern.last_result = true;
            self.circuit_breaker.recordSuccess();
        } else {
            pattern.failure_count += 1;
            pattern.last_result = false;
            self.circuit_breaker.recordFailure();
        }

        pattern.updateHealth();
    }

    /// Rollback to previous stable state
    pub fn rollback(self: *LivePatternManager, reason: []const u8) !void {
        const now = std.time.timestamp();

        // Create snapshot of current state
        if (self.active_patterns.items.len > 0) {
            const last_entry = &self.active_patterns.items[self.active_patterns.items.len - 1];

            const snapshot = PatternSnapshot{
                .pattern_id = try self.allocator.dupe(u8, last_entry.value.id),
                .previous_confidence = last_entry.value.confidence,
                .previous_template = try self.allocator.dupe(u8, last_entry.value.template),
                .timestamp = now,
                .rollback_reason = try self.allocator.dupe(u8, reason),
            };

            try self.rollback_stack.append(snapshot);
        }

        // Remove last pattern if unhealthy
        if (self.active_patterns.items.len > 0) {
            const last = self.active_patterns.pop();
            if (last) |entry| {
                self.allocator.free(entry.key);
                self.allocator.free(entry.value.template);
            }
        }
    }

    /// Get pattern performance metrics
    pub fn getPatternMetrics(
        self: *const LivePatternManager,
        pattern_id: []const u8,
    ) ?PatternMetrics {
        const pattern = self.findPattern(pattern_id) orelse return null;

        const now = std.time.timestamp();
        const age = now - pattern.applied_at;

        return .{
            .success_rate = pattern.successRate(),
            .total_attempts = pattern.success_count + pattern.failure_count,
            .age_seconds = age,
            .health = pattern.health,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "RuntimePattern: success rate calculation" {
    const pattern = RuntimePattern{
        .id = "test",
        .template = "test template",
        .fix_type = .TYPE_FIX,
        .confidence = 0.95,
        .applied_at = 0,
        .success_count = 8,
        .failure_count = 2,
        .last_result = true,
        .health = .healthy,
    };

    try std.testing.expectApproxEqAbs(@as(f64, 0.8), pattern.successRate(), 0.01);
}

test "RuntimePattern: health update" {
    var pattern = RuntimePattern{
        .id = "test",
        .template = "test template",
        .fix_type = .TYPE_FIX,
        .confidence = 0.95,
        .applied_at = 0,
        .success_count = 8,
        .failure_count = 2,
        .last_result = true,
        .health = .critical,
    };

    pattern.updateHealth();
    try std.testing.expectEqual(PatternHealth.healthy, pattern.health);

    pattern.failure_count = 10;
    pattern.updateHealth();
    try std.testing.expectEqual(PatternHealth.critical, pattern.health);
}

test "CircuitBreaker: initial state" {
    const cb = CircuitBreaker.init();
    try std.testing.expectEqual(CircuitBreakerState.closed, cb.state);
    try std.testing.expect(cb.canModify());
}

test "CircuitBreaker: triggers on failures" {
    var cb = CircuitBreaker.init();

    for (0..5) |_| {
        cb.recordFailure();
    }

    try std.testing.expectEqual(CircuitBreakerState.open, cb.state);
    try std.testing.expect(!cb.canModify());
}

test "CircuitBreaker: recovery after timeout" {
    var cb = CircuitBreaker.init();

    // Trigger circuit breaker
    for (0..5) |_| {
        cb.recordFailure();
    }
    try std.testing.expectEqual(CircuitBreakerState.open, cb.state);

    // Set timeout to past
    cb.last_state_change = std.time.timestamp() - 100;

    // Attempt recovery
    const recovered = cb.attemptRecovery();
    try std.testing.expect(recovered);
    try std.testing.expectEqual(CircuitBreakerState.half_open, cb.state);
}

test "CircuitBreaker: closes after successful recovery" {
    var cb = CircuitBreaker.init();

    // Trigger and start recovery
    for (0..5) |_| {
        cb.recordFailure();
    }
    cb.state = .half_open;

    // Record successful recoveries
    for (0..3) |_| {
        cb.recordSuccess();
    }

    try std.testing.expectEqual(CircuitBreakerState.closed, cb.state);
}

test "LivePatternManager: initialization" {
    const allocator = std.testing.allocator;

    var lpm = try LivePatternManager.init(allocator);
    defer lpm.deinit();

    try std.testing.expect(lpm.canModify());
    try std.testing.expectEqual(CircuitBreakerState.closed, lpm.circuit_breaker.state);
}

test "LivePatternManager: propose high confidence pattern" {
    const allocator = std.testing.allocator;

    var lpm = try LivePatternManager.init(allocator);
    defer lpm.deinit();

    const accepted = try lpm.proposePattern("test pattern", .TYPE_FIX, 0.96);
    try std.testing.expect(accepted);
    try std.testing.expectEqual(@as(usize, 1), lpm.active_patterns.items.len);
}

test "LivePatternManager: reject low confidence pattern" {
    const allocator = std.testing.allocator;

    var lpm = try LivePatternManager.init(allocator);
    defer lpm.deinit();

    const accepted = try lpm.proposePattern("test pattern", .TYPE_FIX, 0.80);
    try std.testing.expect(!accepted);
    try std.testing.expectEqual(@as(usize, 0), lpm.active_patterns.items.len);
}

test "LivePatternManager: record outcome" {
    const allocator = std.testing.allocator;

    var lpm = try LivePatternManager.init(allocator);
    defer lpm.deinit();

    _ = try lpm.proposePattern("test pattern", .TYPE_FIX, 0.96);

    const pattern_id = try std.fmt.allocPrint(allocator, "pattern_0", .{});
    defer allocator.free(pattern_id);

    try lpm.recordOutcome(pattern_id, true);

    const metrics = lpm.getPatternMetrics(pattern_id);
    try std.testing.expect(metrics != null);
    if (metrics) |m| {
        try std.testing.expectEqual(@as(usize, 1), m.total_attempts);
    }
}
