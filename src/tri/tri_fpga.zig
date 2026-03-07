// ═══════════════════════════════════════════════════════════════════════════════
// FPGA COMMANDS - VIBEE + FORGE Pipeline
// ═══════════════════════════════════════════════════════════════════════════════
//
// Implements: tri fpga gen, tri fpga verdict
// Pipeline: .vibee → VIBEE → .v/.xdc → Yosys → .json → FORGE → .bit
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Colors for output
const GREEN = "\x1b[0;32m";
const RED = "\x1b[0;31m";
const YELLOW = "\x1b[0;33m";
const CYAN = "\x1b[0;36m";
const RESET = "\x1b[0m";

// ═══════════════════════════════════════════════════════════════════════════════
// FPGA GEN - Generate bitstream from .vibee spec
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runFpgaGen(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printFpgaGenHelp();
        return;
    }

    const spec_path = args[0];
    const output_dir = if (args.len > 1) args[1] else "trinity/output/fpga/";

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  TRI FPGA GEN — VIBEE + FORGE Pipeline{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });

    // Step 1: Generate Verilog + XDC with VIBEE
    std.debug.print("[1/4] {s}VIBEE Code Generation{s}...\n", .{ YELLOW, RESET });
    const vibee_bin = findVibeeBinary(allocator) orelse {
        std.debug.print("{s}Error:{s} VIBEE binary not found. Run 'zig build vibee' first.\n", .{ RED, RESET });
        return error.VibeeNotFound;
    };

    var vibee_argv = try std.ArrayList([]const u8).initCapacity(allocator, 8);
    defer vibee_argv.deinit(allocator);

    try vibee_argv.append(allocator, vibee_bin);
    try vibee_argv.append(allocator, "gen");
    try vibee_argv.append(allocator, spec_path);

    // Run VIBEE
    var vibee_child = std.process.Child.init(vibee_argv.items, allocator);
    vibee_child.stderr_behavior = .Inherit;
    vibee_child.stdout_behavior = .Inherit;

    const vibee_term = vibee_child.spawnAndWait() catch |err| {
        std.debug.print("{s}Error:{s} VIBEE failed: {}\n", .{ RED, RESET, err });
        return err;
    };

    switch (vibee_term) {
        .Exited => |code| {
            if (code != 0) {
                std.debug.print("{s}Error:{s} VIBEE exited with code {d}\n", .{ RED, RESET, code });
                return error.VibeeFailed;
            }
        },
        else => {
            std.debug.print("{s}Error:{s} VIBEE terminated abnormally\n", .{ RED, RESET });
            return error.VibeeFailed;
        },
    }

    std.debug.print("{s}✓{s} VIBEE generation complete\n\n", .{ GREEN, RESET });

    // Step 2: Extract base name from spec path
    const base_name = getBaseName(spec_path);

    // Step 3: Run Yosys synthesis
    std.debug.print("[2/4] {s}Yosys Synthesis{s}...\n", .{ YELLOW, RESET });

    const verilog_file = try std.fmt.allocPrint(allocator, "{s}/{s}.v", .{ output_dir, base_name });
    defer allocator.free(verilog_file);

    const json_file = try std.fmt.allocPrint(allocator, "{s}/{s}.json", .{ output_dir, base_name });
    defer allocator.free(json_file);

    // Check if verilog file exists
    if (std.fs.cwd().openFile(verilog_file, .{})) |file| {
        file.close();
    } else |_| {
        std.debug.print("{s}Error:{s} Verilog file not found: {s}\n", .{ RED, RESET, verilog_file });
        return error.VerilogNotFound;
    }

    // Run Yosys via synth.sh
    const yosys_result = runYosysSynth(allocator, verilog_file, json_file, base_name);
    if (yosys_result) |_| {
        std.debug.print("{s}✓{s} Yosys synthesis complete\n\n", .{ GREEN, RESET });
    } else |err| {
        std.debug.print("{s}Error:{s} Yosys synthesis failed: {}\n", .{ RED, RESET, err });
        return err;
    }

    // Step 4: Run FORGE
    std.debug.print("[3/4] {s}FORGE Place & Route{s}...\n", .{ YELLOW, RESET });

    const xdc_file = try std.fmt.allocPrint(allocator, "{s}/{s}.xdc", .{ output_dir, base_name });
    defer allocator.free(xdc_file);

    const bitstream_file = try std.fmt.allocPrint(allocator, "{s}/{s}.bit", .{ output_dir, base_name });
    defer allocator.free(bitstream_file);

    const forge_result = runForgeBitstream(allocator, json_file, xdc_file, bitstream_file);
    if (forge_result) |_| {
        std.debug.print("{s}✓{s} FORGE complete\n\n", .{ GREEN, RESET });
    } else |err| {
        std.debug.print("{s}Error:{s} FORGE failed: {}\n", .{ RED, RESET, err });
        return err;
    }

    // Summary
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  FPGA GENERATION COMPLETE{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("  Spec:       {s}\n", .{spec_path});
    std.debug.print("  Bitstream:  {s}\n", .{bitstream_file});
    std.debug.print("\n{s}Next steps:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  tri fpga flash {s}\n", .{bitstream_file});
    std.debug.print("  tri fpga verdict\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// FPGA VERDICT - Generate pass/fail verdict
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runFpgaVerdict(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  TRI FPGA VERDICT{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });

    const forge_bin = findForgeBinary(allocator) orelse {
        std.debug.print("{s}Error:{s} FORGE binary not found. Run 'zig build forge' first.\n", .{ RED, RESET });
        return error.ForgeNotFound;
    };

    // Run FORGE verdict
    var forge_argv = try std.ArrayList([]const u8).initCapacity(allocator, 4);
    defer forge_argv.deinit(allocator);

    try forge_argv.append(allocator, forge_bin);
    try forge_argv.append(allocator, "verdict");

    var forge_child = std.process.Child.init(forge_argv.items, allocator);
    forge_child.stderr_behavior = .Inherit;
    forge_child.stdout_behavior = .Inherit;

    const term = forge_child.spawnAndWait() catch |err| {
        std.debug.print("{s}Error:{s} FORGE verdict failed: {}\n", .{ RED, RESET, err });
        return err;
    };

    // Display summary
    const exit_code = switch (term) {
        .Exited => |code| code,
        else => 1,
    };
    const verdict = if (exit_code == 0) "IMMORTAL ✅" else if (exit_code == 1) "FAIL ❌" else "TOXIC ☠️";
    const verdict_color = if (exit_code == 0) GREEN else RED;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  VERDICT: {s}{s}{s}\n", .{ CYAN, verdict_color, verdict, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// FPGA FLASH - Flash bitstream to hardware
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runFpgaFlash(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("{s}Usage:{s} tri fpga flash <bitstream.bit>\n", .{ YELLOW, RESET });
        return;
    }

    const bitstream_path = args[0];

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  FLASHING TO FPGA{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });

    std.debug.print("  Bitstream: {s}\n\n", .{bitstream_path});

    // Check if file exists
    if (std.fs.cwd().openFile(bitstream_path, .{})) |file| {
        file.close();
    } else |_| {
        std.debug.print("{s}Error:{s} Bitstream file not found: {s}\n", .{ RED, RESET, bitstream_path });
        return error.FileNotFound;
    }

    // Run jtag_program script
    const jtag_script = "fpga/tools/jtag_program";

    var jtag_argv = try std.ArrayList([]const u8).initCapacity(allocator, 4);
    defer jtag_argv.deinit(allocator);

    try jtag_argv.append(allocator, jtag_script);
    try jtag_argv.append(allocator, bitstream_path);

    var jtag_child = std.process.Child.init(jtag_argv.items, allocator);
    jtag_child.stderr_behavior = .Inherit;
    jtag_child.stdout_behavior = .Inherit;

    std.debug.print("{s}Flashing...{s}\n\n", .{ YELLOW, RESET });

    const term = jtag_child.spawnAndWait() catch |err| {
        std.debug.print("{s}Error:{s} Flash failed: {}\n", .{ RED, RESET, err });
        std.debug.print("\n{s}Note:{s} Make sure JTAG cable is connected and firmware is loaded.\n", .{ YELLOW, RESET });
        return err;
    };

    switch (term) {
        .Exited => |code| {
            if (code == 0) {
                std.debug.print("\n{s}✓{s} FLASH COMPLETE — FPGA PROGRAMMED\n", .{ GREEN, RESET });
            } else {
                std.debug.print("\n{s}Error:{s} Flash failed with exit code {d}\n", .{ RED, RESET, code });
                return error.FlashFailed;
            }
        },
        else => {
            std.debug.print("\n{s}Error:{s} Flash terminated abnormally\n", .{ RED, RESET });
            return error.FlashFailed;
        },
    }

    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper Functions
// ═══════════════════════════════════════════════════════════════════════════════

fn findVibeeBinary(allocator: std.mem.Allocator) ?[]const u8 {
    const paths = [_][]const u8{
        "zig-out/bin/vibee",
        "./zig-out/bin/vibee",
    };

    for (paths) |path| {
        if (std.fs.cwd().access(path, .{})) |_| {
            return allocator.dupe(u8, path) catch return null;
        } else |_| continue;
    }
    return null;
}

fn findForgeBinary(allocator: std.mem.Allocator) ?[]const u8 {
    const paths = [_][]const u8{
        "zig-out/bin/forge",
        "./zig-out/bin/forge",
    };

    for (paths) |path| {
        if (std.fs.cwd().access(path, .{})) |_| {
            return allocator.dupe(u8, path) catch return null;
        } else |_| continue;
    }
    return null;
}

fn getBaseName(path: []const u8) []const u8 {
    // Extract base name from path: "specs/fpga/blink.vibee" -> "blink"
    const filename = std.fs.path.basename(path);
    if (std.mem.lastIndexOf(u8, filename, ".")) |dot| {
        return filename[0..dot];
    }
    return filename;
}

fn runYosysSynth(allocator: std.mem.Allocator, verilog_file: []const u8, json_file: []const u8, top_module: []const u8) !void {
    // Use synth.sh from openxc7-synth
    const synth_script = "fpga/openxc7-synth/synth.sh";

    var argv = try std.ArrayList([]const u8).initCapacity(allocator, 8);
    defer argv.deinit(allocator);

    try argv.append(allocator, synth_script);
    try argv.append(allocator, verilog_file);
    try argv.append(allocator, top_module);
    try argv.append(allocator, "--forge"); // Use FORGE toolchain (Yosys only)

    var child = std.process.Child.init(argv.items, allocator);
    child.stderr_behavior = .Ignore;
    child.stdout_behavior = .Ignore; // Suppress Yosys output

    const term = child.spawnAndWait() catch |err| {
        return err;
    };

    if (term != .Exited or term.Exited != 0) return error.YosysFailed;

    // Verify JSON output exists
    if (std.fs.cwd().openFile(json_file, .{})) |file| {
        file.close();
    } else |_| {
        return error.JsonNotFound;
    }
}

fn runForgeBitstream(allocator: std.mem.Allocator, json_file: []const u8, xdc_file: []const u8, bitstream_file: []const u8) !void {
    const forge_bin = findForgeBinary(allocator) orelse return error.ForgeNotFound;

    var argv = try std.ArrayList([]const u8).initCapacity(allocator, 16);
    defer argv.deinit(allocator);

    try argv.append(allocator, forge_bin);
    try argv.append(allocator, "run");
    try argv.append(allocator, "--input");
    try argv.append(allocator, json_file);
    try argv.append(allocator, "--device");
    try argv.append(allocator, "xc7a100t");
    try argv.append(allocator, "--constraints");
    try argv.append(allocator, xdc_file);
    try argv.append(allocator, "--output");
    try argv.append(allocator, bitstream_file);

    var child = std.process.Child.init(argv.items, allocator);
    child.stderr_behavior = .Inherit;
    child.stdout_behavior = .Inherit;

    const term = child.spawnAndWait() catch |err| {
        return err;
    };

    if (term != .Exited or term.Exited != 0) return error.ForgeFailed;

    // Verify bitstream exists
    if (std.fs.cwd().openFile(bitstream_file, .{})) |file| {
        file.close();
    } else |_| {
        return error.BitstreamNotFound;
    }
}

fn printFpgaGenHelp() void {
    std.debug.print("\n{s}FPGA GEN HELP{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}Usage:{s}  tri fpga gen <spec.vibee> [output_dir]\n", .{ CYAN, RESET });
    std.debug.print("\n", .{});
    std.debug.print("{s}Pipeline:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  .vibee → VIBEE → .v + .xdc\n", .{});
    std.debug.print("          → Yosys → .json\n", .{});
    std.debug.print("          → FORGE → .bit\n", .{});
    std.debug.print("\n{s}Examples:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  tri fpga gen specs/fpga/blink.vibee\n", .{});
    std.debug.print("  tri fpga gen specs/fpga/counter.vibee\n", .{});
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSCIOUSNESS-GUIDED FPGA SYNTHESIS (Phase 2 Integration)
// ═══════════════════════════════════════════════════════════════════════════════
//
// New commands:
//   tri fpga gen-tri <design.tri>          - Generate Verilog/XDC from .tri spec
//   tri fpga synth <design.tri> --strategy consciousness - Run consciousness-guided synthesis
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate Verilog and XDC from .tri specification
pub fn runFpgaGenTri(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printFpgaGenTriHelp();
        return;
    }

    const tri_path = args[0];
    const output_dir = if (args.len > 1) args[1] else "fpga/output/";

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  .TRI DSL GENERATION{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });

    // Import tri_parser
    const tri_parser = @import("../forge/tri_parser.zig");

    // Parse .tri specification
    std.debug.print("[1/3] {s}Parsing .tri spec{s}...\n", .{ YELLOW, RESET });
    std.debug.print("  File: {s}\n", .{tri_path});

    var parser = tri_parser.TriParser.init(allocator);
    const spec = parser.parse(tri_path) catch |err| {
        std.debug.print("{s}Error:{s} Failed to parse .tri spec: {}\n", .{ RED, RESET, err });
        return err;
    };
    defer spec.deinit();

    std.debug.print("  Module: {s}\n", .{spec.name});
    std.debug.print("  Device: {s}\n", .{spec.device});
    std.debug.print("  Ports: {d}\n", .{spec.ports.items.len});
    std.debug.print("{s}✓{s} Parse complete\n\n", .{ GREEN, RESET });

    // Create output directory if needed
    std.fs.cwd().makePath(output_dir) catch {};

    // Generate Verilog
    std.debug.print("[2/3] {s}Generating Verilog{s}...\n", .{ YELLOW, RESET });

    const verilog_path = try std.fmt.allocPrint(allocator, "{s}/{s}.v", .{ output_dir, spec.name });
    defer allocator.free(verilog_path);

    {
        const verilog_file = try std.fs.cwd().createFile(verilog_path, .{});
        defer verilog_file.close();
        try parser.generateVerilog(&spec, verilog_file.writer());
    }

    std.debug.print("  Output: {s}\n", .{verilog_path});
    std.debug.print("{s}✓{s} Verilog generated\n\n", .{ GREEN, RESET });

    // Generate XDC
    std.debug.print("[3/3] {s}Generating XDC constraints{s}...\n", .{ YELLOW, RESET });

    const xdc_path = try std.fmt.allocPrint(allocator, "{s}/{s}.xdc", .{ output_dir, spec.name });
    defer allocator.free(xdc_path);

    {
        const xdc_file = try std.fs.cwd().createFile(xdc_path, .{});
        defer xdc_file.close();
        try parser.generateXDC(&spec, xdc_file.writer());
    }

    std.debug.print("  Output: {s}\n", .{xdc_path});
    std.debug.print("{s}✓{s} XDC generated\n\n", .{ GREEN, RESET });

    // Summary
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  GENERATION COMPLETE{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("  Verilog:  {s}\n", .{verilog_path});
    std.debug.print("  XDC:      {s}\n", .{xdc_path});
    std.debug.print("\n{s}Next steps:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  tri fpga synth {s}\n", .{tri_path});
}

/// Run consciousness-guided FPGA synthesis
pub fn runFpgaSynth(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printFpgaSynthHelp();
        return;
    }

    const tri_path = args[0];

    // Parse options
    var use_consciousness = false;
    var strategy_override: ?[]const u8 = null;
    var output_dir = "fpga/output/";

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--strategy") and i + 1 < args.len) {
            i += 1;
            strategy_override = args[i];
            if (std.mem.eql(u8, args[i], "consciousness") or
                std.mem.eql(u8, args[i], "conscious")) {
                use_consciousness = true;
            }
        } else if (std.mem.eql(u8, args[i], "--output") and i + 1 < args.len) {
            i += 1;
            output_dir = args[i];
        }
    }

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  FPGA SYNTHESIS{s}\n", .{ CYAN, RESET });
    if (use_consciousness) {
        std.debug.print("{s}  Mode: Consciousness-Guided{s}\n", .{ YELLOW, RESET });
    } else {
        std.debug.print("{s}  Mode: Standard{s}\n", .{ YELLOW, RESET });
    }
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });

    // Import modules
    const tri_parser = @import("../forge/tri_parser.zig");
    const synthesis_types = @import("../forge/synthesis_types.zig");

    // Step 1: Parse .tri specification
    std.debug.print("[1/5] {s}Parsing .tri spec{s}...\n", .{ YELLOW, RESET });
    var parser = tri_parser.TriParser.init(allocator);
    const spec = parser.parse(tri_path) catch |err| {
        std.debug.print("{s}Error:{s} Failed to parse .tri spec: {}\n", .{ RED, RESET, err });
        return err;
    };
    defer spec.deinit();
    std.debug.print("{s}✓{s} Parsed {s}\n\n", .{ GREEN, RESET, spec.name });

    // Step 2: Consciousness analysis (if enabled)
    var strategy = synthesis_types.StrategyParams.default();
    var rationale: []const u8 = "Default parameters";

    if (use_consciousness) {
        std.debug.print("[2/5] {s}Consciousness Analysis{s}...\n", .{ YELLOW, RESET });

        // Initialize consciousness system
        const unified_architecture = @import("../consciousness/core/unified_architecture.zig");
        const learning_loops = @import("../consciousness/learning/learning_loops.zig");
        const strategist = @import("../forge/strategist.zig");

        var consciousness = try unified_architecture.UnifiedConsciousness.init(allocator);
        defer consciousness.deinit();
        try consciousness.start();
        defer consciousness.stop();

        var learning = try learning_loops.LearningLoop.init(allocator);
        defer learning.deinit();

        var forge_strategist = try strategist.ForgeStrategist.init(allocator, &consciousness, &learning);
        defer forge_strategist.deinit();

        // Get strategy decision
        const decision = try forge_strategist.selectStrategy(&spec);
        strategy = decision.params;
        rationale = decision.rationale;

        // Display consciousness analysis
        const analysis = forge_strategist.getConsciousnessAnalysis();
        std.debug.print("  {s}Consciousness Theories:{s}\n", .{ CYAN, RESET });
        std.debug.print("    IIT Φ:     {d:.3}\n", .{analysis.iit_phi});
        std.debug.print("    GWT:       {d:.3}\n", .{analysis.gwt_active});
        std.debug.print("    HOT:       {d:.3}\n", .{analysis.hot_meta});
        std.debug.print("    Unified:   {d:.3}\n", .{analysis.unified_score});
        std.debug.print("  {s}Strategy:{s} {s}\n", .{ CYAN, RESET, @tagName(decision.strategy) });
        std.debug.print("  Rationale: {s}\n", .{decision.rationale});
        std.debug.print("{s}✓{s} Strategy selected\n\n", .{ GREEN, RESET });
    } else {
        std.debug.print("[2/5] {s}Strategy Selection{s}...\n", .{ YELLOW, RESET });
        if (strategy_override) |s| {
            std.debug.print("  Override: {s}\n", .{s});
            if (std.mem.eql(u8, s, "aggressive")) {
                strategy = synthesis_types.StrategyParams.aggressiveTiming();
                rationale = "Aggressive override";
            } else if (std.mem.eql(u8, s, "conservative")) {
                strategy = synthesis_types.StrategyParams.conservative();
                rationale = "Conservative override";
            }
        } else {
            std.debug.print("  Using default balanced strategy\n", .{});
        }
        std.debug.print("{s}✓{s} Strategy: {s}\n\n", .{ GREEN, RESET, rationale });
    }

    // Step 3: Generate Verilog/XDC (if not already done)
    std.debug.print("[3/5] {s}Generating Verilog/XDC{s}...\n", .{ YELLOW, RESET });

    const verilog_path = try std.fmt.allocPrint(allocator, "{s}/{s}.v", .{ output_dir, spec.name });
    defer allocator.free(verilog_path);

    const xdc_path = try std.fmt.allocPrint(allocator, "{s}/{s}.xdc", .{ output_dir, spec.name });
    defer allocator.free(xdc_path);

    {
        const verilog_file = try std.fs.cwd().createFile(verilog_path, .{});
        defer verilog_file.close();
        try parser.generateVerilog(&spec, verilog_file.writer());
    }
    {
        const xdc_file = try std.fs.cwd().createFile(xdc_path, .{});
        defer xdc_file.close();
        try parser.generateXDC(&spec, xdc_file.writer());
    }

    std.debug.print("  Verilog: {s}\n", .{verilog_path});
    std.debug.print("  XDC:     {s}\n", .{xdc_path});
    std.debug.print("{s}✓{s} Files generated\n\n", .{ GREEN, RESET });

    // Step 4: Run Yosys synthesis
    std.debug.print("[4/5] {s}Yosys Synthesis{s}...\n", .{ YELLOW, RESET });

    const json_file = try std.fmt.allocPrint(allocator, "{s}/{s}.json", .{ output_dir, spec.name });
    defer allocator.free(json_file);

    if (runYosysSynth(allocator, verilog_path, json_file, spec.name)) |_| {
        std.debug.print("{s}✓{s} Yosys complete\n\n", .{ GREEN, RESET });
    } else |err| {
        std.debug.print("{s}Error:{s} Yosys failed: {}\n", .{ RED, RESET, err });
        return err;
    }

    // Step 5: Run FORGE with strategy parameters
    std.debug.print("[5/5] {s}FORGE Place & Route{s}...\n", .{ YELLOW, RESET });
    std.debug.print("  Strategy: {s}\n", .{rationale});
    std.debug.print("  Cooling α: {d:.3}\n", .{strategy.placement_cooling_alpha});
    std.debug.print("  Routing:   {d} iterations\n", .{strategy.routing_iterations});
    std.debug.print("  Target:    {d:.1} MHz\n", .{strategy.target_frequency_mhz});

    const bitstream_file = try std.fmt.allocPrint(allocator, "{s}/{s}.bit", .{ output_dir, spec.name });
    defer allocator.free(bitstream_file);

    if (runForgeWithStrategy(allocator, json_file, xdc_file, bitstream_file, strategy)) |_| {
        std.debug.print("{s}✓{s} FORGE complete\n\n", .{ GREEN, RESET });
    } else |err| {
        std.debug.print("{s}Error:{s} FORGE failed: {}\n", .{ RED, RESET, err });
        return err;
    }

    // Summary
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  SYNTHESIS COMPLETE{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("  Bitstream: {s}\n", .{bitstream_file});
    std.debug.print("\n{s}Next steps:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  tri fpga flash {s}\n", .{bitstream_file});
}

fn printFpgaGenTriHelp() void {
    std.debug.print("\n{s}FPGA GEN-TRI HELP{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}Usage:{s}  tri fpga gen-tri <design.tri> [output_dir]\n", .{ CYAN, RESET });
    std.debug.print("\n", .{});
    std.debug.print("{s}Generates:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  Verilog module declaration\n", .{});
    std.debug.print("  XDC constraints file\n", .{});
    std.debug.print("\n{s}Example:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  tri fpga gen-tri fpga/specs/uart.tri\n", .{});
    std.debug.print("\n", .{});
}

fn printFpgaSynthHelp() void {
    std.debug.print("\n{s}FPGA SYNTH HELP{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}Usage:{s}  tri fpga synth <design.tri> [options]\n", .{ CYAN, RESET });
    std.debug.print("\n", .{});
    std.debug.print("{s}Options:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  --strategy <name>    Strategy to use\n", .{});
    std.debug.print("                       consciousness, aggressive, conservative\n", .{});
    std.debug.print("  --output <dir>       Output directory (default: fpga/output/)\n", .{});
    std.debug.print("\n{s}Pipeline:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  .tri → Verilog + XDC\n", .{});
    std.debug.print("       → Yosys → JSON\n", .{});
    std.debug.print("       → FORGE → bitstream\n", .{});
    std.debug.print("\n{s}Example:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  tri fpga synth fpga/specs/uart.tri --strategy consciousness\n", .{});
    std.debug.print("\n", .{});
}

/// Run FORGE with strategy parameters
fn runForgeWithStrategy(
    allocator: std.mem.Allocator,
    json_file: []const u8,
    xdc_file: []const u8,
    bitstream_file: []const u8,
    params: anytype,
) !void {
    _ = params; // Strategy params would be passed to FORGE in full integration
    // For now, use standard FORGE run
    return runForgeBitstream(allocator, json_file, xdc_file, bitstream_file);
}
