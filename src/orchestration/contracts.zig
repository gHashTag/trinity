//! ═══════════════════════════════════════════════════════════════════════════════
//! ORCHESTRATION CONTRACTS — Unified Configuration, Persistence, and Batch
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! This module defines normalized contracts for cross-cutting concerns:
//!   - Configuration management (load/save/validate)
//!   - Persistence (serialize/deserialize synthesis state)
//!   - Batch operations (parallel synthesis execution)
//!
//! These contracts provide:
//!   - Consistent API across forge, consciousness, and tri modules
//!   - Testability via interface contracts
//!   - Clear separation of concerns
//!
//! Usage:
//!   ```zig
//!   const contracts = @import("orchestration/contracts.zig");
//!   const IConfigManager = contracts.IConfigManager;
//!
//!   const config = try Config.load(allocator, "config.json");
//!   defer config.deinit();
//!   ```
//!
//! φ² + 1/φ² = 3 | TRINITY v2.2.0 | MU-11: Contract Normalization
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION CONTRACTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Configuration validation result
pub const ValidationResult = struct {
    valid: bool,
    errors: []const []const u8,
    warnings: []const []const u8,

    pub fn success() ValidationResult {
        return .{
            .valid = true,
            .errors = &.{},
            .warnings = &.{},
        };
    }

    pub fn fail(allocator: std.mem.Allocator, errors_list: []const []const u8) !ValidationResult {
        const errors = try allocator.dupe([]const u8, errors_list);
        return .{
            .valid = false,
            .errors = errors,
            .warnings = &.{},
        };
    }
};

/// Configuration file format
pub const ConfigFormat = enum {
    json,
    yaml,
    toml,
    auto, // Detect from extension
};

/// Configuration manager contract
///
/// Implementations must provide:
///   - load() — Load config from file
///   - save() — Save config to file
///   - validate() — Validate configuration values
///   - get() — Get config value by key
///   - set() — Set config value by key
///   - deinit() — Clean up resources
pub fn IConfigManager(comptime _: type) type {
    return struct {
        /// Verify type implements IConfigManager interface
        pub fn verify(comptime T: type) void {
            comptime {
                const checks = .{
                    hasFn(T, "load"),
                    hasFn(T, "save"),
                    hasFn(T, "validate"),
                    hasFn(T, "get"),
                    hasFn(T, "set"),
                    hasFn(T, "deinit"),
                };

                for (checks) |check| {
                    if (!check) @compileError("Type does not implement IConfigManager interface");
                }
            }
        }

        fn hasFn(comptime T: type, comptime name: []const u8) bool {
            if (!@hasDecl(T, name)) return false;
            const decl = @TypeOf(@field(T, name));
            return @typeInfo(decl) == .Fn;
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERSISTENCE CONTRACTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Serialization format
pub const SerializationFormat = enum {
    json,
    binary,
    msgpack,
};

/// Persistent state contract
///
/// Implementations must provide:
///   - serialize() — Convert state to bytes
///   - deserialize() — Restore state from bytes
///   - saveToFile() — Persist state to disk
///   - loadFromFile() — Load state from disk
///   - checksum() — Compute state integrity checksum
pub fn IPersistentState(comptime _: type) type {
    return struct {
        /// Verify type implements IPersistentState interface
        pub fn verify(comptime T: type) void {
            comptime {
                const checks = .{
                    hasFn(T, "serialize"),
                    hasFn(T, "deserialize"),
                    hasFn(T, "saveToFile"),
                    hasFn(T, "loadFromFile"),
                    hasFn(T, "checksum"),
                };

                for (checks) |check| {
                    if (!check) @compileError("Type does not implement IPersistentState interface");
                }
            }
        }

        fn hasFn(comptime T: type, comptime name: []const u8) bool {
            if (!@hasDecl(T, name)) return false;
            const decl = @TypeOf(@field(T, name));
            return @typeInfo(decl) == .Fn;
        }
    };
}

/// Checksum algorithm
pub const ChecksumAlgorithm = enum {
    crc32,
    sha256,
    xxhash,
};

/// State snapshot metadata
pub const SnapshotMetadata = struct {
    version: u32,
    timestamp: i64,
    checksum: []const u8,
    size_bytes: usize,
    compression: ?CompressionType,
};

pub const CompressionType = enum {
    none,
    gzip,
    zstd,
    lz4,
};

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH OPERATION CONTRACTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Batch execution mode
pub const BatchMode = enum {
    sequential,
    parallel,
    parallel_with_limit, // Parallel with max_concurrent limit
};

/// Batch job state
pub const JobState = enum {
    pending,
    running,
    completed,
    failed,
    cancelled,
};

/// Batch job priority
pub const JobPriority = enum(u8) {
    low = 0,
    normal = 50,
    high = 100,
    critical = 255,
};

/// Batch job metadata
pub const JobMetadata = struct {
    id: []const u8,
    name: []const u8,
    state: JobState,
    priority: JobPriority,
    created_at: i64,
    started_at: ?i64,
    completed_at: ?i64,
    error_message: ?[]const u8,
    retry_count: u32,
    max_retries: u32,
};

/// Batch executor contract
///
/// Implementations must provide:
///   - submit() — Add job to batch queue
///   - run() — Execute batch jobs
///   - cancel() — Cancel running job
///   - getStatus() — Get batch status
///   - getResults() — Get completed job results
///   - deinit() — Clean up resources
pub fn IBatchExecutor(comptime _: type, comptime _: type) type {
    return struct {
        /// Verify type implements IBatchExecutor interface
        pub fn verify(comptime T: type) void {
            comptime {
                const checks = .{
                    hasFn(T, "submit"),
                    hasFn(T, "run"),
                    hasFn(T, "cancel"),
                    hasFn(T, "getStatus"),
                    hasFn(T, "getResults"),
                    hasFn(T, "deinit"),
                };

                for (checks) |check| {
                    if (!check) @compileError("Type does not implement IBatchExecutor interface");
                }
            }
        }

        fn hasFn(comptime T: type, comptime name: []const u8) bool {
            if (!@hasDecl(T, name)) return false;
            const decl = @TypeOf(@field(T, name));
            return @typeInfo(decl) == .Fn;
        }
    };
}

/// Batch execution statistics
pub const BatchStatistics = struct {
    total_jobs: u32,
    completed_jobs: u32,
    failed_jobs: u32,
    cancelled_jobs: u32,
    total_duration_ms: u64,
    average_job_duration_ms: f64,
    throughput_jobs_per_second: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// FORGE-SPECIFIC CONTRACTS
// ═══════════════════════════════════════════════════════════════════════════════

/// FPGA synthesis state (for persistence)
pub const SynthesisState = struct {
    design_name: []const u8,
    strategy: []const u8, // "AggressiveTiming", "Conservative", "Balanced"
    phase: []const u8, // "parsed", "placed", "routed", "complete"
    timestamp: i64,
    consciousness_level: f64,
    learning_iterations: u32,

    // Placeholder for actual implementation
    pub fn serialize(self: *const SynthesisState, allocator: std.mem.Allocator) ![]u8 {
        _ = self;
        _ = allocator;
        return error.NotImplemented;
    }

    pub fn deserialize(data: []const u8, allocator: std.mem.Allocator) !SynthesisState {
        _ = data;
        _ = allocator;
        return error.NotImplemented;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DEFAULT CONFIGS
// ═══════════════════════════════════════════════════════════════════════════════

/// Default synthesis configuration
pub const SynthesisConfig = struct {
    // Toolchain
    yosys_path: []const u8 = "yosys",
    nextpnr_path: []const u8 = "nextpnr-xilinx",
    output_dir: []const u8 = "build/synth",

    // Strategy
    default_strategy: []const u8 = "Balanced",
    max_fix_iterations: u32 = 3,
    enable_auto_fix: bool = true,

    // Parallel execution
    max_parallel_jobs: u32 = 4,
    job_timeout_seconds: u32 = 300,

    // Consciousness
    enable_consciousness: bool = true,
    consciousness_threshold: f64 = 0.618,
    learning_rate: f64 = 0.01,

    // Persistence
    save_state_on_failure: bool = true,
    state_dir: []const u8 = ".forge/state",

    pub fn validate(self: *const SynthesisConfig) ValidationResult {
        // Basic validation
        if (self.max_fix_iterations > 10) {
            return ValidationResult{
                .valid = false,
                .errors = &.{"max_fix_iterations cannot exceed 10"},
                .warnings = &.{},
            };
        }
        if (self.max_parallel_jobs == 0) {
            return ValidationResult{
                .valid = false,
                .errors = &.{"max_parallel_jobs must be at least 1"},
                .warnings = &.{},
            };
        }
        return ValidationResult.success();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Contracts: IConfigManager defines required contract" {
    _ = IConfigManager(struct {});
    try std.testing.expect(true);
}

test "Contracts: IPersistentState defines required contract" {
    _ = IPersistentState(struct {});
    try std.testing.expect(true);
}

test "Contracts: IBatchExecutor defines required contract" {
    _ = IBatchExecutor(struct {}, struct {});
    try std.testing.expect(true);
}

test "Contracts: SynthesisConfig validation" {
    const config = SynthesisConfig{};
    const result = config.validate();
    try std.testing.expect(result.valid);
}

test "Contracts: SynthesisConfig validation detects invalid max_fix_iterations" {
    const config = SynthesisConfig{ .max_fix_iterations = 11 };
    const result = config.validate();
    try std.testing.expect(!result.valid);
    try std.testing.expectEqual(@as(usize, 1), result.errors.len);
}

test "Contracts: SynthesisConfig validation detects invalid max_parallel_jobs" {
    const config = SynthesisConfig{ .max_parallel_jobs = 0 };
    const result = config.validate();
    try std.testing.expect(!result.valid);
}

test "Contracts: ValidationResult success creates valid result" {
    const result = ValidationResult.success();
    try std.testing.expect(result.valid);
}

test "Contracts: JobPriority enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(JobPriority.low));
    try std.testing.expectEqual(@as(u8, 50), @intFromEnum(JobPriority.normal));
    try std.testing.expectEqual(@as(u8, 100), @intFromEnum(JobPriority.high));
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(JobPriority.critical));
}

test "Contracts: JobState enum values exist" {
    _ = JobState.pending;
    _ = JobState.running;
    _ = JobState.completed;
    _ = JobState.failed;
    _ = JobState.cancelled;
    try std.testing.expect(true);
}

// φ² + 1/φ² = 3 | TRINITY v2.2.0 | Phase 3: Architecture Refactor
