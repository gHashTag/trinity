//! Centralized Configuration Management for Trinity S³AI
//!
//! Provides unified configuration loading from JSON files,
//! environment variables, and command-line arguments.

const std = @import("std");

/// Sacred constants for default values
pub const Sacred = struct {
    pub const PHI: f64 = 1.618033988749895;
    pub const PHI_INV: f64 = 0.618033988749895;
    pub const PHI_INV_SQ: f64 = 0.3819660112501051;
    pub const PHI_INV_CUBED: f64 = 0.2360679774997897;

    pub const OPTIMAL_SPARSITY: f64 = PHI_INV_SQ; // ~0.382 non-zero
    pub const TARGET_SPARSITY: f64 = 1.0 - PHI_INV_SQ; // ~0.618 zeros
    pub const FFN_EXPANSION: f64 = PHI * PHI; // ~2.618
};

/// Learning rate schedule types
pub const LRSchedule = enum {
    constant,
    linear,
    cosine,
    sacred, // φ-based decay

    pub fn toString(self: LRSchedule) []const u8 {
        return switch (self) {
            .constant => "constant",
            .linear => "linear",
            .cosine => "cosine",
            .sacred => "sacred",
        };
    }
};

/// Scale initialization types
pub const ScaleType = enum {
    standard, // Standard initialization
    sacred, // φ-based scaling
    kaiming, // Kaiming He
    xavier, // Xavier Glorot

    pub fn toString(self: ScaleType) []const u8 {
        return switch (self) {
            .standard => "standard",
            .sacred => "sacred",
            .kaiming => "kaiming",
            .xavier => "xavier",
        };
    }
};

/// Model architecture configuration
pub const ModelConfig = struct {
    vocab_size: usize = 31000,
    hidden_dim: usize = 512,
    num_layers: usize = 6,
    num_heads: usize = 8,
    ffn_dim: usize = 0, // 0 = auto-calculate using sacred expansion
    max_seq_len: usize = 512,

    pub fn getFFNDim(self: ModelConfig) usize {
        return if (self.ffn_dim > 0)
            self.ffn_dim
        else
            @intFromFloat(@as(f64, @floatFromInt(self.hidden_dim)) * Sacred.FFN_EXPANSION);
    }

    pub fn validate(self: ModelConfig) !void {
        if (self.vocab_size == 0) return error.InvalidVocabSize;
        if (self.hidden_dim == 0) return error.InvalidHiddenDim;
        if (self.num_layers == 0) return error.InvalidNumLayers;
        if (self.num_heads == 0) return error.InvalidNumHeads;
        if (self.hidden_dim % self.num_heads != 0) return error.HiddenDimNotDivisibleByHeads;
    }
};

/// Training configuration
pub const TrainingConfig = struct {
    learning_rate: f64 = 0.001,
    lr_schedule: LRSchedule = .sacred,
    warmup_steps: u32 = 1000,
    max_steps: u32 = 30000,
    batch_size: u32 = 64,
    weight_decay: f64 = 0.01,
    gradient_clip: f64 = 1.0,

    pub fn validate(self: TrainingConfig) !void {
        if (self.learning_rate <= 0) return error.InvalidLearningRate;
        if (self.max_steps == 0) return error.InvalidMaxSteps;
        if (self.batch_size == 0) return error.InvalidBatchSize;
        if (self.weight_decay < 0) return error.InvalidWeightDecay;
        if (self.gradient_clip <= 0) return error.InvalidGradientClip;
    }

    /// Calculate learning rate at step t
    pub fn getLR(self: TrainingConfig, step: u32) f64 {
        if (step < self.warmup_steps) {
            // Linear warmup
            const warmup_frac: f64 = @as(f64, @floatFromInt(step)) / @as(f64, @floatFromInt(self.warmup_steps));
            return self.learning_rate * warmup_frac;
        }

        return switch (self.lr_schedule) {
            .constant => self.learning_rate,
            .linear => {
                const progress: f64 = @as(f64, @floatFromInt(step - self.warmup_steps)) /
                    @as(f64, @floatFromInt(self.max_steps - self.warmup_steps));
                return self.learning_rate * (1.0 - progress);
            },
            .cosine => {
                const progress: f64 = @as(f64, @floatFromInt(step - self.warmup_steps)) /
                    @as(f64, @floatFromInt(self.max_steps - self.warmup_steps));
                const cosine = 0.5 * (1.0 + std.math.cos(std.math.pi * progress));
                return self.learning_rate * cosine;
            },
            .sacred => {
                // φ-based decay: LR * φ^(-progress/φ)
                const progress: f64 = @as(f64, @floatFromInt(step - self.warmup_steps)) /
                    @as(f64, @floatFromInt(self.max_steps - self.warmup_steps));
                const decay = std.math.pow(f64, Sacred.PHI, -progress / Sacred.PHI);
                return self.learning_rate * decay;
            },
        };
    }
};

/// Sacred configuration
pub const SacredConfig = struct {
    use_sacred_scaling: bool = true,
    sacred_sparsity: f64 = Sacred.OPTIMAL_SPARSITY,
    phi_expansion: bool = true,

    pub fn validate(self: SacredConfig) !void {
        if (self.sacred_sparsity < 0 or self.sacred_sparsity > 1) return error.InvalidSparsity;
    }

    /// Get scale factor for parameter initialization
    pub fn getScaleFactor(self: SacredConfig, dim: usize) f64 {
        if (!self.use_sacred_scaling) return std.math.sqrt(2.0 / @as(f64, @floatFromInt(dim)));

        // Sacred scaling: σ = d^(-φ⁻³)
        return std.math.pow(f64, @as(f64, @floatFromInt(dim)), -Sacred.PHI_INV_CUBED);
    }

    /// Get target sparsity (fraction of zeros)
    pub fn getTargetSparsity(self: SacredConfig) f64 {
        return 1.0 - self.sacred_sparsity;
    }
};

/// Quantization configuration
pub const QuantConfig = struct {
    ternary_weights: bool = true,
    sparsity: f64 = Sacred.TARGET_SPARSITY,
    vsa_binding: bool = true,
    quantize_k: bool = true,
    quantize_v: bool = true,

    pub fn validate(self: QuantConfig) !void {
        if (self.sparsity < 0 or self.sparsity > 1) return error.InvalidSparsity;
    }
};

/// Complete Trinity configuration
pub const TrinityConfig = struct {
    model: ModelConfig = .{},
    training: TrainingConfig = .{},
    sacred: SacredConfig = .{},
    quantization: QuantConfig = .{},

    /// Validate all configurations
    pub fn validate(self: TrinityConfig) !void {
        try self.model.validate();
        try self.training.validate();
        try self.sacred.validate();
        try self.quantization.validate();
    }

    /// Get FFN dimension (calculated)
    pub fn getFFNDim(self: TrinityConfig) usize {
        return self.model.getFFNDim();
    }

    /// Get parameter initialization scale
    pub fn getInitScale(self: TrinityConfig, dim: usize) f64 {
        return self.sacred.getScaleFactor(dim);
    }
};

/// Configuration file format (JSON)
pub const ConfigFile = struct {
    version: []const u8 = "1.0",
    model: ModelConfig = .{},
    training: TrainingConfig = .{},
    sacred: SacredConfig = .{},
    quantization: QuantConfig = .{},

    /// Convert to TrinityConfig
    pub fn toTrinityConfig(self: ConfigFile) TrinityConfig {
        return .{
            .model = self.model,
            .training = self.training,
            .sacred = self.sacred,
            .quantization = self.quantization,
        };
    }
};

/// Load configuration from JSON file
pub fn loadConfig(allocator: std.mem.Allocator, path: []const u8) !TrinityConfig {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const max_size = 1024 * 1024; // 1MB max
    const source = try file.readToEndAlloc(allocator, max_size);
    defer allocator.free(source);

    const parsed = try std.json.parseFromSlice(ConfigFile, allocator, source, .{
        .ignore_unknown_fields = true,
        .allocate = .{},
    });
    defer parsed.deinit();

    const config = parsed.value.toTrinityConfig();
    try config.validate();

    return config;
}

/// Save configuration to JSON file
pub fn saveConfig(allocator: std.mem.Allocator, path: []const u8, config: TrinityConfig) !void {
    const config_file: ConfigFile = .{
        .model = config.model,
        .training = config.training,
        .sacred = config.sacred,
        .quantization = config.quantization,
    };

    const options = .{ .whitespace = .indent };
    const stringified = try std.json.stringifyAlloc(allocator, config_file, options);
    defer allocator.free(stringified);

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll(stringified);
}

/// Load configuration from environment variables
pub fn loadFromEnv() !TrinityConfig {
    var config = TrinityConfig{};

    // Training parameters
    if (std.os.getenv("HSLM_LEARNING_RATE")) |lr_str| {
        const lr = try std.fmt.parseFloat(f64, lr_str);
        config.training.learning_rate = lr;
    }

    if (std.os.getenv("HSLM_MAX_STEPS")) |steps_str| {
        const steps = try std.fmt.parseInt(u32, steps_str, 10);
        config.training.max_steps = steps;
    }

    if (std.os.getenv("HSLM_BATCH_SIZE")) |batch_str| {
        const batch = try std.fmt.parseInt(u32, batch_str, 10);
        config.training.batch_size = batch;
    }

    if (std.os.getenv("HSLM_LR_SCHEDULE")) |schedule_str| {
        config.training.lr_schedule = if (std.mem.eql(u8, schedule_str, "sacred"))
            .sacred
        else if (std.mem.eql(u8, schedule_str, "cosine"))
            .cosine
        else if (std.mem.eql(u8, schedule_str, "linear"))
            .linear
        else
            .constant;
    }

    // Sacred parameters
    if (std.os.getenv("HSLM_OPTIMIZER")) |opt_str| {
        if (std.mem.indexOf(u8, opt_str, "sacred") != null) {
            config.sacred.use_sacred_scaling = true;
        }
    }

    try config.validate();
    return config;
}

/// Get default configuration for specific model size
pub fn getDefaultHSLM1_95M() TrinityConfig {
    return .{
        .model = .{
            .vocab_size = 31000,
            .hidden_dim = 512,
            .num_layers = 6,
            .num_heads = 8,
            .ffn_dim = 0, // Auto-calculate
            .max_seq_len = 512,
        },
        .training = .{
            .learning_rate = 0.001,
            .lr_schedule = .sacred,
            .warmup_steps = 1000,
            .max_steps = 30000,
            .batch_size = 64,
            .weight_decay = 0.01,
            .gradient_clip = 1.0,
        },
        .sacred = .{
            .use_sacred_scaling = true,
            .sacred_sparsity = Sacred.OPTIMAL_SPARSITY,
            .phi_expansion = true,
        },
        .quantization = .{
            .ternary_weights = true,
            .sparsity = Sacred.TARGET_SPARSITY,
            .vsa_binding = true,
            .quantize_k = true,
            .quantize_v = true,
        },
    };
}

// Tests
test "ModelConfig validation" {
    var config = ModelConfig{};
    config.hidden_dim = 0;
    try std.testing.expectError(error.InvalidHiddenDim, config.validate());

    config = .{ .hidden_dim = 512, .num_heads = 9 }; // 512 % 9 != 0
    try std.testing.expectError(error.HiddenDimNotDivisibleByHeads, config.validate());
}

test "TrainingConfig LR schedule" {
    const config = TrainingConfig{
        .learning_rate = 0.001,
        .lr_schedule = .sacred,
        .warmup_steps = 100,
        .max_steps = 1000,
    };

    // Warmup phase
    const lr_warmup = config.getLR(50);
    try std.testing.expect(lr_warmup > 0 and lr_warmup < 0.001);

    // Sacred decay phase
    const lr_decay = config.getLR(500);
    try std.testing.expect(lr_decay > 0 and lr_decay < 0.001);

    // End of training
    const lr_end = config.getLR(999);
    try std.testing.expect(lr_end > 0);
}

test "SacredConfig scale factor" {
    const config = SacredConfig{ .use_sacred_scaling = true };

    const scale_512 = config.getScaleFactor(512);
    try std.testing.expect(scale_512 > 0 and scale_512 < 1.0);

    // Sacred scaling should be larger than standard (better gradients)
    const scale_standard = std.math.sqrt(2.0 / 512.0);
    try std.testing.expect(scale_512 > scale_standard);
}

test "Default HSLM config" {
    const config = getDefaultHSLM1_95M();
    try config.validate();

    try std.testing.expectEqual(@as(usize, 512), config.model.hidden_dim);
    try std.testing.expectEqual(@as(usize, 6), config.model.num_layers);
    try std.testing.expect(config.sacred.use_sacred_scaling);
    try std.testing.expect(config.training.lr_schedule == .sacred);

    // FFN dimension should be ~512 * 2.618 ≈ 1340
    const ffn_dim = config.getFFNDim();
    try std.testing.expect(ffn_dim >= 1300 and ffn_dim <= 1400);
}
