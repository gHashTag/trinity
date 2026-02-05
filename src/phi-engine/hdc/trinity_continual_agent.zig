//! Trinity Continual Agent - Lifelong Learning Node
//!
//! Integrates HDC continual learning into Trinity node:
//! - Learns new tasks without forgetting old ones
//! - Persists prototypes to disk for node restart
//! - Earns $TRI rewards for learning and inference
//!
//! Key Properties:
//! - No catastrophic forgetting (prototypes independent)
//! - Incremental learning (add tasks anytime)
//! - Persistent memory (survives restarts)
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const hdc = @import("hdc_core.zig");
const cl = @import("continual_learner.zig");

pub const Trit = hdc.Trit;
pub const HyperVector = hdc.HyperVector;

// ═══════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════

pub const AgentConfig = struct {
    dim: usize = 10000,
    learning_rate: f64 = 0.5,
    persistence_path: []const u8 = "trinity_agent_prototypes.bin",
    auto_save: bool = true,
    reward_per_learn: u64 = 100, // $TRI wei per class learned
    reward_per_inference: u64 = 1, // $TRI wei per inference
};

// ═══════════════════════════════════════════════════════════════
// AGENT STATISTICS
// ═══════════════════════════════════════════════════════════════

pub const AgentStats = struct {
    total_classes: usize,
    total_inferences: u64,
    total_learns: u64,
    total_rewards: u64,
    uptime_seconds: u64,
    avg_forgetting: f64,
    max_forgetting: f64,
};

// ═══════════════════════════════════════════════════════════════
// TRINITY CONTINUAL AGENT
// ═══════════════════════════════════════════════════════════════

pub const TrinityContinualAgent = struct {
    config: AgentConfig,
    learner: cl.ContinualLearner,
    encoder: TextEncoder,
    stats: AgentStats,
    start_time: i64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: AgentConfig) !TrinityContinualAgent {
        return .{
            .config = config,
            .learner = cl.ContinualLearner.init(allocator, .{
                .dim = config.dim,
                .learning_rate = config.learning_rate,
            }),
            .encoder = TextEncoder.init(allocator, config.dim),
            .stats = .{
                .total_classes = 0,
                .total_inferences = 0,
                .total_learns = 0,
                .total_rewards = 0,
                .uptime_seconds = 0,
                .avg_forgetting = 0.0,
                .max_forgetting = 0.0,
            },
            .start_time = std.time.timestamp(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TrinityContinualAgent) void {
        self.learner.deinit();
        self.encoder.deinit();
    }

    /// Learn a new task/class from text samples
    pub fn learnTask(self: *TrinityContinualAgent, task_name: []const u8, samples: []const []const u8) !void {
        var encoded_samples = std.ArrayList([]const Trit).init(self.allocator);
        defer {
            for (encoded_samples.items) |item| {
                self.allocator.free(@constCast(item));
            }
            encoded_samples.deinit();
        }

        // Encode all samples
        for (samples) |text| {
            var vec = try self.encoder.encode(text);
            const data_copy = try self.allocator.dupe(Trit, vec.data);
            vec.deinit();
            try encoded_samples.append(data_copy);
        }

        // Train the class
        try self.learner.trainClass(task_name, encoded_samples.items);

        // Update stats
        self.stats.total_classes = self.learner.prototypes.count();
        self.stats.total_learns += 1;
        self.stats.total_rewards += self.config.reward_per_learn;

        // Auto-save if enabled
        if (self.config.auto_save) {
            try self.savePrototypes();
        }
    }

    /// Predict task/class for input text
    pub fn predict(self: *TrinityContinualAgent, text: []const u8) !struct { task: []const u8, confidence: f64 } {
        var vec = try self.encoder.encode(text);
        defer vec.deinit();

        const result = self.learner.predict(vec.data);

        // Update stats
        self.stats.total_inferences += 1;
        self.stats.total_rewards += self.config.reward_per_inference;

        return .{
            .task = result.label,
            .confidence = result.confidence,
        };
    }

    /// Get all learned tasks
    pub fn getLearnedTasks(self: *TrinityContinualAgent) ![][]const u8 {
        var tasks = std.ArrayList([]const u8).init(self.allocator);
        var iter = self.learner.prototypes.iterator();
        while (iter.next()) |entry| {
            try tasks.append(entry.key_ptr.*);
        }
        return tasks.toOwnedSlice();
    }

    /// Measure current forgetting across all tasks
    pub fn measureForgetting(self: *TrinityContinualAgent) f64 {
        const metrics = self.learner.getMetrics();
        self.stats.avg_forgetting = metrics.avg_forgetting;
        self.stats.max_forgetting = metrics.max_forgetting;
        return metrics.max_forgetting;
    }

    /// Measure interference between tasks
    pub fn measureInterference(self: *TrinityContinualAgent) f64 {
        return self.learner.measureInterference();
    }

    /// Get agent statistics
    pub fn getStats(self: *TrinityContinualAgent) AgentStats {
        self.stats.uptime_seconds = @intCast(std.time.timestamp() - self.start_time);
        self.stats.total_classes = self.learner.prototypes.count();
        return self.stats;
    }

    /// Save prototypes to disk
    pub fn savePrototypes(self: *TrinityContinualAgent) !void {
        const file = try std.fs.cwd().createFile(self.config.persistence_path, .{});
        defer file.close();

        var writer = file.writer();

        // Write header
        try writer.writeInt(u32, @intCast(self.learner.prototypes.count()), .little);
        try writer.writeInt(u32, @intCast(self.config.dim), .little);

        // Write each prototype
        var iter = self.learner.prototypes.iterator();
        while (iter.next()) |entry| {
            const label = entry.key_ptr.*;
            const proto = entry.value_ptr;

            // Write label length and label
            try writer.writeInt(u32, @intCast(label.len), .little);
            try writer.writeAll(label);

            // Write vector
            for (proto.vector) |trit| {
                try writer.writeInt(i8, trit, .little);
            }

            // Write count
            try writer.writeInt(u64, proto.count, .little);
        }
    }

    /// Load prototypes from disk
    pub fn loadPrototypes(self: *TrinityContinualAgent) !void {
        const file = std.fs.cwd().openFile(self.config.persistence_path, .{}) catch |err| {
            if (err == error.FileNotFound) return; // No saved state, start fresh
            return err;
        };
        defer file.close();

        var reader = file.reader();

        // Read header
        const num_protos = try reader.readInt(u32, .little);
        const dim = try reader.readInt(u32, .little);

        if (dim != self.config.dim) return error.DimensionMismatch;

        // Read each prototype
        for (0..num_protos) |_| {
            // Read label
            const label_len = try reader.readInt(u32, .little);
            const label_buf = try self.allocator.alloc(u8, label_len);
            defer self.allocator.free(label_buf);
            _ = try reader.readAll(label_buf);

            // Read vector
            const vector = try self.allocator.alloc(Trit, dim);
            defer self.allocator.free(vector);
            for (vector) |*trit| {
                trit.* = try reader.readInt(i8, .little);
            }

            // Read count
            const count = try reader.readInt(u64, .little);

            // Create prototype with its own copy of label
            var proto = try cl.Prototype.init(self.allocator, label_buf, dim, 0);
            @memcpy(proto.vector, vector);
            proto.count = count;

            // Add to learner using the prototype's own label copy
            try self.learner.prototypes.put(proto.label, proto);
        }

        self.stats.total_classes = self.learner.prototypes.count();
    }

    /// Reset agent (clear all learned tasks)
    pub fn reset(self: *TrinityContinualAgent) void {
        var iter = self.learner.prototypes.iterator();
        while (iter.next()) |entry| {
            var proto = entry.value_ptr;
            proto.deinit();
        }
        self.learner.prototypes.clearAndFree();
        self.learner.current_phase = 0;
        self.learner.phase_results.clearAndFree();

        self.stats = .{
            .total_classes = 0,
            .total_inferences = 0,
            .total_learns = 0,
            .total_rewards = 0,
            .uptime_seconds = 0,
            .avg_forgetting = 0.0,
            .max_forgetting = 0.0,
        };
        self.start_time = std.time.timestamp();
    }
};

// ═══════════════════════════════════════════════════════════════
// TEXT ENCODER (simplified for agent use)
// ═══════════════════════════════════════════════════════════════

pub const TextEncoder = struct {
    codebook: std.StringHashMap(HyperVector),
    dim: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, dim: usize) TextEncoder {
        return .{
            .codebook = std.StringHashMap(HyperVector).init(allocator),
            .dim = dim,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TextEncoder) void {
        var iter = self.codebook.iterator();
        while (iter.next()) |entry| {
            var vec = entry.value_ptr;
            vec.deinit();
        }
        self.codebook.deinit();
    }

    fn getTokenVector(self: *TextEncoder, token: []const u8) ![]const Trit {
        if (self.codebook.get(token)) |vec| {
            return vec.data;
        }

        var hasher = std.hash.Wyhash.init(0);
        hasher.update(token);
        const seed = hasher.final();

        const vec = try hdc.randomVector(self.allocator, self.dim, seed);
        try self.codebook.put(token, vec);
        return vec.data;
    }

    pub fn encode(self: *TextEncoder, text: []const u8) !HyperVector {
        var result = try hdc.zeroVector(self.allocator, self.dim);
        var temp = try HyperVector.init(self.allocator, self.dim);
        defer temp.deinit();

        var tokens = std.mem.tokenizeAny(u8, text, " \t\n\r");
        var pos: usize = 0;

        while (tokens.next()) |token| {
            const token_vec = try self.getTokenVector(token);
            hdc.permute(token_vec, pos, temp.data);

            for (0..self.dim) |i| {
                const sum: i16 = @as(i16, result.data[i]) + @as(i16, temp.data[i]);
                if (sum > 1) {
                    result.data[i] = 1;
                } else if (sum < -1) {
                    result.data[i] = -1;
                } else {
                    result.data[i] = @intCast(sum);
                }
            }
            pos += 1;
        }

        for (result.data) |*t| {
            if (t.* > 0) t.* = 1 else if (t.* < 0) t.* = -1;
        }

        return result;
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "agent init and learn" {
    const allocator = std.testing.allocator;
    var agent = try TrinityContinualAgent.init(allocator, .{
        .dim = 1000,
        .auto_save = false,
    });
    defer agent.deinit();

    const samples = [_][]const u8{
        "buy free click offer limited",
        "winner prize urgent act now",
    };

    try agent.learnTask("spam", &samples);

    try std.testing.expectEqual(@as(usize, 1), agent.stats.total_classes);
    try std.testing.expectEqual(@as(u64, 1), agent.stats.total_learns);
}

test "agent predict" {
    const allocator = std.testing.allocator;
    var agent = try TrinityContinualAgent.init(allocator, .{
        .dim = 5000,
        .auto_save = false,
    });
    defer agent.deinit();

    const spam_samples = [_][]const u8{
        "buy free click offer limited",
        "winner prize urgent act now",
    };
    const ham_samples = [_][]const u8{
        "meeting project report schedule",
        "team update review discuss plan",
    };

    try agent.learnTask("spam", &spam_samples);
    try agent.learnTask("ham", &ham_samples);

    const result = try agent.predict("buy free winner prize");
    try std.testing.expectEqualStrings("spam", result.task);
}

test "agent no forgetting" {
    const allocator = std.testing.allocator;
    var agent = try TrinityContinualAgent.init(allocator, .{
        .dim = 5000,
        .auto_save = false,
    });
    defer agent.deinit();

    // Learn spam
    const spam_samples = [_][]const u8{"buy free click offer limited"};
    try agent.learnTask("spam", &spam_samples);

    // Predict spam before learning ham
    const pred1 = try agent.predict("buy free click");
    try std.testing.expectEqualStrings("spam", pred1.task);

    // Learn ham
    const ham_samples = [_][]const u8{"meeting project report schedule"};
    try agent.learnTask("ham", &ham_samples);

    // Predict spam after learning ham - should still work
    const pred2 = try agent.predict("buy free click");
    try std.testing.expectEqualStrings("spam", pred2.task);
}
