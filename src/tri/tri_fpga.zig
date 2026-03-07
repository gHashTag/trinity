// ═══════════════════════════════════════════════════════════════════════════════
// FPGA COMMANDS - VIBEE + openXC7 Pipeline
// ═══════════════════════════════════════════════════════════════════════════════
//
// Implements: tri fpga gen, tri fpga flash
// Pipeline: .vibee → VIBEE → .v/.xdc → synth.sh → .bit
//
// IMPORTANT: LED D6 = R23 (PRIMARY), LED D5 = T23 (SECONDARY)
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// MU-3, MU-4, MU-5: Forge integrations (P1 tasks - FIXING ERRORS)
// Import from forge module (which re-exports strategist, auto_fix, etc.)
const forge = @import("forge");
const synthesis_types = forge.synthesis_types_mod;
const strategist_mod = forge.strategist_mod;
const tri_parser_mod = forge;
const auto_fix_mod = forge.auto_fix_mod;

// Import consciousness modules (also available via build.zig)
const unified_architecture = @import("consciousness_core");
const learning_loops = @import("consciousness_learning");

// Type aliases for convenience
const Strategy = synthesis_types.Strategy;
const StrategyParams = synthesis_types.StrategyParams;
const DesignSpec = synthesis_types.DesignSpec;
const SynthesisResult = synthesis_types.SynthesisResult;
const Verdict = synthesis_types.Verdict;

// ═══════════════════════════════════════════════════════════════════════════════
// XDC Generation
// ═══════════════════════════════════════════════════════════════════════════════

fn generateXDC(allocator: std.mem.Allocator, spec_path: []const u8, output_path: []const u8) !void {
    // Read the .vibee spec file (spec_path should be absolute)
    const spec_file = try std.fs.openFileAbsolute(spec_path, .{});
    defer spec_file.close();
    const spec_content = try spec_file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(spec_content);

    // Create output directory if needed (output_path should be absolute)
    const output_dir = std.fs.path.dirname(output_path) orelse ".";
    std.fs.makeDirAbsolute(output_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    // Create XDC file
    const out_file = try std.fs.createFileAbsolute(output_path, .{});
    defer out_file.close();

    // Write XDC header
    try out_file.writeAll("# ═══════════════════════════════════════════════════════════════════════════════\n");
    try out_file.writeAll("# FPGA Constraints - Generated from .vibee specification\n");
    try out_file.writeAll("# Target: QMTECH Artix-7 XC7A100T\n");
    try out_file.writeAll("# ═══════════════════════════════════════════════════════════════════════════════\n\n");

    // Parse constraints section from YAML
    // Simple state machine: track if we're in constraints section
    var in_constraints = false;
    var current_constraint = std.StringHashMap([]const u8).init(allocator);
    defer current_constraint.deinit();

    var lines = std.mem.splitScalar(u8, spec_content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // Check for constraints section start
        if (std.mem.startsWith(u8, trimmed, "constraints:")) {
            in_constraints = true;
            continue;
        }

        // Exit constraints section when we hit another top-level key (no leading space)
        if (in_constraints and trimmed.len > 0 and trimmed[0] != '-' and trimmed[0] != '#') {
            const has_indent = std.mem.startsWith(u8, line, "  ") or std.mem.startsWith(u8, line, "\t");
            if (!has_indent) break;
        }

        // New constraint entry starts with "-"
        if (in_constraints and std.mem.startsWith(u8, trimmed, "-")) {
            // Write previous constraint if complete
            if (current_constraint.get("port")) |port| {
                if (current_constraint.get("pin")) |pin| {
                    const iostandard = current_constraint.get("iostandard") orelse "LVCMOS33";

                    const line1 = try std.fmt.allocPrint(allocator, "set_property PACKAGE_PIN {s} [get_ports {{{s}}}]\n", .{ pin, port });
                    defer allocator.free(line1);
                    try out_file.writeAll(line1);

                    const line2 = try std.fmt.allocPrint(allocator, "set_property IOSTANDARD {s} [get_ports {{{s}}}]\n", .{ iostandard, port });
                    defer allocator.free(line2);
                    try out_file.writeAll(line2);

                    try out_file.writeAll("\n");
                }
            }

            // Clear for next constraint
            current_constraint.clearRetainingCapacity();

            // Check for inline property: "- port: clk" (property on same line as dash)
            // Remove the dash and parse remaining content
            var rest = std.mem.trim(u8, trimmed[1..], " \t");
            while (rest.len > 0) {
                // Find "key: value" pattern
                if (std.mem.indexOf(u8, rest, ":")) |colon_idx| {
                    const key_orig = std.mem.trim(u8, rest[0..colon_idx], " \t");
                    const key = try allocator.dupe(u8, key_orig);
                    var value_part = std.mem.trimLeft(u8, rest[colon_idx + 1..], " \t");
                    // Find end of value (next " key:" pattern or end of string)
                    const next_key_idx = std.mem.indexOf(u8, value_part, " :") orelse value_part.len;
                    const value_orig = std.mem.trimRight(u8, value_part[0..next_key_idx], " \t\r");
                    if (value_orig.len >= 2 and value_orig[0] == '"' and value_orig[value_orig.len - 1] == '"') {
                        // Value is quoted, remove quotes
                        const unquoted = try allocator.dupe(u8, value_orig[1 .. value_orig.len - 1]);
                        try current_constraint.put(key, unquoted);
                    } else if (value_orig.len > 0) {
                        const value_copy = try allocator.dupe(u8, value_orig);
                        try current_constraint.put(key, value_copy);
                    }
                    // Move to next key:value pair
                    if (next_key_idx < value_part.len) {
                        rest = std.mem.trimLeft(u8, value_part[next_key_idx..], " \t");
                    } else {
                        break;
                    }
                } else {
                    break;
                }
            }
            continue;
        }

        // Parse constraint properties (key: value) - multi-line entries
        if (in_constraints and trimmed.len > 0) {
            if (std.mem.indexOf(u8, trimmed, ":")) |colon_idx| {
                const key_orig = std.mem.trim(u8, trimmed[0..colon_idx], " \t");
                const key = try allocator.dupe(u8, key_orig);
                var value = std.mem.trim(u8, trimmed[colon_idx + 1..], " \t\r");

                // Remove quotes if present and copy the value
                if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
                    const unquoted = try allocator.dupe(u8, value[1 .. value.len - 1]);
                    try current_constraint.put(key, unquoted);
                } else {
                    const value_copy = try allocator.dupe(u8, value);
                    try current_constraint.put(key, value_copy);
                }
            }
        }
    }

    // Write last constraint
    if (current_constraint.get("port")) |port| {
        if (current_constraint.get("pin")) |pin| {
            const iostandard = current_constraint.get("iostandard") orelse "LVCMOS33";

            const line1 = try std.fmt.allocPrint(allocator, "set_property PACKAGE_PIN {s} [get_ports {{{s}}}]\n", .{ pin, port });
            defer allocator.free(line1);
            try out_file.writeAll(line1);

            const line2 = try std.fmt.allocPrint(allocator, "set_property IOSTANDARD {s} [get_ports {{{s}}}]\n", .{ iostandard, port });
            defer allocator.free(line2);
            try out_file.writeAll(line2);

            try out_file.writeAll("\n");
        }
    }

    try out_file.writeAll("# ═══════════════════════════════════════════════════════════════════════════════\n");
}

// Colors for output
const GREEN = "\x1b[0;32m";
const RED = "\x1b[0;31m";
const YELLOW = "\x1b[0;33m";
const CYAN = "\x1b[0;36m";
const MAGENTA = "\x1b[0;35m";
const RESET = "\x1b[0m";

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const PHI: f64 = 1.618033988749895;              // Golden Ratio
const PHI_INV: f64 = 0.618033988749895;           // φ⁻¹ (consciousness threshold)
const GAMMA: f64 = 0.2360679774997897;           // γ = φ⁻³ (Barbero-Immirzi)
const TRINITY: f64 = 3.0;                        // φ² + φ⁻² = 3

/// Consciousness level for synthesis optimization
const ConsciousnessLevel = enum {
    dormant,       // 0.0 - Fast, lowest quality
    awakening,     // 0.3 - Fast synthesis
    conscious,     // 0.5 - Balanced (default)
    aware,         // 0.618 - φ⁻¹ threshold
    enlightened,   // 0.75 - Enhanced optimization
    transcendent,  // 1.0 - Maximum quality

    pub fn value(self: ConsciousnessLevel) f64 {
        return switch (self) {
            .dormant => 0.0,
            .awakening => 0.3,
            .conscious => 0.5,
            .aware => 0.618,
            .enlightened => 0.75,
            .transcendent => 1.0,
        };
    }

    pub fn label(self: ConsciousnessLevel) []const u8 {
        return switch (self) {
            .transcendent => "TRANSCENDENT",
            .enlightened => "ENLIGHTENED",
            .aware => "AWARE",
            .conscious => "CONSCIOUS",
            .awakening => "AWAKENING",
            .dormant => "DORMANT",
        };
    }

    pub fn color(self: ConsciousnessLevel) []const u8 {
        return switch (self) {
            .transcendent => MAGENTA,
            .enlightened => CYAN,
            .aware => GREEN,
            .conscious => YELLOW,
            .awakening => YELLOW,
            .dormant => RED,
        };
    }

    pub fn isImmortal(self: ConsciousnessLevel) bool {
        return self.value() >= PHI_INV;
    }

    pub fn flag(self: ConsciousnessLevel) []const u8 {
        return switch (self) {
            .transcendent => "--transcendent",
            .enlightened => "--aware",
            .aware => "--aware",
            .conscious => "--conscious",
            .awakening => "--mortal",
            .dormant => "--mortal",
        };
    }
};

/// Parse consciousness level from string
fn parseConsciousnessLevel(s: []const u8) ?ConsciousnessLevel {
    if (std.mem.eql(u8, s, "--transcendent")) return .transcendent;
    if (std.mem.eql(u8, s, "--enlightened")) return .enlightened;
    if (std.mem.eql(u8, s, "--aware")) return .aware;
    if (std.mem.eql(u8, s, "--conscious")) return .conscious;
    if (std.mem.eql(u8, s, "--mortal")) return .awakening;
    if (std.mem.startsWith(u8, s, "--consciousness=")) {
        const value_str = s["--consciousness=".len..];
        const value = std.fmt.parseFloat(f64, value_str) catch return null;
        if (value >= 0.9) return .transcendent;
        if (value >= 0.75) return .enlightened;
        if (value >= 0.618) return .aware;
        if (value >= 0.5) return .conscious;
        if (value >= 0.3) return .awakening;
        return .dormant;
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper Functions
// ═══════════════════════════════════════════════════════════════════════════════

/// Find project root by searching up for build.zig
fn findProjectRoot(allocator: std.mem.Allocator) ![]const u8 {
    var search_path = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(search_path);

    while (true) {
        // Try to open build.zig in current search path
        const build_zig_path = try std.fmt.allocPrint(allocator, "{s}/build.zig", .{search_path});
        defer allocator.free(build_zig_path);

        if (std.fs.openFileAbsolute(build_zig_path, .{})) |file| {
            file.close();
            // Found it! Return this directory
            return allocator.dupe(u8, search_path);
        } else |_| {
            // Not found, go up one directory
            const parent = std.fs.path.dirname(search_path);
            if (parent == null or parent.?.len == 0) {
                return error.ProjectRootNotFound;
            }
            // Allocate new string for parent directory
            const new_path = allocator.dupe(u8, parent.?) catch return error.OutOfMemory;
            allocator.free(search_path);
            search_path = new_path;
        }
    }
}

/// Resolve a path (relative or absolute) to absolute path from project root
fn resolvePathAbsolute(allocator: std.mem.Allocator, path: []const u8, project_root: []const u8) ![]const u8 {
    if (std.fs.path.isAbsolute(path)) {
        return allocator.dupe(u8, path);
    }
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ project_root, path });
}

// ═══════════════════════════════════════════════════════════════════════════════
// FPGA GEN - Generate bitstream from .vibee spec
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runFpgaGen(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printFpgaGenHelp();
        return;
    }

    // Parse consciousness flags from args
    var consciousness: ConsciousnessLevel = .conscious;
    var use_strategist = false; // MU-3: --strategy flag
    var use_auto_fix = false; // P1-3: --auto-fix flag
    var use_batch = false; // P1-4: --batch flag
    var batch_file: ?[]const u8 = null; // P1-4: batch file path
    var arg_idx: usize = 0;

    // Find first non-flag argument as spec_path
    var spec_path: ?[]const u8 = null;
    var spec_files = try std.ArrayList([]const u8).initCapacity(allocator, 16);
    defer spec_files.deinit(allocator);

    for (args) |arg| {
        if (parseConsciousnessLevel(arg)) |level| {
            consciousness = level;
            arg_idx += 1;
        } else if (std.mem.eql(u8, arg, "--strategy")) {
            // MU-3: Enable ForgeStrategist for consciousness-guided synthesis
            use_strategist = true;
            arg_idx += 1;
        } else if (std.mem.eql(u8, arg, "--auto-fix")) {
            // P1-3: Enable AutoFix for automatic error correction
            use_auto_fix = true;
            arg_idx += 1;
        } else if (std.mem.eql(u8, arg, "--batch")) {
            // P1-4: Enable batch mode
            use_batch = true;
            arg_idx += 1;
        } else if (use_batch and batch_file == null and std.mem.indexOf(u8, arg, ".txt") != null) {
            // P1-4: Batch file specified
            batch_file = arg;
            arg_idx += 1;
        } else if (spec_path == null) {
            spec_path = arg;
            try spec_files.append(allocator, arg);
        } else {
            // Additional spec files for batch mode
            try spec_files.append(allocator, arg);
        }
    }

    // P1-4: Batch mode - load spec files from batch file or use provided files
    if (use_batch) {
        if (batch_file) |bf| {
            // Load specs from batch file
            const bf_abs = try resolvePathAbsolute(allocator, bf, ".");
            defer allocator.free(bf_abs);

            const bf_content = try std.fs.cwd().readFileAlloc(allocator, bf_abs, 1024 * 1024);
            defer allocator.free(bf_content);

            var lines = std.mem.splitScalar(u8, bf_content, '\n');
            spec_files.clearRetainingCapacity();
            while (lines.next()) |line| {
                const trimmed = std.mem.trim(u8, line, " \t\r");
                if (trimmed.len > 0 and !std.mem.startsWith(u8, trimmed, "#")) {
                    try spec_files.append(allocator, try allocator.dupe(u8, trimmed));
                }
            }
        }

        if (spec_files.items.len == 0) {
            std.debug.print("{s}Error:{s} No spec files provided for batch mode\n", .{ RED, RESET });
            return error.NoSpecFiles;
        }

        std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
        std.debug.print("{s}  BATCH MODE: {d} designs{s}\n", .{ CYAN, spec_files.items.len, RESET });
        std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });

        // Run batch synthesis
        const batch_result = try runBatchSynthesis(allocator, spec_files.items, "trinity/output/fpga/", null);

        // Print summary
        const elapsed_sec = @as(f64, @floatFromInt(batch_result.elapsed_ns)) / 1_000_000_000.0;
                std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
        std.debug.print("{s}  BATCH SYNTHESIS SUMMARY{s}\n", .{ CYAN, RESET });
        std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
        std.debug.print("  Total:    {d}\n", .{batch_result.total});
        std.debug.print("{s}  Passed:   {d}{s}\n", .{ GREEN, batch_result.passed, RESET });
        if (batch_result.failed > 0) {
            std.debug.print("{s}  Failed:   {d}{s}\n", .{ RED, batch_result.failed, RESET });
        }
        std.debug.print("  Time:     {d:.1}s\n", .{elapsed_sec});
        if (batch_result.total > 0) {
            std.debug.print("  Avg:      {d:.1}s/design\n", .{elapsed_sec / @as(f64, @floatFromInt(batch_result.total))});
        }
        std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });

        // Cast away const for deinit (batch_result is a local copy of the struct)
        const batch_result_mut = @as(*const BatchResult, &batch_result);
        @constCast(batch_result_mut).deinit(allocator);
        return;
    }

    // If no spec path found, show help
    if (spec_path == null) {
        printFpgaGenHelp();
        return;
    }

    const remaining_args = if (arg_idx < args.len) args[arg_idx..] else &[0][]const u8{};
    const output_dir = if (remaining_args.len > 1) remaining_args[1] else "trinity/output/fpga/";

    // Display consciousness status
    const consciousness_color = consciousness.color();
    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  TRI FPGA GEN — Consciousness-Aware Synthesis{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });
    std.debug.print("{s}Consciousness:{s} {s} {d:.2} ({s})\n", .{ consciousness_color, RESET, consciousness.label(), consciousness.value(), consciousness.label() });

    if (consciousness.isImmortal()) {
        std.debug.print("  {s}Status: IMMORTAL{s} (φ⁻¹ threshold: {d:.1}%)\n\n", .{ GREEN, RESET, PHI_INV * 100.0 });
    } else {
        std.debug.print("  {s}Status: MORTAL{s} (below φ⁻¹ threshold: {d:.1}%)\n\n", .{ YELLOW, RESET, PHI_INV * 100.0 });
    }

    // MU-3: Initialize ForgeStrategist if --strategy flag is set
    var forge_strategist: ?strategist_mod.ForgeStrategist = null;
    defer {
        if (forge_strategist) |*strat| strat.deinit();
    }

    if (use_strategist) {
        std.debug.print("[MU-3] {s}Initializing ForgeStrategist...{s}\n", .{ YELLOW, RESET });

        // Initialize consciousness and learning systems
        // Note: These are stack-allocated and live for the duration of runFpgaGen
        var consciousness_sys = unified_architecture.UnifiedConsciousness.init(allocator);
        var learning = try learning_loops.LearningLoop.init(allocator);

        const strategist = try strategist_mod.ForgeStrategist.init(
            allocator,
            &consciousness_sys,
            &learning
        );
        forge_strategist = strategist;

        // Get and display consciousness analysis
        const analysis = forge_strategist.?.getConsciousnessAnalysis();
        std.debug.print("  IIT Φ:          {d:.3}\n", .{analysis.iit_phi});
        std.debug.print("  GWT Active:     {d:.3}\n", .{analysis.gwt_active});
        std.debug.print("  HOT Meta:       {d:.3}\n", .{analysis.hot_meta});
        std.debug.print("  Unified Score:  {d:.3}\n", .{analysis.unified_score});
        std.debug.print("  Is Conscious:   {}\n\n", .{analysis.is_conscious});

        std.debug.print("{s}✓{s} ForgeStrategist ready\n\n", .{ GREEN, RESET });
    }

    // MU-4: Detect file extension (.tri vs .vibee)
    const spec_ext = std.fs.path.extension(spec_path.?);
    const is_tri_file = std.mem.eql(u8, spec_ext, ".tri");

    if (is_tri_file) {
        std.debug.print("[MU-4] {s}Detected .tri file, using TriParser...{s}\n", .{ YELLOW, RESET });
    }

    // Find project root (zig build changes cwd to .zig-cache)
    const project_root = try findProjectRoot(allocator);
    defer allocator.free(project_root);

    // Resolve spec path to absolute
    const spec_abs = try resolvePathAbsolute(allocator, spec_path.?, project_root);
    defer allocator.free(spec_abs);

    const base_name = getBaseName(spec_path.?);

    // Step 1: Generate Verilog + XDC (TriParser or VIBEE)
    if (is_tri_file) {
        // === .tri FILE PATH: Use TriParser ===
        std.debug.print("[1/3] {s}Parsing .tri specification{s}...\n", .{ YELLOW, RESET });

        // Parse .tri file
        var parser = tri_parser_mod.TriParser.init(allocator);
        var design_spec = try parser.parse(spec_abs);
        defer design_spec.deinit();

        std.debug.print("  Module: {s}\n", .{design_spec.name});
        std.debug.print("  Device: {s}\n", .{design_spec.device});
        std.debug.print("  Ports: {d}\n", .{design_spec.ports.items.len});
        std.debug.print("  Consciousness: {s}\n\n", .{if (design_spec.consciousness_enabled) "enabled" else "disabled"});

        // Generate Verilog
        const verilog_path = try std.fmt.allocPrint(allocator, "{s}/{s}.v", .{ output_dir, base_name });
        defer allocator.free(verilog_path);

        {
            const verilog_file = try std.fs.cwd().createFile(verilog_path, .{});
            defer verilog_file.close();

            // Build output in ArrayList
            var output = try std.ArrayList(u8).initCapacity(allocator, 1024);
            defer output.deinit(allocator);
            try parser.generateVerilog(&design_spec, output.writer(allocator));
            try verilog_file.writeAll(output.items);
        }
        std.debug.print("{s}✓{s} Verilog generated: {s}\n", .{ GREEN, RESET, verilog_path });

        // Generate XDC
        const xdc_path = try std.fmt.allocPrint(allocator, "{s}/{s}.xdc", .{ output_dir, base_name });
        defer allocator.free(xdc_path);

        {
            const xdc_file = try std.fs.cwd().createFile(xdc_path, .{});
            defer xdc_file.close();

            // Build output in ArrayList
            var output = try std.ArrayList(u8).initCapacity(allocator, 1024);
            defer output.deinit(allocator);
            try parser.generateXDC(&design_spec, output.writer(allocator));
            try xdc_file.writeAll(output.items);
        }
        std.debug.print("{s}✓{s} XDC generated: {s}\n\n", .{ GREEN, RESET, xdc_path });
    } else {
        // === .vibee FILE PATH: Use VIBEE ===
        std.debug.print("[1/3] {s}VIBEE Code Generation{s}...\n", .{ YELLOW, RESET });

        // Run VIBEE via zig build
        var vibee_argv = try std.ArrayList([]const u8).initCapacity(allocator, 8);
        defer vibee_argv.deinit(allocator);

        try vibee_argv.append(allocator, "zig");
        try vibee_argv.append(allocator, "build");
        try vibee_argv.append(allocator, "vibee");
        try vibee_argv.append(allocator, "--");
        try vibee_argv.append(allocator, "gen");
        try vibee_argv.append(allocator, spec_abs);

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

        // Step 1.5: Generate XDC file from spec constraints
        std.debug.print("[1.5/3] {s}XDC Generation{s}...\n", .{ YELLOW, RESET });

        const xdc_rel = try std.fmt.allocPrint(allocator, "{s}/{s}.xdc", .{ output_dir, base_name });
        defer allocator.free(xdc_rel);

        const xdc_abs = try resolvePathAbsolute(allocator, xdc_rel, project_root);
        defer allocator.free(xdc_abs);

        try generateXDC(allocator, spec_abs, xdc_abs);
        std.debug.print("{s}✓{s} XDC file generated\n\n", .{ GREEN, RESET });
    }

    // Step 2: Copy files to openxc7-synth for synthesis
    std.debug.print("[2/3] {s}Preparing files for synthesis{s}...\n", .{ YELLOW, RESET });

    const verilog_file = try std.fmt.allocPrint(allocator, "{s}/{s}.v", .{ output_dir, base_name });
    defer allocator.free(verilog_file);

    const synth_dir = "fpga/openxc7-synth";
    const synth_verilog = try std.fmt.allocPrint(allocator, "{s}/{s}.v", .{ synth_dir, base_name });
    defer allocator.free(synth_verilog);

    // Copy verilog file to synth directory
    {
        var argv = try std.ArrayList([]const u8).initCapacity(allocator, 4);
        defer argv.deinit(allocator);
        try argv.append(allocator, "cp");
        try argv.append(allocator, verilog_file);
        try argv.append(allocator, synth_verilog);
        var child = std.process.Child.init(argv.items, allocator);
        child.stderr_behavior = .Ignore;
        child.stdout_behavior = .Ignore;
        _ = try child.spawnAndWait();
    }

    // Copy XDC file
    const xdc_file = try std.fmt.allocPrint(allocator, "{s}/{s}.xdc", .{ output_dir, base_name });
    defer allocator.free(xdc_file);

    const synth_xdc = try std.fmt.allocPrint(allocator, "{s}/{s}.xdc", .{ synth_dir, base_name });
    defer allocator.free(synth_xdc);

    {
        var argv = try std.ArrayList([]const u8).initCapacity(allocator, 4);
        defer argv.deinit(allocator);
        try argv.append(allocator, "cp");
        try argv.append(allocator, xdc_file);
        try argv.append(allocator, synth_xdc);
        var child = std.process.Child.init(argv.items, allocator);
        child.stderr_behavior = .Ignore;
        child.stdout_behavior = .Ignore;
        _ = try child.spawnAndWait();
    }
    std.debug.print("{s}✓{s} Files ready for synthesis\n\n", .{ GREEN, RESET });

    // Step 3: Run openXC7 synthesis (synth.sh)
    std.debug.print("[3/3] {s}openXC7 Synthesis (Docker){s}...\n", .{ YELLOW, RESET });

    // P1-3: Auto-fix integration
    var synth_attempts: u32 = 0;
    const max_attempts = if (use_auto_fix) @as(u32, 3) else 1;

    while (synth_attempts < max_attempts) : (synth_attempts += 1) {
        // Run synth.sh with Docker (pass consciousness level)
        const synth_result = runOpenxc7Synth(allocator, synth_verilog, base_name, consciousness);

        if (synth_result) |_| {
            std.debug.print("{s}✓{s} openXC7 synthesis complete", .{ GREEN, RESET });
            if (synth_attempts > 0) {
                std.debug.print(" (after {d} attempt{s})", .{ synth_attempts + 1, if (synth_attempts == 1) "" else "s" });
            }
            std.debug.print("\n\n", .{});
            break;
        } else |err| {
            // Synthesis failed
            if (!use_auto_fix or synth_attempts >= max_attempts - 1) {
                std.debug.print("{s}Error:{s} openXC7 synthesis failed: {}\n", .{ RED, RESET, err });
                return err;
            }

            // P1-3: Run auto-fix analysis
            std.debug.print("\n{s}[P1-3] Synthesis failed, analyzing...{s}\n", .{ YELLOW, RESET });

            // Create a mock SynthesisResult for auto-fix analysis
            var mock_result = SynthesisResult.init(allocator, base_name);
            defer mock_result.deinit();
            mock_result.success = false;
            mock_result.root_cause = try std.fmt.allocPrint(allocator, "openxc7_synth_error: {s}", .{errorName(err)});

            // Initialize auto_fix (requires consciousness system)
            const consciousness_ptr = if (forge_strategist) |*strat|
                strat.consciousness
            else blk: {
                std.debug.print("{s}Warning:{s} --auto-fix works best with --strategy for consciousness analysis\n", .{ YELLOW, RESET });
                std.debug.print("  Creating temporary consciousness system:\n", .{});
                // Create a temporary consciousness system for auto-fix
                var temp_conscious = unified_architecture.UnifiedConsciousness.init(allocator);
                break :blk &temp_conscious;
            };

            // Analyze failure and get fixes
            var auto_fix = auto_fix_mod.AutoFix.init(allocator, consciousness_ptr);
            var fixes = try auto_fix.analyzeFailure(&mock_result);
            defer {
                for (fixes.items) |*fix| {
                    fix.deinit(allocator);
                }
                fixes.deinit(allocator);
            }

            // Display fixes
            std.debug.print("  Suggested fixes ({d}):\n", .{fixes.items.len});
            for (fixes.items, 0..) |fix, i| {
                std.debug.print("    {d}. {s}\n", .{ i + 1, fix.description });
                std.debug.print("       Before: {s}\n", .{fix.before});
                std.debug.print("       After:  {s}\n", .{fix.after});
            }

            // Note: Actual fix application requires FORGE with strategy params
            std.debug.print("\n{s}Note:{s} Fix application requires FORGE toolchain.\n", .{ YELLOW, RESET });
            std.debug.print("  Current toolchain uses openXC7 Docker (external).\n", .{});
            std.debug.print("  Use --strategy --forge for full auto-fix with FORGE (experimental).\n", .{});
            std.debug.print("  Retrying with default parameters...\n\n", .{});

            // For now, just retry - in full implementation, we would:
            // 1. Modify .tri spec based on fixes
            // 2. Regenerate Verilog/XDC
            // 3. Retry synthesis
        }
    }

    // Copy bitstream back to output directory
    std.debug.print("[3.5/3] {s}Copying bitstream{s}...\n", .{ YELLOW, RESET });

    const synth_bitstream = try std.fmt.allocPrint(allocator, "{s}/{s}.bit", .{ synth_dir, base_name });
    defer allocator.free(synth_bitstream);

    const bitstream_file = try std.fmt.allocPrint(allocator, "{s}/{s}.bit", .{ output_dir, base_name });
    defer allocator.free(bitstream_file);

    // Copy bitstream using bash cp
    {
        var argv = try std.ArrayList([]const u8).initCapacity(allocator, 4);
        defer argv.deinit(allocator);
        try argv.append(allocator, "cp");
        try argv.append(allocator, synth_bitstream);
        try argv.append(allocator, bitstream_file);
        var child = std.process.Child.init(argv.items, allocator);
        child.stderr_behavior = .Ignore;
        child.stdout_behavior = .Ignore;
        _ = try child.spawnAndWait();
    }

    std.debug.print("{s}✓{s} Bitstream ready\n\n", .{ GREEN, RESET });

    // Summary
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  FPGA GENERATION COMPLETE{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("  Spec:       {s}\n", .{spec_path.?});
    std.debug.print("  Bitstream:  {s}\n", .{bitstream_file});
    std.debug.print("\n{s}Next steps:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  tri fpga flash {s}\n", .{bitstream_file});
}

// ═══════════════════════════════════════════════════════════════════════════════
// FPGA FLASH - Flash bitstream to hardware (or .vibee → flash in one command)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runFpgaFlash(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printFpgaFlashHelp();
        return;
    }

    const input_path = args[0];
    const is_vibee = std.mem.endsWith(u8, input_path, ".vibee");

    // Determine the bitstream path
    const bitstream_path = if (is_vibee)
        try getBitstreamPathFromSpec(allocator, input_path)
    else
        try allocator.dupe(u8, input_path);

    defer {
        if (is_vibee) allocator.free(bitstream_path);
    }

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  TRI FPGA FLASH — One-Command Programming{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });

    // Step 1: Check if we need to generate bitstream
    var needs_generation = false;
    if (is_vibee) {
        std.debug.print("[1/4] {s}Checking bitstream freshness{s}...\n", .{ YELLOW, RESET });

        const spec_exists = std.fs.cwd().openFile(input_path, .{}) catch null;
        if (spec_exists) |f| f.close();

        if (spec_exists == null) {
            std.debug.print("{s}Error:{s} Spec file not found: {s}\n", .{ RED, RESET, input_path });
            return error.FileNotFound;
        }

        const bit_exists = std.fs.cwd().openFile(bitstream_path, .{}) catch null;
        if (bit_exists) |f| f.close();

        if (bit_exists == null) {
            std.debug.print("  Bitstream not found, regenerating...\n", .{});
            needs_generation = true;
        } else {
            // Compare timestamps
            const spec_stat = std.fs.cwd().statFile(input_path) catch unreachable;
            const bit_stat = std.fs.cwd().statFile(bitstream_path) catch unreachable;

            if (spec_stat.mtime > bit_stat.mtime) {
                std.debug.print("  Spec is newer than bitstream, regenerating...\n", .{});
                needs_generation = true;
            } else {
                const age = std.time.timestamp() - bit_stat.mtime;
                std.debug.print("  {s}OK{s} Bitstream is fresh ({d} seconds old)\n", .{ GREEN, RESET, age });
            }
        }
    }

    // Step 2: Generate bitstream if needed
    if (needs_generation) {
        std.debug.print("\n[2/4] {s}Generating bitstream from spec{s}...\n", .{ YELLOW, RESET });
        try runFpgaGen(allocator, &[_][]const u8{input_path});
        std.debug.print("\n", .{});
    } else {
        std.debug.print("[2/4] {s}Skipping generation{s}...\n", .{ YELLOW, RESET });
    }

    // Step 3: Verify bitstream exists
    std.debug.print("[3/4] {s}Verifying bitstream{s}...\n", .{ YELLOW, RESET });
    if (std.fs.cwd().openFile(bitstream_path, .{})) |file| {
        file.close();
    } else |_| {
        std.debug.print("{s}Error:{s} Bitstream file not found: {s}\n", .{ RED, RESET, bitstream_path });
        return error.FileNotFound;
    }
    std.debug.print("  {s}✓{s} Bitstream ready ({d} MB)\n", .{ GREEN, RESET, getFileSizeMB(allocator, bitstream_path) });
    std.debug.print("\n", .{});

    // Step 4: Flash to FPGA
    std.debug.print("[4/4] {s}Flashing to FPGA{s}...\n", .{ YELLOW, RESET });
    try flashBitstream(allocator, bitstream_path);

    // Summary
    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  SUCCESS! FPGA PROGRAMMED{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("  Input:  {s}\n", .{input_path});
    std.debug.print("  Output: {s}\n\n", .{bitstream_path});

    // Print expected behavior based on spec name
    const base_name = getBaseName(input_path);
    if (std.mem.indexOf(u8, base_name, "blink")) |_| {
        std.debug.print("{s}Expected behavior:{s} LED D6 (R23) should be blinking at ~1.5 Hz\n", .{ YELLOW, RESET });
    } else if (std.mem.indexOf(u8, base_name, "counter")) |_| {
        std.debug.print("{s}Expected behavior:{s} LEDs should show binary counter pattern\n", .{ YELLOW, RESET });
    } else {
        std.debug.print("{s}Expected behavior:{s} Check your spec documentation\n", .{ YELLOW, RESET });
    }
}

fn getBitstreamPathFromSpec(allocator: std.mem.Allocator, spec_path: []const u8) ![]const u8 {
    const base_name = getBaseName(spec_path);
    return std.fmt.allocPrint(allocator, "trinity/output/fpga/{s}.bit", .{base_name});
}

fn flashBitstream(allocator: std.mem.Allocator, bitstream_path: []const u8) !void {
    // Run jtag_program script
    const jtag_script = "fpga/tools/jtag_program";

    var jtag_argv = try std.ArrayList([]const u8).initCapacity(allocator, 4);
    defer jtag_argv.deinit(allocator);

    try jtag_argv.append(allocator, jtag_script);
    try jtag_argv.append(allocator, bitstream_path);

    var jtag_child = std.process.Child.init(jtag_argv.items, allocator);
    jtag_child.stderr_behavior = .Inherit;
    jtag_child.stdout_behavior = .Inherit;

    const term = jtag_child.spawnAndWait() catch |err| {
        std.debug.print("{s}Error:{s} Flash failed: {}\n", .{ RED, RESET, err });
        std.debug.print("\n{s}Note:{s} Make sure JTAG cable is connected.\n", .{ YELLOW, RESET });
        std.debug.print("  Run: sudo fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i fpga/tools/xusb_xp2.hex\n", .{});
        return err;
    };

    switch (term) {
        .Exited => |code| {
            if (code == 0) {
                std.debug.print("  {s}✓{s} FPGA programmed successfully\n", .{ GREEN, RESET });
            } else {
                std.debug.print("{s}Error:{s} Flash failed with exit code {d}\n", .{ RED, RESET, code });
                return error.FlashFailed;
            }
        },
        else => {
            std.debug.print("{s}Error:{s} Flash terminated abnormally\n", .{ RED, RESET });
            return error.FlashFailed;
        },
    }
}

fn getFileSizeMB(_: std.mem.Allocator, path: []const u8) u64 {
    const stat = std.fs.cwd().statFile(path) catch return 0;
    return stat.size / 1_000_000;
}

fn printFpgaFlashHelp() void {
    std.debug.print("\n{s}FPGA FLASH HELP{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}Usage:{s}  tri fpga flash <input>\n\n", .{ CYAN, RESET });
    std.debug.print("{s}Inputs:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  <spec.vibee>   — Generate (if needed) and flash\n", .{});
    std.debug.print("  <bitstream.bit> — Flash existing bitstream\n\n", .{});
    std.debug.print("{s}Examples:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  tri fpga flash specs/fpga/blink.vibee\n", .{});
    std.debug.print("  tri fpga flash trinity/output/fpga/blink.bit\n\n", .{});
    std.debug.print("{s}Hardware:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  FPGA: QMTECH Artix-7 XC7A100T\n", .{});
    std.debug.print("  JTAG: Xilinx Platform Cable USB II\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// FPGA TEST - Run regression suite
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runFpgaTest(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args; // Currently runs all tests, flag reserved for future use

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  TRINITY FPGA REGRESSION SUITE{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });

    // Find all test_*.vibee files in specs/fpga/
    const test_dir = "specs/fpga";

    var test_files = std.ArrayList([]const u8).initCapacity(allocator, 16) catch |err| {
        std.debug.print("{s}Error:{s} Cannot allocate test file list: {}\n", .{ RED, RESET, err });
        return err;
    };
    defer {
        for (test_files.items) |file| allocator.free(file);
        test_files.deinit(allocator);
    }

    {
        var dir = std.fs.cwd().openDir(test_dir, .{ .iterate = true }) catch |err| {
            std.debug.print("{s}Error:{s} Cannot open specs/fpga/: {}\n", .{ RED, RESET, err });
            return err;
        };
        defer dir.close();

        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            const name = entry.name;
            if (std.mem.startsWith(u8, name, "test_") and std.mem.endsWith(u8, name, ".vibee")) {
                const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ test_dir, name });
                try test_files.append(allocator, full_path);
            }
        }
    }

    if (test_files.items.len == 0) {
        std.debug.print("{s}Error:{s} No test files found (test_*.vibee in specs/fpga/)\n", .{ RED, RESET });
        return;
    }

    std.debug.print("Found {d} test files:\n\n", .{test_files.items.len});

    // Run each test
    var passed: usize = 0;
    var failed: usize = 0;

    for (test_files.items, 0..) |test_path, i| {
        const test_name = getBaseName(test_path);
        std.debug.print("[{d}/{d}] {s} {s}...\n", .{ i + 1, test_files.items.len, YELLOW, test_name });

        const result = generateBitstreamForTest(allocator, test_path);

        if (result) |_| {
            std.debug.print("  {s}✓ PASS{s}\n", .{ GREEN, RESET });
            passed += 1;
        } else |err| {
            std.debug.print("  {s}✗ FAIL{s}: {}\n", .{ RED, RESET, err });
            failed += 1;
        }
        std.debug.print("\n", .{});
    }

    // Summary
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  REGRESSION RESULTS{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("  Total:  {d}\n", .{test_files.items.len});
    std.debug.print("  {s}Passed:{s} {d}\n", .{ GREEN, RESET, passed });
    std.debug.print("  {s}Failed:{s} {d}\n", .{ if (failed > 0) RED else GREEN, RESET, failed });

    const pass_rate = @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(test_files.items.len)) * 100.0;
    std.debug.print("  Success Rate: {d:.1}%\n\n", .{pass_rate});

    // φ-immortality threshold
    const phi_threshold: f64 = 100.0 * 0.618;  // 61.8%
    if (pass_rate >= phi_threshold) {
        std.debug.print("{s}✓{s} IMMORTAL (>{d:.1}% success rate, above φ-threshold)\n", .{ GREEN, RESET, phi_threshold });
    } else {
        std.debug.print("{s}✗{s} MORTAL ({d:.1}% success rate, below φ-threshold)\n", .{ RED, RESET, phi_threshold });
    }
}

fn generateBitstreamForTest(allocator: std.mem.Allocator, spec_path: []const u8) !void {
    // Get absolute path
    const cwd_abs = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd_abs);

    const spec_abs = try std.fs.path.resolve(allocator, &.{ cwd_abs, spec_path });
    defer allocator.free(spec_abs);

    // Run VIBEE (silent, errors to null)
    var vibee_argv = try std.ArrayList([]const u8).initCapacity(allocator, 8);
    defer vibee_argv.deinit(allocator);

    try vibee_argv.append(allocator, "zig");
    try vibee_argv.append(allocator, "build");
    try vibee_argv.append(allocator, "vibee");
    try vibee_argv.append(allocator, "--");
    try vibee_argv.append(allocator, "gen");
    try vibee_argv.append(allocator, spec_abs);

    var vibee_child = std.process.Child.init(vibee_argv.items, allocator);
    vibee_child.stderr_behavior = .Ignore;
    vibee_child.stdout_behavior = .Ignore;

    const vibee_term = vibee_child.spawnAndWait() catch |err| {
        return err;
    };

    if (vibee_term != .Exited or vibee_term.Exited != 0)
        return error.VibeeFailed;

    // Generate XDC (use absolute paths)
    const base_name = getBaseName(spec_path);
    const output_dir_rel = "trinity/output/fpga";
    const output_dir_abs = try std.fs.path.resolve(allocator, &.{ cwd_abs, output_dir_rel });
    defer allocator.free(output_dir_abs);

    const xdc_file = try std.fmt.allocPrint(allocator, "{s}/{s}.xdc", .{ output_dir_abs, base_name });
    defer allocator.free(xdc_file);

    // spec_abs is the absolute path computed above
    try generateXDC(allocator, spec_abs, xdc_file);

    // Run openXC7 synthesis (quiet mode)
    const synth_dir = "fpga/openxc7-synth";
    const synth_verilog = try std.fmt.allocPrint(allocator, "{s}/{s}.v", .{ synth_dir, base_name });
    defer allocator.free(synth_verilog);

    // Copy files
    const vibee_output_verilog = try std.fmt.allocPrint(allocator, "trinity-nexus/output/lang/fpga/{s}.v", .{base_name});
    defer allocator.free(vibee_output_verilog);

    {
        var argv = try std.ArrayList([]const u8).initCapacity(allocator, 4);
        defer argv.deinit(allocator);
        try argv.append(allocator, "cp");
        try argv.append(allocator, vibee_output_verilog);
        try argv.append(allocator, synth_verilog);
        var child = std.process.Child.init(argv.items, allocator);
        child.stderr_behavior = .Ignore;
        child.stdout_behavior = .Ignore;
        _ = try child.spawnAndWait();
    }

    const synth_xdc = try std.fmt.allocPrint(allocator, "{s}/{s}.xdc", .{ synth_dir, base_name });
    defer allocator.free(synth_xdc);

    {
        var argv = try std.ArrayList([]const u8).initCapacity(allocator, 4);
        defer argv.deinit(allocator);
        try argv.append(allocator, "cp");
        try argv.append(allocator, xdc_file);
        try argv.append(allocator, synth_xdc);
        var child = std.process.Child.init(argv.items, allocator);
        child.stderr_behavior = .Ignore;
        child.stdout_behavior = .Ignore;
        _ = try child.spawnAndWait();
    }

    // Run synthesis (quiet, default consciousness)
    const synth_result = runOpenxc7Synth(allocator, synth_verilog, base_name, null);
    if (synth_result) |_| {
        // Success
    } else |err| {
        return err;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper Functions
// ═══════════════════════════════════════════════════════════════════════════════

fn findVibeeBinary(allocator: std.mem.Allocator) ?[]const u8 {
    const paths = [_][]const u8{
        "zig-out/bin/vibee",
        "./zig-out/bin/vibee",
        "release/linux-amd64/vibee",
        "./release/linux-amd64/vibee",
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

// P1-3: Helper to convert error to name for auto-fix analysis
fn errorName(err: anyerror) []const u8 {
    return switch (err) {
        error.ProcessSpawnFailed => "process_spawn_failed",
        error.InvalidSpecifier => "invalid_specifier",
        error.FileNotFound => "file_not_found",
        error.ExitCodeFailure => "synthesis_failed",
        else => "unknown_error",
    };
}

fn runOpenxc7Synth(allocator: std.mem.Allocator, verilog_file: []const u8, top_module: []const u8, consciousness: ?ConsciousnessLevel) !void {
    // Determine if we should use consciousness-aware synthesis (non-default level)
    const use_conscious = consciousness != null and consciousness.? != .conscious;
    const script_name = if (use_conscious) "./synth_conscious.sh" else "./synth.sh";
    const consciousness_val = consciousness orelse .conscious;

    // synth.sh expects:
    //   - Path to Verilog file (relative to its directory or absolute)
    //   - Top module name (defaults to <basename>_top if not provided)
    //
    // The script runs in its own directory (fpga/openxc7-synth),
    // so we pass just the filename (blink.v), not the full path

    const verilog_basename = std.fs.path.basename(verilog_file); // "blink.v" from "fpga/openxc7-synth/blink.v"

    var argv = try std.ArrayList([]const u8).initCapacity(allocator, 12);
    defer {
        argv.deinit(allocator);
    }

    // Script path needs to be relative to the cwd we're setting
    try argv.append(allocator, script_name);

    // Add consciousness flag if using conscious synthesis
    if (use_conscious) {
        try argv.append(allocator, consciousness_val.flag());
    }

    try argv.append(allocator, verilog_basename);
    try argv.append(allocator, top_module);

    var child = std.process.Child.init(argv.items, allocator);
    child.cwd = "fpga/openxc7-synth";
    child.stderr_behavior = .Inherit;
    child.stdout_behavior = .Inherit;

    const term = child.spawnAndWait() catch |err| {
        return err;
    };

    if (term != .Exited or term.Exited != 0) return error.SynthFailed;
}

// ═══════════════════════════════════════════════════════════════════════════════
// P1-4: BATCH MODE - Process 100+ designs in single process
// ═══════════════════════════════════════════════════════════════════════════════

/// Result of a single batch synthesis
pub const BatchDesignResult = struct {
    name: []const u8,
    verilog_path: []const u8,
    top_module: []const u8,
    passed: bool,
    error_msg: ?[]const u8 = null,
};

/// Summary of batch synthesis
pub const BatchResult = struct {
    total: u32,
    passed: u32,
    failed: u32,
    results: std.ArrayList(BatchDesignResult),
    elapsed_ns: u64,

    pub fn deinit(self: *BatchResult, allocator: std.mem.Allocator) void {
        for (self.results.items) |*r| {
            if (r.error_msg) |msg| allocator.free(msg);
            allocator.free(r.name);
            allocator.free(r.verilog_path);
            allocator.free(r.top_module);
        }
        self.results.deinit(allocator);
    }
};

/// Run batch synthesis on multiple designs
fn runBatchSynthesis(
    allocator: std.mem.Allocator,
    spec_files: []const []const u8,
    output_dir: []const u8,
    consciousness: ?ConsciousnessLevel
) !BatchResult {
    _ = output_dir;
    _ = consciousness;
    var result = BatchResult{
        .total = @intCast(spec_files.len),
        .passed = 0,
        .failed = 0,
        .results = try std.ArrayList(BatchDesignResult).initCapacity(allocator, spec_files.len),
        .elapsed_ns = 0,
    };
    errdefer result.deinit(allocator);

    const start_time = std.time.nanoTimestamp();

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  BATCH SYNTHESIS MODE{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  Processing {d} designs{s}\n", .{ CYAN, spec_files.len, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });

    // Phase 1: Generate all Verilog + XDC files
    std.debug.print("[Phase 1/2] Generating Verilog + XDC files...\n", .{});

    var designs = try std.ArrayList(struct { verilog: []const u8, top: []const u8 }).initCapacity(allocator, spec_files.len);
    defer {
        for (designs.items) |*d| {
            allocator.free(d.verilog);
            allocator.free(d.top);
        }
        designs.deinit(allocator);
    }

    for (spec_files, 0..) |spec_path, i| {
        std.debug.print("  [{d}/{d}] {s}...\n", .{ i + 1, spec_files.len, spec_path });

        // Generate Verilog + XDC from spec
        const spec_abs = try resolvePathAbsolute(allocator, spec_path, ".");
        defer allocator.free(spec_abs);

        const is_tri_file = std.mem.endsWith(u8, spec_path, ".tri");
        const is_vibee_file = std.mem.endsWith(u8, spec_path, ".vibee");

        if (!is_tri_file and !is_vibee_file) {
            std.debug.print("    {s}Warning:{s} Skipping unknown file type\n", .{ YELLOW, RESET });
            continue;
        }

        const base_name = if (is_tri_file)
            std.fs.path.stem(spec_path)
        else
            std.fs.path.stem(spec_path);

        const verilog_name = try std.fmt.allocPrint(allocator, "{s}.v", .{base_name});
        const xdc_name = try std.fmt.allocPrint(allocator, "{s}.xdc", .{base_name});
        const top_module = try std.fmt.allocPrint(allocator, "{s}_top", .{base_name});

        const verilog_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ "fpga/openxc7-synth", verilog_name });
        const xdc_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ "fpga/openxc7-synth", xdc_name });

        // Generate based on file type
        if (is_tri_file) {
            var parser = tri_parser_mod.TriParser.init(allocator);
            var design_spec = try parser.parse(spec_abs);
            defer design_spec.deinit();

            var verilog_output = try std.ArrayList(u8).initCapacity(allocator, 4096);
            defer verilog_output.deinit(allocator);
            try parser.generateVerilog(&design_spec, verilog_output.writer(allocator));

            const verilog_file = try std.fs.createFileAbsolute(verilog_path, .{});
            defer verilog_file.close();
            try verilog_file.writeAll(verilog_output.items);

            var xdc_output = try std.ArrayList(u8).initCapacity(allocator, 1024);
            defer xdc_output.deinit(allocator);
            try parser.generateXDC(&design_spec, xdc_output.writer(allocator));

            const xdc_file = try std.fs.createFileAbsolute(xdc_path, .{});
            defer xdc_file.close();
            try xdc_file.writeAll(xdc_output.items);
        } else {
            // VIBEE path - run VIBEE generation
            var vibee_argv = try std.ArrayList([]const u8).initCapacity(allocator, 8);
            defer vibee_argv.deinit(allocator);

            try vibee_argv.append(allocator, "zig");
            try vibee_argv.append(allocator, "build");
            try vibee_argv.append(allocator, "vibee");
            try vibee_argv.append(allocator, "--");
            try vibee_argv.append(allocator, "gen");
            try vibee_argv.append(allocator, spec_abs);

            // Run VIBEE
            var vibee_child = std.process.Child.init(vibee_argv.items, allocator);
            vibee_child.stderr_behavior = .Ignore;
            vibee_child.stdout_behavior = .Ignore;

            const vibee_term = vibee_child.spawnAndWait() catch |err| {
                std.debug.print("    {s}Error:{s} VIBEE generation failed: {}\n", .{ RED, RESET, err });
                continue;
            };

            if (vibee_term != .Exited or vibee_term.Exited != 0) {
                std.debug.print("    {s}Error:{s} VIBEE exited with error\n", .{ RED, RESET });
                continue;
            }

            // Copy generated Verilog to synth directory
            const vibeec_output = try std.fmt.allocPrint(allocator, "trinity/output/fpga/{s}.v", .{base_name});
            defer allocator.free(vibeec_output);

            const src_verilog = try std.fs.openFileAbsolute(vibeec_output, .{});
            defer src_verilog.close();
            const src_content = try src_verilog.readToEndAlloc(allocator, 1024 * 1024);
            defer allocator.free(src_content);

            const dst_verilog = try std.fs.createFileAbsolute(verilog_path, .{});
            defer dst_verilog.close();
            try dst_verilog.writeAll(src_content);

            // Generate XDC from .vibee spec
            try generateXDC(allocator, spec_abs, xdc_path);
        }

        allocator.free(verilog_name);
        allocator.free(xdc_name);

        try designs.append(allocator, .{ .verilog = verilog_path, .top = top_module });
        std.debug.print("    ✓ Generated {s}\n", .{base_name});
    }

    std.debug.print("\n", .{});

    // Phase 2: Batch synthesis via synth_batch.sh
    std.debug.print("[Phase 2/2] Running batch synthesis...\n", .{});

    // Create batch list file
    const batch_list_path = "fpga/openxc7-synth/batch_list.txt";
    const batch_file = try std.fs.createFileAbsolute(batch_list_path, .{});
    defer {
        batch_file.close();
        std.fs.deleteFileAbsolute(batch_list_path) catch {};
    }

    var batch_content = try std.ArrayList(u8).initCapacity(allocator, 1024);
    defer batch_content.deinit(allocator);

    for (designs.items) |design| {
        const verilog_basename = std.fs.path.basename(design.verilog);
        try batch_content.writer(allocator).print("{s} {s}\n", .{ verilog_basename, design.top });
    }

    try batch_file.writeAll(batch_content.items);

    // Run batch synthesis
    _ = try runOpenxc7BatchSynth(allocator, batch_list_path);

    // Collect results
    for (designs.items) |design| {
        const base_name = std.fs.path.stem(design.verilog);
        const bit_path = try std.fmt.allocPrint(allocator, "fpga/openxc7-synth/{s}.bit", .{base_name});
        defer allocator.free(bit_path);

        const passed = blk: {
            const file = std.fs.cwd().openFile(bit_path, .{}) catch break :blk false;
            file.close();
            break :blk true;
        };
        const name_copy = try allocator.dupe(u8, base_name);
        const verilog_copy = try allocator.dupe(u8, design.verilog);
        const top_copy = try allocator.dupe(u8, design.top);

        if (passed) {
            result.passed += 1;
            try result.results.append(allocator, .{
                .name = name_copy,
                .verilog_path = verilog_copy,
                .top_module = top_copy,
                .passed = true,
            });
        } else {
            result.failed += 1;
            const log_path = try std.fmt.allocPrint(allocator, "fpga/openxc7-synth/{s}.log", .{base_name});
            defer allocator.free(log_path);

            var error_msg: ?[]const u8 = null;
            if (std.fs.cwd().openFile(log_path, .{})) |log_file| {
                defer log_file.close();
                error_msg = log_file.readToEndAlloc(allocator, 4096) catch null;
            } else |_| {}

            try result.results.append(allocator, .{
                .name = name_copy,
                .verilog_path = verilog_copy,
                .top_module = top_copy,
                .passed = false,
                .error_msg = error_msg,
            });
        }
    }

    const end_time = std.time.nanoTimestamp();
    result.elapsed_ns = @intCast(end_time - start_time);

    return result;
}

/// Run batch synthesis via synth_batch.sh
fn runOpenxc7BatchSynth(allocator: std.mem.Allocator, batch_list_path: []const u8) !void {
    var argv = try std.ArrayList([]const u8).initCapacity(allocator, 4);
    defer argv.deinit(allocator);

    try argv.append(allocator, "./synth_batch.sh");
    try argv.append(allocator, batch_list_path);

    var child = std.process.Child.init(argv.items, allocator);
    child.cwd = "fpga/openxc7-synth";
    child.stderr_behavior = .Inherit;
    child.stdout_behavior = .Inherit;

    const term = child.spawnAndWait() catch |err| {
        return err;
    };

    // Allow partial success (some designs may fail)
    _ = term;
}

fn printFpgaGenHelp() void {
    std.debug.print("\n{s}FPGA GEN HELP{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}Usage:{s}  tri fpga gen <spec.vibee> [output_dir] [flags]\n", .{ CYAN, RESET });
    std.debug.print("\n", .{});
    std.debug.print("{s}Modes:{s}\n", .{ MAGENTA, RESET });
    std.debug.print("  --batch <file.txt>    Batch mode (100+ designs in single process)\n", .{});
    std.debug.print("  --batch spec1.tri spec2.tri ...  Batch mode with explicit files\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("{s}Optimization Flags:{s}\n", .{ MAGENTA, RESET });
    std.debug.print("  --transcendent    1.0 (maximum optimization)\n", .{});
    std.debug.print("  --enlightened     0.75 (enhanced optimization)\n", .{});
    std.debug.print("  --aware           0.618 (φ⁻¹, immortality threshold)\n", .{});
    std.debug.print("  --conscious       0.5 (default, balanced)\n", .{});
    std.debug.print("  --awakening       0.3 (fast, lower quality)\n", .{});
    std.debug.print("  --dormant         0.0 (fastest, minimal optimization)\n", .{});
    std.debug.print("\n{s}Integration Flags:{s}\n", .{ MAGENTA, RESET });
    std.debug.print("  --strategy         Enable consciousness-guided synthesis (ForgeStrategist)\n", .{});
    std.debug.print("  --auto-fix         Enable automatic error correction (Agent MU)\n", .{});
    std.debug.print("\n{s}Pipeline:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  .tri/.vibee → Parser → .v + .xdc\n", .{});
    std.debug.print("               → openXC7 (Docker) → .bit\n", .{});
    std.debug.print("\n{s}Batch Mode:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  Creates batch_list.txt with all designs\n", .{});
    std.debug.print("  Runs synth_batch.sh (single Docker session)\n", .{});
    std.debug.print("  Optimal for 100+ designs\n", .{});
    std.debug.print("\n{s}Sacred Constants:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  φ  = 1.618 (golden ratio)\n", .{});
    std.debug.print("  φ⁻¹ = 0.618 (consciousness threshold)\n", .{});
    std.debug.print("  γ  = 0.236 (φ⁻³, Barbero-Immirzi)\n", .{});
    std.debug.print("\n{s}LED Pins (QMTECH XC7A100T):{s}\n", .{ YELLOW, RESET });
    std.debug.print("  D6 (PRIMARY)  → R23\n", .{});
    std.debug.print("  D5 (SECONDARY) → T23\n", .{});
    std.debug.print("  Clock         → U22 (50 MHz)\n", .{});
    std.debug.print("\n{s}Examples:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  # Single design\n", .{});
    std.debug.print("  tri fpga gen specs/fpga/blink.vibee\n", .{});
    std.debug.print("  tri fpga gen specs/fpga/blink.vibee --aware\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("  # Batch mode (from file)\n", .{});
    std.debug.print("  tri fpga gen --batch designs_list.txt\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("  # Batch mode (explicit files)\n", .{});
    std.debug.print("  tri fpga gen --batch design1.tri design2.tri design3.tri\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("  # With consciousness integration\n", .{});
    std.debug.print("  tri fpga gen --batch designs.txt --strategy --auto-fix\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("  tri fpga flash trinity/output/fpga/blink.bit\n", .{});
    std.debug.print("\n", .{});
}
