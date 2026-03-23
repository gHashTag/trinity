//! ═══════════════════════════════════════════════════════════════════════════════
//! OUTPUT CONFIG — Unified output directory configuration
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Single source of truth for all output directory paths in Trinity.
//!
//! φ² + 1/φ² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// ═══════════════════════════════════════════════════════════════════════════════
/// OUTPUT DIRECTORY STANDARD
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Trinity uses the following output directory structure:
///
/// ```
/// zig-out/                # Zig build artifacts (standard, cannot be changed)
///   ├── bin/              # Executables (tri, vibeec, etc.)
///   ├── lib/              # Libraries (libtrinity.a, libtrinity-vsa.so, etc.)
///   └── include/          # C headers (trinity_vsa.h, etc.)
///
/// var/trinity/output/         # Generated code and build artifacts (VIBEE, etc.)
///   ├── *.zig             # Generated Zig code from .tri specs
///   ├── *.999             # Generated 999-format code
///   └── fpga/             # Generated Verilog files
///       └── *.v           # Generated Verilog from .tri specs
/// ```
///
/// This separation ensures:
/// 1. Zig's standard build output is respected (`zig-out/`)
/// 2. Generated code is clearly separated from source (`var/trinity/output/`)
/// 3. Build artifacts are easy to clean and track
/// 4. CI/CD pipelines have clear artifact targets
/// ═══════════════════════════════════════════════════════════════════════════════
/// Default output directory for VIBEE-generated code
pub const DEFAULT_VIBEE_OUTPUT: []const u8 = "var/trinity/output";

/// Default subdirectory for FPGA/Verilog output
pub const DEFAULT_FPGA_OUTPUT: []const u8 = "var/trinity/output/fpga";

/// Output configuration
pub const OutputConfig = struct {
    /// VIBEE generated code output directory
    vibee_output: []const u8 = DEFAULT_VIBEE_OUTPUT,
    /// FPGA/Verilog output directory
    fpga_output: []const u8 = DEFAULT_FPGA_OUTPUT,

    /// Create default configuration
    pub fn init() OutputConfig {
        return .{};
    }

    /// Create configuration with custom VIBEE output
    pub fn withVibeeOutput(vibee_path: []const u8) OutputConfig {
        return .{
            .tri_output = vibee_path,
            .fpga_output = if (std.mem.endsWith(u8, vibee_path, "/fpga"))
                vibee_path
            else
                &([_]u8{} ** (vibee_path.len + "/fpga".len)) catch unreachable,
        };
    }

    /// Get output path for generated Zig file
    pub fn zigFilePath(config: OutputConfig, allocator: std.mem.Allocator, spec_name: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "{s}/{s}.zig", .{ config.tri_output, spec_name });
    }

    /// Get output path for generated 999 file
    pub fn code999Path(config: OutputConfig, allocator: std.mem.Allocator, spec_name: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "{s}/{s}.999", .{ config.tri_output, spec_name });
    }

    /// Get output path for generated Verilog file
    pub fn verilogFilePath(config: OutputConfig, allocator: std.mem.Allocator, spec_name: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "{s}/{s}.v", .{ config.fpga_output, spec_name });
    }

    /// Ensure output directories exist
    pub fn ensureDirectories(config: OutputConfig) !void {
        std.fs.cwd().makePath(config.tri_output) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
        std.fs.cwd().makePath(config.fpga_output) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
    }
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// PATH UTILITIES
/// ═══════════════════════════════════════════════════════════════════════════════
/// Get Zig's standard output directory
pub fn getZigOutPath(allocator: std.mem.Allocator) ![]u8 {
    // zig-out is Zig's standard build output
    return allocator.dupe(u8, "zig-out");
}

/// Check if path is within standard output directories
pub fn isStandardOutputPath(path: []const u8) bool {
    const zig_out_prefix = "zig-out";
    const trinity_output_prefix = "var/trinity/output";

    return std.mem.startsWith(u8, path, zig_out_prefix) or
        std.mem.startsWith(u8, path, trinity_output_prefix);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "OutputConfig: default paths" {
    const testing = std.testing;

    const config = OutputConfig.init();
    try testing.expectEqualStrings(DEFAULT_VIBEE_OUTPUT, config.tri_output);
    try testing.expectEqualStrings(DEFAULT_FPGA_OUTPUT, config.fpga_output);
}

test "OutputConfig: zig file path" {
    const testing = std.testing;

    const config = OutputConfig.init();
    const path = try config.zigFilePath(testing.allocator, "test_module");
    defer testing.allocator.free(path);

    try testing.expectEqualStrings("var/trinity/output/test_module.zig", path);
}

test "OutputConfig: verilog file path" {
    const testing = std.testing;

    const config = OutputConfig.init();
    const path = try config.verilogFilePath(testing.allocator, "test_core");
    defer testing.allocator.free(path);

    try testing.expectEqualStrings("var/trinity/output/fpga/test_core.v", path);
}

test "OutputConfig: is standard output path" {
    const testing = std.testing;

    try testing.expect(isStandardOutputPath("zig-out/bin/tri"));
    try testing.expect(isStandardOutputPath("var/trinity/output/test.zig"));
    try testing.expect(isStandardOutputPath("var/trinity/output/fpga/test.v"));
    try testing.expect(!isStandardOutputPath("src/trinity.zig"));
    try testing.expect(!isStandardOutputPath("/usr/local/bin/tri"));
}
