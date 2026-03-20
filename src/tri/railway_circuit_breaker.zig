// @origin(spec:railway_circuit_breaker.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// RAILWAY CIRCUIT BREAKER — Production-grade Rate Limiting
// ═══════════════════════════════════════════════════════════════════════════════
//
// Three-tier protection:
// 1. Circuit Breaker — isolates failing accounts
// 2. Request Budget — enforces hourly limits
// 3. Account Health — scores accounts for smart routing
//
// Industry standard patterns:
// - Circuit Breaker: Microsoft Azure, Martin Fowler
// - Request Budgeting: ORQ.ai, Stripe rate limiting
// - Health Scoring: Netflix Hystrix, Google SRE
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// Level 1: Circuit Breaker
// ═══════════════════════════════════════════════════════════════════════════════

/// Circuit breaker state machine
/// CLOSED → normal operation
/// OPEN → account resting, no requests
/// HALF_OPEN → testing if account recovered
pub const CircuitState = enum {
    closed,
    open,
    half_open,
};

/// Circuit Breaker for single Railway account
/// Prevents cascading failures by isolating problematic accounts
pub const AccountCircuit = struct {
    state: CircuitState = .closed,
    failure_count: u32 = 0,
    last_failure: i64 = 0,
    cooldown_sec: i64 = 60, // 1 minute cooldown after opening
    threshold: u32 = 3, // 3 failures triggers OPEN

    /// Check if account can accept requests
    pub fn canUse(self: *AccountCircuit, now: i64) bool {
        return switch (self.state) {
            .closed => true,
            .open => blk: {
                if (now - self.last_failure >= self.cooldown_sec * std.time.ns_per_s) {
                    self.state = .half_open;
                    break :blk true;
                }
                break :blk false;
            },
            .half_open => true,
        };
    }

    /// Record successful request
    pub fn recordSuccess(self: *AccountCircuit) void {
        self.state = .closed;
        self.failure_count = 0;
    }

    /// Record failed request
    pub fn recordFailure(self: *AccountCircuit, now: i64) void {
        self.failure_count += 1;
        self.last_failure = now;
        if (self.failure_count >= self.threshold) {
            self.state = .open;
        }
    }

    /// Reset circuit breaker (manual recovery)
    pub fn reset(self: *AccountCircuit) void {
        self.state = .closed;
        self.failure_count = 0;
        self.last_failure = 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Level 2: Request Budget
// ═══════════════════════════════════════════════════════════════════════════════

/// Request budget tracker for Railway API rate limits
/// Railway: 1000 req/hour per account (we use 900 for safety margin)
pub const RequestBudget = struct {
    hourly_limit: u32 = 900, // 90% of 1000, leave buffer
    hourly_used: u32 = 0,
    hour_start: i64 = 0,

    /// Try to consume one request from budget
    /// Returns true if budget available, false if exhausted
    pub fn tryConsume(self: *RequestBudget, now: i64) bool {
        const hour_ns = 3600 * std.time.ns_per_s;
        if (now - self.hour_start >= hour_ns) {
            self.hourly_used = 0;
            self.hour_start = now;
        }
        if (self.hourly_used >= self.hourly_limit) return false;
        self.hourly_used += 1;
        return true;
    }

    /// Get remaining budget for current hour
    pub fn remaining(self: *const RequestBudget) u32 {
        return self.hourly_limit -| self.hourly_used;
    }

    /// Get usage percentage (0.0 to 1.0)
    pub fn usageRatio(self: *const RequestBudget) f32 {
        return @as(f32, @floatFromInt(self.hourly_used)) / @as(f32, @floatFromInt(self.hourly_limit));
    }

    /// Reset budget (for new hour)
    pub fn reset(self: *RequestBudget, now: i64) void {
        self.hourly_used = 0;
        self.hour_start = now;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Level 3: Account Health
// ═══════════════════════════════════════════════════════════════════════════════

/// Account health score for smart routing
/// Combines circuit state, budget, and latency into single score
pub const AccountHealth = struct {
    name: []const u8,
    circuit: AccountCircuit = .{},
    budget: RequestBudget = .{},
    avg_latency_ms: f32 = 200.0,
    score: f32 = 1.0,
    total_requests: u64 = 0,
    total_failures: u64 = 0,

    /// Record API call result and update health score
    pub fn record(self: *AccountHealth, latency_ms: u32, success: bool, now: i64) void {
        self.total_requests += 1;

        // Exponential moving average for latency
        const latency_f = @as(f32, @floatFromInt(latency_ms));
        self.avg_latency_ms = self.avg_latency_ms * 0.9 + latency_f * 0.1;

        if (success) {
            self.circuit.recordSuccess();
        } else {
            self.total_failures += 1;
            self.circuit.recordFailure(now);
        }

        self.recalcScore();
    }

    /// Recalculate health score from components
    fn recalcScore(self: *AccountHealth) void {
        // Latency factor: penalize high latency
        const latency_factor: f32 = if (self.avg_latency_ms > 2000) 0.6 else if (self.avg_latency_ms > 1000) 0.8 else 1.0;

        // Budget factor: prefer accounts with more remaining budget
        const budget_f = @as(f32, @floatFromInt(self.budget.remaining())) / 900.0;

        // Circuit factor: CLOSED=1.0, HALF_OPEN=0.5, OPEN=0.0
        const circuit_factor: f32 = switch (self.circuit.state) {
            .closed => 1.0,
            .half_open => 0.5,
            .open => 0.0,
        };

        // Combined score (weighted average)
        self.score = latency_factor * (0.4 + budget_f * 0.3) * circuit_factor;
    }

    /// Get success rate (0.0 to 1.0)
    pub fn successRate(self: *const AccountHealth) f32 {
        if (self.total_requests == 0) return 1.0;
        const success_count = self.total_requests -| self.total_failures;
        return @as(f32, @floatFromInt(success_count)) / @as(f32, @floatFromInt(self.total_requests));
    }

    /// Check if account is healthy (score > 0.5)
    pub fn isHealthy(self: *const AccountHealth) bool {
        return self.score > 0.5 and self.circuit.state != .open;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Account Selector
// ═══════════════════════════════════════════════════════════════════════════════

/// Select best available account based on health scoring
/// Returns null if all accounts exhausted
pub fn selectBest(accounts: []AccountHealth, now: i64) ?*AccountHealth {
    var best: ?*AccountHealth = null;
    var best_score: f32 = -1.0;

    for (accounts) |*acc| {
        // Skip accounts that can't be used
        if (!acc.circuit.canUse(now)) continue;

        // Try to consume budget (rollback if failed)
        if (!acc.budget.tryConsume(now)) {
            // Budget exhausted — don't use this account
            continue;
        }

        // Track best score
        if (acc.score > best_score) {
            best = acc;
            best_score = acc.score;
        }
    }

    return best;
}

/// Get list of healthy accounts (score > 0.5)
pub fn getHealthyAccounts(accounts: []AccountHealth, now: i64) []const *AccountHealth {
    var healthy: [4]*const AccountHealth = undefined;
    var len: usize = 0;

    for (accounts) |*acc| {
        if (acc.isHealthy() and acc.circuit.canUse(now)) {
            if (len < healthy.len) {
                healthy[len] = acc;
                len += 1;
            }
        }
    }

    return healthy[0..len];
}

/// Get overall farm health status
pub const FarmHealth = struct {
    total_accounts: u32,
    healthy_accounts: u32,
    total_budget_remaining: u32,
    avg_score: f32,
};

pub fn getFarmHealth(accounts: []const AccountHealth, now: i64) FarmHealth {
    var healthy: u32 = 0;
    var total_budget: u32 = 0;
    var total_score: f32 = 0.0;

    for (accounts) |*acc| {
        if (acc.isHealthy() and acc.circuit.canUse(now)) healthy += 1;
        total_budget += acc.budget.remaining();
        total_score += acc.score;
    }

    return .{
        .total_accounts = @intCast(accounts.len),
        .healthy_accounts = healthy,
        .total_budget_remaining = total_budget,
        .avg_score = if (accounts.len > 0) total_score / @as(f32, @floatFromInt(accounts.len)) else 0.0,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "CircuitBreaker: closed allows requests" {
    var cb = AccountCircuit{};
    const now = std.time.timestamp();

    try std.testing.expectEqual(cb.canUse(now), true);
    try std.testing.expectEqual(cb.state, .closed);
}

test "CircuitBreaker: three failures opens circuit" {
    var cb = AccountCircuit{};
    const now = std.time.timestamp();

    cb.recordFailure(now);
    try std.testing.expectEqual(cb.state, .closed);

    cb.recordFailure(now);
    try std.testing.expectEqual(cb.state, .closed);

    cb.recordFailure(now);
    try std.testing.expectEqual(cb.state, .open);
    try std.testing.expectEqual(cb.canUse(now), false);
}

test "CircuitBreaker: success resets circuit" {
    var cb = AccountCircuit{};
    const now = std.time.timestamp();

    // Trip circuit
    cb.recordFailure(now);
    cb.recordFailure(now);
    cb.recordFailure(now);
    try std.testing.expectEqual(cb.state, .open);

    // Success resets
    cb.recordSuccess();
    try std.testing.expectEqual(cb.state, .closed);
    try std.testing.expectEqual(cb.canUse(now), true);
}

test "RequestBudget: respects hourly limit" {
    var rb = RequestBudget{};
    const now = std.time.timestamp();

    // Should allow up to hourly_limit
    var i: u32 = 0;
    while (i < rb.hourly_limit) : (i += 1) {
        try std.testing.expectEqual(rb.tryConsume(now), true);
    }

    // Next request should fail
    try std.testing.expectEqual(rb.tryConsume(now), false);
    try std.testing.expectEqual(rb.remaining(), 0);
}

test "RequestBudget: resets after hour" {
    var rb = RequestBudget{};
    const now = std.time.timestamp();

    // Use some budget
    _ = rb.tryConsume(now);
    _ = rb.tryConsume(now);

    // Simulate hour passed
    const hour_later = now + 3601 * std.time.ns_per_s;
    try std.testing.expectEqual(rb.tryConsume(hour_later), true);
    try std.testing.expectEqual(rb.hourly_used, 1); // Only new request counted
}

test "AccountHealth: score calculation" {
    var acc = AccountHealth{ .name = "TEST" };
    const now = std.time.timestamp();

    // Initial score should be 1.0
    try std.testing.expectEqual(acc.score, 1.0);

    // Record high latency (should reduce score)
    acc.record(3000, true, now);
    try std.testing.expect(acc.score < 1.0);

    // Record success (should improve score)
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        acc.record(200, true, now + @as(i64, i) * std.time.ns_per_s);
    }
    try std.testing.expect(acc.score > 0.65); // Max score = 0.7 with formula: 1.0 * (0.4 + 1.0 * 0.3) * 1.0
}

test "selectBest: chooses healthiest account" {
    const now = std.time.timestamp();

    var accounts = [_]AccountHealth{
        .{ .name = "PRIMARY", .score = 0.5 },
        .{ .name = "FARM-2", .score = 0.9 },
        .{ .name = "FARM-3", .score = 0.7 },
    };

    const best = selectBest(&accounts, now);
    try std.testing.expect(best != null);
    try std.testing.expectEqual(best.?.name, "FARM-2");
}

test "selectBest: skips exhausted budget" {
    const now = std.time.timestamp();

    var accounts = [_]AccountHealth{
        .{ .name = "PRIMARY" },
        .{ .name = "FARM-2" },
    };

    // Exhaust PRIMARY budget
    var i: u32 = 0;
    while (i < 900) : (i += 1) {
        _ = accounts[0].budget.tryConsume(now);
    }

    const best = selectBest(&accounts, now);
    try std.testing.expect(best != null);
    try std.testing.expectEqual(best.?.name, "FARM-2"); // Should skip PRIMARY
}

test "selectBest: returns null if all exhausted" {
    const now = std.time.timestamp();

    var accounts = [_]AccountHealth{
        .{ .name = "PRIMARY" },
    };

    // Open circuit (no requests allowed)
    accounts[0].circuit.recordFailure(now);
    accounts[0].circuit.recordFailure(now);
    accounts[0].circuit.recordFailure(now);

    const best = selectBest(&accounts, now);
    try std.testing.expect(best == null);
}
