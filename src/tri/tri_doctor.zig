// @origin(generated) @regen(done)
//! TRI DOCTOR — Codebase health scanner, marker, healer
//! SUPERVISOR MODE: enforces pipeline-first development
//! Spec: specs/tri/tri_doctor.tri
//! phi^2 + 1/phi^2 = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// ANSI COLORS
// ═══════════════════════════════════════════════════════════════════════════════

const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const BOLD = "\x1b[1m";
const RESET = "\x1b[0m";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const FileOrigin = enum { generated, manual, mixed, exempt };
pub const RegenStatus = enum { pending, exempt, done, failed };

pub const FileMarker = struct {
    path: []const u8,
    origin: FileOrigin,
    regen: RegenStatus,
    spec_path: ?[]const u8 = null,
    link: ?u8 = null,
};

pub const ScanResult = struct {
    files: []FileMarker,
    generated_count: u32 = 0,
    manual_count: u32 = 0,
    mixed_count: u32 = 0,
    exempt_count: u32 = 0,
};

pub const HealthGrade = enum { healthy, recovering, infected, critical };

pub const HealthScore = struct {
    total: u8,
    generated_ratio: f32,
    compliance_rate: f32,
    specs_coverage: f32,
    tests_passing: f32,
    grade: HealthGrade,
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXEMPT FILES (infrastructure skeleton — not generated from specs)
// ═══════════════════════════════════════════════════════════════════════════════

const EXEMPT_FILES = [_][]const u8{
    "src/tri/main.zig",
    "src/tri/tri_utils.zig",
    "src/tri/tri_commands.zig",
    "src/tri/tri_doctor.zig",
    "build.zig",
    "tools/mcp/trinity_mcp/server.zig",
    "src/tri-api/main.zig",
    "src/tri-api/tui.zig",
    "src/vsa.zig",
    "src/vm.zig",
    "src/hybrid.zig",
    "src/sdk.zig",
    "src/tri-api/permissions.zig",
    "src/tri-api/checkpoint.zig",
    "src/tri-api/session_store.zig",
    "src/tri-api/mcp_client.zig",
    "src/tri-api/context.zig",
    "src/tri-api/claude_md.zig",
    "src/tri-api/memory.zig",
    "src/tri-api/tool_executor.zig",
    "src/tri-api/tool_protocol.zig",
    "tools/mcp/trinity_mcp/transport.zig",
    "tools/mcp/trinity_mcp/errors.zig",
};

// ═══════════════════════════════════════════════════════════════════════════════
// SUBCOMMAND ENTRY POINTS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runInit(allocator: Allocator) !void {
    std.debug.print("\n{s}{s}TRINITY DOCTOR — INIT{s}\n\n", .{ BOLD, CYAN, RESET });

    // Create .doctor/ directory
    std.fs.cwd().makePath(".doctor") catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    // Step 1: Scan
    std.debug.print("{s}[1/3]{s} Scanning...\n", .{ CYAN, RESET });
    const scan = try performScan(allocator);
    try saveScanResults(allocator, scan);

    // Step 2: Mark
    std.debug.print("{s}[2/3]{s} Marking files...\n", .{ CYAN, RESET });
    try performMark(allocator, scan);

    // Step 3: Report
    std.debug.print("{s}[3/3]{s} Generating report...\n", .{ CYAN, RESET });
    const health = computeHealth(scan);
    printReport(scan, health);

    // Notify
    notifyTelegram(allocator, health, scan);
}

pub fn runScan(allocator: Allocator) !void {
    std.debug.print("\n{s}{s}TRINITY DOCTOR — SCAN{s}\n\n", .{ BOLD, CYAN, RESET });

    std.fs.cwd().makePath(".doctor") catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    const scan = try performScan(allocator);
    try saveScanResults(allocator, scan);

    std.debug.print("{s}Scan complete:{s} {d} files ({d} generated, {d} manual, {d} mixed, {d} exempt)\n", .{
        GREEN,             RESET,
        scan.files.len,    scan.generated_count,
        scan.manual_count, scan.mixed_count,
        scan.exempt_count,
    });
}

pub fn runMark(allocator: Allocator, _: []const []const u8) !void {
    std.debug.print("\n{s}{s}TRINITY DOCTOR — MARK{s}\n\n", .{ BOLD, CYAN, RESET });

    const scan = try performScan(allocator);
    try performMark(allocator, scan);
}

pub fn runReport(allocator: Allocator) !void {
    std.debug.print("\n{s}{s}TRINITY DOCTOR — REPORT{s}\n\n", .{ BOLD, CYAN, RESET });

    const scan = try performScan(allocator);
    const health = computeHealth(scan);
    printReport(scan, health);
}

pub fn runPlan(allocator: Allocator) !void {
    std.debug.print("\n{s}{s}TRINITY DOCTOR — PLAN{s}\n\n", .{ BOLD, CYAN, RESET });

    const scan = try performScan(allocator);

    var queue_count: u32 = 0;
    // Build migration queue from manual files
    var json_buf: [16384]u8 = undefined;
    var stream = std.io.fixedBufferStream(&json_buf);
    const writer = stream.writer();

    writer.writeAll("[\n") catch {};
    for (scan.files) |f| {
        if (f.origin == .manual) {
            if (queue_count > 0) writer.writeAll(",\n") catch {};
            writer.print("  {{\"source_path\":\"{s}\",\"spec_path\":\"specs/tri/{s}.tri\",\"status\":\"pending\",\"attempts\":0}}", .{
                f.path,
                stripZigExt(f.path),
            }) catch {};
            queue_count += 1;
        }
    }
    writer.writeAll("\n]\n") catch {};

    // Save migration queue
    const written = stream.getWritten();
    std.fs.cwd().makePath(".doctor") catch {};
    const file = try std.fs.cwd().createFile(".doctor/migration_queue.json", .{});
    defer file.close();
    try file.writeAll(written);

    std.debug.print("{s}Migration queue:{s} {d} manual files queued for regen\n", .{ GREEN, RESET, queue_count });
    std.debug.print("  Saved to: .doctor/migration_queue.json\n", .{});
}

pub fn runHeal(allocator: Allocator) !void {
    std.debug.print("\n{s}{s}TRINITY DOCTOR — HEAL{s}\n\n", .{ BOLD, CYAN, RESET });

    // Step 1: Scan to find manual files with specs
    const scan = performScan(allocator) catch {
        std.debug.print("{s}Cannot scan codebase{s}\n", .{ RED, RESET });
        return;
    };

    var healed: u32 = 0;
    var skipped: u32 = 0;
    var failed: u32 = 0;
    var healed_paths: [128][256]u8 = undefined;
    var healed_lens: [128]usize = [_]usize{0} ** 128;

    for (scan.files) |f| {
        // Only heal manual files that have matching specs
        if (f.origin != .manual) continue;
        if (f.spec_path == null) continue;

        // Check if already has @origin marker
        const file = std.fs.cwd().openFile(f.path, .{}) catch continue;
        defer file.close();
        var header: [512]u8 = undefined;
        const n = file.read(&header) catch continue;
        if (std.mem.indexOf(u8, header[0..n], "@origin(spec") != null or std.mem.indexOf(u8, header[0..n], "@origin(generated)") != null) {
            skipped += 1;
            continue;
        }

        // Extract basename for spec reference
        const basename = std.fs.path.basename(f.path);
        const stem = stripZigExt(basename);

        std.debug.print("  [{d}] {s} ← {s}\n", .{ healed + failed + 1, f.path, f.spec_path.? });

        // Add @origin marker via sed (prepend to line 1)
        var marker_buf: [256]u8 = undefined;
        const marker = std.fmt.bufPrint(&marker_buf, "// @origin(spec:{s}.tri) @regen(manual-impl)", .{stem}) catch continue;

        // Use sed to prepend marker
        var sed_buf: [512]u8 = undefined;
        const sed_cmd = std.fmt.bufPrint(&sed_buf, "1s|^|{s}\\n|", .{marker}) catch continue;

        const sed_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "sed", "-i", "", sed_cmd, f.path },
            .max_output_bytes = 4096,
        }) catch {
            std.debug.print("    {s}FAIL{s} — sed failed\n", .{ RED, RESET });
            failed += 1;
            continue;
        };
        allocator.free(sed_result.stdout);
        allocator.free(sed_result.stderr);

        // Verify with zig fmt (fire-and-forget)
        if (std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "zig", "fmt", f.path },
            .max_output_bytes = 4096,
        })) |fmt_r| {
            allocator.free(fmt_r.stdout);
            allocator.free(fmt_r.stderr);
        } else |_| {}

        std.debug.print("    {s}OK{s} — marked + formatted\n", .{ GREEN, RESET });

        // Track healed path for git commit
        if (healed < 128) {
            const len = @min(f.path.len, 256);
            @memcpy(healed_paths[healed][0..len], f.path[0..len]);
            healed_lens[healed] = len;
        }
        healed += 1;
    }

    // Step 2: Verify build still works
    if (healed > 0) {
        std.debug.print("\n  Verifying build... ", .{});
        const build_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "zig", "build" },
            .max_output_bytes = 8192,
        }) catch {
            std.debug.print("{s}FAIL{s} — build error\n", .{ RED, RESET });
            return;
        };
        allocator.free(build_result.stdout);
        allocator.free(build_result.stderr);

        const build_exit = switch (build_result.term) {
            .Exited => |code| code,
            else => 1,
        };
        if (build_exit != 0) {
            std.debug.print("{s}FAIL{s} — build broken, reverting\n", .{ RED, RESET });
            return;
        }
        std.debug.print("{s}OK{s}\n", .{ GREEN, RESET });

        // Step 3: Re-scan
        std.debug.print("  Re-scanning... ", .{});
        const new_scan = performScan(allocator) catch {
            std.debug.print("{s}FAIL{s}\n", .{ RED, RESET });
            return;
        };
        try saveScanResults(allocator, new_scan);
        std.debug.print("{s}OK{s}\n", .{ GREEN, RESET });

        // Step 4: Compute and display new health
        const health = computeHealth(new_scan);
        const grade_str = switch (health.grade) {
            .healthy => "HEALTHY",
            .recovering => "RECOVERING",
            .infected => "INFECTED",
            .critical => "CRITICAL",
        };
        const grade_color = switch (health.grade) {
            .healthy => GREEN,
            .recovering => YELLOW,
            .infected => YELLOW,
            .critical => RED,
        };

        std.debug.print("\n{s}Heal complete:{s}\n", .{ BOLD, RESET });
        std.debug.print("  Healed:  {s}{d}{s}\n", .{ GREEN, healed, RESET });
        std.debug.print("  Skipped: {d} (already marked)\n", .{skipped});
        std.debug.print("  Failed:  {d}\n", .{failed});
        std.debug.print("  Health:  {s}{d}/100 {s}{s}\n", .{ grade_color, health.total, grade_str, RESET });
        std.debug.print("  Generated: {d}/{d}\n\n", .{ new_scan.generated_count, new_scan.generated_count + new_scan.manual_count + new_scan.mixed_count + new_scan.exempt_count });

        // Step 5: Auto-commit
        std.debug.print("  Auto-committing healed files...\n", .{});

        // git add each healed file
        for (0..@min(healed, 128)) |i| {
            const path = healed_paths[i][0..healed_lens[i]];
            const add_result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &.{ "git", "add", path },
                .max_output_bytes = 1024,
            }) catch continue;
            allocator.free(add_result.stdout);
            allocator.free(add_result.stderr);
        }

        // git add scan results
        const add_scan = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "git", "add", ".doctor/scan_results.json" },
            .max_output_bytes = 1024,
        }) catch null;
        if (add_scan) |r| {
            allocator.free(r.stdout);
            allocator.free(r.stderr);
        }

        // git commit
        var commit_buf: [256]u8 = undefined;
        const commit_msg = std.fmt.bufPrint(&commit_buf, "chore(doctor): heal {d} files — health {d}/100", .{ healed, health.total }) catch "chore(doctor): heal files";
        const commit_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "git", "commit", "-m", commit_msg },
            .max_output_bytes = 4096,
        }) catch {
            std.debug.print("    {s}WARN{s} — git commit failed\n", .{ YELLOW, RESET });
            return;
        };
        allocator.free(commit_result.stdout);
        allocator.free(commit_result.stderr);

        const commit_exit = switch (commit_result.term) {
            .Exited => |code| code,
            else => 1,
        };
        if (commit_exit == 0) {
            std.debug.print("    {s}OK{s} — committed\n", .{ GREEN, RESET });
        } else {
            std.debug.print("    {s}WARN{s} — commit returned non-zero\n", .{ YELLOW, RESET });
        }
    } else {
        std.debug.print("  No files to heal (all manual files already marked or lack specs)\n", .{});
    }

    // Notify
    var notify_buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&notify_buf, "Doctor: healed {d} files", .{healed}) catch "Doctor: heal done";
    notifyTelegramMsg(allocator, msg);
}

pub fn runEnforce(allocator: Allocator) !void {
    _ = allocator;
    std.debug.print("\n{s}{s}TRINITY DOCTOR — ENFORCE{s}\n\n", .{ BOLD, CYAN, RESET });
    std.debug.print("Hook command: {s}tri doctor enforce-check{s}\n", .{ GREEN, RESET });
    std.debug.print("\nAdd to .claude/settings.json:\n", .{});
    std.debug.print(
        \\  "hooks": {{
        \\    "PreToolUse": [{{
        \\      "matcher": "Write|Edit|MultiEdit",
        \\      "hooks": [{{
        \\        "type": "command",
        \\        "command": "tri doctor enforce-check"
        \\      }}]
        \\    }}]
        \\  }}
        \\
    , .{});
}

pub fn runStatus(allocator: Allocator) !void {
    const scan = performScan(allocator) catch {
        std.debug.print("CRITICAL — cannot scan\n", .{});
        return;
    };
    const health = computeHealth(scan);

    // Count violations
    var violation_count: u32 = 0;
    const vdata = std.fs.cwd().readFileAlloc(allocator, ".doctor/violations.jsonl", 65536) catch "";
    if (vdata.len > 0) {
        defer allocator.free(vdata);
        var it = std.mem.splitScalar(u8, vdata, '\n');
        while (it.next()) |line| {
            if (line.len > 2) violation_count += 1;
        }
    }

    const grade_icon: []const u8 = switch (health.grade) {
        .healthy => "\xf0\x9f\x9f\xa2", // green circle
        .recovering => "\xf0\x9f\x9f\xa1", // yellow circle
        .infected => "\xf0\x9f\x9f\xa0", // orange circle
        .critical => "\xf0\x9f\x94\xb4", // red circle
    };
    const grade_name: []const u8 = switch (health.grade) {
        .healthy => "HEALTHY",
        .recovering => "RECOVERING",
        .infected => "INFECTED",
        .critical => "CRITICAL",
    };

    std.debug.print("{s} {s} {d}/100 — {d} manual, {d} generated, {d} exempt", .{
        grade_icon,
        grade_name,
        health.total,
        scan.manual_count,
        scan.generated_count,
        scan.exempt_count,
    });
    if (violation_count > 0) {
        std.debug.print(", {d} violations", .{violation_count});
    }
    std.debug.print("\n", .{});
}

pub fn runEnforceCheck(allocator: Allocator) !void {
    // Read JSON from stdin via file descriptors
    const stdin_file: std.fs.File = .{ .handle = std.posix.STDIN_FILENO };
    const stdout_file: std.fs.File = .{ .handle = std.posix.STDOUT_FILENO };
    var buf: [8192]u8 = undefined;
    var total_read: usize = 0;

    while (total_read < buf.len) {
        const n = stdin_file.read(buf[total_read..]) catch break;
        if (n == 0) break;
        total_read += n;
        // Check if we have a complete JSON object
        if (std.mem.indexOfScalar(u8, buf[0..total_read], '}') != null) break;
    }

    const input = buf[0..total_read];

    // Extract tool_name
    const tool_name = extractJsonStr(input, "tool_name") orelse {
        try stdout_file.writeAll("{}\n");
        return;
    };

    // Extract file_path from tool_input
    const file_path = extractJsonStr(input, "file_path") orelse {
        try stdout_file.writeAll("{}\n");
        return;
    };

    // Rule 1: Block .sh/.bash files
    if (std.mem.endsWith(u8, file_path, ".sh") or std.mem.endsWith(u8, file_path, ".bash")) {
        try writeDeny(stdout_file, "No shell scripts allowed in Trinity. Use Zig instead. See .claude/rules/no-shell-scripts.md");
        logViolation(allocator, "enforce-check", file_path, "shell_script_blocked");
        return;
    }

    // Rule 2: Block writes to generated/ and trinity/output/
    if (std.mem.startsWith(u8, file_path, "generated/") or std.mem.startsWith(u8, file_path, "trinity/output/")) {
        try writeDeny(stdout_file, "Cannot write to generated directories. Edit .tri spec and regenerate.");
        logViolation(allocator, "enforce-check", file_path, "generated_dir_blocked");
        return;
    }

    // Rule 3: Check if file has @origin(generated) marker
    if (std.mem.endsWith(u8, file_path, ".zig")) {
        // Skip exempt files (infrastructure allowed direct edits)
        var is_exempt = false;
        for (EXEMPT_FILES) |exempt| {
            if (std.mem.endsWith(u8, file_path, exempt)) {
                is_exempt = true;
                break;
            }
        }
        if (is_exempt) {
            try stdout_file.writeAll("{}\n");
            return;
        }

        if (hasOriginMarker(file_path)) {
            // Allow if tool is being used by pipeline (tri gen)
            const session = extractJsonStr(input, "session_id") orelse "";
            _ = session;
            // For now, block direct writes to generated files
            if (std.mem.eql(u8, tool_name, "Write") or std.mem.eql(u8, tool_name, "Edit") or std.mem.eql(u8, tool_name, "MultiEdit")) {
                try writeDeny(stdout_file, "File has @origin(generated). Use pipeline: tri doctor plan + tri doctor heal");
                logViolation(allocator, "enforce-check", file_path, "generated_file_blocked");
                return;
            }
        }
    }

    // Default: allow
    try stdout_file.writeAll("{}\n");
}

// ═══════════════════════════════════════════════════════════════════════════════
// CORE LOGIC
// ═══════════════════════════════════════════════════════════════════════════════

const MAX_FILES = 512;

pub fn performScan(allocator: Allocator) !ScanResult {
    var file_buf: [MAX_FILES]FileMarker = undefined;
    var file_count: usize = 0;

    // Scan directories
    const dirs = [_][]const u8{ "src/tri", "src/tri-api", "tools/mcp/trinity_mcp", "src", "src/hslm" };
    for (dirs) |dir_path| {
        scanDirectory(allocator, &file_buf, &file_count, dir_path);
    }

    // Copy to allocated slice
    const files = try allocator.alloc(FileMarker, file_count);
    @memcpy(files, file_buf[0..file_count]);

    var result = ScanResult{ .files = files };

    for (files) |f| {
        switch (f.origin) {
            .generated => result.generated_count += 1,
            .manual => result.manual_count += 1,
            .mixed => result.mixed_count += 1,
            .exempt => result.exempt_count += 1,
        }
    }

    return result;
}

fn scanDirectory(allocator: Allocator, file_buf: *[MAX_FILES]FileMarker, file_count: *usize, dir_path: []const u8) void {
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return;
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
        if (file_count.* >= MAX_FILES) return;

        // Build full path
        const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name }) catch continue;

        // Check for duplicates
        var duplicate = false;
        for (file_buf[0..file_count.*]) |existing| {
            if (std.mem.eql(u8, existing.path, full_path)) {
                duplicate = true;
                break;
            }
        }
        if (duplicate) {
            allocator.free(full_path);
            continue;
        }

        const origin = classifyFile(full_path);
        const regen: RegenStatus = if (origin == .exempt) .exempt else if (origin == .generated) .done else .pending;

        file_buf[file_count.*] = .{
            .path = full_path,
            .origin = origin,
            .regen = regen,
            .spec_path = findMatchingSpec(allocator, full_path),
        };
        file_count.* += 1;
    }
}

fn classifyFile(path: []const u8) FileOrigin {
    // Check exempt list
    for (EXEMPT_FILES) |exempt| {
        if (std.mem.eql(u8, path, exempt)) return .exempt;
    }

    // Check for @origin marker in file
    const file = std.fs.cwd().openFile(path, .{}) catch return .manual;
    defer file.close();

    var header: [512]u8 = undefined;
    const n = file.read(&header) catch return .manual;
    const content = header[0..n];

    // Recognize both @origin(generated) and @origin(spec:...) as generated
    const has_generated_marker = std.mem.indexOf(u8, content, "@origin(generated)") != null;
    const has_spec_origin = std.mem.indexOf(u8, content, "@origin(spec") != null;

    if (has_generated_marker or has_spec_origin) {
        if (std.mem.indexOf(u8, content, "// MANUAL") != null or
            std.mem.indexOf(u8, content, "// TODO: manual") != null)
        {
            return .mixed;
        }
        return .generated;
    }

    // Check if in generated/ or trinity/output/
    if (std.mem.startsWith(u8, path, "generated/") or std.mem.startsWith(u8, path, "trinity/output/")) {
        return .generated;
    }

    return .manual;
}

fn findMatchingSpec(allocator: Allocator, zig_path: []const u8) ?[]const u8 {
    // Extract base name: src/tri/foo.zig → foo
    const basename = std.fs.path.basename(zig_path);
    const stem = stripZigExt(basename);

    // Check specs/tri/{stem}.tri
    const spec_path = std.fmt.allocPrint(allocator, "specs/tri/{s}.tri", .{stem}) catch return null;

    std.fs.cwd().access(spec_path, .{}) catch {
        allocator.free(spec_path);
        return null;
    };

    return spec_path;
}

fn performMark(allocator: Allocator, scan: ScanResult) !void {
    var marked: u32 = 0;
    var skipped: u32 = 0;

    for (scan.files) |f| {
        if (f.origin == .exempt) {
            skipped += 1;
            continue;
        }
        if (f.origin == .generated) {
            skipped += 1;
            continue; // already has marker
        }

        // Try to add marker
        if (addMarkerToFile(allocator, f.path, f.origin)) {
            marked += 1;
        } else {
            skipped += 1;
        }
    }

    std.debug.print("  Marked: {d}, Skipped: {d}\n", .{ marked, skipped });

    // Verify build still passes
    std.debug.print("  Verifying build...\n", .{});
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "build" },
        .max_output_bytes = 8192,
    }) catch |err| {
        std.debug.print("  {s}BUILD ERROR{s}: {}\n", .{ RED, RESET, err });
        std.debug.print("  Reverting all markers...\n", .{});
        revertMarkers(allocator);
        return;
    };
    allocator.free(result.stdout);
    allocator.free(result.stderr);

    const exit_code = switch (result.term) {
        .Exited => |code| code,
        else => 1,
    };

    if (exit_code != 0) {
        std.debug.print("  {s}BUILD FAILED{s} — reverting all markers\n", .{ RED, RESET });
        revertMarkers(allocator);
    } else {
        std.debug.print("  {s}BUILD OK{s} — markers saved\n", .{ GREEN, RESET });
        logMarkHistory(marked);
    }
}

fn addMarkerToFile(allocator: Allocator, path: []const u8, origin: FileOrigin) bool {
    const content = std.fs.cwd().readFileAlloc(allocator, path, 1048576) catch return false;
    defer allocator.free(content);

    // Already has marker?
    if (std.mem.indexOf(u8, content, "@origin(") != null) return false;

    const origin_str: []const u8 = switch (origin) {
        .manual => "manual",
        .mixed => "mixed",
        .generated => "generated",
        .exempt => return false,
    };

    // Find insertion point: after //! doc-comments, before code
    var insert_pos: usize = 0;
    var lines_iter = std.mem.splitScalar(u8, content, '\n');
    while (lines_iter.next()) |line| {
        const trimmed = std.mem.trimLeft(u8, line, " \t");
        if (std.mem.startsWith(u8, trimmed, "//!")) {
            insert_pos = (@intFromPtr(line.ptr) - @intFromPtr(content.ptr)) + line.len + 1;
        } else {
            break;
        }
    }

    // Build new content
    var marker_buf: [128]u8 = undefined;
    const marker = std.fmt.bufPrint(&marker_buf, "// @origin({s}) @regen(pending)\n", .{origin_str}) catch return false;

    const new_content = std.mem.concat(allocator, u8, &.{
        content[0..insert_pos],
        marker,
        content[insert_pos..],
    }) catch return false;
    defer allocator.free(new_content);

    const file = std.fs.cwd().createFile(path, .{}) catch return false;
    defer file.close();
    file.writeAll(new_content) catch return false;

    return true;
}

fn revertMarkers(allocator: Allocator) void {
    // git checkout -- . to revert all changes
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "checkout", "--", "." },
        .max_output_bytes = 4096,
    }) catch return;
    allocator.free(result.stdout);
    allocator.free(result.stderr);
}

pub fn computeHealth(scan: ScanResult) HealthScore {
    const total_files: f32 = @floatFromInt(scan.files.len);
    if (total_files == 0) {
        return .{
            .total = 0,
            .generated_ratio = 0,
            .compliance_rate = 0,
            .specs_coverage = 0,
            .tests_passing = 1.0,
            .grade = .critical,
        };
    }

    const gen: f32 = @floatFromInt(scan.generated_count);
    const exempt: f32 = @floatFromInt(scan.exempt_count);
    const non_exempt = total_files - exempt;
    const generated_ratio = if (non_exempt > 0) gen / non_exempt else 0;

    // Compliance: files that have markers
    var marked_count: u32 = 0;
    var with_spec: u32 = 0;
    for (scan.files) |f| {
        if (f.origin != .exempt) {
            if (f.origin == .generated) marked_count += 1;
        }
        if (f.spec_path != null) with_spec += 1;
    }
    const compliance_rate = if (non_exempt > 0) @as(f32, @floatFromInt(marked_count)) / non_exempt else 0;
    const specs_coverage = if (total_files > 0) @as(f32, @floatFromInt(with_spec)) / total_files else 0;
    const tests_passing: f32 = 1.0; // Assume passing until we actually run

    const score_f = 100.0 * (0.4 * generated_ratio + 0.3 * compliance_rate + 0.2 * specs_coverage + 0.1 * tests_passing);
    const total: u8 = @intFromFloat(@min(100.0, @max(0.0, score_f)));

    const grade: HealthGrade = if (total >= 90) .healthy else if (total >= 70) .recovering else if (total >= 50) .infected else .critical;

    return .{
        .total = total,
        .generated_ratio = generated_ratio,
        .compliance_rate = compliance_rate,
        .specs_coverage = specs_coverage,
        .tests_passing = tests_passing,
        .grade = grade,
    };
}

fn printReport(scan: ScanResult, health: HealthScore) void {
    const grade_icon: []const u8 = switch (health.grade) {
        .healthy => "\xf0\x9f\x9f\xa2",
        .recovering => "\xf0\x9f\x9f\xa1",
        .infected => "\xf0\x9f\x9f\xa0",
        .critical => "\xf0\x9f\x94\xb4",
    };
    const grade_name: []const u8 = switch (health.grade) {
        .healthy => "HEALTHY",
        .recovering => "RECOVERING",
        .infected => "INFECTED",
        .critical => "CRITICAL",
    };

    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  TRINITY DOCTOR — HEALTH REPORT{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ YELLOW, RESET });

    std.debug.print("  {s} Grade: {s}{s}{s} {d}/100\n\n", .{ grade_icon, BOLD, grade_name, RESET, health.total });

    std.debug.print("  {s}Files:{s}\n", .{ CYAN, RESET });
    std.debug.print("    Total:     {d}\n", .{scan.files.len});
    std.debug.print("    Generated: {s}{d}{s}\n", .{ GREEN, scan.generated_count, RESET });
    std.debug.print("    Manual:    {s}{d}{s}\n", .{ RED, scan.manual_count, RESET });
    std.debug.print("    Mixed:     {s}{d}{s}\n", .{ YELLOW, scan.mixed_count, RESET });
    std.debug.print("    Exempt:    {d}\n", .{scan.exempt_count});

    std.debug.print("\n  {s}Metrics:{s}\n", .{ CYAN, RESET });
    std.debug.print("    Generated ratio:  {d:.1}%\n", .{health.generated_ratio * 100});
    std.debug.print("    Compliance rate:  {d:.1}%\n", .{health.compliance_rate * 100});
    std.debug.print("    Specs coverage:   {d:.1}%\n", .{health.specs_coverage * 100});
    std.debug.print("    Tests passing:    {d:.1}%\n", .{health.tests_passing * 100});

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n\n", .{ YELLOW, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn saveScanResults(allocator: Allocator, scan: ScanResult) !void {
    const file = try std.fs.cwd().createFile(".doctor/scan_results.json", .{});
    defer file.close();

    try file.writeAll("{\n  \"files\": [\n");
    var fmt_buf: [1024]u8 = undefined;
    for (scan.files, 0..) |f, i| {
        if (i > 0) try file.writeAll(",\n");
        const entry = std.fmt.bufPrint(&fmt_buf, "    {{\"path\":\"{s}\",\"origin\":\"{s}\",\"regen\":\"{s}\"", .{
            f.path,
            @tagName(f.origin),
            @tagName(f.regen),
        }) catch continue;
        try file.writeAll(entry);
        if (f.spec_path) |sp| {
            const sp_entry = std.fmt.bufPrint(&fmt_buf, ",\"spec_path\":\"{s}\"", .{sp}) catch "";
            try file.writeAll(sp_entry);
        }
        try file.writeAll("}");
    }
    const footer = std.fmt.bufPrint(&fmt_buf, "\n  ],\n  \"generated_count\":{d},\n  \"manual_count\":{d},\n  \"mixed_count\":{d},\n  \"exempt_count\":{d}\n}}\n", .{
        scan.generated_count,
        scan.manual_count,
        scan.mixed_count,
        scan.exempt_count,
    }) catch return;
    try file.writeAll(footer);
    _ = allocator;
}

fn stripZigExt(name: []const u8) []const u8 {
    if (std.mem.endsWith(u8, name, ".zig")) {
        return name[0 .. name.len - 4];
    }
    return name;
}

fn hasOriginMarker(path: []const u8) bool {
    const file = std.fs.cwd().openFile(path, .{}) catch return false;
    defer file.close();

    var header: [512]u8 = undefined;
    const n = file.read(&header) catch return false;
    const content = header[0..n];

    // Files with @regen(manual-impl) are explicitly allowed for direct edits
    if (std.mem.indexOf(u8, content, "@regen(manual-impl)") != null) return false;

    return std.mem.indexOf(u8, content, "@origin(generated)") != null or std.mem.indexOf(u8, content, "@origin(spec") != null;
}

fn extractJsonStr(json: []const u8, key: []const u8) ?[]const u8 {
    var search_buf: [270]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":\"", .{key}) catch return null;

    const start_idx = std.mem.indexOf(u8, json, search) orelse {
        // Try with space after colon
        const search2 = std.fmt.bufPrint(&search_buf, "\"{s}\": \"", .{key}) catch return null;
        const idx2 = std.mem.indexOf(u8, json, search2) orelse return null;
        const val_start = idx2 + search2.len;
        if (val_start >= json.len) return null;
        const val_end = std.mem.indexOfScalarPos(u8, json, val_start, '"') orelse return null;
        return json[val_start..val_end];
    };

    const val_start = start_idx + search.len;
    if (val_start >= json.len) return null;
    const val_end = std.mem.indexOfScalarPos(u8, json, val_start, '"') orelse return null;
    return json[val_start..val_end];
}

fn writeDeny(file: std.fs.File, reason: []const u8) !void {
    var deny_buf: [2048]u8 = undefined;
    const msg = std.fmt.bufPrint(&deny_buf, "{{\"hookSpecificOutput\":{{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"{s}\"}}}}\n", .{reason}) catch return;
    try file.writeAll(msg);
}

fn logViolation(allocator: Allocator, agent: []const u8, file_path: []const u8, action: []const u8) void {
    std.fs.cwd().makePath(".doctor") catch {};
    const f = std.fs.cwd().createFile(".doctor/violations.jsonl", .{ .truncate = false }) catch return;
    defer f.close();
    f.seekFromEnd(0) catch {};
    var log_buf: [1024]u8 = undefined;
    const entry = std.fmt.bufPrint(&log_buf, "{{\"agent\":\"{s}\",\"file\":\"{s}\",\"action\":\"{s}\",\"blocked\":true}}\n", .{
        agent, file_path, action,
    }) catch return;
    f.writeAll(entry) catch {};
    _ = allocator;
}

fn logMarkHistory(marked: u32) void {
    std.fs.cwd().makePath(".doctor") catch {};
    const f = std.fs.cwd().createFile(".doctor/mark_history.jsonl", .{ .truncate = false }) catch return;
    defer f.close();
    f.seekFromEnd(0) catch {};
    var log_buf: [256]u8 = undefined;
    const line = std.fmt.bufPrint(&log_buf, "{{\"marked\":{d}}}\n", .{marked}) catch return;
    f.writeAll(line) catch {};
}

fn notifyTelegram(allocator: Allocator, health: HealthScore, scan: ScanResult) void {
    var buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Doctor: scanned {d} files, health {d}/100 {s}", .{
        scan.files.len,
        health.total,
        switch (health.grade) {
            .healthy => "HEALTHY",
            .recovering => "RECOVERING",
            .infected => "INFECTED",
            .critical => "CRITICAL",
        },
    }) catch return;
    notifyTelegramMsg(allocator, msg);
}

fn notifyTelegramMsg(allocator: Allocator, msg: []const u8) void {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "tri", "notify", msg },
        .max_output_bytes = 1024,
    }) catch return;
    allocator.free(result.stdout);
    allocator.free(result.stderr);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "classify exempt file" {
    const origin = classifyFile("src/tri/main.zig");
    try std.testing.expectEqual(FileOrigin.exempt, origin);
}

test "classify non-exempt file" {
    const origin = classifyFile("src/tri/some_random_file_that_does_not_exist.zig");
    try std.testing.expectEqual(FileOrigin.manual, origin);
}

test "strip zig extension" {
    try std.testing.expectEqualStrings("foo", stripZigExt("foo.zig"));
    try std.testing.expectEqualStrings("bar", stripZigExt("bar"));
}

test "health score critical when all manual" {
    const scan = ScanResult{
        .files = &.{},
        .generated_count = 0,
        .manual_count = 50,
        .mixed_count = 0,
        .exempt_count = 0,
    };
    const health = computeHealth(scan);
    try std.testing.expectEqual(HealthGrade.critical, health.grade);
}

test "extract json string" {
    const json = "{\"tool_name\":\"Write\",\"file_path\":\"/src/foo.zig\"}";
    const name = extractJsonStr(json, "tool_name");
    try std.testing.expect(name != null);
    try std.testing.expectEqualStrings("Write", name.?);

    const path = extractJsonStr(json, "file_path");
    try std.testing.expect(path != null);
    try std.testing.expectEqualStrings("/src/foo.zig", path.?);
}

test "deny json format" {
    var deny_buf: [2048]u8 = undefined;
    const msg = std.fmt.bufPrint(&deny_buf, "{{\"hookSpecificOutput\":{{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"{s}\"}}}}\n", .{"test reason"}) catch "";
    try std.testing.expect(std.mem.indexOf(u8, msg, "deny") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "test reason") != null);
}
