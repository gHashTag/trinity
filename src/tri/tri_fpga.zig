// =============================================================================
// TRI FPGA Commands — Native openXC7 FPGA Toolchain
// =============================================================================
//
// Complete FPGA pipeline: synth, flash, verify, snap, build, status
//
// Native tools (NO Docker):
//   yosys -> nextpnr-xilinx -> fasm2frames -> xc7frames2bit -> jtag_program
//
// Proven on QMTECH XC7A100T-1FGG676C:
//   - beal_top.v: Beal conjecture scanner (working)
//   - vsa_uart_phi_top.v: VSA + UART (working)
//   - ternary_matvec_top.v: 64x64 ternary AI (working, self-test PASS)
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");

// =========================================================================
// Tool paths — relative to project root
// =========================================================================
const YOSYS = "yosys";
const NEXTPNR = "fpga/nextpnr-xilinx/build/nextpnr-xilinx";
const FASM2FRAMES = "fpga/prjxray/utils/fasm2frames.py";
const XC7FRAMES2BIT = "fpga/prjxray/build/tools/xc7frames2bit";
const JTAG_PROGRAM = "fpga/tools/jtag_program";
const CHIPDB = "fpga/openxc7-synth/chipdb/xc7a100tfgg676.bin";
const PRJXRAY_DB = "fpga/prjxray/database/artix7";

// Color codes
const CYAN = "\x1b[0;36m";
const GREEN = "\x1b[0;32m";
const YELLOW = "\x1b[0;33m";
const RED = "\x1b[0;31m";
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";

/// Helper: run a command, return success. If verbose, inherit stdout/stderr.
fn runCmd(allocator: std.mem.Allocator, argv: []const []const u8, verbose: bool) !bool {
    var child = std.process.Child.init(argv, allocator);
    if (verbose) {
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;
    } else {
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;
    }
    try child.spawn();
    const term = try child.wait();
    return term.Exited == 0;
}

// =========================================================================
// SYNTH — Full native openXC7 synthesis pipeline
// =========================================================================

pub fn runFpgaSynthCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) return printSynthUsage();
    if (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h")) return printSynthUsage();

    // Parse args: collect .v files and options
    var vfiles_buf: [16][]const u8 = undefined;
    var vfiles_count: usize = 0;
    var top: ?[]const u8 = null;
    var verbose = false;
    var seed: []const u8 = "1";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--top")) {
            i += 1;
            if (i < args.len) top = args[i];
        } else if (std.mem.eql(u8, arg, "--seed")) {
            i += 1;
            if (i < args.len) seed = args[i];
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            verbose = true;
        } else if (std.mem.endsWith(u8, arg, ".v")) {
            if (vfiles_count < 16) {
                vfiles_buf[vfiles_count] = arg;
                vfiles_count += 1;
            }
        }
    }

    if (vfiles_count == 0) {
        std.debug.print("{s}Error:{s} No .v files specified\n", .{ RED, RESET });
        return error.NoInput;
    }

    const vfiles = vfiles_buf[0..vfiles_count];
    const first_file = vfiles[0];
    const basename = std.fs.path.stem(first_file);
    const resolved_top = top orelse basename;
    const dir = std.fs.path.dirname(first_file) orelse ".";

    std.debug.print("\n{s}{s}=== TRI FPGA SYNTH ==={s}\n", .{ BOLD, CYAN, RESET });
    std.debug.print("{s}Top:{s}   {s}\n", .{ DIM, RESET, resolved_top });
    std.debug.print("{s}Files:{s} ", .{ DIM, RESET });
    for (vfiles) |f| std.debug.print("{s} ", .{f});
    std.debug.print("\n{s}Seed:{s}  {s}\n\n", .{ DIM, RESET, seed });

    // ── Step 1: Yosys ──
    std.debug.print("{s}[1/4]{s} Yosys synthesis...", .{ CYAN, RESET });

    // Build yosys -p command string
    var cmd_buf: [2048]u8 = undefined;
    var pos: usize = 0;

    const rv_prefix = "read_verilog ";
    @memcpy(cmd_buf[pos..][0..rv_prefix.len], rv_prefix);
    pos += rv_prefix.len;

    for (vfiles, 0..) |f, idx| {
        if (idx > 0) {
            cmd_buf[pos] = ' ';
            pos += 1;
        }
        @memcpy(cmd_buf[pos..][0..f.len], f);
        pos += f.len;
    }

    const synth_fmt = try std.fmt.bufPrint(cmd_buf[pos..], "; synth_xilinx -flatten -abc9 -arch xc7 -top {s}; delete t:$scopeinfo; write_json {s}/{s}.json", .{ resolved_top, dir, resolved_top });
    pos += synth_fmt.len;

    const yosys_cmd = cmd_buf[0..pos];

    const ok1 = try runCmd(allocator, &[_][]const u8{ YOSYS, "-p", yosys_cmd }, verbose);
    if (!ok1) {
        std.debug.print(" {s}FAIL{s}\n  Re-run with -v for details\n", .{ RED, RESET });
        return error.YosysFailed;
    }
    std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });

    // ── Step 2: nextpnr-xilinx ──
    std.debug.print("{s}[2/4]{s} nextpnr-xilinx P&R...", .{ CYAN, RESET });

    const json_path = try std.fmt.allocPrint(allocator, "{s}/{s}.json", .{ dir, resolved_top });
    defer allocator.free(json_path);
    const xdc_path = try std.fmt.allocPrint(allocator, "{s}/{s}.xdc", .{ dir, resolved_top });
    defer allocator.free(xdc_path);
    const fasm_path = try std.fmt.allocPrint(allocator, "{s}/{s}.fasm", .{ dir, resolved_top });
    defer allocator.free(fasm_path);

    const ok2 = try runCmd(allocator, &[_][]const u8{
        NEXTPNR,    "--chipdb", CHIPDB,
        "--xdc",    xdc_path,
        "--json",   json_path,
        "--fasm",   fasm_path,
        "--seed",   seed,
    }, verbose);
    if (!ok2) {
        std.debug.print(" {s}FAIL{s}\n  Re-run with -v for details\n", .{ RED, RESET });
        return error.NextpnrFailed;
    }
    std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });

    // ── Step 3: fasm2frames ──
    std.debug.print("{s}[3/4]{s} fasm2frames...", .{ CYAN, RESET });

    const frames_path = try std.fmt.allocPrint(allocator, "{s}/{s}.frames", .{ dir, resolved_top });
    defer allocator.free(frames_path);

    const ok3 = try runCmd(allocator, &[_][]const u8{
        "python3", FASM2FRAMES,
        "--db-root", PRJXRAY_DB,
        "--sparse",
        fasm_path,
        frames_path,
    }, verbose);
    if (!ok3) {
        std.debug.print(" {s}FAIL{s}\n", .{ RED, RESET });
        return error.Fasm2FramesFailed;
    }
    std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });

    // ── Step 4: xc7frames2bit ──
    std.debug.print("{s}[4/4]{s} xc7frames2bit...", .{ CYAN, RESET });

    const bit_path = try std.fmt.allocPrint(allocator, "{s}/{s}.bit", .{ dir, resolved_top });
    defer allocator.free(bit_path);

    const ok4 = try runCmd(allocator, &[_][]const u8{
        XC7FRAMES2BIT,
        "--part_file",  PRJXRAY_DB ++ "/xc7a100tfgg676-1/part.yaml",
        "--part_name",  "xc7a100tfgg676-1",
        "--frm_file",   frames_path,
        "--output_file", bit_path,
    }, verbose);
    if (!ok4) {
        std.debug.print(" {s}FAIL{s}\n", .{ RED, RESET });
        return error.Frames2BitFailed;
    }
    std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });

    // ── Done ──
    std.debug.print("\n{s}{s}SYNTH COMPLETE{s}\n", .{ BOLD, GREEN, RESET });
    std.debug.print("  Bitstream: {s}\n", .{bit_path});
    std.debug.print("  Flash:     tri fpga flash {s}\n\n", .{bit_path});
}

fn printSynthUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA SYNTH ==={1s}
        \\
        \\Native openXC7 synthesis: .v -> .bit (NO Docker)
        \\
        \\USAGE:
        \\  tri fpga synth <file1.v> [file2.v ...] [options]
        \\
        \\OPTIONS:
        \\  --top <module>   Top module name (default: stem of first file)
        \\  --seed <N>       nextpnr seed (default: 1)
        \\  --verbose, -v    Show tool output
        \\  --help, -h       Show this help
        \\
        \\PIPELINE:
        \\  [1] yosys          -> .json (synthesis)
        \\  [2] nextpnr-xilinx -> .fasm (place & route)
        \\  [3] fasm2frames    -> .frames
        \\  [4] xc7frames2bit  -> .bit (bitstream)
        \\
        \\EXAMPLES:
        \\  tri fpga synth fpga/openxc7-synth/ternary_matvec.v fpga/openxc7-synth/ternary_matvec_top.v
        \\  tri fpga synth blink.v --top blink_top -v
        \\
    , .{ CYAN, RESET });
}

// =========================================================================
// FLASH — Program FPGA via JTAG
// =========================================================================

pub fn runFpgaFlashCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) return printFlashUsage();
    if (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h")) return printFlashUsage();

    const bit_path = args[0];

    std.fs.cwd().access(bit_path, .{}) catch {
        std.debug.print("{s}Error:{s} Bitstream not found: {s}\n", .{ RED, RESET, bit_path });
        return error.FileNotFound;
    };

    std.debug.print("\n{s}{s}=== TRI FPGA FLASH ==={s}\n", .{ BOLD, CYAN, RESET });
    std.debug.print("  Bitstream: {s}\n", .{bit_path});
    std.debug.print("  Programming via JTAG...\n\n", .{});

    var child = std.process.Child.init(
        &[_][]const u8{ "sudo", JTAG_PROGRAM, bit_path },
        allocator,
    );
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    const term = try child.wait();

    if (term.Exited != 0) {
        std.debug.print("\n{s}FLASH FAILED{s} (exit code {d})\n", .{ RED, RESET, term.Exited });
        return error.FlashFailed;
    }

    std.debug.print("\n{s}{s}FLASH COMPLETE{s}\n", .{ BOLD, GREEN, RESET });
    std.debug.print("  Verify: tri fpga snap\n\n", .{});
}

fn printFlashUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA FLASH ==={1s}
        \\
        \\Program FPGA via JTAG (requires sudo).
        \\
        \\USAGE:
        \\  tri fpga flash <bitstream.bit>
        \\
        \\EXAMPLES:
        \\  tri fpga flash fpga/openxc7-synth/ternary_matvec_top.bit
        \\  tri fpga flash fpga/openxc7-synth/beal_top.bit
        \\
    , .{ CYAN, RESET });
}

// =========================================================================
// SNAP — Quick camera snapshot of FPGA board
// =========================================================================

pub fn runFpgaSnapCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var camera: []const u8 = "2";
    var duration: []const u8 = "3";
    var output_path: []const u8 = "/tmp/fpga_snap.jpg";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--help") or std.mem.eql(u8, args[i], "-h")) {
            return printSnapUsage();
        } else if (std.mem.eql(u8, args[i], "--camera") or std.mem.eql(u8, args[i], "-c")) {
            i += 1;
            if (i < args.len) camera = args[i];
        } else if (std.mem.eql(u8, args[i], "--duration") or std.mem.eql(u8, args[i], "-d")) {
            i += 1;
            if (i < args.len) duration = args[i];
        } else if (std.mem.eql(u8, args[i], "--out") or std.mem.eql(u8, args[i], "-o")) {
            i += 1;
            if (i < args.len) output_path = args[i];
        }
    }

    std.debug.print("\n{s}{s}=== TRI FPGA SNAP ==={s}\n", .{ BOLD, CYAN, RESET });
    std.debug.print("  Camera: device {s}, {s}s\n", .{ camera, duration });

    // Capture video -> extract last frame
    const video_path = "/tmp/fpga_snap_video.mp4";
    const cam_arg = try std.fmt.allocPrint(allocator, "{s}:none", .{camera});
    defer allocator.free(cam_arg);

    std.debug.print("  Capturing...", .{});

    const ok1 = try runCmd(allocator, &[_][]const u8{
        "ffmpeg",     "-f",    "avfoundation",
        "-framerate", "30",    "-video_size",
        "1920x1080",  "-i",    cam_arg,
        "-t",         duration, "-y",
        video_path,
    }, false);

    if (!ok1) {
        std.debug.print(" {s}FAIL{s}\n", .{ RED, RESET });
        return error.CaptureFailed;
    }

    // Extract last frame
    const ok2 = try runCmd(allocator, &[_][]const u8{
        "ffmpeg",    "-sseof", "-0.5",
        "-i",        video_path,
        "-frames:v", "1",
        "-y",        output_path,
    }, false);

    std.fs.cwd().deleteFile(video_path) catch {};

    if (!ok2) {
        std.debug.print(" {s}FAIL{s} (frame extraction)\n", .{ RED, RESET });
        return error.ExtractFailed;
    }

    std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });
    std.debug.print("  Snapshot: {s}\n\n", .{output_path});
}

fn printSnapUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA SNAP ==={1s}
        \\
        \\Camera snapshot of FPGA board (iPhone Continuity Camera).
        \\
        \\USAGE:
        \\  tri fpga snap [options]
        \\
        \\OPTIONS:
        \\  --camera, -c <id>    Camera device (default: 2 = iPhone main)
        \\  --duration, -d <s>   Capture duration (default: 3)
        \\  --out, -o <path>     Output path (default: /tmp/fpga_snap.jpg)
        \\
    , .{ CYAN, RESET });
}

// =========================================================================
// VERIFY — LED pattern analysis via camera
// =========================================================================

pub fn runFpgaVerifyCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var camera: []const u8 = "2";
    var duration: []const u8 = "5";

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) return printVerifyUsage();
    }

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--camera") or std.mem.eql(u8, args[i], "-c")) {
            i += 1;
            if (i < args.len) camera = args[i];
        } else if (std.mem.eql(u8, args[i], "--duration") or std.mem.eql(u8, args[i], "-d")) {
            i += 1;
            if (i < args.len) duration = args[i];
        }
    }

    std.debug.print("\n{s}{s}=== TRI FPGA VERIFY ==={s}\n", .{ BOLD, CYAN, RESET });
    std.debug.print("  Camera: device {s}, {s}s capture\n\n", .{ camera, duration });

    // Step 1: Capture video
    const video_path = "/tmp/fpga_verify_video.mp4";
    const cam_arg = try std.fmt.allocPrint(allocator, "{s}:none", .{camera});
    defer allocator.free(cam_arg);

    std.debug.print("  [1/3] Capturing video...", .{});
    const ok1 = try runCmd(allocator, &[_][]const u8{
        "ffmpeg",     "-f",    "avfoundation",
        "-framerate", "30",    "-video_size",
        "1920x1080",  "-i",    cam_arg,
        "-t",         duration, "-y",
        video_path,
    }, false);
    if (!ok1) {
        std.debug.print(" {s}FAIL{s}\n", .{ RED, RESET });
        return error.CaptureFailed;
    }
    std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });

    // Step 2: Extract frames
    std.debug.print("  [2/3] Extracting frames...", .{});
    const ok2 = try runCmd(allocator, &[_][]const u8{
        "ffmpeg", "-i", video_path,
        "-vf",    "fps=5", "-y",
        "/tmp/fpga_verify_frames/frame_%03d.jpg",
    }, false);
    if (!ok2) {
        std.debug.print(" {s}FAIL{s}\n", .{ RED, RESET });
        return error.ExtractFailed;
    }
    std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });

    // Step 3: Run analyzer
    std.debug.print("  [3/3] Analyzing LED pattern...\n", .{});
    const ok3 = runCmd(allocator, &[_][]const u8{
        "python3", "fpga/tools/led_pattern_analyzer.py", video_path,
    }, true) catch false;
    if (!ok3) {
        std.debug.print("\n  {s}Analyzer unavailable.{s}\n", .{ YELLOW, RESET });
    }

    std.debug.print("\n  Frames: /tmp/fpga_verify_frames/\n\n", .{});
    std.fs.cwd().deleteFile(video_path) catch {};
}

fn printVerifyUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA VERIFY ==={1s}
        \\
        \\LED verification via camera capture + analysis.
        \\
        \\USAGE:
        \\  tri fpga verify [options]
        \\
        \\OPTIONS:
        \\  --camera, -c <id>    Camera device (default: 2)
        \\  --duration, -d <s>   Capture seconds (default: 5)
        \\  --help, -h           Show this help
        \\
        \\LED MEANINGS:
        \\  Solid ON  = Self-test PASSED
        \\  Blinking  = Computation in progress
        \\  OFF       = Self-test FAILED
        \\
    , .{ CYAN, RESET });
}

// =========================================================================
// BUILD — Full pipeline: synth + flash
// =========================================================================

pub fn runFpgaBuildCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) return printBuildUsage();
    if (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h")) return printBuildUsage();

    // Check for --no-flash, pass rest to synth
    var no_flash = false;
    var synth_buf: [32][]const u8 = undefined;
    var synth_count: usize = 0;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--no-flash")) {
            no_flash = true;
        } else {
            if (synth_count < 32) {
                synth_buf[synth_count] = arg;
                synth_count += 1;
            }
        }
    }

    // Run synth
    try runFpgaSynthCommand(allocator, synth_buf[0..synth_count]);

    if (no_flash) return;

    // Derive bit path and flash
    for (args) |arg| {
        if (std.mem.endsWith(u8, arg, ".v")) {
            const dir = std.fs.path.dirname(arg) orelse ".";
            const stem = std.fs.path.stem(arg);

            var top_name: []const u8 = stem;
            var j: usize = 0;
            while (j < args.len) : (j += 1) {
                if (std.mem.eql(u8, args[j], "--top") and j + 1 < args.len) {
                    top_name = args[j + 1];
                    break;
                }
            }

            const bit_path = try std.fmt.allocPrint(allocator, "{s}/{s}.bit", .{ dir, top_name });
            defer allocator.free(bit_path);

            try runFpgaFlashCommand(allocator, &[_][]const u8{bit_path});
            return;
        }
    }
}

fn printBuildUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA BUILD ==={1s}
        \\
        \\Full pipeline: synth + flash.
        \\
        \\USAGE:
        \\  tri fpga build <file1.v> [file2.v ...] [options]
        \\
        \\OPTIONS:
        \\  --top <module>   Top module name
        \\  --seed <N>       nextpnr seed (default: 1)
        \\  --no-flash       Synth only, skip flash
        \\  --verbose, -v    Show tool output
        \\
        \\EXAMPLES:
        \\  tri fpga build fpga/openxc7-synth/ternary_matvec.v fpga/openxc7-synth/ternary_matvec_top.v
        \\  tri fpga build blink.v --no-flash
        \\
    , .{ CYAN, RESET });
}

// =========================================================================
// STATUS — Board and toolchain info
// =========================================================================

pub fn runFpgaStatusCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    _ = allocator;

    std.debug.print(
        \\
        \\{0s}{1s}=== TRI FPGA STATUS ==={2s}
        \\
        \\{0s}Board:{2s}   QMTECH XC7A100T-1FGG676C (Artix-7)
        \\  LUT:     63,400
        \\  FF:      129,600
        \\  BRAM36:  135 (4,860 Kb)
        \\  DSP48:   240
        \\
        \\{0s}Toolchain:{2s}
        \\  yosys:          /opt/homebrew/bin/yosys
        \\  nextpnr-xilinx: fpga/nextpnr-xilinx/build/nextpnr-xilinx
        \\  fasm2frames:    fpga/prjxray/utils/fasm2frames.py
        \\  xc7frames2bit:  fpga/prjxray/build/tools/xc7frames2bit
        \\  jtag_program:   fpga/tools/jtag_program
        \\
        \\{0s}Pin Map:{2s}
        \\  CLK:     U22  (50 MHz)
        \\  LED:     R23  (active-low)
        \\  UART_RX: L20
        \\  UART_TX: K20
        \\  DBG[0]:  N23
        \\  DBG[1]:  M22
        \\
        \\{0s}Designs:{2s}
        \\  ternary_matvec_top  633 LUT   64x64 ternary AI     PASS
        \\  beal_top            1200 LUT  Beal scanner 1000^3  OK
        \\  vsa_uart_phi_top    ~800 LUT  VSA + UART           OK
        \\
        \\{0s}Commands:{2s}
        \\  tri fpga synth   .v -> .bit (native openXC7)
        \\  tri fpga flash   Program via JTAG
        \\  tri fpga build   synth + flash
        \\  tri fpga snap    Camera snapshot
        \\  tri fpga verify  LED pattern analysis
        \\  tri fpga status  This info
        \\
    , .{ CYAN, BOLD, RESET });
}

/// Export for tri_register.zig
pub const runCommand = runFpgaBuildCommand;
