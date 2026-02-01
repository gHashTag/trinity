const std = @import("std");

// ============================================================================
// TRINITY: MoE ROUTER (PHASE 16) - Mixture of Experts with Ternary Weights
// Inspired by Mixtral/BitNet architecture for efficient agentic routing
// ============================================================================

/// Expert types available in the MoE system
pub const Expert = enum {
    Inference, // Mistral-7B.tri - для inference задач
    Network, // P2P/staking - сетевые операции
    CodeGen, // Qwen2.5-Coder-7B.tri - генерация кода
    Planning, // Steering модель - планирование и координация

    pub fn getName(self: Expert) []const u8 {
        return switch (self) {
            .Inference => "InferenceExpert (Mistral-7B.tri)",
            .Network => "NetworkExpert (P2P/Staking)",
            .CodeGen => "CodeGenExpert (Qwen2.5-Coder-7B.tri)",
            .Planning => "PlanningExpert (Steering Model)",
        };
    }

    pub fn getIcon(self: Expert) []const u8 {
        return switch (self) {
            .Inference => "🔮",
            .Network => "🌐",
            .CodeGen => "💻",
            .Planning => "🧠",
        };
    }
};

/// Ternary weight: -1, 0, +1 (BitNet-style)
pub const TernaryWeight = i2;

/// MoE Gate configuration
pub const MoEConfig = struct {
    top_k: u8 = 2, // Number of experts to activate
    hidden_dim: usize = 64, // Gate hidden dimension
    latency_threshold_ms: u64 = 50, // Mobile mode threshold
    adaptive_depth: bool = true, // Auto-reduce depth for latency
};

/// Expert routing result
pub const RouteResult = struct {
    experts: [4]Expert = .{ .Inference, .Network, .CodeGen, .Planning },
    scores: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },
    selected: [2]Expert = .{ .Inference, .Planning },
    selected_count: u8 = 2,
    latency_ms: u64 = 0,
};

/// MoE Router with ternary gating
pub const MoERouter = struct {
    allocator: std.mem.Allocator,
    config: MoEConfig,

    // Ternary gate weights: [4 experts][hidden_dim]
    gate_weights: [4][64]TernaryWeight,

    // Task embedding projection
    task_projection: [64]f32,

    // Statistics
    total_routes: u64 = 0,
    expert_activations: [4]u64 = .{ 0, 0, 0, 0 },

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: MoEConfig) !*Self {
        const self = try allocator.create(Self);

        // Initialize ternary gate weights with deterministic pattern
        var gate_weights: [4][64]TernaryWeight = undefined;

        // Expert 0: Inference - responds to "infer", "model", "predict"
        for (0..64) |i| {
            gate_weights[0][i] = if (i < 16) 1 else if (i < 32) -1 else 0;
        }
        // Expert 1: Network - responds to "network", "p2p", "stake"
        for (0..64) |i| {
            gate_weights[1][i] = if (i >= 16 and i < 32) 1 else if (i < 16) -1 else 0;
        }
        // Expert 2: CodeGen - responds to "code", "generate", "implement"
        for (0..64) |i| {
            gate_weights[2][i] = if (i >= 32 and i < 48) 1 else if (i >= 48) -1 else 0;
        }
        // Expert 3: Planning - responds to planning/coordination keywords
        for (0..64) |i| {
            gate_weights[3][i] = if (i >= 48) 1 else if (i >= 32 and i < 48) -1 else 0;
        }

        self.* = .{
            .allocator = allocator,
            .config = config,
            .gate_weights = gate_weights,
            .task_projection = [_]f32{0.0} ** 64,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    /// Fast ternary matrix-vector multiplication
    /// Exploits {-1, 0, +1} weights for addition-only compute
    pub fn ternaryMatVec(weights: []const TernaryWeight, input: []const f32) f32 {
        var sum: f32 = 0.0;
        const len = @min(weights.len, input.len);

        for (0..len) |i| {
            switch (weights[i]) {
                1 => sum += input[i],
                -1 => sum -= input[i],
                0 => {}, // Skip zero weights - sparse optimization
                else => {}, // Handle any other values
            }
        }
        return sum;
    }

    /// Project task text to embedding space
    fn projectTask(self: *Self, task: []const u8) void {
        // Simple character-level hash projection
        @memset(&self.task_projection, 0.0);

        for (task, 0..) |c, i| {
            const idx = (c +% @as(u8, @truncate(i))) % 64;
            self.task_projection[idx] += 1.0;
        }

        // Keyword boosting for better routing
        const keywords = [_]struct { key: []const u8, expert_idx: usize, boost: f32 }{
            .{ .key = "infer", .expert_idx = 0, .boost = 10.0 },
            .{ .key = "model", .expert_idx = 0, .boost = 8.0 },
            .{ .key = "mistral", .expert_idx = 0, .boost = 12.0 },
            .{ .key = "network", .expert_idx = 1, .boost = 10.0 },
            .{ .key = "stake", .expert_idx = 1, .boost = 12.0 },
            .{ .key = "vote", .expert_idx = 1, .boost = 8.0 },
            .{ .key = "p2p", .expert_idx = 1, .boost = 10.0 },
            .{ .key = "code", .expert_idx = 2, .boost = 10.0 },
            .{ .key = "generate", .expert_idx = 2, .boost = 8.0 },
            .{ .key = "implement", .expert_idx = 2, .boost = 10.0 },
            .{ .key = "qwen", .expert_idx = 2, .boost = 12.0 },
            .{ .key = "plan", .expert_idx = 3, .boost = 10.0 },
            .{ .key = "goal", .expert_idx = 3, .boost = 8.0 },
            .{ .key = "maximize", .expert_idx = 3, .boost = 10.0 },
        };

        for (keywords) |kw| {
            if (std.mem.indexOf(u8, task, kw.key) != null) {
                const base = kw.expert_idx * 16;
                for (0..16) |j| {
                    self.task_projection[base + j] += kw.boost;
                }
            }
        }

        // L2 normalize
        var norm: f32 = 0.0;
        for (self.task_projection) |v| norm += v * v;
        norm = @sqrt(norm);
        if (norm > 0.0) {
            for (&self.task_projection) |*v| v.* /= norm;
        }
    }

    /// Route a task to the best experts using top-k gating
    pub fn route(self: *Self, task: []const u8) RouteResult {
        const start_time = std.time.milliTimestamp();

        self.projectTask(task);

        var result = RouteResult{};

        // Compute expert scores using ternary matvec
        for (0..4) |i| {
            result.scores[i] = ternaryMatVec(&self.gate_weights[i], &self.task_projection);
        }

        // Softmax normalization
        var max_score: f32 = result.scores[0];
        for (result.scores[1..]) |s| if (s > max_score) {
            max_score = s;
        };

        var sum_exp: f32 = 0.0;
        for (&result.scores) |*s| {
            s.* = @exp(s.* - max_score);
            sum_exp += s.*;
        }
        for (&result.scores) |*s| s.* /= sum_exp;

        // Top-k selection
        var indices: [4]usize = .{ 0, 1, 2, 3 };
        // Simple bubble sort for top-k (k=2, so efficient)
        for (0..2) |i| {
            for (i + 1..4) |j| {
                if (result.scores[indices[j]] > result.scores[indices[i]]) {
                    const tmp = indices[i];
                    indices[i] = indices[j];
                    indices[j] = tmp;
                }
            }
        }

        result.selected[0] = result.experts[indices[0]];
        result.selected[1] = result.experts[indices[1]];
        result.selected_count = self.config.top_k;

        // Adaptive depth for mobile/low-latency
        result.latency_ms = @intCast(std.time.milliTimestamp() - start_time);
        if (self.config.adaptive_depth and result.latency_ms > self.config.latency_threshold_ms) {
            result.selected_count = 1; // Reduce to single expert
            std.debug.print("⚡ [MoE] Adaptive mode: reduced to 1 expert (latency: {d}ms)\n", .{result.latency_ms});
        }

        // Update statistics
        self.total_routes += 1;
        for (0..result.selected_count) |i| {
            self.expert_activations[@intFromEnum(result.selected[i])] += 1;
        }

        return result;
    }

    /// Print routing decision
    pub fn printRoute(result: RouteResult) void {
        std.debug.print("\n🎯 [MoE] Expert Routing Decision:\n", .{});
        std.debug.print("   Scores: Inference={d:.2} Network={d:.2} CodeGen={d:.2} Planning={d:.2}\n", .{
            result.scores[0],
            result.scores[1],
            result.scores[2],
            result.scores[3],
        });
        std.debug.print("   Selected ({d} experts):\n", .{result.selected_count});
        for (0..result.selected_count) |i| {
            std.debug.print("     {s} {s}\n", .{
                result.selected[i].getIcon(),
                result.selected[i].getName(),
            });
        }
    }

    /// Get routing statistics
    pub fn getStats(self: *Self) struct { total: u64, activations: [4]u64 } {
        return .{
            .total = self.total_routes,
            .activations = self.expert_activations,
        };
    }
};

// ============================================================================
// DEMO / TEST
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n🌟 TRINITY MoE ROUTER - PHASE 16\n", .{});
    std.debug.print("   Ternary Mixture of Experts for Agentic CLI\n\n", .{});

    var router = try MoERouter.init(allocator, .{});
    defer router.deinit();

    // Test routing scenarios
    const test_tasks = [_][]const u8{
        "Запусти инференс на Mistral-7B",
        "Застейкай 10000 TRI и проголосуй за proposal 42",
        "Сгенерируй код на Qwen2.5-Coder",
        "Максимизируй earnings на моём node",
        "Запусти инференс на Mistral, затем застейкай 10000 TRI",
    };

    for (test_tasks) |task| {
        std.debug.print("📝 Task: \"{s}\"\n", .{task});
        const result = router.route(task);
        MoERouter.printRoute(result);
        std.debug.print("\n", .{});
    }

    // Print statistics
    const stats = router.getStats();
    std.debug.print("📊 Routing Statistics:\n", .{});
    std.debug.print("   Total routes: {d}\n", .{stats.total});
    std.debug.print("   Inference activations: {d}\n", .{stats.activations[0]});
    std.debug.print("   Network activations: {d}\n", .{stats.activations[1]});
    std.debug.print("   CodeGen activations: {d}\n", .{stats.activations[2]});
    std.debug.print("   Planning activations: {d}\n", .{stats.activations[3]});

    std.debug.print("\n✅ MoE Router Phase 16 Complete!\n", .{});
}
