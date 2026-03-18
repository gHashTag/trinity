//! FIREBIRD Continual Agent - Web Learning Without Forgetting
//!
//! Integrates FIREBIRD (WebArena browser agent) with HDC Continual Learning:
//! - Learns new tasks from web browsing results
//! - No catastrophic forgetting (old knowledge preserved)
//! - Earns $TRI rewards for browsing and learning
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const firebird = @import("firebird.zig");
const vsa = @import("vsa.zig");

// ═══════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════

pub const FirebirdAgentConfig = struct {
    dim: usize = 10000,
    learning_rate: f64 = 0.5,
    auto_learn: bool = true, // Learn from browsing automatically
    reward_per_browse: u64 = 10,
    reward_per_learn: u64 = 100,
    reward_per_task_complete: u64 = 500,
};

// ═══════════════════════════════════════════════════════════════
// WEB TASK TYPES
// ═══════════════════════════════════════════════════════════════

pub const WebTaskType = enum {
    search,
    navigate,
    click,
    form_fill,
    extract,
    classify,
};

pub const WebTask = struct {
    task_type: WebTaskType,
    query: []const u8,
    url: []const u8,
    result: ?[]const u8,
    success: bool,
    learned: bool,
};

// ═══════════════════════════════════════════════════════════════
// BROWSING RESULT
// ═══════════════════════════════════════════════════════════════

pub const BrowsingResult = struct {
    url: []const u8,
    title: []const u8,
    content_snippet: []const u8,
    category: []const u8, // Detected category (tech, sports, etc.)
    confidence: f64,
};

// ═══════════════════════════════════════════════════════════════
// AGENT STATISTICS
// ═══════════════════════════════════════════════════════════════

pub const AgentStats = struct {
    total_browses: u64,
    total_tasks_completed: u64,
    total_tasks_learned: u64,
    total_categories: usize,
    total_rewards: u64,
    accuracy: f64,
    forgetting: f64,
};

// ═══════════════════════════════════════════════════════════════
// PROTOTYPE (HDC class representation)
// ═══════════════════════════════════════════════════════════════

pub const Prototype = struct {
    label: []const u8,
    accumulator: []f64,
    vector: []vsa.Trit,
    count: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, label: []const u8, dim: usize) !Prototype {
        const acc = try allocator.alloc(f64, dim);
        @memset(acc, 0.0);
        const vec = try allocator.alloc(vsa.Trit, dim);
        @memset(vec, 0);
        const label_copy = try allocator.dupe(u8, label);

        return .{
            .label = label_copy,
            .accumulator = acc,
            .vector = vec,
            .count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Prototype) void {
        self.allocator.free(self.accumulator);
        self.allocator.free(self.vector);
        self.allocator.free(@constCast(self.label));
    }

    pub fn update(self: *Prototype, input: []const vsa.Trit, lr: f64) void {
        for (0..self.accumulator.len) |i| {
            self.accumulator[i] = self.accumulator[i] * (1.0 - lr) + @as(f64, @floatFromInt(input[i])) * lr;
        }
        // Quantize to ternary
        for (0..self.vector.len) |i| {
            if (self.accumulator[i] > 0.3) {
                self.vector[i] = 1;
            } else if (self.accumulator[i] < -0.3) {
                self.vector[i] = -1;
            } else {
                self.vector[i] = 0;
            }
        }
        self.count += 1;
    }
};

// ═══════════════════════════════════════════════════════════════
// FIREBIRD CONTINUAL AGENT
// ═══════════════════════════════════════════════════════════════

pub const FirebirdContinualAgent = struct {
    config: FirebirdAgentConfig,
    prototypes: std.StringHashMap(Prototype),
    codebook: std.StringHashMap([]vsa.Trit),
    task_history: std.ArrayList(WebTask),
    stats: AgentStats,
    dim: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: FirebirdAgentConfig) FirebirdContinualAgent {
        return .{
            .config = config,
            .prototypes = std.StringHashMap(Prototype).init(allocator),
            .codebook = std.StringHashMap([]vsa.Trit).init(allocator),
            .task_history = std.ArrayList(WebTask).init(allocator),
            .stats = .{
                .total_browses = 0,
                .total_tasks_completed = 0,
                .total_tasks_learned = 0,
                .total_categories = 0,
                .total_rewards = 0,
                .accuracy = 0.0,
                .forgetting = 0.0,
            },
            .dim = config.dim,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FirebirdContinualAgent) void {
        var proto_iter = self.prototypes.iterator();
        while (proto_iter.next()) |entry| {
            var proto = entry.value_ptr;
            proto.deinit();
        }
        self.prototypes.deinit();

        var code_iter = self.codebook.iterator();
        while (code_iter.next()) |entry| {
            // Free the token key (we duped it)
            self.allocator.free(@constCast(entry.key_ptr.*));
            // Free the vector value
            self.allocator.free(entry.value_ptr.*);
        }
        self.codebook.deinit();

        self.task_history.deinit();
    }

    /// Get or create token vector
    fn getTokenVector(self: *FirebirdContinualAgent, token: []const u8) ![]const vsa.Trit {
        if (self.codebook.get(token)) |vec| {
            return vec;
        }

        var hasher = std.hash.Wyhash.init(0);
        hasher.update(token);
        const seed = hasher.final();

        const vec = try self.allocator.alloc(vsa.Trit, self.dim);
        var rng = std.Random.DefaultPrng.init(seed);
        const random = rng.random();

        for (vec) |*t| {
            t.* = random.intRangeAtMost(i8, -1, 1);
        }

        // Copy token for hashmap key
        const token_copy = try self.allocator.dupe(u8, token);
        try self.codebook.put(token_copy, vec);
        return vec;
    }

    /// Encode text to hypervector
    fn encodeText(self: *FirebirdContinualAgent, text: []const u8) ![]vsa.Trit {
        var accumulator = try self.allocator.alloc(f64, self.dim);
        defer self.allocator.free(accumulator);
        @memset(accumulator, 0.0);

        var tokens = std.mem.tokenizeAny(u8, text, " \t\n\r.,;:!?");
        var pos: usize = 0;

        while (tokens.next()) |token| {
            const token_vec = try self.getTokenVector(token);

            for (0..self.dim) |i| {
                const permuted_i = (i + pos) % self.dim;
                accumulator[permuted_i] += @as(f64, @floatFromInt(token_vec[i]));
            }
            pos += 1;
        }

        const result = try self.allocator.alloc(vsa.Trit, self.dim);
        for (0..self.dim) |i| {
            if (accumulator[i] > 0.5) {
                result[i] = 1;
            } else if (accumulator[i] < -0.5) {
                result[i] = -1;
            } else {
                result[i] = 0;
            }
        }

        return result;
    }

    /// Similarity between two vectors
    fn similarity(self: *FirebirdContinualAgent, a: []const vsa.Trit, b: []const vsa.Trit) f64 {
        _ = self;
        var dot: i64 = 0;
        var norm_a: i64 = 0;
        var norm_b: i64 = 0;

        for (0..a.len) |i| {
            dot += @as(i64, a[i]) * @as(i64, b[i]);
            norm_a += @as(i64, a[i]) * @as(i64, a[i]);
            norm_b += @as(i64, b[i]) * @as(i64, b[i]);
        }

        if (norm_a == 0 or norm_b == 0) return 0.0;

        return @as(f64, @floatFromInt(dot)) / (@sqrt(@as(f64, @floatFromInt(norm_a))) * @sqrt(@as(f64, @floatFromInt(norm_b))));
    }

    /// Learn a category from browsing result
    pub fn learnFromBrowsing(self: *FirebirdContinualAgent, result: BrowsingResult) !void {
        // Encode the content
        const content = try std.fmt.allocPrint(self.allocator, "{s} {s}", .{ result.title, result.content_snippet });
        defer self.allocator.free(content);

        const vec = try self.encodeText(content);
        defer self.allocator.free(vec);

        // Update or create prototype
        if (self.prototypes.getPtr(result.category)) |proto| {
            proto.update(vec, self.config.learning_rate);
        } else {
            var new_proto = try Prototype.init(self.allocator, result.category, self.dim);
            new_proto.update(vec, 1.0);
            try self.prototypes.put(result.category, new_proto);
        }

        self.stats.total_tasks_learned += 1;
        self.stats.total_categories = self.prototypes.count();
        self.stats.total_rewards += self.config.reward_per_learn;
    }

    /// Classify content
    pub fn classify(self: *FirebirdContinualAgent, content: []const u8) !struct { category: []const u8, confidence: f64 } {
        const vec = try self.encodeText(content);
        defer self.allocator.free(vec);

        var best_sim: f64 = -2.0;
        var best_category: []const u8 = "unknown";

        var iter = self.prototypes.iterator();
        while (iter.next()) |entry| {
            const sim = self.similarity(vec, entry.value_ptr.vector);
            if (sim > best_sim) {
                best_sim = sim;
                best_category = entry.key_ptr.*;
            }
        }

        return .{
            .category = best_category,
            .confidence = if (best_sim > -2.0) best_sim else 0.0,
        };
    }

    /// Execute web task
    pub fn executeTask(self: *FirebirdContinualAgent, task: WebTask) !WebTask {
        var result = task;

        // Simulate task execution
        self.stats.total_browses += 1;
        self.stats.total_rewards += self.config.reward_per_browse;

        // If task completed successfully and auto_learn enabled
        if (task.success and self.config.auto_learn) {
            if (task.result) |content| {
                // Detect category from content
                const classification = try self.classify(content);

                // Learn from result
                const browsing_result = BrowsingResult{
                    .url = task.url,
                    .title = task.query,
                    .content_snippet = content,
                    .category = classification.category,
                    .confidence = classification.confidence,
                };

                try self.learnFromBrowsing(browsing_result);
                result.learned = true;
            }
        }

        if (task.success) {
            self.stats.total_tasks_completed += 1;
            self.stats.total_rewards += self.config.reward_per_task_complete;
        }

        try self.task_history.append(result);
        return result;
    }

    /// Measure interference between categories
    pub fn measureInterference(self: *FirebirdContinualAgent) f64 {
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
                const sim = @abs(self.similarity(proto_i.vector, proto_j.vector));
                if (sim > max_sim) max_sim = sim;
            }
        }

        return max_sim;
    }

    /// Get agent statistics
    pub fn getStats(self: *FirebirdContinualAgent) AgentStats {
        return self.stats;
    }

    /// Get learned categories
    pub fn getCategories(self: *FirebirdContinualAgent) ![][]const u8 {
        var categories = std.ArrayList([]const u8).init(self.allocator);
        var iter = self.prototypes.iterator();
        while (iter.next()) |entry| {
            try categories.append(entry.key_ptr.*);
        }
        return categories.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "firebird agent init" {
    const allocator = std.testing.allocator;
    var agent = FirebirdContinualAgent.init(allocator, .{ .dim = 1000 });
    defer agent.deinit();

    try std.testing.expectEqual(@as(usize, 0), agent.prototypes.count());
}

test "firebird agent learn" {
    const allocator = std.testing.allocator;
    var agent = FirebirdContinualAgent.init(allocator, .{ .dim = 5000 });
    defer agent.deinit();

    const result = BrowsingResult{
        .url = "https://github.com",
        .title = "GitHub",
        .content_snippet = "programming code software developer repository",
        .category = "tech",
        .confidence = 0.9,
    };

    try agent.learnFromBrowsing(result);

    try std.testing.expectEqual(@as(usize, 1), agent.prototypes.count());
    try std.testing.expectEqual(@as(u64, 1), agent.stats.total_tasks_learned);
}

test "firebird agent classify" {
    const allocator = std.testing.allocator;
    var agent = FirebirdContinualAgent.init(allocator, .{ .dim = 5000 });
    defer agent.deinit();

    // Learn tech category
    const tech_result = BrowsingResult{
        .url = "https://github.com",
        .title = "GitHub programming",
        .content_snippet = "code software developer repository algorithm",
        .category = "tech",
        .confidence = 0.9,
    };
    try agent.learnFromBrowsing(tech_result);

    // Learn sports category
    const sports_result = BrowsingResult{
        .url = "https://espn.com",
        .title = "ESPN Sports",
        .content_snippet = "football basketball game team player score",
        .category = "sports",
        .confidence = 0.9,
    };
    try agent.learnFromBrowsing(sports_result);

    // Classify tech content
    const classification = try agent.classify("programming code software algorithm");
    try std.testing.expectEqualStrings("tech", classification.category);
}
