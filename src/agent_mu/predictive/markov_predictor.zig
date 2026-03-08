//! Markov Predictor v8.21
//!
//! Predictive intelligence using Markov chains
//! Features:
//! - State transition probability tracking
//! - Success probability forecasting
//! - λ(10) sacred constant for long-term predictions
//! - Adaptive learning from outcomes

const std = @import("std");
const sacred = @import("sacred_constants.zig");

const ArrayList = std.array_list.Managed;
const Allocator = std.mem.Allocator;

/// Markov state for pattern transitions
pub const MarkovState = enum {
    success,
    failure,
    partial,
    timeout,
    pending,
};

/// Transition count
pub const TransitionCount = struct {
    from: MarkovState,
    to: MarkovState,
    count: usize,
    probability: f64,
};

/// Markov chain predictor
pub const MarkovPredictor = struct {
    const Self = @This();

    allocator: Allocator,
    transition_matrix: std.AutoHashMap(usize, usize),
    from_counts: [5]usize, // Count of transitions FROM each state
    to_counts: [5]usize, // Count of transitions TO each state
    current_state: MarkovState,
    total_transitions: usize,

    /// Initialize predictor
    pub fn init(allocator: Allocator) MarkovPredictor {
        return .{
            .allocator = allocator,
            .transition_matrix = std.AutoHashMap(usize, usize).init(allocator),
            .from_counts = [_]usize{0} ** 5,
            .to_counts = [_]usize{0} ** 5,
            .current_state = .pending,
            .total_transitions = 0,
        };
    }

    /// Deinitialize
    pub fn deinit(self: *MarkovPredictor) void {
        self.transition_matrix.deinit();
    }

    /// Encode state pair to key
    fn encodeKey(from: MarkovState, to: MarkovState) usize {
        return (@as(usize, @intFromEnum(from)) << 3) | @as(usize, @intFromEnum(to));
    }

    /// Record state transition
    pub fn recordTransition(self: *MarkovPredictor, from: MarkovState, to: MarkovState) !void {
        const key = Self.encodeKey(from, to);
        const entry = try self.transition_matrix.getOrPut(key);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }

        self.from_counts[@intFromEnum(from)] += 1;
        self.to_counts[@intFromEnum(to)] += 1;
        self.current_state = to;
        self.total_transitions += 1;
    }

    /// Get transition probability
    pub fn getTransitionProbability(self: *const MarkovPredictor, from: MarkovState, to: MarkovState) f64 {
        const key = Self.encodeKey(from, to);
        const count = self.transition_matrix.get(key) orelse return 0;
        const from_count = self.from_counts[@intFromEnum(from)];
        if (from_count == 0) return 0;
        return @as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(from_count));
    }

    /// Predict success probability for N steps ahead
    pub fn predictSuccessProbability(self: *MarkovPredictor, steps: u32) !f64 {
        if (steps == 0) {
            return if (self.current_state == .success) 1.0 else 0.0;
        }

        var prob = self.getTransitionProbability(self.current_state, .success);

        // Apply L(10) sacred constant for longer-term predictions
        if (steps > 1) {
            const lambda10 = sacred.LAMBDA_SCALE;
            var step: u32 = 1;
            while (step < steps) : (step += 1) {
                prob *= lambda10;
                if (prob > 1.0) prob = 1.0;
            }
        }

        return prob;
    }

    /// Get most likely next state
    pub fn getMostLikelyNextState(self: *const MarkovPredictor) MarkovState {
        var best_state: MarkovState = .pending;
        var best_prob: f64 = 0.0;

        for (0..5) |i| {
            const state = @as(MarkovState, @enumFromInt(i));
            const prob = self.getTransitionProbability(self.current_state, state);
            if (prob > best_prob) {
                best_prob = prob;
                best_state = state;
            }
        }

        return best_state;
    }

    /// Train from historical data
    pub fn trainFromHistory(self: *MarkovPredictor, history: []const MarkovState) !void {
        if (history.len < 2) return;

        for (0..history.len - 1) |i| {
            try self.recordTransition(history[i], history[i + 1]);
        }
    }

    /// Get transition entropy (uncertainty measure)
    pub fn getTransitionEntropy(self: *const MarkovPredictor) f64 {
        var entropy: f64 = 0.0;
        const from_idx = @intFromEnum(self.current_state);
        const total = self.from_counts[from_idx];

        if (total == 0) return 0.0;

        for (0..5) |i| {
            const to = @as(MarkovState, @enumFromInt(i));
            const prob = self.getTransitionProbability(self.current_state, to);
            if (prob > 0) {
                entropy -= prob * std.math.log2(prob);
            }
        }

        return entropy;
    }

    /// Get confidence score for predictions
    pub fn getPredictionConfidence(self: *const MarkovPredictor) f64 {
        const entropy = self.getTransitionEntropy();
        const max_entropy = std.math.log2(5.0);
        return 1.0 - (entropy / max_entropy);
    }

    /// Reset predictor
    pub fn reset(self: *MarkovPredictor) void {
        self.transition_matrix.clearRetainingCapacity();
        self.from_counts = [_]usize{0} ** 5;
        self.to_counts = [_]usize{0} ** 5;
        self.current_state = .pending;
        self.total_transitions = 0;
    }

    /// Get total transitions count
    pub fn getTotalTransitions(self: *const MarkovPredictor) usize {
        return self.total_transitions;
    }

    /// Get count for specific state (number of times this state was reached)
    pub fn getStateCount(self: *const MarkovPredictor, state: MarkovState) usize {
        return self.to_counts[@intFromEnum(state)];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "Markov Predictor: Initialize" {
    var predictor = MarkovPredictor.init(std.testing.allocator);
    defer predictor.deinit();

    try std.testing.expectEqual(@as(usize, 0), predictor.total_transitions);
}

test "Markov Predictor: Record transition" {
    var predictor = MarkovPredictor.init(std.testing.allocator);
    defer predictor.deinit();

    try predictor.recordTransition(.pending, .success);
    try std.testing.expectEqual(@as(usize, 1), predictor.total_transitions);
    try std.testing.expectEqual(MarkovState.success, predictor.current_state);
}

test "Markov Predictor: Transition probability" {
    var predictor = MarkovPredictor.init(std.testing.allocator);
    defer predictor.deinit();

    // Record 3 successes out of 5 attempts from pending
    try predictor.recordTransition(.pending, .success);
    try predictor.recordTransition(.pending, .success);
    try predictor.recordTransition(.pending, .success);
    try predictor.recordTransition(.pending, .failure);
    try predictor.recordTransition(.pending, .failure);

    const prob = predictor.getTransitionProbability(.pending, .success);
    try std.testing.expectApproxEqAbs(0.6, prob, 0.01);
}

test "Markov Predictor: Predict success probability" {
    var predictor = MarkovPredictor.init(std.testing.allocator);
    defer predictor.deinit();

    // Record transitions from pending to success
    try predictor.recordTransition(.pending, .success);
    try predictor.recordTransition(.pending, .success);

    // Reset to pending state to test prediction from pending
    predictor.current_state = .pending;

    const prob = try predictor.predictSuccessProbability(1);
    try std.testing.expect(prob > 0.9);
}

test "Markov Predictor: Most likely next state" {
    var predictor = MarkovPredictor.init(std.testing.allocator);
    defer predictor.deinit();

    // Record transitions from pending to various states
    try predictor.recordTransition(.pending, .success);
    try predictor.recordTransition(.pending, .success);
    try predictor.recordTransition(.pending, .failure);

    // Reset to pending to get prediction from pending
    predictor.current_state = .pending;

    const next = predictor.getMostLikelyNextState();
    try std.testing.expectEqual(MarkovState.success, next);
}

test "Markov Predictor: Train from history" {
    var predictor = MarkovPredictor.init(std.testing.allocator);
    defer predictor.deinit();

    const history = [_]MarkovState{ .pending, .success, .pending, .success, .pending, .failure };
    try predictor.trainFromHistory(&history);

    try std.testing.expectEqual(@as(usize, 5), predictor.total_transitions);
}

test "Markov Predictor: Transition entropy" {
    var predictor = MarkovPredictor.init(std.testing.allocator);
    defer predictor.deinit();

    try predictor.recordTransition(.pending, .success);
    try predictor.recordTransition(.pending, .success);

    const entropy = predictor.getTransitionEntropy();
    // Low entropy because transitions are predictable
    try std.testing.expect(entropy >= 0.0 and entropy < 1.0);
}

test "Markov Predictor: Prediction confidence" {
    var predictor = MarkovPredictor.init(std.testing.allocator);
    defer predictor.deinit();

    // Make highly predictable transitions
    try predictor.recordTransition(.pending, .success);
    try predictor.recordTransition(.pending, .success);
    try predictor.recordTransition(.pending, .success);

    const confidence = predictor.getPredictionConfidence();
    // High confidence because low entropy
    try std.testing.expect(confidence > 0.5);
}

test "Markov Predictor: Reset" {
    var predictor = MarkovPredictor.init(std.testing.allocator);
    defer predictor.deinit();

    try predictor.recordTransition(.pending, .success);
    try predictor.recordTransition(.pending, .failure);

    try std.testing.expectEqual(@as(usize, 2), predictor.total_transitions);

    predictor.reset();

    try std.testing.expectEqual(@as(usize, 0), predictor.total_transitions);
    try std.testing.expectEqual(MarkovState.pending, predictor.current_state);
}

test "Markov Predictor: Get state counts" {
    var predictor = MarkovPredictor.init(std.testing.allocator);
    defer predictor.deinit();

    try predictor.recordTransition(.pending, .success);
    try predictor.recordTransition(.pending, .success);
    try predictor.recordTransition(.pending, .failure);

    try std.testing.expectEqual(@as(usize, 2), predictor.getStateCount(.success));
    try std.testing.expectEqual(@as(usize, 1), predictor.getStateCount(.failure));
}

test "Markov Predictor: Lambda scaling for long-term predictions" {
    var predictor = MarkovPredictor.init(std.testing.allocator);
    defer predictor.deinit();

    try predictor.recordTransition(.pending, .success);
    try predictor.recordTransition(.pending, .success);

    const prob1 = try predictor.predictSuccessProbability(1);
    const prob10 = try predictor.predictSuccessProbability(10);

    // Long-term predictions should be scaled by LAMBDA_SCALE
    try std.testing.expect(prob10 >= prob1);
}
