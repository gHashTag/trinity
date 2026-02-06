// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY HYBRID NODE - Multi-Provider LLM Integration + Mainnet
// Providers: Groq (fast), Zhipu (Chinese/long), Anthropic (quality), Cohere (free)
// Token: $TRI | Supply: 3^21 = 10,460,353,203
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const oss = @import("oss_api_client.zig");
const genesis = @import("mainnet_genesis.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// NODE CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeConfig = struct {
    /// Provider API keys (from environment)
    groq_key: ?[]const u8 = null,
    zhipu_key: ?[]const u8 = null,
    anthropic_key: ?[]const u8 = null,
    cohere_key: ?[]const u8 = null,

    /// Selection preferences
    prefer_speed: bool = true,
    prefer_free: bool = true,
    prefer_quality: bool = false,

    /// IGLA settings
    use_igla_planning: bool = true,

    /// Fallback behavior
    enable_fallback: bool = true,
    max_fallback_attempts: u8 = 3,

    pub fn fromEnv() NodeConfig {
        return .{
            .groq_key = std.posix.getenv("GROQ_API_KEY"),
            .zhipu_key = std.posix.getenv("ZHIPU_API_KEY"),
            .anthropic_key = std.posix.getenv("ANTHROPIC_API_KEY"),
            .cohere_key = std.posix.getenv("COHERE_API_KEY"),
        };
    }

    pub fn hasAnyProvider(self: NodeConfig) bool {
        return self.groq_key != null or
            self.zhipu_key != null or
            self.anthropic_key != null or
            self.cohere_key != null;
    }

    pub fn countProviders(self: NodeConfig) u8 {
        var count: u8 = 0;
        if (self.groq_key != null) count += 1;
        if (self.zhipu_key != null) count += 1;
        if (self.anthropic_key != null) count += 1;
        if (self.cohere_key != null) count += 1;
        return count;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INFERENCE REQUEST/RESPONSE
// ═══════════════════════════════════════════════════════════════════════════════

pub const InferenceRequest = struct {
    prompt: []const u8,
    max_tokens: u32 = 256,
    temperature: f32 = 0.7,
    force_provider: ?oss.ApiProvider = null,
    context_length: u32 = 0,
};

pub const InferenceResponse = struct {
    content: []const u8,
    provider: oss.ApiProvider,
    language: oss.Language,
    tokens: u32,
    elapsed_ms: u64,
    speed_tok_s: f32,
    coherent: bool,
    igla_plan: ?[]const u8,
    phi_verified: bool,
    fallback_used: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY HYBRID NODE
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityHybridNode = struct {
    config: NodeConfig,
    stats: NodeStats,
    node_state: genesis.NodeState,
    current_block: u64,

    pub const NodeStats = struct {
        total_requests: u64 = 0,
        groq_requests: u64 = 0,
        zhipu_requests: u64 = 0,
        anthropic_requests: u64 = 0,
        cohere_requests: u64 = 0,
        fallback_count: u64 = 0,
        total_tokens: u64 = 0,
        total_time_ms: u64 = 0,
        total_rewards: u64 = 0,

        pub fn avgSpeed(self: NodeStats) f32 {
            if (self.total_time_ms == 0) return 0;
            return @as(f32, @floatFromInt(self.total_tokens)) /
                (@as(f32, @floatFromInt(self.total_time_ms)) / 1000.0);
        }
    };

    pub fn init(config: NodeConfig) !TrinityHybridNode {
        if (!config.hasAnyProvider()) {
            return error.NoProvidersConfigured;
        }

        // Generate node ID from config
        var node_id: [32]u8 = undefined;
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        if (config.groq_key) |key| hasher.update(key);
        if (config.zhipu_key) |key| hasher.update(key);
        hasher.update("TRINITY_NODE");
        node_id = hasher.finalResult();

        const timestamp = @as(u64, @intCast(std.time.timestamp()));

        return TrinityHybridNode{
            .config = config,
            .stats = .{},
            .node_state = .{
                .node_id = node_id,
                .stake = 0,
                .total_rewards = 0,
                .blocks_mined = 0,
                .inferences_completed = 0,
                .tokens_processed = 0,
                .joined_at = timestamp,
                .last_active = timestamp,
            },
            .current_block = 0,
        };
    }

    pub fn initFromEnv() !TrinityHybridNode {
        return init(NodeConfig.fromEnv());
    }

    /// Join mainnet with stake
    pub fn joinMainnet(self: *TrinityHybridNode, stake_amount: u64) void {
        self.node_state.stake = stake_amount;
        self.node_state.joined_at = @as(u64, @intCast(std.time.timestamp()));
    }

    /// Calculate and claim inference reward
    pub fn claimInferenceReward(self: *TrinityHybridNode, tokens: u64, coherent: bool) u64 {
        const reward = genesis.calculateInferenceReward(tokens, coherent);
        self.node_state.total_rewards += reward;
        self.node_state.tokens_processed += tokens;
        self.node_state.inferences_completed += 1;
        self.stats.total_rewards += reward;
        return reward;
    }

    /// Get current block reward
    pub fn getBlockReward(self: *TrinityHybridNode) u64 {
        return genesis.calculateBlockReward(self.current_block);
    }

    /// Select best provider for the given prompt
    pub fn selectProvider(self: *TrinityHybridNode, prompt: []const u8, context_length: u32) oss.ApiProvider {
        const criteria = oss.SelectionCriteria{
            .prefer_speed = self.config.prefer_speed,
            .prefer_free = self.config.prefer_free,
            .prefer_quality = self.config.prefer_quality,
        };

        const selected = oss.selectProviderAdvanced(prompt, context_length, criteria);

        // Check if selected provider is available
        const available = switch (selected) {
            .groq => self.config.groq_key != null,
            .zhipu => self.config.zhipu_key != null,
            .anthropic => self.config.anthropic_key != null,
            .cohere => self.config.cohere_key != null,
            else => false,
        };

        if (available) return selected;

        // Fallback to first available
        if (self.config.groq_key != null) return .groq;
        if (self.config.cohere_key != null) return .cohere;
        if (self.config.zhipu_key != null) return .zhipu;
        if (self.config.anthropic_key != null) return .anthropic;

        return .groq; // Default
    }

    /// Execute inference with auto-provider selection
    pub fn infer(self: *TrinityHybridNode, request: InferenceRequest) !InferenceResponse {
        self.stats.total_requests += 1;

        // Detect language
        const language = oss.detectLanguage(request.prompt);

        // Select provider
        const provider = if (request.force_provider) |p|
            p
        else
            self.selectProvider(request.prompt, request.context_length);

        // Generate IGLA plan if enabled
        var igla_buffer: [4096]u8 = undefined;
        var igla_plan: ?[]const u8 = null;
        if (self.config.use_igla_planning) {
            igla_plan = try oss.generateIglaPlan(&igla_buffer, request.prompt);
        }

        // Verify φ identity
        const phi_verified = @abs(oss.verifyPhiIdentity() - 3.0) < 0.0001;

        // Update provider stats
        switch (provider) {
            .groq => self.stats.groq_requests += 1,
            .zhipu => self.stats.zhipu_requests += 1,
            .anthropic => self.stats.anthropic_requests += 1,
            .cohere => self.stats.cohere_requests += 1,
            else => {},
        }

        // For now, return a placeholder response
        // In production, this would make actual API calls
        return InferenceResponse{
            .content = "Inference result placeholder",
            .provider = provider,
            .language = language,
            .tokens = 0,
            .elapsed_ms = 0,
            .speed_tok_s = 0,
            .coherent = true,
            .igla_plan = igla_plan,
            .phi_verified = phi_verified,
            .fallback_used = false,
        };
    }

    pub fn getStats(self: *TrinityHybridNode) NodeStats {
        return self.stats;
    }

    pub fn printStatus(self: *TrinityHybridNode) void {
        std.debug.print("\n", .{});
        std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
        std.debug.print("TRINITY HYBRID NODE STATUS\n", .{});
        std.debug.print("$TRI Mainnet | Supply: 3^21 = {d}\n", .{genesis.PHOENIX_NUMBER});
        std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
        std.debug.print("Providers: {d}/4 configured\n", .{self.config.countProviders()});
        std.debug.print("  Groq:      {s}\n", .{if (self.config.groq_key != null) "✓" else "✗"});
        std.debug.print("  Zhipu:     {s}\n", .{if (self.config.zhipu_key != null) "✓" else "✗"});
        std.debug.print("  Anthropic: {s}\n", .{if (self.config.anthropic_key != null) "✓" else "✗"});
        std.debug.print("  Cohere:    {s}\n", .{if (self.config.cohere_key != null) "✓" else "✗"});
        std.debug.print("\nNode State:\n", .{});
        std.debug.print("  Stake: {d} $TRI\n", .{self.node_state.stake});
        std.debug.print("  Total rewards: {d} $TRI\n", .{self.node_state.total_rewards});
        std.debug.print("  Inferences: {d}\n", .{self.node_state.inferences_completed});
        std.debug.print("  Tokens processed: {d}\n", .{self.node_state.tokens_processed});
        std.debug.print("\nStats:\n", .{});
        std.debug.print("  Total requests: {d}\n", .{self.stats.total_requests});
        std.debug.print("  Avg speed: {d:.1} tok/s\n", .{self.stats.avgSpeed()});
        std.debug.print("  Fallbacks: {d}\n", .{self.stats.fallback_count});
        std.debug.print("  Rewards earned: {d} $TRI\n", .{self.stats.total_rewards});
        std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "node config from env" {
    const config = NodeConfig.fromEnv();
    // Just verify it doesn't crash
    _ = config.hasAnyProvider();
    _ = config.countProviders();
}

test "node config manual" {
    const config = NodeConfig{
        .groq_key = "test-key",
        .prefer_speed = true,
    };
    try std.testing.expect(config.hasAnyProvider());
    try std.testing.expectEqual(@as(u8, 1), config.countProviders());
}

test "provider selection for chinese" {
    var node = try TrinityHybridNode.init(.{
        .groq_key = "test",
        .zhipu_key = "test",
    });
    const provider = node.selectProvider("你好世界", 0);
    try std.testing.expectEqual(oss.ApiProvider.zhipu, provider);
}

test "provider selection for english" {
    var node = try TrinityHybridNode.init(.{
        .groq_key = "test",
        .zhipu_key = "test",
    });
    const provider = node.selectProvider("Hello world", 0);
    try std.testing.expectEqual(oss.ApiProvider.groq, provider);
}

test "infer returns response" {
    var node = try TrinityHybridNode.init(.{
        .groq_key = "test",
    });

    const response = try node.infer(.{
        .prompt = "test prompt",
    });

    try std.testing.expect(response.phi_verified);
    try std.testing.expectEqual(@as(u64, 1), node.stats.total_requests);
}

test "stats tracking" {
    var node = try TrinityHybridNode.init(.{
        .groq_key = "test",
    });

    _ = try node.infer(.{ .prompt = "test 1" });
    _ = try node.infer(.{ .prompt = "test 2" });
    _ = try node.infer(.{ .prompt = "test 3" });

    try std.testing.expectEqual(@as(u64, 3), node.stats.total_requests);
    try std.testing.expectEqual(@as(u64, 3), node.stats.groq_requests);
}

test "mainnet join" {
    var node = try TrinityHybridNode.init(.{
        .groq_key = "test",
    });

    // Initially no stake
    try std.testing.expectEqual(@as(u64, 0), node.node_state.stake);

    // Join with stake
    node.joinMainnet(1000);
    try std.testing.expectEqual(@as(u64, 1000), node.node_state.stake);
}

test "inference reward claim" {
    var node = try TrinityHybridNode.init(.{
        .groq_key = "test",
    });

    // Claim reward for 1000 tokens, coherent
    const reward = node.claimInferenceReward(1000, true);
    try std.testing.expectEqual(@as(u64, 2), reward); // 2x for coherent

    // Check stats updated
    try std.testing.expectEqual(@as(u64, 2), node.stats.total_rewards);
    try std.testing.expectEqual(@as(u64, 1000), node.node_state.tokens_processed);
    try std.testing.expectEqual(@as(u64, 1), node.node_state.inferences_completed);
}

test "block reward" {
    var node = try TrinityHybridNode.init(.{
        .groq_key = "test",
    });

    // Initial block reward
    const reward = node.getBlockReward();
    try std.testing.expectEqual(@as(u64, 100), reward);
}

test "phoenix number constant" {
    try std.testing.expectEqual(@as(u64, 10_460_353_203), genesis.PHOENIX_NUMBER);
}
