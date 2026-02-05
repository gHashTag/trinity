//! HDC Continual Learner - No Catastrophic Forgetting
//!
//! Demonstrates that HDC prototypes are independent:
//! - Old prototypes remain untouched when learning new classes
//! - No weight sharing means no interference
//! - Forgetting only from boundary crowding, not parameter corruption
//!
//! Key Metrics:
//! - Forgetting: accuracy_before - accuracy_after on old classes
//! - Interference: max cosine similarity between prototypes
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const hdc = @import("hdc_core.zig");
const mtl = @import("multi_task_learner.zig");

pub const Trit = hdc.Trit;
pub const HyperVector = hdc.HyperVector;

// ═══════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════

pub const ContinualConfig = struct {
    dim: usize = 10000,
    learning_rate: f64 = 0.5,
    samples_per_class: usize = 30,
    test_samples_per_class: usize = 10,
};

// ═══════════════════════════════════════════════════════════════
// PHASE RESULT
// ═══════════════════════════════════════════════════════════════

pub const PhaseResult = struct {
    phase_id: usize,
    new_classes: []const []const u8,
    new_class_accuracy: f64,
    old_class_accuracy: f64,
    forgetting: f64, // old_acc_before - old_acc_after
    interference: f64, // max similarity between prototypes
    total_classes: usize,
};

// ═══════════════════════════════════════════════════════════════
// CONTINUAL METRICS
// ═══════════════════════════════════════════════════════════════

pub const ContinualMetrics = struct {
    phases_completed: usize,
    total_classes: usize,
    avg_forgetting: f64,
    max_forgetting: f64,
    avg_interference: f64,
    max_interference: f64,
    final_accuracy: f64,
};

// ═══════════════════════════════════════════════════════════════
// PROTOTYPE (with snapshot for forgetting measurement)
// ═══════════════════════════════════════════════════════════════

pub const Prototype = struct {
    label: []const u8,
    accumulator: []f64,
    vector: []Trit,
    count: u64,
    phase_added: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, label: []const u8, dim: usize, phase: usize) !Prototype {
        const acc = try allocator.alloc(f64, dim);
        @memset(acc, 0.0);
        const vec = try allocator.alloc(Trit, dim);
        @memset(vec, 0);
        const label_copy = try allocator.dupe(u8, label);

        return .{
            .label = label_copy,
            .accumulator = acc,
            .vector = vec,
            .count = 0,
            .phase_added = phase,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Prototype) void {
        self.allocator.free(self.accumulator);
        self.allocator.free(self.vector);
        self.allocator.free(@constCast(self.label));
    }

    pub fn update(self: *Prototype, input: []const Trit, lr: f64) void {
        hdc.onlineUpdate(self.accumulator, input, lr);
        hdc.quantizeToTernary(self.accumulator, self.vector);
        self.count += 1;
    }

    pub fn clone(self: *const Prototype, allocator: std.mem.Allocator) !Prototype {
        const acc = try allocator.alloc(f64, self.accumulator.len);
        @memcpy(acc, self.accumulator);
        const vec = try allocator.alloc(Trit, self.vector.len);
        @memcpy(vec, self.vector);
        const label_copy = try allocator.dupe(u8, self.label);

        return .{
            .label = label_copy,
            .accumulator = acc,
            .vector = vec,
            .count = self.count,
            .phase_added = self.phase_added,
            .allocator = allocator,
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// CONTINUAL LEARNER
// ═══════════════════════════════════════════════════════════════

pub const ContinualLearner = struct {
    config: ContinualConfig,
    prototypes: std.StringHashMap(Prototype),
    phase_results: std.ArrayList(PhaseResult),
    current_phase: usize,
    dim: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: ContinualConfig) ContinualLearner {
        return .{
            .config = config,
            .prototypes = std.StringHashMap(Prototype).init(allocator),
            .phase_results = std.ArrayList(PhaseResult).init(allocator),
            .current_phase = 0,
            .dim = config.dim,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ContinualLearner) void {
        var iter = self.prototypes.iterator();
        while (iter.next()) |entry| {
            var proto = entry.value_ptr;
            proto.deinit();
        }
        self.prototypes.deinit();
        self.phase_results.deinit();
    }

    /// Train a class with samples
    pub fn trainClass(self: *ContinualLearner, label: []const u8, samples: []const []const Trit) !void {
        if (self.prototypes.getPtr(label)) |proto| {
            for (samples) |sample| {
                proto.update(sample, self.config.learning_rate);
            }
        } else {
            var new_proto = try Prototype.init(self.allocator, label, self.dim, self.current_phase);
            for (samples) |sample| {
                new_proto.update(sample, 1.0); // First samples get full weight
            }
            try self.prototypes.put(label, new_proto);
        }
    }

    /// Predict class for input
    pub fn predict(self: *ContinualLearner, input: []const Trit) struct { label: []const u8, confidence: f64 } {
        var best_sim: f64 = -2.0;
        var best_label: []const u8 = "";

        var iter = self.prototypes.iterator();
        while (iter.next()) |entry| {
            const sim = hdc.similarity(input, entry.value_ptr.vector);
            if (sim > best_sim) {
                best_sim = sim;
                best_label = entry.key_ptr.*;
            }
        }

        return .{
            .label = best_label,
            .confidence = if (best_sim > -2.0) best_sim else 0.0,
        };
    }

    pub const TestSample = struct { input: []const Trit, label: []const u8 };

    /// Test accuracy on specific classes
    pub fn testAccuracy(self: *ContinualLearner, test_data: []const TestSample) f64 {
        if (test_data.len == 0) return 0.0;

        var correct: u32 = 0;
        for (test_data) |sample| {
            const pred = self.predict(sample.input);
            if (std.mem.eql(u8, pred.label, sample.label)) {
                correct += 1;
            }
        }

        return @as(f64, @floatFromInt(correct)) / @as(f64, @floatFromInt(test_data.len));
    }

    /// Measure interference between all prototype pairs
    pub fn measureInterference(self: *ContinualLearner) f64 {
        var max_sim: f64 = 0.0;

        var labels = std.ArrayList([]const u8).init(self.allocator);
        defer labels.deinit();

        var iter = self.prototypes.iterator();
        while (iter.next()) |entry| {
            labels.append(entry.key_ptr.*) catch continue;
        }

        const label_arr = labels.items;
        for (0..label_arr.len) |i| {
            for (i + 1..label_arr.len) |j| {
                const proto_i = self.prototypes.get(label_arr[i]) orelse continue;
                const proto_j = self.prototypes.get(label_arr[j]) orelse continue;
                const sim = @abs(hdc.similarity(proto_i.vector, proto_j.vector));
                if (sim > max_sim) max_sim = sim;
            }
        }

        return max_sim;
    }

    /// Get list of classes from specific phases
    pub fn getClassesFromPhases(self: *ContinualLearner, phases: []const usize) ![][]const u8 {
        var classes = std.ArrayList([]const u8).init(self.allocator);

        var iter = self.prototypes.iterator();
        while (iter.next()) |entry| {
            for (phases) |phase| {
                if (entry.value_ptr.phase_added == phase) {
                    try classes.append(entry.key_ptr.*);
                    break;
                }
            }
        }

        return classes.toOwnedSlice();
    }

    /// Run a complete phase
    pub fn runPhase(
        self: *ContinualLearner,
        new_classes: []const []const u8,
        train_data: []const struct { input: []const Trit, label: []const u8 },
        test_data_new: []const struct { input: []const Trit, label: []const u8 },
        test_data_old: []const struct { input: []const Trit, label: []const u8 },
    ) !PhaseResult {
        // Measure old accuracy before training
        const old_acc_before = if (test_data_old.len > 0) self.testAccuracy(test_data_old) else 1.0;

        // Train new classes
        for (new_classes) |class_label| {
            var class_samples = std.ArrayList([]const Trit).init(self.allocator);
            defer class_samples.deinit();

            for (train_data) |sample| {
                if (std.mem.eql(u8, sample.label, class_label)) {
                    try class_samples.append(sample.input);
                }
            }

            try self.trainClass(class_label, class_samples.items);
        }

        // Measure new class accuracy
        const new_acc = self.testAccuracy(test_data_new);

        // Measure old accuracy after training
        const old_acc_after = if (test_data_old.len > 0) self.testAccuracy(test_data_old) else 1.0;

        // Calculate forgetting
        const forgetting = old_acc_before - old_acc_after;

        // Measure interference
        const interference = self.measureInterference();

        const result = PhaseResult{
            .phase_id = self.current_phase,
            .new_classes = new_classes,
            .new_class_accuracy = new_acc,
            .old_class_accuracy = old_acc_after,
            .forgetting = forgetting,
            .interference = interference,
            .total_classes = self.prototypes.count(),
        };

        try self.phase_results.append(result);
        self.current_phase += 1;

        return result;
    }

    /// Get overall metrics
    pub fn getMetrics(self: *ContinualLearner) ContinualMetrics {
        var total_forgetting: f64 = 0.0;
        var max_forgetting: f64 = 0.0;
        var total_interference: f64 = 0.0;
        var max_interference: f64 = 0.0;

        for (self.phase_results.items) |result| {
            total_forgetting += result.forgetting;
            if (result.forgetting > max_forgetting) max_forgetting = result.forgetting;
            total_interference += result.interference;
            if (result.interference > max_interference) max_interference = result.interference;
        }

        const n = self.phase_results.items.len;
        const avg_forgetting = if (n > 0) total_forgetting / @as(f64, @floatFromInt(n)) else 0.0;
        const avg_interference = if (n > 0) total_interference / @as(f64, @floatFromInt(n)) else 0.0;

        // Final accuracy on all classes
        var final_acc: f64 = 0.0;
        if (n > 0) {
            final_acc = self.phase_results.items[n - 1].new_class_accuracy;
        }

        return .{
            .phases_completed = self.current_phase,
            .total_classes = self.prototypes.count(),
            .avg_forgetting = avg_forgetting,
            .max_forgetting = max_forgetting,
            .avg_interference = avg_interference,
            .max_interference = max_interference,
            .final_accuracy = final_acc,
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "continual learner init" {
    const allocator = std.testing.allocator;
    var learner = ContinualLearner.init(allocator, .{ .dim = 1000 });
    defer learner.deinit();

    try std.testing.expectEqual(@as(usize, 0), learner.current_phase);
    try std.testing.expectEqual(@as(usize, 0), learner.prototypes.count());
}

test "prototype independence" {
    const allocator = std.testing.allocator;
    var learner = ContinualLearner.init(allocator, .{ .dim = 5000 });
    defer learner.deinit();

    // Create two random class vectors
    var class_a = try hdc.randomVector(allocator, 5000, 11111);
    defer class_a.deinit();
    var class_b = try hdc.randomVector(allocator, 5000, 22222);
    defer class_b.deinit();

    const samples_a = [_][]const Trit{class_a.data};
    const samples_b = [_][]const Trit{class_b.data};

    try learner.trainClass("class_a", &samples_a);
    try learner.trainClass("class_b", &samples_b);

    // Interference should be low
    const interference = learner.measureInterference();
    try std.testing.expect(interference < 0.15);
}

test "no catastrophic forgetting" {
    const allocator = std.testing.allocator;
    var learner = ContinualLearner.init(allocator, .{ .dim = 5000 });
    defer learner.deinit();

    // Phase 1: Learn class A
    var class_a = try hdc.randomVector(allocator, 5000, 11111);
    defer class_a.deinit();
    const samples_a = [_][]const Trit{class_a.data};
    try learner.trainClass("class_a", &samples_a);

    // Test class A
    const pred_a_before = learner.predict(class_a.data);
    try std.testing.expectEqualStrings("class_a", pred_a_before.label);

    // Phase 2: Learn class B (should NOT affect class A)
    var class_b = try hdc.randomVector(allocator, 5000, 22222);
    defer class_b.deinit();
    const samples_b = [_][]const Trit{class_b.data};
    try learner.trainClass("class_b", &samples_b);

    // Test class A again - should still work
    const pred_a_after = learner.predict(class_a.data);
    try std.testing.expectEqualStrings("class_a", pred_a_after.label);

    // Confidence should be similar (no forgetting)
    try std.testing.expect(@abs(pred_a_before.confidence - pred_a_after.confidence) < 0.1);
}
