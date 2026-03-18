// @origin(spec:tri_strict.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Strict Mode (VIBEE-First Workflow Enforcement)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Enforces that all development goes through .tri specifications first.
// Protected paths (trinity/output/, generated/) must not be directly edited.
//
// Sub-commands:
//   tri strict enable    - Activate strict mode (creates .trinity-strict-mode)
//   tri strict disable   - Deactivate strict mode (removes marker)
//   tri strict status    - Show current mode and enforcement rules
//   tri strict check     - Validate VIBEE-first compliance
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const WHITE = colors.WHITE;
const GRAY = colors.GRAY;
const RED = colors.RED;
const CYAN = colors.CYAN;
const RESET = colors.RESET;

/// Marker file placed in project root when strict mode is active
const STRICT_MODE_MARKER = ".trinity-strict-mode";

// ═══════════════════════════════════════════════════════════════════════════════
// TOP-LEVEL DISPATCHER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runStrictCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    if (args.len < 1) {
        printStrictHelp();
        return;
    }

    const subcmd = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcmd, "enable")) {
        runStrictEnable();
    } else if (std.mem.eql(u8, subcmd, "disable")) {
        runStrictDisable();
    } else if (std.mem.eql(u8, subcmd, "status")) {
        runStrictStatus();
    } else if (std.mem.eql(u8, subcmd, "check")) {
        runStrictCheck(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "fix")) {
        runStrictFix(allocator, sub_args);
    } else {
        std.debug.print("{s}Unknown strict subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printStrictHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELP
// ═══════════════════════════════════════════════════════════════════════════════

fn printStrictHelp() void {
    std.debug.print("\n{s}VIBEE-First Strict Mode{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });
    std.debug.print("Enforces that all code in protected directories comes from\n", .{});
    std.debug.print(".tri specifications. Direct edits to generated code are flagged.\n\n", .{});
    std.debug.print("{s}Usage:{s} tri strict <subcommand> [args...]\n\n", .{ CYAN, RESET });
    std.debug.print("{s}Subcommands:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}enable{s}          Activate strict mode (creates .trinity-strict-mode)\n", .{ GREEN, RESET });
    std.debug.print("  {s}disable{s}         Deactivate strict mode (removes marker)\n", .{ GREEN, RESET });
    std.debug.print("  {s}status{s}          Show current mode and enforcement rules\n", .{ GREEN, RESET });
    std.debug.print("  {s}check{s} [path]    Validate VIBEE-first compliance for path or project\n", .{ GREEN, RESET });
    std.debug.print("  {s}fix{s} [--dry-run]  Auto-generate missing .tri specs from generated code\n", .{ GREEN, RESET });
    std.debug.print("\n{s}Protected directories (NEVER edit directly):{s}\n", .{ RED, RESET });
    std.debug.print("  trinity/output/*.zig    Auto-generated from .tri\n", .{});
    std.debug.print("  trinity/output/fpga/*.v Auto-generated from .tri\n", .{});
    std.debug.print("  generated/*.zig         Auto-generated from .tri\n", .{});
    std.debug.print("\n{s}Source of truth (OK to edit):{s}\n", .{ GREEN, RESET });
    std.debug.print("  specs/tri/*.tri       VIBEE specifications\n", .{});
    std.debug.print("  src/vibeec/*.zig        Compiler source\n", .{});
    std.debug.print("  src/*.zig               Core library\n", .{});
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARKER FILE
// ═══════════════════════════════════════════════════════════════════════════════

fn isStrictModeEnabled() bool {
    std.fs.cwd().access(STRICT_MODE_MARKER, .{}) catch return false;
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENABLE
// ═══════════════════════════════════════════════════════════════════════════════

fn runStrictEnable() void {
    if (isStrictModeEnabled()) {
        std.debug.print("{s}Strict mode is already enabled.{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const file = std.fs.cwd().createFile(STRICT_MODE_MARKER, .{}) catch |err| {
        std.debug.print("{s}Error creating marker file: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer file.close();

    const timestamp = std.time.timestamp();
    var buf: [512]u8 = undefined;
    const content = std.fmt.bufPrint(&buf,
        \\VIBEE-FIRST STRICT MODE ENABLED
        \\Activated: {d} (unix timestamp)
        \\Protected: trinity/output/, generated/
        \\Source of truth: specs/tri/*.tri
        \\
        \\Rules:
        \\  1. ALL application code MUST be generated from .tri specifications
        \\  2. Files in trinity/output/ and generated/ must NOT be edited directly
        \\  3. Workflow: spec -> gen -> test -> assess
        \\  4. Only specs/tri/*.tri, src/vibeec/*.zig, src/*.zig are directly editable
    , .{timestamp}) catch |err| {
        std.debug.print("{s}Error formatting marker: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    file.writeAll(content) catch |err| {
        std.debug.print("{s}Error writing marker file: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    std.debug.print("\n{s}STRICT MODE ENABLED{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ GRAY, RESET });
    std.debug.print("  Marker: {s}{s}{s}\n", .{ CYAN, STRICT_MODE_MARKER, RESET });
    std.debug.print("  Protected: trinity/output/, generated/\n", .{});
    std.debug.print("  Source of truth: specs/tri/*.tri\n", .{});
    std.debug.print("\n  Run {s}tri strict check{s} to validate compliance.\n", .{ GREEN, RESET });
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISABLE
// ═══════════════════════════════════════════════════════════════════════════════

fn runStrictDisable() void {
    if (!isStrictModeEnabled()) {
        std.debug.print("{s}Strict mode is already disabled.{s}\n", .{ GOLDEN, RESET });
        return;
    }

    std.fs.cwd().deleteFile(STRICT_MODE_MARKER) catch |err| {
        std.debug.print("{s}Error removing marker file: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    std.debug.print("\n{s}STRICT MODE DISABLED{s}\n", .{ RED, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ GRAY, RESET });
    std.debug.print("  Marker removed: {s}\n", .{STRICT_MODE_MARKER});
    std.debug.print("  Direct edits to generated files are no longer enforced.\n", .{});
    std.debug.print("\n{s}WARNING:{s} VIBEE-first workflow is still recommended.\n", .{ GOLDEN, RESET });
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS
// ═══════════════════════════════════════════════════════════════════════════════

fn runStrictStatus() void {
    const enabled = isStrictModeEnabled();

    std.debug.print("\n{s}VIBEE-First Strict Mode Status{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    if (enabled) {
        std.debug.print("  Status: {s}ENABLED{s}\n", .{ GREEN, RESET });
        std.debug.print("  Marker: {s}{s}{s} (present)\n", .{ CYAN, STRICT_MODE_MARKER, RESET });
    } else {
        std.debug.print("  Status: {s}DISABLED{s}\n", .{ RED, RESET });
        std.debug.print("  Marker: {s}{s}{s} (absent)\n", .{ GRAY, STRICT_MODE_MARKER, RESET });
    }

    std.debug.print("\n{s}Enforcement Rules:{s}\n", .{ CYAN, RESET });
    std.debug.print("  1. All code in protected dirs MUST come from .tri specs\n", .{});
    std.debug.print("  2. Workflow: spec ({s}specs/tri/*.tri{s}) -> gen -> test -> assess\n", .{ GREEN, RESET });
    std.debug.print("\n{s}Protected Directories:{s}\n", .{ RED, RESET });
    std.debug.print("  trinity/output/*.zig      (auto-generated)\n", .{});
    std.debug.print("  trinity/output/fpga/*.v   (auto-generated)\n", .{});
    std.debug.print("  generated/*.zig           (auto-generated)\n", .{});
    std.debug.print("\n{s}Editable Directories:{s}\n", .{ GREEN, RESET });
    std.debug.print("  specs/tri/*.tri         (source of truth)\n", .{});
    std.debug.print("  src/vibeec/*.zig          (compiler source)\n", .{});
    std.debug.print("  src/*.zig                 (core library)\n", .{});
    std.debug.print("  docs/*.md                 (documentation)\n", .{});
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHECK (VIBEE-First Compliance Validation)
// ═══════════════════════════════════════════════════════════════════════════════

fn runStrictCheck(allocator: std.mem.Allocator, args: []const []const u8) void {
    const check_path: ?[]const u8 = if (args.len > 0) args[0] else null;

    std.debug.print("\n{s}VIBEE-First Compliance Check{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    if (!isStrictModeEnabled()) {
        std.debug.print("  {s}[WARN]{s} Strict mode is not enabled. Running check anyway.\n", .{ GOLDEN, RESET });
        std.debug.print("  Use {s}tri strict enable{s} to activate enforcement.\n\n", .{ GREEN, RESET });
    }

    var total_files: usize = 0;
    var violations: usize = 0;
    var warnings: usize = 0;

    if (check_path) |path| {
        if (isProtectedPath(path)) {
            checkSingleFile(path, &violations, &warnings);
            total_files = 1;
        } else {
            std.debug.print("  {s}[OK]{s} {s} is not in a protected directory\n", .{ GREEN, RESET, path });
            total_files = 1;
        }
    } else {
        std.debug.print("  Scanning protected directories...\n\n", .{});
        total_files += scanDirectoryRecursive(allocator, "trinity/output", &violations, &warnings);
        total_files += scanDirectoryRecursive(allocator, "generated", &violations, &warnings);
    }

    // Summary
    std.debug.print("\n{s}Summary:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Files scanned: {d}\n", .{total_files});

    if (violations > 0) {
        std.debug.print("  Violations:    {s}{d}{s}\n", .{ RED, violations, RESET });
    } else {
        std.debug.print("  Violations:    {s}0{s}\n", .{ GREEN, RESET });
    }

    if (warnings > 0) {
        std.debug.print("  Warnings:      {s}{d}{s}\n", .{ GOLDEN, warnings, RESET });
    } else {
        std.debug.print("  Warnings:      0\n", .{});
    }

    if (violations == 0 and warnings == 0 and total_files > 0) {
        std.debug.print("\n  {s}[PASS]{s} All files comply with VIBEE-first workflow.\n", .{ GREEN, RESET });
    } else if (violations > 0) {
        std.debug.print("\n  {s}[FAIL]{s} VIBEE-first violations detected!\n", .{ RED, RESET });
        std.debug.print("  Fix: Create .tri specs and regenerate.\n", .{});
    } else if (warnings > 0) {
        std.debug.print("\n  {s}[WARN]{s} Some files need attention.\n", .{ GOLDEN, RESET });
    } else {
        std.debug.print("\n  {s}[OK]{s} No protected files found to check.\n", .{ GREEN, RESET });
    }

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn isProtectedPath(path: []const u8) bool {
    if (std.mem.startsWith(u8, path, "trinity/output/")) return true;
    if (std.mem.startsWith(u8, path, "generated/")) return true;
    if (std.mem.startsWith(u8, path, "./trinity/output/")) return true;
    if (std.mem.startsWith(u8, path, "./generated/")) return true;
    return false;
}

fn scanDirectoryRecursive(allocator: std.mem.Allocator, dir_path: []const u8, violations: *usize, warnings: *usize) usize {
    _ = allocator;
    var count: usize = 0;

    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch {
        std.debug.print("  {s}[SKIP]{s} Directory not found: {s}\n", .{ GRAY, RESET, dir_path });
        return 0;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        var path_buf: [512]u8 = undefined;
        const full_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir_path, entry.name }) catch continue;

        if (entry.kind == .directory) {
            count += scanDirectoryRecursive(undefined, full_path, violations, warnings);
        } else if (entry.kind == .file) {
            checkSingleFile(full_path, violations, warnings);
            count += 1;
        }
    }

    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIX (Auto-generate missing .tri specs)
// ═══════════════════════════════════════════════════════════════════════════════

fn runStrictFix(allocator: std.mem.Allocator, args: []const []const u8) void {
    var dry_run = false;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--dry-run")) dry_run = true;
    }

    std.debug.print("\n{s}VIBEE-First Auto-Fix{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ GRAY, RESET });
    if (dry_run) {
        std.debug.print("  Mode: {s}DRY RUN{s} (no files written)\n\n", .{ GOLDEN, RESET });
    } else {
        std.debug.print("  Mode: {s}LIVE{s} (writing .tri specs)\n\n", .{ GREEN, RESET });
    }

    var created: usize = 0;
    var skipped: usize = 0;
    var errors: usize = 0;

    // Scan generated/ directory
    fixDirectory(allocator, "generated", dry_run, &created, &skipped, &errors);
    // Scan trinity/output/ directory
    fixDirectoryRecursive(allocator, "trinity/output", dry_run, &created, &skipped, &errors);

    // Summary
    std.debug.print("\n{s}Fix Summary:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Specs created: {s}{d}{s}\n", .{ GREEN, created, RESET });
    std.debug.print("  Already exist: {d}\n", .{skipped});
    if (errors > 0) {
        std.debug.print("  Errors:        {s}{d}{s}\n", .{ RED, errors, RESET });
    }

    if (dry_run) {
        std.debug.print("\n  {s}[DRY RUN]{s} No files were written. Run without --dry-run to apply.\n", .{ GOLDEN, RESET });
    } else if (created > 0) {
        std.debug.print("\n  {s}[DONE]{s} Created {d} skeleton .tri specs in specs/tri/\n", .{ GREEN, RESET, created });
        std.debug.print("  Run {s}tri strict check{s} to verify compliance.\n", .{ GREEN, RESET });
    }

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

fn fixDirectory(allocator: std.mem.Allocator, dir_path: []const u8, dry_run: bool, created: *usize, skipped: *usize, errors: *usize) void {
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch {
        std.debug.print("  {s}[SKIP]{s} Directory not found: {s}\n", .{ GRAY, RESET, dir_path });
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        var path_buf: [512]u8 = undefined;
        const full_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir_path, entry.name }) catch continue;
        fixSingleFile(allocator, full_path, entry.name, dry_run, created, skipped, errors);
    }
}

fn fixDirectoryRecursive(allocator: std.mem.Allocator, dir_path: []const u8, dry_run: bool, created: *usize, skipped: *usize, errors: *usize) void {
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch {
        std.debug.print("  {s}[SKIP]{s} Directory not found: {s}\n", .{ GRAY, RESET, dir_path });
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        var path_buf: [512]u8 = undefined;
        const full_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir_path, entry.name }) catch continue;

        if (entry.kind == .directory) {
            fixDirectoryRecursive(allocator, full_path, dry_run, created, skipped, errors);
        } else if (entry.kind == .file) {
            fixSingleFile(allocator, full_path, entry.name, dry_run, created, skipped, errors);
        }
    }
}

fn fixSingleFile(allocator: std.mem.Allocator, full_path: []const u8, filename: []const u8, dry_run: bool, created: *usize, skipped: *usize, errors: *usize) void {
    // Get stem
    const stem = blk: {
        if (std.mem.endsWith(u8, filename, ".zig")) break :blk filename[0 .. filename.len - 4];
        if (std.mem.endsWith(u8, filename, ".v")) break :blk filename[0 .. filename.len - 2];
        return; // Skip non-code files
    };

    // Check if spec already exists
    var spec_path_buf: [512]u8 = undefined;
    const spec_path = std.fmt.bufPrint(&spec_path_buf, "specs/tri/{s}.tri", .{stem}) catch return;

    const spec_exists = blk: {
        std.fs.cwd().access(spec_path, .{}) catch break :blk false;
        break :blk true;
    };

    if (spec_exists) {
        skipped.* += 1;
        return;
    }

    // Read the generated file to extract info
    const source = std.fs.cwd().readFileAlloc(allocator, full_path, 256 * 1024) catch {
        std.debug.print("  {s}[ERR]{s} Cannot read: {s}\n", .{ RED, RESET, full_path });
        errors.* += 1;
        return;
    };
    defer allocator.free(source);

    // Parse constants and functions from the source
    var const_count: usize = 0;
    var fn_count: usize = 0;
    var lines_iter = std.mem.splitScalar(u8, source, '\n');
    while (lines_iter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &[_]u8{' ', '\t', '\r'});
        if (std.mem.startsWith(u8, trimmed, "pub const ") and std.mem.indexOf(u8, trimmed, ": f64 =") != null) {
            const_count += 1;
        }
        if (std.mem.startsWith(u8, trimmed, "pub fn ")) {
            fn_count += 1;
        }
    }

    // Determine language from extension
    const lang = if (std.mem.endsWith(u8, filename, ".v")) "varlog" else "zig";

    if (dry_run) {
        std.debug.print("  {s}[WOULD CREATE]{s} {s} ({d} const, {d} fn)\n", .{ GOLDEN, RESET, spec_path, const_count, fn_count });
        created.* += 1;
        return;
    }

    // Generate skeleton .tri spec
    var spec_content: [4096]u8 = undefined;
    const spec = std.fmt.bufPrint(&spec_content,
        \\# ============================================================================
        \\# {s} - Auto-generated skeleton spec
        \\# Created by: tri strict fix
        \\# Golden Identity: phi^2 + 1/phi^2 = 3 = TRINITY
        \\# ============================================================================
        \\
        \\name: {s}
        \\version: "1.0.0"
        \\language: {s}
        \\module: {s}
        \\
        \\description: |
        \\  Auto-generated skeleton from {s}.
        \\  Contains {d} constants and {d} public functions.
        \\  REVIEW: Add proper types/behaviors for production use.
        \\
        \\constants:
        \\  PLACEHOLDER: 0
        \\
        \\types:
        \\  Config:
        \\    fields:
        \\      enabled: Bool
        \\
        \\behaviors:
        \\  - name: init
        \\    given: Module is loaded
        \\    when: Initialization requested
        \\    then: Returns configured instance
    , .{ stem, stem, lang, stem, full_path, const_count, fn_count }) catch {
        std.debug.print("  {s}[ERR]{s} Spec too large: {s}\n", .{ RED, RESET, spec_path });
        errors.* += 1;
        return;
    };

    // Ensure specs/tri/ directory exists
    std.fs.cwd().makePath("specs/tri") catch |err| {
        std.log.warn("tri_strict: failed to create specs/tri dir: {}", .{err});
    };

    // Write spec file
    const file = std.fs.cwd().createFile(spec_path, .{}) catch {
        std.debug.print("  {s}[ERR]{s} Cannot create: {s}\n", .{ RED, RESET, spec_path });
        errors.* += 1;
        return;
    };
    defer file.close();

    file.writeAll(spec) catch {
        std.debug.print("  {s}[ERR]{s} Cannot write: {s}\n", .{ RED, RESET, spec_path });
        errors.* += 1;
        return;
    };

    std.debug.print("  {s}[CREATED]{s} {s} ({d} const, {d} fn)\n", .{ GREEN, RESET, spec_path, const_count, fn_count });
    created.* += 1;
}

fn checkSingleFile(path: []const u8, violations: *usize, warnings: *usize) void {
    const basename = std.fs.path.basename(path);

    // Extract stem (filename without extension)
    const stem = blk: {
        if (std.mem.endsWith(u8, basename, ".zig")) {
            break :blk basename[0 .. basename.len - 4];
        } else if (std.mem.endsWith(u8, basename, ".v")) {
            break :blk basename[0 .. basename.len - 2];
        } else {
            break :blk basename;
        }
    };

    // Look for matching .tri spec
    var spec_buf: [512]u8 = undefined;
    const spec_path = std.fmt.bufPrint(&spec_buf, "specs/tri/{s}.tri", .{stem}) catch {
        std.debug.print("  {s}[WARN]{s} {s} - path too long for spec lookup\n", .{ GOLDEN, RESET, path });
        warnings.* += 1;
        return;
    };

    const spec_exists = blk: {
        std.fs.cwd().access(spec_path, .{}) catch break :blk false;
        break :blk true;
    };

    if (!spec_exists) {
        std.debug.print("  {s}[VIOLATION]{s} {s}\n", .{ RED, RESET, path });
        std.debug.print("             No matching spec: {s}\n", .{spec_path});
        violations.* += 1;
        return;
    }

    // Spec exists - compare timestamps
    const gen_stat = std.fs.cwd().statFile(path) catch {
        std.debug.print("  {s}[WARN]{s} {s} - cannot stat\n", .{ GOLDEN, RESET, path });
        warnings.* += 1;
        return;
    };

    const spec_stat = std.fs.cwd().statFile(spec_path) catch {
        std.debug.print("  {s}[WARN]{s} {s} - cannot stat spec\n", .{ GOLDEN, RESET, spec_path });
        warnings.* += 1;
        return;
    };

    if (gen_stat.mtime > spec_stat.mtime) {
        std.debug.print("  {s}[WARN]{s} {s}\n", .{ GOLDEN, RESET, path });
        std.debug.print("           Generated file newer than spec {s}\n", .{spec_path});
        std.debug.print("           (may have been directly edited -- regenerate from spec)\n", .{});
        warnings.* += 1;
    } else {
        std.debug.print("  {s}[OK]{s} {s}\n", .{ GREEN, RESET, path });
    }
}

// ═══════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════

test "isStrictModeEnabled returns false when marker missing" {
    _ = isStrictModeEnabled();
    try std.testing.expect(isStrictModeEnabled() == false);
}

test "STRICT_MODE_MARKER constant" {
    try std.testing.expectEqualStrings(".trinity-strict-mode", STRICT_MODE_MARKER);
}

test "isProtectedPath identifies protected directories" {
    try std.testing.expect(isProtectedPath("trinity/output/main.zig") == true);
    try std.testing.expect(isProtectedPath("generated/test.v") == true);
    try std.testing.expect(isProtectedPath("./trinity/output/") == true);
    try std.testing.expect(isProtectedPath("./generated/") == true);
    try std.testing.expect(isProtectedPath("specs/tri/test.tri") == false);
    try std.testing.expect(isProtectedPath("src/vsa.zig") == false);
}

test "isProtectedPath handles relative paths" {
    try std.testing.expect(isProtectedPath("trinity/output/file.zig") == true);
    try std.testing.expect(isProtectedPath("generated/file.v") == true);
}

test "isProtectedPath handles absolute paths" {
    try std.testing.expect(isProtectedPath("/some/path/trinity/output/file.zig") == true);
    try std.testing.expect(isProtectedPath("/some/path/generated/file.v") == true);
}
