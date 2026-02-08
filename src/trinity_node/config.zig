// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE CONFIG - Configuration Management
// Settings persistence and defaults
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const discovery = @import("discovery.zig");
const network = @import("network.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// DEFAULT PATHS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DEFAULT_CONFIG_DIR = ".trinity";
pub const DEFAULT_WALLET_FILE = "wallet.enc";
pub const DEFAULT_CONFIG_FILE = "config.json";
pub const DEFAULT_MODEL_DIR = "models";

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Config = struct {
    // Network
    discovery_port: u16 = discovery.DISCOVERY_PORT,
    job_port: u16 = network.JOB_PORT,
    bootstrap_nodes: []const []const u8 = &discovery.DEFAULT_BOOTSTRAP_NODES,

    // Resource limits
    max_cpu_percent: u8 = 80,
    max_memory_mb: u32 = 4096,
    max_concurrent_jobs: u8 = 4,

    // Model
    model_path: []const u8 = "models/tinyllama-q6k.gguf",
    max_batch_size: u32 = 1,
    max_context_length: u32 = 2048,

    // Inference
    default_temperature: f32 = 0.7,
    default_top_p: f32 = 0.9,
    default_max_tokens: u32 = 256,

    // UI
    window_width: u32 = 1280,
    window_height: u32 = 800,
    theme: Theme = .dark,

    // Behavior
    auto_start: bool = false,
    minimize_to_tray: bool = true,
    show_notifications: bool = true,

    pub const Theme = enum {
        dark,
        light,
    };

    /// Get home directory path
    pub fn getHomeDir() ![]const u8 {
        return std.posix.getenv("HOME") orelse return error.NoHomeDir;
    }

    /// Get config directory path
    pub fn getConfigDir(allocator: std.mem.Allocator) ![]u8 {
        const home = try getHomeDir();
        return std.fmt.allocPrint(allocator, "{s}/{s}", .{ home, DEFAULT_CONFIG_DIR });
    }

    /// Get wallet file path
    pub fn getWalletPath(allocator: std.mem.Allocator) ![]u8 {
        const config_dir = try getConfigDir(allocator);
        defer allocator.free(config_dir);
        return std.fmt.allocPrint(allocator, "{s}/{s}", .{ config_dir, DEFAULT_WALLET_FILE });
    }

    /// Get config file path
    pub fn getConfigPath(allocator: std.mem.Allocator) ![]u8 {
        const config_dir = try getConfigDir(allocator);
        defer allocator.free(config_dir);
        return std.fmt.allocPrint(allocator, "{s}/{s}", .{ config_dir, DEFAULT_CONFIG_FILE });
    }

    /// Get model directory path
    pub fn getModelDir(allocator: std.mem.Allocator) ![]u8 {
        const config_dir = try getConfigDir(allocator);
        defer allocator.free(config_dir);
        return std.fmt.allocPrint(allocator, "{s}/{s}", .{ config_dir, DEFAULT_MODEL_DIR });
    }

    /// Load config from file
    pub fn load(allocator: std.mem.Allocator) !Config {
        const path = try getConfigPath(allocator);
        defer allocator.free(path);

        const file = std.fs.cwd().openFile(path, .{}) catch {
            // Return default config if file doesn't exist
            return Config{};
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(content);

        // Parse JSON (simplified - in real impl would use std.json)
        // For now, return default
        return Config{};
    }

    /// Save config to file
    pub fn save(self: *const Config, allocator: std.mem.Allocator) !void {
        const config_dir = try getConfigDir(allocator);
        defer allocator.free(config_dir);

        // Ensure config directory exists
        std.fs.cwd().makePath(config_dir) catch {};

        const path = try getConfigPath(allocator);
        defer allocator.free(path);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        // Write JSON (simplified)
        try file.writeAll("{\n");
        try file.writer().print("  \"discovery_port\": {d},\n", .{self.discovery_port});
        try file.writer().print("  \"job_port\": {d},\n", .{self.job_port});
        try file.writer().print("  \"max_cpu_percent\": {d},\n", .{self.max_cpu_percent});
        try file.writer().print("  \"max_memory_mb\": {d},\n", .{self.max_memory_mb});
        try file.writer().print("  \"auto_start\": {s},\n", .{if (self.auto_start) "true" else "false"});
        try file.writer().print("  \"model_path\": \"{s}\"\n", .{self.model_path});
        try file.writeAll("}\n");
    }

    /// Ensure all directories exist
    pub fn ensureDirectories(allocator: std.mem.Allocator) !void {
        const config_dir = try getConfigDir(allocator);
        defer allocator.free(config_dir);
        std.fs.cwd().makePath(config_dir) catch {};

        const model_dir = try getModelDir(allocator);
        defer allocator.free(model_dir);
        std.fs.cwd().makePath(model_dir) catch {};
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// RUNTIME STATE
// ═══════════════════════════════════════════════════════════════════════════════

pub const RuntimeState = struct {
    config: Config,
    is_running: bool,
    is_processing: bool,
    current_job_id: ?[16]u8,
    last_error: ?[]const u8,

    pub fn init(config: Config) RuntimeState {
        return RuntimeState{
            .config = config,
            .is_running = false,
            .is_processing = false,
            .current_job_id = null,
            .last_error = null,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "default config values" {
    const config = Config{};
    try std.testing.expectEqual(@as(u16, 9333), config.discovery_port);
    try std.testing.expectEqual(@as(u8, 80), config.max_cpu_percent);
    try std.testing.expectEqual(Config.Theme.dark, config.theme);
}

test "config paths" {
    const allocator = std.testing.allocator;

    if (Config.getConfigDir(allocator)) |dir| {
        defer allocator.free(dir);
        try std.testing.expect(dir.len > 0);
    } else |_| {
        // No home dir in test environment is OK
    }
}
