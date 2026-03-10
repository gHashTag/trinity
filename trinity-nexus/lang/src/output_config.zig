//! ═══════════════════════════════════════════════════════════════════════════════
//! OUTPUT CONFIG — Unified output directory configuration for VIBEE compiler
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Single source of truth for all output directory paths in VIBEE compiler.
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
/// trinity/output/         # Generated code and build artifacts (VIBEE, etc.)
///   ├── *.zig             # Generated Zig code from .vibee specs
///   ├── *.999             # Generated 999-format code
///   └── fpga/             # Generated Verilog files
///       └── *.v           # Generated Verilog from .vibee specs
/// ```
/// ═══════════════════════════════════════════════════════════════════════════════
/// Default output directory for VIBEE-generated code
pub const DEFAULT_VIBEE_OUTPUT: []const u8 = "trinity/output";

/// Default subdirectory for FPGA/Verilog output
pub const DEFAULT_FPGA_OUTPUT: []const u8 = "trinity/output/fpga";

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
    pub fn withVibeeOutput(allocator: std.mem.Allocator, vibee_path: []const u8) !OutputConfig {
        const fpga_path = try std.fmt.allocPrint(allocator, "{s}/fpga", .{vibee_path});
        return .{
            .vibee_output = vibee_path,
            .fpga_output = fpga_path,
        };
    }

    /// Get output path for generated Zig file
    pub fn zigFilePath(config: OutputConfig, allocator: std.mem.Allocator, spec_name: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "{s}/{s}.zig", .{ config.vibee_output, spec_name });
    }

    /// Get output path for generated 999 file
    pub fn code999Path(config: OutputConfig, allocator: std.mem.Allocator, spec_name: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "{s}/{s}.999", .{ config.vibee_output, spec_name });
    }

    /// Get output path for generated Verilog file
    pub fn verilogFilePath(config: OutputConfig, allocator: std.mem.Allocator, spec_name: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "{s}/{s}.v", .{ config.fpga_output, spec_name });
    }

    /// Ensure output directories exist
    pub fn ensureDirectories(config: OutputConfig) !void {
        std.fs.cwd().makePath(config.vibee_output) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
        std.fs.cwd().makePath(config.fpga_output) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
    }
};

/// Get default output configuration
pub fn getDefaultConfig() OutputConfig {
    return OutputConfig.init();
}
