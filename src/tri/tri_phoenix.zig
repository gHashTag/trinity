// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI PHOENIX — Self-Regenerating Cell System (Bone Marrow)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands: tri phoenix scan | regen <cell_id> | regen --all | lineage <cell_id> | biopsy <cell_id>
//
// Biology model:
//   cell.tri  = cell membrane (manifest)
//   dna.tri   = DNA (regeneration contract inside [dna]+[contract] sections)
//   gen/      = phenotype (generated code — only Phoenix writes here)
//   genome.log = mutation history
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const cell_parser = @import("ribosome.zig");
const colors = @import("tri_colors.zig");

const Allocator = std.mem.Allocator;

const CYAN = colors.CYAN;
const RESET = colors.RESET;
const GREEN = colors.GREEN;
const YELLOW = colors.YELLOW;
const RED = colors.RED;
const GOLDEN = colors.GOLDEN;
const GRAY = colors.GRAY;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const PhoenixCell = struct {
    manifest: cell_parser.CellManifest,
    cell_dir: []const u8,
    has_dna: bool,
    has_gen: bool,
};

pub const RegenerationStatus = enum {
    ok,
    failed,
    skipped,
    no_dna,
};

pub const RegenerationEvent = struct {
    cell_id: []const u8,
    timestamp: i64,
    status: RegenerationStatus,
    files_generated: u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runPhoenixCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        printHelp();
        return;
    }

    const cmd = args[0];
    const rest = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, cmd, "scan")) {
        try cmdScan(allocator);
    } else if (std.mem.eql(u8, cmd, "regen")) {
        if (rest.len > 0 and std.mem.eql(u8, rest[0], "--all")) {
            try cmdRegenAll(allocator);
        } else if (rest.len > 0) {
            try cmdRegen(allocator, rest[0]);
        } else {
            std.debug.print("{s}Usage:{s} tri phoenix regen <cell_id> | --all\n", .{ YELLOW, RESET });
        }
    } else if (std.mem.eql(u8, cmd, "lineage")) {
        if (rest.len > 0) {
            try cmdLineage(allocator, rest[0]);
        } else {
            std.debug.print("{s}Usage:{s} tri phoenix lineage <cell_id>\n", .{ YELLOW, RESET });
        }
    } else if (std.mem.eql(u8, cmd, "biopsy")) {
        if (rest.len > 0) {
            try cmdBiopsy(allocator, rest[0]);
        } else {
            std.debug.print("{s}Usage:{s} tri phoenix biopsy <cell_id>\n", .{ YELLOW, RESET });
        }
    } else if (std.mem.eql(u8, cmd, "immune")) {
        try cmdImmune(allocator);
    } else {
        // Delegate to phoenix_core for start/status/stop/once/fpga
        const phoenix_core = @import("phoenix_core.zig");
        try phoenix_core.runPhoenixCoreCLI(allocator, args);
    }
}

fn printHelp() void {
    std.debug.print(
        \\
        \\PHOENIX — Self-Regenerating Cell System
        \\══════════════════════════════════════════
        \\
        \\Biology Commands:
        \\  scan                 Scan organism: fill rate, cells without DNA
        \\  regen <cell_id>      Regenerate one cell from DNA -> gen/
        \\  regen --all          DAG-ordered tissue regeneration
        \\  lineage <cell_id>    Show genome.log mutation history
        \\  biopsy <cell_id>     Diff DNA contract vs current gen/
        \\
        \\Immune System:
        \\  immune               Show weak cells + suggested regen order
        \\
        \\Daemon Commands:
        \\  start                Start PhoenixCore daemon
        \\  status               Show organism status
        \\  stop                 Stop daemon
        \\  once                 Run single cycle and exit
        \\
        \\phi^2 + 1/phi^2 = 3 | TRINITY
        \\
    , .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN — enumerate organism, count DNA coverage
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdScan(allocator: Allocator) !void {
    const cells = try cell_parser.discoverAll(allocator);
    defer allocator.free(cells);

    var total: u32 = 0;
    var with_dna: u32 = 0;
    var regenerable: u32 = 0;

    std.debug.print("\n{s}PHOENIX SCAN — Organism Status{s}\n", .{ GOLDEN, RESET });
    std.debug.print("═══════════════════════════════════════════\n\n", .{});

    for (cells) |cell| {
        total += 1;
        const m = cell.manifest;
        const has_dna = m.hasDNA();
        if (has_dna) {
            with_dna += 1;
            if (m.dna_regenerable) regenerable += 1;
        }

        const dna_icon: []const u8 = if (has_dna) GREEN ++ "DNA" ++ RESET else GRAY ++ "---" ++ RESET;
        const regen_icon: []const u8 = if (m.dna_regenerable) GREEN ++ "REGEN" ++ RESET else GRAY ++ "-----" ++ RESET;

        std.debug.print("  [{s}] [{s}] {s}{s}{s} ({s})\n", .{
            dna_icon,
            regen_icon,
            CYAN,
            m.id,
            RESET,
            cell.dir_path,
        });
    }

    const fill_pct: u32 = if (total > 0) (with_dna * 100) / total else 0;
    const fill_color = if (fill_pct >= 80) GREEN else if (fill_pct >= 30) YELLOW else RED;

    std.debug.print("\n{s}Summary:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Total cells:      {d}\n", .{total});
    std.debug.print("  With DNA:         {s}{d}{s}\n", .{ fill_color, with_dna, RESET });
    std.debug.print("  Regenerable:      {d}\n", .{regenerable});
    std.debug.print("  Fill rate:        {s}{d}%{s} ({d}/{d})\n", .{
        fill_color, fill_pct, RESET, with_dna, total,
    });
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// REGEN — regenerate a single cell from its DNA
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdRegen(allocator: Allocator, cell_id: []const u8) !void {
    const cells = try cell_parser.discoverAll(allocator);
    defer allocator.free(cells);

    for (cells) |cell| {
        if (!std.mem.eql(u8, cell.manifest.id, cell_id)) continue;

        if (!cell.manifest.hasDNA()) {
            std.debug.print("{s}ERROR{s}: Cell {s}{s}{s} has no DNA (no [dna] section in cell.tri)\n", .{
                RED, RESET, CYAN, cell_id, RESET,
            });
            return;
        }

        if (!cell.manifest.dna_regenerable) {
            std.debug.print("{s}SKIP{s}: Cell {s}{s}{s} is not marked as regenerable\n", .{
                YELLOW, RESET, CYAN, cell_id, RESET,
            });
            return;
        }

        std.debug.print("\n{s}PHOENIX REGEN{s} — {s}{s}{s}\n", .{ GOLDEN, RESET, CYAN, cell_id, RESET });
        std.debug.print("  Source: {s}\n", .{cell.manifest.dna_source});
        std.debug.print("  Output: {s}\n", .{cell.manifest.dna_output});

        // Ensure gen/ directory exists
        const gen_dir = std.fmt.allocPrint(allocator, "{s}/gen", .{cell.dir_path}) catch return;
        defer allocator.free(gen_dir);
        std.fs.cwd().makePath(gen_dir) catch |err| {
            std.debug.print("{s}ERROR{s}: Cannot create gen/ directory: {}\n", .{ RED, RESET, err });
            return;
        };

        // Check if source spec exists
        if (std.fs.cwd().access(cell.manifest.dna_source, .{})) |_| {
            std.debug.print("  Spec:   {s}EXISTS{s}\n", .{ GREEN, RESET });

            // Run vibee gen to regenerate
            var child = std.process.Child.init(&.{
                "zig", "build", "vibee", "--", "gen", cell.manifest.dna_source,
            }, allocator);
            child.stdout_behavior = .Pipe;
            child.stderr_behavior = .Pipe;

            child.spawn() catch |err| {
                std.debug.print("  Regen:  {s}FAILED{s} (spawn: {})\n", .{ RED, RESET, err });
                try appendGenomeLog(allocator, cell.dir_path, cell_id, .failed);
                return;
            };
            const term = child.wait() catch |err| {
                std.debug.print("  Regen:  {s}FAILED{s} (wait: {})\n", .{ RED, RESET, err });
                try appendGenomeLog(allocator, cell.dir_path, cell_id, .failed);
                return;
            };

            if (term.Exited == 0) {
                std.debug.print("  Regen:  {s}OK{s}\n", .{ GREEN, RESET });
                try appendGenomeLog(allocator, cell.dir_path, cell_id, .ok);
            } else {
                std.debug.print("  Regen:  {s}FAILED{s} (exit={d})\n", .{ RED, RESET, term.Exited });
                try appendGenomeLog(allocator, cell.dir_path, cell_id, .failed);
            }
        } else |_| {
            std.debug.print("  Spec:   {s}MISSING{s} ({s})\n", .{ RED, RESET, cell.manifest.dna_source });
            std.debug.print("  Regen:  {s}SKIPPED{s} (no source spec)\n", .{ YELLOW, RESET });
            try appendGenomeLog(allocator, cell.dir_path, cell_id, .skipped);
        }

        std.debug.print("\n", .{});
        return;
    }

    std.debug.print("{s}ERROR{s}: Cell '{s}' not found\n", .{ RED, RESET, cell_id });
}

// ═══════════════════════════════════════════════════════════════════════════════
// REGEN ALL — DAG-ordered tissue regeneration
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdRegenAll(allocator: Allocator) !void {
    const cells = try cell_parser.discoverAll(allocator);
    defer allocator.free(cells);

    var regen_count: u32 = 0;
    var skip_count: u32 = 0;

    std.debug.print("\n{s}PHOENIX REGEN --all{s}\n", .{ GOLDEN, RESET });
    std.debug.print("═══════════════════════════════════════════\n\n", .{});

    // Simple linear pass — DAG ordering deferred to v2
    for (cells) |cell| {
        if (!cell.manifest.hasDNA() or !cell.manifest.dna_regenerable) {
            skip_count += 1;
            continue;
        }

        std.debug.print("  Regenerating {s}{s}{s}...", .{ CYAN, cell.manifest.id, RESET });

        // Ensure gen/ exists
        const gen_dir = std.fmt.allocPrint(allocator, "{s}/gen", .{cell.dir_path}) catch continue;
        defer allocator.free(gen_dir);
        std.fs.cwd().makePath(gen_dir) catch continue;

        if (std.fs.cwd().access(cell.manifest.dna_source, .{})) |_| {
            // Run vibee gen to regenerate
            var child = std.process.Child.init(&.{
                "zig", "build", "vibee", "--", "gen", cell.manifest.dna_source,
            }, allocator);
            child.stdout_behavior = .Pipe;
            child.stderr_behavior = .Pipe;

            child.spawn() catch |err| {
                std.debug.print(" {s}FAILED{s} (spawn: {})\n", .{ RED, RESET, err });
                try appendGenomeLog(allocator, cell.dir_path, cell.manifest.id, .failed);
                continue;
            };
            const term = child.wait() catch |err| {
                std.debug.print(" {s}FAILED{s} (wait: {})\n", .{ RED, RESET, err });
                try appendGenomeLog(allocator, cell.dir_path, cell.manifest.id, .failed);
                continue;
            };

            if (term.Exited == 0) {
                std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });
                try appendGenomeLog(allocator, cell.dir_path, cell.manifest.id, .ok);
                regen_count += 1;
            } else {
                std.debug.print(" {s}FAILED{s} (exit={d})\n", .{ RED, RESET, term.Exited });
                try appendGenomeLog(allocator, cell.dir_path, cell.manifest.id, .failed);
            }
        } else |_| {
            std.debug.print(" {s}SKIP{s} (no spec)\n", .{ YELLOW, RESET });
            skip_count += 1;
        }
    }

    std.debug.print("\n  Regenerated: {s}{d}{s} | Skipped: {d}\n\n", .{
        GREEN, regen_count, RESET, skip_count,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// LINEAGE — show genome.log mutation history
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdLineage(allocator: Allocator, cell_id: []const u8) !void {
    const cells = try cell_parser.discoverAll(allocator);
    defer allocator.free(cells);

    for (cells) |cell| {
        if (!std.mem.eql(u8, cell.manifest.id, cell_id)) continue;

        const log_path = std.fmt.allocPrint(allocator, "{s}/genome.log", .{cell.dir_path}) catch return;
        defer allocator.free(log_path);

        std.debug.print("\n{s}GENOME LINEAGE{s} — {s}{s}{s}\n", .{ GOLDEN, RESET, CYAN, cell_id, RESET });
        std.debug.print("═══════════════════════════════════════════\n\n", .{});

        const content = std.fs.cwd().readFileAlloc(allocator, log_path, 1024 * 64) catch {
            std.debug.print("  {s}No genome.log found{s} — cell has no mutation history yet.\n\n", .{ GRAY, RESET });
            return;
        };
        defer allocator.free(content);

        if (content.len == 0) {
            std.debug.print("  {s}Empty genome.log{s}\n\n", .{ GRAY, RESET });
            return;
        }

        std.debug.print("{s}\n", .{content});
        return;
    }

    std.debug.print("{s}ERROR{s}: Cell '{s}' not found\n", .{ RED, RESET, cell_id });
}

// ═══════════════════════════════════════════════════════════════════════════════
// BIOPSY — diff DNA contract vs current gen/ output
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdBiopsy(allocator: Allocator, cell_id: []const u8) !void {
    const cells = try cell_parser.discoverAll(allocator);
    defer allocator.free(cells);

    for (cells) |cell| {
        if (!std.mem.eql(u8, cell.manifest.id, cell_id)) continue;

        std.debug.print("\n{s}BIOPSY{s} — {s}{s}{s}\n", .{ GOLDEN, RESET, CYAN, cell_id, RESET });
        std.debug.print("═══════════════════════════════════════════\n\n", .{});

        if (!cell.manifest.hasDNA()) {
            std.debug.print("  {s}No DNA{s} — cell has no [dna] section\n\n", .{ RED, RESET });
            return;
        }

        std.debug.print("  DNA Source:    {s}\n", .{cell.manifest.dna_source});
        std.debug.print("  DNA Output:    {s}\n", .{cell.manifest.dna_output});
        std.debug.print("  Regenerable:   {s}\n", .{if (cell.manifest.dna_regenerable) GREEN ++ "yes" ++ RESET else RED ++ "no" ++ RESET});

        // Check source spec
        const source_exists = if (std.fs.cwd().access(cell.manifest.dna_source, .{})) |_| true else |_| false;
        std.debug.print("  Source exists:  {s}\n", .{if (source_exists) GREEN ++ "yes" ++ RESET else RED ++ "MISSING" ++ RESET});

        // Check output
        const output_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ cell.dir_path, cell.manifest.dna_output }) catch return;
        defer allocator.free(output_path);
        const output_exists = if (std.fs.cwd().access(output_path, .{})) |_| true else |_| false;
        std.debug.print("  Output exists:  {s}\n", .{if (output_exists) GREEN ++ "yes" ++ RESET else YELLOW ++ "not yet generated" ++ RESET});

        // Show contract
        if (cell.manifest.dna_contract_raw.len > 0) {
            std.debug.print("\n  {s}Contract:{s}\n", .{ GOLDEN, RESET });
            var lines = std.mem.splitScalar(u8, cell.manifest.dna_contract_raw, '\n');
            while (lines.next()) |line| {
                const trimmed = std.mem.trim(u8, line, &[_]u8{ ' ', '\t', '\r' });
                if (trimmed.len > 0) {
                    std.debug.print("    {s}\n", .{trimmed});
                }
            }
        }

        std.debug.print("\n", .{});
        return;
    }

    std.debug.print("{s}ERROR{s}: Cell '{s}' not found\n", .{ RED, RESET, cell_id });
}

// ═══════════════════════════════════════════════════════════════════════════════
// GENOME LOG — append mutation history
// ═══════════════════════════════════════════════════════════════════════════════

fn appendGenomeLog(allocator: Allocator, cell_dir: []const u8, cell_id: []const u8, status: RegenerationStatus) !void {
    const log_path = try std.fmt.allocPrint(allocator, "{s}/genome.log", .{cell_dir});
    defer allocator.free(log_path);

    const cwd = std.fs.cwd();
    const file = cwd.createFile(log_path, .{ .truncate = false }) catch |err| {
        std.debug.print("  (genome.log write failed: {})\n", .{err});
        return;
    };
    defer file.close();

    // Seek to end for append
    file.seekFromEnd(0) catch {};

    const ts = std.time.timestamp();
    const status_str: []const u8 = switch (status) {
        .ok => "OK",
        .failed => "FAILED",
        .skipped => "SKIPPED",
        .no_dna => "NO_DNA",
    };

    const entry = try std.fmt.allocPrint(allocator, "[{d}] {s} status={s}\n", .{ ts, cell_id, status_str });
    defer allocator.free(entry);

    _ = file.write(entry) catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// IMMUNE — scan weak cells, suggest regen order
// ═══════════════════════════════════════════════════════════════════════════════

const WeakCell = struct {
    id: []const u8,
    dir_path: []const u8,
    has_dna: bool,
    regenerable: bool,
    health: u8,
    dep_count: u32,
};

fn cmdImmune(allocator: Allocator) !void {
    const cells = try cell_parser.discoverAll(allocator);
    defer allocator.free(cells);

    var weak_cells = std.array_list.Managed(WeakCell).init(allocator);
    defer weak_cells.deinit();

    // Collect weak cells (health < 80 based on DNA + basic heuristics)
    for (cells) |cell| {
        const m = cell.manifest;
        var health: u8 = 50; // base

        // DNA bonus
        if (m.hasDNA()) health += 10;
        if (m.dna_regenerable) health += 5;

        // Owner/tests/capabilities bonuses
        if (m.owner.len > 0) health += 15;
        if (m.tests > 0) health += 10;
        if (m.capabilities.len > 2) health += 5;
        if (m.contributes_commands.len > 2 or m.contributes_tri_subcommands.len > 2) health += 5;

        // Count how many other cells depend on this one
        var dep_count: u32 = 0;
        for (cells) |other| {
            if (std.mem.eql(u8, other.manifest.id, m.id)) continue;
            if (other.manifest.dependencies_raw.len == 0) continue;
            if (std.mem.indexOf(u8, other.manifest.dependencies_raw, m.id) != null) {
                dep_count += 1;
            }
        }

        if (health < 80) {
            try weak_cells.append(.{
                .id = m.id,
                .dir_path = cell.dir_path,
                .has_dna = m.hasDNA(),
                .regenerable = m.dna_regenerable,
                .health = health,
                .dep_count = dep_count,
            });
        }
    }

    // Sort: core deps first (more dependents = higher priority), then lowest health
    std.mem.sort(WeakCell, weak_cells.items, {}, struct {
        fn lessThan(_: void, a: WeakCell, b: WeakCell) bool {
            if (a.dep_count != b.dep_count) return a.dep_count > b.dep_count;
            return a.health < b.health;
        }
    }.lessThan);

    // Display
    std.debug.print("\n{s}PHOENIX IMMUNE SYSTEM — Weak Cell Report{s}\n", .{ GOLDEN, RESET });
    std.debug.print("═══════════════════════════════════════════\n\n", .{});

    if (weak_cells.items.len == 0) {
        std.debug.print("  {s}All cells healthy (health >= 80){s}\n\n", .{ GREEN, RESET });
        return;
    }

    std.debug.print("  {s}Suggested regen order (core deps first, lowest health first):{s}\n\n", .{ CYAN, RESET });

    for (weak_cells.items, 0..) |wc, idx| {
        const health_color = if (wc.health >= 60) YELLOW else RED;
        const dna_str: []const u8 = if (wc.has_dna) GREEN ++ "DNA" ++ RESET else GRAY ++ "---" ++ RESET;
        const regen_str: []const u8 = if (wc.regenerable) GREEN ++ "REGEN" ++ RESET else GRAY ++ "-----" ++ RESET;

        std.debug.print("  {d:>2}. [{s}] [{s}] {s}{s}{s} health={s}{d}{s} deps={d}\n", .{
            idx + 1,
            dna_str,
            regen_str,
            CYAN,
            wc.id,
            RESET,
            health_color,
            wc.health,
            RESET,
            wc.dep_count,
        });
    }

    // Summary
    var regen_ready: u32 = 0;
    for (weak_cells.items) |wc| {
        if (wc.regenerable) regen_ready += 1;
    }

    std.debug.print("\n{s}Summary:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Weak cells:      {s}{d}{s}\n", .{ RED, @as(u32, @intCast(weak_cells.items.len)), RESET });
    std.debug.print("  Regen-ready:     {s}{d}{s}\n", .{ GREEN, regen_ready, RESET });
    std.debug.print("  Total cells:     {d}\n", .{cells.len});
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parse cell.tri with DNA section" {
    const content =
        \\[cell]
        \\id = "trinity.b2t"
        \\name = "B2T"
        \\path = "src/b2t"
        \\
        \\[dna]
        \\cell_id = "trinity.b2t"
        \\source = "specs/b2t/core.tri"
        \\output = "gen/protein.zig"
        \\regenerable = true
        \\
        \\[contract]
        \\inputs = ["binary_data: []u8"]
        \\outputs = ["ternary_data: []Trit"]
    ;

    const m = cell_parser.parse(content);
    try std.testing.expectEqualStrings("trinity.b2t", m.id);
    try std.testing.expectEqualStrings("trinity.b2t", m.dna_cell_id);
    try std.testing.expectEqualStrings("specs/b2t/core.tri", m.dna_source);
    try std.testing.expectEqualStrings("gen/protein.zig", m.dna_output);
    try std.testing.expect(m.dna_regenerable);
    try std.testing.expect(m.hasDNA());
}

test "cell without DNA has hasDNA false" {
    const content =
        \\[cell]
        \\id = "trinity.core"
        \\name = "Core"
        \\path = "src/core"
    ;

    const m = cell_parser.parse(content);
    try std.testing.expect(!m.hasDNA());
    try std.testing.expectEqualStrings("", m.dna_source);
}
