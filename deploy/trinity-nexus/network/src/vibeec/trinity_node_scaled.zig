// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE SCALED - Optimized Multi-Task Node with Metal GPU
// ═══════════════════════════════════════════════════════════════════════════════
//
// Optimized Trinity Node with:
// - Metal GPU acceleration (M1 Pro 14-core)
// - Multi-task capabilities (generation, sentiment, topic, QA)
// - Reduced FFI overhead
// - Batch processing
//
// Target: Maximum throughput on Apple Silicon
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const TaskType = enum {
    Generation,
    Sentiment,
    Topic,
    QA,
    Summarize,

    pub fn getName(self: TaskType) []const u8 {
        return switch (self) {
            .Generation => "generation",
            .Sentiment => "sentiment",
            .Topic => "topic",
            .QA => "qa",
            .Summarize => "summarize",
        };
    }

    pub fn getPromptTemplate(self: TaskType) []const u8 {
        return switch (self) {
            .Generation => "Continue this text:\n{s}\n\nContinuation:",
            .Sentiment => "Analyze the sentiment (positive/negative/neutral) of this text:\n{s}\n\nSentiment:",
            .Topic => "What is the main topic of this text? Answer in one word:\n{s}\n\nTopic:",
            .QA => "Answer concisely:\n{s}\n\nAnswer:",
            .Summarize => "Summarize in one sentence:\n{s}\n\nSummary:",
        };
    }

    pub fn getDefaultTokens(self: TaskType) u32 {
        return switch (self) {
            .Generation => 100,
            .Sentiment => 20,
            .Topic => 10,
            .QA => 50,
            .Summarize => 50,
        };
    }
};

pub const TaskRequest = struct {
    task_type: TaskType,
    input: []const u8,
    max_tokens: ?u32 = null,
};

pub const TaskResult = struct {
    task_type: TaskType,
    input: []const u8,
    output: []const u8,
    tokens: usize,
    elapsed_ms: f64,
    tok_per_sec: f64,
    success: bool,
};

pub const NodeConfig = struct {
    llama_cli_path: []const u8 = "bitnet-cpp/build/bin/llama-cli",
    model_path: []const u8 = "bitnet-cpp/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf",
    threads: u32 = 8,
    temperature: f32 = 0.7,
    gpu_layers: u32 = 31, // All layers on GPU
};

pub const NodeStats = struct {
    node_id: []const u8,
    total_requests: usize,
    total_tokens: usize,
    total_time_ms: f64,
    avg_tok_per_sec: f64,
    requests_by_type: [5]usize, // One per TaskType
    uptime_seconds: u64,
};

pub const ScaledTrinityNode = struct {
    allocator: std.mem.Allocator,
    config: NodeConfig,
    node_id: []const u8,
    total_requests: usize,
    total_tokens: usize,
    total_time_ms: f64,
    requests_by_type: [5]usize,
    uptime_start: i64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, node_id: []const u8, config: NodeConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .node_id = node_id,
            .total_requests = 0,
            .total_tokens = 0,
            .total_time_ms = 0,
            .requests_by_type = [_]usize{0} ** 5,
            .uptime_start = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Process a single task
    pub fn processTask(self: *Self, request: TaskRequest) !TaskResult {
        const max_tokens = request.max_tokens orelse request.task_type.getDefaultTokens();

        // Build optimized prompt (shorter = faster)
        const prompt = try self.buildPrompt(request.task_type, request.input);
        defer self.allocator.free(prompt);

        // Call BitNet via subprocess
        const result = try self.callBitNet(prompt, max_tokens);
        defer self.allocator.free(result.full_output);

        // Update stats
        self.total_requests += 1;
        self.total_tokens += result.tokens;
        self.total_time_ms += result.elapsed_ms;
        self.requests_by_type[@intFromEnum(request.task_type)] += 1;

        const tok_per_sec = if (result.elapsed_ms > 0)
            @as(f64, @floatFromInt(result.tokens)) / (result.elapsed_ms / 1000.0)
        else
            0.0;

        return TaskResult{
            .task_type = request.task_type,
            .input = request.input,
            .output = result.output,
            .tokens = result.tokens,
            .elapsed_ms = result.elapsed_ms,
            .tok_per_sec = tok_per_sec,
            .success = result.success,
        };
    }

    const BitNetResult = struct {
        output: []const u8,
        full_output: []const u8,
        tokens: usize,
        elapsed_ms: f64,
        success: bool,
    };

    fn callBitNet(self: *Self, prompt: []const u8, max_tokens: u32) !BitNetResult {
        var timer = try std.time.Timer.start();

        // Build command arguments
        var args: std.ArrayListUnmanaged([]const u8) = .{};
        defer args.deinit(self.allocator);

        try args.append(self.allocator, self.config.llama_cli_path);
        try args.append(self.allocator, "-m");
        try args.append(self.allocator, self.config.model_path);
        try args.append(self.allocator, "-p");
        try args.append(self.allocator, prompt);
        try args.append(self.allocator, "-n");

        var n_buf: [16]u8 = undefined;
        const n_str = std.fmt.bufPrint(&n_buf, "{d}", .{max_tokens}) catch "50";
        try args.append(self.allocator, n_str);

        try args.append(self.allocator, "-t");
        var t_buf: [16]u8 = undefined;
        const t_str = std.fmt.bufPrint(&t_buf, "{d}", .{self.config.threads}) catch "8";
        try args.append(self.allocator, t_str);

        try args.append(self.allocator, "--temp");
        var temp_buf: [16]u8 = undefined;
        const temp_str = std.fmt.bufPrint(&temp_buf, "{d:.2}", .{self.config.temperature}) catch "0.7";
        try args.append(self.allocator, temp_str);

        // GPU layers (Metal)
        try args.append(self.allocator, "-ngl");
        var ngl_buf: [16]u8 = undefined;
        const ngl_str = std.fmt.bufPrint(&ngl_buf, "{d}", .{self.config.gpu_layers}) catch "31";
        try args.append(self.allocator, ngl_str);

        // Suppress output
        try args.append(self.allocator, "--no-warmup");

        // Run subprocess
        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = args.items,
            .max_output_bytes = 1024 * 1024,
        });
        defer self.allocator.free(result.stderr);

        const elapsed_ns = timer.read();

        // Parse output
        const output = try self.parseOutput(result.stdout, prompt);
        const tokens = output.len / 4; // Approx

        const success = switch (result.term) {
            .Exited => |code| code == 0,
            else => false,
        };

        return BitNetResult{
            .output = output,
            .full_output = result.stdout,
            .tokens = tokens,
            .elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1e6,
            .success = success,
        };
    }

    fn parseOutput(self: *Self, output: []const u8, prompt: []const u8) ![]const u8 {
        // Find the prompt in output and extract everything after it
        if (std.mem.indexOf(u8, output, prompt)) |prompt_start| {
            const after_prompt = output[prompt_start + prompt.len ..];
            // Find end
            if (std.mem.indexOf(u8, after_prompt, "\n\nllama_perf")) |end| {
                return try self.allocator.dupe(u8, std.mem.trim(u8, after_prompt[0..end], " \n\t"));
            }
            if (std.mem.indexOf(u8, after_prompt, "\nllama_perf")) |end| {
                return try self.allocator.dupe(u8, std.mem.trim(u8, after_prompt[0..end], " \n\t"));
            }
            return try self.allocator.dupe(u8, std.mem.trim(u8, after_prompt, " \n\t"));
        }
        return try self.allocator.dupe(u8, output);
    }

    /// Process multiple tasks (batch)
    pub fn processBatch(self: *Self, requests: []const TaskRequest) ![]TaskResult {
        var results = try self.allocator.alloc(TaskResult, requests.len);

        for (requests, 0..) |request, i| {
            results[i] = try self.processTask(request);
        }

        return results;
    }

    fn buildPrompt(self: *Self, task_type: TaskType, input: []const u8) ![]u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .{};
        errdefer buffer.deinit(self.allocator);

        switch (task_type) {
            .Generation => {
                try buffer.appendSlice(self.allocator, "Continue this text:\n");
                try buffer.appendSlice(self.allocator, input);
                try buffer.appendSlice(self.allocator, "\n\nContinuation:");
            },
            .Sentiment => {
                try buffer.appendSlice(self.allocator, "Analyze sentiment (positive/negative/neutral):\n");
                try buffer.appendSlice(self.allocator, input);
                try buffer.appendSlice(self.allocator, "\n\nSentiment:");
            },
            .Topic => {
                try buffer.appendSlice(self.allocator, "Main topic in one word:\n");
                try buffer.appendSlice(self.allocator, input);
                try buffer.appendSlice(self.allocator, "\n\nTopic:");
            },
            .QA => {
                try buffer.appendSlice(self.allocator, "Answer concisely:\n");
                try buffer.appendSlice(self.allocator, input);
                try buffer.appendSlice(self.allocator, "\n\nAnswer:");
            },
            .Summarize => {
                try buffer.appendSlice(self.allocator, "Summarize in one sentence:\n");
                try buffer.appendSlice(self.allocator, input);
                try buffer.appendSlice(self.allocator, "\n\nSummary:");
            },
        }

        return buffer.toOwnedSlice(self.allocator);
    }

    /// Get node statistics
    pub fn getStats(self: *Self) NodeStats {
        const uptime = std.time.timestamp() - self.uptime_start;
        const avg_tok = if (self.total_time_ms > 0)
            @as(f64, @floatFromInt(self.total_tokens)) / (self.total_time_ms / 1000.0)
        else
            0.0;

        return NodeStats{
            .node_id = self.node_id,
            .total_requests = self.total_requests,
            .total_tokens = self.total_tokens,
            .total_time_ms = self.total_time_ms,
            .avg_tok_per_sec = avg_tok,
            .requests_by_type = self.requests_by_type,
            .uptime_seconds = @intCast(uptime),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN - Multi-Task Demo
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const llama_cli = if (args.len > 1) args[1] else "bitnet-cpp/build/bin/llama-cli";
    const model_path = if (args.len > 2) args[2] else "bitnet-cpp/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf";

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     TRINITY NODE SCALED — METAL GPU + MULTI-TASK             ║\n", .{});
    std.debug.print("║     Apple M1 Pro (14-core GPU) | BitNet b1.58-2B-4T          ║\n", .{});
    std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    std.debug.print("\nConfiguration:\n", .{});
    std.debug.print("  llama-cli: {s}\n", .{llama_cli});
    std.debug.print("  Model: {s}\n", .{model_path});
    std.debug.print("  GPU Layers: 31 (full Metal offload)\n", .{});
    std.debug.print("  Node ID: trinity-scaled-kosamui-01\n", .{});

    // Initialize Node
    var node = ScaledTrinityNode.init(allocator, "trinity-scaled-kosamui-01", .{
        .llama_cli_path = llama_cli,
        .model_path = model_path,
        .threads = 8,
        .gpu_layers = 31,
        .temperature = 0.7,
    });
    defer node.deinit();

    // Multi-task demo requests
    const tasks = [_]TaskRequest{
        // Generation tasks
        .{ .task_type = .Generation, .input = "The future of AI is" },
        .{ .task_type = .Generation, .input = "Ternary computing enables" },

        // QA tasks
        .{ .task_type = .QA, .input = "What is the golden ratio?" },
        .{ .task_type = .QA, .input = "How does a neural network learn?" },
        .{ .task_type = .QA, .input = "What is decentralized AI?" },

        // Sentiment tasks
        .{ .task_type = .Sentiment, .input = "I love how efficient BitNet is!" },
        .{ .task_type = .Sentiment, .input = "The slow speed is disappointing." },

        // Topic tasks
        .{ .task_type = .Topic, .input = "Bitcoin mining consumes a lot of electricity compared to proof of stake systems." },
        .{ .task_type = .Topic, .input = "The Eiffel Tower was built in 1889 for the World's Fair in Paris." },

        // Summarize tasks
        .{ .task_type = .Summarize, .input = "Machine learning models require large amounts of data for training. They learn patterns from this data to make predictions. Deep learning is a subset that uses neural networks with many layers." },
    };

    std.debug.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     MULTI-TASK BENCHMARK ({d} requests)                       \n", .{tasks.len});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    for (tasks, 0..) |task, i| {
        std.debug.print("\n[{d}/{d}] {s}: \"{s}\"\n", .{
            i + 1,
            tasks.len,
            task.task_type.getName(),
            task.input[0..@min(task.input.len, 50)],
        });
        if (task.input.len > 50) std.debug.print("...\n", .{});

        const result = node.processTask(task) catch |err| {
            std.debug.print("  Error: {}\n", .{err});
            continue;
        };
        defer allocator.free(result.output);

        std.debug.print("  Time: {d:.0}ms | Tokens: ~{d} | Speed: {d:.1} tok/s\n", .{
            result.elapsed_ms,
            result.tokens,
            result.tok_per_sec,
        });

        // Show output (truncated)
        const display_len = @min(result.output.len, 200);
        std.debug.print("  Output: \"{s}\"\n", .{result.output[0..display_len]});
        if (result.output.len > 200) {
            std.debug.print("  ... [{d} more chars]\n", .{result.output.len - 200});
        }
    }

    // Print statistics
    const stats = node.getStats();

    std.debug.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     NODE STATISTICS                                           \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Node ID: {s}\n", .{stats.node_id});
    std.debug.print("  Total Requests: {d}\n", .{stats.total_requests});
    std.debug.print("  Total Tokens: {d}\n", .{stats.total_tokens});
    std.debug.print("  Total Time: {d:.0}ms\n", .{stats.total_time_ms});
    std.debug.print("  Average Speed: {d:.1} tok/s\n", .{stats.avg_tok_per_sec});
    std.debug.print("  Uptime: {d} seconds\n", .{stats.uptime_seconds});
    std.debug.print("\n  Requests by Type:\n", .{});
    std.debug.print("    Generation: {d}\n", .{stats.requests_by_type[0]});
    std.debug.print("    Sentiment:  {d}\n", .{stats.requests_by_type[1]});
    std.debug.print("    Topic:      {d}\n", .{stats.requests_by_type[2]});
    std.debug.print("    QA:         {d}\n", .{stats.requests_by_type[3]});
    std.debug.print("    Summarize:  {d}\n", .{stats.requests_by_type[4]});

    // Performance summary
    std.debug.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     PERFORMANCE SUMMARY                                       \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  GPU: Apple M1 Pro (14-core, Metal 3)\n", .{});
    std.debug.print("  Model: BitNet b1.58-2B-4T (ternary)\n", .{});
    std.debug.print("  Offload: 31/31 layers on GPU\n", .{});
    std.debug.print("  Average: {d:.1} tok/s\n", .{stats.avg_tok_per_sec});
    std.debug.print("  Throughput: {d:.1} tokens/minute\n", .{stats.avg_tok_per_sec * 60.0});

    std.debug.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL\n", .{});
}

test "TaskType templates" {
    try std.testing.expect(TaskType.Generation.getDefaultTokens() > 0);
    try std.testing.expect(TaskType.Sentiment.getDefaultTokens() < TaskType.Generation.getDefaultTokens());
}

test "ScaledTrinityNode init" {
    const allocator = std.testing.allocator;
    var node = ScaledTrinityNode.init(allocator, "test-node", .{});
    defer node.deinit();

    const stats = node.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats.total_requests);
}
