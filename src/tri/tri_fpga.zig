// ═══════════════════════════════════════════════════════════════════════════════
// TRI FPGA Commands — Single entry point for .tri → .bit synthesis
// ═══════════════════════════════════════════════════════════════════════════════
//
// Implements `tri fpga build` command as SSOT for FPGA synthesis.
//
// Flow: .vibee/.v → VIBEE → Verilog → openXC7 Docker → .bit
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Run `tri fpga build` command
pub fn runFpgaBuildCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        return printUsage(allocator);
    }

    const input = args[0];
    const ext = std.fs.path.extension(input);

    // Validate input type
    const is_vibee = std.mem.eql(u8, ext, ".vibee");
    const is_verilog = std.mem.eql(u8, ext, ".v");

    if (!is_vibee and !is_verilog) {
        std.debug.print("Error: Unsupported input type: {s}\n", .{ext});
        std.debug.print("       Supported: .vibee, .v\n", .{});
        return error.UnsupportedInputType;
    }

    // Parse options
    var target: []const u8 = "xc7a100t";
    var top: ?[]const u8 = null;
    var output: ?[]const u8 = null;
    var verify = false;
    var verbose = false;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        
        if (std.mem.eql(u8, arg, "--target") or std.mem.eql(u8, arg, "-t")) {
            if (i + 1 >= args.len]) return error.MissingArgument;
            i += 1;
            target = args[i];
        } else if (std.mem.eql(u8, arg, "--top")) {
            if (i + 1 >= args.len]) return error.MissingArgument;
            i += 1;
            top = args[i];
        } else if (std.mem.eql(u8, arg, "--out") or std.mem.eql(u8, arg, "-o")) {
            if (i + 1 >= args.len]) return error.MissingArgument;
            i += 1;
            output = args[i];
        } else if (std.mem.eql(u8, arg, "--verify")) {
            verify = true;
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            return printUsage(allocator);
        } else {
            std.debug.print("Error: Unknown option: {s}\n", .{arg});
            return error.UnknownOption;
        }
    }

    // Resolve paths
    const basename = std.fs.path.stem(input);
    const resolved_top = top orelse try std.fmt.allocPrint(allocator, "{s}_top", .{basename});
    defer allocator.free(resolved_top);

    const resolved_output = output orelse try std.fmt.allocPrint(allocator, "build/{s}.bit", .{basename});
    defer allocator.free(resolved_output);

    // For .vibee, check if VIBEE output exists
    var verilog_path = input;
    if (is_vibee) {
        const vibee_output = try std.fmt.allocPrint(allocator, "trinity-nexus/output/lang/fpga/{s}.v", .{basename});
        if (std.fs.cwd().access(vibee_output, .{})) {
            verilog_path = vibee_output;
            if (verbose) {
                std.debug.print("Using VIBEE output: {s}\n", .{vibee_output});
            }
        } else {
            std.debug.print("Error: VIBEE output not found: {s}\n", .{vibee_output});
            std.debug.print("       Run: zig build vibee -- gen {s}\n", .{input});
            return error.VibeeOutputNotFound;
        }
    }

    // Run synthesis via synth.sh
    if (verbose) {
        std.debug.print("Running synthesis...\n", .{});
        std.debug.print("  Input: {s}\n", .{verilog_path});
        std.debug.print("  Top: {s}\n", .{resolved_top});
        std.debug.print("  Output: {s}\n", .{resolved_output});
    }

    const synth_script = "fpga/openxc7-synth/synth.sh";
    const result = try std.process.Child.exec(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ synth_script, verilog_path, resolved_top },
    });

    if (result.term != 0) {
        std.debug.print("Error: Synthesis failed\n", .{});
        if (result.stderr.len > 0) {
            std.debug.print("{s}\n", .{result.stderr});
        }
        return error.SynthesisFailed;
    }

    // Success
    std.debug.print("✓ FPGA build complete: {s}\n", .{resolved_output});
}

/// Print usage information
fn printUsage(allocator: std.mem.Allocator) !void {
    _ = allocator;
    std.debug.print(
        \\╔═══════════════════════════════════════════════════════════════════════════╗
        \\║ TRI FPGA BUILD — Single Source of Truth for .tri → .bit synthesis      ║
        \\╚═══════════════════════════════════════════════════════════════════════════╝
        \\
        \\USAGE:
        \\  tri fpga build <input> [options]
        \\
        \\INPUT:
        \\  <input>              Path to .vibee spec or .v file
        \\
        \\OPTIONS:
        \\  --target, -t <dev>   Target FPGA device (default: xc7a100t)
        \\  --top <module>       Top module name
        \\  --out, -o <path>     Output bitstream path
        \\  --verify             Run LED hardware verification (TODO)
        \\  --verbose, -v        Enable verbose output
        \\  --help, -h           Show this help
        \\
        \\EXAMPLES:
        \\  tri fpga build fpga/openxc7-synth/blink.v
        \\  tri fpga build specs/tri/uart.vibee --verify
        \\  tri fpga build counter.v --out build/counter.bit
        \\
        \\FLOW:
        \\  .vibee/.v → Verilog → synth.sh → openXC7 Docker → .bit
        \\
        \\φ² + 1/φ² = 3 | TRINITY v2.2.0
        \\
    , .{});
}

/// Export for tri_register.zig
pub const runCommand = runFpgaBuildCommand;
