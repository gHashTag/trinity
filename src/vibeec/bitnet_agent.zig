// ═══════════════════════════════════════════════════════════════════════════════
// BITNET AGENT - Local Coherent Inference via FFI
// ═══════════════════════════════════════════════════════════════════════════════
//
// Trinity Agent powered by BitNet b1.58-2B-4T for local coherent text generation.
// Uses official bitnet.cpp via subprocess FFI for reliable 16+ tok/s inference.
//
// No cloud APIs needed - fully local ternary AI!
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const bitnet_ffi = @import("bitnet_ffi.zig");

pub const BitNetAgentError = error{
    InferenceError,
    ParseError,
    MaxStepsReached,
    OutOfMemory,
    ModelNotFound,
};

pub const AgentConfig = struct {
    llama_cli_path: []const u8 = "bitnet-cpp/build/bin/llama-cli",
    model_path: []const u8 = "bitnet-cpp/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf",
    threads: u32 = 8,
    max_tokens: u32 = 200,
    temperature: f32 = 0.7,
    max_steps: u32 = 5,
    verbose: bool = true,
};

pub const AgentStep = struct {
    step_num: u32,
    thought: []const u8,
    action: []const u8,
    observation: []const u8,
    tokens_generated: usize,
    elapsed_ms: f64,
};

pub const AgentResult = struct {
    success: bool,
    answer: ?[]const u8,
    steps: u32,
    total_tokens: usize,
    total_time_ms: f64,
    tok_per_sec: f64,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *AgentResult) void {
        if (self.answer) |ans| {
            self.allocator.free(ans);
        }
    }
};

pub const BitNetAgent = struct {
    allocator: std.mem.Allocator,
    config: AgentConfig,
    ffi: bitnet_ffi.BitNetFFI,
    history: std.ArrayListUnmanaged([]const u8),
    total_tokens: usize,
    total_time_ms: f64,

    const Self = @This();

    const SYSTEM_PROMPT =
        \\You are a helpful AI assistant running locally on BitNet b1.58 ternary model.
        \\You are part of the Trinity network - a decentralized AI infrastructure.
        \\
        \\You solve tasks step by step. Available tools:
        \\- infer: Run additional inference
        \\- calculate: Math operations
        \\- final_answer: Provide your final answer
        \\
        \\Format:
        \\Thought: [reasoning]
        \\Action: [tool]
        \\Answer: [response]
        \\
        \\Be concise and helpful.
    ;

    pub fn init(allocator: std.mem.Allocator, config: AgentConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .ffi = bitnet_ffi.BitNetFFI.init(
                allocator,
                config.llama_cli_path,
                config.model_path,
                config.threads,
            ),
            .history = .{},
            .total_tokens = 0,
            .total_time_ms = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.history.items) |item| {
            self.allocator.free(item);
        }
        self.history.deinit(self.allocator);
    }

    /// Generate coherent response for a task
    pub fn think(self: *Self, task: []const u8) ![]const u8 {
        // Build prompt with context
        const prompt = try std.fmt.allocPrint(
            self.allocator,
            "{s}\n\nTask: {s}\n\nThought:",
            .{ SYSTEM_PROMPT, task },
        );
        defer self.allocator.free(prompt);

        // Call BitNet FFI for coherent generation
        const result = try self.ffi.generate(
            prompt,
            self.config.max_tokens,
            self.config.temperature,
        );

        self.total_tokens += result.text.len / 4; // Approx tokens
        self.total_time_ms += result.elapsed_ms;

        if (self.config.verbose) {
            const tok_s = if (result.elapsed_ms > 0)
                @as(f64, @floatFromInt(result.text.len / 4)) / (result.elapsed_ms / 1000.0)
            else
                0.0;
            std.debug.print("  [BitNet] Generated {d} chars in {d:.0}ms ({d:.1} tok/s)\n", .{
                result.text.len,
                result.elapsed_ms,
                tok_s,
            });
        }

        // Add to history
        const history_entry = try self.allocator.dupe(u8, result.text);
        try self.history.append(self.allocator, history_entry);

        // Return the generated text (caller owns full_output)
        self.allocator.free(result.full_output);
        return result.text;
    }

    /// Run agent on a task with ReAct loop
    pub fn run(self: *Self, task: []const u8) BitNetAgentError!AgentResult {
        const start_time = std.time.nanoTimestamp();

        // Clear history for new task
        for (self.history.items) |item| {
            self.allocator.free(item);
        }
        self.history.clearRetainingCapacity();
        self.total_tokens = 0;
        self.total_time_ms = 0;

        if (self.config.verbose) {
            std.debug.print("\n", .{});
            std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
            std.debug.print("║     BITNET AGENT — LOCAL COHERENT INFERENCE                  ║\n", .{});
            std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
            std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
            std.debug.print("\nTask: \"{s}\"\n", .{task});
        }

        var step: u32 = 0;
        var final_answer: ?[]const u8 = null;

        while (step < self.config.max_steps) : (step += 1) {
            if (self.config.verbose) {
                std.debug.print("\n--- Step {d}/{d} ---\n", .{ step + 1, self.config.max_steps });
            }

            // Generate response
            const response = self.think(task) catch |err| {
                if (self.config.verbose) {
                    std.debug.print("  Error: {}\n", .{err});
                }
                return BitNetAgentError.InferenceError;
            };
            defer self.allocator.free(response);

            if (self.config.verbose) {
                // Show first 500 chars
                const display_len = @min(response.len, 500);
                std.debug.print("  Response: \"{s}\"\n", .{response[0..display_len]});
                if (response.len > 500) {
                    std.debug.print("  ... [{d} more chars]\n", .{response.len - 500});
                }
            }

            // Check for final answer or completion
            if (self.containsFinalAnswer(response) or step == self.config.max_steps - 1) {
                final_answer = self.allocator.dupe(u8, response) catch return BitNetAgentError.OutOfMemory;
                break;
            }
        }

        const end_time = std.time.nanoTimestamp();
        const total_ns = @as(f64, @floatFromInt(end_time - start_time));

        const tok_per_sec = if (self.total_time_ms > 0)
            @as(f64, @floatFromInt(self.total_tokens)) / (self.total_time_ms / 1000.0)
        else
            0.0;

        if (self.config.verbose) {
            std.debug.print("\n═══════════════════════════════════════════════════════════════\n", .{});
            std.debug.print("Agent completed in {d} steps\n", .{step + 1});
            std.debug.print("Total: ~{d} tokens in {d:.0}ms = {d:.1} tok/s\n", .{
                self.total_tokens,
                self.total_time_ms,
                tok_per_sec,
            });
        }

        return AgentResult{
            .success = final_answer != null,
            .answer = final_answer,
            .steps = step + 1,
            .total_tokens = self.total_tokens,
            .total_time_ms = total_ns / 1e6,
            .tok_per_sec = tok_per_sec,
            .allocator = self.allocator,
        };
    }

    fn containsFinalAnswer(self: *Self, response: []const u8) bool {
        _ = self;
        return std.mem.indexOf(u8, response, "Answer:") != null or
            std.mem.indexOf(u8, response, "final_answer") != null or
            std.mem.indexOf(u8, response, "Therefore") != null or
            std.mem.indexOf(u8, response, "In conclusion") != null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE - Local AI Node with BitNet Coherent Inference
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityNode = struct {
    allocator: std.mem.Allocator,
    agent: BitNetAgent,
    node_id: []const u8,
    total_requests: usize,
    total_tokens_generated: usize,
    uptime_start: i64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, node_id: []const u8, config: AgentConfig) Self {
        return Self{
            .allocator = allocator,
            .agent = BitNetAgent.init(allocator, config),
            .node_id = node_id,
            .total_requests = 0,
            .total_tokens_generated = 0,
            .uptime_start = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.agent.deinit();
    }

    /// Process a request on this node
    pub fn processRequest(self: *Self, task: []const u8) !AgentResult {
        self.total_requests += 1;

        std.debug.print("\n[Node {s}] Processing request #{d}\n", .{
            self.node_id,
            self.total_requests,
        });

        const result = try self.agent.run(task);
        self.total_tokens_generated += result.total_tokens;

        return result;
    }

    /// Get node statistics
    pub fn getStats(self: *Self) NodeStats {
        const uptime = std.time.timestamp() - self.uptime_start;
        return NodeStats{
            .node_id = self.node_id,
            .total_requests = self.total_requests,
            .total_tokens = self.total_tokens_generated,
            .uptime_seconds = @intCast(uptime),
            .avg_tok_per_request = if (self.total_requests > 0)
                @as(f64, @floatFromInt(self.total_tokens_generated)) / @as(f64, @floatFromInt(self.total_requests))
            else
                0.0,
        };
    }
};

pub const NodeStats = struct {
    node_id: []const u8,
    total_requests: usize,
    total_tokens: usize,
    uptime_seconds: u64,
    avg_tok_per_request: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN - Demo Trinity Node with BitNet
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
    std.debug.print("║     TRINITY NODE — LOCAL BITNET COHERENT INFERENCE           ║\n", .{});
    std.debug.print("║     Powered by BitNet b1.58-2B-4T via FFI                    ║\n", .{});
    std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    std.debug.print("\nConfiguration:\n", .{});
    std.debug.print("  llama-cli: {s}\n", .{llama_cli});
    std.debug.print("  Model: {s}\n", .{model_path});
    std.debug.print("  Node ID: trinity-node-kosamui-01\n", .{});

    // Initialize Trinity Node
    var node = TrinityNode.init(allocator, "trinity-node-kosamui-01", .{
        .llama_cli_path = llama_cli,
        .model_path = model_path,
        .threads = 8,
        .max_tokens = 150,
        .temperature = 0.7,
        .max_steps = 1, // Single generation for demo
        .verbose = true,
    });
    defer node.deinit();

    // Demo tasks for Trinity Node
    const tasks = [_][]const u8{
        "Explain what is ternary computing in one paragraph",
        "What is the golden ratio and why is it special?",
        "Describe how neural networks learn",
        "What makes BitNet different from traditional models?",
        "Explain decentralized AI in simple terms",
    };

    std.debug.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     TRINITY NODE COHERENT GENERATION DEMO                     \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    for (tasks, 0..) |task, i| {
        std.debug.print("\n[Request {d}/{d}] \"{s}\"\n", .{ i + 1, tasks.len, task });

        var result = node.processRequest(task) catch |err| {
            std.debug.print("  Error: {}\n", .{err});
            continue;
        };
        defer result.deinit();

        if (result.answer) |answer| {
            const display_len = @min(answer.len, 400);
            std.debug.print("\n  Answer ({d:.1} tok/s):\n", .{result.tok_per_sec});
            std.debug.print("  \"{s}\"\n", .{answer[0..display_len]});
            if (answer.len > 400) {
                std.debug.print("  ... [{d} more chars]\n", .{answer.len - 400});
            }
        }
    }

    // Print node statistics
    const stats = node.getStats();
    std.debug.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     NODE STATISTICS                                           \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Node ID: {s}\n", .{stats.node_id});
    std.debug.print("  Total Requests: {d}\n", .{stats.total_requests});
    std.debug.print("  Total Tokens: {d}\n", .{stats.total_tokens});
    std.debug.print("  Uptime: {d} seconds\n", .{stats.uptime_seconds});
    std.debug.print("  Avg Tokens/Request: {d:.1}\n", .{stats.avg_tok_per_request});

    std.debug.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL\n", .{});
}

test "BitNetAgent init" {
    const allocator = std.testing.allocator;
    var agent = BitNetAgent.init(allocator, .{});
    defer agent.deinit();
}

test "TrinityNode init" {
    const allocator = std.testing.allocator;
    var node = TrinityNode.init(allocator, "test-node", .{});
    defer node.deinit();

    const stats = node.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats.total_requests);
}

test "phi constant verification" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}
