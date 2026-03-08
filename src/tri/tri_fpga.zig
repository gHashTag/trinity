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
            if (i + 1 >= args.len) return error.MissingArgument;
            i += 1;
            target = args[i];
        } else if (std.mem.eql(u8, arg, "--top")) {
            if (i + 1 >= args.len) return error.MissingArgument;
            i += 1;
            top = args[i];
        } else if (std.mem.eql(u8, arg, "--out") or std.mem.eql(u8, arg, "-o")) {
            if (i + 1 >= args.len) return error.MissingArgument;
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

/// Run `tri fpga verify` command — LED video analysis using Apple VideoFlashingReduction algorithm
pub fn runFpgaVerifyCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    // Check for --help first
    if (args.len >= 1 and (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h"))) {
        return printVerifyUsage(allocator);
    }

    if (args.len < 1) {
        return printVerifyUsage(allocator);
    }

    const video_path = args[0];
    var duration: f32 = 5.0;
    var camera_device: []const u8 = "2";
    var verbose = true;
    var keep_video = false;

    // Parse options
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--duration") or std.mem.eql(u8, args[i], "-d")) {
            if (i + 1 >= args.len) return error.MissingArgument;
            i += 1;
            duration = try std.fmt.parseFloat(f32, args[i]);
        } else if (std.mem.eql(u8, args[i], "--camera") or std.mem.eql(u8, args[i], "-c")) {
            if (i + 1 >= args.len) return error.MissingArgument;
            i += 1;
            camera_device = args[i];
        } else if (std.mem.eql(u8, args[i], "--quiet") or std.mem.eql(u8, args[i], "-q")) {
            verbose = false;
        } else if (std.mem.eql(u8, args[i], "--keep") or std.mem.eql(u8, args[i], "-k")) {
            keep_video = true;
        } else if (std.mem.eql(u8, args[i], "--help") or std.mem.eql(u8, args[i], "-h")) {
            return printVerifyUsage(allocator);
        } else {
            std.debug.print("Error: Unknown option: {s}\n", .{args[i]});
            return error.UnknownOption;
        }
    }

    // Path to LED detector script
    const detector_script = "/tmp/led_detector.py";
    const venv_python = "/tmp/led_venv/bin/python3";

    // Check if video path is provided (reuse existing) or capture new
    const input_is_video = std.mem.endsWith(u8, video_path, ".mp4") or
                          std.mem.endsWith(u8, video_path, ".mov") or
                          std.mem.endsWith(u8, video_path, ".avi");

    const video_to_analyze = if (input_is_video)
        video_path
    else blk: {
        // Capture new video
        const output_path = "/tmp/fpga_verify.mp4";

        if (verbose) {
            std.debug.print("Capturing {d:.1}s video from camera {s}...\n", .{duration, camera_device});
        }

        const cam_arg = try std.fmt.allocPrint(allocator, "{s}:none", .{camera_device});
        defer allocator.free(cam_arg);
        const duration_arg = try std.fmt.allocPrint(allocator, "{d:.1}", .{duration});
        defer allocator.free(duration_arg);

        const ffmpeg_result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{
                "ffmpeg",
                "-f", "avfoundation",
                "-framerate", "30",
                "-video_size", "1920x1080",
                "-i", cam_arg,
                "-t", duration_arg,
                "-y",
                output_path,
            },
        });

        if (ffmpeg_result.term.Exited != 0) {
            std.debug.print("Error: Video capture failed\n", .{});
            if (ffmpeg_result.stderr.len > 0) {
                std.debug.print("{s}\n", .{ffmpeg_result.stderr});
            }
            return error.VideoCaptureFailed;
        }

        break :blk output_path;
    };

    // Run LED detector
    if (verbose) {
        std.debug.print("\n{s}╔═══════════════════════════════════════════════════════════════╗{s}\n", .{CYAN, RESET});
        std.debug.print("{s}║{s}  FPGA LED DETECTOR - Apple VideoFlashingReduction Analysis  {s}║{s}\n", .{CYAN, BOLD, RESET, RESET});
        std.debug.print("{s}╚═══════════════════════════════════════════════════════════════╝{s}\n\n", .{CYAN, RESET});
    }

    var child = std.process.Child.init(&[_][]const u8{ venv_python, detector_script, video_to_analyze }, allocator);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    const term = child.spawnAndWait() catch |err| {
        std.debug.print("Error: Failed to run LED detector: {}\n", .{err});
        return err;
    };

    // Clean up captured video if not keeping it
    if (!input_is_video and !keep_video) {
        std.fs.cwd().deleteFile("/tmp/fpga_verify.mp4") catch {};
    }

    // Exit code indicates result
    if (term.Exited != 0) {
        std.debug.print("\n{s}✗ LED NOT BLINKING{s}\n", .{RED, RESET});
    } else {
        std.debug.print("\n{s}✓ LED IS BLINKING{s}\n", .{GREEN, RESET});
    }

    return;
}

fn printVerifyUsage(allocator: std.mem.Allocator) !void {
    _ = allocator;
    std.debug.print(
        \\╔═══════════════════════════════════════════════════════════════════════════╗
        \\║ TRI FPGA VERIFY — LED Blink Detection via Video Analysis                  ║
        \\╚═══════════════════════════════════════════════════════════════════════════╝
        \\
        \\USAGE:
        \\  tri fpga verify <video.mp4> [options]
        \\  tri fpga verify capture [options]
        \\
        \\ARGUMENTS:
        \\  <video.mp4>          Path to existing video file for analysis
        \\  capture              Capture new video from iPhone camera
        \\
        \\OPTIONS:
        \\  --duration, -d <s>   Video duration in seconds (default: 5.0)
        \\  --camera, -c <id>    Camera device ID (default: 2 for iPhone main)
        \\  --quiet, -q          Suppress verbose output
        \\  --keep, -k           Keep captured video file
        \\  --help, -h           Show this help
        \\
        \\EXAMPLES:
        \\  tri fpga verify /tmp/test.mp4
        \\  tri fpga verify capture --duration 10
        \\  tri fpga verify capture --camera 3 --keep
        \\
        \\ALGORITHM:
        \\  Based on Apple's VideoFlashingReduction algorithm:
        \\  - APL (Average Pixel Level) frame analysis
        \\  - FFT-based frequency detection
        \\  - Blink pattern classification
        \\  - Confidence scoring
        \\
        \\φ² + 1/φ² = 3 | TRINITY v2.2.0
        \\
    , .{});
}

/// Export for tri_register.zig
pub const runCommand = runFpgaBuildCommand;

// Color codes
const CYAN = "\x1b[0;36m";
const GREEN = "\x1b[0;32m";
const RED = "\x1b[0;31m";
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
