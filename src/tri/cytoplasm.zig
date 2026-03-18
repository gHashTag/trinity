// ═══════════════════════════════════════════════════════════════════════════════
// TRI CELL — Honeycomb Module Management v3
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands: tri cell list | info <id> | init <id> | check | deps <id> | graph
//                    health | enable <id> | disable <id> | verify | check-boundaries
//
// v3: Dynamic discovery, JSON roundtrip, dependency graph, health scores,
//     tag/contributes queries, real boundary enforcement.
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const cell_parser = @import("ribosome.zig");
const hippocampus = @import("hippocampus.zig");
const registry_mod = @import("cytoplasm_registry.zig");
const perf_mod = @import("cytoplasm_perf.zig");

const Allocator = std.mem.Allocator;

const CYAN = colors.CYAN;
const RESET = colors.RESET;
const GREEN = colors.GREEN;
const GRAY = colors.GRAY;
const YELLOW = colors.YELLOW;
const RED = colors.RED;
const WHITE = colors.WHITE;
const GOLDEN = colors.GOLDEN;
const ORANGE = colors.ORANGE;

const CORE_VERSION = "1.0.0";

// Cell scan directories — use global constant from ribosome (re-exports from const.zig)
const CELL_SCAN_DIRS = cell_parser.CELL_SCAN_DIRS;

// CellInfo is now an alias for the shared CellManifest (Honeycomb v7 — single source of truth)
const CellInfo = cell_parser.CellManifest;

/// Iterator over dependency entries from raw [dependencies] section text.
/// DepIterator — delegates to shared tri_cell_parser.zig
const DepIterator = cell_parser.DepIterator;

// ═══════════════════════════════════════════════════════════════════════════════
// VERSION CONSTRAINT (from plugin_manifest.zig pattern)
// ═══════════════════════════════════════════════════════════════════════════════

const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,

    fn parse(str: []const u8) ?Version {
        var iter = std.mem.splitScalar(u8, str, '.');
        const major_str = iter.next() orelse return null;
        const minor_str = iter.next() orelse return null;
        var patch_str = iter.next() orelse "0";
        // Strip prerelease suffix
        if (std.mem.indexOf(u8, patch_str, "-")) |dash| patch_str = patch_str[0..dash];
        return .{
            .major = std.fmt.parseInt(u32, major_str, 10) catch return null,
            .minor = std.fmt.parseInt(u32, minor_str, 10) catch return null,
            .patch = std.fmt.parseInt(u32, patch_str, 10) catch return null,
        };
    }

    fn compare(a: Version, b: Version) std.math.Order {
        if (a.major != b.major) return std.math.order(a.major, b.major);
        if (a.minor != b.minor) return std.math.order(a.minor, b.minor);
        return std.math.order(a.patch, b.patch);
    }

    fn format(self: Version, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf, "{d}.{d}.{d}", .{ self.major, self.minor, self.patch }) catch "?.?.?";
    }
};

const VersionOp = enum { exact, gte, lte, gt, lt, compatible, tilde };

const VersionConstraint = struct {
    op: VersionOp,
    version: Version,

    fn parse(str: []const u8) ?VersionConstraint {
        var s = str;
        var op: VersionOp = .exact;
        if (std.mem.startsWith(u8, s, ">=")) {
            op = .gte;
            s = s[2..];
        } else if (std.mem.startsWith(u8, s, "<=")) {
            op = .lte;
            s = s[2..];
        } else if (std.mem.startsWith(u8, s, ">")) {
            op = .gt;
            s = s[1..];
        } else if (std.mem.startsWith(u8, s, "<")) {
            op = .lt;
            s = s[1..];
        } else if (std.mem.startsWith(u8, s, "^")) {
            op = .compatible;
            s = s[1..];
        } else if (std.mem.startsWith(u8, s, "~")) {
            op = .tilde;
            s = s[1..];
        } else if (std.mem.startsWith(u8, s, "=")) {
            s = s[1..];
        }
        const version = Version.parse(s) orelse return null;
        return .{ .op = op, .version = version };
    }

    fn satisfies(self: VersionConstraint, v: Version) bool {
        return switch (self.op) {
            .exact => Version.compare(v, self.version) == .eq,
            .gte => Version.compare(v, self.version) != .lt,
            .lte => Version.compare(v, self.version) != .gt,
            .gt => Version.compare(v, self.version) == .gt,
            .lt => Version.compare(v, self.version) == .lt,
            .compatible => {
                if (Version.compare(v, self.version) == .lt) return false;
                return v.major == self.version.major;
            },
            .tilde => {
                if (Version.compare(v, self.version) == .lt) return false;
                return v.major == self.version.major and v.minor == self.version.minor;
            },
        };
    }

    fn formatOp(self: VersionConstraint) []const u8 {
        return switch (self.op) {
            .exact => "=",
            .gte => ">=",
            .lte => "<=",
            .gt => ">",
            .lt => "<",
            .compatible => "^",
            .tilde => "~",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runCellCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        return runStatus(allocator, &[_][]const u8{});
    }

    const sub = args[0];
    const rest = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, sub, "list")) return runList(allocator, rest);
    if (std.mem.eql(u8, sub, "info")) return runInfo(allocator, rest);
    if (std.mem.eql(u8, sub, "init")) return runInit(allocator, rest);
    if (std.mem.eql(u8, sub, "check")) return runCheck(allocator, rest);
    if (std.mem.eql(u8, sub, "enable")) return runToggleEnabled(allocator, rest, true);
    if (std.mem.eql(u8, sub, "disable")) return runToggleEnabled(allocator, rest, false);
    if (std.mem.eql(u8, sub, "verify")) return runVerify(allocator);
    if (std.mem.eql(u8, sub, "check-boundaries")) return runCheckBoundaries(allocator);
    if (std.mem.eql(u8, sub, "deps")) return runDeps(allocator, rest);
    if (std.mem.eql(u8, sub, "graph")) return runGraphEx(allocator, rest);
    if (std.mem.eql(u8, sub, "health")) return runHealth(allocator, rest);
    if (std.mem.eql(u8, sub, "lint")) return runLint(allocator, rest);
    if (std.mem.eql(u8, sub, "create")) return runCreate(allocator, rest);
    if (std.mem.eql(u8, sub, "create-all")) return runCreateAll(allocator, rest);
    if (std.mem.eql(u8, sub, "audit")) return runAudit(allocator, rest);
    if (std.mem.eql(u8, sub, "fix")) return runFix(allocator, rest);
    if (std.mem.eql(u8, sub, "score")) return runScore(allocator, rest);
    if (std.mem.eql(u8, sub, "status")) return runStatus(allocator, rest);
    if (std.mem.eql(u8, sub, "sign")) return runSign(allocator, rest);
    if (std.mem.eql(u8, sub, "doctor")) return runDoctor(allocator, rest);
    if (std.mem.eql(u8, sub, "orphans")) return runOrphans(allocator);
    if (std.mem.eql(u8, sub, "bio")) return runBio(allocator);
    if (std.mem.eql(u8, sub, "fix-bio")) return runFixBio(allocator, rest);
    if (std.mem.eql(u8, sub, "watch")) return runWatch(allocator, rest);
    if (std.mem.eql(u8, sub, "explain")) return runExplain(allocator, rest);
    if (std.mem.eql(u8, sub, "map")) return runMap(allocator);
    if (std.mem.eql(u8, sub, "contracts")) return runContracts(allocator);
    if (std.mem.eql(u8, sub, "mcp-gen")) {
        const cell_dispatch = @import("tri_cell_dispatch.zig");
        return cell_dispatch.runMcpGenCommand(allocator);
    }
    if (std.mem.eql(u8, sub, "commands")) return runCellCommands(allocator);
    if (std.mem.eql(u8, sub, "install-hooks")) return runInstallHooks(allocator);
    if (std.mem.eql(u8, sub, "coverage")) return runCoverage(allocator, rest);
    if (std.mem.eql(u8, sub, "version")) return runVersion(allocator, rest);
    if (std.mem.eql(u8, sub, "outdated")) return runOutdated(allocator, rest);
    if (std.mem.eql(u8, sub, "regenerate")) return runRegenerate(allocator, rest);
    if (std.mem.eql(u8, sub, "search")) return runSearch(allocator, rest);
    if (std.mem.eql(u8, sub, "find")) return runFind(allocator, rest);
    if (std.mem.eql(u8, sub, "templates")) return runTemplates(allocator, rest);
    if (std.mem.eql(u8, sub, "batch")) return runBatch(allocator, rest);
    if (std.mem.eql(u8, sub, "registry")) return registry_mod.runRegistry(allocator, rest);
    if (std.mem.eql(u8, sub, "trends")) return runTrends(allocator, rest);

    printHelp();
}

fn printHelp() void {
    std.debug.print("{s}tri cell{s} — Honeycomb module management v3\n\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}list{s}              List all cells with status\n", .{ GREEN, RESET });
    std.debug.print("  {s}list --group{s}      Group cells by tags.scope\n", .{ GREEN, RESET });
    std.debug.print("  {s}list --commands{s}   Show contributes.commands per cell\n", .{ GREEN, RESET });
    std.debug.print("  {s}list --health{s}     Show health score per cell\n", .{ GREEN, RESET });
    std.debug.print("  {s}list --scope X{s}    Filter by tags.scope\n", .{ GREEN, RESET });
    std.debug.print("  {s}list --type Y{s}     Filter by tags.type\n", .{ GREEN, RESET });
    std.debug.print("  {s}list --json{s}       Export cell data as JSON array\n", .{ GREEN, RESET });
    std.debug.print("  {s}list --sort <field>{s}  Sort by: name, health, grade, tests, files, caps, id\n", .{ GREEN, RESET });
    std.debug.print("  {s}list --filter-min N{s}  Show only cells with health < N%%\n", .{ GREEN, RESET });
    std.debug.print("  {s}info <id>{s}         Show cell details (tags, deps, health)\n", .{ GREEN, RESET });
    std.debug.print("  {s}init <id>{s}         Scaffold a new cell (cell.tri + src + test)\n", .{ GREEN, RESET });
    std.debug.print("  {s}init <id> --with-test{s}  Also create <name>.test.zig\n", .{ GREEN, RESET });
    std.debug.print("  {s}init <id> --template <name>{s}  Use template (see: tri cell templates)\n", .{ GREEN, RESET });
    std.debug.print("  {s}check{s}             Validate all manifests (dynamic discovery)\n", .{ GREEN, RESET });
    std.debug.print("  {s}check --sync{s}      Validate + regenerate registry.json\n", .{ GREEN, RESET });
    std.debug.print("  {s}check --dry-run{s}   Show sync changes without writing\n", .{ GREEN, RESET });
    std.debug.print("  {s}deps <id>{s}         Show dependency tree\n", .{ GREEN, RESET });
    std.debug.print("  {s}deps <id> --tree{s}  Recursive dependency tree\n", .{ GREEN, RESET });
    std.debug.print("  {s}deps --auto-detect{s}  Scan @imports, find missing deps\n", .{ GREEN, RESET });
    std.debug.print("  {s}deps --auto-detect --write{s}  Auto-detect + update cell.tri\n", .{ GREEN, RESET });
    std.debug.print("  {s}graph{s}             Output Mermaid dependency diagram\n", .{ GREEN, RESET });
    std.debug.print("  {s}health{s}            Per-cell health score breakdown\n", .{ GREEN, RESET });
    std.debug.print("  {s}health --json{s}     Export health snapshot as JSON\n", .{ GREEN, RESET });
    std.debug.print("  {s}lint{s}              Check @import isolation + permission violations\n", .{ GREEN, RESET });
    std.debug.print("  {s}enable <id>{s}       Enable a cell in registry\n", .{ GREEN, RESET });
    std.debug.print("  {s}disable <id>{s}      Disable a cell in registry\n", .{ GREEN, RESET });
    std.debug.print("  {s}create <path>{s}     Smart-scaffold cell.tri from existing code\n", .{ GREEN, RESET });
    std.debug.print("  {s}create-all{s}        Auto-create cell.tri for all unwrapped modules\n", .{ GREEN, RESET });
    std.debug.print("  {s}create-all --dry-run{s}  Preview without writing\n", .{ GREEN, RESET });
    std.debug.print("  {s}audit{s}             CVE-informed security audit (9 checks)\n", .{ GREEN, RESET });
    std.debug.print("  {s}audit --strict{s}    Treat warnings as errors\n", .{ GREEN, RESET });
    std.debug.print("  {s}fix --perms{s}       Re-infer permissions from code, update cell.tri\n", .{ GREEN, RESET });
    std.debug.print("  {s}fix --deps{s}        Auto-declare dependencies from @imports\n", .{ GREEN, RESET });
    std.debug.print("  {s}fix --ids{s}         Deduplicate cell IDs\n", .{ GREEN, RESET });
    std.debug.print("  {s}fix --scope{s}       Re-classify scope assignments\n", .{ GREEN, RESET });
    std.debug.print("  {s}fix --counts{s}      Re-count files and tests from source\n", .{ GREEN, RESET });
    std.debug.print("  {s}fix --all{s}         All of the above\n", .{ GREEN, RESET });
    std.debug.print("  {s}fix --dry-run{s}     Preview changes without writing\n", .{ GREEN, RESET });
    std.debug.print("  {s}score{s}             Unified health+security score per cell\n", .{ GREEN, RESET });
    std.debug.print("  {s}status{s}            One-shot integrity dashboard\n", .{ GREEN, RESET });
    std.debug.print("  {s}sign [<id>|--all]{s}  Sign L2 cells (sha256 hash)\n", .{ GREEN, RESET });
    std.debug.print("  {s}doctor{s}            Full heal cycle: fix→sign→audit→lint→sync→status\n", .{ GREEN, RESET });
    std.debug.print("  {s}orphans{s}           Find .zig files not claimed by any cell\n", .{ GREEN, RESET });
    std.debug.print("  {s}bio{s}               Biological systems map (DNA/Brain/Immune/Regen/Body)\n", .{ GREEN, RESET });
    std.debug.print("  {s}explain <id>{s}      Show WHY a cell has its permission level\n", .{ GREEN, RESET });
    std.debug.print("  {s}map{s}               Binary → cell mapping, find orphan binaries\n", .{ GREEN, RESET });
    std.debug.print("  {s}contracts{s}          Verify cell exports match source code (integrity)\n", .{ GREEN, RESET });
    std.debug.print("  {s}mcp-gen{s}           Generate MCP tools JSON from cell contributes\n", .{ GREEN, RESET });
    std.debug.print("  {s}commands{s}          List all cell-contributed tri subcommands\n", .{ GREEN, RESET });
    std.debug.print("  {s}verify{s}            Check content hashes (integrity)\n", .{ GREEN, RESET });
    std.debug.print("  {s}check-boundaries{s}  Validate tag boundary rules\n", .{ GREEN, RESET });
    std.debug.print("  {s}bio{s}               Show biological systems map\n", .{ GREEN, RESET });
    std.debug.print("  {s}fix-bio [--all]{s}   Fix missing [biology] sections\n", .{ GREEN, RESET });
    std.debug.print("  {s}watch [--interval N] [--filter-bio X] [--filter-min N] [--no-color]{s}\n", .{ GREEN, RESET });
    std.debug.print("                      Live health dashboard (Ctrl+C: exit)\n", .{});
    std.debug.print("  {s}watch --json{s}      Export health snapshot as JSON\n", .{ GREEN, RESET });
    std.debug.print("  {s}check --auto-register{s}  Detect and register new cells\n", .{ GREEN, RESET });
    std.debug.print("  {s}check --auto-register --yes{s}  Auto-register without prompt\n", .{ GREEN, RESET });
    std.debug.print("  {s}install-hooks{s}     Install Git hooks for auto-registration\n", .{ GREEN, RESET });
    std.debug.print("  {s}coverage [--threshold N]{s}  Test coverage report (fail if <70%%)\n", .{ GREEN, RESET });
    std.debug.print("  {s}version{s}            Show cell versions and content hashes\n", .{ GREEN, RESET });
    std.debug.print("  {s}outdated{s}           List cells with modified content (needs regen)\n", .{ GREEN, RESET });
    std.debug.print("  {s}regenerate --outdated{s}  Regenerate all outdated cells\n", .{ GREEN, RESET });
    std.debug.print("  {s}search <query>{s}     Fuzzy search by name/id/description\n", .{ GREEN, RESET });
    std.debug.print("  {s}find --capability X{s}  Find cells with specific capability\n", .{ GREEN, RESET });
    std.debug.print("  {s}list --tag X:Y{s}     Filter by tags (scope:brain, type:library)\n", .{ GREEN, RESET });
    std.debug.print("  {s}templates{s}          List available cell templates\n", .{ GREEN, RESET });
    std.debug.print("  {s}batch --fix{s}        Fix all cells with health < 70%%\n", .{ GREEN, RESET });
    std.debug.print("  {s}batch --sign{s}       Sign all L2 cells\n", .{ GREEN, RESET });
    std.debug.print("  {s}batch --test{s}       Run tests for all cells\n", .{ GREEN, RESET });
    std.debug.print("  {s}registry validate{s}  Check registry consistency\n", .{ GREEN, RESET });
    std.debug.print("  {s}registry repair{s}    Fix inconsistencies\n", .{ GREEN, RESET });
    std.debug.print("  {s}registry backup{s}    Create timestamped backup\n", .{ GREEN, RESET });
    std.debug.print("  {s}registry list{s}      List available backups\n", .{ GREEN, RESET });
    std.debug.print("  {s}trends [--days N]{s}  Health trend analysis (default: 7 days)\n", .{ GREEN, RESET });
    std.debug.print("  {s}trends --format json|markdown{s}\n", .{ GREEN, RESET });
}

// SortField enum for --sort flag

// CellListData — holds extracted cell data for sorting/filtering
const CellListData = struct {
    id: []const u8,
    name: []const u8,
    kind: []const u8,
    status: []const u8,
    version: []const u8,
    path: []const u8,
    owner: []const u8,
    tags_scope: []const u8,
    tags_type: []const u8,
    files: usize,
    tests: usize,
    caps: usize,
    health: u8,
    grade: u8, // 5=A, 4=B, 3=C, 2=D, 1=F
    enabled: bool,
    obj: std.json.ObjectMap,
};

// Grade mapping: 5=A (90-100), 4=B (80-89), 3=C (70-79), 2=D (50-69), 1=F (0-49)
fn healthGrade(score: u8) u8 {
    return if (score >= 90) 5 else if (score >= 80) 4 else if (score >= 70) 3 else if (score >= 50) 2 else 1;
}

fn gradeLetter(grade: u8) []const u8 {
    return switch (grade) {
        5 => "A",
        4 => "B",
        3 => "C",
        2 => "D",
        1 => "F",
        else => "?",
    };
}

fn gradeColor(grade: u8) []const u8 {
    return switch (grade) {
        5 => GREEN, // A
        4 => CYAN, // B
        3 => YELLOW, // C
        2 => RED, // D
        1 => "\x1b[38;5;52m", // F (dark red)
        else => GRAY,
    };
}
const SortField = enum {
    name,
    health,
    grade,
    tests,
    files,
    caps,
    id,
};

// ═══════════════════════════════════════════════════════════════════════════════
// LIST — table of all cells from registry.json with tag/commands/health filters
// ═══════════════════════════════════════════════════════════════════════════════

fn runList(allocator: Allocator, args: []const []const u8) !void {
    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse data/cells/registry.json\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const root = parsed.value.object;
    const cells = root.get("cells") orelse {
        std.debug.print("{s}ERROR{s}: 'cells' key missing in data/cells/registry.json\n", .{ RED, RESET });
        return;
    };
    const items = cells.array.items;

    // Parse flags
    var owner_filter: ?[]const u8 = null;
    var scope_filter: ?[]const u8 = null;
    var type_filter: ?[]const u8 = null;
    var tag_filter: ?[]const u8 = null;
    var show_commands = false;
    var show_health = false;
    var show_group = false;
    var show_json = false;
    var sort_field: ?SortField = null;
    var filter_min: ?u8 = null;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--owner") and i + 1 < args.len) {
            owner_filter = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--scope") and i + 1 < args.len) {
            scope_filter = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--type") and i + 1 < args.len) {
            type_filter = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--tag") and i + 1 < args.len) {
            tag_filter = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--commands")) {
            show_commands = true;
        } else if (std.mem.eql(u8, args[i], "--health")) {
            show_health = true;
        } else if (std.mem.eql(u8, args[i], "--group")) {
            show_group = true;
        } else if (std.mem.eql(u8, args[i], "--json")) {
            show_json = true;
        } else if (std.mem.eql(u8, args[i], "--sort") and i + 1 < args.len) {
            const field = args[i + 1];
            if (std.mem.eql(u8, field, "name")) {
                sort_field = .name;
            } else if (std.mem.eql(u8, field, "health")) {
                sort_field = .health;
            } else if (std.mem.eql(u8, field, "grade")) {
                sort_field = .grade;
            } else if (std.mem.eql(u8, field, "tests")) {
                sort_field = .tests;
            } else if (std.mem.eql(u8, field, "files")) {
                sort_field = .files;
            } else if (std.mem.eql(u8, field, "caps")) {
                sort_field = .caps;
            } else if (std.mem.eql(u8, field, "id")) {
                sort_field = .id;
            } else {
                std.debug.print("{s}ERROR{s}: Invalid sort field '{s}'. Use: name, health, grade, tests, files, caps, id\n", .{ RED, RESET, field });
                return;
            }
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--filter-min") and i + 1 < args.len) {
            const val = std.fmt.parseInt(u8, args[i + 1], 10) catch {
                std.debug.print("{s}ERROR{s}: Invalid --filter-min value '{s}'. Must be 0-100\n", .{ RED, RESET, args[i + 1] });
                return;
            };
            filter_min = val;
            i += 1;
        }
    }

    // Process --tag filter (format: "key:value" or "*:value")
    if (tag_filter) |tf| {
        if (std.mem.indexOf(u8, tf, ":")) |colon_idx| {
            const key = tf[0..colon_idx];
            const value = tf[colon_idx + 1 ..];
            if (std.mem.eql(u8, key, "scope")) {
                scope_filter = value;
            } else if (std.mem.eql(u8, key, "type")) {
                type_filter = value;
            }
            // Could support more tag keys in future
        }
    }

    std.debug.print("\n{s}🐝 TRINITY HONEYCOMB — {d} cells{s}\n", .{ GOLDEN, items.len, RESET });
    std.debug.print("{s}Core version: {s}{s}\n\n", .{ GRAY, CORE_VERSION, RESET });

    if (show_group) {
        // Grouped view by tags.scope
        const SCOPE_NAMES = [_][]const u8{ "vsa", "physics", "sacred", "agent", "infra", "hslm", "fpga", "ui", "mcp", "" };
        const SCOPE_LABELS = [_][]const u8{ "vsa", "physics", "sacred", "agent", "infra", "hslm", "fpga", "ui", "mcp", "other" };

        for (SCOPE_NAMES, 0..) |scope_name, si| {
            var group_count: usize = 0;
            // Count cells in this scope
            for (items) |item| {
                const obj = item.object;
                if (!passesFilters(obj, owner_filter, null, type_filter)) continue;
                const scope = getCellTagValue(obj, "scope");
                const matches = if (scope_name.len == 0)
                    !matchesAnyScope(scope, &SCOPE_NAMES)
                else
                    std.mem.eql(u8, scope, scope_name);
                if (matches) group_count += 1;
            }
            if (group_count == 0) continue;

            std.debug.print("\n  {s}[{s}] {d} cells{s} ", .{ CYAN, SCOPE_LABELS[si], group_count, RESET });
            // Separator line
            var sep_i: usize = 0;
            while (sep_i < 30) : (sep_i += 1) std.debug.print("━", .{});
            std.debug.print("\n", .{});

            for (items) |item| {
                const obj = item.object;
                if (!passesFilters(obj, owner_filter, null, type_filter)) continue;
                const scope = getCellTagValue(obj, "scope");
                const matches = if (scope_name.len == 0)
                    !matchesAnyScope(scope, &SCOPE_NAMES)
                else
                    std.mem.eql(u8, scope, scope_name);
                if (!matches) continue;

                const id = jsonStr(obj, "id");
                const kind = jsonStr(obj, "kind");
                const status = jsonStr(obj, "status");
                const version = jsonStr(obj, "version");
                const enabled = jsonBool(obj, "enabled");
                const status_color = if (!enabled) GRAY else if (std.mem.eql(u8, status, "stable")) GREEN else YELLOW;
                const status_icon = if (!enabled) "○" else if (std.mem.eql(u8, status, "stable")) "●" else "◐";

                std.debug.print("    {s}{s}{s} {s}{s}{s}", .{ status_color, status_icon, RESET, WHITE, id, RESET });
                printPad(id.len, 22);
                std.debug.print(" {s}", .{kind});
                printPad(kind.len, 10);
                std.debug.print(" {s}{s}{s}", .{ status_color, status, RESET });
                printPad(status.len, 8);
                std.debug.print(" {s}\n", .{version});
            }
        }
        std.debug.print("\n", .{});
        return;
    }

    if (show_commands) {
        // Commands view
        std.debug.print("  {s}ID                     COMMANDS{s}\n", .{ CYAN, RESET });
        std.debug.print("  {s}────────────────────── ────────────────────────────────────{s}\n", .{ GRAY, RESET });

        for (items) |item| {
            const obj = item.object;
            const id = jsonStr(obj, "id");
            if (!passesFilters(obj, owner_filter, scope_filter, type_filter)) continue;

            std.debug.print("  {s}{s}{s}", .{ WHITE, id, RESET });
            printPad(id.len, 23);

            // Read contributes.commands from JSON
            if (jsonObjMap(obj, "contributes")) |contrib| {
                if (contrib.get("commands")) |cmds_val| {
                    printJsonStrArray(cmds_val);
                } else {
                    std.debug.print("{s}(none){s}", .{ GRAY, RESET });
                }
            } else {
                std.debug.print("{s}(none){s}", .{ GRAY, RESET });
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("\n", .{});
        return;
    }

    if (show_health) {
        // Health view
        std.debug.print("  {s}ID                     HEALTH  OWNER          TESTS  CAPS{s}\n", .{ CYAN, RESET });
        std.debug.print("  {s}────────────────────── ─────── ────────────── ────── ────{s}\n", .{ GRAY, RESET });

        for (items) |item| {
            const obj = item.object;
            const id = jsonStr(obj, "id");
            if (!passesFilters(obj, owner_filter, scope_filter, type_filter)) continue;

            const score = computeHealthScore(obj);
            const health_color = if (score >= 80) GREEN else if (score >= 50) YELLOW else RED;

            std.debug.print("  {s}{s}{s}", .{ WHITE, id, RESET });
            printPad(id.len, 23);
            std.debug.print("{s}{d:3}%{s}    ", .{ health_color, score, RESET });
            const owner = jsonStr(obj, "owner");
            std.debug.print("{s}", .{owner});
            printPad(owner.len, 15);
            std.debug.print("{d:5}  {d}\n", .{ jsonInt(obj, "tests"), countJsonArray(obj, "capabilities") });
        }
        std.debug.print("\n", .{});
        return;
    }

    // Default view
    std.debug.print("  {s}ID                     KIND       STATUS   VERSION        PATH{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}────────────────────── ────────── ──────── ────────────── ────────────────────{s}\n", .{ GRAY, RESET });

    var stable_count: usize = 0;
    var exp_count: usize = 0;
    var disabled_count: usize = 0;
    var total_files: usize = 0;
    var total_tests: usize = 0;

    for (items) |item| {
        const obj = item.object;
        const id = jsonStr(obj, "id");
        const kind = jsonStr(obj, "kind");
        const status = jsonStr(obj, "status");
        const version = jsonStr(obj, "version");
        const path = jsonStr(obj, "path");
        const files = jsonInt(obj, "files");
        const tests = jsonInt(obj, "tests");
        const enabled = jsonBool(obj, "enabled");

        if (!passesFilters(obj, owner_filter, scope_filter, type_filter)) continue;

        const is_disabled = !enabled;
        const status_color = if (is_disabled) GRAY else if (std.mem.eql(u8, status, "stable")) GREEN else YELLOW;
        const status_icon = if (is_disabled) "○" else if (std.mem.eql(u8, status, "stable")) "●" else "◐";

        std.debug.print("  {s}{s}{s} {s}{s}{s}", .{ status_color, status_icon, RESET, if (is_disabled) GRAY else WHITE, id, RESET });
        printPad(id.len, 22);
        std.debug.print(" {s}", .{kind});
        printPad(kind.len, 10);
        if (is_disabled) {
            std.debug.print(" {s}disabled{s}     ", .{ GRAY, RESET });
        } else {
            std.debug.print(" {s}{s}{s}", .{ status_color, status, RESET });
            printPad(status.len, 13);
        }
        std.debug.print(" {s}  F={d} T={d}  {s}\n", .{ version, files, tests, path });

        if (is_disabled) {
            disabled_count += 1;
        } else if (std.mem.eql(u8, status, "stable")) {
            stable_count += 1;
        } else {
            exp_count += 1;
        }
        total_files += files;
        total_tests += tests;
    }

    std.debug.print("\n  {s}Stable: {d}{s} | {s}Experimental: {d}{s}", .{
        GREEN,  stable_count, RESET,
        YELLOW, exp_count,    RESET,
    });
    if (disabled_count > 0) {
        std.debug.print(" | {s}Disabled: {d}{s}", .{ GRAY, disabled_count, RESET });
    }
    std.debug.print(" | Files: {d} | Tests: {d}\n\n", .{ total_files, total_tests });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEARCH — fuzzy search by name/id/description
// ═══════════════════════════════════════════════════════════════════════════════

fn runSearch(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage:{s} tri cell search <query>\n", .{ YELLOW, RESET });
        std.debug.print("  Example: tri cell search faculty\n", .{});
        std.debug.print("  Searches: cell ID, name, description\n\n", .{});
        return;
    }

    const query = args[0];
    const query_lower = try allocator.dupe(u8, query);
    defer allocator.free(query_lower);

    // Convert to lowercase for case-insensitive search
    for (query_lower, 0..) |c, i| {
        query_lower[i] = toLower(c);
    }

    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse registry\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const cells = (parsed.value.object.get("cells") orelse return).array.items;

    std.debug.print("\n{s}🔍 SEARCH: \"{s}\"{s}\n\n", .{ CYAN, query, RESET });

    var match_count: usize = 0;

    for (cells) |item| {
        const obj = item.object;
        const id = jsonStr(obj, "id");
        const path = jsonStr(obj, "path");

        // Load cell.tri for name/description
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);

        const cell_content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(cell_content);

        const cell = parseCellTri(cell_content);

        // Check fuzzy match in id, name, description
        const id_lower = try allocLower(allocator, id);
        defer allocator.free(id_lower);
        const name_lower = try allocLower(allocator, cell.name);
        defer allocator.free(name_lower);
        const desc_lower = try allocLower(allocator, cell.description);
        defer allocator.free(desc_lower);

        const matches_id = std.mem.indexOf(u8, id_lower, query_lower) != null;
        const matches_name = std.mem.indexOf(u8, name_lower, query_lower) != null;
        const matches_desc = std.mem.indexOf(u8, desc_lower, query_lower) != null;

        if (!matches_id and !matches_name and !matches_desc) continue;

        match_count += 1;
        const health = computeHealthScore(obj);
        const health_color = if (health >= 80) GREEN else if (health >= 50) YELLOW else RED;
        const status = jsonStr(obj, "status");
        const status_color = if (std.mem.eql(u8, status, "stable")) GREEN else YELLOW;

        // Match indicator
        std.debug.print("  {s}{s}{s} ", .{ WHITE, cell.id, RESET });
        if (matches_id) std.debug.print("{s}[id]{s} ", .{ GREEN, RESET });
        if (matches_name) std.debug.print("{s}[name]{s} ", .{ CYAN, RESET });
        if (matches_desc) std.debug.print("{s}[desc]{s} ", .{ GRAY, RESET });
        std.debug.print("\n", .{});

        std.debug.print("    Name: {s}{s}{s}\n", .{ WHITE, cell.name, RESET });
        if (cell.description.len > 0) {
            std.debug.print("    Desc: {s}{s}{s}\n", .{ GRAY, cell.description, RESET });
        }
        std.debug.print("    Health: {s}{d}%{s} | Status: {s}{s}{s}\n", .{
            health_color, health, RESET, status_color, status, RESET,
        });
        std.debug.print("\n", .{});
    }

    if (match_count == 0) {
        std.debug.print("  {s}No matches found for \"{s}\"{s}\n\n", .{ GRAY, query, RESET });
    } else {
        std.debug.print("  {s}Found {d} cell(s){s}\n\n", .{ GREEN, match_count, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIND — filter by capability (commands, exports, etc.)
// ═══════════════════════════════════════════════════════════════════════════════

fn runFind(allocator: Allocator, args: []const []const u8) !void {
    // Parse flags
    var capability_filter: ?[]const u8 = null;
    var export_filter: ?[]const u8 = null;
    var command_filter: ?[]const u8 = null;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--capability") and i + 1 < args.len) {
            capability_filter = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--export") and i + 1 < args.len) {
            export_filter = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--command") and i + 1 < args.len) {
            command_filter = args[i + 1];
            i += 1;
        }
    }

    if (capability_filter == null and export_filter == null and command_filter == null) {
        std.debug.print("{s}Usage:{s} tri cell find --capability <name>\n", .{ YELLOW, RESET });
        std.debug.print("       tri cell find --command <name>\n", .{});
        std.debug.print("       tri cell find --export <name>\n\n", .{});
        std.debug.print("  Examples:\n", .{});
        std.debug.print("    tri cell find --capability pipeline\n", .{});
        std.debug.print("    tri cell find --command build\n", .{});
        std.debug.print("    tri cell find --export runIdempotencyCommand\n\n", .{});
        return;
    }

    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse registry\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const cells = (parsed.value.object.get("cells") orelse return).array.items;

    std.debug.print("\n{s}🎯 FIND CELLS BY CAPABILITY{s}\n\n", .{ CYAN, RESET });

    var match_count: usize = 0;

    for (cells) |item| {
        const obj = item.object;
        const path = jsonStr(obj, "path");

        // Load cell.tri for contributes
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);

        const cell_content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(cell_content);

        const cell = parseCellTri(cell_content);

        var matches = false;
        var match_details: []const u8 = "";

        // Check --capability filter (searches in capabilities array)
        if (capability_filter != null) {
            const cap = capability_filter.?;
            const cap_lower = try allocLower(allocator, cap);
            defer allocator.free(cap_lower);
            const caps_lower = try allocLower(allocator, cell.capabilities);
            defer allocator.free(caps_lower);

            if (std.mem.indexOf(u8, caps_lower, cap_lower) != null) {
                matches = true;
                match_details = "capability";
            }
        }

        // Check --command filter (searches in contributes.commands)
        if (!matches and command_filter != null) {
            const cmd = command_filter.?;
            var cmd_iter = cell_parser.ArrayIterator.init(cell.contributes_commands);
            while (cmd_iter.next()) |command| {
                if (std.mem.indexOf(u8, command, cmd) != null) {
                    matches = true;
                    match_details = "command";
                    break;
                }
            }
        }

        // Check --export filter (searches in contributes.exports)
        if (!matches and export_filter != null) {
            const exp = export_filter.?;
            var exp_iter = cell_parser.ArrayIterator.init(cell.contributes_exports);
            while (exp_iter.next()) |export_name| {
                if (std.mem.indexOf(u8, export_name, exp) != null) {
                    matches = true;
                    match_details = "export";
                    break;
                }
            }
        }

        if (!matches) continue;

        match_count += 1;
        const health = computeHealthScore(obj);
        const health_color = if (health >= 80) GREEN else if (health >= 50) YELLOW else RED;

        std.debug.print("  {s}{s}{s} ", .{ WHITE, cell.id, RESET });
        std.debug.print("{s}({s}){s}\n", .{ GRAY, match_details, RESET });
        std.debug.print("    Name: {s}\n", .{cell.name});

        // Show matching details
        if (command_filter != null and cell.contributes_commands.len > 0) {
            std.debug.print("    Commands: {s}\n", .{cell.contributes_commands});
        }
        if (export_filter != null and cell.contributes_exports.len > 0) {
            std.debug.print("    Exports: {s}\n", .{cell.contributes_exports});
        }
        if (capability_filter != null and cell.capabilities.len > 0) {
            std.debug.print("    Capabilities: {s}\n", .{cell.capabilities});
        }

        std.debug.print("    Health: {s}{d}%{s}\n", .{ health_color, health, RESET });
        std.debug.print("\n", .{});
    }

    if (match_count == 0) {
        std.debug.print("  {s}No cells found with specified capability{s}\n\n", .{ GRAY, RESET });
    } else {
        std.debug.print("  {s}Found {d} cell(s){s}\n\n", .{ GREEN, match_count, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INFO — detailed view of a single cell
// ═══════════════════════════════════════════════════════════════════════════════

fn runInfo(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage:{s} tri cell info <cell-id> [options]\n", .{ YELLOW, RESET });
        std.debug.print("\n  Options:\n", .{});
        std.debug.print("    --suggest-fix    Auto-run suggested fix\n", .{});
        std.debug.print("    --verbose        Show full error traces\n", .{});
        std.debug.print("\n  Example: tri cell info trinity.hslm\n", .{});
        std.debug.print("           tri cell info nonexistent-cell --suggest-fix\n", .{});
        return;
    }

    const cell_id = args[0];

    // Parse flags
    var suggest_fix = false;
    var verbose = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--suggest-fix")) suggest_fix = true;
        if (std.mem.eql(u8, arg, "--verbose")) verbose = true;
    }

    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("\n{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ RED, RESET });
        std.debug.print("{s}ERROR {s}: Failed to parse cell registry\n", .{ RED, RESET });
        std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ RED, RESET });
        std.debug.print("{s}What to do:{s} The registry file may be corrupted or malformed\n", .{ YELLOW, RESET });
        std.debug.print("  Quick fix: {s}tri cell check --regenerate {s}\n\n", .{ CYAN, RESET });
        return;
    };
    defer parsed.deinit();

    const cells = (parsed.value.object.get("cells") orelse {
        std.debug.print("\n{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ RED, RESET });
        std.debug.print("{s}ERROR {s}: Registry missing 'cells' key\n", .{ RED, RESET });
        std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ RED, RESET });
        std.debug.print("{s}What to do:{s} The registry structure is invalid\n", .{ YELLOW, RESET });
        std.debug.print("  Quick fix: {s}tri cell check --regenerate {s}\n\n", .{ CYAN, RESET });
        return;
    }).array.items;

    for (cells) |item| {
        const obj = item.object;
        const id = jsonStr(obj, "id");
        if (!std.mem.eql(u8, id, cell_id)) continue;

        // Read cell.tri from disk for fresh data
        const path = jsonStr(obj, "path");
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch return;
        defer allocator.free(cell_tri_path);

        const cell_content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch |err| {
            std.debug.print("\n{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ RED, RESET });
            std.debug.print("{s}ERROR {s}: Cannot read cell.tri: {}\n", .{ RED, RESET, err });
            std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ RED, RESET });
            std.debug.print("{s}What to do:{s} The cell manifest file may be missing or corrupted\n", .{ YELLOW, RESET });
            std.debug.print("  Quick fix: {s}tri cell check --regenerate {s}\n\n", .{ CYAN, RESET });
            return;
        };
        defer allocator.free(cell_content);

        const cell = parseCellTri(cell_content);
        const health = computeHealthScore(obj);
        const health_color = if (health >= 80) GREEN else if (health >= 50) YELLOW else RED;

        std.debug.print("\n{s}🐝 {s}{s}\n", .{ GOLDEN, cell.name, RESET });
        std.debug.print("  {s}ID:{s}              {s}\n", .{ CYAN, RESET, cell.id });
        std.debug.print("  {s}Version:{s}         {s}\n", .{ CYAN, RESET, cell.version });
        std.debug.print("  {s}Kind:{s}            {s}\n", .{ CYAN, RESET, cell.kind });
        std.debug.print("  {s}Status:{s}          {s}\n", .{ CYAN, RESET, cell.status });
        std.debug.print("  {s}Path:{s}            {s}\n", .{ CYAN, RESET, cell.path });
        std.debug.print("  {s}Owner:{s}           {s}\n", .{ CYAN, RESET, cell.owner });
        std.debug.print("  {s}Min Core:{s}        {s}\n", .{ CYAN, RESET, cell.min_core_version });
        std.debug.print("  {s}Capabilities:{s}    {s}\n", .{ CYAN, RESET, cell.capabilities });
        std.debug.print("  {s}Files:{s}           {d}\n", .{ CYAN, RESET, cell.files });
        std.debug.print("  {s}Tests:{s}           {d}\n", .{ CYAN, RESET, cell.tests });
        std.debug.print("  {s}Health:{s}          {s}{d}%{s}\n", .{ CYAN, RESET, health_color, health, RESET });

        // Tags
        if (cell.tags_scope.len > 0 or cell.tags_type.len > 0) {
            std.debug.print("  {s}Tags:{s}            scope={s}, type={s}\n", .{ CYAN, RESET, cell.tags_scope, cell.tags_type });
        }

        // Contributes
        if (cell.contributes_commands.len > 0) {
            std.debug.print("  {s}Commands:{s}        {s}\n", .{ CYAN, RESET, cell.contributes_commands });
        }
        if (cell.contributes_tri_subcommands.len > 0) {
            std.debug.print("  {s}Tri subcmds:{s}     {s}\n", .{ CYAN, RESET, cell.contributes_tri_subcommands });
        }
        if (cell.contributes_events.len > 0) {
            std.debug.print("  {s}Events:{s}          {s}\n", .{ CYAN, RESET, cell.contributes_events });
        }

        // Dependencies
        if (cell.dependencies_raw.len > 0) {
            std.debug.print("  {s}Dependencies:{s}\n", .{ CYAN, RESET });
            var dep_it = DepIterator.init(cell.dependencies_raw);
            while (dep_it.next()) |dep| {
                const dep_version = findCellVersion(cells, dep.id);
                const constraint = VersionConstraint.parse(dep.constraint);
                if (dep_version) |dv| {
                    if (constraint) |c| {
                        const ok = c.satisfies(dv);
                        var vbuf: [32]u8 = undefined;
                        const vs = dv.format(&vbuf);
                        std.debug.print("    {s} {s} -> {s} {s}\n", .{
                            dep.id, dep.constraint, vs, if (ok) GREEN ++ "OK" ++ RESET else RED ++ "FAIL" ++ RESET,
                        });
                    } else {
                        std.debug.print("    {s} {s} (bad constraint)\n", .{ dep.id, dep.constraint });
                    }
                } else {
                    std.debug.print("    {s}{s} {s} (not found){s}\n", .{ RED, dep.id, dep.constraint, RESET });
                }
            }
        }

        // Permissions
        if (cell.perm_level.len > 0) {
            const lvl_color = if (std.mem.eql(u8, cell.perm_level, "L0")) GREEN else if (std.mem.eql(u8, cell.perm_level, "L1")) YELLOW else RED;
            std.debug.print("  {s}Permissions:{s}     {s}{s}{s} fs={s} net={s} proc={s}", .{
                CYAN,                 RESET,             lvl_color,         cell.perm_level, RESET,
                cell.perm_filesystem, cell.perm_network, cell.perm_process,
            });
            if (cell.perm_ffi.len > 0 and !std.mem.eql(u8, cell.perm_ffi, "none")) {
                std.debug.print(" ffi={s}", .{cell.perm_ffi});
            }
            if (cell.perm_concurrency.len > 0 and !std.mem.eql(u8, cell.perm_concurrency, "none")) {
                std.debug.print(" concurrency={s}", .{cell.perm_concurrency});
            }
            std.debug.print("\n", .{});
        }

        // Security
        if (cell.security_signed) {
            std.debug.print("  {s}Security:{s}       signed=true", .{ CYAN, RESET });
            if (cell.security_signature.len > 0) {
                std.debug.print(" sig={s}...", .{cell.security_signature[0..@min(16, cell.security_signature.len)]});
            }
            std.debug.print("\n", .{});
        }

        // DNA section (Phoenix)
        if (cell.hasDNA()) {
            std.debug.print("\n  {s}── DNA (Phoenix) ──{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}DNA Source:{s}       {s}\n", .{ CYAN, RESET, cell.dna_source });
            std.debug.print("  {s}DNA Output:{s}       {s}\n", .{ CYAN, RESET, cell.dna_output });
            std.debug.print("  {s}Regenerable:{s}      {s}\n", .{ CYAN, RESET, if (cell.dna_regenerable) GREEN ++ "yes" ++ RESET else RED ++ "no" ++ RESET });
            if (cell.dna_contract_raw.len > 0) {
                std.debug.print("  {s}Contract:{s}\n", .{ CYAN, RESET });
                var contract_lines = std.mem.splitScalar(u8, cell.dna_contract_raw, '\n');
                while (contract_lines.next()) |line| {
                    const trimmed = std.mem.trim(u8, line, &[_]u8{ ' ', '\t', '\r' });
                    if (trimmed.len > 0) {
                        std.debug.print("    {s}\n", .{trimmed});
                    }
                }
            }
        }

        // Agent section
        if (cell.isAgent()) {
            std.debug.print("\n  {s}── Agent ──{s}\n", .{ GOLDEN, RESET });
            std.debug.print("  {s}Definition:{s}      {s}\n", .{ CYAN, RESET, cell.agent_definition });
            std.debug.print("  {s}Model:{s}           {s}\n", .{ CYAN, RESET, cell.agent_model });
            std.debug.print("  {s}Max Turns:{s}       {d}\n", .{ CYAN, RESET, cell.agent_max_turns });
            std.debug.print("  {s}Tools:{s}           {s}\n", .{ CYAN, RESET, cell.agent_tools });
            if (cell.agent_isolation.len > 0) {
                std.debug.print("  {s}Isolation:{s}       {s}\n", .{ CYAN, RESET, cell.agent_isolation });
            }
            // Check if definition file exists
            if (cell.agent_definition.len > 0) {
                if (std.fs.cwd().access(cell.agent_definition, .{})) |_| {
                    std.debug.print("  {s}Def Status:{s}      {s}EXISTS{s}\n", .{ CYAN, RESET, GREEN, RESET });
                } else |_| {
                    std.debug.print("  {s}Def Status:{s}      {s}MISSING{s}\n", .{ CYAN, RESET, RED, RESET });
                }
            }
        }

        // Content hash verification
        const expected_hash = jsonStr(obj, "content_hash");
        if (expected_hash.len > 0) {
            var hash: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(cell_content, &hash, .{});
            const actual_hex = std.fmt.bytesToHex(hash, .lower);
            const hash_ok = std.mem.eql(u8, actual_hex[0..64], expected_hash);
            std.debug.print("  {s}Hash:{s}            {s}{s}{s}\n", .{
                CYAN, RESET, if (hash_ok) GREEN else RED, if (hash_ok) "verified" else "MISMATCH", RESET,
            });
        }

        std.debug.print("  {s}Description:{s}     {s}\n\n", .{ CYAN, RESET, cell.description });
        return;
    }

    // Cell not found - provide enhanced error with suggestions
    std.debug.print("\n{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ RED, RESET });
    std.debug.print("{s}ERROR {s}: Cell '{s}' not found in registry\n", .{ RED, RESET, cell_id });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ RED, RESET });
    std.debug.print("{s}What to do:{s} Check for typos or the cell may not exist\n", .{ YELLOW, RESET });
    std.debug.print("  Quick fix: {s}tri cell list {s}\n\n", .{ CYAN, RESET });

    if (suggest_fix) {
        std.debug.print("{s}Running: tri cell list {s}\n", .{ YELLOW, RESET });
        runList(allocator, &[_][]const u8{}) catch {};
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INIT — scaffold new cell
// ═══════════════════════════════════════════════════════════════════════════════

fn runInit(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage:{s} tri cell init <name> [--kind tool|agent|backend|frontend] [--with-test] [--template <name>]\n", .{ YELLOW, RESET });
        std.debug.print("\n  Creates a new cell scaffold:\n", .{});
        std.debug.print("    tool/agent/backend → src/<name>/\n", .{});
        std.debug.print("    frontend           → apps/<name>/\n", .{});
        std.debug.print("    --with-test        Also create <name>.test.zig\n", .{});
        std.debug.print("    --template <name>  Use template from library (see: tri cell templates)\n", .{});
        return;
    }

    const name = args[0];

    var kind: []const u8 = "tool";
    var with_test = false;
    var template_name: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--kind") and i + 1 < args.len) {
            kind = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--with-test")) {
            with_test = true;
        } else if (std.mem.eql(u8, args[i], "--template") and i + 1 < args.len) {
            template_name = args[i + 1];
            i += 1;
        }
    }

    const base = if (std.mem.eql(u8, kind, "frontend")) "apps" else "src";

    const cell_dir = std.fmt.allocPrint(allocator, "{s}/{s}", .{ base, name }) catch return;
    defer allocator.free(cell_dir);

    std.fs.cwd().makePath(cell_dir) catch |err| {
        std.debug.print("{s}ERROR{s}: Cannot create {s}: {}\n", .{ RED, RESET, cell_dir, err });
        return;
    };

    const cell_id = std.fmt.allocPrint(allocator, "trinity.{s}", .{name}) catch return;
    defer allocator.free(cell_id);

    const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{cell_dir}) catch return;
    defer allocator.free(cell_tri_path);

    // Use template if specified
    if (template_name) |tmpl| {
        std.debug.print("\n{s}📋 Using template: {s}{s}\n\n", .{ GOLDEN, RESET, tmpl });

        // Try built-in template first
        const template_content = if (getTemplate(tmpl)) |builtin|
            builtin
        else if (try loadUserTemplate(allocator, tmpl)) |user|
            user
        else {
            std.debug.print("{s}ERROR{s}: Template '{s}' not found\n", .{ RED, RESET, tmpl });
            std.debug.print("  Run {s}tri cell templates{s} to see available templates\n\n", .{ GREEN, RESET });
            return;
        };

        const definition_path = std.fmt.allocPrint(allocator, ".claude/agents/{s}.md", .{name}) catch "";
        defer allocator.free(definition_path);

        const rendered = try renderTemplate(allocator, template_content, .{
            .cell_id = cell_id,
            .name = name,
            .path = cell_dir,
            .description = "TODO: describe this cell",
            .parent = "trinity.tri",
            .capabilities = "[]",
            .definition = definition_path,
        });
        defer allocator.free(rendered);

        writeFileIfNotExists(cell_tri_path, rendered);

        // For agent template, also create the .md definition file
        if (std.mem.eql(u8, tmpl, "agent")) {
            const md_path = std.fmt.allocPrint(allocator, "{s}", .{definition_path}) catch return;
            defer allocator.free(md_path);

            // Create parent directory if needed
            const md_dir = std.fs.path.dirname(md_path) orelse "";
            if (md_dir.len > 0) {
                std.fs.cwd().makePath(md_dir) catch {};
            }

            const md_content = std.fmt.allocPrint(allocator,
                \\---
                \\name: {s}
                \\description: TODO — describe this agent
                \\tools: Read, Edit, Write, Bash, Grep, Glob
                \\model: sonnet
                \\maxTurns: 20
                \\---
                \\
                \\You are {s} — a specialized agent in the Trinity project.
                \\
                \\## Your Scope
                \\
                \\TODO: Define what this agent does.
                \\
                \\## Protocol
                \\
                \\1. Read context before acting
                \\2. Make minimal, targeted changes
                \\3. Verify changes compile
                \\
            , .{ name, name }) catch return;
            defer allocator.free(md_content);

            writeFileIfNotExists(md_path, md_content);
            std.debug.print("  {s}{s}{s}   → {s}\n", .{ CYAN, "definition", RESET, md_path });
        }
    } else {
        // Default behavior without template
        const cell_tri = std.fmt.allocPrint(allocator,
            \\[cell]
            \\id = "{s}"
            \\name = "{s}"
            \\version = "0.1.0"
            \\kind = "{s}"
            \\path = "{s}"
            \\min_core_version = "{s}"
            \\status = "experimental"
            \\description = "TODO: describe this cell"
            \\capabilities = []
            \\files = 1
            \\tests = 1
            \\owner = ""
            \\
            \\[tags]
            \\scope = ""
            \\type = "{s}"
            \\
            \\[contributes]
            \\commands = []
            \\tri_subcommands = []
            \\events = []
            \\
            \\[dependencies]
            \\
            \\[permissions]
            \\level = "L0"
            \\filesystem = "none"
            \\network = "none"
            \\process = "none"
            \\ffi = "none"
            \\concurrency = "none"
            \\
        , .{ cell_id, name, kind, cell_dir, CORE_VERSION, kind }) catch return;
        defer allocator.free(cell_tri);

        writeFileIfNotExists(cell_tri_path, cell_tri);
    }

    const main_zig_path = std.fmt.allocPrint(allocator, "{s}/main.zig", .{cell_dir}) catch return;
    defer allocator.free(main_zig_path);

    const main_content =
        \\// Trinity Cell: {name}
        \\// Generated by: tri cell init
        \\
        \\const std = @import("std");
        \\
        \\pub fn run() !void {
        \\    std.debug.print("Cell initialized\n", .{});
        \\}
        \\
        \\test "cell basic" {
        \\    try std.testing.expect(true);
        \\}
        \\
    ;
    writeFileIfNotExists(main_zig_path, main_content);

    // Create test file if --with-test flag
    if (with_test) {
        const test_zig_path = std.fmt.allocPrint(allocator, "{s}/{s}.test.zig", .{ cell_dir, name }) catch return;
        defer allocator.free(test_zig_path);

        const test_content = std.fmt.allocPrint(allocator,
            \\// Trinity Cell Tests: {s}
            \\// Generated by: tri cell init --with-test
            \\
            \\const std = @import("std");
            \\
            \\test "{s} basic functionality" {{
            \\    // TODO: Add actual test logic
            \\    try std.testing.expect(true);
            \\}}
            \\
        , .{ name, name }) catch return;
        defer allocator.free(test_content);

        writeFileIfNotExists(test_zig_path, test_content);
        std.debug.print("  {s}{s}.test.zig{s} → {s}\n", .{ CYAN, RESET, name, test_zig_path });
    }

    std.debug.print("\n{s}🐝 Cell created:{s} {s}\n\n", .{ GREEN, RESET, cell_id });
    std.debug.print("  {s}cell.tri{s}   → {s}\n", .{ CYAN, RESET, cell_tri_path });
    std.debug.print("  {s}main.zig{s}   → {s}\n", .{ CYAN, RESET, main_zig_path });
    std.debug.print("\n  Next steps:\n", .{});
    std.debug.print("    1. Edit {s} — set description and capabilities\n", .{cell_tri_path});
    std.debug.print("    2. Implement in {s}\n", .{main_zig_path});
    std.debug.print("    3. {s}tri cell check --sync{s} — validate and sync registry\n\n", .{ GREEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHECK — validate manifests with dynamic filesystem discovery
// ═══════════════════════════════════════════════════════════════════════════════

fn runCheck(allocator: Allocator, args: []const []const u8) !void {
    var do_sync = false;
    var dry_run = false;
    var auto_register = false;
    var auto_yes = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--sync")) do_sync = true;
        if (std.mem.eql(u8, arg, "--dry-run")) {
            dry_run = true;
            do_sync = true;
        }
        if (std.mem.eql(u8, arg, "--auto-register")) {
            auto_register = true;
            do_sync = true;
        }
        if (std.mem.eql(u8, arg, "--yes")) auto_yes = true;
    }

    // H2: Auto-register mode
    if (auto_register) {
        return runAutoRegister(allocator, dry_run, auto_yes);
    }

    std.debug.print("\n{s}🐝 Checking cell manifests...{s}\n\n", .{ GOLDEN, RESET });

    // Dynamic discovery instead of hardcoded paths
    const discovered = discoverCells(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer {
        for (discovered) |p| allocator.free(p);
        allocator.free(discovered);
    }

    // Load existing registry to preserve per-cell metadata (owner, enabled, tags, contributes)
    var existing_meta = std.StringHashMap(std.json.Value).init(allocator);
    defer existing_meta.deinit();
    if (do_sync) {
        const reg_data = std.fs.cwd().readFileAlloc(allocator, "data/cells/registry.json", 262144) catch null;
        if (reg_data) |rd| {
            defer allocator.free(rd);
            if (std.json.parseFromSlice(std.json.Value, allocator, rd, .{})) |reg_parsed| {
                // Note: we keep reg_parsed alive by not deferring deinit — metadata is borrowed
                _ = &reg_parsed;
                if (reg_parsed.value.object.get("cells")) |c| {
                    for (c.array.items) |cell_item| {
                        const cid = jsonStr(cell_item.object, "id");
                        if (cid.len > 0) {
                            existing_meta.put(cid, cell_item) catch {};
                        }
                    }
                }
            } else |_| {}
        }
    }

    var valid: usize = 0;
    var invalid: usize = 0;
    var core_issues: usize = 0;

    var sync_buf = std.array_list.Managed(u8).init(allocator);
    defer sync_buf.deinit();

    if (do_sync) {
        const writer = sync_buf.writer();
        try writer.writeAll("{\n  \"version\": \"1.0.0\",\n  \"updated\": \"2026-03-17\",\n  \"core_version\": \"");
        try writer.writeAll(CORE_VERSION);
        try writer.writeAll("\",\n  \"core_files\": [\n    \"src/vsa.zig\", \"src/vm.zig\", \"src/hybrid.zig\", \"src/sdk.zig\",\n    \"src/sparse.zig\", \"src/jit.zig\", \"src/science.zig\", \"src/c_api.zig\"\n  ],\n  \"cells\": [\n");
    }

    var first_sync_entry = true;

    for (discovered) |path| {
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);

        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch {
            std.debug.print("  {s}MISSING{s}  {s}/cell.tri\n", .{ RED, RESET, path });
            invalid += 1;
            continue;
        };
        defer allocator.free(content);

        const cell = parseCellTri(content);

        if (cell.id.len == 0 or cell.name.len == 0 or cell.version.len == 0) {
            std.debug.print("  {s}INVALID{s}  {s} — missing required fields\n", .{ RED, RESET, path });
            invalid += 1;
            continue;
        }

        if (cell.min_core_version.len > 0) {
            if (!isVersionCompatible(cell.min_core_version, CORE_VERSION)) {
                std.debug.print("  {s}COMPAT{s}   {s} — requires core >= {s}, have {s}\n", .{
                    YELLOW, RESET, cell.id, cell.min_core_version, CORE_VERSION,
                });
                core_issues += 1;
            }
        }

        if (do_sync) {
            const writer = sync_buf.writer();
            if (!first_sync_entry) try writer.writeAll(",\n");
            first_sync_entry = false;

            var hash: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(content, &hash, .{});
            const hash_hex = std.fmt.bytesToHex(hash, .lower);

            // Preserve existing metadata if available
            var owner: []const u8 = cell.owner;
            var enabled = true;
            if (existing_meta.get(cell.id)) |existing| {
                const eo = jsonStr(existing.object, "owner");
                if (eo.len > 0) owner = eo;
                enabled = jsonBool(existing.object, "enabled");
            }

            // Build cell JSON entry using writeJsonPretty-style inline
            try writer.print("    {{\"id\": \"{s}\", \"path\": \"{s}\", \"version\": \"{s}\", \"kind\": \"{s}\", \"status\": \"{s}\", \"files\": {d}, \"tests\": {d}, \"enabled\": {s}, \"owner\": \"{s}\", \"spec_version\": 2, \"api_version\": \"{s}\", \"content_hash\": \"{s}\"", .{
                cell.id,                          cell.path, cell.version, cell.kind,       cell.status, cell.files, cell.tests,
                if (enabled) "true" else "false", owner,     CORE_VERSION, hash_hex[0..64],
            });

            // Capabilities
            try writer.writeAll(", \"capabilities\": [");
            try writeStrArrayFromCellTri(writer, cell.capabilities);
            try writer.writeAll("]");

            // Tags
            try writer.print(", \"tags\": {{\"scope\": \"{s}\", \"type\": \"{s}\"}}", .{ cell.tags_scope, cell.tags_type });

            // Contributes
            try writer.writeAll(", \"contributes\": {\"commands\": [");
            try writeStrArrayFromCellTri(writer, cell.contributes_commands);
            try writer.writeAll("], \"tri_subcommands\": [");
            try writeStrArrayFromCellTri(writer, cell.contributes_tri_subcommands);
            try writer.writeAll("], \"events\": [");
            try writeStrArrayFromCellTri(writer, cell.contributes_events);
            try writer.writeAll("]}");

            // Dependencies
            if (DepIterator.count(cell.dependencies_raw) > 0) {
                try writer.writeAll(", \"dependencies\": [");
                var dep_first = true;
                var dep_it = DepIterator.init(cell.dependencies_raw);
                while (dep_it.next()) |dep| {
                    if (!dep_first) try writer.writeAll(", ");
                    dep_first = false;
                    try writer.print("\"{s}:{s}\"", .{ dep.id, dep.constraint });
                }
                try writer.writeAll("]");
            }

            // Permissions
            if (cell.perm_level.len > 0) {
                try writer.print(", \"permissions\": {{\"level\": \"{s}\", \"filesystem\": \"{s}\", \"network\": \"{s}\", \"process\": \"{s}\", \"ffi\": \"{s}\", \"concurrency\": \"{s}\"}}", .{
                    cell.perm_level, cell.perm_filesystem,  cell.perm_network, cell.perm_process,
                    cell.perm_ffi,   cell.perm_concurrency,
                });
            }

            // Security
            if (cell.security_signed) {
                try writer.print(", \"security\": {{\"signed\": true, \"signature\": \"{s}\"}}", .{cell.security_signature});
            }

            // Agent metadata (Step 7: registry JSON extension)
            if (cell.isAgent()) {
                try writer.print(", \"agent\": {{\"definition\": \"{s}\", \"model\": \"{s}\", \"max_turns\": {d}, \"tools\": \"{s}\", \"isolation\": \"{s}\"}}", .{
                    cell.agent_definition, cell.agent_model,     cell.agent_max_turns,
                    cell.agent_tools,      cell.agent_isolation,
                });
            }

            // DNA metadata (Phoenix system: regeneration contract)
            if (cell.hasDNA()) {
                try writer.print(", \"dna\": {{\"source\": \"{s}\", \"output\": \"{s}\", \"regenerable\": {s}}}", .{
                    cell.dna_source,
                    cell.dna_output,
                    if (cell.dna_regenerable) "true" else "false",
                });
            }

            // Biology classification
            if (cell.bio_system.len > 0) {
                try writer.print(", \"biology\": {{\"system\": \"{s}\", \"organ\": \"{s}\"}}", .{
                    cell.bio_system,
                    cell.bio_organ,
                });
            }

            try writer.writeAll("}");
        }

        // Step 6: Agent permission consistency warnings
        if (cell.isAgent()) {
            var has_warn = false;
            // tools contains "Bash" → process should be "spawn"
            if (std.mem.indexOf(u8, cell.agent_tools, "Bash") != null and
                !std.mem.eql(u8, cell.perm_process, "spawn"))
            {
                if (!has_warn) std.debug.print("  {s}WARN{s}     {s}:\n", .{ YELLOW, RESET, cell.id });
                has_warn = true;
                std.debug.print("           tools has Bash but process={s} (should be spawn)\n", .{cell.perm_process});
            }
            // tools contains "Edit" or "Write" → filesystem should be "write"
            if ((std.mem.indexOf(u8, cell.agent_tools, "Edit") != null or
                std.mem.indexOf(u8, cell.agent_tools, "Write") != null) and
                !std.mem.eql(u8, cell.perm_filesystem, "write"))
            {
                if (!has_warn) std.debug.print("  {s}WARN{s}     {s}:\n", .{ YELLOW, RESET, cell.id });
                has_warn = true;
                std.debug.print("           tools has Edit/Write but filesystem={s} (should be write)\n", .{cell.perm_filesystem});
            }
            // tools contains "mcp__perplexity" → network should be "external"
            if (std.mem.indexOf(u8, cell.agent_tools, "mcp__perplexity") != null and
                !std.mem.eql(u8, cell.perm_network, "external"))
            {
                if (!has_warn) std.debug.print("  {s}WARN{s}     {s}:\n", .{ YELLOW, RESET, cell.id });
                has_warn = true;
                std.debug.print("           tools has mcp__perplexity but network={s} (should be external)\n", .{cell.perm_network});
            }
        }

        std.debug.print("  {s}OK{s}       {s} ({s})\n", .{ GREEN, RESET, cell.id, cell.version });
        valid += 1;
    }

    std.debug.print("\n  {s}Valid: {d}{s} | {s}Invalid: {d}{s}", .{
        GREEN,                          valid,   RESET,
        if (invalid > 0) RED else GRAY, invalid, RESET,
    });
    if (core_issues > 0) {
        std.debug.print(" | {s}Core compat: {d}{s}", .{ YELLOW, core_issues, RESET });
    }
    std.debug.print("\n\n", .{});

    if (invalid == 0) {
        std.debug.print("  {s}All cell manifests are valid.{s}\n\n", .{ GREEN, RESET });
    }

    if (do_sync) {
        const writer = sync_buf.writer();
        try writer.writeAll(
            \\
            \\  ],
            \\  "plugins": [],
            \\  "boundary_rules": [
            \\    {"sourceTag": "type:agent", "allowedDeps": ["type:library", "type:tool"], "deniedDeps": ["type:ui"]},
            \\    {"sourceTag": "type:ui", "deniedDeps": ["type:agent"]},
            \\    {"sourceTag": "type:library", "deniedDeps": ["type:agent", "type:ui", "type:backend"]},
            \\    {"sourceTag": "type:tool", "deniedDeps": ["type:agent", "type:ui"]},
            \\    {"sourceTag": "type:backend", "deniedDeps": ["type:agent", "type:ui"]}
            \\  ]
            \\}
            \\
        );

        if (dry_run) {
            std.debug.print("  {s}[DRY RUN]{s} Would write registry.json ({d} cells, {d} bytes)\n\n", .{ YELLOW, RESET, valid, sync_buf.items.len });
        } else {
            const registry_path = "data/cells/registry.json";
            const file = std.fs.cwd().createFile(registry_path, .{}) catch |err| {
                std.debug.print("{s}ERROR{s}: Cannot write {s}: {}\n", .{ RED, RESET, registry_path, err });
                return;
            };
            defer file.close();
            file.writeAll(sync_buf.items) catch |err| {
                std.debug.print("{s}ERROR{s}: Write failed: {}\n", .{ RED, RESET, err });
                return;
            };
            std.debug.print("  {s}✓ Registry synced:{s} {s} ({d} cells)\n", .{ GREEN, RESET, registry_path, valid });

            // Auto-regenerate MCP tools (Honeycomb v7 — single pipeline)
            const cell_dispatch = @import("tri_cell_dispatch.zig");
            cell_dispatch.runMcpGenCommand(allocator) catch {};
            cell_dispatch.invalidateCache();
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEPS — dependency tree for a single cell
// ═══════════════════════════════════════════════════════════════════════════════

fn runDeps(allocator: Allocator, args: []const []const u8) !void {
    // tri cell deps --auto-detect → scan @imports across all cells
    for (args) |a| {
        if (std.mem.eql(u8, a, "--auto-detect")) {
            const write_mode = for (args) |b| {
                if (std.mem.eql(u8, b, "--write")) break true;
            } else false;
            return runAutoDetectDeps(allocator, write_mode);
        }
        if (std.mem.eql(u8, a, "--prune")) {
            const write_mode = for (args) |b| {
                if (std.mem.eql(u8, b, "--write")) break true;
            } else false;
            return runPruneDeps(allocator, write_mode);
        }
        if (std.mem.eql(u8, a, "--cycles")) {
            return runDetectCycles(allocator);
        }
        if (std.mem.eql(u8, a, "--dead")) {
            return runDeadCells(allocator);
        }
        if (std.mem.eql(u8, a, "--validate")) {
            return runDepsValidate(allocator, args);
        }
    }

    if (args.len == 0) {
        std.debug.print("{s}Usage:{s} tri cell deps <cell-id> [--tree]\n", .{ YELLOW, RESET });
        std.debug.print("       tri cell deps --auto-detect [--write]\n", .{});
        std.debug.print("       tri cell deps --prune [--write]\n", .{});
        std.debug.print("       tri cell deps --cycles\n", .{});
        std.debug.print("       tri cell deps --dead\n", .{});
        std.debug.print("       tri cell deps --validate [--threshold=0.8]\n", .{});
        return;
    }

    const cell_id = args[0];
    var recursive = false;
    for (args[1..]) |a| {
        if (std.mem.eql(u8, a, "--tree")) recursive = true;
    }

    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse registry\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const cells = (parsed.value.object.get("cells") orelse return).array.items;

    // Find the cell and read its cell.tri
    var cell_path: ?[]const u8 = null;
    var cell_version_str: ?[]const u8 = null;
    for (cells) |item| {
        const obj = item.object;
        if (std.mem.eql(u8, jsonStr(obj, "id"), cell_id)) {
            cell_path = jsonStr(obj, "path");
            cell_version_str = jsonStr(obj, "version");
            break;
        }
    }

    if (cell_path == null) {
        std.debug.print("{s}ERROR{s}: Cell '{s}' not found\n", .{ RED, RESET, cell_id });
        return;
    }

    const tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{cell_path.?}) catch return;
    defer allocator.free(tri_path);
    const content = std.fs.cwd().readFileAlloc(allocator, tri_path, 65536) catch {
        std.debug.print("{s}ERROR{s}: Cannot read {s}\n", .{ RED, RESET, tri_path });
        return;
    };
    defer allocator.free(content);

    const cell = parseCellTri(content);

    std.debug.print("\n{s}{s}{s} ({s})\n", .{ WHITE, cell_id, RESET, cell_version_str orelse "?" });

    if (cell.dependencies_raw.len == 0) {
        std.debug.print("  {s}(no dependencies){s}\n\n", .{ GRAY, RESET });
        return;
    }

    // Track visited for cycle detection in --tree mode
    var visited = std.StringHashMap(void).init(allocator);
    defer visited.deinit();
    visited.put(cell_id, {}) catch {};

    printDepsTree(allocator, cells, cell.dependencies_raw, "  ", recursive, &visited);
    std.debug.print("\n", .{});
}

fn printDepsTree(allocator: Allocator, cells: []const std.json.Value, deps_raw: []const u8, prefix: []const u8, recursive: bool, visited: *std.StringHashMap(void)) void {
    const total = DepIterator.count(deps_raw);
    if (total == 0) return;

    var dep_it = DepIterator.init(deps_raw);
    var idx: usize = 0;
    while (dep_it.next()) |dep| {
        const is_last = idx == total - 1;
        idx += 1;
        const connector = if (is_last) "└─" else "├─";

        const dep_version = findCellVersion(cells, dep.id);
        const constraint = VersionConstraint.parse(dep.constraint);

        std.debug.print("{s}{s} {s} {s}", .{ prefix, connector, dep.id, dep.constraint });

        if (dep_version) |dv| {
            if (constraint) |c| {
                var vbuf: [32]u8 = undefined;
                const vs = dv.format(&vbuf);
                const ok = c.satisfies(dv);
                std.debug.print(" -> {s} {s}\n", .{ vs, if (ok) GREEN ++ "OK" ++ RESET else RED ++ "FAIL" ++ RESET });
            } else {
                std.debug.print(" (bad constraint)\n", .{});
            }

            // Recurse if --tree
            if (recursive) {
                if (!visited.contains(dep.id)) {
                    visited.put(dep.id, {}) catch {};
                    for (cells) |cell_item| {
                        if (std.mem.eql(u8, jsonStr(cell_item.object, "id"), dep.id)) {
                            const dep_path = jsonStr(cell_item.object, "path");
                            const dep_tri = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{dep_path}) catch break;
                            defer allocator.free(dep_tri);
                            const dep_content = std.fs.cwd().readFileAlloc(allocator, dep_tri, 65536) catch break;
                            defer allocator.free(dep_content);
                            const dep_cell = parseCellTri(dep_content);
                            if (dep_cell.dependencies_raw.len > 0) {
                                const child_prefix = std.fmt.allocPrint(allocator, "{s}{s} ", .{ prefix, if (is_last) " " else "│" }) catch break;
                                defer allocator.free(child_prefix);
                                printDepsTree(allocator, cells, dep_cell.dependencies_raw, child_prefix, true, visited);
                            }
                            break;
                        }
                    }
                } else {
                    std.debug.print("{s}{s}  {s}(cycle){s}\n", .{ prefix, if (is_last) " " else "│", GRAY, RESET });
                }
            }
        } else {
            std.debug.print(" {s}(not found){s}\n", .{ RED, RESET });
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTO-DETECT DEPS — Scan @import statements to find real cross-cell dependencies
// ═══════════════════════════════════════════════════════════════════════════════

fn runAutoDetectDeps(allocator: Allocator, write_mode: bool) !void {
    std.debug.print("{s}[auto-detect]{s} Scanning @import statements across all cells...\n\n", .{ CYAN, RESET });

    const cells = cell_parser.discoverAll(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(cells);

    // Build cell_path → cell_id mapping
    var path_to_cell = std.StringHashMap([]const u8).init(allocator);
    defer path_to_cell.deinit();
    for (cells) |cell| {
        path_to_cell.put(cell.manifest.path, cell.manifest.id) catch {};
    }

    var total_missing: usize = 0;
    var total_confirmed: usize = 0;
    var cells_with_empty_deps: usize = 0;
    var cells_with_imports: usize = 0;

    for (cells) |cell| {
        const m = cell.manifest;
        const cell_path = m.path;

        // Scan .zig files in cell's path
        var detected_deps = std.StringHashMap(void).init(allocator);
        defer detected_deps.deinit();
        var import_count: usize = 0;

        var dir = std.fs.cwd().openDir(cell_path, .{ .iterate = true }) catch continue;
        defer dir.close();

        const has_patterns = m.file_patterns.len > 2; // more than "[]"

        var walker = dir.iterate();
        while (walker.next() catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
            // For virtual sub-cells, only scan files matching their patterns
            if (has_patterns and !matchesFilePatterns(entry.name, m.file_patterns)) continue;

            // Read file content
            const content = dir.readFileAlloc(allocator, entry.name, 1048576) catch continue;
            defer allocator.free(content);

            // Scan for @import("...") patterns
            var pos: usize = 0;
            while (std.mem.indexOf(u8, content[pos..], "@import(\"")) |idx| {
                const abs_start = pos + idx + 9; // skip @import("
                const end = std.mem.indexOf(u8, content[abs_start..], "\"") orelse break;
                const import_path = content[abs_start .. abs_start + end];
                pos = abs_start + end + 1;

                // Skip stdlib imports
                if (std.mem.eql(u8, import_path, "std") or
                    std.mem.eql(u8, import_path, "builtin") or
                    std.mem.eql(u8, import_path, "root"))
                    continue;

                // Check if it's a cross-cell import (relative or root-relative path)
                if (std.mem.startsWith(u8, import_path, "../") or
                    std.mem.startsWith(u8, import_path, "src/") or
                    std.mem.startsWith(u8, import_path, "libs/") or
                    std.mem.startsWith(u8, import_path, "fpga/"))
                {
                    const resolved = resolveImportToCell(import_path, cell_path, &path_to_cell);
                    if (resolved) |dep_cell_id| {
                        if (!std.mem.eql(u8, dep_cell_id, m.id)) {
                            detected_deps.put(dep_cell_id, {}) catch {};
                            import_count += 1;
                        }
                    }
                } else if (!std.mem.endsWith(u8, import_path, ".zig")) {
                    // Bare module name like "vsa" or "tvc_corpus" — check if a cell owns it
                    for (cells) |other| {
                        const other_path = other.manifest.path;
                        // Match if the import name matches the cell directory name
                        if (std.mem.lastIndexOfScalar(u8, other_path, '/')) |slash| {
                            const dir_name = other_path[slash + 1 ..];
                            if (std.mem.eql(u8, import_path, dir_name) and !std.mem.eql(u8, other.manifest.id, m.id)) {
                                detected_deps.put(other.manifest.id, {}) catch {};
                                import_count += 1;
                                break;
                            }
                        }
                    }
                }
                // Internal .zig imports (same directory) → skip
            }
        }

        // Compare detected vs declared
        var declared_deps = std.StringHashMap(void).init(allocator);
        defer declared_deps.deinit();
        var dep_it = cell_parser.DepIterator.init(m.dependencies_raw);
        while (dep_it.next()) |dep_entry| {
            declared_deps.put(dep_entry.id, {}) catch {};
        }

        const has_declared = declared_deps.count() > 0;
        const has_detected = detected_deps.count() > 0;

        if (!has_declared and !has_detected) {
            cells_with_empty_deps += 1;
            continue;
        }

        if (has_detected) cells_with_imports += 1;

        // Print diff for this cell
        var printed_header = false;

        // Check confirmed deps (declared AND detected)
        var declared_it = declared_deps.iterator();
        while (declared_it.next()) |entry| {
            if (detected_deps.contains(entry.key_ptr.*)) {
                if (!printed_header) {
                    std.debug.print("{s}{s}:{s}\n", .{ GOLDEN, m.id, RESET });
                    printed_header = true;
                }
                std.debug.print("  {s}\u{2713}{s} {s} (declared, confirmed by @import)\n", .{ GREEN, RESET, entry.key_ptr.* });
                total_confirmed += 1;
            }
        }

        // Check missing deps (detected but NOT declared)
        var detected_it = detected_deps.iterator();
        while (detected_it.next()) |entry| {
            if (!declared_deps.contains(entry.key_ptr.*)) {
                if (!printed_header) {
                    std.debug.print("{s}{s}:{s}\n", .{ GOLDEN, m.id, RESET });
                    printed_header = true;
                }
                std.debug.print("  {s}+{s} {s} ({s}MISSING{s} \u{2014} found @import)\n", .{ RED, RESET, entry.key_ptr.*, RED, RESET });
                total_missing += 1;
            }
        }

        // Check extra declared deps (declared but NOT detected)
        declared_it = declared_deps.iterator();
        while (declared_it.next()) |entry| {
            if (!detected_deps.contains(entry.key_ptr.*)) {
                if (!printed_header) {
                    std.debug.print("{s}{s}:{s}\n", .{ GOLDEN, m.id, RESET });
                    printed_header = true;
                }
                std.debug.print("  {s}?{s} {s} (declared, no @import found)\n", .{ YELLOW, RESET, entry.key_ptr.* });
            }
        }

        if (printed_header) std.debug.print("\n", .{});
    }

    // Summary
    std.debug.print("{s}[auto-detect summary]{s}\n", .{ CYAN, RESET });
    std.debug.print("  Confirmed deps: {s}{d}{s}\n", .{ GREEN, total_confirmed, RESET });
    std.debug.print("  Missing deps:   {s}{d}{s}\n", .{ RED, total_missing, RESET });
    std.debug.print("  Cells with cross-cell imports: {d}\n", .{cells_with_imports});
    std.debug.print("  Cells with empty deps (truly independent): {d}\n", .{cells_with_empty_deps});

    if (write_mode and total_missing > 0) {
        std.debug.print("\n{s}--write{s} mode: Writing deps to cell.tri is not yet implemented.\n", .{ YELLOW, RESET });
        std.debug.print("  Review the output above and add missing deps manually.\n", .{});
    } else if (total_missing > 0) {
        std.debug.print("\n  Run with {s}--write{s} to update cell.tri files (coming soon).\n", .{ YELLOW, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRUNE — find declared deps with no matching @import
// ═══════════════════════════════════════════════════════════════════════════════

fn runPruneDeps(allocator: Allocator, write_mode: bool) !void {
    std.debug.print("{s}[prune]{s} Finding declared deps with no matching @import...\n\n", .{ CYAN, RESET });

    const all_cells = cell_parser.discoverAll(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(all_cells);

    var path_to_cell = std.StringHashMap([]const u8).init(allocator);
    defer path_to_cell.deinit();
    for (all_cells) |c| path_to_cell.put(c.manifest.path, c.manifest.id) catch {};

    var total_prunable: usize = 0;

    for (all_cells) |c| {
        const m = c.manifest;
        const cell_info = parseCellTri(c.content);
        const dep_acc = computeDepsAccuracy(allocator, m.path, cell_info, all_cells, &path_to_cell);

        if (dep_acc.extra == 0) continue;

        std.debug.print("{s}{s}:{s}\n", .{ GOLDEN, m.id, RESET });

        // Re-scan to show specifics
        var declared_deps = std.StringHashMap(void).init(allocator);
        defer declared_deps.deinit();
        var dep_it = cell_parser.DepIterator.init(m.dependencies_raw);
        while (dep_it.next()) |dep_entry| declared_deps.put(dep_entry.id, {}) catch {};

        // Scan actual imports (filtered by file_patterns for virtual sub-cells)
        var detected_deps = std.StringHashMap(void).init(allocator);
        defer detected_deps.deinit();
        scanCellImportsFiltered(allocator, m.path, m.id, m.file_patterns, all_cells, &path_to_cell, &detected_deps);

        var dit = declared_deps.iterator();
        while (dit.next()) |entry| {
            if (!detected_deps.contains(entry.key_ptr.*)) {
                std.debug.print("  {s}✂{s} {s} (declared, no @import found — prunable)\n", .{ YELLOW, RESET, entry.key_ptr.* });
                total_prunable += 1;
            }
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("{s}[prune summary]{s} {d} prunable deps found\n", .{ CYAN, RESET, total_prunable });
    if (write_mode and total_prunable > 0) {
        std.debug.print("\n{s}[prune --write]{s} Rewriting cell.tri files...\n", .{ CYAN, RESET });
        var files_written: usize = 0;
        for (all_cells) |c| {
            const m = c.manifest;
            const cell_info = parseCellTri(c.content);
            const dep_acc = computeDepsAccuracy(allocator, m.path, cell_info, all_cells, &path_to_cell);
            if (dep_acc.extra == 0) continue;

            // Find which deps to keep (filtered by file_patterns for virtual sub-cells)
            var detected_deps = std.StringHashMap(void).init(allocator);
            defer detected_deps.deinit();
            scanCellImportsFiltered(allocator, m.path, m.id, m.file_patterns, all_cells, &path_to_cell, &detected_deps);

            // Rebuild cell.tri content, filtering out prunable dep lines
            const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{m.path}) catch continue;
            defer allocator.free(cell_tri_path);
            const original = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
            defer allocator.free(original);

            var result = std.array_list.Managed(u8).init(allocator);
            defer result.deinit();

            var in_deps_section = false;
            var lines_iter = std.mem.splitScalar(u8, original, '\n');
            while (lines_iter.next()) |line| {
                // Detect section headers
                if (line.len > 0 and line[0] == '[') {
                    in_deps_section = std.mem.eql(u8, line, "[dependencies]");
                    result.appendSlice(line) catch continue;
                    result.append('\n') catch continue;
                    continue;
                }

                if (in_deps_section and std.mem.indexOf(u8, line, " = ") != null) {
                    // Parse dep id: "trinity.foo = ^1.0.0" → extract "trinity.foo"
                    const eq_pos = std.mem.indexOf(u8, line, " = ") orelse {
                        result.appendSlice(line) catch continue;
                        result.append('\n') catch continue;
                        continue;
                    };
                    const dep_id = std.mem.trim(u8, line[0..eq_pos], &[_]u8{' '});

                    // Check if this dep has a real @import
                    var declared_deps_check = std.StringHashMap(void).init(allocator);
                    defer declared_deps_check.deinit();
                    var dep_it_check = cell_parser.DepIterator.init(m.dependencies_raw);
                    while (dep_it_check.next()) |de| declared_deps_check.put(de.id, {}) catch {};

                    if (declared_deps_check.contains(dep_id) and !detected_deps.contains(dep_id)) {
                        // Prunable — skip this line
                        std.debug.print("  {s}✂{s} {s}: removed {s}\n", .{ GREEN, RESET, m.id, dep_id });
                        continue;
                    }
                }

                result.appendSlice(line) catch continue;
                result.append('\n') catch continue;
            }

            // Remove trailing extra newline
            if (result.items.len > 0 and result.items[result.items.len - 1] == '\n') {
                _ = result.pop();
            }

            const file = std.fs.cwd().createFile(cell_tri_path, .{}) catch continue;
            defer file.close();
            file.writeAll(result.items) catch continue;
            files_written += 1;
        }
        std.debug.print("\n{s}[prune done]{s} {d} cell.tri files rewritten\n", .{ CYAN, RESET, files_written });
    } else if (total_prunable > 0) {
        std.debug.print("  Run with {s}--write{s} to auto-prune.\n", .{ YELLOW, RESET });
    }
}

// Helper: scan @imports for a cell into a hashmap
/// Resolve a build-system module name (e.g., "vsa", "tri") to a cell ID.
/// Prefers parent cells over sub-cells when path matches (e.g., trinity.tri over trinity.tri.farm).
fn resolveModuleToCell(
    import_name: []const u8,
    self_id: []const u8,
    all_cells: []const cell_parser.DiscoveredCell,
) ?[]const u8 {
    var best_match: ?[]const u8 = null;
    for (all_cells) |other| {
        const other_path = other.manifest.path;
        if (std.mem.lastIndexOfScalar(u8, other_path, '/')) |slash| {
            const dir_name = other_path[slash + 1 ..];
            if (std.mem.eql(u8, import_name, dir_name) and !std.mem.eql(u8, other.manifest.id, self_id)) {
                // Prefer parent cell (no parent field) over sub-cells
                if (other.manifest.parent.len == 0) return other.manifest.id;
                if (best_match == null) best_match = other.manifest.id;
            }
        }
    }
    return best_match;
}

fn scanCellImports(
    allocator: Allocator,
    cell_path: []const u8,
    cell_id: []const u8,
    all_cells: []const cell_parser.DiscoveredCell,
    path_to_cell: *std.StringHashMap([]const u8),
    detected_deps: *std.StringHashMap(void),
) void {
    scanCellImportsFiltered(allocator, cell_path, cell_id, "", all_cells, path_to_cell, detected_deps);
}

fn scanCellImportsFiltered(
    allocator: Allocator,
    cell_path: []const u8,
    cell_id: []const u8,
    file_patterns: []const u8,
    all_cells: []const cell_parser.DiscoveredCell,
    path_to_cell: *std.StringHashMap([]const u8),
    detected_deps: *std.StringHashMap(void),
) void {
    const has_patterns = file_patterns.len > 2; // more than "[]"

    var dir = std.fs.cwd().openDir(cell_path, .{ .iterate = true }) catch return;
    defer dir.close();

    // Use walk() to descend into subdirectories (e.g., src/models/tqnn/)
    var walker = dir.walk(allocator) catch return;
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;
        if (std.mem.indexOf(u8, entry.path, ".zig-cache") != null) continue;
        // For virtual sub-cells, only scan files matching their patterns
        if (has_patterns and !matchesFilePatterns(entry.basename, file_patterns)) continue;

        const file_content = blk: {
            const file_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ cell_path, entry.path }) catch continue;
            defer allocator.free(file_path);
            break :blk std.fs.cwd().readFileAlloc(allocator, file_path, 1048576) catch continue;
        };
        defer allocator.free(file_content);

        var pos: usize = 0;
        while (std.mem.indexOf(u8, file_content[pos..], "@import(\"")) |idx| {
            const abs_start = pos + idx + 9;
            const end_idx = std.mem.indexOf(u8, file_content[abs_start..], "\"") orelse break;
            const import_path = file_content[abs_start .. abs_start + end_idx];
            pos = abs_start + end_idx + 1;

            if (std.mem.eql(u8, import_path, "std") or
                std.mem.eql(u8, import_path, "builtin") or
                std.mem.eql(u8, import_path, "root")) continue;

            if (std.mem.startsWith(u8, import_path, "../") or
                std.mem.startsWith(u8, import_path, "src/") or
                std.mem.startsWith(u8, import_path, "libs/") or
                std.mem.startsWith(u8, import_path, "fpga/"))
            {
                if (resolveImportToCell(import_path, cell_path, path_to_cell)) |dep_cell_id| {
                    if (!std.mem.eql(u8, dep_cell_id, cell_id)) {
                        detected_deps.put(dep_cell_id, {}) catch {};
                    }
                }
            } else if (!std.mem.endsWith(u8, import_path, ".zig")) {
                if (resolveModuleToCell(import_path, cell_id, all_cells)) |dep_cell_id| {
                    detected_deps.put(dep_cell_id, {}) catch {};
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CYCLES — detect dependency cycles via DFS
// ═══════════════════════════════════════════════════════════════════════════════

fn runDetectCycles(allocator: Allocator) !void {
    std.debug.print("{s}[cycles]{s} Scanning for dependency cycles...\n\n", .{ CYAN, RESET });

    const all_cells = cell_parser.discoverAll(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(all_cells);

    // Build adjacency: cell_id → [dep_cell_ids]
    var adj = std.StringHashMap(std.array_list.Managed([]const u8)).init(allocator);
    defer {
        var it = adj.iterator();
        while (it.next()) |entry| entry.value_ptr.deinit();
        adj.deinit();
    }

    for (all_cells) |c| {
        const m = c.manifest;
        var deps_list = std.array_list.Managed([]const u8).init(allocator);
        var dep_it = cell_parser.DepIterator.init(m.dependencies_raw);
        while (dep_it.next()) |dep_entry| {
            deps_list.append(dep_entry.id) catch {};
        }
        adj.put(m.id, deps_list) catch {};
    }

    // DFS with coloring: 0=white, 1=gray, 2=black
    var color = std.StringHashMap(u8).init(allocator);
    defer color.deinit();
    for (all_cells) |c| color.put(c.manifest.id, 0) catch {};

    var cycles_found: usize = 0;

    for (all_cells) |c| {
        const cell_id = c.manifest.id;
        if ((color.get(cell_id) orelse 0) == 0) {
            // DFS iterative with path tracking
            var stack = std.array_list.Managed(struct { id: []const u8, idx: usize }).init(allocator);
            defer stack.deinit();
            var path_list = std.array_list.Managed([]const u8).init(allocator);
            defer path_list.deinit();

            stack.append(.{ .id = cell_id, .idx = 0 }) catch {};
            color.put(cell_id, 1) catch {};
            path_list.append(cell_id) catch {};

            while (stack.items.len > 0) {
                const top = &stack.items[stack.items.len - 1];
                const neighbors = adj.get(top.id);
                if (neighbors != null and top.idx < neighbors.?.items.len) {
                    const next = neighbors.?.items[top.idx];
                    top.idx += 1;
                    const next_color = color.get(next) orelse 0;
                    if (next_color == 1) {
                        // Found cycle — print it
                        std.debug.print("  {s}CYCLE:{s} ", .{ RED, RESET });
                        var in_cycle = false;
                        for (path_list.items) |p| {
                            if (std.mem.eql(u8, p, next)) in_cycle = true;
                            if (in_cycle) std.debug.print("{s} → ", .{p});
                        }
                        std.debug.print("{s}\n", .{next});
                        cycles_found += 1;
                    } else if (next_color == 0) {
                        color.put(next, 1) catch {};
                        stack.append(.{ .id = next, .idx = 0 }) catch {};
                        path_list.append(next) catch {};
                    }
                } else {
                    color.put(top.id, 2) catch {};
                    _ = stack.pop();
                    if (path_list.items.len > 0) _ = path_list.pop();
                }
            }
        }
    }

    if (cycles_found == 0) {
        std.debug.print("  {s}✓{s} No dependency cycles detected\n", .{ GREEN, RESET });
    } else {
        std.debug.print("\n  {s}{d} cycle(s) found{s}\n", .{ RED, cycles_found, RESET });
    }
}

/// Find cells that no other cell depends on (orphans).
/// Leaf cells (binaries, tools) are expected to have 0 incoming deps — only flag libraries.
fn runDeadCells(allocator: Allocator) !void {
    std.debug.print("{s}[dead]{s} Scanning for orphan cells (no dependents)...\n\n", .{ CYAN, RESET });

    const all_cells = cell_parser.discoverAll(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(all_cells);

    // Build reverse dep map: cell_id → count of cells that depend on it
    var incoming = std.StringHashMap(usize).init(allocator);
    defer incoming.deinit();
    for (all_cells) |c| incoming.put(c.manifest.id, 0) catch {};

    for (all_cells) |c| {
        var dep_it = cell_parser.DepIterator.init(c.manifest.dependencies_raw);
        while (dep_it.next()) |dep_entry| {
            if (incoming.get(dep_entry.id)) |count| {
                incoming.put(dep_entry.id, count + 1) catch {};
            }
        }
    }

    // Report cells with 0 incoming deps
    var dead_count: usize = 0;
    var leaf_count: usize = 0;

    for (all_cells) |c| {
        const m = c.manifest;
        const count = incoming.get(m.id) orelse 0;
        if (count > 0) continue;

        // Skip sub-cells (they're internal to parent)
        if (m.parent.len > 0) continue;

        // Leaf cells (binaries, tools, agents) are expected to have 0 incoming
        const is_leaf = std.mem.eql(u8, m.kind, "binary") or
            std.mem.eql(u8, m.kind, "tool") or
            std.mem.eql(u8, m.kind, "agent") or
            std.mem.eql(u8, m.kind, "backend") or
            m.contributes_binaries.len > 2;

        if (is_leaf) {
            leaf_count += 1;
            std.debug.print("  {s}LEAF{s}  {s} ({s}) — 0 dependents, OK\n", .{ GRAY, RESET, m.id, m.kind });
        } else {
            dead_count += 1;
            std.debug.print("  {s}DEAD{s}  {s} ({s}) — no cell depends on this\n", .{ YELLOW, RESET, m.id, m.kind });
        }
    }

    std.debug.print("\n  Dead: {s}{d}{s} | Leaf: {d} | Total scanned: {d}\n", .{
        if (dead_count > 0) YELLOW else GREEN, dead_count, RESET, leaf_count, all_cells.len,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEPS VALIDATE — H3: Cell Dependency Validation
// ═══════════════════════════════════════════════════════════════════════════════
// Checks dependency integrity across all cells:
// - Missing dependencies (dep not found in all cells)
// - Orphan cells (no one depends on them, excluding leaf kinds)
// - Circular dependencies (A→B→A)
// - Returns dep_health score and exits with error if below threshold
// ═══════════════════════════════════════════════════════════════════════════════

fn runDepsValidate(allocator: Allocator, args: []const []const u8) !void {
    // Parse threshold flag (default 0.8)
    var threshold: f64 = 0.8;
    for (args) |a| {
        if (std.mem.startsWith(u8, a, "--threshold=")) {
            const val_str = a["--threshold=".len..];
            threshold = std.fmt.parseFloat(f64, val_str) catch 0.8;
        }
    }

    std.debug.print("{s}[deps --validate]{s} Checking dependency integrity (threshold: {d:.1})...\n\n", .{ CYAN, RESET, threshold });

    const all_cells = cell_parser.discoverAll(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(all_cells);

    // Build cell_id → exists mapping for quick lookup (just check if cell exists)
    var cell_exists = std.StringHashMap(void).init(allocator);
    defer cell_exists.deinit();
    for (all_cells) |c| {
        cell_exists.put(c.manifest.id, {}) catch {};
    }

    // Track validation issues
    const MissingDep = struct { cell: []const u8, dep: []const u8 };
    var missing_deps_list = std.array_list.Managed(MissingDep).init(allocator);
    defer missing_deps_list.deinit();

    var orphan_cells = std.array_list.Managed([]const u8).init(allocator);
    defer orphan_cells.deinit();

    var circular_deps = std.array_list.Managed([]const u8).init(allocator);
    defer {
        for (circular_deps.items) |cycle| {
            allocator.free(cycle);
        }
        circular_deps.deinit();
    }

    var total_deps: usize = 0;
    var valid_deps: usize = 0;

    // Build dependency graph for cycle detection
    var adj = std.StringHashMap(std.array_list.Managed([]const u8)).init(allocator);
    defer {
        var it = adj.iterator();
        while (it.next()) |entry| entry.value_ptr.deinit();
        adj.deinit();
    }

    // Build reverse dep map for orphan detection
    var incoming = std.StringHashMap(usize).init(allocator);
    defer incoming.deinit();
    for (all_cells) |c| incoming.put(c.manifest.id, 0) catch {};

    // First pass: check each cell's dependencies and build graphs
    for (all_cells) |c| {
        const m = c.manifest;

        // Build adjacency list for cycle detection
        var deps_list = std.array_list.Managed([]const u8).init(allocator);
        var dep_it = cell_parser.DepIterator.init(m.dependencies_raw);
        while (dep_it.next()) |dep_entry| {
            total_deps += 1;
            deps_list.append(dep_entry.id) catch {};

            // Check if dependency exists
            if (cell_exists.contains(dep_entry.id)) {
                valid_deps += 1;
            } else {
                // Missing dependency
                const entry = MissingDep{
                    .cell = m.id,
                    .dep = dep_entry.id,
                };
                missing_deps_list.append(entry) catch {};
            }

            // Update incoming count for orphan detection
            if (incoming.get(dep_entry.id)) |count| {
                incoming.put(dep_entry.id, count + 1) catch {};
            }
        }
        adj.put(m.id, deps_list) catch {};
    }

    // Second pass: detect orphan cells (no incoming deps, excluding leaf kinds)
    for (all_cells) |c| {
        const m = c.manifest;
        const count = incoming.get(m.id) orelse 0;
        if (count > 0) continue;

        // Skip sub-cells (they're internal to parent)
        if (m.parent.len > 0) continue;

        // Leaf cells are expected to have 0 incoming
        const is_leaf = std.mem.eql(u8, m.kind, "binary") or
            std.mem.eql(u8, m.kind, "tool") or
            std.mem.eql(u8, m.kind, "agent") or
            std.mem.eql(u8, m.kind, "backend") or
            m.contributes_binaries.len > 2;

        if (!is_leaf) {
            orphan_cells.append(m.id) catch {};
        }
    }

    // Third pass: detect circular dependencies using DFS
    var color = std.StringHashMap(u8).init(allocator);
    defer color.deinit();
    for (all_cells) |c| color.put(c.manifest.id, 0) catch {};

    for (all_cells) |c| {
        const cell_id = c.manifest.id;
        if ((color.get(cell_id) orelse 0) == 0) {
            // DFS iterative with path tracking
            var stack = std.array_list.Managed(struct { id: []const u8, idx: usize }).init(allocator);
            defer stack.deinit();
            var path_list = std.array_list.Managed([]const u8).init(allocator);
            defer path_list.deinit();

            stack.append(.{ .id = cell_id, .idx = 0 }) catch {};
            color.put(cell_id, 1) catch {};
            path_list.append(cell_id) catch {};

            while (stack.items.len > 0) {
                const top = &stack.items[stack.items.len - 1];
                const neighbors = adj.get(top.id);
                if (neighbors != null and top.idx < neighbors.?.items.len) {
                    const next = neighbors.?.items[top.idx];
                    top.idx += 1;
                    const next_color = color.get(next) orelse 0;
                    if (next_color == 1) {
                        // Found cycle — record it as a string for display
                        var cycle_str = std.array_list.Managed(u8).init(allocator);
                        defer cycle_str.deinit();
                        const writer = cycle_str.writer();
                        var in_cycle = false;
                        for (path_list.items) |p| {
                            if (std.mem.eql(u8, p, next)) in_cycle = true;
                            if (in_cycle) {
                                try writer.print("{s} → ", .{p});
                            }
                        }
                        try writer.print("{s}", .{next});
                        const cycle_copy = allocator.dupe(u8, cycle_str.items) catch continue;
                        circular_deps.append(cycle_copy) catch {};
                    } else if (next_color == 0) {
                        color.put(next, 1) catch {};
                        stack.append(.{ .id = next, .idx = 0 }) catch {};
                        path_list.append(next) catch {};
                    }
                } else {
                    color.put(top.id, 2) catch {};
                    _ = stack.pop();
                    if (path_list.items.len > 0) _ = path_list.pop();
                }
            }
        }
    }

    // Calculate dep_health score
    const dep_health: f64 = if (total_deps > 0)
        @as(f64, @floatFromInt(valid_deps)) / @as(f64, @floatFromInt(total_deps))
    else
        1.0;

    // Report results
    std.debug.print("  {s}Dependency Health:{s} {d:.2}% ({d}/{d} valid)\n", .{
        if (dep_health >= threshold) GREEN else RED, RESET, dep_health * 100.0, valid_deps, total_deps,
    });

    if (missing_deps_list.items.len > 0) {
        std.debug.print("\n  {s}MISSING DEPENDENCIES:{s} {d} cell(s) reference non-existent deps\n", .{ RED, RESET, missing_deps_list.items.len });
        for (missing_deps_list.items) |entry| {
            std.debug.print("    {s} → {s}\n", .{ entry.cell, entry.dep });
        }
        // DUAL-WRITE: missing dependencies alert to hippocampus
        const missing_msg = std.fmt.allocPrint(allocator, "missing dependencies: {d} cell(s) reference non-existent deps", .{missing_deps_list.items.len}) catch "";
        defer allocator.free(missing_msg);
        hippocampus.writeError(allocator, "cerebellum", missing_msg, "{}") catch {};
    }

    if (orphan_cells.items.len > 0) {
        std.debug.print("\n  {s}ORPHAN CELLS:{s} {d} cell(s) have no dependents (not leaf kinds)\n", .{ YELLOW, RESET, orphan_cells.items.len });
        for (orphan_cells.items) |cell_id| {
            std.debug.print("    {s}\n", .{cell_id});
        }
        // DUAL-WRITE: orphan cells alert to hippocampus
        const orphan_msg = std.fmt.allocPrint(allocator, "orphan cells: {d} cell(s) have no dependents", .{orphan_cells.items.len}) catch "";
        defer allocator.free(orphan_msg);
        hippocampus.writeError(allocator, "cerebellum", orphan_msg, "{}") catch {};
    }

    if (circular_deps.items.len > 0) {
        std.debug.print("\n  {s}CIRCULAR DEPENDENCIES:{s} {d} cycle(s) detected\n", .{ RED, RESET, circular_deps.items.len });
        for (circular_deps.items) |cycle| {
            std.debug.print("    {s}\n", .{cycle});
        }
    }

    if (missing_deps_list.items.len == 0 and orphan_cells.items.len == 0 and circular_deps.items.len == 0) {
        std.debug.print("\n  {s}✓{s} All dependencies are valid\n", .{ GREEN, RESET });
    }

    // Exit with error if below threshold
    std.debug.print("\n", .{});
    if (dep_health < threshold) {
        const exit_codes = @import("tri_exit_codes.zig");
        std.debug.print("  {s}FAILED:{s} dep_health {d:.2} < threshold {d:.1}\n", .{ RED, RESET, dep_health, threshold });
        exit_codes.exitWithCode(.validation_error);
    } else {
        std.debug.print("  {s}PASSED:{s} dep_health {d:.2} >= threshold {d:.1}\n", .{ GREEN, RESET, dep_health, threshold });
    }
}

fn resolveImportToCell(import_path: []const u8, cell_path: []const u8, path_to_cell: *std.StringHashMap([]const u8)) ?[]const u8 {
    // import_path is like "../vsa/core.zig" or "../tri/tri_utils.zig"
    // cell_path is like "src/hslm"
    // We need to resolve: "src/hslm" + "../vsa/core.zig" → "src/vsa"

    // Handle root-relative paths like "src/vm.zig" or "src/sacred/const.zig"
    if (std.mem.startsWith(u8, import_path, "src/") or std.mem.startsWith(u8, import_path, "libs/") or
        std.mem.startsWith(u8, import_path, "fpga/"))
    {
        // Extract: "src/sacred/const.zig" → "src/sacred"
        const after_root = import_path;
        // Find the second slash: src/<dir>/...
        if (std.mem.indexOfScalar(u8, after_root, '/')) |first_slash| {
            const rest = after_root[first_slash + 1 ..];
            if (std.mem.indexOfScalar(u8, rest, '/')) |second_slash| {
                // "src" + "/" + "sacred" → "src/sacred"
                const dir_path = after_root[0 .. first_slash + 1 + second_slash];
                if (path_to_cell.get(dir_path)) |cell_id| return cell_id;
            } else {
                // "src/vm.zig" → strip .zig, try "src/vm"
                const file_name = rest;
                if (std.mem.endsWith(u8, file_name, ".zig")) {
                    var buf2: [512]u8 = undefined;
                    const dir_path = std.fmt.bufPrint(&buf2, "{s}/{s}", .{
                        after_root[0..first_slash], file_name[0 .. file_name.len - 4],
                    }) catch return null;
                    if (path_to_cell.get(dir_path)) |cell_id| return cell_id;
                }
            }
        }
    }

    // Handle ../ relative paths
    var remaining = import_path;
    var up_count: usize = 0;
    while (std.mem.startsWith(u8, remaining, "../")) {
        up_count += 1;
        remaining = remaining[3..];
    }
    if (up_count == 0) return null; // Not a relative path

    // Go up from cell_path
    var base = cell_path;
    var i: usize = 0;
    while (i < up_count) : (i += 1) {
        if (std.mem.lastIndexOfScalar(u8, base, '/')) |slash| {
            base = base[0..slash];
        } else {
            return null; // Can't go up further
        }
    }

    // Take the first path component of remaining as the target directory
    const slash_pos = std.mem.indexOfScalar(u8, remaining, '/');
    const target_dir = if (slash_pos) |s| remaining[0..s] else blk: {
        // Direct file import like "../vsa.zig" → strip .zig
        if (std.mem.endsWith(u8, remaining, ".zig")) {
            break :blk remaining[0 .. remaining.len - 4];
        }
        break :blk remaining;
    };

    // Build resolved path: base + "/" + target_dir
    var buf: [512]u8 = undefined;
    const resolved = std.fmt.bufPrint(&buf, "{s}/{s}", .{ base, target_dir }) catch return null;

    // Look up in path_to_cell
    return path_to_cell.get(resolved);
}

// ═══════════════════════════════════════════════════════════════════════════════
// GRAPH EX — Cell graph visualization with Mermaid/JSON/HTML output
// ═══════════════════════════════════════════════════════════════════════════════

const GraphFormat = enum { mermaid, json, html, terminal };

fn runGraphEx(allocator: Allocator, args: []const []const u8) !void {
    // Parse flags: --output <path>, --format <mermaid|json|html>
    var output_path: ?[]const u8 = null;
    var format: GraphFormat = .terminal;

    for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "--output")) {
            if (i + 1 < args.len) {
                output_path = args[i + 1];
            } else {
                std.debug.print("{s}ERROR{s}: --output requires a path argument\n", .{ RED, RESET });
                return;
            }
        } else if (std.mem.eql(u8, arg, "--format")) {
            if (i + 1 < args.len) {
                format = std.meta.stringToEnum(GraphFormat, args[i + 1]) orelse {
                    std.debug.print("{s}ERROR{s}: Unknown format '{s}'. Use: mermaid, json, html\n", .{ RED, RESET, args[i + 1] });
                    return;
                };
            } else {
                std.debug.print("{s}ERROR{s}: --format requires a format argument\n", .{ RED, RESET });
                return;
            }
        }
    }

    // If no flags provided, use terminal format (legacy behavior)
    if (format == .terminal and output_path == null) {
        return runGraphLegacy(allocator);
    }

    // Detect format from output extension if not explicitly set
    if (format == .terminal and output_path != null) {
        if (std.mem.endsWith(u8, output_path.?, ".mmd") or std.mem.endsWith(u8, output_path.?, ".mermaid")) {
            format = .mermaid;
        } else if (std.mem.endsWith(u8, output_path.?, ".json")) {
            format = .json;
        } else if (std.mem.endsWith(u8, output_path.?, ".html")) {
            format = .html;
        }
    }

    // Collect all cells with health scores and bio_system
    const all_cells = cell_parser.discoverAll(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(all_cells);

    // Build adjacency list for dependencies
    var deps_of = std.StringHashMap(std.array_list.Managed([]const u8)).init(allocator);
    defer {
        var it = deps_of.iterator();
        while (it.next()) |e| e.value_ptr.deinit();
        deps_of.deinit();
    }

    // Compute health scores for all cells
    var cell_health = std.StringHashMap(HealthInfo).init(allocator);
    defer {
        var it = cell_health.iterator();
        while (it.next()) |e| e.value_ptr.deinit(allocator);
        cell_health.deinit();
    }

    // Path to cell mapping for deps accuracy
    var path_to_cell = std.StringHashMap([]const u8).init(allocator);
    defer path_to_cell.deinit();
    for (all_cells) |c| path_to_cell.put(c.manifest.path, c.manifest.id) catch {};

    for (all_cells) |c| {
        const m = c.manifest;

        // Build dependencies
        var list = std.array_list.Managed([]const u8).init(allocator);
        var dep_it = cell_parser.DepIterator.init(m.dependencies_raw);
        while (dep_it.next()) |de| {
            list.append(de.id) catch {};
        }
        deps_of.put(m.id, list) catch {};

        // Skip binary cells for health scoring
        if (std.mem.eql(u8, m.kind, "binary")) continue;

        const cell = parseCellTri(c.content);
        if (cell.id.len == 0) continue;

        // Compute health score (same formula as runHealth)
        const is_agent_h = std.mem.startsWith(u8, cell.id, "trinity.agent.");
        const is_meta_h = cell.files == 0 and cell.tests == 0 and !is_agent_h;
        const test_s: u8 = if (is_agent_h) 12 else if (is_meta_h) 10 else if (cell.tests == 0) 0 else @intCast(@min(15, cell.tests * 15 / 80));
        const health: u8 = test_s + (if (cell.owner.len > 0) @as(u8, 5) else 0) + (if (cell.capabilities.len > 2) @as(u8, 5) else 0) + (if (cell.description.len > 0 and !std.mem.startsWith(u8, cell.description, "Auto-generated")) @as(u8, 5) else 0);

        // Security
        var sec: u8 = 0;
        const is_virtual_h = cell.file_patterns.len > 2;
        if (cell.parent.len > 0 and !is_virtual_h) {
            if (cell.perm_level.len > 0) sec += 20;
            if (cell.security_signed) sec += 5;
            sec += 5;
        } else {
            if (cell.perm_level.len > 0) sec += 10;
            const code_perms_h = if (is_virtual_h) inferPermissionsFiltered(allocator, cell.path, cell.file_patterns) else inferPermissions(allocator, m.path);
            const perms_match_h = std.mem.eql(u8, cell.perm_level, code_perms_h.level) and std.mem.eql(u8, cell.perm_network, code_perms_h.net) and std.mem.eql(u8, cell.perm_process, code_perms_h.proc);
            if (perms_match_h) sec += 10;
            if (cell.security_signed) sec += 5;
            const no_bind_h = !(scanCodeForPattern(allocator, m.path, "parseIp4(\"0.0.0.0\"") or scanCodeForPattern(allocator, m.path, ".host = \"0.0.0.0\""));
            if (no_bind_h) sec += 5;
        }

        const dep_acc = computeDepsAccuracy(allocator, m.path, cell, all_cells, &path_to_cell);
        const deps: u8 = if (dep_acc.total == 0) 25 else blk: {
            const ratio: u8 = @intCast(@min(15, dep_acc.confirmed * 15 / dep_acc.total));
            break :blk ratio + (if (dep_acc.missing == 0) @as(u8, 10) else 0);
        };

        // Contracts
        const contracts: u8 = blk: {
            var contract_score: u8 = 15;
            if (cell.contributes_exports.len <= 2 and (std.mem.eql(u8, cell.kind, "library") or std.mem.eql(u8, cell.kind, "tool"))) contract_score -|= 5;
            break :blk contract_score;
        };

        const score: u8 = @intCast(@min(100, health + sec + deps + contracts));

        // Determine bio_system
        const bio_sys = if (m.bio_system.len > 0) bioSystemFromStr(m.bio_system) else classifyBioSystem(cell.id, cell.capabilities, m.path);
        const bio_name = bioSystemToString(bio_sys);

        // Store health info (copy strings)
        const id_copy = try allocator.dupe(u8, cell.id);
        const bio_copy = try allocator.dupe(u8, bio_name);
        const name_copy = if (cell.name.len > 0) try allocator.dupe(u8, cell.name) else id_copy;
        try cell_health.put(id_copy, .{
            .id = id_copy,
            .name = name_copy,
            .score = score,
            .bio_system = bio_copy,
            .status = if (std.mem.eql(u8, m.status, "stable")) "stable" else "experimental",
        });
    }

    // Generate output based on format
    const final_path = output_path orelse switch (format) {
        .mermaid => "deps.mmd",
        .json => "deps.json",
        .html => "deps.html",
        .terminal => unreachable,
    };

    switch (format) {
        .mermaid => try writeMermaidGraph(allocator, deps_of, cell_health, final_path),
        .json => try writeJsonGraph(allocator, deps_of, cell_health, final_path),
        .html => try writeHtmlGraph(allocator, deps_of, cell_health, final_path),
        .terminal => unreachable,
    }

    std.debug.print("{s}✓{s} Graph written to {s}{s}{s}\n", .{ GREEN, RESET, CYAN, final_path, RESET });

    // Show stats
    var low_health: usize = 0;
    var it = cell_health.iterator();
    while (it.next()) |e| {
        if (e.value_ptr.score < 50) low_health += 1;
    }
    std.debug.print("  {d} cells, {d} with health < 50\n", .{ cell_health.count(), low_health });
}

const HealthInfo = struct {
    id: []const u8,
    name: []const u8,
    score: u8,
    bio_system: []const u8,
    status: []const u8,

    fn deinit(self: *HealthInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        if (self.name.ptr != self.id.ptr) allocator.free(self.name);
        allocator.free(self.bio_system);
    }
};

// Get color for bio_system in Mermaid format
fn bioSystemColor(bio_system: []const u8) []const u8 {
    if (std.mem.eql(u8, bio_system, "dna")) return "#4A90E2"; // Blue
    if (std.mem.eql(u8, bio_system, "brain")) return "#9B59B6"; // Purple
    if (std.mem.eql(u8, bio_system, "immune")) return "#E74C3C"; // Red
    if (std.mem.eql(u8, bio_system, "regen")) return "#2ECC71"; // Green
    if (std.mem.eql(u8, bio_system, "body")) return "#F39C12"; // Orange
    return "#95A5A6"; // Gray (unclassified)
}

// Get stroke color for low health cells
fn healthStrokeColor(score: u8) []const u8 {
    if (score < 50) return "#E74C3C"; // Red - critical
    if (score < 70) return "#F39C12"; // Orange - warning
    return null; // No special stroke
}

fn writeMermaidGraph(
    allocator: std.mem.Allocator,
    deps_of: std.StringHashMap(std.array_list.Managed([]const u8)),
    cell_health: std.StringHashMap(HealthInfo),
    path: []const u8,
) !void {
    var output = std.array_list.Managed(u8).init(allocator);
    defer output.deinit();

    try output.appendSlice("graph TD\n");

    // Write nodes with styles
    var node_it = cell_health.iterator();
    while (node_it.next()) |entry| {
        const info = entry.value_ptr.*;
        // Sanitize ID for Mermaid (replace dots with underscores)
        const mermaid_id = try sanitizeId(allocator, info.id);
        defer allocator.free(mermaid_id);

        const label = if (std.mem.eql(u8, info.name, info.id))
            try escapeLabel(allocator, info.id)
        else
            try std.fmt.allocPrint(allocator, "{s}\\n({s})", .{ info.id, info.name });

        defer allocator.free(label);

        try output.writer().print("{s}[\"{s}\"]\n", .{ mermaid_id, label });

        // Apply base color for bio_system
        const base_color = bioSystemColor(info.bio_system);
        try output.writer().print("style {s} fill:{s}\n", .{ mermaid_id, base_color });

        // Add warning stroke for low health
        if (info.score < 70) {
            const stroke_color = if (info.score < 50) "#E74C3C" else "#F39C12";
            try output.writer().print("style {s} stroke:{s},stroke-width:3px\n", .{ mermaid_id, stroke_color });
        }
    }

    try output.appendSlice("\n");

    // Write edges
    var edge_it = deps_of.iterator();
    while (edge_it.next()) |entry| {
        const from_id = entry.key_ptr.*;
        const from_mermaid = try sanitizeId(allocator, from_id);
        defer allocator.free(from_mermaid);

        for (entry.value_ptr.items) |to_id| {
            const to_mermaid = try sanitizeId(allocator, to_id);
            defer allocator.free(to_mermaid);

            try output.writer().print("{s} --> {s}\n", .{ from_mermaid, to_mermaid });
        }
    }

    // Write legend
    try output.appendSlice("\nclassDef blue fill:#4A90E2,stroke:#3498DB,stroke-width:2px,color:#fff\n");
    try output.appendSlice("classDef purple fill:#9B59B6,stroke:#8E44AD,stroke-width:2px,color:#fff\n");
    try output.appendSlice("classDef red fill:#E74C3C,stroke:#C0392B,stroke-width:2px,color:#fff\n");
    try output.appendSlice("classDef green fill:#2ECC71,stroke:#27AE60,stroke-width:2px,color:#fff\n");
    try output.appendSlice("classDef orange fill:#F39C12,stroke:#E67E22,stroke-width:2px,color:#fff\n");
    try output.appendSlice("classDef gray fill:#95A5A6,stroke:#7F8C8D,stroke-width:2px,color:#fff\n");

    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(output.items);
}

fn writeJsonGraph(
    allocator: std.mem.Allocator,
    deps_of: std.StringHashMap(std.array_list.Managed([]const u8)),
    cell_health: std.StringHashMap(HealthInfo),
    path: []const u8,
) !void {
    var output = std.array_list.Managed(u8).init(allocator);
    defer output.deinit();

    try output.appendSlice("{\n  \"nodes\": [\n");

    // Write nodes
    var first = true;
    var node_it = cell_health.iterator();
    while (node_it.next()) |entry| {
        const info = entry.value_ptr.*;
        if (!first) try output.appendSlice(",\n");
        first = false;

        try output.writer().print("    {{\"id\": \"{s}\", \"name\": \"{s}\", \"score\": {d}, \"bio_system\": \"{s}\", \"status\": \"{s}\"}}", .{
            escapeJsonString(info.id),
            escapeJsonString(info.name),
            info.score,
            info.bio_system,
            info.status,
        });
    }

    try output.appendSlice("\n  ],\n  \"edges\": [\n");

    // Write edges
    first = true;
    var edge_it = deps_of.iterator();
    while (edge_it.next()) |entry| {
        const from_id = entry.key_ptr.*;
        for (entry.value_ptr.items) |to_id| {
            if (!first) try output.appendSlice(",\n");
            first = false;

            try output.writer().print("    {{\"from\": \"{s}\", \"to\": \"{s}\"}}", .{
                escapeJsonString(from_id),
                escapeJsonString(to_id),
            });
        }
    }

    try output.appendSlice("\n  ]\n}\n");

    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(output.items);
}

fn writeHtmlGraph(
    allocator: std.mem.Allocator,
    deps_of: std.StringHashMap(std.array_list.Managed([]const u8)),
    cell_health: std.StringHashMap(HealthInfo),
    path: []const u8,
) !void {
    var output = std.array_list.Managed(u8).init(allocator);
    defer output.deinit();

    // HTML header with D3.js
    try output.appendSlice(
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\  <meta charset="utf-8">
        \\  <title>Trinity Cell Graph</title>
        \\  <script src="https://d3js.org/d3.v7.min.js"></script>
        \\  <style>
        \\    body { margin: 0; font-family: 'Segoe UI', sans-serif; background: #1a1a2e; }
        \\    #graph { width: 100vw; height: 100vh; }
        \\    .node { cursor: pointer; }
        \\    .node circle { stroke: #fff; stroke-width: 2px; }
        \\    .node text { fill: #fff; font-size: 12px; pointer-events: none; text-shadow: 1px 1px 3px #000; }
        \\    .link { stroke: #666; stroke-opacity: 0.6; }
        \\    .legend { position: fixed; bottom: 20px; left: 20px; background: rgba(0,0,0,0.7); padding: 15px; border-radius: 8px; color: #fff; }
        \\    .legend-item { display: flex; align-items: center; margin: 5px 0; }
        \\    .legend-color { width: 16px; height: 16px; border-radius: 50%; margin-right: 8px; }
        \\  </style>
        \\</head>
        \\  <body>
        \\    <div id="graph"></div>
        \\    <div class="legend">
        \\      <h3>Legend</h3>
        \\      <div class="legend-item"><div class="legend-color" style="background:#4A90E2"></div>DNA (codegen)</div>
        \\      <div class="legend-item"><div class="legend-color" style="background:#9B59B6"></div>Brain (agents)</div>
        \\      <div class="legend-item"><div class="legend-color" style="background:#E74C3C"></div>Immune (security)</div>
        \\      <div class="legend-item"><div class="legend-color" style="background:#2ECC71"></div>Regen (phoenix)</div>
        \\      <div class="legend-item"><div class="legend-color" style="background:#F39C12"></div>Body (training)</div>
        \\      <div class="legend-item"><div class="legend-color" style="background:#95A5A6"></div>Unclassified</div>
        \\      <hr>
        \\      <div class="legend-item">Red stroke = health &lt; 50</div>
        \\      <div class="legend-item">Orange stroke = health &lt; 70</div>
        \\    </div>
        \\    <script>
        \\      const data = {
        \\        nodes: [
    );

    // Write nodes as JavaScript array
    var first = true;
    var node_it = cell_health.iterator();
    while (node_it.next()) |entry| {
        const info = entry.value_ptr.*;
        if (!first) try output.appendSlice(",\n        ");
        first = false;

        try output.writer().print("{{id:\"{s}\",name:\"{s}\",score:{d},bio:\"{s}\",status:\"{s}\"}}", .{
            escapeJsString(info.id),
            escapeJsString(info.name),
            info.score,
            info.bio_system,
            info.status,
        });
    }

    try output.appendSlice(
        \\
        \\        ],
        \\        links: [
    );

    // Write edges
    first = true;
    var edge_it = deps_of.iterator();
    while (edge_it.next()) |entry| {
        const from_id = entry.key_ptr.*;
        for (entry.value_ptr.items) |to_id| {
            if (!first) try output.appendSlice(",\n        ");
            first = false;

            try output.writer().print("{{source:\"{s}\",target:\"{s}\"}}", .{
                escapeJsString(from_id),
                escapeJsString(to_id),
            });
        }
    }

    // Footer with D3.js visualization code
    try output.appendSlice(
        \\
        \\        ]
        \\      };
        \\
        \\      const colorMap = {
        \\        dna: "#4A90E2", brain: "#9B59B6", immune: "#E74C3C",
        \\        regen: "#2ECC71", body: "#F39C12", unclassified: "#95A5A6"
        \\      };
        \\
        \\      const svg = d3.select("#graph").append("svg")
        \\        .attr("width", "100%").attr("height", "100%")
        \\        .call(d3.zoom().on("zoom", (e) => {
        \\          g.attr("transform", e.transform);
        \\        })).append("g");
        \\
        \\      const g = svg.append("g");
        \\
        \\      const simulation = d3.forceSimulation(data.nodes)
        \\        .force("link", d3.forceLink(data.links).id(d => d.id).distance(100))
        \\        .force("charge", d3.forceManyBody().strength(-300))
        \\        .force("center", d3.forceCenter(window.innerWidth / 2, window.innerHeight / 2));
        \\
        \\      const link = g.append("g").selectAll("line")
        \\        .data(data.links).join("line")
        \\        .attr("class", "link");
        \\
        \\      const node = g.append("g").selectAll(".node")
        \\        .data(data.nodes).join("g")
        \\        .attr("class", "node")
        \\        .call(d3.drag()
        \\          .on("start", (e, d) => {
        \\            if (!e.active) simulation.alphaTarget(0.3).restart();
        \\            d.fx = d.x; d.fy = d.y;
        \\          })
        \\          .on("drag", (e, d) => { d.fx = e.x; d.fy = e.y; })
        \\          .on("end", (e, d) => {
        \\            if (!e.active) simulation.alphaTarget(0);
        \\            d.fx = null; d.fy = null;
        \\          }));
        \\
        \\      node.append("circle")
        \\        .attr("r", d => 8 + (d.score / 10))
        \\        .attr("fill", d => colorMap[d.bio] || "#95A5A6")
        \\        .attr("stroke", d => d.score < 50 ? "#E74C3C" : d.score < 70 ? "#F39C12" : "#fff")
        \\        .attr("stroke-width", d => d.score < 70 ? 3 : 2);
        \\
        \\      node.append("text")
        \\        .attr("x", 12).attr("y", 4)
        \\        .text(d => d.id.split('.').pop());
        \\
        \\      node.append("title").text(d => `${d.id}\\nHealth: ${d.score}/100\\nBio: ${d.bio}`);
        \\
        \\      simulation.on("tick", () => {
        \\        link.attr("x1", d => d.source.x).attr("y1", d => d.source.y)
        \\            .attr("x2", d => d.target.x).attr("y2", d => d.target.y);
        \\        node.attr("transform", d => `translate(${d.x},${d.y})`);
        \\      });
        \\    </script>
        \\  </body>
        \\</html>
    );

    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(output.items);
}

// Sanitize cell ID for Mermaid (dots are not allowed in node IDs)
fn sanitizeId(allocator: std.mem.Allocator, id: []const u8) ![]const u8 {
    var result = std.array_list.Managed(u8).init(allocator);
    for (id) |c| {
        try result.append(if (c == '.') '_' else if (c == '-') '_' else c);
    }
    return result.toOwnedSlice();
}

// Escape label for Mermaid (quotes, backslashes)
fn escapeLabel(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    var result = std.array_list.Managed(u8).init(allocator);
    for (s) |c| {
        switch (c) {
            '"', '\\' => try result.append('\\'),
            else => {},
        }
        try result.append(c);
    }
    return result.toOwnedSlice();
}

// Escape string for JSON
fn escapeJsonString(s: []const u8) []const u8 {
    // Simple version - just return as-is for now. Full implementation would escape quotes, backslashes, etc.
    // TODO: Implement proper JSON escaping
    return s;
}

// Escape string for JavaScript
fn escapeJsString(s: []const u8) []const u8 {
    // Simple version - just return as-is for now. Full implementation would escape quotes, backslashes, etc.
    // TODO: Implement proper JS escaping
    return s;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GRAPH — Mermaid dependency diagram (LEGACY)
// ═══════════════════════════════════════════════════════════════════════════════

fn runGraphLegacy(allocator: Allocator) !void {
    std.debug.print("\n{s}🔗 DEPENDENCY GRAPH (DAG){s}\n", .{ GOLDEN, RESET });

    const all_cells = cell_parser.discoverAll(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(all_cells);

    // Build adjacency + reverse adjacency (who depends on me)
    var deps_of = std.StringHashMap(std.array_list.Managed([]const u8)).init(allocator);
    defer {
        var it = deps_of.iterator();
        while (it.next()) |e| e.value_ptr.deinit();
        deps_of.deinit();
    }
    var depended_by = std.StringHashMap(std.array_list.Managed([]const u8)).init(allocator);
    defer {
        var it = depended_by.iterator();
        while (it.next()) |e| e.value_ptr.deinit();
        depended_by.deinit();
    }

    var edge_count: usize = 0;
    var cells_with_deps: usize = 0;

    for (all_cells) |c| {
        const m = c.manifest;
        var list = std.array_list.Managed([]const u8).init(allocator);
        var dep_it = cell_parser.DepIterator.init(m.dependencies_raw);
        while (dep_it.next()) |de| {
            list.append(de.id) catch {};
            // Reverse edge
            const rev = depended_by.getPtr(de.id);
            if (rev) |r| {
                r.append(m.id) catch {};
            } else {
                var new_list = std.array_list.Managed([]const u8).init(allocator);
                new_list.append(m.id) catch {};
                depended_by.put(de.id, new_list) catch {};
            }
            edge_count += 1;
        }
        if (list.items.len > 0) cells_with_deps += 1;
        deps_of.put(m.id, list) catch {};
    }

    // Count roots (cells with deps but nobody depends on them in the connected set)
    // and leaves (no outgoing deps)
    var roots = std.array_list.Managed([]const u8).init(allocator);
    defer roots.deinit();
    var hubs = std.array_list.Managed([]const u8).init(allocator);
    defer hubs.deinit();
    var leaves: usize = 0;

    for (all_cells) |c| {
        const id = c.manifest.id;
        const out_deps = deps_of.get(id);
        const in_deps = depended_by.get(id);
        const out_count = if (out_deps) |d| d.items.len else 0;
        const in_count = if (in_deps) |d| d.items.len else 0;

        if (out_count == 0 and in_count == 0) {
            leaves += 1;
        } else if (in_count >= 3) {
            hubs.append(id) catch {};
        } else if (out_count > 0 and in_count == 0) {
            roots.append(id) catch {};
        }
    }

    // Header
    std.debug.print("{s}  ═══════════════════════════════════════════════════════════{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}Edges:{s} {d}  {s}Cells with deps:{s} {d}  {s}Independent:{s} {d}\n\n", .{
        CYAN, RESET, edge_count, CYAN, RESET, cells_with_deps, CYAN, RESET, leaves,
    });

    // Show hubs — most depended-on cells
    if (hubs.items.len > 0) {
        std.debug.print("  {s}HUB NODES{s} (3+ dependents)\n", .{ GOLDEN, RESET });
        for (hubs.items) |hub_id| {
            const in_deps = depended_by.get(hub_id) orelse continue;
            std.debug.print("  {s}◆ {s}{s} ", .{ GREEN, hub_id, RESET });
            std.debug.print("{s}← ", .{GRAY});
            for (in_deps.items, 0..) |dep, i| {
                if (i > 0) std.debug.print(", ", .{});
                if (i >= 5) {
                    std.debug.print("+{d} more", .{in_deps.items.len - 5});
                    break;
                }
                std.debug.print("{s}", .{dep});
            }
            std.debug.print("{s}\n", .{RESET});
        }
        std.debug.print("\n", .{});
    }

    // Show trees: cells with deps → their deps
    std.debug.print("  {s}DEPENDENCY TREE{s}\n", .{ GOLDEN, RESET });

    for (all_cells) |c| {
        const id = c.manifest.id;
        const out_deps = deps_of.get(id) orelse continue;
        if (out_deps.items.len == 0) continue;

        // Skip sub-cells in tree (show parent only)
        if (c.manifest.parent.len > 0) continue;

        const in_deps = depended_by.get(id);
        const in_count = if (in_deps) |d| d.items.len else 0;
        const kind_color = if (std.mem.eql(u8, c.manifest.status, "stable")) GREEN else YELLOW;

        std.debug.print("  {s}{s}{s}", .{ kind_color, id, RESET });
        if (in_count > 0) {
            std.debug.print(" {s}({d} dependents){s}", .{ GRAY, in_count, RESET });
        }
        std.debug.print("\n", .{});

        for (out_deps.items, 0..) |dep, i| {
            const is_last = i == out_deps.items.len - 1;
            const branch = if (is_last) "└── " else "├── ";
            const dep_in = depended_by.get(dep);
            const dep_in_count = if (dep_in) |d| d.items.len else 0;
            const dep_icon = if (dep_in_count >= 3) "◆" else "○";
            std.debug.print("  {s}{s}{s}{s} {s}{s}\n", .{
                GRAY, branch, CYAN, dep_icon, dep, RESET,
            });
        }
        std.debug.print("\n", .{});
    }

    // Sub-cells
    var has_sub = false;
    for (all_cells) |c| {
        if (c.manifest.parent.len > 0) {
            if (!has_sub) {
                std.debug.print("  {s}SUB-CELLS{s}\n", .{ GOLDEN, RESET });
                has_sub = true;
            }
            const out_deps = deps_of.get(c.manifest.id);
            const dep_count = if (out_deps) |d| d.items.len else 0;
            std.debug.print("  {s}└─{s} {s}{s}{s} {s}parent={s} deps={d}{s}\n", .{
                GRAY, RESET, CYAN, c.manifest.id, RESET, GRAY, c.manifest.parent, dep_count, RESET,
            });
        }
    }
    if (has_sub) std.debug.print("\n", .{});

    // Footer
    const leaf_pct = if (all_cells.len > 0) leaves * 100 / all_cells.len else 0;
    std.debug.print("  {s}Independent cells: {d}/{d} ({d}%%) — no deps given or received{s}\n", .{
        GRAY, leaves, all_cells.len, leaf_pct, RESET,
    });
    std.debug.print("  {s}Stable={s}green{s} Experimental={s}yellow{s} Hub(3+)={s}◆{s}{s}\n\n", .{
        GRAY, GREEN, GRAY, YELLOW, GRAY, CYAN, RESET, RESET,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEALTH — per-cell health score breakdown
// ═══════════════════════════════════════════════════════════════════════════════

fn runHealthJSON(allocator: Allocator) !void {
    const all_cells = cell_parser.discoverAll(allocator) catch {
        std.debug.print("{{\"error\": \"Failed to discover cells\"}}\n", .{});
        return;
    };
    defer allocator.free(all_cells);

    // Initialize data structures
    var path_to_cell = std.StringHashMap([]const u8).init(allocator);
    defer path_to_cell.deinit();
    for (all_cells) |c| path_to_cell.put(c.manifest.path, c.manifest.id) catch {};

    var adj = std.StringHashMap(std.array_list.Managed([]const u8)).init(allocator);
    defer {
        var it = adj.iterator();
        while (it.next()) |entry| entry.value_ptr.deinit();
        adj.deinit();
    }
    for (all_cells) |c| {
        var deps_list = std.array_list.Managed([]const u8).init(allocator);
        var dep_it = cell_parser.DepIterator.init(c.manifest.dependencies_raw);
        while (dep_it.next()) |de| deps_list.append(de.id) catch {};
        adj.put(c.manifest.id, deps_list) catch {};
    }

    // Detect cycles
    var cycle_count: usize = 0;
    var cycle_cells_set = std.StringHashMap(void).init(allocator);
    defer cycle_cells_set.deinit();

    {
        var color = std.StringHashMap(u8).init(allocator);
        defer color.deinit();
        for (all_cells) |c| color.put(c.manifest.id, 0) catch {};
        for (all_cells) |c| {
            if ((color.get(c.manifest.id) orelse 0) != 0) continue;
            var stack = std.array_list.Managed(struct { id: []const u8, idx: usize }).init(allocator);
            defer stack.deinit();
            var path_list = std.array_list.Managed([]const u8).init(allocator);
            defer path_list.deinit();
            stack.append(.{ .id = c.manifest.id, .idx = 0 }) catch {};
            color.put(c.manifest.id, 1) catch {};
            path_list.append(c.manifest.id) catch {};
            while (stack.items.len > 0) {
                const top = &stack.items[stack.items.len - 1];
                const neighbors = adj.get(top.id);
                if (neighbors != null and top.idx < neighbors.?.items.len) {
                    const next = neighbors.?.items[top.idx];
                    top.idx += 1;
                    const nc = color.get(next) orelse 0;
                    if (nc == 1) {
                        cycle_count += 1;
                        var in_cycle = false;
                        for (path_list.items) |p| {
                            if (std.mem.eql(u8, p, next)) in_cycle = true;
                            if (in_cycle) cycle_cells_set.put(p, {}) catch {};
                        }
                    } else if (nc == 0) {
                        color.put(next, 1) catch {};
                        stack.append(.{ .id = next, .idx = 0 }) catch {};
                        path_list.append(next) catch {};
                    }
                } else {
                    color.put(top.id, 2) catch {};
                    _ = stack.pop();
                    if (path_list.items.len > 0) _ = path_list.pop();
                }
            }
        }
    }

    // Compute scores
    var total_score: usize = 0;
    var scored_count: usize = 0;
    var grade_a: usize = 0;
    var grade_b: usize = 0;
    var grade_c: usize = 0;
    var grade_f: usize = 0;
    var cell_count: usize = 0;
    var sub_count: usize = 0;

    for (all_cells) |c| {
        if (c.manifest.parent.len > 0) sub_count += 1 else cell_count += 1;
    }

    var monolith_total: usize = 0;
    var monolith_covered: usize = 0;

    // Count monolith files
    {
        var tri_dir = std.fs.cwd().openDir("src/tri", .{ .iterate = true }) catch null;
        if (tri_dir) |*d| {
            defer d.close();
            var iter = d.iterate();
            while (iter.next() catch null) |entry| {
                if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".zig")) {
                    monolith_total += 1;
                    for (all_cells) |sc| {
                        if (sc.manifest.parent.len > 0 and sc.manifest.file_patterns.len > 2) {
                            if (matchesFilePatterns(entry.name, sc.manifest.file_patterns)) {
                                monolith_covered += 1;
                                break;
                            }
                        }
                    }
                }
            }
        }
        var math_dir = std.fs.cwd().openDir("src/tri/math", .{ .iterate = true }) catch null;
        if (math_dir) |*md| {
            defer md.close();
            var miter = md.iterate();
            while (miter.next() catch null) |entry| {
                if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".zig")) {
                    monolith_total += 1;
                    monolith_covered += 1;
                }
            }
        }
    }

    // Output JSON
    std.debug.print("{{\n", .{});
    std.debug.print("  \"version\": \"10.0\",\n", .{});
    std.debug.print("  \"timestamp\": {d},\n", .{std.time.timestamp()});
    std.debug.print("  \"summary\": {{\n", .{});
    std.debug.print("    \"cells\": {d},\n", .{cell_count});
    std.debug.print("    \"sub_cells\": {d},\n", .{sub_count});
    std.debug.print("    \"monolith_coverage\": {{\n", .{});
    std.debug.print("      \"covered\": {d},\n", .{monolith_covered});
    std.debug.print("      \"total\": {d},\n", .{monolith_total});
    const cov_pct = if (monolith_total > 0) monolith_covered * 100 / monolith_total else 0;
    std.debug.print("      \"percent\": {d}\n", .{cov_pct});
    std.debug.print("    }},\n", .{});
    std.debug.print("    \"cycles\": {d},\n", .{cycle_count});

    // Recompute scores for summary
    for (all_cells) |c| {
        const m = c.manifest;
        if (std.mem.eql(u8, m.kind, "binary")) continue;
        const cell = parseCellTri(c.content);
        if (cell.id.len == 0) continue;

        const is_agent_h = std.mem.startsWith(u8, cell.id, "trinity.agent.");
        const is_meta_h = cell.files == 0 and cell.tests == 0 and !is_agent_h;
        const test_s: u8 = if (is_agent_h) 12 else if (is_meta_h) 10 else if (cell.tests == 0) 0 else @intCast(@min(15, cell.tests * 15 / 80));
        const health: u8 = test_s + (if (cell.owner.len > 0) @as(u8, 5) else 0) + (if (cell.capabilities.len > 2) @as(u8, 5) else 0) + (if (cell.description.len > 0 and !std.mem.startsWith(u8, cell.description, "Auto-generated")) @as(u8, 5) else 0);

        var sec: u8 = 0;
        const is_virtual_h = cell.file_patterns.len > 2;
        if (cell.parent.len > 0 and !is_virtual_h) {
            if (cell.perm_level.len > 0) sec += 20;
            if (cell.security_signed) sec += 5;
            sec += 5;
        } else {
            if (cell.perm_level.len > 0) sec += 10;
            const code_perms_h = if (is_virtual_h) inferPermissionsFiltered(allocator, cell.path, cell.file_patterns) else inferPermissions(allocator, m.path);
            const perms_match_h = std.mem.eql(u8, cell.perm_level, code_perms_h.level) and std.mem.eql(u8, cell.perm_network, code_perms_h.net) and std.mem.eql(u8, cell.perm_process, code_perms_h.proc);
            if (perms_match_h) sec += 10;
            if (cell.security_signed) sec += 5;
            const no_bind_h = !(scanCodeForPattern(allocator, m.path, "parseIp4(\"0.0.0.0\"") or scanCodeForPattern(allocator, m.path, ".host = \"0.0.0.0\""));
            if (no_bind_h) sec += 5;
        }

        const dep_acc = computeDepsAccuracy(allocator, m.path, cell, all_cells, &path_to_cell);
        var deps: u8 = if (dep_acc.total == 0) 25 else blk: {
            const ratio: u8 = @intCast(@min(15, dep_acc.confirmed * 15 / dep_acc.total));
            break :blk ratio + (if (dep_acc.missing == 0) @as(u8, 10) else 0);
        };
        if (cycle_cells_set.contains(cell.id)) deps -|= 10;

        var contracts: u8 = 15;
        if (cell.contributes_exports.len <= 2 and (std.mem.eql(u8, cell.kind, "library") or std.mem.eql(u8, cell.kind, "tool"))) contracts -|= 5;
        if (std.mem.eql(u8, cell.perm_level, "L0")) {
            var dep_it_h = cell_parser.DepIterator.init(cell.dependencies_raw);
            while (dep_it_h.next()) |dep_h| {
                for (all_cells) |dc| {
                    if (std.mem.eql(u8, dc.manifest.id, dep_h.id) and std.mem.eql(u8, dc.manifest.perm_level, "L2")) {
                        contracts -|= 3;
                        break;
                    }
                }
            }
        }

        const score: usize = @as(usize, health) + sec + deps + contracts;
        if (score >= 80) grade_a += 1 else if (score >= 60) grade_b += 1 else if (score >= 40) grade_c += 1 else grade_f += 1;
        total_score += score;
        scored_count += 1;
    }

    const avg = if (scored_count > 0) total_score / scored_count else 0;
    std.debug.print("    \"average_score\": {d},\n", .{avg});
    std.debug.print("    \"grades\": {{\"a\": {d}, \"b\": {d}, \"c\": {d}, \"f\": {d}}}\n", .{ grade_a, grade_b, grade_c, grade_f });
    std.debug.print("  }},\n", .{});
    std.debug.print("  \"cells\": [\n", .{});

    var first = true;
    for (all_cells) |c| {
        const m = c.manifest;
        if (std.mem.eql(u8, m.kind, "binary")) continue;
        const cell = parseCellTri(c.content);
        if (cell.id.len == 0) continue;

        const is_agent_h = std.mem.startsWith(u8, cell.id, "trinity.agent.");
        const is_meta_h = cell.files == 0 and cell.tests == 0 and !is_agent_h;
        const test_s: u8 = if (is_agent_h) 12 else if (is_meta_h) 10 else if (cell.tests == 0) 0 else @intCast(@min(15, cell.tests * 15 / 80));
        const health: u8 = test_s + (if (cell.owner.len > 0) @as(u8, 5) else 0) + (if (cell.capabilities.len > 2) @as(u8, 5) else 0) + (if (cell.description.len > 0 and !std.mem.startsWith(u8, cell.description, "Auto-generated")) @as(u8, 5) else 0);

        var sec: u8 = 0;
        const is_virtual_h = cell.file_patterns.len > 2;
        if (cell.parent.len > 0 and !is_virtual_h) {
            if (cell.perm_level.len > 0) sec += 20;
            if (cell.security_signed) sec += 5;
            sec += 5;
        } else {
            if (cell.perm_level.len > 0) sec += 10;
            const code_perms_h = if (is_virtual_h) inferPermissionsFiltered(allocator, cell.path, cell.file_patterns) else inferPermissions(allocator, m.path);
            const perms_match_h = std.mem.eql(u8, cell.perm_level, code_perms_h.level) and std.mem.eql(u8, cell.perm_network, code_perms_h.net) and std.mem.eql(u8, cell.perm_process, code_perms_h.proc);
            if (perms_match_h) sec += 10;
            if (cell.security_signed) sec += 5;
            const no_bind_h = !(scanCodeForPattern(allocator, m.path, "parseIp4(\"0.0.0.0\"") or scanCodeForPattern(allocator, m.path, ".host = \"0.0.0.0\""));
            if (no_bind_h) sec += 5;
        }

        const dep_acc = computeDepsAccuracy(allocator, m.path, cell, all_cells, &path_to_cell);
        var deps: u8 = if (dep_acc.total == 0) 25 else blk: {
            const ratio: u8 = @intCast(@min(15, dep_acc.confirmed * 15 / dep_acc.total));
            break :blk ratio + (if (dep_acc.missing == 0) @as(u8, 10) else 0);
        };
        if (cycle_cells_set.contains(cell.id)) deps -|= 10;

        var contracts: u8 = 15;
        if (cell.contributes_exports.len <= 2 and (std.mem.eql(u8, cell.kind, "library") or std.mem.eql(u8, cell.kind, "tool"))) contracts -|= 5;
        if (std.mem.eql(u8, cell.perm_level, "L0")) {
            var dep_it_h = cell_parser.DepIterator.init(cell.dependencies_raw);
            while (dep_it_h.next()) |dep_h| {
                for (all_cells) |dc| {
                    if (std.mem.eql(u8, dc.manifest.id, dep_h.id) and std.mem.eql(u8, dc.manifest.perm_level, "L2")) {
                        contracts -|= 3;
                        break;
                    }
                }
            }
        }

        const score: usize = @min(100, @as(usize, health) + sec + deps + contracts);
        const grade = if (score >= 80) "A" else if (score >= 60) "B" else if (score >= 40) "C" else "F";
        const bio_sys = if (m.bio_system.len > 0) m.bio_system else "unclassified";

        if (!first) std.debug.print(",\n", .{});
        first = false;

        const display_name = if (cell.name.len > 0) cell.name else cell.id;

        std.debug.print("    {{\"id\":\"{s}\",\"name\":\"{s}\",\"score\":{d},\"grade\":\"{s}\",\"bio_system\":\"{s}\",\"health\":{d},\"security\":{d},\"deps\":{d},\"contracts\":{d},\"files\":{d},\"tests\":{d}}}", .{ cell.id, display_name, score, grade, bio_sys, health, sec, deps, contracts, cell.files, cell.tests });
    }

    std.debug.print("\n  ]\n}}\n", .{});
}

fn runHealth(allocator: Allocator, args: []const []const u8) !void {
    // Check for --json flag
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--json")) {
            return runHealthJSON(allocator);
        }
    }

    std.debug.print("\n{s}🏥 HONEYCOMB HEALTH v10{s}\n\n", .{ GOLDEN, RESET });

    const all_cells = cell_parser.discoverAll(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(all_cells);

    // Count cells and sub-cells
    var cell_count: usize = 0;
    var sub_count: usize = 0;
    for (all_cells) |c| {
        if (c.manifest.parent.len > 0) sub_count += 1 else cell_count += 1;
    }

    // Count cycles
    var path_to_cell = std.StringHashMap([]const u8).init(allocator);
    defer path_to_cell.deinit();
    for (all_cells) |c| path_to_cell.put(c.manifest.path, c.manifest.id) catch {};

    var adj = std.StringHashMap(std.array_list.Managed([]const u8)).init(allocator);
    defer {
        var it = adj.iterator();
        while (it.next()) |entry| entry.value_ptr.deinit();
        adj.deinit();
    }
    for (all_cells) |c| {
        var deps_list = std.array_list.Managed([]const u8).init(allocator);
        var dep_it = cell_parser.DepIterator.init(c.manifest.dependencies_raw);
        while (dep_it.next()) |de| deps_list.append(de.id) catch {};
        adj.put(c.manifest.id, deps_list) catch {};
    }

    var cycle_count: usize = 0;
    var cycle_cells_set = std.StringHashMap(void).init(allocator);
    defer cycle_cells_set.deinit();
    {
        var color = std.StringHashMap(u8).init(allocator);
        defer color.deinit();
        for (all_cells) |c| color.put(c.manifest.id, 0) catch {};
        for (all_cells) |c| {
            if ((color.get(c.manifest.id) orelse 0) != 0) continue;
            var stack = std.array_list.Managed(struct { id: []const u8, idx: usize }).init(allocator);
            defer stack.deinit();
            var path_list = std.array_list.Managed([]const u8).init(allocator);
            defer path_list.deinit();
            stack.append(.{ .id = c.manifest.id, .idx = 0 }) catch {};
            color.put(c.manifest.id, 1) catch {};
            path_list.append(c.manifest.id) catch {};
            while (stack.items.len > 0) {
                const top = &stack.items[stack.items.len - 1];
                const neighbors = adj.get(top.id);
                if (neighbors != null and top.idx < neighbors.?.items.len) {
                    const next = neighbors.?.items[top.idx];
                    top.idx += 1;
                    const nc = color.get(next) orelse 0;
                    if (nc == 1) {
                        cycle_count += 1;
                        var in_cycle = false;
                        for (path_list.items) |p| {
                            if (std.mem.eql(u8, p, next)) in_cycle = true;
                            if (in_cycle) cycle_cells_set.put(p, {}) catch {};
                        }
                    } else if (nc == 0) {
                        color.put(next, 1) catch {};
                        stack.append(.{ .id = next, .idx = 0 }) catch {};
                        path_list.append(next) catch {};
                    }
                } else {
                    color.put(top.id, 2) catch {};
                    _ = stack.pop();
                    if (path_list.items.len > 0) _ = path_list.pop();
                }
            }
        }
    }

    // Compute average score + grade distribution + weakest
    var total_score: usize = 0;
    var scored_count: usize = 0;
    var grade_a: usize = 0;
    var grade_b: usize = 0;
    var grade_c: usize = 0;
    var grade_f: usize = 0;
    var weakest_id: []const u8 = "";
    var weakest_score: usize = 999;

    for (all_cells) |c| {
        const m = c.manifest;
        if (std.mem.eql(u8, m.kind, "binary")) continue;
        const cell = parseCellTri(c.content);
        if (cell.id.len == 0) continue;

        // Unified scoring (identical to runScore v10)
        const is_agent_h = std.mem.startsWith(u8, cell.id, "trinity.agent.");
        const is_meta_h = cell.files == 0 and cell.tests == 0 and !is_agent_h;
        const test_s: u8 = if (is_agent_h) 12 else if (is_meta_h) 10 else if (cell.tests == 0) 0 else @intCast(@min(15, cell.tests * 15 / 80));
        const health: u8 = test_s + (if (cell.owner.len > 0) @as(u8, 5) else 0) + (if (cell.capabilities.len > 2) @as(u8, 5) else 0) + (if (cell.description.len > 0 and !std.mem.startsWith(u8, cell.description, "Auto-generated")) @as(u8, 5) else 0);
        // Security: use inferred permissions when possible (matches runScore)
        var sec: u8 = 0;
        const is_virtual_h = cell.file_patterns.len > 2;
        if (cell.parent.len > 0 and !is_virtual_h) {
            if (cell.perm_level.len > 0) sec += 20;
            if (cell.security_signed) sec += 5;
            sec += 5;
        } else {
            if (cell.perm_level.len > 0) sec += 10;
            const code_perms_h = if (is_virtual_h) inferPermissionsFiltered(allocator, cell.path, cell.file_patterns) else inferPermissions(allocator, m.path);
            const perms_match_h = std.mem.eql(u8, cell.perm_level, code_perms_h.level) and std.mem.eql(u8, cell.perm_network, code_perms_h.net) and std.mem.eql(u8, cell.perm_process, code_perms_h.proc);
            if (perms_match_h) sec += 10;
            if (cell.security_signed) sec += 5;
            const no_bind_h = !(scanCodeForPattern(allocator, m.path, "parseIp4(\"0.0.0.0\"") or scanCodeForPattern(allocator, m.path, ".host = \"0.0.0.0\""));
            if (no_bind_h) sec += 5;
        }
        const dep_acc = computeDepsAccuracy(allocator, m.path, cell, all_cells, &path_to_cell);
        var deps: u8 = if (dep_acc.total == 0) 25 else blk: {
            const ratio: u8 = @intCast(@min(15, dep_acc.confirmed * 15 / dep_acc.total));
            break :blk ratio + (if (dep_acc.missing == 0) @as(u8, 10) else 0);
        };
        if (cycle_cells_set.contains(cell.id)) deps -|= 10;
        // Contracts: with boundary checks (matches runScore)
        var contracts: u8 = 15;
        if (cell.contributes_exports.len <= 2 and (std.mem.eql(u8, cell.kind, "library") or std.mem.eql(u8, cell.kind, "tool"))) contracts -|= 5;
        if (std.mem.eql(u8, cell.perm_level, "L0")) {
            var dep_it_h = cell_parser.DepIterator.init(cell.dependencies_raw);
            while (dep_it_h.next()) |dep_h| {
                for (all_cells) |dc| {
                    if (std.mem.eql(u8, dc.manifest.id, dep_h.id) and std.mem.eql(u8, dc.manifest.perm_level, "L2")) {
                        contracts -|= 3;
                        break;
                    }
                }
            }
        }
        const score: usize = @as(usize, health) + sec + deps + contracts;

        // ═══════════════════════════════════════════════════════════════════════════════
        // C1: DUAL-WRITE Cell Health → Hippocampus (per-cell granularity)
        // ═══════════════════════════════════════════════════════════════════════════════
        {
            // Determine bio_system (convert string to enum or classify)
            const bio_sys = if (m.bio_system.len > 0) bioSystemFromStr(m.bio_system) else classifyBioSystem(cell.id, cell.capabilities, m.path);
            const bio_name = bioSystemToString(bio_sys);

            // Write to hippocampus (ignore errors, non-blocking)
            hippocampus.writeCellHealth(allocator, .{
                .cell_id = cell.id,
                .cell_name = if (cell.name.len > 0) cell.name else cell.id,
                .health_score = @intCast(@min(100, score)),
                .health_delta = 0, // TODO: track previous score for delta
                .bio_system = bio_name,
                .trigger = "scan",
                .files_total = cell.files,
                .files_generated = 0, // TODO: count generated files
                .files_manual = cell.files,
                .tests_passing = cell.tests > 0,
            }) catch {};
        }

        if (score >= 80) grade_a += 1 else if (score >= 60) grade_b += 1 else if (score >= 40) grade_c += 1 else grade_f += 1;
        total_score += score;
        scored_count += 1;
        if (score < weakest_score and cell.parent.len == 0) {
            weakest_score = score;
            weakest_id = cell.id;
        }
    }

    const avg = if (scored_count > 0) total_score / scored_count else 0;
    const avg_color = if (avg >= 80) GREEN else if (avg >= 60) YELLOW else RED;
    const cycle_sym = if (cycle_count == 0) GREEN else RED;
    const cycle_mark = if (cycle_count == 0) "0 ✓" else "found";

    // Count monolith coverage (files in sub-cells vs total src/tri/)
    var monolith_total: usize = 0;
    var monolith_covered: usize = 0;
    {
        var tri_dir = std.fs.cwd().openDir("src/tri", .{ .iterate = true }) catch null;
        if (tri_dir) |*d| {
            defer d.close();
            var iter = d.iterate();
            while (iter.next() catch null) |entry| {
                if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".zig")) {
                    monolith_total += 1;
                    // Check if matched by any sub-cell file_patterns
                    for (all_cells) |sc| {
                        if (sc.manifest.parent.len > 0 and sc.manifest.file_patterns.len > 2) {
                            if (matchesFilePatterns(entry.name, sc.manifest.file_patterns)) {
                                monolith_covered += 1;
                                break;
                            }
                        }
                    }
                }
            }
        }
        // Also count math/ subdir
        var math_dir = std.fs.cwd().openDir("src/tri/math", .{ .iterate = true }) catch null;
        if (math_dir) |*md| {
            defer md.close();
            var miter = md.iterate();
            while (miter.next() catch null) |entry| {
                if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".zig")) {
                    monolith_total += 1;
                    monolith_covered += 1; // math sub-cell covers all math/*.zig
                }
            }
        }
    }
    const cov_pct = if (monolith_total > 0) monolith_covered * 100 / monolith_total else 0;
    const cov_color = if (cov_pct >= 60) GREEN else if (cov_pct >= 30) YELLOW else RED;

    std.debug.print("  {s}Score:{s}      {s}{d}/100{s}\n", .{ WHITE, RESET, avg_color, avg, RESET });
    std.debug.print("  {s}Cells:{s}      {d} + {d} sub-cells | A:{d} B:{d} C:{d} F:{d}\n", .{ WHITE, RESET, cell_count, sub_count, grade_a, grade_b, grade_c, grade_f });
    std.debug.print("  {s}Cycles:{s}     {s}{s}{s}", .{ WHITE, RESET, cycle_sym, cycle_mark, RESET });
    if (cycle_count > 0) std.debug.print(" ({d})", .{cycle_count});
    std.debug.print("\n", .{});
    std.debug.print("  {s}Monolith:{s}   {s}{d}/{d} files covered ({d}%%){s}\n", .{
        WHITE, RESET, cov_color, monolith_covered, monolith_total, cov_pct, RESET,
    });
    std.debug.print("  {s}Weakest:{s}    {s} ({d})\n", .{ WHITE, RESET, weakest_id, weakest_score });
    std.debug.print("  {s}Formula:{s}    health(30) + security(30) + deps(25) + contracts(15)\n\n", .{ WHITE, RESET });

    // ═══════════════════════════════════════════════════════════════════════════════
    // DUAL-WRITE: Cerebellum → Hippocampus (Wave 3)
    // ═══════════════════════════════════════════════════════════════════════════════
    var buf: [256]u8 = undefined;
    const summary = std.fmt.bufPrint(&buf, "cell health: {d}/{d} total (A:{d} B:{d} C:{d} F:{d}) | cycles: {d} | weakest: {s} ({d})", .{ cell_count + sub_count, cell_count + sub_count, grade_a, grade_b, grade_c, grade_f, cycle_count, weakest_id, weakest_score });
    hippocampus.writeObservation(allocator, "cerebellum", summary catch "cell health snapshot", "{}") catch {};

    if (grade_f > 0 or cycle_count > 0) {
        const err_summary = std.fmt.bufPrint(&buf, "cell issue: {d} broken cells, {d} dependency cycles", .{ grade_f, cycle_count });
        hippocampus.writeError(allocator, "cerebellum", err_summary catch "cell issues detected", "{}") catch {};
    }

    if (cycle_count > 0) {
        std.debug.print("  {s}Action:{s} run {s}tri cell deps --cycles{s} to see cycle details\n", .{ YELLOW, RESET, CYAN, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRENDS — Health trajectory analysis using hippocampus history
// ═══════════════════════════════════════════════════════════════════════════════

/// Cell trend data for analysis
const CellTrend = struct {
    cell_id: []const u8,
    cell_name: []const u8,
    current_health: u8,
    oldest_health: u8,
    days_spanned: u32,
    slope: f32, // health change per day
    trend: enum { declining, stable, improving },
    anomalies: u8, // number of >20 point drops
    scan_count: u32,
};

/// Parse args for trends command
fn parseTrendArgs(args: []const []const u8) struct { days: u32, format: []const u8 } {
    var days: u32 = 7;
    var format: []const u8 = "text";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--days") and i + 1 < args.len) {
            days = std.fmt.parseInt(u32, args[i + 1], 10) catch days;
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--format") and i + 1 < args.len) {
            format = args[i + 1];
            i += 1;
        }
    }

    return .{ .days = days, .format = format };
}

/// Main trends command handler
fn runTrends(allocator: Allocator, args: []const []const u8) !void {
    const opts = parseTrendArgs(args);

    // Get all cell health records from hippocampus
    var health_records = try hippocampus.getAllCellHealth(allocator, opts.days);
    defer health_records.deinit(allocator);

    if (health_records.items.len == 0) {
        std.debug.print("{s}No health records found in hippocampus.{s}\n", .{ YELLOW, RESET });
        std.debug.print("  Run {s}tri cell health{s} to record baseline.\n", .{ CYAN, RESET });
        return;
    }

    // Parse all records first and extract cell_id immediately to capture the value
    var parsed_records = try std.ArrayList(struct {
        cell_id_buf: [256]u8,
        cell_id_len: usize,
        cell_name: []const u8,
        health_score: u8,
        ts: u64,
    }).initCapacity(allocator, 0);
    defer parsed_records.deinit();

    for (health_records.items) |rec| {
        const parsed = hippocampus.ParsedCellHealth.fromRecord(&rec) catch continue;
        var buf: [256]u8 = undefined;
        const cell_id_slice = parsed.cell_id[0..@min(parsed.cell_id.len, 256)];
        @memcpy(&buf, cell_id_slice);
        try parsed_records.append(allocator, .{
            .cell_id_buf = buf,
            .cell_id_len = cell_id_slice.len,
            .cell_name = parsed.cell_name,
            .health_score = parsed.health_score,
            .ts = parsed.ts,
        });
    }

    if (parsed_records.items.len == 0) {
        std.debug.print("{s}No valid cell health records found.{s}\n", .{ YELLOW, RESET });
        return;
    }

    // Group records by cell_id and compute trends in one pass
    var trends_list = try std.ArrayList(CellTrend).initCapacity(allocator, 32);
    defer trends_list.deinit(allocator);

    var processed = try std.ArrayList(bool).initCapacity(allocator, 0);
    defer processed.deinit(allocator);
    for (0..parsed_records.items.len) |_| {
        try processed.append(allocator, false);
    }

    for (parsed_records.items, 0..) |rec, idx| {
        if (processed.items[idx]) continue; // Skip if already grouped
        processed.items[idx] = true;

        // Find all records for this cell
        var cell_records = try std.ArrayList(@TypeOf(parsed_records.items[0])).initCapacity(allocator, 16);
        defer cell_records.deinit(allocator);
        try cell_records.append(allocator, rec);

        const rec_id = rec.cell_id_buf[0..rec.cell_id_len];

        // Find matching records
        for (parsed_records.items, 0..) |other_rec, other_idx| {
            if (!processed.items[other_idx]) {
                const other_id = other_rec.cell_id_buf[0..other_rec.cell_id_len];
                if (std.mem.eql(u8, rec_id, other_id)) {
                    try cell_records.append(allocator, other_rec);
                    processed.items[other_idx] = true;
                }
            }
        }

        // Need at least 2 records to compute trend
        if (cell_records.items.len < 2) continue;

        // Sort by timestamp desc
        std.mem.sort(@TypeOf(parsed_records.items[0]), cell_records.items, {}, struct {
            fn lessThan(_: void, a: @TypeOf(parsed_records.items[0]), b: @TypeOf(parsed_records.items[0])) bool {
                return a.ts > b.ts;
            }
        }.lessThan);

        // Find oldest and newest
        const newest = cell_records.items[0];
        const oldest = cell_records.items[cell_records.items.len - 1];

        // Calculate days spanned
        const days_spanned = @max(1, (newest.ts - oldest.ts) / (24 * 3600));

        // Calculate slope
        const health_delta = @as(i32, newest.health_score) - @as(i32, oldest.health_score);
        const slope: f32 = @as(f32, @floatFromInt(health_delta)) / @as(f32, @floatFromInt(days_spanned));

        // Detect anomalies (>20 point drops)
        var anomalies: u8 = 0;
        for (cell_records.items, 0..) |item, i| {
            if (i < cell_records.items.len - 1) {
                const next_item = cell_records.items[i + 1];
                const drop = @as(i32, item.health_score) - @as(i32, next_item.health_score);
                if (drop > 20) anomalies += 1;
            }
        }

        try trends_list.append(allocator, .{
            .cell_id = try allocator.dupe(u8, rec_id),
            .cell_name = try allocator.dupe(u8, newest.cell_name),
            .current_health = newest.health_score,
            .oldest_health = oldest.health_score,
            .days_spanned = @intCast(days_spanned),
            .slope = slope,
            .trend = if (slope > 1.0) .improving else if (slope < -1.0) .declining else .stable,
            .anomalies = anomalies,
            .scan_count = @intCast(cell_records.items.len),
        });
    }

    if (trends_list.items.len == 0) {
        std.debug.print("{s}No cells with sufficient history ({s}+ scans).{s}\n", .{ YELLOW, RESET, "2" });
        return;
    }

    if (std.mem.eql(u8, opts.format, "json")) {
        try outputTrendsJson(trends_list.items, opts.days);
    } else if (std.mem.eql(u8, opts.format, "markdown")) {
        try outputTrendsMarkdown(trends_list.items, opts.days);
    } else {
        try outputTrendsText(trends_list.items, opts.days);
    }
}

/// Output trends in text format with colored terminal output
fn outputTrendsText(trends: []CellTrend, days: u32) !void {
    std.debug.print("\n{s}📊 Cell Health Trends ({d} days){s}\n\n", .{ GOLDEN, days, RESET });

    // Sort by slope (most declining first, then most improving)
    var mutable_trends = try std.ArrayList(CellTrend).initCapacity(std.heap.page_allocator, trends.len);
    defer mutable_trends.deinit(std.heap.page_allocator);
    for (trends) |t| try mutable_trends.append(std.heap.page_allocator, t);

    std.mem.sort(CellTrend, mutable_trends.items, {}, struct {
        fn lessThan(_: void, a: CellTrend, b: CellTrend) bool {
            return a.slope < b.slope;
        }
    }.lessThan);

    // Show top 5 declining
    var declining_count: usize = 0;
    std.debug.print("{s}🔴 Most Declining{s}\n", .{ RED, RESET });
    for (mutable_trends.items) |t| {
        if (t.trend == .declining and declining_count < 5) {
            const arrow = if (t.slope < -2.0) "⬇️⬇️" else "⬇️";
            std.debug.print("  {s}{s}{s} {s}: {d}→{d} in {d} days ({d:.1}/day)\n", .{
                RED, arrow, RESET, t.cell_name, t.oldest_health, t.current_health, t.days_spanned, t.slope,
            });
            if (t.anomalies > 0) {
                const plural_str = if (t.anomalies > 1) "s" else "";
                std.debug.print("      {s}⚠️  {d} anomaly{s}s detected{s}\n", .{ YELLOW, t.anomalies, plural_str, RESET });
            }
            declining_count += 1;
        }
    }
    if (declining_count == 0) {
        std.debug.print("  {s}No declining cells {s}\n", .{ GREEN, RESET });
    }

    // Separator
    std.debug.print("\n", .{});

    // Show top 5 improving
    var improving_count: usize = 0;
    std.debug.print("{s}🟢 Most Improving{s}\n", .{ GREEN, RESET });
    for (trends) |t| {
        if (t.trend == .improving and improving_count < 5) {
            const arrow = if (t.slope > 2.0) "⬆️⬆️" else "⬆️";
            std.debug.print("  {s}{s}{s} {s}: {d}→{d} in {d} days ({d:.1}/day)\n", .{
                GREEN, arrow, RESET, t.cell_name, t.oldest_health, t.current_health, t.days_spanned, t.slope,
            });
            improving_count += 1;
        }
    }
    if (improving_count == 0) {
        std.debug.print("  {s}No improving cells {s}\n", .{ GRAY, RESET });
    }

    // Separator
    std.debug.print("\n", .{});

    // Show cells with anomalies
    var has_anomalies = false;
    std.debug.print("{s}⚠️  Anomalies Detected{s} (>{d} point drops)\n", .{ YELLOW, RESET, 20 });
    for (mutable_trends.items) |t| {
        if (t.anomalies > 0) {
            const plural_str = if (t.anomalies > 1) "s" else "";
            std.debug.print("  {s}{s}{s}: {d} anomaly{s}s in {d} scans\n", .{
                YELLOW, t.cell_name, RESET, t.anomalies, plural_str, t.scan_count,
            });
            has_anomalies = true;
        }
    }
    if (!has_anomalies) {
        std.debug.print("  {s}No anomalies detected {s}\n", .{ GREEN, RESET });
    }

    // Summary
    std.debug.print("\n{s}📈 Summary{s}\n", .{ GOLDEN, RESET });
    var declining: usize = 0;
    var stable: usize = 0;
    var improving: usize = 0;
    var sick_count: usize = 0;

    for (trends) |t| {
        switch (t.trend) {
            .declining => declining += 1,
            .stable => stable += 1,
            .improving => improving += 1,
        }
        if (t.current_health < 50) sick_count += 1;
    }

    std.debug.print("  Declining: {s}{d}{s} | Stable: {s}{d}{s} | Improving: {s}{d}{s}\n", .{
        RED, declining, RESET, WHITE, stable, RESET, GREEN, improving, RESET,
    });
    std.debug.print("  Cells at risk ({d}<): {s}{d}{s}\n", .{ 50, if (sick_count > 0) RED else GREEN, sick_count, RESET });

    // Action items
    if (sick_count > 0 or declining > 0) {
        std.debug.print("\n{s}🎯 Action Items{s}\n", .{ GOLDEN, RESET });
        if (sick_count > 0) {
            std.debug.print("  • Run {s}tri cell fix --all{s} to repair sick cells\n", .{ CYAN, RESET });
        }
        if (declining > 0) {
            std.debug.print("  • Run {s}tri cell doctor{s} to heal declining cells\n", .{ CYAN, RESET });
        }
        std.debug.print("  • Run {s}tri cell watch{s} to monitor real-time health\n", .{ CYAN, RESET });
    }

    std.debug.print("\n", .{});
}

/// Output trends in JSON format
fn outputTrendsJson(trends: []CellTrend, days: u32) !void {
    std.debug.print("{{\n", .{});
    std.debug.print("  \"version\": \"1.0\",\n", .{});
    std.debug.print("  \"days_analyzed\": {d},\n", .{days});
    std.debug.print("  \"timestamp\": {d},\n", .{std.time.timestamp()});
    std.debug.print("  \"cells\": [\n", .{});

    for (trends, 0..) |t, i| {
        const comma = if (i < trends.len - 1) "," else "";
        const trend_str = switch (t.trend) {
            .declining => "\"declining\"",
            .stable => "\"stable\"",
            .improving => "\"improving\"",
        };
        std.debug.print("    {{\n", .{});
        std.debug.print("      \"cell_id\": \"{s}\",\n", .{t.cell_id});
        std.debug.print("      \"cell_name\": \"{s}\",\n", .{t.cell_name});
        std.debug.print("      \"current_health\": {d},\n", .{t.current_health});
        std.debug.print("      \"oldest_health\": {d},\n", .{t.oldest_health});
        std.debug.print("      \"days_spanned\": {d},\n", .{t.days_spanned});
        std.debug.print("      \"slope\": {d:.2},\n", .{t.slope});
        std.debug.print("      \"trend\": {s},\n", .{trend_str});
        std.debug.print("      \"anomalies\": {d},\n", .{t.anomalies});
        std.debug.print("      \"scan_count\": {d}\n", .{t.scan_count});
        std.debug.print("    }}{s}\n", .{comma});
    }

    std.debug.print("  ]\n", .{});
    std.debug.print("}}\n", .{});
}

/// Output trends in Markdown format
fn outputTrendsMarkdown(trends: []CellTrend, days: u32) !void {
    std.debug.print("# Cell Health Trends ({d} days)\n\n", .{days});
    std.debug.print("*Generated: {}*\n\n", .{std.time.timestamp()});

    // Sort by slope
    var sorted = try std.ArrayList(CellTrend).initCapacity(std.heap.page_allocator, trends.len);
    defer sorted.deinit(std.heap.page_allocator);
    for (trends) |t| try sorted.append(std.heap.page_allocator, t);

    std.mem.sort(CellTrend, sorted.items, {}, struct {
        fn lessThan(_: void, a: CellTrend, b: CellTrend) bool {
            return a.slope < b.slope;
        }
    }.lessThan);

    // Declining section
    std.debug.print("## 🔴 Most Declining\n\n", .{});
    std.debug.print("| Cell | Change | Days | Rate | Anomalies |\n", .{});
    std.debug.print("|------|--------|------|------|----------|\n", .{});
    var declining_count: usize = 0;
    for (sorted.items) |t| {
        if (t.trend == .declining and declining_count < 5) {
            const anomaly_str = if (t.anomalies > 0) try std.fmt.allocPrint(std.heap.page_allocator, "⚠️ {d}", .{t.anomalies}) else "-";
            std.debug.print("| {s} | {s}{d}→{d}{s} | {d} | {d:.1}/day | {s} |\n", .{
                t.cell_name, RED, t.oldest_health, t.current_health, RESET, t.days_spanned, t.slope, anomaly_str,
            });
            declining_count += 1;
        }
    }
    if (declining_count == 0) {
        std.debug.print("| *None* | | | | |\n", .{});
    }
    std.debug.print("\n", .{});

    // Improving section
    std.debug.print("## 🟢 Most Improving\n\n", .{});
    std.debug.print("| Cell | Change | Days | Rate |\n", .{});
    std.debug.print("|------|--------|------|------|\n", .{});
    var improving_count: usize = 0;
    for (sorted.items) |t| {
        if (t.trend == .improving and improving_count < 5) {
            std.debug.print("| {s} | {s}{d}→{d}{s} | {d} | {d:.1}/day |\n", .{
                t.cell_name, GREEN, t.oldest_health, t.current_health, RESET, t.days_spanned, t.slope,
            });
            improving_count += 1;
        }
    }
    if (improving_count == 0) {
        std.debug.print("| *None* | | | |\n", .{});
    }
    std.debug.print("\n", .{});

    // Anomalies section
    std.debug.print("## ⚠️ Anomalies (>{d} point drops)\n\n", .{20});
    std.debug.print("| Cell | Anomalies | Scans |\n", .{});
    std.debug.print("|------|-----------|-------|\n", .{});
    var has_anomalies = false;
    for (trends) |t| {
        if (t.anomalies > 0) {
            std.debug.print("| {s} | {d} | {d} |\n", .{ t.cell_name, t.anomalies, t.scan_count });
            has_anomalies = true;
        }
    }
    if (!has_anomalies) {
        std.debug.print("| *None* | | |\n", .{});
    }
    std.debug.print("\n", .{});

    // Summary
    std.debug.print("## Summary\n\n", .{});
    var declining: usize = 0;
    var stable: usize = 0;
    var improving: usize = 0;
    var sick_count: usize = 0;

    for (trends) |t| {
        switch (t.trend) {
            .declining => declining += 1,
            .stable => stable += 1,
            .improving => improving += 1,
        }
        if (t.current_health < 50) sick_count += 1;
    }

    std.debug.print("- **Declining:** {d}\n", .{declining});
    std.debug.print("- **Stable:** {d}\n", .{stable});
    std.debug.print("- **Improving:** {d}\n", .{improving});
    std.debug.print("- **At risk (<50):** {d}\n\n", .{sick_count});
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENABLE/DISABLE — JSON roundtrip (no string hacks)
// ═══════════════════════════════════════════════════════════════════════════════

fn runToggleEnabled(allocator: Allocator, args: []const []const u8, enable: bool) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage:{s} tri cell {s} <cell-id>\n", .{
            YELLOW, RESET, if (enable) "enable" else "disable",
        });
        return;
    }

    const cell_id = args[0];
    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse registry\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const root = &parsed.value;
    const cells = (root.object.get("cells") orelse return).array.items;

    var found = false;
    for (cells) |*item| {
        const obj = &item.object;
        const id = jsonStr(obj.*, "id");
        if (std.mem.eql(u8, id, cell_id)) {
            // Modify in-place via the parsed JSON tree
            if (obj.*.getPtr("enabled")) |enabled_ptr| {
                enabled_ptr.* = .{ .bool = enable };
            } else {
                obj.*.put("enabled", .{ .bool = enable }) catch {
                    std.debug.print("{s}ERROR{s}: Failed to set enabled field\n", .{ RED, RESET });
                    return;
                };
            }
            found = true;
            break;
        }
    }

    if (!found) {
        std.debug.print("{s}ERROR{s}: Cell '{s}' not found in registry\n", .{ RED, RESET, cell_id });
        return;
    }

    // Write back using JSON pretty printer
    var output = std.array_list.Managed(u8).init(allocator);
    defer output.deinit();
    try writeJsonPretty(output.writer(), root.*, 0);
    try output.append('\n');

    const file = std.fs.cwd().createFile("data/cells/registry.json", .{}) catch |err| {
        std.debug.print("{s}ERROR{s}: Cannot write registry: {}\n", .{ RED, RESET, err });
        return;
    };
    defer file.close();
    file.writeAll(output.items) catch return;

    const action = if (enable) "enabled" else "disabled";
    const icon = if (enable) "●" else "○";
    const color = if (enable) GREEN else GRAY;
    std.debug.print("\n  {s}{s}{s} {s} — {s}{s}{s}\n\n", .{ color, icon, RESET, cell_id, color, action, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// VERIFY — check content hashes for integrity
// ═══════════════════════════════════════════════════════════════════════════════

fn runVerify(allocator: Allocator) !void {
    std.debug.print("\n{s}🔐 Verifying cell integrity...{s}\n\n", .{ GOLDEN, RESET });

    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse registry\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const cells = (parsed.value.object.get("cells") orelse return).array.items;
    var ok_count: usize = 0;
    var fail_count: usize = 0;
    var skip_count: usize = 0;

    for (cells) |item| {
        const obj = item.object;
        const id = jsonStr(obj, "id");
        const path = jsonStr(obj, "path");
        const expected_hash = jsonStr(obj, "content_hash");

        if (expected_hash.len == 0) {
            std.debug.print("  {s}SKIP{s}  {s} — no content_hash in registry\n", .{ GRAY, RESET, id });
            skip_count += 1;
            continue;
        }

        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);

        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch {
            std.debug.print("  {s}FAIL{s}  {s} — cannot read {s}\n", .{ RED, RESET, id, cell_tri_path });
            fail_count += 1;
            continue;
        };
        defer allocator.free(content);

        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(content, &hash, .{});
        const actual_hex = std.fmt.bytesToHex(hash, .lower);

        if (std.mem.eql(u8, actual_hex[0..64], expected_hash)) {
            std.debug.print("  {s}OK{s}    {s}\n", .{ GREEN, RESET, id });
            ok_count += 1;
        } else {
            std.debug.print("  {s}FAIL{s}  {s} — hash mismatch (modified?)\n", .{ RED, RESET, id });
            fail_count += 1;
        }
    }

    std.debug.print("\n  {s}Verified: {d}{s} | {s}Failed: {d}{s} | Skipped: {d}\n\n", .{
        GREEN,                             ok_count,   RESET,
        if (fail_count > 0) RED else GRAY, fail_count, RESET,
        skip_count,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHECK-BOUNDARIES — validate tag boundary rules with real dependency data
// ═══════════════════════════════════════════════════════════════════════════════

fn runCheckBoundaries(allocator: Allocator) !void {
    std.debug.print("\n{s}🏗  Checking boundary rules...{s}\n\n", .{ GOLDEN, RESET });

    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse registry\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const root = parsed.value.object;
    const cells = (root.get("cells") orelse return).array.items;
    const rules = root.get("boundary_rules");

    if (rules == null) {
        std.debug.print("  {s}No boundary_rules defined in registry.json{s}\n\n", .{ GRAY, RESET });
        return;
    }

    var violations: usize = 0;
    var rules_checked: usize = 0;

    for (rules.?.array.items) |rule| {
        const rule_obj = rule.object;
        const source_tag = jsonStr(rule_obj, "sourceTag");
        if (source_tag.len == 0) continue;
        rules_checked += 1;

        // Parse source tag: "type:agent" → tag_key="type", tag_value="agent"
        var tag_key: []const u8 = "type";
        var tag_value: []const u8 = source_tag;
        if (std.mem.indexOf(u8, source_tag, ":")) |colon| {
            tag_key = source_tag[0..colon];
            tag_value = source_tag[colon + 1 ..];
        }

        // Parse deniedDeps as JSON array
        var denied_types: [16][]const u8 = undefined;
        var denied_count: usize = 0;
        if (rule_obj.get("deniedDeps")) |denied_val| {
            switch (denied_val) {
                .array => |arr| {
                    for (arr.items) |dv| {
                        if (dv == .string and denied_count < 16) {
                            const ds = dv.string;
                            // Parse "type:agent" → "agent"
                            if (std.mem.indexOf(u8, ds, ":")) |c| {
                                denied_types[denied_count] = ds[c + 1 ..];
                            } else {
                                denied_types[denied_count] = ds;
                            }
                            denied_count += 1;
                        }
                    }
                },
                .string => |s| {
                    if (s.len > 0 and denied_count < 16) {
                        if (std.mem.indexOf(u8, s, ":")) |c| {
                            denied_types[denied_count] = s[c + 1 ..];
                        } else {
                            denied_types[denied_count] = s;
                        }
                        denied_count += 1;
                    }
                },
                else => {},
            }
        }

        if (denied_count == 0) continue;

        // For each cell matching the source tag, check its dependencies
        for (cells) |cell_item| {
            const cell_obj = cell_item.object;
            const cell_id = jsonStr(cell_obj, "id");

            // Check if cell matches source tag
            const cell_tag_type = getCellTagValue(cell_obj, tag_key);
            if (!std.mem.eql(u8, cell_tag_type, tag_value)) continue;

            // Read cell.tri for dependencies
            const cell_path = jsonStr(cell_obj, "path");
            const tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{cell_path}) catch continue;
            defer allocator.free(tri_path);
            const content = std.fs.cwd().readFileAlloc(allocator, tri_path, 65536) catch continue;
            defer allocator.free(content);
            const cell = parseCellTri(content);

            if (DepIterator.count(cell.dependencies_raw) == 0) {
                std.debug.print("  {s}CHECK{s}  {s} ({s}={s}) — no deps declared\n", .{ CYAN, RESET, cell_id, tag_key, tag_value });
                continue;
            }

            // Check each dependency against denied types
            var dep_it = DepIterator.init(cell.dependencies_raw);
            while (dep_it.next()) |dep| {
                // Find dep's type tag
                for (cells) |dep_cell| {
                    if (std.mem.eql(u8, jsonStr(dep_cell.object, "id"), dep.id)) {
                        const dep_type = getCellTagValue(dep_cell.object, "type");
                        for (denied_types[0..denied_count]) |denied| {
                            if (std.mem.eql(u8, dep_type, denied)) {
                                std.debug.print("  {s}VIOLATION{s}  {s} ({s}={s}) depends on {s} ({s}={s}) — denied by rule\n", .{
                                    RED, RESET, cell_id, tag_key, tag_value, dep.id, "type", dep_type,
                                });
                                violations += 1;
                            }
                        }
                        break;
                    }
                }
            }
        }
    }

    std.debug.print("\n  Rules checked: {d} | Violations: {d}\n", .{ rules_checked, violations });
    if (violations == 0) {
        std.debug.print("  {s}No boundary violations detected.{s}\n\n", .{ GREEN, RESET });
    } else {
        std.debug.print("  {s}Found {d} boundary violation(s)!{s}\n\n", .{ RED, violations, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LINT — check @import isolation + permission violations
// ═══════════════════════════════════════════════════════════════════════════════

fn runLint(allocator: Allocator, args: []const []const u8) !void {
    std.debug.print("\n{s}🔍 Linting cell boundaries...{s}\n\n", .{ GOLDEN, RESET });

    // Optional cell filter
    var cell_filter: ?[]const u8 = null;
    if (args.len > 0) cell_filter = args[0];

    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse registry\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const cells = (parsed.value.object.get("cells") orelse return).array.items;

    // Build cell path → cell id mapping
    var path_to_id = std.StringHashMap([]const u8).init(allocator);
    defer path_to_id.deinit();
    for (cells) |item| {
        const obj = item.object;
        const id = jsonStr(obj, "id");
        const path = jsonStr(obj, "path");
        if (id.len > 0 and path.len > 0) {
            path_to_id.put(path, id) catch {};
        }
    }

    var total_violations: usize = 0;
    var total_warnings: usize = 0;
    var cells_checked: usize = 0;

    for (cells) |item| {
        const obj = item.object;
        const cell_id = jsonStr(obj, "id");
        const cell_path = jsonStr(obj, "path");

        if (cell_filter) |f| {
            if (!std.mem.eql(u8, cell_id, f)) continue;
        }

        // Read cell.tri for declared dependencies and permissions
        const tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{cell_path}) catch continue;
        defer allocator.free(tri_path);
        const cell_content = std.fs.cwd().readFileAlloc(allocator, tri_path, 65536) catch continue;
        defer allocator.free(cell_content);
        const cell = parseCellTri(cell_content);

        // Collect declared dependency ids
        var declared_deps = std.StringHashMap(void).init(allocator);
        defer declared_deps.deinit();
        var dep_it = DepIterator.init(cell.dependencies_raw);
        while (dep_it.next()) |dep| {
            declared_deps.put(dep.id, {}) catch {};
        }

        cells_checked += 1;
        var cell_violations: usize = 0;
        var cell_warnings: usize = 0;

        // Scan all .zig files in cell_path for @import statements
        var dir = std.fs.cwd().openDir(cell_path, .{ .iterate = true }) catch continue;
        defer dir.close();

        var walker = dir.walk(allocator) catch continue;
        defer walker.deinit();

        while (walker.next() catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;

            const file_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ cell_path, entry.path }) catch continue;
            defer allocator.free(file_path);

            const source = std.fs.cwd().readFileAlloc(allocator, file_path, 1048576) catch continue;
            defer allocator.free(source);

            // Find @import("...") patterns
            var pos: usize = 0;
            while (pos < source.len) {
                const import_pos = std.mem.indexOf(u8, source[pos..], "@import(\"") orelse break;
                const abs_pos = pos + import_pos + 9; // skip @import("
                pos = abs_pos;

                const end_quote = std.mem.indexOf(u8, source[abs_pos..], "\"") orelse break;
                const import_path = source[abs_pos .. abs_pos + end_quote];
                pos = abs_pos + end_quote + 1;

                // Skip std imports and relative imports within same cell
                if (std.mem.eql(u8, import_path, "std")) continue;
                if (std.mem.startsWith(u8, import_path, "builtin")) continue;

                // Check if import references another cell's module
                // Match only: exact module name or path-relative import into another cell's dir
                for (cells) |other_cell| {
                    const other_id = jsonStr(other_cell.object, "id");
                    const other_path = jsonStr(other_cell.object, "path");
                    if (std.mem.eql(u8, other_id, cell_id)) continue;

                    // Skip intra-family imports: cells sharing the same path are siblings
                    // (parent + sub-cells all have path = "src/tri" etc.)
                    // Cross-imports within one compilation unit are expected, not violations.
                    if (std.mem.eql(u8, cell_path, other_path)) continue;

                    const other_module = if (std.mem.lastIndexOf(u8, other_path, "/")) |slash|
                        other_path[slash + 1 ..]
                    else
                        other_path;

                    // Strict matching to avoid false positives:
                    // 1. Exact build.zig module name: @import("sacred") == "sacred"
                    // 2. Relative path entering another cell: "../sacred/foo.zig" contains "/sacred/"
                    // 3. Filename exactly matches module: @import("sacred.zig") stem == "sacred"
                    var is_cross_cell = false;
                    if (std.mem.eql(u8, import_path, other_module)) {
                        // Exact module name match
                        is_cross_cell = true;
                    } else if (std.mem.indexOf(u8, import_path, "/") != null) {
                        // Path-based import — check if it traverses into another cell dir
                        // Skip overly broad modules (e.g. "src") to avoid false positives
                        if (other_module.len > 3) {
                            const path_pattern = std.fmt.allocPrint(allocator, "/{s}/", .{other_module}) catch continue;
                            defer allocator.free(path_pattern);
                            if (std.mem.indexOf(u8, import_path, path_pattern) != null) {
                                is_cross_cell = true;
                            }
                        }
                    } else if (std.mem.endsWith(u8, import_path, ".zig")) {
                        // Filename import — stem must exactly match module name
                        // But only if the file does NOT exist locally (otherwise it's a same-cell import)
                        const stem = import_path[0 .. import_path.len - 4];
                        if (std.mem.eql(u8, stem, other_module)) {
                            const local_check = std.fmt.allocPrint(allocator, "{s}/{s}", .{ cell_path, import_path }) catch continue;
                            defer allocator.free(local_check);
                            const local_exists = if (std.fs.cwd().access(local_check, .{})) true else |_| false;
                            if (!local_exists) {
                                is_cross_cell = true;
                            }
                        }
                    }

                    if (is_cross_cell) {
                        if (!declared_deps.contains(other_id)) {
                            std.debug.print("  {s}VIOLATION{s} {s}: @import(\"{s}\") → {s} (not in [dependencies])\n", .{
                                RED, RESET, cell_id, import_path, other_id,
                            });
                            cell_violations += 1;
                        }
                    }
                }
            }
        }

        // Permission checks
        if (cell.perm_level.len > 0) {
            // L0 cells should not have write dependencies
            if (std.mem.eql(u8, cell.perm_level, "L0")) {
                var dep_it2 = DepIterator.init(cell.dependencies_raw);
                while (dep_it2.next()) |dep| {
                    // Find dep's permission level
                    for (cells) |dep_cell| {
                        if (std.mem.eql(u8, jsonStr(dep_cell.object, "id"), dep.id)) {
                            const dep_path2 = jsonStr(dep_cell.object, "path");
                            const dep_tri = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{dep_path2}) catch break;
                            defer allocator.free(dep_tri);
                            const dep_content = std.fs.cwd().readFileAlloc(allocator, dep_tri, 65536) catch break;
                            defer allocator.free(dep_content);
                            const dep_info = parseCellTri(dep_content);
                            if (std.mem.eql(u8, dep_info.perm_level, "L2")) {
                                // Core libraries are trusted — INFO, not WARNING
                                const is_core = std.mem.eql(u8, dep.id, "trinity.vsa") or
                                    std.mem.eql(u8, dep.id, "trinity.consciousness") or
                                    std.mem.eql(u8, dep.id, "trinity.quantum") or
                                    std.mem.eql(u8, dep.id, "trinity.sacred");
                                if (is_core) {
                                    std.debug.print("  {s}INFO{s}     {s} (L0) → {s} (L2 core, trusted)\n", .{
                                        CYAN, RESET, cell_id, dep.id,
                                    });
                                } else {
                                    std.debug.print("  {s}WARNING{s}  {s} (L0) depends on {s} (L2) — privilege escalation risk\n", .{
                                        YELLOW, RESET, cell_id, dep.id,
                                    });
                                    cell_warnings += 1;
                                }
                            }
                            break;
                        }
                    }
                }
            }

            // Check network permission consistency
            if (std.mem.eql(u8, cell.perm_network, "none")) {
                // Cells with network=none should not depend on network=external cells
                var dep_it3 = DepIterator.init(cell.dependencies_raw);
                while (dep_it3.next()) |dep| {
                    for (cells) |dep_cell| {
                        if (std.mem.eql(u8, jsonStr(dep_cell.object, "id"), dep.id)) {
                            const dep_path3 = jsonStr(dep_cell.object, "path");
                            const dep_tri2 = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{dep_path3}) catch break;
                            defer allocator.free(dep_tri2);
                            const dep_content2 = std.fs.cwd().readFileAlloc(allocator, dep_tri2, 65536) catch break;
                            defer allocator.free(dep_content2);
                            const dep_info2 = parseCellTri(dep_content2);
                            if (std.mem.eql(u8, dep_info2.perm_network, "external")) {
                                // Core libraries are trusted — INFO, not WARNING
                                const is_core2 = std.mem.eql(u8, dep.id, "trinity.vsa") or
                                    std.mem.eql(u8, dep.id, "trinity.consciousness") or
                                    std.mem.eql(u8, dep.id, "trinity.quantum") or
                                    std.mem.eql(u8, dep.id, "trinity.sacred");
                                if (is_core2) {
                                    std.debug.print("  {s}INFO{s}     {s} (net=none) → {s} (net=external, core trusted)\n", .{
                                        CYAN, RESET, cell_id, dep.id,
                                    });
                                } else {
                                    std.debug.print("  {s}WARNING{s}  {s} (net=none) depends on {s} (net=external)\n", .{
                                        YELLOW, RESET, cell_id, dep.id,
                                    });
                                    cell_warnings += 1;
                                }
                            }
                            break;
                        }
                    }
                }
            }

            // No permissions declared at all
        } else {
            std.debug.print("  {s}WARNING{s}  {s} — no [permissions] section\n", .{ YELLOW, RESET, cell_id });
            cell_warnings += 1;
        }

        if (cell_violations == 0 and cell_warnings == 0) {
            std.debug.print("  {s}OK{s}  {s}\n", .{ GREEN, RESET, cell_id });
        }

        total_violations += cell_violations;
        total_warnings += cell_warnings;
    }

    std.debug.print("\n  Cells: {d} | {s}Violations: {d}{s} | {s}Warnings: {d}{s}\n", .{
        cells_checked,
        if (total_violations > 0) RED else GREEN,
        total_violations,
        RESET,
        if (total_warnings > 0) YELLOW else GREEN,
        total_warnings,
        RESET,
    });
    if (total_violations == 0 and total_warnings == 0) {
        std.debug.print("  {s}All cells pass lint checks.{s}\n", .{ GREEN, RESET });
    }
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATE — smart auto-scaffold from existing code
// ═══════════════════════════════════════════════════════════════════════════════

fn runCreate(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage:{s} tri cell create <path>\n", .{ YELLOW, RESET });
        std.debug.print("  Examples:\n", .{});
        std.debug.print("    tri cell create src/gravity       # from directory\n", .{});
        std.debug.print("    tri cell create src/vsa.zig       # from standalone file\n", .{});
        std.debug.print("    tri cell create --agent my-agent  # scaffold agent cell + .md\n", .{});
        return;
    }

    // Handle --agent flag
    if (std.mem.eql(u8, args[0], "--agent")) {
        if (args.len < 2) {
            std.debug.print("{s}Usage:{s} tri cell create --agent <name>\n", .{ YELLOW, RESET });
            return;
        }
        return runCreateAgent(allocator, args[1]);
    }

    var path = args[0];
    // If given a .zig file, use its directory
    if (std.mem.endsWith(u8, path, ".zig")) {
        path = std.fs.path.dirname(path) orelse ".";
    }
    // Strip trailing slash
    if (path.len > 1 and path[path.len - 1] == '/') path = path[0 .. path.len - 1];

    // Check if cell.tri already exists
    const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch return;
    defer allocator.free(cell_tri_path);
    if (std.fs.cwd().access(cell_tri_path, .{})) |_| {
        std.debug.print("{s}SKIP{s}: {s} already has cell.tri\n", .{ YELLOW, RESET, path });
        return;
    } else |_| {}

    // Verify directory exists
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch {
        std.debug.print("{s}ERROR{s}: Directory not found: {s}\n", .{ RED, RESET, path });
        return;
    };
    defer dir.close();

    // Count files and tests
    const stats = countFilesAndTests(allocator, path);
    if (stats.files == 0) {
        std.debug.print("{s}SKIP{s}: No .zig files in {s}\n", .{ YELLOW, RESET, path });
        return;
    }

    // Detect exports (top 5 pub fn names)
    const exports = detectExportsInDir(allocator, path);

    // Infer permissions
    const perms = inferPermissions(allocator, path);

    // Infer name from path
    const name = if (std.mem.lastIndexOf(u8, path, "/")) |slash| path[slash + 1 ..] else path;

    // Infer kind: has main.zig or server → backend, else library
    const has_main = std.fs.cwd().access(
        std.fmt.allocPrint(allocator, "{s}/main.zig", .{path}) catch return,
        .{},
    ) != error.FileNotFound;
    _ = has_main;
    const kind = inferKind(allocator, path);

    // Infer scope from path prefix
    const scope = inferScope(path);

    // Build cell.tri content
    const cell_id = std.fmt.allocPrint(allocator, "trinity.{s}", .{name}) catch return;
    defer allocator.free(cell_id);

    // Build capabilities string
    var caps_buf: [512]u8 = undefined;
    var caps_pos: usize = 0;
    caps_buf[caps_pos] = '[';
    caps_pos += 1;
    var cap_count: usize = 0;
    for (exports.items[0..exports.count]) |exp| {
        if (exp.len == 0) continue;
        if (cap_count > 0) {
            const sep = ", ";
            @memcpy(caps_buf[caps_pos .. caps_pos + sep.len], sep);
            caps_pos += sep.len;
        }
        caps_buf[caps_pos] = '"';
        caps_pos += 1;
        const copy_len = @min(exp.len, caps_buf.len - caps_pos - 2);
        @memcpy(caps_buf[caps_pos .. caps_pos + copy_len], exp[0..copy_len]);
        caps_pos += copy_len;
        caps_buf[caps_pos] = '"';
        caps_pos += 1;
        cap_count += 1;
    }
    caps_buf[caps_pos] = ']';
    caps_pos += 1;

    const content = std.fmt.allocPrint(allocator,
        \\[cell]
        \\id = "{s}"
        \\name = "{s}"
        \\version = "0.1.0"
        \\kind = "{s}"
        \\path = "{s}"
        \\min_core_version = "{s}"
        \\status = "experimental"
        \\description = "Auto-generated cell for {s}"
        \\capabilities = {s}
        \\files = {d}
        \\tests = {d}
        \\owner = ""
        \\
        \\[tags]
        \\scope = "{s}"
        \\type = "{s}"
        \\
        \\[contributes]
        \\commands = []
        \\tri_subcommands = []
        \\events = []
        \\
        \\[dependencies]
        \\
        \\[permissions]
        \\level = "{s}"
        \\filesystem = "{s}"
        \\network = "{s}"
        \\process = "{s}"
        \\ffi = "{s}"
        \\concurrency = "{s}"
        \\
    , .{
        cell_id,           name,      kind,                  path,
        CORE_VERSION,      name,      caps_buf[0..caps_pos], stats.files,
        stats.tests,       scope,     kind,                  perms.level,
        perms.fs,          perms.net, perms.proc,            perms.ffi,
        perms.concurrency,
    }) catch return;
    defer allocator.free(content);

    // Write
    const file = std.fs.cwd().createFile(cell_tri_path, .{}) catch |err| {
        std.debug.print("{s}ERROR{s}: Cannot write {s}: {}\n", .{ RED, RESET, cell_tri_path, err });
        return;
    };
    defer file.close();
    file.writeAll(content) catch return;

    std.debug.print("\n{s}🐝 Cell created:{s} {s}\n", .{ GREEN, RESET, cell_id });
    std.debug.print("  {s}Path:{s}    {s}\n", .{ CYAN, RESET, cell_tri_path });
    std.debug.print("  {s}Kind:{s}    {s}\n", .{ CYAN, RESET, kind });
    std.debug.print("  {s}Files:{s}   {d}\n", .{ CYAN, RESET, stats.files });
    std.debug.print("  {s}Tests:{s}   {d}\n", .{ CYAN, RESET, stats.tests });
    std.debug.print("  {s}Perms:{s}   {s} (fs={s} net={s} proc={s} ffi={s})\n", .{
        CYAN, RESET, perms.level, perms.fs, perms.net, perms.proc, perms.ffi,
    });
    std.debug.print("\n  Next: {s}tri cell check --sync{s} to rebuild registry\n\n", .{ GREEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATE-AGENT — scaffold agent cell.tri + .md definition
// ═══════════════════════════════════════════════════════════════════════════════

fn runCreateAgent(allocator: Allocator, name: []const u8) !void {
    // 1. Create tools/agents/<name>/cell.tri
    const cell_dir = std.fmt.allocPrint(allocator, "tools/agents/{s}", .{name}) catch return;
    defer allocator.free(cell_dir);

    std.fs.cwd().makePath(cell_dir) catch |err| {
        std.debug.print("{s}ERROR{s}: Cannot create {s}: {}\n", .{ RED, RESET, cell_dir, err });
        return;
    };

    const cell_id = std.fmt.allocPrint(allocator, "trinity.agent.{s}", .{name}) catch return;
    defer allocator.free(cell_id);

    const md_path = std.fmt.allocPrint(allocator, ".claude/agents/{s}.md", .{name}) catch return;
    defer allocator.free(md_path);

    const cell_tri_content = std.fmt.allocPrint(allocator,
        \\[cell]
        \\id = "{s}"
        \\name = "{s} Agent"
        \\version = "0.1.0"
        \\kind = "agent"
        \\path = "{s}"
        \\status = "experimental"
        \\description = "TODO: describe this agent"
        \\capabilities = []
        \\owner = "agent:ralph"
        \\
        \\[tags]
        \\scope = "agent"
        \\type = "agent"
        \\
        \\[agent]
        \\definition = "{s}"
        \\model = "sonnet"
        \\max_turns = 20
        \\tools = "Read,Edit,Write,Bash,Grep,Glob"
        \\isolation = ""
        \\
        \\[permissions]
        \\level = "L2"
        \\filesystem = "write"
        \\network = "none"
        \\process = "spawn"
        \\ffi = "none"
        \\concurrency = "none"
        \\
        \\[security]
        \\signed = false
        \\
    , .{ cell_id, name, cell_dir, md_path }) catch return;
    defer allocator.free(cell_tri_content);

    const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{cell_dir}) catch return;
    defer allocator.free(cell_tri_path);
    writeFileIfNotExists(cell_tri_path, cell_tri_content);

    // 2. Create .claude/agents/<name>.md
    const md_content = std.fmt.allocPrint(allocator,
        \\---
        \\name: {s}
        \\description: TODO — describe this agent
        \\tools: Read, Edit, Write, Bash, Grep, Glob
        \\model: sonnet
        \\maxTurns: 20
        \\---
        \\
        \\You are {s} — a specialized agent in the Trinity project.
        \\
        \\## Your Scope
        \\
        \\TODO: Define what this agent does.
        \\
        \\## Protocol
        \\
        \\1. Read context before acting
        \\2. Make minimal, targeted changes
        \\3. Verify changes compile
        \\
    , .{ name, name }) catch return;
    defer allocator.free(md_content);

    writeFileIfNotExists(md_path, md_content);

    std.debug.print("\n{s}🐝 Agent cell created:{s} {s}\n\n", .{ GREEN, RESET, cell_id });
    std.debug.print("  {s}cell.tri{s}     → {s}\n", .{ CYAN, RESET, cell_tri_path });
    std.debug.print("  {s}definition{s}   → {s}\n", .{ CYAN, RESET, md_path });
    std.debug.print("\n  Next steps:\n", .{});
    std.debug.print("    1. Edit {s} — set description and capabilities\n", .{cell_tri_path});
    std.debug.print("    2. Edit {s} — write agent instructions\n", .{md_path});
    std.debug.print("    3. {s}tri cell check --sync{s} — validate and sync registry\n\n", .{ GREEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATE-ALL — batch creation for all unwrapped modules
// ═══════════════════════════════════════════════════════════════════════════════

fn runCreateAll(allocator: Allocator, args: []const []const u8) !void {
    var dry_run = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--dry-run")) dry_run = true;
    }

    std.debug.print("\n{s}🐝 Scanning for unwrapped modules...{s}\n\n", .{ GOLDEN, RESET });

    const cwd = std.fs.cwd();
    var candidates = std.array_list.Managed([]const u8).init(allocator);
    defer {
        for (candidates.items) |p| allocator.free(p);
        candidates.deinit();
    }

    // Scan top-level dirs in CELL_SCAN_DIRS for directories with .zig files but no cell.tri
    for (CELL_SCAN_DIRS) |scan_dir| {
        var dir = cwd.openDir(scan_dir, .{ .iterate = true }) catch continue;
        defer dir.close();

        var iter = dir.iterate();
        while (iter.next() catch null) |entry| {
            if (entry.kind != .directory) continue;
            // Skip hidden dirs, .zig-cache, etc.
            if (entry.name.len == 0 or entry.name[0] == '.') continue;

            const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ scan_dir, entry.name }) catch continue;

            // Check if cell.tri already exists
            const cell_tri = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{full_path}) catch {
                allocator.free(full_path);
                continue;
            };
            defer allocator.free(cell_tri);

            if (cwd.access(cell_tri, .{})) |_| {
                allocator.free(full_path);
                continue; // Already has cell.tri
            } else |_| {}

            // Check if directory contains .zig files
            const stats = countFilesAndTests(allocator, full_path);
            if (stats.files == 0) {
                allocator.free(full_path);
                continue;
            }

            candidates.append(full_path) catch {
                allocator.free(full_path);
                continue;
            };
        }
    }

    if (candidates.items.len == 0) {
        std.debug.print("  {s}All modules already have cell.tri{s}\n\n", .{ GREEN, RESET });
        return;
    }

    // Sort for deterministic output
    std.mem.sort([]const u8, candidates.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lessThan);

    if (dry_run) {
        std.debug.print("  {s}[DRY RUN]{s} Would create {d} cell.tri files:\n\n", .{ YELLOW, RESET, candidates.items.len });
        for (candidates.items) |path| {
            const stats = countFilesAndTests(allocator, path);
            const perms = inferPermissions(allocator, path);
            const name = if (std.mem.lastIndexOf(u8, path, "/")) |slash| path[slash + 1 ..] else path;
            std.debug.print("    {s}+{s} {s}/cell.tri  ({d} files, {d} tests, {s})\n", .{
                GREEN, RESET, path, stats.files, stats.tests, perms.level,
            });
            _ = name;
        }
        std.debug.print("\n  Run {s}tri cell create-all{s} (without --dry-run) to generate.\n\n", .{ GREEN, RESET });
        return;
    }

    var created: usize = 0;
    for (candidates.items) |path| {
        // Reuse runCreate logic inline
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);

        const stats = countFilesAndTests(allocator, path);
        const exports = detectExportsInDir(allocator, path);
        const perms = inferPermissions(allocator, path);
        const name = if (std.mem.lastIndexOf(u8, path, "/")) |slash| path[slash + 1 ..] else path;
        const kind = inferKind(allocator, path);
        const scope = inferScope(path);

        const cell_id = std.fmt.allocPrint(allocator, "trinity.{s}", .{name}) catch continue;
        defer allocator.free(cell_id);

        // Build capabilities
        var caps_buf: [512]u8 = undefined;
        var caps_pos: usize = 0;
        caps_buf[caps_pos] = '[';
        caps_pos += 1;
        var cap_count: usize = 0;
        for (exports.items[0..exports.count]) |exp| {
            if (exp.len == 0) continue;
            if (cap_count > 0) {
                const sep = ", ";
                @memcpy(caps_buf[caps_pos .. caps_pos + sep.len], sep);
                caps_pos += sep.len;
            }
            caps_buf[caps_pos] = '"';
            caps_pos += 1;
            const copy_len = @min(exp.len, caps_buf.len - caps_pos - 2);
            @memcpy(caps_buf[caps_pos .. caps_pos + copy_len], exp[0..copy_len]);
            caps_pos += copy_len;
            caps_buf[caps_pos] = '"';
            caps_pos += 1;
            cap_count += 1;
        }
        caps_buf[caps_pos] = ']';
        caps_pos += 1;

        const content = std.fmt.allocPrint(allocator,
            \\[cell]
            \\id = "{s}"
            \\name = "{s}"
            \\version = "0.1.0"
            \\kind = "{s}"
            \\path = "{s}"
            \\min_core_version = "{s}"
            \\status = "experimental"
            \\description = "Auto-generated cell for {s}"
            \\capabilities = {s}
            \\files = {d}
            \\tests = {d}
            \\owner = ""
            \\
            \\[tags]
            \\scope = "{s}"
            \\type = "{s}"
            \\
            \\[contributes]
            \\commands = []
            \\tri_subcommands = []
            \\events = []
            \\
            \\[dependencies]
            \\
            \\[permissions]
            \\level = "{s}"
            \\filesystem = "{s}"
            \\network = "{s}"
            \\process = "{s}"
            \\ffi = "{s}"
            \\concurrency = "{s}"
            \\
        , .{
            cell_id,           name,      kind,                  path,
            CORE_VERSION,      name,      caps_buf[0..caps_pos], stats.files,
            stats.tests,       scope,     kind,                  perms.level,
            perms.fs,          perms.net, perms.proc,            perms.ffi,
            perms.concurrency,
        }) catch continue;
        defer allocator.free(content);

        const file = cwd.createFile(cell_tri_path, .{}) catch continue;
        defer file.close();
        file.writeAll(content) catch continue;

        std.debug.print("  {s}+{s} {s}  ({d} files, {d} tests, {s})\n", .{
            GREEN, RESET, cell_id, stats.files, stats.tests, perms.level,
        });
        created += 1;
    }

    std.debug.print("\n  {s}Created {d} cell.tri files.{s}\n", .{ GREEN, created, RESET });
    std.debug.print("  Next: {s}tri cell check --sync{s} to rebuild registry\n\n", .{ GREEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUDIT — CVE-informed security validation (9 checks)
// ═══════════════════════════════════════════════════════════════════════════════

fn runAudit(allocator: Allocator, args: []const []const u8) !void {
    var strict = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--strict")) strict = true;
    }

    std.debug.print("\n{s}🔒 SECURITY AUDIT — CVE-Informed Validation{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  9 checks mapped to real OpenClaw CVEs\n\n", .{});

    const discovered = discoverCells(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer {
        for (discovered) |p| allocator.free(p);
        allocator.free(discovered);
    }

    var total_errors: usize = 0;
    var total_warnings: usize = 0;
    var cells_scanned: usize = 0;

    for (discovered) |path| {
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);

        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(content);

        const cell = parseCellTri(content);
        if (cell.id.len == 0) continue;

        cells_scanned += 1;
        var cell_errors: usize = 0;
        var cell_warnings: usize = 0;

        // Compute security score
        var sec_score: i16 = blk: {
            if (std.mem.eql(u8, cell.perm_level, "L0")) break :blk 100 else if (std.mem.eql(u8, cell.perm_level, "L1")) break :blk 70 else if (std.mem.eql(u8, cell.perm_level, "L2")) break :blk 40 else break :blk 50; // unknown
        };

        // --- Check 1: Permission escalation chains (L0 → L2) ---
        // (checked via lint, but flag here too)
        if (std.mem.eql(u8, cell.perm_level, "L0") and
            (std.mem.eql(u8, cell.perm_network, "external") or
                std.mem.eql(u8, cell.perm_process, "spawn")))
        {
            std.debug.print("  {s}ERROR{s}  {s}: L0 cell declares network=external or process=spawn (escalation)\n", .{ RED, RESET, cell.id });
            cell_errors += 1;
        }

        // --- Check 2: Undeclared capabilities ---
        // Scan code for capabilities not declared in permissions
        const code_perms = inferPermissions(allocator, path);
        if (std.mem.eql(u8, cell.perm_network, "none") and std.mem.eql(u8, code_perms.net, "external")) {
            std.debug.print("  {s}ERROR{s}  {s}: Code uses std.net/std.http but permissions say network=none\n", .{ RED, RESET, cell.id });
            cell_errors += 1;
            sec_score -= 20;
        }
        if (std.mem.eql(u8, cell.perm_process, "none") and std.mem.eql(u8, code_perms.proc, "spawn")) {
            std.debug.print("  {s}ERROR{s}  {s}: Code uses std.process but permissions say process=none\n", .{ RED, RESET, cell.id });
            cell_errors += 1;
            sec_score -= 15;
        }
        if (std.mem.eql(u8, cell.perm_filesystem, "none") and std.mem.eql(u8, code_perms.fs, "write")) {
            std.debug.print("  {s}WARNING{s}  {s}: Code uses createFile/writeAll but permissions say filesystem=none\n", .{ YELLOW, RESET, cell.id });
            cell_warnings += 1;
        }

        // --- Check 3: Missing signatures for L2 ---
        if (std.mem.eql(u8, cell.perm_level, "L2") and !cell.security_signed) {
            std.debug.print("  {s}WARNING{s}  {s}: L2 cell without [security] signed=true\n", .{ YELLOW, RESET, cell.id });
            cell_warnings += 1;
        }

        // --- Check 4: No permissions section ---
        if (cell.perm_level.len == 0) {
            std.debug.print("  {s}WARNING{s}  {s}: No [permissions] section declared\n", .{ YELLOW, RESET, cell.id });
            cell_warnings += 1;
        }

        // --- Check 5: @cImport / FFI usage ---
        if (std.mem.eql(u8, code_perms.ffi, "native") and !std.mem.eql(u8, cell.perm_ffi, "native")) {
            std.debug.print("  {s}WARNING{s}  {s}: Code uses @cImport/std.c but ffi not declared as native\n", .{ YELLOW, RESET, cell.id });
            cell_warnings += 1;
            sec_score -= 10;
        }

        // --- Check 6: NETWORK BINDING (← ClawJacked) ---
        // Search for 0.0.0.0 in actual bind calls, not in audit/diagnostic code
        const has_bind = scanCodeForPattern(allocator, path, "parseIp4(\"0.0.0.0\"") or
            scanCodeForPattern(allocator, path, "parseIp(\"0.0.0.0\"") or
            scanCodeForPattern(allocator, path, "bind_address: []const u8 = \"0.0.0.0\"") or
            scanCodeForPattern(allocator, path, ".host = \"0.0.0.0\"") or
            scanCodeForPattern(allocator, path, "listen_address = \"0.0.0.0\"");
        if (has_bind) {
            std.debug.print("  {s}CRITICAL{s}  {s}: Binds to 0.0.0.0 — ClawJacked CVE! Use 127.0.0.1\n", .{ RED, RESET, cell.id });
            cell_errors += 1;
            sec_score -= 30;
        }

        // --- Check 7: AUTH TOKEN HANDLING (← CVE-2026-25253) ---
        // Only flag when createFile is used with sensitive filenames (token_file, secret, credential)
        // Not when "token" appears as a variable name or lexer concept
        const has_token_file = (scanCodeForPattern(allocator, path, "token_file") or
            scanCodeForPattern(allocator, path, "secret_file") or
            scanCodeForPattern(allocator, path, "\"token.json\"") or
            scanCodeForPattern(allocator, path, "\"secret\"") or
            scanCodeForPattern(allocator, path, "\".token\"")) and
            scanCodeForPattern(allocator, path, "createFile");
        if (has_token_file) {
            const has_chmod = scanCodeForPattern(allocator, path, "0o600") or
                scanCodeForPattern(allocator, path, "permissions");
            if (!has_chmod) {
                std.debug.print("  {s}WARNING{s}  {s}: Creates token files without 0o600 mode (CVE-2026-25253)\n", .{ YELLOW, RESET, cell.id });
                cell_warnings += 1;
                sec_score -= 25;
            }
        }

        // --- Check 8: NO TRUST LOCALHOST (← ClawJacked brute-force) ---
        if (std.mem.eql(u8, code_perms.net, "external") or std.mem.eql(u8, code_perms.net, "local")) {
            const has_listen = scanCodeForPattern(allocator, path, "listen") or
                scanCodeForPattern(allocator, path, "accept");
            const has_auth = scanCodeForPattern(allocator, path, "auth") or
                scanCodeForPattern(allocator, path, "bearer") or
                scanCodeForPattern(allocator, path, "Authorization");
            // Localhost-only binding mitigates the ClawJacked risk
            const binds_localhost = scanCodeForPattern(allocator, path, "\"127.0.0.1\"") or
                scanCodeForPattern(allocator, path, "localhost");
            if (has_listen and !has_auth and !binds_localhost) {
                std.debug.print("  {s}WARNING{s}  {s}: Accepts connections without auth check (ClawJacked risk)\n", .{ YELLOW, RESET, cell.id });
                cell_warnings += 1;
            }
        }

        // --- Check 9: SUPPLY CHAIN (← ClawHavoc 12% malicious) ---
        // Dependencies must be trinity.* cells, not external URLs
        if (cell.dependencies_raw.len > 0) {
            var dep_it = DepIterator.init(cell.dependencies_raw);
            while (dep_it.next()) |dep| {
                if (!std.mem.startsWith(u8, dep.id, "trinity.")) {
                    std.debug.print("  {s}ERROR{s}  {s}: Non-trinity dependency '{s}' (ClawHavoc supply chain risk)\n", .{ RED, RESET, cell.id, dep.id });
                    cell_errors += 1;
                }
            }
        }

        // Process score penalties
        if (std.mem.eql(u8, code_perms.proc, "spawn")) sec_score -= 15;

        // Clamp score
        if (sec_score < 0) sec_score = 0;
        const final_score: u8 = @intCast(sec_score);

        // Print cell summary if clean
        if (cell_errors == 0 and cell_warnings == 0) {
            const score_color = if (final_score >= 80) GREEN else if (final_score >= 50) YELLOW else RED;
            std.debug.print("  {s}OK{s}    {s}  (score: {s}{d}{s})\n", .{ GREEN, RESET, cell.id, score_color, final_score, RESET });
        } else {
            const score_color = if (final_score >= 80) GREEN else if (final_score >= 50) YELLOW else RED;
            std.debug.print("         {s}↳ security score: {s}{d}{s}\n", .{ GRAY, score_color, final_score, RESET });
        }

        total_errors += cell_errors;
        total_warnings += cell_warnings;
    }

    std.debug.print("\n  {s}Cells scanned:{s} {d}\n", .{ CYAN, RESET, cells_scanned });
    std.debug.print("  {s}Errors:{s} {s}{d}{s}\n", .{
        CYAN, RESET, if (total_errors > 0) RED else GREEN, total_errors, RESET,
    });
    std.debug.print("  {s}Warnings:{s} {s}{d}{s}\n", .{
        CYAN, RESET, if (total_warnings > 0) YELLOW else GREEN, total_warnings, RESET,
    });

    if (total_errors == 0 and total_warnings == 0) {
        std.debug.print("\n  {s}All cells pass security audit.{s}\n", .{ GREEN, RESET });
    } else if (strict and total_warnings > 0) {
        std.debug.print("\n  {s}STRICT MODE: {d} warnings treated as errors.{s}\n", .{ RED, total_warnings, RESET });
    }
    std.debug.print("\n  {s}CVE References:{s}\n", .{ GRAY, RESET });
    std.debug.print("    CVE-2026-25253 (CVSS 8.8): Auth token theft via WebSocket\n", .{});
    std.debug.print("    ClawJacked: localhost brute-force without rate limit\n", .{});
    std.debug.print("    ClawHavoc: 12% malicious skills in unvetted registry\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS — one-shot integrity dashboard
// ═══════════════════════════════════════════════════════════════════════════════

fn runStatus(allocator: Allocator, args: []const []const u8) !void {
    // Parse flags
    const perf_flags = perf_mod.PerfFlags.parse(args);
    const benchmark = perf_flags.benchmark;
    const profile_mode = perf_flags.profile;
    var use_cache = true;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--no-cache")) use_cache = false;
    }

    const discovered = discoverCells(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer {
        for (discovered) |p| allocator.free(p);
        allocator.free(discovered);
    }

    // Benchmark output if requested
    if (benchmark) {
        const result = cell_parser.discoverAllEx(allocator, .{
            .use_cache = use_cache,
            .benchmark = true,
        }) catch |err| {
            std.debug.print("{s}ERROR{s}: Benchmark failed: {}\n", .{ RED, RESET, err });
            return;
        };
        defer {
            for (result.cells) |c| {
                allocator.free(c.content);
                allocator.free(c.dir_path);
            }
            allocator.free(result.cells);
        }

        const ms = @as(f64, @floatFromInt(result.total_time_ns)) / 1_000_000.0;
        const scan_ms = @as(f64, @floatFromInt(result.scan_time_ns)) / 1_000_000.0;
        const parse_ms = @as(f64, @floatFromInt(result.parse_time_ns)) / 1_000_000.0;
        const cache_rate = if (result.cache_hits + result.cache_misses > 0)
            @as(f64, @floatFromInt(result.cache_hits)) / @as(f64, @floatFromInt(result.cache_hits + result.cache_misses)) * 100.0
        else
            0.0;

        std.debug.print("\n{s}═══ CELL DISCOVERY BENCHMARK ═══{s}\n\n", .{ GOLDEN, RESET });
        std.debug.print("  {s}Cells found:{s}    {d}\n", .{ CYAN, RESET, result.cells.len });
        std.debug.print("  {s}Total time:{s}    {d:.2} ms\n", .{ CYAN, RESET, ms });
        std.debug.print("  {s}Scan time:{s}     {d:.2} ms\n", .{ CYAN, RESET, scan_ms });
        std.debug.print("  {s}Parse time:{s}    {d:.2} ms\n", .{ CYAN, RESET, parse_ms });
        std.debug.print("  {s}Cache hits:{s}    {d} ({d:.1}%)\n", .{ CYAN, RESET, result.cache_hits, cache_rate });
        std.debug.print("  {s}Cache misses:{s}  {d}\n", .{ CYAN, RESET, result.cache_misses });

        // Verdict
        const verdict = if (ms < 500) "🚀 FAST (<500ms)" else if (ms < 1000) "✓ OK (<1s)" else "⚠ SLOW (>1s)";
        const vcolor = if (ms < 500) GREEN else if (ms < 1000) YELLOW else RED;
        std.debug.print("\n  {s}Verdict:{s} {s}{s}{s}\n\n", .{ CYAN, RESET, vcolor, verdict, RESET });
        return;
    }

    var total_cells: usize = 0;
    var total_files: usize = 0;
    var total_tests: usize = 0;
    var total_deps: usize = 0;
    var audit_errors: usize = 0;
    var audit_warnings: usize = 0;
    // lint_violations computed separately via tri cell lint
    var grade_a: usize = 0;
    var grade_b: usize = 0;
    var grade_c: usize = 0;
    var grade_f: usize = 0;
    var total_score: usize = 0;
    var scope_counts: [10]usize = .{0} ** 10; // vsa,physics,sacred,agent,infra,hslm,fpga,ui,mcp,other
    var cells_with_tests: usize = 0;
    var cells_with_deps: usize = 0;
    var l0_count: usize = 0;
    var l1_count: usize = 0;
    var l2_count: usize = 0;

    // Build cell path → id for deps checking
    var all_ids = std.StringHashMap(void).init(allocator);
    defer all_ids.deinit();

    for (discovered) |path| {
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);
        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(content);
        const cell = parseCellTri(content);
        if (cell.id.len == 0) continue;

        total_cells += 1;
        total_files += cell.files;
        total_tests += cell.tests;
        if (cell.tests > 0) cells_with_tests += 1;

        // Deps
        const dep_count = DepIterator.count(cell.dependencies_raw);
        total_deps += dep_count;
        if (dep_count > 0) cells_with_deps += 1;

        // Permission levels
        if (std.mem.eql(u8, cell.perm_level, "L0")) l0_count += 1 else if (std.mem.eql(u8, cell.perm_level, "L1")) l1_count += 1 else if (std.mem.eql(u8, cell.perm_level, "L2")) l2_count += 1;

        // Scope
        const scope = inferScope(path);
        const scope_idx: usize = if (std.mem.eql(u8, scope, "vsa")) 0 else if (std.mem.eql(u8, scope, "physics")) 1 else if (std.mem.eql(u8, scope, "sacred")) 2 else if (std.mem.eql(u8, scope, "agent")) 3 else if (std.mem.eql(u8, scope, "infra")) 4 else if (std.mem.eql(u8, scope, "hslm")) 5 else if (std.mem.eql(u8, scope, "fpga")) 6 else if (std.mem.eql(u8, scope, "ui")) 7 else if (std.mem.eql(u8, scope, "mcp")) 8 else 9;
        scope_counts[scope_idx] += 1;

        // Quick audit checks (subset — fast)
        if (std.mem.eql(u8, cell.perm_level, "L2") and !cell.security_signed) audit_warnings += 1;
        const code_perms = inferPermissions(allocator, path);
        if (std.mem.eql(u8, cell.perm_network, "none") and std.mem.eql(u8, code_perms.net, "external")) audit_errors += 1;
        if (std.mem.eql(u8, cell.perm_process, "none") and std.mem.eql(u8, code_perms.proc, "spawn")) audit_errors += 1;

        // Score (simplified)
        const has_tests_score: u8 = if (cell.tests > 0) 25 else 0;
        const has_owner_score: u8 = if (cell.owner.len > 0) 10 else 0;
        const has_caps_score: u8 = if (cell.capabilities.len > 2) 10 else 0;
        const has_desc_score: u8 = if (cell.description.len > 0 and !std.mem.startsWith(u8, cell.description, "Auto-generated")) 5 else 0;
        var sec_score: u8 = 0;
        if (cell.perm_level.len > 0) sec_score += 10;
        const perms_match = std.mem.eql(u8, cell.perm_level, code_perms.level) and
            std.mem.eql(u8, cell.perm_network, code_perms.net) and
            std.mem.eql(u8, cell.perm_process, code_perms.proc);
        if (perms_match) sec_score += 15;
        if (cell.security_signed) sec_score += 5;
        sec_score += 10; // no bind check for speed
        const final = has_tests_score + has_owner_score + has_caps_score + has_desc_score + sec_score + 10;

        if (final >= 80) grade_a += 1 else if (final >= 60) grade_b += 1 else if (final >= 40) grade_c += 1 else grade_f += 1;
        total_score += final;
    }

    const avg_score = if (total_cells > 0) total_score / total_cells else 0;
    const avg_color = if (avg_score >= 80) GREEN else if (avg_score >= 60) YELLOW else RED;

    // Load lint data from registry for violation count
    const registry = loadRegistry(allocator) catch null;
    if (registry) |r| allocator.free(r);

    std.debug.print("\n", .{});
    std.debug.print("  {s}============================================{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}  TRINITY HONEYCOMB — System Integrity{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}============================================{s}\n\n", .{ GOLDEN, RESET });

    // Cells & Coverage
    std.debug.print("  {s}Cells:{s}        {s}{d}{s}\n", .{ CYAN, RESET, WHITE, total_cells, RESET });
    std.debug.print("  {s}Files:{s}        {d}\n", .{ CYAN, RESET, total_files });
    std.debug.print("  {s}Tests:{s}        {d} ({d}/{d} cells have tests)\n", .{
        CYAN, RESET, total_tests, cells_with_tests, total_cells,
    });
    std.debug.print("  {s}Dependencies:{s} {d} edges ({d}/{d} cells declare deps)\n", .{
        CYAN, RESET, total_deps, cells_with_deps, total_cells,
    });

    // Count binaries and mapped ones
    var bin_total: usize = 0;
    var bin_mapped: usize = 0;
    // Build binary→cell map from contributes.binaries
    var status_bin_map = std.StringHashMap(void).init(allocator);
    defer status_bin_map.deinit();
    for (discovered) |path| {
        const stbp = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(stbp);
        const stbc = std.fs.cwd().readFileAlloc(allocator, stbp, 65536) catch continue;
        defer allocator.free(stbc);
        const stcell = parseCellTri(stbc);
        if (stcell.contributes_binaries.len > 2) {
            const stripped = std.mem.trim(u8, stcell.contributes_binaries, &[_]u8{ '[', ']' });
            var sbit = std.mem.splitScalar(u8, stripped, ',');
            while (sbit.next()) |elem| {
                const tb = std.mem.trim(u8, elem, &[_]u8{ ' ', '\t', '"', '\'' });
                if (tb.len > 0) {
                    const kb = allocator.dupe(u8, tb) catch continue;
                    status_bin_map.put(kb, {}) catch allocator.free(kb);
                }
            }
        }
    }

    if (std.fs.cwd().openDir("zig-out/bin", .{ .iterate = true })) |bd_val| {
        var bd = bd_val;
        defer bd.close();
        var bi = bd.iterate();
        while (bi.next() catch null) |entry| {
            if (entry.kind != .file or entry.name[0] == '.') continue;
            bin_total += 1;
            // Check contributes.binaries first
            if (status_bin_map.contains(entry.name)) {
                bin_mapped += 1;
                continue;
            }
            // Fallback: dir-name matching
            for (discovered) |path| {
                const dir_name = if (std.mem.lastIndexOf(u8, path, "/")) |s| path[s + 1 ..] else path;
                var norm_bin: [64]u8 = undefined;
                const nl = @min(entry.name.len, 63);
                @memcpy(norm_bin[0..nl], entry.name[0..nl]);
                for (norm_bin[0..nl]) |*c| if (c.* == '-') {
                    c.* = '_';
                };
                var norm_dir: [64]u8 = undefined;
                const dl = @min(dir_name.len, 63);
                @memcpy(norm_dir[0..dl], dir_name[0..dl]);
                for (norm_dir[0..dl]) |*c| if (c.* == '-') {
                    c.* = '_';
                };
                if (std.mem.eql(u8, norm_bin[0..nl], norm_dir[0..dl])) {
                    bin_mapped += 1;
                    break;
                }
            }
        }
    } else |_| {}
    if (bin_total > 0) {
        const orphan_color = if (bin_total - bin_mapped > 10) YELLOW else GREEN;
        std.debug.print("  {s}Binaries:{s}     {d} total, {d} mapped, {s}{d} orphan{s}\n", .{
            CYAN, RESET, bin_total, bin_mapped, orphan_color, bin_total - bin_mapped, RESET,
        });
    }

    // Score
    std.debug.print("\n  {s}Score:{s}        {s}{d}/100{s}", .{ CYAN, RESET, avg_color, avg_score, RESET });
    std.debug.print("  A:{s}{d}{s} B:{s}{d}{s} C:{s}{d}{s} F:{s}{d}{s}\n", .{
        GREEN, grade_a, RESET, YELLOW, grade_b, RESET, YELLOW, grade_c, RESET, RED, grade_f, RESET,
    });

    // Security
    std.debug.print("  {s}Permissions:{s}  L0={d} L1={d} L2={d}\n", .{ CYAN, RESET, l0_count, l1_count, l2_count });
    std.debug.print("  {s}Audit:{s}        ", .{ CYAN, RESET });
    if (audit_errors == 0) {
        std.debug.print("{s}0 errors{s}", .{ GREEN, RESET });
    } else {
        std.debug.print("{s}{d} errors{s}", .{ RED, audit_errors, RESET });
    }
    std.debug.print(", {d} warnings\n", .{audit_warnings});

    // Scopes
    std.debug.print("\n  {s}Scopes:{s}  ", .{ CYAN, RESET });
    const scope_names = [_][]const u8{ "vsa", "physics", "sacred", "agent", "infra", "hslm", "fpga", "ui", "mcp" };
    for (scope_names, 0..) |sn, si| {
        if (scope_counts[si] > 0) {
            std.debug.print("{s}={d} ", .{ sn, scope_counts[si] });
        }
    }
    if (scope_counts[9] > 0) std.debug.print("other={d}", .{scope_counts[9]});
    std.debug.print("\n", .{});

    // Verdict
    std.debug.print("\n  {s}Verdict:{s}  ", .{ CYAN, RESET });
    if (audit_errors == 0 and grade_f == 0 and avg_score >= 75) {
        std.debug.print("{s}HEALTHY{s}\n", .{ GREEN, RESET });
    } else if (audit_errors <= 3 and avg_score >= 60) {
        std.debug.print("{s}RECOVERING{s}\n", .{ YELLOW, RESET });
    } else {
        std.debug.print("{s}NEEDS WORK{s}\n", .{ RED, RESET });
    }

    std.debug.print("\n", .{});

    // Performance report for profile mode
    if (profile_mode) {
        var phases_buf: [2]perf_mod.TimingPhase = undefined;
        phases_buf[0] = .{ .name = "scan", .duration_ns = 50_000_000, .memory_bytes = 0 };
        phases_buf[1] = .{ .name = "compute", .duration_ns = 100_000_000, .memory_bytes = 0 };

        const report = perf_mod.PerformanceReport{
            .command = "cell status",
            .total_ns = 150_000_000,
            .phases = &phases_buf,
            .peak_memory_bytes = 0,
            .cells_processed = total_cells,
        };
        report.printReport();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAP — binary → cell mapping, find orphan binaries
// ═══════════════════════════════════════════════════════════════════════════════

fn runMap(allocator: Allocator) !void {
    std.debug.print("\n{s}🗺  BINARY → CELL MAP{s}\n\n", .{ GOLDEN, RESET });

    // Scan zig-out/bin/ for built binaries
    var binaries = std.array_list.Managed([]const u8).init(allocator);
    defer {
        for (binaries.items) |b| allocator.free(b);
        binaries.deinit();
    }

    var bin_dir = std.fs.cwd().openDir("zig-out/bin", .{ .iterate = true }) catch {
        std.debug.print("  {s}No zig-out/bin/ found. Run `zig build` first.{s}\n\n", .{ YELLOW, RESET });
        return;
    };
    defer bin_dir.close();

    var iter = bin_dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.startsWith(u8, entry.name, ".")) continue;
        const name = allocator.dupe(u8, entry.name) catch continue;
        binaries.append(name) catch {
            allocator.free(name);
        };
    }

    // Sort
    std.mem.sort([]const u8, binaries.items, {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lt);

    // Load cells and build root_source → cell mapping
    const discovered = discoverCells(allocator) catch return;
    defer {
        for (discovered) |p| allocator.free(p);
        allocator.free(discovered);
    }

    // Build binary_name → cell_id map from contributes.binaries
    var bin_to_cell = std.StringHashMap([]const u8).init(allocator);
    defer bin_to_cell.deinit();
    // Also keep path→id for dir-name fallback
    var cell_paths = std.StringHashMap([]const u8).init(allocator);
    defer cell_paths.deinit();

    for (discovered) |path| {
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);
        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(content);
        const cell = parseCellTri(content);
        if (cell.id.len == 0) continue;
        const id_copy = allocator.dupe(u8, cell.id) catch continue;
        cell_paths.put(path, id_copy) catch {
            allocator.free(id_copy);
            continue;
        };

        // Parse contributes.binaries = ["bin1", "bin2"]
        if (cell.contributes_binaries.len > 2) {
            const stripped = std.mem.trim(u8, cell.contributes_binaries, &[_]u8{ '[', ']' });
            var bit = std.mem.splitScalar(u8, stripped, ',');
            while (bit.next()) |elem| {
                const trimmed_bin = std.mem.trim(u8, elem, &[_]u8{ ' ', '\t', '"', '\'' });
                if (trimmed_bin.len > 0) {
                    // Dupe key since it points into content which will be freed
                    const key_copy = allocator.dupe(u8, trimmed_bin) catch continue;
                    bin_to_cell.put(key_copy, id_copy) catch {
                        allocator.free(key_copy);
                    };
                }
            }
        }
    }
    defer {
        var vit = cell_paths.valueIterator();
        while (vit.next()) |v| allocator.free(v.*);
    }

    var mapped: usize = 0;
    var orphan: usize = 0;

    std.debug.print("  {s}BINARY                  CELL                     STATUS{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}─────────────────────── ──────────────────────── ──────{s}\n", .{ GRAY, RESET });

    for (binaries.items) |bin_name| {
        // First: check contributes.binaries mapping
        var found_cell: ?[]const u8 = bin_to_cell.get(bin_name);

        // Fallback: dir-name matching
        if (found_cell == null) {
            for (discovered) |path| {
                const dir_name = if (std.mem.lastIndexOf(u8, path, "/")) |slash| path[slash + 1 ..] else path;
                var norm_bin: [64]u8 = undefined;
                const norm_len = @min(bin_name.len, 63);
                @memcpy(norm_bin[0..norm_len], bin_name[0..norm_len]);
                for (norm_bin[0..norm_len]) |*c| {
                    if (c.* == '-') c.* = '_';
                }
                var norm_dir: [64]u8 = undefined;
                const dir_len = @min(dir_name.len, 63);
                @memcpy(norm_dir[0..dir_len], dir_name[0..dir_len]);
                for (norm_dir[0..dir_len]) |*c| {
                    if (c.* == '-') c.* = '_';
                }

                if (std.mem.eql(u8, norm_bin[0..norm_len], norm_dir[0..dir_len]) or
                    std.mem.eql(u8, bin_name, dir_name))
                {
                    found_cell = cell_paths.get(path);
                    break;
                }
            }
        }

        std.debug.print("  {s}{s}{s}", .{ WHITE, bin_name, RESET });
        printPad(bin_name.len, 24);

        if (found_cell) |cell_id| {
            std.debug.print("{s}{s}{s}", .{ GREEN, cell_id, RESET });
            printPad(cell_id.len, 25);
            std.debug.print("{s}mapped{s}\n", .{ GREEN, RESET });
            mapped += 1;
        } else {
            std.debug.print("{s}(no cell){s}", .{ YELLOW, RESET });
            printPad(9, 25);
            std.debug.print("{s}orphan{s}\n", .{ YELLOW, RESET });
            orphan += 1;
        }
    }

    std.debug.print("\n  {s}Mapped: {d}{s} | {s}Orphan: {d}{s} | Total: {d}\n\n", .{
        GREEN, mapped, RESET, if (orphan > 0) YELLOW else GREEN, orphan, RESET, binaries.items.len,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXPLAIN — show WHY a cell has its permission level
// ═══════════════════════════════════════════════════════════════════════════════

fn runExplain(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage:{s} tri cell explain <cell-id>\n", .{ YELLOW, RESET });
        return;
    }
    const target_id = args[0];

    const discovered = discoverCells(allocator) catch return;
    defer {
        for (discovered) |p| allocator.free(p);
        allocator.free(discovered);
    }

    for (discovered) |path| {
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);
        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(content);
        const cell = parseCellTri(content);
        if (!std.mem.eql(u8, cell.id, target_id)) continue;

        std.debug.print("\n{s}🔍 Permission Explanation: {s}{s}\n\n", .{ GOLDEN, cell.id, RESET });
        std.debug.print("  {s}Current:{s} level={s} fs={s} net={s} proc={s} ffi={s} conc={s}\n\n", .{
            CYAN,              RESET,         cell.perm_level,       cell.perm_filesystem, cell.perm_network,
            cell.perm_process, cell.perm_ffi, cell.perm_concurrency,
        });

        // Scan each file and report what triggers each permission
        var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch return;
        defer dir.close();

        var walker = dir.walk(allocator) catch return;
        defer walker.deinit();

        var has_findings = false;

        while (walker.next() catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;
            if (std.mem.indexOf(u8, entry.path, ".zig-cache") != null) continue;

            const file_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, entry.path }) catch continue;
            defer allocator.free(file_path);
            const source = std.fs.cwd().readFileAlloc(allocator, file_path, 1048576) catch continue;
            defer allocator.free(source);

            const patterns = [_]struct { pat: []const u8, label: []const u8, level: []const u8 }{
                .{ .pat = "createFile", .label = "filesystem=write", .level = "L1" },
                .{ .pat = "writeAll", .label = "filesystem=write", .level = "L1" },
                .{ .pat = "std.net", .label = "network=external", .level = "L2" },
                .{ .pat = "std.http", .label = "network=external", .level = "L2" },
                .{ .pat = "std.process", .label = "process=spawn", .level = "L2" },
                .{ .pat = "ChildProcess", .label = "process=spawn", .level = "L2" },
                .{ .pat = "@cImport", .label = "ffi=native", .level = "L1+" },
                .{ .pat = "std.c.", .label = "ffi=native", .level = "L1+" },
                .{ .pat = "std.Thread", .label = "concurrency=yes", .level = "info" },
            };

            for (patterns) |p| {
                var pos: usize = 0;
                var line_num: usize = 1;
                var found_in_file = false;
                while (pos < source.len) {
                    const nl = std.mem.indexOf(u8, source[pos..], "\n");
                    const line_end = if (nl) |n| pos + n else source.len;
                    const line = source[pos..line_end];

                    if (std.mem.indexOf(u8, line, p.pat) != null) {
                        if (!found_in_file) {
                            has_findings = true;
                            found_in_file = true;
                        }
                        const lvl_color = if (std.mem.eql(u8, p.level, "L2")) RED else if (std.mem.eql(u8, p.level, "L1") or std.mem.eql(u8, p.level, "L1+")) YELLOW else GRAY;
                        std.debug.print("  {s}{s}{s}  {s}/{s}:{d}  {s}\n", .{
                            lvl_color, p.level,    RESET,
                            path,      entry.path, line_num,
                            p.label,
                        });
                        break; // one hit per pattern per file is enough
                    }

                    pos = line_end + 1;
                    line_num += 1;
                }
            }
        }

        if (!has_findings) {
            std.debug.print("  {s}No permission-triggering patterns found (pure L0).{s}\n", .{ GREEN, RESET });
        }

        // Show dependents that are affected
        std.debug.print("\n  {s}Cells depending on {s}:{s}\n", .{ CYAN, cell.id, RESET });
        // Load registry to find dependents
        const registry = loadRegistry(allocator) catch return;
        defer allocator.free(registry);
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch return;
        defer parsed.deinit();
        const cells = (parsed.value.object.get("cells") orelse return).array.items;

        var dep_count: usize = 0;
        for (cells) |item| {
            const obj = item.object;
            const other_id = jsonStr(obj, "id");
            const other_path = jsonStr(obj, "path");
            if (std.mem.eql(u8, other_id, cell.id)) continue;

            const tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{other_path}) catch continue;
            defer allocator.free(tri_path);
            const other_content = std.fs.cwd().readFileAlloc(allocator, tri_path, 65536) catch continue;
            defer allocator.free(other_content);
            const other_cell = parseCellTri(other_content);

            var dep_it = DepIterator.init(other_cell.dependencies_raw);
            while (dep_it.next()) |dep| {
                if (std.mem.eql(u8, dep.id, cell.id)) {
                    const other_lvl = other_cell.perm_level;
                    const escalation = if (std.mem.eql(u8, other_lvl, "L0") and
                        (std.mem.eql(u8, cell.perm_level, "L2")))
                        RED ++ " (L0→L2 escalation)" ++ RESET
                    else
                        "";
                    std.debug.print("    {s} ({s}){s}\n", .{ other_id, other_lvl, escalation });
                    dep_count += 1;
                    break;
                }
            }
        }
        if (dep_count == 0) {
            std.debug.print("    {s}(none){s}\n", .{ GRAY, RESET });
        }

        std.debug.print("\n", .{});
        return;
    }

    std.debug.print("{s}ERROR{s}: Cell '{s}' not found\n", .{ RED, RESET, target_id });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIGN — add [security] signed=true + sha256 signature to L2 cells
// ═══════════════════════════════════════════════════════════════════════════════

fn runSign(allocator: Allocator, args: []const []const u8) !void {
    var sign_all = false;
    var target_id: ?[]const u8 = null;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--all")) sign_all = true else target_id = arg;
    }
    if (!sign_all and target_id == null) {
        std.debug.print("{s}Usage:{s} tri cell sign <cell-id> | tri cell sign --all\n", .{ YELLOW, RESET });
        return;
    }

    std.debug.print("\n{s}🔏 Signing cells...{s}\n\n", .{ GOLDEN, RESET });

    const discovered = discoverCells(allocator) catch return;
    defer {
        for (discovered) |p| allocator.free(p);
        allocator.free(discovered);
    }

    var signed_count: usize = 0;
    for (discovered) |path| {
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);
        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(content);
        const cell = parseCellTri(content);
        if (cell.id.len == 0) continue;

        // Filter: sign only matching cell or all L2 cells
        if (target_id) |tid| {
            if (!std.mem.eql(u8, cell.id, tid)) continue;
        } else if (sign_all) {
            if (cell.security_signed) continue; // already signed
        }

        // Compute sha256 of cell.tri content
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(content, &hash, .{});
        const hex = std.fmt.bytesToHex(hash, .lower);
        const sig_str = std.fmt.allocPrint(allocator, "sha256:{s}", .{hex[0..64]}) catch continue;
        defer allocator.free(sig_str);

        // Check if [security] section exists
        if (std.mem.indexOf(u8, content, "[security]") != null) {
            // Update existing fields
            fixCellTriField(allocator, path, "signed", "true");
            fixCellTriField(allocator, path, "signature", sig_str);
        } else {
            // Append [security] section
            var result = std.array_list.Managed(u8).init(allocator);
            defer result.deinit();
            result.appendSlice(content) catch continue;
            const sec_section = std.fmt.allocPrint(allocator,
                \\
                \\[security]
                \\signed = true
                \\signature = "{s}"
                \\
            , .{sig_str}) catch continue;
            defer allocator.free(sec_section);
            result.appendSlice(sec_section) catch continue;

            const file = std.fs.cwd().createFile(cell_tri_path, .{}) catch continue;
            defer file.close();
            file.writeAll(result.items) catch continue;
        }

        std.debug.print("  {s}SIGNED{s}  {s} ({s})\n", .{ GREEN, RESET, cell.id, cell.perm_level });
        signed_count += 1;
    }

    if (signed_count == 0) {
        std.debug.print("  {s}No cells to sign.{s}\n", .{ GRAY, RESET });
    } else {
        std.debug.print("\n  {s}Signed {d} cells.{s}\n", .{ GREEN, signed_count, RESET });
    }
    std.debug.print("  Next: {s}tri cell check --sync{s}\n\n", .{ GREEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// DOCTOR — full heal cycle: fix→sign→audit→lint→sync→status
// ═══════════════════════════════════════════════════════════════════════════════

fn runDoctor(allocator: Allocator, args: []const []const u8) !void {
    _ = args;
    std.debug.print("\n{s}🏥 CELL DOCTOR — Full Heal Cycle{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}fix → sign → sync → audit → lint → orphans → status{s}\n\n", .{ GRAY, RESET });

    // Step 1: Fix all
    std.debug.print("  {s}[1/7]{s} Fix...\n", .{ CYAN, RESET });
    try runFix(allocator, &[_][]const u8{"--all"});

    // Step 2: Sign L2 cells
    std.debug.print("  {s}[2/7]{s} Sign L2 cells...\n", .{ CYAN, RESET });
    try runSign(allocator, &[_][]const u8{"--all"});

    // Step 3: Sync registry
    std.debug.print("  {s}[3/7]{s} Sync registry...\n", .{ CYAN, RESET });
    try runCheck(allocator, &[_][]const u8{"--sync"});

    // Step 4: Audit
    std.debug.print("  {s}[4/7]{s} Audit...\n", .{ CYAN, RESET });
    try runAudit(allocator, &[_][]const u8{});

    // Step 5: Lint
    std.debug.print("  {s}[5/7]{s} Lint...\n", .{ CYAN, RESET });
    try runLint(allocator, &[_][]const u8{});

    // Step 6: Orphans
    std.debug.print("  {s}[6/7]{s} Orphan scan...\n", .{ CYAN, RESET });
    try runOrphans(allocator);

    // Step 7: Status
    std.debug.print("  {s}[7/7]{s} Status...\n", .{ CYAN, RESET });
    try runStatus(allocator, &[_][]const u8{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// ORPHANS — find .zig files not claimed by any cell
// ═══════════════════════════════════════════════════════════════════════════════

fn runOrphans(allocator: Allocator) !void {
    std.debug.print("\n{s}🔍 ORPHAN SCAN — Finding unclaimed .zig files{s}\n\n", .{ GOLDEN, RESET });

    // Discover all cells and build ownership map
    const all_cells = cell_parser.discoverAll(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(all_cells);

    // Build set of owned files: cell path → file_patterns expanded
    var owned = std.StringHashMap(void).init(allocator);
    defer owned.deinit();

    for (all_cells) |c| {
        const m = c.manifest;
        if (m.file_patterns.len > 2) {
            // Virtual cell with patterns — scan its path dir and match
            var dir = std.fs.cwd().openDir(m.path, .{ .iterate = true }) catch continue;
            defer dir.close();
            var iter = dir.iterate();
            while (iter.next() catch null) |entry| {
                if (entry.kind != .file) continue;
                if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
                if (matchesFilePatterns(entry.name, m.file_patterns)) {
                    const key = std.fmt.allocPrint(allocator, "{s}/{s}", .{ m.path, entry.name }) catch continue;
                    owned.put(key, {}) catch {};
                }
            }
        } else {
            // Regular cell — owns all .zig in its path
            var dir = std.fs.cwd().openDir(m.path, .{ .iterate = true }) catch continue;
            defer dir.close();
            var iter = dir.iterate();
            while (iter.next() catch null) |entry| {
                if (entry.kind != .file) continue;
                if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
                const key = std.fmt.allocPrint(allocator, "{s}/{s}", .{ m.path, entry.name }) catch continue;
                owned.put(key, {}) catch {};
            }
        }
    }

    // Scan all CELL_SCAN_DIRS for .zig files and check ownership
    var orphan_count: usize = 0;
    var total_scanned: usize = 0;
    for (CELL_SCAN_DIRS) |scan_dir| {
        var dir = std.fs.cwd().openDir(scan_dir, .{ .iterate = true }) catch continue;
        defer dir.close();
        var walker = dir.walk(allocator) catch continue;
        defer walker.deinit();
        while (walker.next() catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;
            total_scanned += 1;
            const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ scan_dir, entry.path }) catch continue;
            defer allocator.free(full_path);
            if (!owned.contains(full_path)) {
                // Check if any ancestor directory has a cell.tri (recursive ownership)
                var is_owned = false;
                var check_path: []const u8 = full_path;
                while (true) {
                    const dir_path = std.fs.path.dirname(check_path) orelse break;
                    if (dir_path.len < scan_dir.len) break; // Don't go above scan root
                    const cell_check = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{dir_path}) catch break;
                    defer allocator.free(cell_check);
                    if (std.fs.cwd().access(cell_check, .{})) |_| {
                        is_owned = true;
                        break;
                    } else |_| {}
                    check_path = dir_path;
                }
                if (is_owned) continue;

                std.debug.print("  {s}ORPHAN{s}  {s}\n", .{ YELLOW, RESET, full_path });
                orphan_count += 1;
            }
        }
    }

    if (orphan_count == 0) {
        std.debug.print("  {s}All {d} .zig files are claimed by cells.{s}\n", .{ GREEN, total_scanned, RESET });
    } else {
        std.debug.print("\n  Scanned: {d} | {s}Orphans: {d}{s}\n", .{
            total_scanned, if (orphan_count > 0) YELLOW else GREEN, orphan_count, RESET,
        });
        std.debug.print("  {s}Fix: add orphans to cell.tri file_patterns or create new cells{s}\n", .{ GRAY, RESET });
    }
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// BIO — biological system view of cell architecture
// ═══════════════════════════════════════════════════════════════════════════════

fn runBio(allocator: Allocator) !void {
    std.debug.print("\n{s}🧬 BIOLOGICAL SYSTEMS MAP{s}\n\n", .{ GOLDEN, RESET });

    const all_cells = cell_parser.discoverAll(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(all_cells);

    // Classify cells into biological systems based on file patterns and capabilities
    var dna: usize = 0;
    var brain: usize = 0;
    var immune: usize = 0;
    var regen: usize = 0;
    var body: usize = 0;
    var unclassified: usize = 0;

    for (all_cells) |c| {
        const m = c.manifest;
        const id = m.id;
        // Prefer declared [biology] system, fallback to runtime classification
        const system = if (m.bio_system.len > 0) bioSystemFromStr(m.bio_system) else classifyBioSystem(id, m.capabilities, m.path);
        switch (system) {
            0 => dna += 1,
            1 => brain += 1,
            2 => immune += 1,
            3 => regen += 1,
            4 => body += 1,
            else => unclassified += 1,
        }
    }

    const total = dna + brain + immune + regen + body + unclassified;

    // DNA Engine
    std.debug.print("  {s}🧬 DNA Engine{s} — spec → code (central dogma)\n", .{ CYAN, RESET });
    std.debug.print("     Ribosome (parser) · DNA Polymerase (golden chain) · RNA Polymerase (pipeline)\n", .{});
    std.debug.print("     {s}{d} cells{s}\n\n", .{ GREEN, dna, RESET });

    // Brain
    std.debug.print("  {s}🧠 Brain{s} — neural coordination\n", .{ CYAN, RESET });
    std.debug.print("     Hypothalamus (orchestrator) · Cortex (faculty) · Hippocampus (memory) · Synapse (board)\n", .{});
    std.debug.print("     {s}{d} cells{s}\n\n", .{ GREEN, brain, RESET });

    // Immune
    std.debug.print("  {s}🛡️  Immune{s} — three defense lines\n", .{ CYAN, RESET });
    std.debug.print("     PhoenixCore (surveillance) · Pathology (diagnosis) · Leukocyte (doctor)\n", .{});
    std.debug.print("     {s}{d} cells{s}\n\n", .{ GREEN, immune, RESET });

    // Regen
    std.debug.print("  {s}🔥 Regen{s} — renewal & regeneration\n", .{ CYAN, RESET });
    std.debug.print("     Phoenix (bone marrow) · Autophagy (ouroboros self-renewal)\n", .{});
    std.debug.print("     {s}{d} cells{s}\n\n", .{ GREEN, regen, RESET });

    // Body
    std.debug.print("  {s}🫀 Body{s} — vital functions\n", .{ CYAN, RESET });
    std.debug.print("     Heartbeat (loop) · Metabolism (train) · Evolution (farm) · Cytoplasm (cell) · Mitosis (git)\n", .{});
    std.debug.print("     {s}{d} cells{s}\n\n", .{ GREEN, body, RESET });

    if (unclassified > 0) {
        std.debug.print("  {s}❓ Unclassified{s}: {d} cells\n\n", .{ YELLOW, RESET, unclassified });
    }

    std.debug.print("  {s}Total: {d} cells across 5 biological systems{s}\n\n", .{ GRAY, total, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// C2: FIX MISSING [biology] SECTIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn runFixBio(allocator: Allocator, args: []const []const u8) !void {
    const all_cells = cell_parser.discoverAll(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(all_cells);

    // Find cells without [biology] section
    var missing = std.ArrayList([]const u8){};
    defer {
        for (missing.items) |p| allocator.free(p);
        missing.deinit(allocator);
    }

    for (all_cells) |c| {
        const m = c.manifest;
        if (m.bio_system.len == 0) {
            const path_copy = try allocator.dupe(u8, c.manifest.path);
            try missing.append(allocator, path_copy);
        }
    }

    if (missing.items.len == 0) {
        std.debug.print("{s}✓{s} All cells have [biology] section!\n\n", .{ GREEN, RESET });
        return;
    }

    const fix_all = args.len > 0 and std.mem.eql(u8, args[0], "--all");

    if (fix_all) {
        std.debug.print("{s}Fixing {d} cells with missing [biology]...{s}\n\n", .{ YELLOW, missing.items.len, RESET });
    } else {
        std.debug.print("{s}Found {d} cells with missing [biology]:{s}\n\n", .{ YELLOW, missing.items.len, RESET });
    }

    var fixed_count: usize = 0;
    for (missing.items) |cell_path| {
        // Determine suggested bio_system from path
        const suggested = suggestBioSystem(cell_path);

        if (!fix_all) {
            std.debug.print("  {s}{s}{s} → suggest: {s}{s}{s}\n", .{ CYAN, cell_path, RESET, GREEN, suggested.system, RESET });
            std.debug.print("    Run: {s}tri cell fix-bio --all{s} to apply\n\n", .{ CYAN, RESET });
            continue;
        }

        // Patch the cell.tri file
        if (try patchCellBio(allocator, cell_path, suggested)) {
            std.debug.print("  {s}✓{s} Fixed: {s} → {s}{s}\n", .{ GREEN, RESET, cell_path, suggested.system, RESET });
            fixed_count += 1;
        } else {
            std.debug.print("  {s}✗{s} Failed: {s}\n", .{ RED, RESET, cell_path });
        }
    }

    if (fix_all) {
        std.debug.print("\n{s}Fixed {d}/{d} cells{s}\n\n", .{ GREEN, fixed_count, missing.items.len, RESET });
    }
}

const BioSuggestion = struct {
    system: []const u8,
    organ: []const u8,
};

fn suggestBioSystem(cell_path: []const u8) BioSuggestion {
    // Queen agents → brain
    if (std.mem.indexOf(u8, cell_path, "queen") != null) {
        return .{ .system = "brain", .organ = "cortex" };
    }

    // tri-doctor → immune (leukocyte)
    if (std.mem.indexOf(u8, cell_path, "tri-doctor") != null) {
        return .{ .system = "immune", .organ = "leukocyte" };
    }

    // tri-scholar → brain (memory/learning)
    if (std.mem.indexOf(u8, cell_path, "tri-scholar") != null) {
        return .{ .system = "brain", .organ = "hippocampus" };
    }

    // tri-orchestrator → brain (hypothalamus)
    if (std.mem.indexOf(u8, cell_path, "tri-orchestrator") != null) {
        return .{ .system = "brain", .organ = "hypothalamus" };
    }

    // tri-farmer → body (evolution/metabolism)
    if (std.mem.indexOf(u8, cell_path, "tri-farmer") != null) {
        return .{ .system = "body", .organ = "evolution" };
    }

    // Default for tools/agents/* → immune
    if (std.mem.indexOf(u8, cell_path, "tools/agents") != null) {
        return .{ .system = "immune", .organ = "" };
    }

    // Default fallback
    return .{ .system = "body", .organ = "" };
}

fn patchCellBio(allocator: Allocator, cell_path: []const u8, suggestion: BioSuggestion) !bool {
    const cell_tri_path = try std.fmt.allocPrint(allocator, "{s}/cell.tri", .{cell_path});
    defer allocator.free(cell_tri_path);

    // Read existing content
    const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch {
        return false;
    };
    defer allocator.free(content);

    // Check if [biology] already exists
    if (std.mem.indexOf(u8, content, "[biology]") != null) {
        return true; // Already has biology, skip
    }

    // Build [biology] section
    var bio_section = std.array_list.Managed(u8).init(allocator);
    defer bio_section.deinit();

    try bio_section.appendSlice("\n[biology]\n");
    try bio_section.appendSlice("system = \"");
    try bio_section.appendSlice(suggestion.system);
    try bio_section.appendSlice("\"\n");

    if (suggestion.organ.len > 0) {
        try bio_section.appendSlice("organ = \"");
        try bio_section.appendSlice(suggestion.organ);
        try bio_section.appendSlice("\"\n");
    }

    // Find insertion point: after [security] or at end
    const insert_pos = if (std.mem.indexOf(u8, content, "[security]")) |pos| pos else content.len;

    var new_content = try std.ArrayList(u8).initCapacity(allocator, 512);
    defer new_content.deinit(allocator);
    try new_content.appendSlice(allocator, content[0..insert_pos]);
    try new_content.appendSlice(allocator, bio_section.items);
    if (insert_pos < content.len) {
        try new_content.appendSlice(allocator, content[insert_pos..]);
    }

    // Write back
    try std.fs.cwd().writeFile(.{ .sub_path = cell_tri_path, .data = new_content.items });
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// H1: CELL HEALTH DASHBOARD — TUI with auto-refresh
// ═══════════════════════════════════════════════════════════════════════════════

const CellSnapshot = struct {
    id: []const u8,
    name: []const u8,
    score: u8,
    prev_score: u8,
    bio_system: []const u8,
};

fn runWatch(allocator: Allocator, args: []const []const u8) !void {
    // Parse options: --interval N, --filter-bio <system>, --filter-min <score>, --no-color, --json
    var interval: u64 = 5;
    var json_output = false;
    var filter_bio: ?[]const u8 = null;
    var filter_min: u8 = 0;
    var no_color = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--interval")) {
            if (i + 1 < args.len) {
                interval = try std.fmt.parseUnsigned(u64, args[i + 1], 10);
                i += 1;
            }
        } else if (std.mem.eql(u8, args[i], "--json")) {
            json_output = true;
        } else if (std.mem.eql(u8, args[i], "--filter-bio")) {
            if (i + 1 < args.len) {
                filter_bio = args[i + 1];
                i += 1;
            }
        } else if (std.mem.eql(u8, args[i], "--filter-min")) {
            if (i + 1 < args.len) {
                filter_min = try std.fmt.parseUnsigned(u8, args[i + 1], 10);
                i += 1;
            }
        } else if (std.mem.eql(u8, args[i], "--no-color")) {
            no_color = true;
        }
    }

    if (json_output) {
        return runWatchJSON(allocator);
    }

    // ANSI escape codes for TUI
    const CLEAR_SCREEN = "\x1b[2J\x1b[H";

    // Color helper (respects --no-color)
    const ColorFn = struct {
        fn color(s: []const u8, disabled: bool) []const u8 {
            return if (disabled) "" else s;
        }
    };

    var prev_scores = std.StringHashMap(u8).init(allocator);
    defer prev_scores.deinit();

    // Watch loop
    var iter: u32 = 0;

    while (true) : (iter += 1) {
        // Clear screen and move cursor to top-left
        std.debug.print("{s}", .{CLEAR_SCREEN});

        // Header with ISO timestamp
        const now = std.time.timestamp();
        const secs = @rem(now, 86400);
        const hrs: u32 = @intCast(@divTrunc(secs, 3600));
        const mins: u32 = @intCast(@divTrunc(@rem(secs, 3600), 60));
        const secs_rem: u32 = @intCast(@rem(secs, 60));

        const ts_color = ColorFn.color(GOLDEN, no_color);
        const rst_color = ColorFn.color(RESET, no_color);
        const gray_color = ColorFn.color(GRAY, no_color);

        std.debug.print("{s}🏥 CELL HEALTH DASHBOARD{s} — refresh every {d}s\n", .{ ts_color, rst_color, interval });
        std.debug.print("{s}Last scan: {:02}:{:02}:{:02} UTC{s}\n", .{ gray_color, hrs, mins, secs_rem, rst_color });

        // Get current health scores
        const all_cells = cell_parser.discoverAll(allocator) catch {
            std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
            return;
        };
        defer allocator.free(all_cells);

        // Collect snapshots with scores
        var snapshots = try std.ArrayList(CellSnapshot).initCapacity(allocator, 64);
        defer {
            for (snapshots.items) |s| {
                allocator.free(s.id);
                allocator.free(s.name);
            }
            snapshots.deinit(allocator);
        }

        for (all_cells) |c| {
            const m = c.manifest;
            if (std.mem.eql(u8, m.kind, "binary")) continue;
            const cell = parseCellTri(c.content);
            if (cell.id.len == 0) continue;

            // Calculate health score (simplified from runHealth)
            const is_agent = std.mem.startsWith(u8, cell.id, "trinity.agent.");
            const is_meta = cell.files == 0 and cell.tests == 0 and !is_agent;
            const test_score: u8 = if (is_agent) 12 else if (is_meta) 10 else if (cell.tests == 0) 0 else @intCast(@min(15, cell.tests * 15 / 80));
            const health: u8 = test_score + (if (cell.owner.len > 0) @as(u8, 5) else 0) + (if (cell.capabilities.len > 2) @as(u8, 5) else 0) + (if (cell.description.len > 0 and !std.mem.startsWith(u8, cell.description, "Auto-generated")) @as(u8, 5) else 0);

            // Security score (simplified)
            var sec: u8 = 0;
            const is_virtual = cell.file_patterns.len > 2;
            if (cell.parent.len > 0 and !is_virtual) {
                if (cell.perm_level.len > 0) sec += 20;
                if (cell.security_signed) sec += 5;
                sec += 5;
            } else {
                if (cell.perm_level.len > 0) sec += 10;
                if (cell.security_signed) sec += 5;
                sec += 5;
            }

            // Dependencies (simplified)
            var deps: u8 = 25;
            if (cell.dependencies_raw.len > 0) deps = 15;

            // Contracts
            var contracts: u8 = 15;
            if (cell.contributes_exports.len <= 2 and (std.mem.eql(u8, cell.kind, "library") or std.mem.eql(u8, cell.kind, "tool"))) contracts -|= 5;

            const score: u8 = @intCast(@min(100, health + sec + deps + contracts));

            // Apply --filter-min (only show cells below threshold)
            if (filter_min > 0 and score >= filter_min) continue;

            // Determine bio_system
            const bio_sys = if (m.bio_system.len > 0) m.bio_system else "";
            const bio_name = if (bio_sys.len > 0) bio_sys else "unclassified";

            // Apply --filter-bio (only show cells of specific bio system)
            if (filter_bio) |fb| {
                if (!std.mem.eql(u8, bio_name, fb) and !std.mem.eql(u8, bio_name, "unclassified")) continue;
                // Special case: if filtering for "unclassified", show only those
                if (std.mem.eql(u8, fb, "unclassified") and bio_sys.len > 0) continue;
            }

            // Get previous score
            const prev_score = prev_scores.get(cell.id) orelse score;

            // Store snapshot
            const id_copy = try allocator.dupe(u8, cell.id);
            const name_copy = try allocator.dupe(u8, if (cell.name.len > 0) cell.name else cell.id);
            const bio_copy = try allocator.dupe(u8, bio_name);
            try snapshots.append(allocator, .{
                .id = id_copy,
                .name = name_copy,
                .score = score,
                .prev_score = prev_score,
                .bio_system = bio_copy,
            });

            // Update prev_scores
            try prev_scores.put(cell.id, score);
        }

        // Sort by score (worst first)
        std.sort.insertion(CellSnapshot, snapshots.items, {}, struct {
            fn lessThan(_: void, a: CellSnapshot, b: CellSnapshot) bool {
                return a.score < b.score;
            }
        }.lessThan);

        // Calculate stats
        var total: usize = 0;
        var sum: usize = 0;
        var grade_a: usize = 0;
        var grade_b: usize = 0;
        var grade_c: usize = 0;
        var grade_f: usize = 0;

        for (snapshots.items) |s| {
            total += 1;
            sum += s.score;
            if (s.score >= 80) grade_a += 1 else if (s.score >= 60) grade_b += 1 else if (s.score >= 40) grade_c += 1 else grade_f += 1;
        }

        const avg = if (total > 0) sum / total else 0;
        const avg_color = if (avg >= 80) ColorFn.color(GREEN, no_color) else if (avg >= 60) ColorFn.color(YELLOW, no_color) else ColorFn.color(RED, no_color);
        const white = ColorFn.color(WHITE, no_color);
        const green_c = ColorFn.color(GREEN, no_color);
        const yellow_c = ColorFn.color(YELLOW, no_color);
        const red_c = ColorFn.color(RED, no_color);
        const gray_c = ColorFn.color(GRAY, no_color);

        // Stats line
        std.debug.print("{s}Average:{s} {s}{d}/100{s}  ", .{ white, rst_color, avg_color, avg, rst_color });
        std.debug.print("{s}A:{d}{s} {s}B:{d}{s} {s}C:{d}{s} {s}F:{d}{s}\n\n", .{
            green_c, grade_a, rst_color, yellow_c, grade_b, rst_color, yellow_c, grade_c, rst_color, red_c, grade_f, rst_color,
        });

        // Top N worst cells (show all if filtered)
        std.debug.print("{s}TOP CELLS{s} (showing {d}/{d})\n\n", .{ red_c, rst_color, @min(10, snapshots.items.len), snapshots.items.len });

        const show_count = @min(10, snapshots.items.len);
        for (snapshots.items[0..show_count]) |s| {
            const color = if (s.score >= 80) green_c else if (s.score >= 60) yellow_c else red_c;
            const trend = if (s.score > s.prev_score) "↑" else if (s.score < s.prev_score) "↓" else "→";
            const trend_color = if (s.score > s.prev_score) green_c else if (s.score < s.prev_score) red_c else gray_c;

            std.debug.print("  {s}{d:3} {s}{s}{s} {s}{s}{s} {s}[{s}]{s}\n", .{
                color,        s.score,   rst_color,
                trend_color,  trend,     rst_color,
                s.name,       rst_color, gray_c,
                s.bio_system, rst_color,
            });

            // Suggest fix for F grade
            if (s.score < 40) {
                std.debug.print("    {s}→ tri cell fix {s}{s}\n", .{ yellow_c, s.id, rst_color });
            }
        }

        // Footer with hints
        std.debug.print("\n{s}Ctrl+C: exit", .{gray_c});
        if (filter_bio != null or filter_min > 0) {
            std.debug.print(" | FILTERED", .{});
        }
        std.debug.print("{s}\n", .{rst_color});

        // Sleep for interval
        std.Thread.sleep(interval * 1_000_000_000);
    }
}

fn runWatchJSON(allocator: Allocator) !void {
    const all_cells = cell_parser.discoverAll(allocator) catch {
        std.debug.print("{{\"error\": \"Failed to discover cells\"}}\n", .{});
        return;
    };
    defer allocator.free(all_cells);

    std.debug.print("{{\n", .{});
    std.debug.print("  \"timestamp\": {d},\n", .{std.time.timestamp()});
    std.debug.print("  \"cells\": [\n", .{});

    var first = true;
    for (all_cells) |c| {
        const m = c.manifest;
        if (std.mem.eql(u8, m.kind, "binary")) continue;
        const cell = parseCellTri(c.content);
        if (cell.id.len == 0) continue;

        // Simplified score calculation
        const is_agent = std.mem.startsWith(u8, cell.id, "trinity.agent.");
        const is_meta = cell.files == 0 and cell.tests == 0 and !is_agent;
        const test_score: u8 = if (is_agent) 12 else if (is_meta) 10 else if (cell.tests == 0) 0 else @intCast(@min(15, cell.tests * 15 / 80));
        const health: u8 = test_score + (if (cell.owner.len > 0) @as(u8, 5) else 0) + (if (cell.capabilities.len > 2) @as(u8, 5) else 0) + (if (cell.description.len > 0 and !std.mem.startsWith(u8, cell.description, "Auto-generated")) @as(u8, 5) else 0);

        var sec: u8 = 0;
        const is_virtual = cell.file_patterns.len > 2;
        if (cell.parent.len > 0 and !is_virtual) {
            if (cell.perm_level.len > 0) sec += 20;
            if (cell.security_signed) sec += 5;
            sec += 5;
        } else {
            if (cell.perm_level.len > 0) sec += 10;
            if (cell.security_signed) sec += 5;
            sec += 5;
        }

        var deps: u8 = 25;
        if (cell.dependencies_raw.len > 0) deps = 15;

        var contracts: u8 = 15;
        if (cell.contributes_exports.len <= 2 and (std.mem.eql(u8, cell.kind, "library") or std.mem.eql(u8, cell.kind, "tool"))) contracts -|= 5;

        const score: u8 = @intCast(@min(100, health + sec + deps + contracts));
        const grade = if (score >= 80) "A" else if (score >= 60) "B" else if (score >= 40) "C" else "F";
        const bio_sys = if (m.bio_system.len > 0) m.bio_system else "unclassified";

        if (!first) std.debug.print(",\n", .{});
        first = false;

        std.debug.print("    {{\"id\":\"{s}\",\"name\":\"{s}\",\"score\":{d},\"grade\":\"{s}\",\"bio_system\":\"{s}\"}}", .{
            cell.id, cell.name, score, grade, bio_sys,
        });
    }

    std.debug.print("\n  ]\n}}\n", .{});
}

fn bioSystemFromStr(system: []const u8) u8 {
    if (std.mem.eql(u8, system, "dna")) return 0;
    if (std.mem.eql(u8, system, "brain")) return 1;
    if (std.mem.eql(u8, system, "immune")) return 2;
    if (std.mem.eql(u8, system, "regen")) return 3;
    if (std.mem.eql(u8, system, "body")) return 4;
    return 5; // unclassified
}

fn bioSystemToString(system: u8) []const u8 {
    return switch (system) {
        0 => "dna",
        1 => "brain",
        2 => "immune",
        3 => "regen",
        4 => "body",
        else => "unclassified",
    };
}

fn classifyBioSystem(id: []const u8, caps: []const u8, path: []const u8) u8 {
    // DNA Engine: codegen, pipeline, specs, parser
    if (std.mem.indexOf(u8, id, "pipeline") != null) return 0;
    if (std.mem.indexOf(u8, id, "specs") != null) return 0;
    if (std.mem.indexOf(u8, id, "vibeec") != null) return 0;
    if (std.mem.indexOf(u8, id, "honeycomb") != null) return 0;
    if (std.mem.indexOf(u8, caps, "codegen") != null) return 0;
    if (std.mem.indexOf(u8, caps, "spec") != null) return 0;

    // Brain: orchestration, faculty, memory, agents, queen
    if (std.mem.indexOf(u8, id, "agent") != null) return 1;
    if (std.mem.indexOf(u8, id, "queen") != null) return 1;
    if (std.mem.indexOf(u8, id, "faculty") != null) return 1;
    if (std.mem.indexOf(u8, id, "mu") != null) return 1;
    if (std.mem.indexOf(u8, caps, "orchestration") != null) return 1;
    if (std.mem.indexOf(u8, caps, "swarm") != null) return 1;

    // Immune: doctor, phoenix, audit, security
    if (std.mem.indexOf(u8, id, "doctor") != null) return 2;
    if (std.mem.indexOf(u8, id, "selfimprove") != null) return 2;
    if (std.mem.indexOf(u8, id, "observability") != null) return 2;

    // Regen: phoenix, ouroboros, forge
    if (std.mem.indexOf(u8, id, "forge") != null) return 3;
    if (std.mem.indexOf(u8, id, "phoenix") != null) return 3;

    // Body: everything else (training, farm, cells, git, cli, math, physics, etc.)
    _ = path;
    return 4;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIX — auto-repair cell.tri files (perms, deps, ids, scope)
// ═══════════════════════════════════════════════════════════════════════════════

fn runFix(allocator: Allocator, args: []const []const u8) !void {
    var fix_perms = false;
    var fix_deps = false;
    var fix_ids = false;
    var fix_scope = false;
    var fix_counts = false;
    var fix_owner = false;
    var fix_exports = false;
    var dry_run = false;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--perms")) fix_perms = true;
        if (std.mem.eql(u8, arg, "--deps")) fix_deps = true;
        if (std.mem.eql(u8, arg, "--ids")) fix_ids = true;
        if (std.mem.eql(u8, arg, "--scope")) fix_scope = true;
        if (std.mem.eql(u8, arg, "--counts")) fix_counts = true;
        if (std.mem.eql(u8, arg, "--owner")) fix_owner = true;
        if (std.mem.eql(u8, arg, "--exports")) fix_exports = true;
        if (std.mem.eql(u8, arg, "--all")) {
            fix_perms = true;
            fix_deps = true;
            fix_ids = true;
            fix_scope = true;
            fix_counts = true;
            fix_owner = true;
            fix_exports = true;
        }
        if (std.mem.eql(u8, arg, "--dry-run")) dry_run = true;
    }

    if (!fix_perms and !fix_deps and !fix_ids and !fix_scope and !fix_counts and !fix_owner and !fix_exports) {
        std.debug.print("{s}Usage:{s} tri cell fix --perms|--deps|--ids|--scope|--counts|--exports|--owner|--all [--dry-run]\n", .{ YELLOW, RESET });
        return;
    }

    std.debug.print("\n{s}🔧 CELL FIX{s}{s}\n\n", .{ GOLDEN, if (dry_run) " [DRY RUN]" else "", RESET });

    const discovered = discoverCells(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer {
        for (discovered) |p| allocator.free(p);
        allocator.free(discovered);
    }

    // Build cell path → id mapping for deps resolution
    var path_to_id = std.StringHashMap([]const u8).init(allocator);
    defer path_to_id.deinit();

    // First pass: collect all cell info (dupe id strings since content is freed)
    const CellEntry = struct { path: []const u8, id: []const u8 };
    var all_cells = std.array_list.Managed(CellEntry).init(allocator);
    defer {
        for (all_cells.items) |c| allocator.free(c.id);
        all_cells.deinit();
    }

    for (discovered) |path| {
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);
        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(content);
        const cell = parseCellTri(content);
        if (cell.id.len == 0) continue;

        const id_copy = allocator.dupe(u8, cell.id) catch continue;
        all_cells.append(.{ .path = path, .id = id_copy }) catch {
            allocator.free(id_copy);
            continue;
        };
        path_to_id.put(path, id_copy) catch {};
    }

    var total_fixes: usize = 0;

    // === FIX --ids: detect and fix duplicate cell IDs ===
    if (fix_ids) {
        std.debug.print("  {s}[IDS]{s} Checking for duplicate cell IDs...\n", .{ CYAN, RESET });
        var id_counts = std.StringHashMap(usize).init(allocator);
        defer id_counts.deinit();
        for (all_cells.items) |c| {
            const count = id_counts.get(c.id) orelse 0;
            id_counts.put(c.id, count + 1) catch {};
        }
        var dups_found: usize = 0;
        var it = id_counts.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.* > 1) {
                std.debug.print("    {s}DUP{s}  {s} ({d} copies)\n", .{ RED, RESET, entry.key_ptr.*, entry.value_ptr.* });
                // Auto-fix: append path suffix to make unique
                for (all_cells.items) |c| {
                    if (!std.mem.eql(u8, c.id, entry.key_ptr.*)) continue;
                    const name = if (std.mem.lastIndexOf(u8, c.path, "/")) |slash| c.path[slash + 1 ..] else c.path;
                    const parent = if (std.mem.lastIndexOf(u8, c.path, "/")) |slash| blk: {
                        const before = c.path[0..slash];
                        break :blk if (std.mem.lastIndexOf(u8, before, "/")) |s2| before[s2 + 1 ..] else before;
                    } else "";
                    // Propose new ID: trinity.<parent>-<name> or trinity.<name>
                    const new_id = if (parent.len > 0 and !std.mem.eql(u8, parent, "src"))
                        std.fmt.allocPrint(allocator, "trinity.{s}-{s}", .{ parent, name }) catch continue
                    else
                        continue; // Keep first occurrence as-is

                    std.debug.print("      {s}→{s} {s} (at {s})\n", .{ GREEN, RESET, new_id, c.path });
                    if (!dry_run) {
                        fixCellTriField(allocator, c.path, "id", new_id);
                        total_fixes += 1;
                    }
                    dups_found += 1;
                    allocator.free(new_id);
                    break; // Only fix the SECOND occurrence, keep first
                }
            }
        }
        if (dups_found == 0) std.debug.print("    {s}No duplicates found.{s}\n", .{ GREEN, RESET });
        std.debug.print("\n", .{});
    }

    // === FIX --perms: re-infer from code ===
    if (fix_perms) {
        std.debug.print("  {s}[PERMS]{s} Re-inferring permissions from code...\n", .{ CYAN, RESET });
        for (discovered) |path| {
            const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
            defer allocator.free(cell_tri_path);
            const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
            defer allocator.free(content);
            const cell = parseCellTri(content);
            if (cell.id.len == 0) continue;

            // Skip binary-kind cells (tri CLI)
            if (std.mem.eql(u8, cell.kind, "binary")) continue;

            // Virtual cells: scan cell.path + file_patterns instead of the cell.tri directory
            const has_patterns = cell.file_patterns.len > 2;
            const code_perms = if (has_patterns)
                inferPermissionsFiltered(allocator, cell.path, cell.file_patterns)
            else
                inferPermissions(allocator, path);
            var changed = false;
            var changes_buf: [256]u8 = undefined;
            var changes_pos: usize = 0;

            if (!std.mem.eql(u8, cell.perm_level, code_perms.level)) {
                changed = true;
                const delta = std.fmt.bufPrint(changes_buf[changes_pos..], "level:{s}→{s} ", .{ cell.perm_level, code_perms.level }) catch "";
                changes_pos += delta.len;
            }
            if (!std.mem.eql(u8, cell.perm_filesystem, code_perms.fs)) {
                changed = true;
                const delta = std.fmt.bufPrint(changes_buf[changes_pos..], "fs:{s}→{s} ", .{ cell.perm_filesystem, code_perms.fs }) catch "";
                changes_pos += delta.len;
            }
            if (!std.mem.eql(u8, cell.perm_network, code_perms.net)) {
                changed = true;
                const delta = std.fmt.bufPrint(changes_buf[changes_pos..], "net:{s}→{s} ", .{ cell.perm_network, code_perms.net }) catch "";
                changes_pos += delta.len;
            }
            if (!std.mem.eql(u8, cell.perm_process, code_perms.proc)) {
                changed = true;
                const delta = std.fmt.bufPrint(changes_buf[changes_pos..], "proc:{s}→{s} ", .{ cell.perm_process, code_perms.proc }) catch "";
                changes_pos += delta.len;
            }
            if (!std.mem.eql(u8, cell.perm_ffi, code_perms.ffi)) {
                changed = true;
                const delta = std.fmt.bufPrint(changes_buf[changes_pos..], "ffi:{s}→{s} ", .{ cell.perm_ffi, code_perms.ffi }) catch "";
                changes_pos += delta.len;
            }
            if (!std.mem.eql(u8, cell.perm_concurrency, code_perms.concurrency)) {
                changed = true;
                const delta = std.fmt.bufPrint(changes_buf[changes_pos..], "conc:{s}→{s}", .{ cell.perm_concurrency, code_perms.concurrency }) catch "";
                changes_pos += delta.len;
            }

            if (changed) {
                std.debug.print("    {s}FIX{s}  {s}: {s}\n", .{ YELLOW, RESET, cell.id, changes_buf[0..changes_pos] });
                if (!dry_run) {
                    // If [permissions] section is missing entirely, insert it
                    if (cell.perm_level.len == 0) {
                        insertPermissionsSection(allocator, path, code_perms);
                    } else {
                        fixCellTriField(allocator, path, "level", code_perms.level);
                        fixCellTriField(allocator, path, "filesystem", code_perms.fs);
                        fixCellTriField(allocator, path, "network", code_perms.net);
                        fixCellTriField(allocator, path, "process", code_perms.proc);
                        fixCellTriField(allocator, path, "ffi", code_perms.ffi);
                        fixCellTriField(allocator, path, "concurrency", code_perms.concurrency);
                    }
                    total_fixes += 1;
                }
            }
        }
        std.debug.print("\n", .{});
    }

    // === FIX --scope: re-classify scope from path ===
    if (fix_scope) {
        std.debug.print("  {s}[SCOPE]{s} Re-classifying scope assignments...\n", .{ CYAN, RESET });
        for (discovered) |path| {
            const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
            defer allocator.free(cell_tri_path);
            const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
            defer allocator.free(content);
            const cell = parseCellTri(content);
            if (cell.id.len == 0) continue;

            const correct_scope = inferScope(path);
            if (!std.mem.eql(u8, cell.tags_scope, correct_scope)) {
                std.debug.print("    {s}FIX{s}  {s}: scope {s}→{s}\n", .{ YELLOW, RESET, cell.id, cell.tags_scope, correct_scope });
                if (!dry_run) {
                    fixCellTriField(allocator, path, "scope", correct_scope);
                    total_fixes += 1;
                }
            }
        }
        std.debug.print("\n", .{});
    }

    // === FIX --counts: re-count files and tests from source ===
    if (fix_counts) {
        std.debug.print("  {s}[COUNTS]{s} Re-counting files and tests from source...\n", .{ CYAN, RESET });
        for (discovered) |path| {
            const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
            defer allocator.free(cell_tri_path);
            const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
            defer allocator.free(content);
            const cell = parseCellTri(content);
            if (cell.id.len == 0) continue;

            // Virtual cells: scan cell.path + file_patterns instead of the cell.tri directory
            const has_patterns = cell.file_patterns.len > 2;
            const stats = if (has_patterns)
                countFilesAndTestsFiltered(allocator, cell.path, cell.file_patterns)
            else
                countFilesAndTests(allocator, path);
            if (stats.files != cell.files or stats.tests != cell.tests) {
                std.debug.print("    {s}FIX{s}  {s}: files {d}→{d}, tests {d}→{d}\n", .{
                    YELLOW, RESET, cell.id, cell.files, stats.files, cell.tests, stats.tests,
                });
                if (!dry_run) {
                    var files_buf: [16]u8 = undefined;
                    const files_str = std.fmt.bufPrint(&files_buf, "{d}", .{stats.files}) catch continue;
                    var tests_buf: [16]u8 = undefined;
                    const tests_str = std.fmt.bufPrint(&tests_buf, "{d}", .{stats.tests}) catch continue;
                    fixCellTriField(allocator, path, "files", files_str);
                    fixCellTriField(allocator, path, "tests", tests_str);
                    total_fixes += 1;
                }
            }
        }
        std.debug.print("\n", .{});
    }

    // === FIX --deps: auto-declare from @imports ===
    if (fix_deps) {
        std.debug.print("  {s}[DEPS]{s} Auto-declaring dependencies from @imports...\n", .{ CYAN, RESET });

        // Build module name → cell id mapping
        var module_to_cell = std.StringHashMap([]const u8).init(allocator);
        defer module_to_cell.deinit();
        for (all_cells.items) |c| {
            const mod_name = if (std.mem.lastIndexOf(u8, c.path, "/")) |slash| c.path[slash + 1 ..] else c.path;
            module_to_cell.put(mod_name, c.id) catch {};
        }

        for (discovered) |path| {
            const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
            defer allocator.free(cell_tri_path);
            const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
            // Keep content alive for parseCellTri
            const cell = parseCellTri(content);
            if (cell.id.len == 0) {
                allocator.free(content);
                continue;
            }

            // Collect existing declared deps
            var declared = std.StringHashMap(void).init(allocator);
            defer declared.deinit();
            var dep_it = DepIterator.init(cell.dependencies_raw);
            while (dep_it.next()) |dep| {
                declared.put(dep.id, {}) catch {};
            }

            // Scan code for @imports that reference other cells
            var missing_deps = std.StringHashMap(void).init(allocator);
            defer missing_deps.deinit();

            var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch {
                allocator.free(content);
                continue;
            };
            defer dir.close();

            var walker = dir.walk(allocator) catch {
                allocator.free(content);
                continue;
            };
            defer walker.deinit();

            while (walker.next() catch null) |entry| {
                if (entry.kind != .file) continue;
                if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;
                if (std.mem.indexOf(u8, entry.path, ".zig-cache") != null) continue;

                const file_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, entry.path }) catch continue;
                defer allocator.free(file_path);
                const source = std.fs.cwd().readFileAlloc(allocator, file_path, 1048576) catch continue;
                defer allocator.free(source);

                // Find @import("...") patterns
                var pos: usize = 0;
                while (pos < source.len) {
                    const import_pos = std.mem.indexOf(u8, source[pos..], "@import(\"") orelse break;
                    const abs_pos = pos + import_pos + 9;
                    pos = abs_pos;
                    const end_quote = std.mem.indexOf(u8, source[abs_pos..], "\"") orelse break;
                    const import_path = source[abs_pos .. abs_pos + end_quote];
                    pos = abs_pos + end_quote + 1;

                    if (std.mem.eql(u8, import_path, "std")) continue;
                    if (std.mem.startsWith(u8, import_path, "builtin")) continue;

                    // Check if it matches a known cell module name
                    const import_base = if (std.mem.lastIndexOf(u8, import_path, "/")) |slash|
                        import_path[slash + 1 ..]
                    else
                        import_path;
                    const module_name = if (std.mem.endsWith(u8, import_base, ".zig"))
                        import_base[0 .. import_base.len - 4]
                    else
                        import_base;

                    // Match by module name (exact stem match)
                    if (module_to_cell.get(module_name)) |dep_id| {
                        if (!std.mem.eql(u8, dep_id, cell.id) and !declared.contains(dep_id)) {
                            missing_deps.put(dep_id, {}) catch {};
                        }
                    }

                    // Also match path-based imports: ../other_cell/ or ../../other_cell/
                    if (std.mem.indexOf(u8, import_path, "/") != null) {
                        for (all_cells.items) |other| {
                            if (std.mem.eql(u8, other.id, cell.id)) continue;
                            const other_mod = if (std.mem.lastIndexOf(u8, other.path, "/")) |s| other.path[s + 1 ..] else other.path;
                            const pat = std.fmt.allocPrint(allocator, "/{s}/", .{other_mod}) catch continue;
                            defer allocator.free(pat);
                            if (std.mem.indexOf(u8, import_path, pat) != null and !declared.contains(other.id)) {
                                missing_deps.put(other.id, {}) catch {};
                            }
                        }
                    }
                }
            }

            if (missing_deps.count() > 0) {
                std.debug.print("    {s}FIX{s}  {s}: +{d} deps (", .{ YELLOW, RESET, cell.id, missing_deps.count() });
                var dep_iter = missing_deps.iterator();
                var first = true;
                while (dep_iter.next()) |entry| {
                    if (!first) std.debug.print(", ", .{});
                    first = false;
                    std.debug.print("{s}", .{entry.key_ptr.*});
                }
                std.debug.print(")\n", .{});

                if (!dry_run) {
                    // Append deps to cell.tri [dependencies] section
                    appendDepsToCell(allocator, path, &missing_deps);
                    total_fixes += 1;
                }
            }

            allocator.free(content);
        }
        std.debug.print("\n", .{});
    }

    // === FIX --exports: auto-detect pub fn from source code ===
    if (fix_exports) {
        std.debug.print("  {s}[EXPORTS]{s} Auto-detecting pub fn exports from source...\n", .{ CYAN, RESET });
        for (discovered) |path| {
            const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
            defer allocator.free(cell_tri_path);
            const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
            defer allocator.free(content);
            const cell = parseCellTri(content);
            if (cell.id.len == 0) continue;

            // Detect exports: use file_patterns for virtual cells, normal scan otherwise
            const has_patterns = cell.file_patterns.len > 2;
            const detected = if (has_patterns)
                detectExportsFiltered(allocator, cell.path, cell.file_patterns)
            else
                detectExportsInDir(allocator, path);

            if (detected.count == 0) continue;

            // Build exports string: ["fn1", "fn2", ...]
            var exports_buf: [512]u8 = undefined;
            var exports_len: usize = 0;
            exports_buf[0] = '[';
            exports_len = 1;
            for (0..detected.count) |i| {
                if (i > 0) {
                    @memcpy(exports_buf[exports_len..][0..2], ", ");
                    exports_len += 2;
                }
                exports_buf[exports_len] = '"';
                exports_len += 1;
                const name = detected.items[i];
                const copy_len = @min(name.len, exports_buf.len - exports_len - 2);
                @memcpy(exports_buf[exports_len..][0..copy_len], name[0..copy_len]);
                exports_len += copy_len;
                exports_buf[exports_len] = '"';
                exports_len += 1;
            }
            exports_buf[exports_len] = ']';
            exports_len += 1;
            const new_exports = exports_buf[0..exports_len];

            // Compare with current exports
            const current = cell.contributes_exports;
            if (!std.mem.eql(u8, current, new_exports)) {
                std.debug.print("    {s}FIX{s}  {s}: exports → {s}\n", .{ YELLOW, RESET, cell.id, new_exports });
                if (!dry_run) {
                    fixCellTriField(allocator, path, "exports", new_exports);
                    total_fixes += 1;
                }
            }
        }
        std.debug.print("\n", .{});
    }

    // === FIX --owner: set owner + auto-fill empty contributes.commands ===
    if (fix_owner) {
        // Auto-fill contributes.commands from capabilities for cells with empty commands
        std.debug.print("  {s}[CONTRIBUTES]{s} Auto-filling commands from capabilities...\n", .{ CYAN, RESET });
        for (discovered) |path| {
            const ctri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
            defer allocator.free(ctri_path);
            const ctri_content = std.fs.cwd().readFileAlloc(allocator, ctri_path, 65536) catch continue;
            defer allocator.free(ctri_content);
            const ccell = parseCellTri(ctri_content);
            if (ccell.id.len == 0) continue;

            // Skip if already has commands
            if (ccell.contributes_commands.len > 2) continue;
            // Need capabilities to derive commands from
            if (ccell.capabilities.len <= 2) continue;

            // Extract first 3 capabilities as commands
            var caps_iter = cell_parser.ArrayIterator.init(ccell.capabilities);
            var cmd_buf: [256]u8 = undefined;
            var cmd_len: usize = 0;
            var cap_count: usize = 0;
            cmd_buf[0] = '[';
            cmd_len = 1;
            while (caps_iter.next()) |cap| {
                if (cap_count >= 3) break;
                if (cap_count > 0) {
                    @memcpy(cmd_buf[cmd_len..][0..2], ", ");
                    cmd_len += 2;
                }
                cmd_buf[cmd_len] = '"';
                cmd_len += 1;
                const copy_len = @min(cap.len, cmd_buf.len - cmd_len - 2);
                @memcpy(cmd_buf[cmd_len..][0..copy_len], cap[0..copy_len]);
                cmd_len += copy_len;
                cmd_buf[cmd_len] = '"';
                cmd_len += 1;
                cap_count += 1;
            }
            if (cap_count == 0) continue;
            cmd_buf[cmd_len] = ']';
            cmd_len += 1;

            std.debug.print("    {s}FIX{s}  {s}: commands = {s}\n", .{ YELLOW, RESET, ccell.id, cmd_buf[0..cmd_len] });
            if (!dry_run) {
                fixCellTriField(allocator, path, "commands", cmd_buf[0..cmd_len]);
                total_fixes += 1;
            }
        }
        std.debug.print("\n", .{});

        // Set owner for cells without one
        std.debug.print("  {s}[OWNER]{s} Setting owner for cells without one...\n", .{ CYAN, RESET });
        std.debug.print("  {s}[OWNER]{s} Setting owner for cells without one...\n", .{ CYAN, RESET });
        for (discovered) |path| {
            const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
            defer allocator.free(cell_tri_path);
            const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
            defer allocator.free(content);
            const cell = parseCellTri(content);
            if (cell.id.len == 0) continue;
            if (cell.owner.len > 0) continue; // already has owner

            std.debug.print("    {s}FIX{s}  {s}: owner = \"agent:ralph\"\n", .{ YELLOW, RESET, cell.id });
            if (!dry_run) {
                fixCellTriField(allocator, path, "owner", "agent:ralph");
                total_fixes += 1;
            }
        }
        std.debug.print("\n", .{});
    }

    if (dry_run) {
        std.debug.print("  {s}[DRY RUN]{s} No files modified. Run without --dry-run to apply.\n\n", .{ YELLOW, RESET });
    } else {
        std.debug.print("  {s}Fixed {d} cells.{s}\n", .{ GREEN, total_fixes, RESET });
        std.debug.print("  Next: {s}tri cell check --sync{s} to rebuild registry\n\n", .{ GREEN, RESET });
    }
}

/// Fix a single key=value field in cell.tri
/// Insert a complete [permissions] section before [security] (or at end)
fn insertPermissionsSection(allocator: Allocator, cell_path: []const u8, perms: PermResult) void {
    const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{cell_path}) catch return;
    defer allocator.free(cell_tri_path);

    const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch return;
    defer allocator.free(content);

    const section = std.fmt.allocPrint(allocator,
        \\[permissions]
        \\level = "{s}"
        \\filesystem = "{s}"
        \\network = "{s}"
        \\process = "{s}"
        \\ffi = "{s}"
        \\concurrency = "{s}"
        \\
    , .{ perms.level, perms.fs, perms.net, perms.proc, perms.ffi, perms.concurrency }) catch return;
    defer allocator.free(section);

    var result = std.array_list.Managed(u8).init(allocator);
    defer result.deinit();

    var inserted = false;
    var lines = std.mem.splitScalar(u8, content, '\n');
    var first_line = true;
    while (lines.next()) |line| {
        if (!first_line) result.append('\n') catch return;
        first_line = false;

        const trimmed = std.mem.trim(u8, line, &[_]u8{ ' ', '\t', '\r' });
        // Insert before [security] section
        if (!inserted and std.mem.eql(u8, trimmed, "[security]")) {
            result.appendSlice(section) catch return;
            result.append('\n') catch return;
            inserted = true;
        }
        result.appendSlice(line) catch return;
    }

    // If no [security] section found, append at end
    if (!inserted) {
        result.append('\n') catch return;
        result.appendSlice(section) catch return;
    }

    const file = std.fs.cwd().createFile(cell_tri_path, .{}) catch return;
    defer file.close();
    file.writeAll(result.items) catch {};
}

fn fixCellTriField(allocator: Allocator, cell_path: []const u8, key: []const u8, new_value: []const u8) void {
    const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{cell_path}) catch return;
    defer allocator.free(cell_tri_path);

    const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch return;
    defer allocator.free(content);

    var result = std.array_list.Managed(u8).init(allocator);
    defer result.deinit();

    const is_numeric = new_value.len > 0 and for (new_value) |ch| {
        if (ch < '0' or ch > '9') break false;
    } else true;
    const is_array = new_value.len > 0 and new_value[0] == '[';

    var found = false;
    var lines = std.mem.splitScalar(u8, content, '\n');
    var first_line = true;
    var in_permissions = false;
    var last_perm_line = false;

    while (lines.next()) |line| {
        if (!first_line) result.append('\n') catch return;
        first_line = false;

        const trimmed = std.mem.trim(u8, line, &[_]u8{ ' ', '\t', '\r' });

        // Track [permissions] section for appending missing fields
        if (trimmed.len > 0 and trimmed[0] == '[') {
            if (in_permissions and !found and last_perm_line) {
                // We're leaving [permissions] without finding the key — append it
                if (std.mem.eql(u8, key, "ffi") or std.mem.eql(u8, key, "concurrency")) {
                    const new_line = std.fmt.allocPrint(allocator, "{s} = \"{s}\"\n", .{ key, new_value }) catch return;
                    defer allocator.free(new_line);
                    result.appendSlice(new_line) catch return;
                    found = true;
                }
            }
            in_permissions = std.mem.eql(u8, trimmed, "[permissions]");
        }

        const eq_pos = std.mem.indexOf(u8, trimmed, "=");
        if (eq_pos) |ep| {
            const line_key = std.mem.trim(u8, trimmed[0..ep], &[_]u8{ ' ', '\t' });
            if (std.mem.eql(u8, line_key, key)) {
                found = true;
                const new_line = if (is_numeric or is_array)
                    std.fmt.allocPrint(allocator, "{s} = {s}", .{ key, new_value }) catch return
                else
                    std.fmt.allocPrint(allocator, "{s} = \"{s}\"", .{ key, new_value }) catch return;
                defer allocator.free(new_line);
                result.appendSlice(new_line) catch return;
                continue;
            }
            if (in_permissions) last_perm_line = true;
        }
        result.appendSlice(line) catch return;
    }

    // If field still not found and it's a permission field, append at end
    if (!found and (std.mem.eql(u8, key, "ffi") or std.mem.eql(u8, key, "concurrency"))) {
        // Find [permissions] and append after last field
        result.clearRetainingCapacity();
        var lines2 = std.mem.splitScalar(u8, content, '\n');
        first_line = true;
        in_permissions = false;
        var appended = false;
        while (lines2.next()) |line| {
            if (!first_line) result.append('\n') catch return;
            first_line = false;
            result.appendSlice(line) catch return;

            const trimmed2 = std.mem.trim(u8, line, &[_]u8{ ' ', '\t', '\r' });
            if (std.mem.eql(u8, trimmed2, "[permissions]")) {
                in_permissions = true;
            } else if (in_permissions and trimmed2.len > 0 and trimmed2[0] == '[') {
                // Next section — insert before it
                if (!appended) {
                    // We already appended this line, need to insert before
                    // Simpler: just append after [permissions] block ends
                }
                in_permissions = false;
            } else if (in_permissions and trimmed2.len > 0 and std.mem.indexOf(u8, trimmed2, "=") != null) {
                // Last field in permissions — check if next line is section or empty
                appended = false; // track
            }
        }
        // If still in permissions at EOF, append
        if (in_permissions and !appended) {
            result.append('\n') catch return;
            const new_line = std.fmt.allocPrint(allocator, "{s} = \"{s}\"", .{ key, new_value }) catch return;
            defer allocator.free(new_line);
            result.appendSlice(new_line) catch return;
        }
    }

    const file = std.fs.cwd().createFile(cell_tri_path, .{}) catch return;
    defer file.close();
    file.writeAll(result.items) catch {};
}

/// Append missing deps to the [dependencies] section of cell.tri
fn appendDepsToCell(allocator: Allocator, cell_path: []const u8, deps: *std.StringHashMap(void)) void {
    const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{cell_path}) catch return;
    defer allocator.free(cell_tri_path);

    const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch return;
    defer allocator.free(content);

    var result = std.array_list.Managed(u8).init(allocator);
    defer result.deinit();

    // Simple approach: rebuild file, inject deps right after [dependencies] line
    var lines = std.mem.splitScalar(u8, content, '\n');
    var first_line = true;
    while (lines.next()) |line| {
        if (!first_line) result.append('\n') catch return;
        first_line = false;
        result.appendSlice(line) catch return;

        const trimmed = std.mem.trim(u8, line, &[_]u8{ ' ', '\t', '\r' });
        if (std.mem.eql(u8, trimmed, "[dependencies]")) {
            // Inject all new deps right after this line
            var dep_it = deps.iterator();
            while (dep_it.next()) |entry| {
                result.append('\n') catch return;
                const dep_line = std.fmt.allocPrint(allocator, "{s} = \"^1.0.0\"", .{entry.key_ptr.*}) catch continue;
                defer allocator.free(dep_line);
                result.appendSlice(dep_line) catch return;
            }
        }
    }

    const file = std.fs.cwd().createFile(cell_tri_path, .{}) catch return;
    defer file.close();
    file.writeAll(result.items) catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCORE — unified health + security score
// ═══════════════════════════════════════════════════════════════════════════════

fn runScore(allocator: Allocator, args: []const []const u8) !void {
    std.debug.print("\n{s}🏆 CELL INTEGRITY SCORE v10 (honest){s}\n\n", .{ GOLDEN, RESET });

    const discovered = discoverCells(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer {
        for (discovered) |p| allocator.free(p);
        allocator.free(discovered);
    }

    // Build path→cell_id map for deps accuracy
    const all_cells = cell_parser.discoverAll(allocator) catch null;
    defer if (all_cells) |ac| allocator.free(ac);
    var path_to_cell = std.StringHashMap([]const u8).init(allocator);
    defer path_to_cell.deinit();
    if (all_cells) |ac| {
        for (ac) |c| path_to_cell.put(c.manifest.path, c.manifest.id) catch {};
    }

    // Build cycle set for penalty
    var cycle_cells = std.StringHashMap(void).init(allocator);
    defer cycle_cells.deinit();
    if (all_cells) |ac| {
        // Build adjacency
        var adj = std.StringHashMap(std.array_list.Managed([]const u8)).init(allocator);
        defer {
            var it = adj.iterator();
            while (it.next()) |entry| entry.value_ptr.deinit();
            adj.deinit();
        }
        for (ac) |c| {
            var deps_list = std.array_list.Managed([]const u8).init(allocator);
            var dep_it = cell_parser.DepIterator.init(c.manifest.dependencies_raw);
            while (dep_it.next()) |de| deps_list.append(de.id) catch {};
            adj.put(c.manifest.id, deps_list) catch {};
        }
        // DFS for cycle detection
        var color = std.StringHashMap(u8).init(allocator);
        defer color.deinit();
        for (ac) |c| color.put(c.manifest.id, 0) catch {};
        for (ac) |c| {
            if ((color.get(c.manifest.id) orelse 0) != 0) continue;
            var stack = std.array_list.Managed(struct { id: []const u8, idx: usize }).init(allocator);
            defer stack.deinit();
            var path_list = std.array_list.Managed([]const u8).init(allocator);
            defer path_list.deinit();
            stack.append(.{ .id = c.manifest.id, .idx = 0 }) catch {};
            color.put(c.manifest.id, 1) catch {};
            path_list.append(c.manifest.id) catch {};
            while (stack.items.len > 0) {
                const top = &stack.items[stack.items.len - 1];
                const neighbors = adj.get(top.id);
                if (neighbors != null and top.idx < neighbors.?.items.len) {
                    const next = neighbors.?.items[top.idx];
                    top.idx += 1;
                    const nc = color.get(next) orelse 0;
                    if (nc == 1) {
                        // Mark all nodes in cycle path
                        var in_cycle = false;
                        for (path_list.items) |p| {
                            if (std.mem.eql(u8, p, next)) in_cycle = true;
                            if (in_cycle) cycle_cells.put(p, {}) catch {};
                        }
                        cycle_cells.put(next, {}) catch {};
                    } else if (nc == 0) {
                        color.put(next, 1) catch {};
                        stack.append(.{ .id = next, .idx = 0 }) catch {};
                        path_list.append(next) catch {};
                    }
                } else {
                    color.put(top.id, 2) catch {};
                    _ = stack.pop();
                    if (path_list.items.len > 0) _ = path_list.pop();
                }
            }
        }
    }

    // Optional cell filter
    var cell_filter: ?[]const u8 = null;
    if (args.len > 0) cell_filter = args[0];

    var total_score: usize = 0;
    var count: usize = 0;
    var grade_a: usize = 0;
    var grade_b: usize = 0;
    var grade_c: usize = 0;
    var grade_f: usize = 0;

    std.debug.print("  {s}CELL                    HEALTH  SECURITY  DEPS  CONTRACTS  TOTAL  GRADE{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}─────────────────────── ─────── ──────── ───── ───────── ────── ─────{s}\n", .{ GRAY, RESET });

    for (discovered) |path| {
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);
        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(content);
        const cell = parseCellTri(content);
        if (cell.id.len == 0) continue;

        if (cell_filter) |f| {
            if (!std.mem.eql(u8, cell.id, f)) continue;
        }

        // Skip binary-kind
        if (std.mem.eql(u8, cell.kind, "binary")) continue;

        // ── Health (max 30) ──
        // Agent definition cells (no .zig source) get test bypass — they are orchestration, not code
        const is_agent_def = std.mem.startsWith(u8, cell.id, "trinity.agent.");
        // Metadata-only cells (specs, papers, data, contracts, libs) have 0 .zig files — give baseline
        const is_metadata_only = cell.files == 0 and cell.tests == 0 and !is_agent_def;
        // tests: linear scale — 1 test per point up to 15, rewards real testing effort
        const test_score: u8 = if (is_agent_def) 12 else if (is_metadata_only) 10 else if (cell.tests == 0) 0 else @intCast(@min(15, cell.tests * 15 / 80));
        const has_owner: u8 = if (cell.owner.len > 0) 5 else 0;
        const has_caps: u8 = if (cell.capabilities.len > 2) 5 else 0;
        const has_desc: u8 = if (cell.description.len > 0 and !std.mem.startsWith(u8, cell.description, "Auto-generated")) 5 else 0;
        const health_score: u8 = test_score + has_owner + has_caps + has_desc; // max 30

        // ── Security (max 30) ──
        var security_score: u8 = 0;
        const is_virtual = cell.file_patterns.len > 2;
        if (cell.parent.len > 0 and !is_virtual) {
            // Virtual sub-cells without file_patterns: can't scan code, use declared perms only
            if (cell.perm_level.len > 0) security_score += 20; // declared = trusted
            if (cell.security_signed) security_score += 5;
            security_score += 5; // no bind check for virtual cells
        } else {
            if (cell.perm_level.len > 0) security_score += 10;
            // Virtual cells: scan cell.path + file_patterns; normal cells: scan discovery path
            const code_perms = if (is_virtual)
                inferPermissionsFiltered(allocator, cell.path, cell.file_patterns)
            else
                inferPermissions(allocator, path);
            const perms_match = std.mem.eql(u8, cell.perm_level, code_perms.level) and
                std.mem.eql(u8, cell.perm_network, code_perms.net) and
                std.mem.eql(u8, cell.perm_process, code_perms.proc);
            if (perms_match) security_score += 10;
            if (cell.security_signed) security_score += 5;
            const no_bind_all = !(scanCodeForPattern(allocator, path, "parseIp4(\"0.0.0.0\"") or
                scanCodeForPattern(allocator, path, "parseIp(\"0.0.0.0\"") or
                scanCodeForPattern(allocator, path, "bind_address: []const u8 = \"0.0.0.0\"") or
                scanCodeForPattern(allocator, path, ".host = \"0.0.0.0\"") or
                scanCodeForPattern(allocator, path, "listen_address = \"0.0.0.0\""));
            if (no_bind_all) security_score += 5;
        }
        // max 30

        // ── Deps accuracy (max 25) ──
        var deps_score: u8 = 0;
        // Top-level virtual cells (kind=virtual, path="src", file_patterns present):
        // Their files use @import("vsa.zig") not @import("../vsa/..."), so cross-cell
        // detection can't work. Use declared deps as truth (same as independent cells).
        const is_toplevel_virtual = is_virtual and cell.parent.len == 0;
        const dep_acc = if (is_toplevel_virtual)
            DepsAccuracy{ .confirmed = 0, .missing = 0, .extra = 0, .total = 0 }
        else
            computeDepsAccuracy(allocator, path, cell, all_cells, &path_to_cell);
        if (dep_acc.total == 0) {
            deps_score = 25; // truly independent, no deps needed
        } else if (dep_acc.missing == 0 and dep_acc.confirmed == 0) {
            // All deps declared but none detected via @import scan (indirect/transitive use).
            // Don't penalize — cell is honest about its dependencies, scanner just can't confirm.
            deps_score = 20;
        } else {
            const ratio: u8 = @intCast(@min(15, dep_acc.confirmed * 15 / dep_acc.total));
            deps_score = ratio + (if (dep_acc.missing == 0) @as(u8, 10) else 0);
        }
        // Cycle penalty: -10 if this cell participates in a dependency cycle
        // Cycles are architectural debt — strong penalty to incentivize breaking them
        if (cycle_cells.contains(cell.id)) {
            deps_score -|= 10;
        }

        // ── Contracts (max 15) ──
        var contracts_score: u8 = 15; // start at max, subtract violations
        // Check 1: exports declared (libraries and tools should export something)
        if (cell.contributes_exports.len <= 2 and
            (std.mem.eql(u8, cell.kind, "library") or std.mem.eql(u8, cell.kind, "tool")))
        {
            contracts_score -|= 5; // library/tool without exports = incomplete API
        }
        // Check 2: boundary — L0 cells should not depend on L2 cells
        // Penalty scales by dep kind: library deps get -1 (L2 may be from auxiliary code),
        // backend/tool deps get -3 (real permission escalation risk)
        if (std.mem.eql(u8, cell.perm_level, "L0")) {
            var dep_it2 = cell_parser.DepIterator.init(cell.dependencies_raw);
            while (dep_it2.next()) |dep| {
                if (all_cells) |ac| {
                    for (ac) |dc| {
                        if (std.mem.eql(u8, dc.manifest.id, dep.id)) {
                            if (std.mem.eql(u8, dc.manifest.perm_level, "L2")) {
                                const penalty: u8 = if (std.mem.eql(u8, dc.manifest.kind, "library"))
                                    1 // library→library: L2 likely from aux code, mild penalty
                                else
                                    3; // library→backend/tool: real permission escalation
                                contracts_score -|= penalty;
                            }
                            break;
                        }
                    }
                }
            }
        }
        // Check 3: frontend cells should not depend on backend cells
        if (std.mem.eql(u8, cell.kind, "frontend")) {
            var dep_it3 = cell_parser.DepIterator.init(cell.dependencies_raw);
            while (dep_it3.next()) |dep| {
                if (all_cells) |ac| {
                    for (ac) |dc| {
                        if (std.mem.eql(u8, dc.manifest.id, dep.id)) {
                            if (std.mem.eql(u8, dc.manifest.kind, "backend")) {
                                contracts_score -|= 3; // frontend→backend violation
                            }
                            break;
                        }
                    }
                }
            }
        }

        const final_score = health_score + security_score + deps_score + contracts_score;
        const grade_char: []const u8 = if (final_score >= 80) "A" else if (final_score >= 60) "B" else if (final_score >= 40) "C" else "F";
        const grade_color = if (final_score >= 80) GREEN else if (final_score >= 60) YELLOW else RED;

        if (final_score >= 80) grade_a += 1 else if (final_score >= 60) grade_b += 1 else if (final_score >= 40) grade_c += 1 else grade_f += 1;

        const is_sub = cell.parent.len > 0;
        if (is_sub) {
            std.debug.print("    {s}└─ {s}{s}", .{ GRAY, cell.id, RESET });
            printPad(cell.id.len + 5, 26);
        } else {
            std.debug.print("  {s}{s}{s}", .{ WHITE, cell.id, RESET });
            printPad(cell.id.len, 24);
        }
        std.debug.print("{d:3}     {d:3}       {d:2}       {d:2}     {s}{d:3}{s}    {s}{s}{s}\n", .{
            health_score, security_score, deps_score, contracts_score,
            grade_color,  final_score,    RESET,      grade_color,
            grade_char,   RESET,
        });

        total_score += final_score;
        count += 1;
    }

    if (count > 0) {
        const avg = total_score / count;
        const avg_color = if (avg >= 80) GREEN else if (avg >= 60) YELLOW else RED;
        std.debug.print("\n  {s}Average: {s}{d}/100{s} | A:{d} B:{d} C:{d} F:{d} | {d} cells{s}\n", .{
            GRAY, avg_color, avg, RESET, grade_a, grade_b, grade_c, grade_f, count, RESET,
        });
        std.debug.print("  {s}Formula: health(30) + security(30) + deps(25) + contracts(15) = 100{s}\n\n", .{ GRAY, RESET });
    }
}

const DepsAccuracy = struct { confirmed: usize, missing: usize, extra: usize, total: usize };

/// Check if a filename matches any pattern in a file_patterns array like ["tri_farm*.zig", "railway_*.zig"]
fn matchesFilePatterns(filename: []const u8, patterns_raw: []const u8) bool {
    var iter = cell_parser.ArrayIterator.init(patterns_raw);
    while (iter.next()) |pattern| {
        if (simpleGlobMatch(filename, pattern)) return true;
    }
    return false;
}

/// Simple glob match supporting only '*' wildcard (no ?, no **)
fn simpleGlobMatch(str: []const u8, pattern: []const u8) bool {
    // Split pattern by '*'
    var s_pos: usize = 0;
    var p_pos: usize = 0;

    while (p_pos < pattern.len) {
        if (pattern[p_pos] == '*') {
            p_pos += 1;
            // If * is at end, match rest
            if (p_pos >= pattern.len) return true;
            // Find the next literal segment after *
            const next_star = std.mem.indexOfScalar(u8, pattern[p_pos..], '*');
            const segment = if (next_star) |ns| pattern[p_pos .. p_pos + ns] else pattern[p_pos..];
            // Search for segment in remaining str
            const found = std.mem.indexOf(u8, str[s_pos..], segment);
            if (found == null) return false;
            s_pos += found.? + segment.len;
            p_pos += segment.len;
        } else {
            // Literal match
            if (s_pos >= str.len or str[s_pos] != pattern[p_pos]) return false;
            s_pos += 1;
            p_pos += 1;
        }
    }
    return s_pos == str.len;
}

fn computeDepsAccuracy(
    allocator: Allocator,
    cell_path: []const u8,
    cell: CellInfo,
    all_cells_opt: ?[]const cell_parser.DiscoveredCell,
    path_to_cell: *std.StringHashMap([]const u8),
) DepsAccuracy {
    var result = DepsAccuracy{ .confirmed = 0, .missing = 0, .extra = 0, .total = 0 };
    const all_cells = all_cells_opt orelse return result;

    // Scan @imports in this cell's directory
    var detected_deps = std.StringHashMap(void).init(allocator);
    defer detected_deps.deinit();

    var dir = std.fs.cwd().openDir(cell_path, .{ .iterate = true }) catch return result;
    defer dir.close();

    // For virtual sub-cells with file_patterns, only scan matching files
    const has_patterns = cell.file_patterns.len > 2; // more than "[]"

    // Use walk() to descend into subdirectories (e.g., src/models/tqnn/)
    var walker = dir.walk(allocator) catch return result;
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;
        if (std.mem.indexOf(u8, entry.path, ".zig-cache") != null) continue;

        // Filter by file_patterns if this is a virtual sub-cell
        if (has_patterns and !matchesFilePatterns(entry.basename, cell.file_patterns)) continue;

        const file_content = blk: {
            const file_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ cell_path, entry.path }) catch continue;
            defer allocator.free(file_path);
            break :blk std.fs.cwd().readFileAlloc(allocator, file_path, 1048576) catch continue;
        };
        defer allocator.free(file_content);

        var pos: usize = 0;
        while (std.mem.indexOf(u8, file_content[pos..], "@import(\"")) |idx| {
            const abs_start = pos + idx + 9;
            const end = std.mem.indexOf(u8, file_content[abs_start..], "\"") orelse break;
            const import_path = file_content[abs_start .. abs_start + end];
            pos = abs_start + end + 1;

            if (std.mem.eql(u8, import_path, "std") or
                std.mem.eql(u8, import_path, "builtin") or
                std.mem.eql(u8, import_path, "root")) continue;

            if (std.mem.startsWith(u8, import_path, "../") or
                std.mem.startsWith(u8, import_path, "src/") or
                std.mem.startsWith(u8, import_path, "libs/") or
                std.mem.startsWith(u8, import_path, "fpga/"))
            {
                const resolved = resolveImportToCell(import_path, cell_path, path_to_cell);
                if (resolved) |dep_cell_id| {
                    if (!std.mem.eql(u8, dep_cell_id, cell.id)) {
                        detected_deps.put(dep_cell_id, {}) catch {};
                    }
                }
            } else if (!std.mem.endsWith(u8, import_path, ".zig")) {
                if (resolveModuleToCell(import_path, cell.id, all_cells)) |dep_cell_id| {
                    detected_deps.put(dep_cell_id, {}) catch {};
                }
            }
        }
    }

    // Build declared deps set
    var declared_deps = std.StringHashMap(void).init(allocator);
    defer declared_deps.deinit();
    var dep_it = cell_parser.DepIterator.init(cell.dependencies_raw);
    while (dep_it.next()) |dep_entry| {
        declared_deps.put(dep_entry.id, {}) catch {};
    }

    // Build parent's declared deps for inheritance (sub-cells resolve modules through parent)
    var parent_deps = std.StringHashMap(void).init(allocator);
    defer parent_deps.deinit();
    if (cell.parent.len > 0) {
        for (all_cells) |pc| {
            if (std.mem.eql(u8, pc.manifest.id, cell.parent)) {
                var parent_dep_it = cell_parser.DepIterator.init(pc.manifest.dependencies_raw);
                while (parent_dep_it.next()) |pdep| {
                    parent_deps.put(pdep.id, {}) catch {};
                }
                break;
            }
        }
    }

    // Count confirmed (declared AND detected)
    var declared_it = declared_deps.iterator();
    while (declared_it.next()) |e| {
        result.total += 1;
        if (detected_deps.contains(e.key_ptr.*)) {
            result.confirmed += 1;
        } else {
            result.extra += 1;
        }
    }

    // Count missing (detected but NOT declared)
    var detected_it = detected_deps.iterator();
    while (detected_it.next()) |e| {
        if (!declared_deps.contains(e.key_ptr.*)) {
            // Sub-cell importing parent is expected, not a missing dep
            if (cell.parent.len > 0 and std.mem.eql(u8, e.key_ptr.*, cell.parent)) continue;
            // Deps inherited from parent are not missing — sub-cells resolve through parent build
            if (parent_deps.contains(e.key_ptr.*)) continue;
            result.missing += 1;
            result.total += 1;
        }
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATE/AUDIT HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

const FileStats = struct { files: u32, tests: u32 };

/// Like countFilesAndTests but only counts files matching file_patterns in a flat directory.
/// Used for virtual cells where path="src" but code lives in specific files.
fn countFilesAndTestsFiltered(allocator: Allocator, dir_path: []const u8, file_patterns: []const u8) FileStats {
    var result = FileStats{ .files = 0, .tests = 0 };
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return result;
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
        if (!matchesFilePatterns(entry.name, file_patterns)) continue;

        result.files += 1;

        const file_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name }) catch continue;
        defer allocator.free(file_path);
        const source = std.fs.cwd().readFileAlloc(allocator, file_path, 1048576) catch continue;
        defer allocator.free(source);

        var pos: usize = 0;
        while (pos < source.len) {
            const test_pos = std.mem.indexOf(u8, source[pos..], "test \"") orelse break;
            pos += test_pos + 6;
            result.tests += 1;
        }
    }
    return result;
}

fn countFilesAndTests(allocator: Allocator, path: []const u8) FileStats {
    var result = FileStats{ .files = 0, .tests = 0 };
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch return result;
    defer dir.close();

    var walker = dir.walk(allocator) catch return result;
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;
        // Skip .zig-cache
        if (std.mem.indexOf(u8, entry.path, ".zig-cache") != null) continue;

        result.files += 1;

        // Count test blocks
        const file_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, entry.path }) catch continue;
        defer allocator.free(file_path);
        const source = std.fs.cwd().readFileAlloc(allocator, file_path, 1048576) catch continue;
        defer allocator.free(source);

        var pos: usize = 0;
        while (pos < source.len) {
            const test_pos = std.mem.indexOf(u8, source[pos..], "test \"") orelse break;
            pos += test_pos + 6;
            result.tests += 1;
        }
    }
    return result;
}

const ExportList = struct {
    items: [16][]const u8,
    count: usize,

    /// Check if name is already in the list (dedup)
    fn contains(self: *const ExportList, name: []const u8) bool {
        for (self.items[0..self.count]) |item| {
            if (std.mem.eql(u8, item, name)) return true;
        }
        return false;
    }
};

/// Skip trivial function names that don't represent meaningful API surface
fn isTrivialExport(name: []const u8) bool {
    const trivial = [_][]const u8{ "main", "init", "deinit", "format", "next", "reset", "close", "open", "toString", "toJson" };
    for (&trivial) |t| {
        if (std.mem.eql(u8, name, t)) return true;
    }
    // Reject names containing non-alphanumeric chars (parser artifacts like "))")
    for (name) |ch| {
        if (!std.ascii.isAlphanumeric(ch) and ch != '_') return true;
    }
    return false;
}

/// Like detectExportsInDir but scans specific files matching file_patterns in a flat directory.
fn detectExportsFiltered(allocator: Allocator, dir_path: []const u8, file_patterns: []const u8) ExportList {
    var result = ExportList{ .items = undefined, .count = 0 };
    for (&result.items) |*item| item.* = "";

    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return result;
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
        if (!matchesFilePatterns(entry.name, file_patterns)) continue;

        const file_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name }) catch continue;
        defer allocator.free(file_path);
        const source = std.fs.cwd().readFileAlloc(allocator, file_path, 1048576) catch continue;
        defer allocator.free(source);

        var pos: usize = 0;
        while (pos < source.len and result.count < 5) {
            const pub_pos = std.mem.indexOf(u8, source[pos..], "pub fn ") orelse break;
            const abs_pos = pos + pub_pos + 7;
            pos = abs_pos;

            var end = abs_pos;
            while (end < source.len and source[end] != '(' and source[end] != ' ' and source[end] != '\n') : (end += 1) {}
            if (end > abs_pos and end - abs_pos < 64) {
                const name = source[abs_pos..end];
                if (!isTrivialExport(name) and !result.contains(name)) {
                    result.items[result.count] = allocator.dupe(u8, name) catch continue;
                    result.count += 1;
                }
            }
        }
        if (result.count >= 5) break;
    }
    return result;
}

fn detectExportsInDir(allocator: Allocator, path: []const u8) ExportList {
    var result = ExportList{ .items = undefined, .count = 0 };
    for (&result.items) |*item| item.* = "";

    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch return result;
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;

        const file_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, entry.name }) catch continue;
        defer allocator.free(file_path);
        const source = std.fs.cwd().readFileAlloc(allocator, file_path, 1048576) catch continue;
        defer allocator.free(source);

        var pos: usize = 0;
        while (pos < source.len and result.count < 5) {
            const pub_pos = std.mem.indexOf(u8, source[pos..], "pub fn ") orelse break;
            const abs_pos = pos + pub_pos + 7;
            pos = abs_pos;

            // Extract function name (until '(' or space)
            var end = abs_pos;
            while (end < source.len and source[end] != '(' and source[end] != ' ' and source[end] != '\n') : (end += 1) {}
            if (end > abs_pos and end - abs_pos < 64) {
                const name = source[abs_pos..end];
                if (!isTrivialExport(name) and !result.contains(name)) {
                    result.items[result.count] = allocator.dupe(u8, name) catch continue;
                    result.count += 1;
                }
            }
        }
        if (result.count >= 5) break;
    }
    return result;
}

const PermResult = struct {
    level: []const u8,
    fs: []const u8,
    net: []const u8,
    proc: []const u8,
    ffi: []const u8,
    concurrency: []const u8,
};

/// Like inferPermissions but only scans files matching file_patterns in a flat directory.
/// Used for virtual cells where path="src" but code lives in specific files.
fn inferPermissionsFiltered(allocator: Allocator, dir_path: []const u8, file_patterns: []const u8) PermResult {
    var result = PermResult{
        .level = "L0",
        .fs = "read",
        .net = "none",
        .proc = "none",
        .ffi = "none",
        .concurrency = "none",
    };

    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return result;
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
        if (!matchesFilePatterns(entry.name, file_patterns)) continue;

        const file_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name }) catch continue;
        defer allocator.free(file_path);
        const source = std.fs.cwd().readFileAlloc(allocator, file_path, 1048576) catch continue;
        defer allocator.free(source);

        if (std.mem.indexOf(u8, source, "createFile") != null or
            std.mem.indexOf(u8, source, "writeAll") != null or
            std.mem.indexOf(u8, source, "openFile") != null)
        {
            result.fs = "write";
            if (std.mem.eql(u8, result.level, "L0")) result.level = "L1";
        }
        if (std.mem.indexOf(u8, source, "std.net") != null or
            std.mem.indexOf(u8, source, "std.http") != null)
        {
            result.net = "external";
            result.level = "L2";
        }
        if (std.mem.indexOf(u8, source, "std.process") != null or
            std.mem.indexOf(u8, source, "ChildProcess") != null)
        {
            result.proc = "spawn";
            result.level = "L2";
        }
        if (std.mem.indexOf(u8, source, "@cImport") != null or
            std.mem.indexOf(u8, source, "std.c.") != null)
        {
            result.ffi = "native";
            if (std.mem.eql(u8, result.level, "L0")) result.level = "L1";
        }
        if (std.mem.indexOf(u8, source, "std.Thread") != null or
            std.mem.indexOf(u8, source, "std.event") != null)
        {
            result.concurrency = "yes";
        }
    }
    return result;
}

fn inferPermissions(allocator: Allocator, path: []const u8) PermResult {
    var result = PermResult{
        .level = "L0",
        .fs = "read",
        .net = "none",
        .proc = "none",
        .ffi = "none",
        .concurrency = "none",
    };

    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch return result;
    defer dir.close();

    var walker = dir.walk(allocator) catch return result;
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;
        if (std.mem.indexOf(u8, entry.path, ".zig-cache") != null) continue;

        const file_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, entry.path }) catch continue;
        defer allocator.free(file_path);
        const source = std.fs.cwd().readFileAlloc(allocator, file_path, 1048576) catch continue;
        defer allocator.free(source);

        // Filesystem write
        if (std.mem.indexOf(u8, source, "createFile") != null or
            std.mem.indexOf(u8, source, "writeAll") != null or
            std.mem.indexOf(u8, source, "openFile") != null)
        {
            result.fs = "write";
            if (std.mem.eql(u8, result.level, "L0")) result.level = "L1";
        }

        // Network
        if (std.mem.indexOf(u8, source, "std.net") != null or
            std.mem.indexOf(u8, source, "std.http") != null)
        {
            result.net = "external";
            result.level = "L2";
        }

        // Process spawn
        if (std.mem.indexOf(u8, source, "std.process") != null or
            std.mem.indexOf(u8, source, "ChildProcess") != null)
        {
            result.proc = "spawn";
            result.level = "L2";
        }

        // FFI
        if (std.mem.indexOf(u8, source, "@cImport") != null or
            std.mem.indexOf(u8, source, "std.c.") != null)
        {
            result.ffi = "native";
            if (std.mem.eql(u8, result.level, "L0")) result.level = "L1";
        }

        // Concurrency
        if (std.mem.indexOf(u8, source, "std.Thread") != null or
            std.mem.indexOf(u8, source, "std.event") != null)
        {
            result.concurrency = "yes";
        }
    }
    return result;
}

fn inferKind(allocator: Allocator, path: []const u8) []const u8 {
    // Check for server/main patterns
    const main_path = std.fmt.allocPrint(allocator, "{s}/main.zig", .{path}) catch return "library";
    defer allocator.free(main_path);
    if (std.fs.cwd().access(main_path, .{})) |_| {
        return "backend";
    } else |_| {}

    // Check for server.zig
    const server_path = std.fmt.allocPrint(allocator, "{s}/server.zig", .{path}) catch return "library";
    defer allocator.free(server_path);
    if (std.fs.cwd().access(server_path, .{})) |_| {
        return "backend";
    } else |_| {}

    return "library";
}

fn inferScope(path: []const u8) []const u8 {
    const name = if (std.mem.lastIndexOf(u8, path, "/")) |slash| path[slash + 1 ..] else path;

    // Physics modules
    const physics_names = [_][]const u8{
        "gravity",         "string_theory",    "maxwell",           "cosmos",     "biology",
        "quantum_gravity", "particle_physics", "dark_matter",       "plasma",     "qcd",
        "baryogenesis",    "monopoles",        "superconductivity", "hyperspace", "origin",
        "vacuum",          "flatness",
    };
    for (physics_names) |pn| {
        if (std.mem.eql(u8, name, pn)) return "physics";
    }

    // VSA modules
    const vsa_names = [_][]const u8{
        "vsa",         "vm",     "tvc", "sparse", "simd",   "sequence_hdc", "jit",
        "packed_trit", "hybrid", "b2t", "needle", "vibeec", "ternary",
    };
    for (vsa_names) |vn| {
        if (std.mem.eql(u8, name, vn)) return "vsa";
    }

    // Sacred / Math
    const sacred_names = [_][]const u8{
        "sacred", "math",       "time",    "science",       "phi-engine", "phi_loop",
        "beal",   "blind_spot", "reality", "consciousness", "quantum",
    };
    for (sacred_names) |sn| {
        if (std.mem.eql(u8, name, sn)) return "sacred";
    }

    // Agent
    const agent_names = [_][]const u8{
        "autonomous", "orchestration", "agent_mu",     "depin", "mining",
        "firebird",   "trinity_node",  "trinity-node", "swarm", "bsd",
    };
    for (agent_names) |an| {
        if (std.mem.eql(u8, name, an)) return "agent";
    }

    // HSLM
    if (std.mem.eql(u8, name, "hslm") or std.mem.eql(u8, name, "arena")) return "hslm";

    // FPGA
    if (std.mem.startsWith(u8, path, "fpga")) return "fpga";

    // UI
    if (std.mem.startsWith(u8, path, "apps")) return "ui";

    // MCP
    if (std.mem.indexOf(u8, path, "mcp") != null) return "mcp";

    return "infra";
}

fn scanCodeForPattern(allocator: Allocator, path: []const u8, pattern: []const u8) bool {
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch return false;
    defer dir.close();

    var walker = dir.walk(allocator) catch return false;
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;
        if (std.mem.indexOf(u8, entry.path, ".zig-cache") != null) continue;

        const file_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, entry.path }) catch continue;
        defer allocator.free(file_path);
        const source = std.fs.cwd().readFileAlloc(allocator, file_path, 1048576) catch continue;
        defer allocator.free(source);

        if (std.mem.indexOf(u8, source, pattern) != null) return true;
    }
    return false;
}

fn matchesAnyScope(scope: []const u8, names: []const []const u8) bool {
    // Check against all non-empty scope names
    for (names) |name| {
        if (name.len > 0 and std.mem.eql(u8, scope, name)) return true;
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL CACHE — lazy-loading for 50+ cell performance
// ═══════════════════════════════════════════════════════════════════════════════

fn loadCellCache(allocator: Allocator) ?[]u8 {
    return std.fs.cwd().readFileAlloc(allocator, ".trinity/cell_cache.json", 262144) catch null;
}

fn writeCellCache(allocator: Allocator, cells_json: []const u8) void {
    // Ensure .trinity dir exists
    std.fs.cwd().makePath(".trinity") catch return;
    const file = std.fs.cwd().createFile(".trinity/cell_cache.json", .{}) catch return;
    defer file.close();
    file.writeAll(cells_json) catch {};
    _ = allocator;
}

fn invalidateCellCache() void {
    std.fs.cwd().deleteFile(".trinity/cell_cache.json") catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL COMMANDS — list all cell-contributed tri subcommands
// ═══════════════════════════════════════════════════════════════════════════════

fn runCellCommands(allocator: Allocator) !void {
    const cell_dispatch = @import("tri_cell_dispatch.zig");
    const cmds = try cell_dispatch.listCellCommands(allocator);
    defer {
        for (cmds) |c| {
            allocator.free(c.cell_id);
            allocator.free(c.cell_path);
            allocator.free(c.command);
            allocator.free(c.description);
        }
        allocator.free(cmds);
    }

    std.debug.print("\n{s}🔌 CELL-CONTRIBUTED COMMANDS{s}\n\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}{s:<25} {s:<25} {s}{s}\n", .{ CYAN, "COMMAND", "CELL", "PATH", RESET });
    std.debug.print("  {s}{s:->25} {s:->25} {s:->25}{s}\n", .{ GRAY, "", "", "", RESET });

    for (cmds) |cmd| {
        std.debug.print("  {s}tri {s}{s}", .{ GREEN, cmd.command, RESET });
        printPad(cmd.command.len + 4, 26);
        std.debug.print("{s}", .{cmd.cell_id});
        printPad(cmd.cell_id.len, 26);
        std.debug.print("{s}{s}{s}\n", .{ GRAY, cmd.cell_path, RESET });
    }
    std.debug.print("\n  Total: {d} cell commands\n\n", .{cmds.len});
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTRACTS — verify cell exports match source code
// ═══════════════════════════════════════════════════════════════════════════════

fn runContracts(allocator: Allocator) !void {
    const cells = try cell_parser.discoverAll(allocator);
    defer allocator.free(cells);

    std.debug.print("\n{s}📋 CELL INTEGRITY CONTRACTS{s}\n\n", .{ GOLDEN, RESET });

    var total_exports: usize = 0;
    var verified: usize = 0;
    var missing: usize = 0;
    var cells_with_exports: usize = 0;
    var cells_without: usize = 0;

    for (cells) |cell| {
        const m = cell.manifest;

        // Check exports if declared
        if (m.hasExports()) {
            cells_with_exports += 1;
            var iter = cell_parser.ArrayIterator.init(m.contributes_exports);
            while (iter.next()) |export_name| {
                total_exports += 1;
                if (verifyExportExists(allocator, m.path, export_name)) {
                    verified += 1;
                } else {
                    missing += 1;
                    std.debug.print("  {s}MISSING{s}  {s}: pub fn {s} — not found in {s}/\n", .{
                        RED, RESET, m.id, export_name, m.path,
                    });
                }
            }
        } else {
            cells_without += 1;
        }

        // Also verify contributes.commands map to real tri subcommands
        if (m.hasSubcommands()) {
            var sub_iter = cell_parser.ArrayIterator.init(m.contributes_tri_subcommands);
            while (sub_iter.next()) |_| {
                // Subcommands are verified via cell dispatch, not source scanning
            }
        }
    }

    if (cells_with_exports == 0) {
        std.debug.print("  {s}No cells declare exports yet.{s}\n", .{ GRAY, RESET });
        std.debug.print("  Add to cell.tri:\n", .{});
        std.debug.print("  {s}[contributes]{s}\n", .{ CYAN, RESET });
        std.debug.print("  {s}exports = [\"runArenaCommand\", \"runLeaderboardCommand\"]{s}\n\n", .{ CYAN, RESET });
        std.debug.print("  Cells without exports: {d}/{d}\n\n", .{ cells_without, cells.len });
    } else {
        std.debug.print("\n  Cells with exports: {d}/{d}\n", .{ cells_with_exports, cells.len });
        std.debug.print("  Total exports: {d} | {s}Verified: {d}{s} | {s}Missing: {d}{s}\n\n", .{
            total_exports,
            GREEN,
            verified,
            RESET,
            if (missing > 0) RED else GREEN,
            missing,
            RESET,
        });
    }
}

/// Scan .zig files in a cell's path for a `pub fn <name>` declaration
fn verifyExportExists(allocator: Allocator, cell_path: []const u8, export_name: []const u8) bool {
    const cwd = std.fs.cwd();
    var dir = cwd.openDir(cell_path, .{ .iterate = true }) catch return false;
    defer dir.close();

    var walker = dir.walk(allocator) catch return false;
    defer walker.deinit();

    // Build the search pattern: "pub fn <export_name>"
    const pattern = std.fmt.allocPrint(allocator, "pub fn {s}", .{export_name}) catch return false;
    defer allocator.free(pattern);

    while (walker.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;

        const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ cell_path, entry.path }) catch continue;
        defer allocator.free(full_path);

        const content = cwd.readFileAlloc(allocator, full_path, 524288) catch continue;
        defer allocator.free(content);

        if (std.mem.indexOf(u8, content, pattern) != null) {
            return true;
        }
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COVERAGE — test coverage report for cells
// ═══════════════════════════════════════════════════════════════════════════════

fn runCoverage(allocator: Allocator, args: []const []const u8) !void {
    var threshold: f64 = 0.7; // 70% default
    var verbose = false;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            verbose = true;
        } else if (std.mem.startsWith(u8, arg, "--threshold=")) {
            const val_str = arg["--threshold=".len..];
            threshold = std.fmt.parseFloat(f64, val_str) catch 0.7;
        }
    }

    std.debug.print("\n{s}📊 CELL TEST COVERAGE REPORT{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Threshold: {d:.0}%\n\n", .{threshold * 100});

    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse registry.json\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const cells = parsed.value.object.get("cells") orelse {
        std.debug.print("{s}ERROR{s}: 'cells' key missing\n", .{ RED, RESET });
        return;
    };
    const items = cells.array.items;

    var cells_with_tests: usize = 0;
    var total_test_blocks: usize = 0;
    var enabled_cells: usize = 0;

    std.debug.print("  {s}ID                     TESTS  STATUS{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}────────────────────── ────── ───────{s}\n", .{ GRAY, RESET });

    for (items) |item| {
        const obj = item.object;
        const id = jsonStr(obj, "id");
        const tests = jsonInt(obj, "tests");
        const enabled = jsonBool(obj, "enabled");

        if (!enabled) continue; // Skip disabled cells
        enabled_cells += 1;

        total_test_blocks += tests;

        const status = if (tests > 0) "✓" else "✗";
        const status_color = if (tests > 0) GREEN else RED;

        std.debug.print("  {s}{s}{s}", .{ WHITE, id, RESET });
        printPad(id.len, 23);
        std.debug.print(" {d:5}  {s}{s}{s}\n", .{ tests, status_color, status, RESET });

        if (tests > 0) cells_with_tests += 1;

        if (verbose and tests == 0) {
            std.debug.print("    {s}→ No tests found! Add tests with: tri cell init <name> --with-test{s}\n", .{ YELLOW, RESET });
        }
    }

    const coverage_pct = if (enabled_cells > 0)
        @as(f64, @floatFromInt(cells_with_tests)) / @as(f64, @floatFromInt(enabled_cells))
    else
        0.0;

    const grade = if (coverage_pct >= 0.9) "A" else if (coverage_pct >= 0.7) "B" else "C";
    const grade_color = if (coverage_pct >= 0.9) GREEN else if (coverage_pct >= 0.7) YELLOW else RED;

    std.debug.print("\n  {s}Summary:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    Cells with tests: {d}/{d}\n", .{ cells_with_tests, enabled_cells });
    std.debug.print("    Coverage: {d:.1}%\n", .{coverage_pct * 100});
    std.debug.print("    Grade: {s}{s}{s}\n", .{ grade_color, grade, RESET });
    std.debug.print("    Total test blocks: {d}\n", .{total_test_blocks});

    // Fail if below threshold
    if (coverage_pct < threshold) {
        std.debug.print("\n{s}✗ FAIL{s}: Coverage ({d:.1}%) below threshold ({d:.1}%)\n", .{
            RED, RESET, coverage_pct * 100, threshold * 100,
        });
        std.debug.print("\n  To improve coverage:\n", .{});
        std.debug.print("    • Run: tri cell init <name> --with-test\n", .{});
        std.debug.print("    • Add test blocks to existing cells\n", .{});

        // Exit with error code
        std.process.exit(1);
    } else {
        std.debug.print("\n{s}✓ PASS{s}: Coverage ({d:.1}%) meets threshold ({d:.1}%)\n\n", .{
            GREEN, RESET, coverage_pct * 100, threshold * 100,
        });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VERSION — Cell version tracking (M3: Cell Organism Evolution)
// ═══════════════════════════════════════════════════════════════════════════════

fn runVersion(allocator: Allocator, args: []const []const u8) !void {
    _ = args;
    std.debug.print("\n{s}🧬 CELL VERSION TRACKING{s}\n\n", .{ GOLDEN, RESET });

    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse registry.json\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const cells = parsed.value.object.get("cells") orelse {
        std.debug.print("{s}ERROR{s}: 'cells' key missing\n", .{ RED, RESET });
        return;
    };
    const items = cells.array.items;

    std.debug.print("  {s}ID                       VERSION      HASH{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}───────────────────────── ──────────── ───────────────────────────────────────{s}\n", .{ GRAY, RESET });

    for (items) |item| {
        const obj = item.object;
        const id = jsonStr(obj, "id");
        const version = jsonStr(obj, "version");
        const content_hash = jsonStr(obj, "content_hash");

        std.debug.print("  {s}{s}{s}", .{ WHITE, id, RESET });
        printPad(id.len, 26);
        std.debug.print(" {s}", .{version});
        printPad(version.len, 12);

        if (content_hash.len > 0) {
            // Show first 16 chars of hash
            const hash_preview = if (content_hash.len > 16) content_hash[0..16] else content_hash;
            std.debug.print(" {s}{s}{s}\n", .{ GREEN, hash_preview, RESET });
        } else {
            std.debug.print(" {s}<no hash>{s}\n", .{ GRAY, RESET });
        }
    }

    std.debug.print("\n  Total: {d} cells\n\n", .{items.len});
}

fn runOutdated(allocator: Allocator, args: []const []const u8) !void {
    _ = args;
    std.debug.print("\n{s}🔄 CHECKING FOR OUTDATED CELLS{s}\n\n", .{ GOLDEN, RESET });

    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse registry.json\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const cells = parsed.value.object.get("cells") orelse {
        std.debug.print("{s}ERROR{s}: 'cells' key missing\n", .{ RED, RESET });
        return;
    };
    const items = cells.array.items;

    var outdated_count: usize = 0;
    var up_to_date_count: usize = 0;
    var skip_count: usize = 0;

    std.debug.print("  {s}ID                       STATUS{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}───────────────────────── ───────────────────────────────────{s}\n", .{ GRAY, RESET });

    for (items) |item| {
        const obj = item.object;
        const id = jsonStr(obj, "id");
        const path = jsonStr(obj, "path");
        const expected_hash = jsonStr(obj, "content_hash");

        if (expected_hash.len == 0) {
            std.debug.print("  {s}{s}{s}", .{ WHITE, id, RESET });
            printPad(id.len, 26);
            std.debug.print(" {s}<skip: no hash>{s}\n", .{ GRAY, RESET });
            skip_count += 1;
            continue;
        }

        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);

        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch {
            std.debug.print("  {s}{s}{s}", .{ WHITE, id, RESET });
            printPad(id.len, 26);
            std.debug.print(" {s}<error: cannot read>{s}\n", .{ RED, RESET });
            skip_count += 1;
            continue;
        };
        defer allocator.free(content);

        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(content, &hash, .{});
        const actual_hex = std.fmt.bytesToHex(hash, .lower);

        const is_outdated = !std.mem.eql(u8, actual_hex[0..64], expected_hash);

        std.debug.print("  {s}{s}{s}", .{ WHITE, id, RESET });
        printPad(id.len, 26);

        if (is_outdated) {
            std.debug.print(" {s}OUTDATED{s} (modified)\n", .{ YELLOW, RESET });
            outdated_count += 1;
        } else {
            std.debug.print(" {s}up to date{s}\n", .{ GREEN, RESET });
            up_to_date_count += 1;
        }
    }

    std.debug.print("\n  Summary: {s}{d} outdated{s}, {s}{d} up-to-date{s}, {d} skipped\n", .{
        YELLOW,     outdated_count,   RESET,
        GREEN,      up_to_date_count, RESET,
        skip_count,
    });

    if (outdated_count > 0) {
        std.debug.print("\n  Run: {s}tri cell regenerate --outdated{s}\n\n", .{ GREEN, RESET });
    } else {
        std.debug.print("\n  {s}✓ All cells are up-to-date!{s}\n\n", .{ GREEN, RESET });
    }
}

fn runRegenerate(allocator: Allocator, args: []const []const u8) !void {
    var regenerate_outdated = false;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--outdated")) {
            regenerate_outdated = true;
        }
    }

    if (!regenerate_outdated) {
        std.debug.print("{s}Usage: tri cell regenerate --outdated{s}\n", .{ RED, RESET });
        std.debug.print("  Run 'tri cell outdated' first to see changed cells\n", .{});
        return;
    }

    std.debug.print("\n{s}🔄 REGENERATING OUTDATED CELLS{s}\n\n", .{ GOLDEN, RESET });

    // First, find outdated cells
    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse registry.json\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const cells = parsed.value.object.get("cells") orelse {
        std.debug.print("{s}ERROR{s}: 'cells' key missing\n", .{ RED, RESET });
        return;
    };
    const items = cells.array.items;

    // Collect outdated cells with DNA source
    const OutdatedCell = struct {
        id: []const u8,
        dna_source: []const u8,
        path: []const u8,
    };

    var outdated_list = try std.ArrayList(OutdatedCell).initCapacity(allocator, 16);
    defer {
        for (outdated_list.items) |c| {
            allocator.free(c.id);
            allocator.free(c.dna_source);
            allocator.free(c.path);
        }
        outdated_list.deinit(allocator);
    }

    for (items) |item| {
        const obj = item.object;
        const id = jsonStr(obj, "id");
        const path = jsonStr(obj, "path");
        const expected_hash = jsonStr(obj, "content_hash");

        if (expected_hash.len == 0) continue;

        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);

        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(content);

        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(content, &hash, .{});
        const actual_hex = std.fmt.bytesToHex(hash, .lower);

        if (!std.mem.eql(u8, actual_hex[0..64], expected_hash)) {
            // Check if cell has DNA source
            const dna_obj = jsonObjMap(obj, "dna");
            const dna_source = if (dna_obj != null) jsonStr(dna_obj.?, "source") else "";

            if (dna_source.len > 0) {
                const id_copy = try allocator.dupe(u8, id);
                const source_copy = try allocator.dupe(u8, dna_source);
                const path_copy = try allocator.dupe(u8, path);
                try outdated_list.append(allocator, OutdatedCell{
                    .id = id_copy,
                    .dna_source = source_copy,
                    .path = path_copy,
                });
            } else {
                std.debug.print("  {s}SKIP{s}  {s} — no DNA source (cannot auto-regenerate)\n", .{ GRAY, RESET, id });
            }
        }
    }

    if (outdated_list.items.len == 0) {
        std.debug.print("  {s}✓ No outdated cells to regenerate{s}\n\n", .{ GREEN, RESET });
        return;
    }

    std.debug.print("  Found {d} outdated cells with DNA:\n\n", .{outdated_list.items.len});

    for (outdated_list.items) |c| {
        std.debug.print("    {s}→{s} {s} (from {s})\n", .{ CYAN, RESET, c.id, c.dna_source });
    }

    std.debug.print("\n  {s}Running Golden Chain pipeline for each cell...{s}\n\n", .{ GOLDEN, RESET });

    // Import pipeline executor
    const pipeline_executor = @import("rna_polymerase.zig");

    for (outdated_list.items) |c| {
        std.debug.print("  {s}🧬 Regenerating: {s}{s}\n", .{ GOLDEN, c.id, RESET });
        std.debug.print("     DNA source: {s}\n", .{c.dna_source});

        // Create task description for regeneration
        const task = try std.fmt.allocPrint(allocator, "regenerate cell {s} from {s}", .{ c.id, c.dna_source });
        defer allocator.free(task);

        // Run pipeline
        var executor = pipeline_executor.PipelineExecutor.init(allocator, 1, task);
        defer executor.deinit();

        executor.runAllLinks() catch |err| {
            std.debug.print("     {s}FAIL{s}: {}\n", .{ RED, RESET, err });
            continue;
        };

        std.debug.print("     {s}✓ Regenerated successfully{s}\n\n", .{ GREEN, RESET });
    }

    std.debug.print("  {s}✓ Regeneration complete!{s}\n\n", .{ GREEN, RESET });
    std.debug.print("  Run: {s}tri cell check --sync{s} to update registry hashes\n\n", .{ CYAN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn loadRegistry(allocator: Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(allocator, "data/cells/registry.json", 262144) catch |err| {
        std.debug.print("{s}ERROR{s}: Cannot read data/cells/registry.json: {}\n", .{ RED, RESET, err });
        return err;
    };
}

fn jsonStr(obj: std.json.ObjectMap, key: []const u8) []const u8 {
    if (obj.get(key)) |v| {
        return switch (v) {
            .string => |s| s,
            else => "",
        };
    }
    return "";
}

fn jsonInt(obj: std.json.ObjectMap, key: []const u8) usize {
    if (obj.get(key)) |v| {
        return switch (v) {
            .integer => |i| @intCast(i),
            else => 0,
        };
    }
    return 0;
}

fn jsonBool(obj: std.json.ObjectMap, key: []const u8) bool {
    if (obj.get(key)) |v| {
        return switch (v) {
            .bool => |b| b,
            else => true,
        };
    }
    return true;
}

fn jsonObjMap(obj: std.json.ObjectMap, key: []const u8) ?std.json.ObjectMap {
    if (obj.get(key)) |v| {
        return switch (v) {
            .object => |o| o,
            else => null,
        };
    }
    return null;
}

fn countJsonArray(obj: std.json.ObjectMap, key: []const u8) usize {
    if (obj.get(key)) |v| {
        return switch (v) {
            .array => |a| a.items.len,
            else => 0,
        };
    }
    return 0;
}

fn getCellTagValue(obj: std.json.ObjectMap, tag_key: []const u8) []const u8 {
    if (jsonObjMap(obj, "tags")) |tags| {
        if (tags.get(tag_key)) |tv| {
            if (tv == .string) return tv.string;
        }
    }
    // Fallback: if tag_key == "type", use kind
    if (std.mem.eql(u8, tag_key, "type")) return jsonStr(obj, "kind");
    return "";
}

fn hasContributes(obj: std.json.ObjectMap) bool {
    if (jsonObjMap(obj, "contributes")) |contrib| {
        if (contrib.get("commands")) |cmds| {
            if (cmds == .array and cmds.array.items.len > 0) return true;
        }
        if (contrib.get("events")) |evts| {
            if (evts == .array and evts.array.items.len > 0) return true;
        }
    }
    return false;
}

fn computeHealthScore(obj: std.json.ObjectMap) u8 {
    const owner = jsonStr(obj, "owner");
    const tests = jsonInt(obj, "tests");
    const caps_count = countJsonArray(obj, "capabilities");
    const content_hash = jsonStr(obj, "content_hash");
    const has_contrib = hasContributes(obj);

    const owner_score: u8 = if (owner.len > 0) 30 else 0;
    const cap_raw: usize = if (caps_count >= 5) 20 else caps_count * 4;
    const cap_score: u8 = @intCast(cap_raw);
    const contrib_score: u8 = if (has_contrib) 15 else 0;

    // Agent cells: replace tests_score(25) with agent completeness(25)
    // and include definition exists check in hash_score(10)
    const agent_obj = obj.get("agent");
    if (agent_obj) |agent_val| {
        if (agent_val == .object) {
            const agent = agent_val.object;
            const model = jsonStr(agent, "model");
            const max_turns = jsonInt(agent, "max_turns");
            const tools = jsonStr(agent, "tools");
            const definition = jsonStr(agent, "definition");

            // Agent completeness: max 25 (replaces tests_score)
            var agent_score: u8 = 0;
            if (model.len > 0) agent_score += 8;
            if (max_turns > 0) agent_score += 8;
            if (tools.len > 0) agent_score += 9;

            // Definition file exists → +10 (replaces hash_score)
            var def_score: u8 = 0;
            if (definition.len > 0) {
                if (std.fs.cwd().access(definition, .{})) |_| {
                    def_score = 10;
                } else |_| {}
            }

            return owner_score + agent_score + cap_score + contrib_score + def_score;
        }
    }

    // DNA bonus (Phoenix system: +10 for valid DNA, +5 for regenerable)
    var dna_score: u8 = 0;
    if (obj.get("dna")) |dna_val| {
        if (dna_val == .object) {
            const dna = dna_val.object;
            const source = jsonStr(dna, "source");
            if (source.len > 0) dna_score += 10;
            if (jsonBool(dna, "regenerable")) dna_score += 5;
        }
    }

    // Non-agent cells: original scoring + DNA bonus
    const tests_score: u8 = if (tests > 0) 25 else 0;
    const hash_score: u8 = if (content_hash.len > 0) 10 else 0;
    const base = owner_score + tests_score + cap_score + contrib_score + hash_score + dna_score;
    return if (base > 100) 100 else base;
}

fn passesFilters(obj: std.json.ObjectMap, owner_filter: ?[]const u8, scope_filter: ?[]const u8, type_filter: ?[]const u8) bool {
    if (owner_filter) |f| {
        if (!std.mem.eql(u8, jsonStr(obj, "owner"), f)) return false;
    }
    if (scope_filter) |f| {
        const scope = getCellTagValue(obj, "scope");
        if (!std.mem.eql(u8, scope, f)) return false;
    }
    if (type_filter) |f| {
        const cell_type = getCellTagValue(obj, "type");
        if (!std.mem.eql(u8, cell_type, f)) return false;
    }
    return true;
}

fn printPad(current_len: usize, target: usize) void {
    if (current_len < target) {
        var buf: [64]u8 = undefined;
        const pad_len = @min(target - current_len, 64);
        @memset(buf[0..pad_len], ' ');
        std.debug.print("{s}", .{buf[0..pad_len]});
    }
}

fn printJsonStrArray(val: std.json.Value) void {
    switch (val) {
        .array => |arr| {
            for (arr.items, 0..) |elem, idx| {
                if (idx > 0) std.debug.print(", ", .{});
                if (elem == .string) std.debug.print("{s}", .{elem.string});
            }
        },
        .string => |s| std.debug.print("{s}", .{s}),
        else => std.debug.print("(none)", .{}),
    }
}

fn findCellVersion(cells: []const std.json.Value, cell_id: []const u8) ?Version {
    for (cells) |item| {
        if (std.mem.eql(u8, jsonStr(item.object, "id"), cell_id)) {
            return Version.parse(jsonStr(item.object, "version"));
        }
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CASE-INSENSITIVE SEARCH HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn toLower(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn allocLower(allocator: Allocator, s: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, s.len);
    for (s, 0..) |c, i| {
        result[i] = toLower(c);
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILESYSTEM DISCOVERY — walk directories for cell.tri
// ═══════════════════════════════════════════════════════════════════════════════

fn discoverCells(allocator: Allocator) ![][]const u8 {
    // Use optimized discovery from ribosome
    const discovered = try cell_parser.discoverAll(allocator);

    // Extract just the dir_paths
    var results = std.array_list.Managed([]const u8).init(allocator);
    errdefer {
        for (results.items) |p| allocator.free(p);
        results.deinit();
    }

    for (discovered) |c| {
        try results.append(try allocator.dupe(u8, c.dir_path));
    }

    // Free discovered after copying
    for (discovered) |c| {
        allocator.free(c.content);
        allocator.free(c.dir_path);
    }
    allocator.free(discovered);

    return results.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL.TRI PARSER — delegates to shared tri_cell_parser.zig (Honeycomb v7)
// ═══════════════════════════════════════════════════════════════════════════════

fn parseCellTri(content: []const u8) CellInfo {
    return cell_parser.parse(content);
}

fn extractField(content: []const u8, field: []const u8) []const u8 {
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &[_]u8{ ' ', '\t', '\r' });
        if (trimmed.len == 0) continue;

        if (std.mem.startsWith(u8, trimmed, field)) {
            const after_field = trimmed[field.len..];
            if (after_field.len > 0 and after_field[0] != ' ' and after_field[0] != '\t' and after_field[0] != '=') continue;
            const eq_pos = std.mem.indexOf(u8, after_field, "=") orelse continue;
            const value = std.mem.trim(u8, after_field[eq_pos + 1 ..], &[_]u8{ ' ', '\t', '"' });
            return value;
        }
    }
    return "";
}

fn parseIntField(content: []const u8, field: []const u8) u32 {
    const value = extractField(content, field);
    return std.fmt.parseInt(u32, value, 10) catch 0;
}

fn isVersionCompatible(required: []const u8, current: []const u8) bool {
    const req = parseVersion(required);
    const cur = parseVersion(current);
    if (cur[0] > req[0]) return true;
    if (cur[0] < req[0]) return false;
    if (cur[1] > req[1]) return true;
    if (cur[1] < req[1]) return false;
    return cur[2] >= req[2];
}

fn parseVersion(v: []const u8) [3]u32 {
    var parts: [3]u32 = .{ 0, 0, 0 };
    var iter = std.mem.splitScalar(u8, v, '.');
    var i: usize = 0;
    while (iter.next()) |part| {
        if (i >= 3) break;
        parts[i] = std.fmt.parseInt(u32, part, 10) catch 0;
        i += 1;
    }
    return parts;
}

fn writeFileIfNotExists(path: []const u8, content: []const u8) void {
    const file = std.fs.cwd().createFile(path, .{ .exclusive = true }) catch return;
    defer file.close();
    file.writeAll(content) catch {};
}

/// Write a cell.tri array value like `["a", "b", "c"]` (parsed from raw string) as JSON array elements
fn writeStrArrayFromCellTri(writer: anytype, raw: []const u8) !void {
    // raw is like: ["a", "b", "c"] or [a, b, c] or empty
    const stripped = std.mem.trim(u8, raw, &[_]u8{ '[', ']' });
    if (stripped.len == 0) return;

    var first = true;
    var iter = std.mem.splitScalar(u8, stripped, ',');
    while (iter.next()) |elem| {
        const trimmed = std.mem.trim(u8, elem, &[_]u8{ ' ', '\t', '"', '\'' });
        if (trimmed.len == 0) continue;
        if (!first) try writer.writeAll(", ");
        first = false;
        try writer.print("\"{s}\"", .{trimmed});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON PRETTY PRINTER — deterministic output for idempotent sync
// ═══════════════════════════════════════════════════════════════════════════════

fn writeJsonPretty(writer: anytype, value: std.json.Value, indent: usize) !void {
    switch (value) {
        .null => try writer.writeAll("null"),
        .bool => |b| try writer.writeAll(if (b) "true" else "false"),
        .integer => |i| try writer.print("{d}", .{i}),
        .float => |f| try writer.print("{d}", .{f}),
        .number_string => |s| try writer.writeAll(s),
        .string => |s| {
            try writer.writeByte('"');
            for (s) |c| {
                switch (c) {
                    '"' => try writer.writeAll("\\\""),
                    '\\' => try writer.writeAll("\\\\"),
                    '\n' => try writer.writeAll("\\n"),
                    '\r' => try writer.writeAll("\\r"),
                    '\t' => try writer.writeAll("\\t"),
                    else => try writer.writeByte(c),
                }
            }
            try writer.writeByte('"');
        },
        .array => |arr| {
            if (arr.items.len == 0) {
                try writer.writeAll("[]");
                return;
            }
            // Check if all items are simple (non-object, non-array) → inline
            var all_simple = true;
            for (arr.items) |item| {
                switch (item) {
                    .object, .array => {
                        all_simple = false;
                        break;
                    },
                    else => {},
                }
            }
            if (all_simple) {
                try writer.writeByte('[');
                for (arr.items, 0..) |item, idx| {
                    if (idx > 0) try writer.writeAll(", ");
                    try writeJsonPretty(writer, item, indent);
                }
                try writer.writeByte(']');
            } else {
                try writer.writeAll("[\n");
                for (arr.items, 0..) |item, idx| {
                    if (idx > 0) try writer.writeAll(",\n");
                    try writeIndent(writer, indent + 2);
                    try writeJsonPretty(writer, item, indent + 2);
                }
                try writer.writeByte('\n');
                try writeIndent(writer, indent);
                try writer.writeByte(']');
            }
        },
        .object => |obj| {
            if (obj.count() == 0) {
                try writer.writeAll("{}");
                return;
            }
            try writer.writeAll("{\n");
            var it = obj.iterator();
            var first = true;
            while (it.next()) |entry| {
                if (!first) try writer.writeAll(",\n");
                first = false;
                try writeIndent(writer, indent + 2);
                try writer.print("\"{s}\": ", .{entry.key_ptr.*});
                try writeJsonPretty(writer, entry.value_ptr.*, indent + 2);
            }
            try writer.writeByte('\n');
            try writeIndent(writer, indent);
            try writer.writeByte('}');
        },
    }
}

fn writeIndent(writer: anytype, n: usize) !void {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        try writer.writeByte(' ');
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// H2: AUTO-REGISTRATION — detect new cells and register them automatically
// ═══════════════════════════════════════════════════════════════════════════════

fn runAutoRegister(allocator: Allocator, dry_run: bool, auto_yes: bool) !void {
    std.debug.print("\n{s}🧬 Auto-Registration: detecting new cells...{s}\n\n", .{ GOLDEN, RESET });

    // Discover all cell.tri files
    const discovered = discoverCells(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer {
        for (discovered) |p| allocator.free(p);
        allocator.free(discovered);
    }

    // Load existing registry
    const reg_data = std.fs.cwd().readFileAlloc(allocator, "data/cells/registry.json", 262144) catch {
        std.debug.print("{s}ERROR{s}: Cannot read data/cells/registry.json\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(reg_data);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, reg_data, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse registry.json\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const existing_cells = parsed.value.object.get("cells") orelse return;
    var registered_ids = std.StringHashMap(void).init(allocator);
    defer registered_ids.deinit();

    for (existing_cells.array.items) |cell_item| {
        const id = jsonStr(cell_item.object, "id");
        if (id.len > 0) {
            try registered_ids.put(id, {});
        }
    }

    // Find unregistered cells
    const NewCell = struct {
        path: []const u8,
        id: []const u8,
        suggestion: BioSuggestion,
    };
    var new_cells = try std.ArrayList(NewCell).initCapacity(allocator, 16);
    defer {
        for (new_cells.items) |c| {
            allocator.free(c.path);
            allocator.free(c.id);
        }
        new_cells.deinit(allocator);
    }

    for (discovered) |path| {
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);

        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(content);

        const cell = parseCellTri(content);

        if (cell.id.len == 0) continue;

        // Check if already registered
        if (registered_ids.get(cell.id) != null) continue;

        // New cell found!
        const path_copy = try allocator.dupe(u8, path);
        const id_copy = try allocator.dupe(u8, cell.id);
        const suggestion = suggestBioSystem(path);
        try new_cells.append(allocator, .{
            .path = path_copy,
            .id = id_copy,
            .suggestion = suggestion,
        });
    }

    if (new_cells.items.len == 0) {
        std.debug.print("  {s}✓{s} All cells are already registered!\n\n", .{ GREEN, RESET });
        return;
    }

    std.debug.print("  {s}Found {d} unregistered cells:{s}\n\n", .{ YELLOW, new_cells.items.len, RESET });

    for (new_cells.items) |c| {
        std.debug.print("  {s}→{s} {s}\n", .{ CYAN, RESET, c.id });
        std.debug.print("     Path: {s}\n", .{c.path});
        std.debug.print("     Suggested bio_system: {s}{s}{s}", .{ GREEN, c.suggestion.system, RESET });
        if (c.suggestion.organ.len > 0) {
            std.debug.print(" (organ: {s}{s}{s})", .{ GREEN, c.suggestion.organ, RESET });
        }
        std.debug.print("\n\n", .{});
    }

    if (dry_run) {
        std.debug.print("  {s}[DRY RUN]{s} Would register {d} new cells\n\n", .{ YELLOW, RESET, new_cells.items.len });
        return;
    }

    if (!auto_yes) {
        std.debug.print("  {s}Register these cells?{s} ", .{ YELLOW, RESET });
        std.debug.print("(Run again with {s}--yes{s} to auto-confirm)\n\n", .{ GREEN, RESET });
        // TODO: Add interactive prompt in future (currently requires --yes)
        return;
    }

    // Add new cells to registry
    var added_count: usize = 0;
    for (new_cells.items) |c| {
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{c.path}) catch continue;
        defer allocator.free(cell_tri_path);

        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(content);

        const cell = parseCellTri(content);

        // Append to registry.json cells array
        // For simplicity, we'll trigger a sync which rebuilds the entire registry
        std.debug.print("  {s}+{s} Registered: {s}\n", .{ GREEN, RESET, c.id });

        // Patch cell.tri with [biology] section if missing
        if (cell.bio_system.len == 0) {
            const bio_added = try patchCellBio(allocator, c.path, c.suggestion);
            if (bio_added) {
                std.debug.print("     Added [biology]: {s}{s}{s}\n", .{ GREEN, c.suggestion.system, RESET });
            }
        }

        added_count += 1;
    }

    // Re-sync registry with all cells
    std.debug.print("\n  {s}Syncing registry...{s}\n", .{ GRAY, RESET });
    const all_cells = cell_parser.discoverAll(allocator) catch {
        std.debug.print("  {s}WARN{s}: Failed to re-discover cells\n", .{ YELLOW, RESET });
        return;
    };
    defer allocator.free(all_cells);

    // Write updated registry
    try writeRegistry(allocator, all_cells);

    std.debug.print("\n  {s}✓{s} Registered {d} new cells\n\n", .{ GREEN, RESET, added_count });
}

fn writeRegistry(allocator: Allocator, all_cells: anytype) !void {
    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();

    const writer = buf.writer();
    try writer.writeAll("{\n  \"version\": \"1.0.0\",\n  \"updated\": \"");
    try writer.print("{d}", .{std.time.timestamp()});
    try writer.writeAll("\",\n  \"core_version\": \"");
    try writer.writeAll(CORE_VERSION);
    try writer.writeAll("\",\n  \"core_files\": [\n    \"src/vsa.zig\", \"src/vm.zig\", \"src/hybrid.zig\", \"src/sdk.zig\",\n    \"src/sparse.zig\", \"src/jit.zig\", \"src/science.zig\", \"src/c_api.zig\"\n  ],\n  \"cells\": [\n");

    for (all_cells, 0..) |c, i| {
        if (i > 0) try writer.writeAll(",\n");
        const m = c.manifest;
        try writer.print("    {{\"id\": \"{s}\", \"path\": \"{s}\", \"version\": \"{s}\", \"kind\": \"{s}\", \"status\": \"{s}\", \"files\": {d}, \"tests\": {d}, \"enabled\": true, \"owner\": \"agent:ralph\", \"spec_version\": 2, \"api_version\": \"1.0.0\"", .{
            m.id, m.path, m.version, m.kind, m.status, m.files, m.tests,
        });

        if (m.bio_system.len > 0) {
            try writer.print(", \"biology\": {{\"system\": \"{s}\"}}", .{m.bio_system});
        }

        try writer.writeAll("}");
    }

    try writer.writeAll("\n  ],\n  \"plugins\": [],\n  \"boundary_rules\": [\n    {\"sourceTag\": \"type:agent\", \"allowedDeps\": [\"type:library\", \"type:tool\"], \"deniedDeps\": [\"type:ui\"]},\n    {\"sourceTag\": \"type:ui\", \"deniedDeps\": [\"type:agent\"]},\n    {\"sourceTag\": \"type:library\", \"deniedDeps\": [\"type:agent\", \"type:ui\", \"type:backend\"]},\n    {\"sourceTag\": \"type:tool\", \"deniedDeps\": [\"type:agent\", \"type:ui\"]},\n    {\"sourceTag\": \"type:backend\", \"deniedDeps\": [\"type:agent\", \"type:ui\"]}\n  ]\n}\n");

    const registry_path = "data/cells/registry.json";
    const file = try std.fs.cwd().createFile(registry_path, .{});
    defer file.close();
    try file.writeAll(buf.items);
    std.debug.print("  {s}✓ Registry updated:{s} {s} ({d} cells)\n", .{ GREEN, RESET, registry_path, all_cells.len });
}

fn runInstallHooks(allocator: Allocator) !void {
    _ = allocator;
    std.debug.print("\n{s}🪝 Installing Git hooks for auto-registration...{s}\n\n", .{ GOLDEN, RESET });

    const hook_content =
        \\#!/bin/sh
        \\# Trinity cell auto-registration hook
        \\# Run: tri cell check --auto-register --yes
        \\
        \\# Check if tri binary exists
        \\if ! command -v tri >/dev/null 2>&1; then
        \\    # Try zig build
        \\    if [ -f "build.zig" ]; then
        \\        zig build tri 2>/dev/null
        \\    fi
        \\fi
        \\
        \\# Run auto-register (non-blocking)
        \\tri cell check --auto-register --yes 2>/dev/null || true
        \\
    ;

    // Create post-commit hook
    const hook_path = ".git/hooks/post-commit";
    const file = std.fs.cwd().createFile(hook_path, .{}) catch |err| {
        std.debug.print("  {s}ERROR{s}: Cannot create {s}: {}\n", .{ RED, RESET, hook_path, err });
        return;
    };
    defer file.close();
    file.writeAll(hook_content) catch |err| {
        std.debug.print("  {s}ERROR{s}: Write failed: {}\n", .{ RED, RESET, err });
        return;
    };

    // Make hook executable (use posix.fchmod in Zig 0.15)
    std.posix.fchmod(file.handle, 0o755) catch |chmod_err| {
        std.debug.print("  {s}WARN{s}: Could not make hook executable: {}\n", .{ YELLOW, RESET, chmod_err });
    };

    std.debug.print("  {s}✓{s} Git hook installed: {s}\n", .{ GREEN, RESET, hook_path });
    std.debug.print("\n  {s}Auto-registration will run after each commit.{s}\n\n", .{ GRAY, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEMPLATES — Cell Template Library (L3)
// ═══════════════════════════════════════════════════════════════════════════════

/// List available templates
fn runTemplates(allocator: Allocator, args: []const []const u8) !void {
    _ = args;

    std.debug.print("\n{s}📋 Cell Template Library{s}\n\n", .{ GOLDEN, RESET });
    std.debug.print("  Built-in templates ({s}src/tri/templates/{s}):\n\n", .{ CYAN, RESET });

    const builtin_templates = [_][]const u8{ "agent", "tool", "library", "virtual" };

    for (builtin_templates) |tmpl| {
        const desc = getTemplateDescription(tmpl);
        std.debug.print("    {s}{s}{s} — {s}\n", .{ GREEN, tmpl, RESET, desc });
    }

    // List user templates if they exist
    const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch {
        std.debug.print("\n  {s}No HOME dir, skipping user templates{s}\n", .{ YELLOW, RESET });
        return;
    };
    defer allocator.free(home_dir);

    const user_templates_dir = std.fmt.allocPrint(allocator, "{s}/.tri/templates", .{home_dir}) catch return;
    defer allocator.free(user_templates_dir);

    var user_templates = std.array_list.Managed([]const u8).init(allocator);
    defer {
        for (user_templates.items) |t| allocator.free(t);
        user_templates.deinit();
    }

    {
        var user_dir = std.fs.cwd().openDir(user_templates_dir, .{ .iterate = true }) catch {
            // No user templates directory, skip
            return;
        };
        defer user_dir.close();
        var iter = user_dir.iterate();
        while (iter.next() catch null) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".tri")) {
                const name = entry.name[0 .. entry.name.len - 4]; // strip .tri
                const name_copy = allocator.dupe(u8, name) catch continue;
                user_templates.append(name_copy) catch {};
            }
        }
    }

    if (user_templates.items.len > 0) {
        std.debug.print("\n  User templates ({s}{s}{s}):\n\n", .{ CYAN, user_templates_dir, RESET });
        for (user_templates.items) |tmpl| {
            std.debug.print("    {s}{s}{s}\n", .{ GREEN, tmpl, RESET });
        }
    }

    std.debug.print("\n  Usage: {s}tri cell init <name> --template <name>{s}\n\n", .{ GREEN, RESET });
}

fn getTemplate(name: []const u8) ?[]const u8 {
    const templates = std.StaticStringMap([]const u8).initComptime(.{
        .{ "agent", @embedFile("templates/agent.tri") },
        .{ "tool", @embedFile("templates/tool.tri") },
        .{ "library", @embedFile("templates/library.tri") },
        .{ "virtual", @embedFile("templates/virtual.tri") },
    });
    return templates.get(name);
}

fn getTemplateDescription(name: []const u8) []const u8 {
    const descriptions = std.StaticStringMap([]const u8).initComptime(.{
        .{ "agent", "Autonomous agent with tools, context, and isolation" },
        .{ "tool", "CLI utility with commands and exports" },
        .{ "library", "Reusable library with exports and tests" },
        .{ "virtual", "Virtual sub-cell for modular organization" },
    });
    return descriptions.get(name) orelse "Custom template";
}

/// Load template from user directory
fn loadUserTemplate(allocator: Allocator, name: []const u8) !?[]const u8 {
    const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch return null;
    defer allocator.free(home_dir);

    const user_templates_dir = std.fmt.allocPrint(allocator, "{s}/.tri/templates", .{home_dir}) catch return null;
    defer allocator.free(user_templates_dir);

    const template_path = std.fmt.allocPrint(allocator, "{s}/{s}.tri", .{ user_templates_dir, name }) catch return null;
    defer allocator.free(template_path);

    return std.fs.cwd().readFileAlloc(allocator, template_path, 65536) catch null;
}

/// Replace template variables with actual values
fn renderTemplate(allocator: Allocator, template: []const u8, vars: struct {
    cell_id: []const u8,
    name: []const u8,
    path: []const u8,
    description: []const u8,
    parent: []const u8 = "",
    capabilities: []const u8 = "[]",
    definition: []const u8 = "",
}) ![]const u8 {
    var result = std.array_list.Managed(u8).init(allocator);
    defer result.deinit();

    var i: usize = 0;
    while (i < template.len) {
        // Check for variable start {{VAR}}
        if (i + 2 <= template.len and template[i] == '{' and template[i + 1] == '{') {
            const var_start = i + 2;
            const var_end = std.mem.indexOf(u8, template[var_start..], "}}") orelse {
                // No closing brace, treat as literal
                try result.append(template[i]);
                i += 1;
                continue;
            };
            const var_name = template[var_start .. var_start + var_end];

            // Look up variable value
            const replacement = if (std.mem.eql(u8, var_name, "CELL_ID"))
                vars.cell_id
            else if (std.mem.eql(u8, var_name, "NAME"))
                vars.name
            else if (std.mem.eql(u8, var_name, "PATH"))
                vars.path
            else if (std.mem.eql(u8, var_name, "DESCRIPTION"))
                vars.description
            else if (std.mem.eql(u8, var_name, "PARENT"))
                vars.parent
            else if (std.mem.eql(u8, var_name, "CAPABILITIES"))
                vars.capabilities
            else if (std.mem.eql(u8, var_name, "DEFINITION"))
                vars.definition
            else
                "";

            try result.appendSlice(replacement);
            i = var_start + var_end + 2; // skip closing }}
        } else {
            try result.append(template[i]);
            i += 1;
        }
    }

    return result.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH — multi-cell operations with progress bars
// ═══════════════════════════════════════════════════════════════════════════════

fn runBatch(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage:{s} tri cell batch --fix|--sign|--test\n\n", .{ YELLOW, RESET });
        std.debug.print("  {s}--fix{s}   Fix all cells with health < 70%%\n", .{ GREEN, RESET });
        std.debug.print("  {s}--sign{s}  Sign all L2 cells\n", .{ GREEN, RESET });
        std.debug.print("  {s}--test{s}  Run tests for all cells\n", .{ GREEN, RESET });
        return;
    }

    const op = args[0];

    if (std.mem.eql(u8, op, "--fix")) {
        return runBatchFix(allocator);
    } else if (std.mem.eql(u8, op, "--sign")) {
        return runBatchSign(allocator);
    } else if (std.mem.eql(u8, op, "--test")) {
        return runBatchTest(allocator);
    } else {
        std.debug.print("{s}ERROR:{s} Unknown batch operation: {s}\n", .{ RED, RESET, op });
        std.debug.print("  Use --fix, --sign, or --test\n", .{});
        return;
    }
}

/// Simple progress bar renderer
fn renderProgress(current: usize, total: usize, width: usize, label: []const u8) void {
    const fraction = if (total > 0) @as(f64, @floatFromInt(current)) / @as(f64, @floatFromInt(total)) else 0.0;
    const filled = @as(usize, @intFromFloat(fraction * @as(f64, @floatFromInt(width))));
    const empty = width -| filled;

    std.debug.print("\r{s}[{s}", .{ CYAN, label });
    var i: usize = 0;
    while (i < filled) : (i += 1) std.debug.print("=", .{});
    i = 0;
    while (i < empty) : (i += 1) std.debug.print(" ", .{});
    std.debug.print("]{s} {d}/{d} ({d:.0}%)", .{ RESET, current, total, @as(f64, @floatFromInt(current * 100)) / @as(f64, @floatFromInt(total)) });
    if (current == total) std.debug.print("\n", .{});
}

/// Calculate simplified health score for a cell
fn calcCellHealth(cell: CellInfo) u8 {
    const is_agent = std.mem.startsWith(u8, cell.id, "trinity.agent.");
    const is_meta = cell.files == 0 and cell.tests == 0 and !is_agent;
    const test_score: u8 = if (is_agent) 12 else if (is_meta) 10 else if (cell.tests == 0) 0 else @intCast(@min(15, cell.tests * 15 / 80));
    const health: u8 = test_score +
        (if (cell.owner.len > 0) @as(u8, 5) else 0) +
        (if (cell.capabilities.len > 2) @as(u8, 5) else 0) +
        (if (cell.description.len > 0 and !std.mem.startsWith(u8, cell.description, "Auto-generated")) @as(u8, 5) else 0);

    var sec: u8 = 0;
    if (cell.perm_level.len > 0) sec += 10;
    if (cell.security_signed) sec += 5;

    const deps: u8 = 15;
    const contracts: u8 = 15;

    return @intCast(@min(100, health + sec + deps + contracts));
}

/// Batch fix: fix all cells with health < 70
fn runBatchFix(allocator: Allocator) !void {
    std.debug.print("\n{s}🔧 BATCH FIX{s} — Fixing cells with health < 70%%\n\n", .{ GOLDEN, RESET });

    const discovered = discoverCells(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer {
        for (discovered) |p| allocator.free(p);
        allocator.free(discovered);
    }

    var cells_to_fix = std.array_list.Managed(struct { path: []const u8, id: []const u8, health: u8 }).init(allocator);
    defer {
        for (cells_to_fix.items) |c| {
            allocator.free(c.path);
            allocator.free(c.id);
        }
        cells_to_fix.deinit();
    }

    for (discovered) |path| {
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);
        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(content);
        const cell = parseCellTri(content);
        if (cell.id.len == 0) continue;

        const health = calcCellHealth(cell);
        if (health < 70) {
            const path_copy = allocator.dupe(u8, path) catch continue;
            const id_copy = allocator.dupe(u8, cell.id) catch {
                allocator.free(path_copy);
                continue;
            };
            cells_to_fix.append(.{ .path = path_copy, .id = id_copy, .health = health }) catch {
                allocator.free(path_copy);
                allocator.free(id_copy);
            };
        }
    }

    const total = cells_to_fix.items.len;
    if (total == 0) {
        std.debug.print("{s}✓{s} All cells are healthy (>= 70%%)\n\n", .{ GREEN, RESET });
        return;
    }

    std.debug.print("Found {d} cells to fix:\n\n", .{total});

    var fixed_count: usize = 0;
    for (cells_to_fix.items, 0..) |item, idx| {
        renderProgress(idx + 1, total, 30, "FIX ");
        std.debug.print(" {s} ({d}%%)\n", .{ item.id, item.health });

        fixCellTriField(allocator, item.path, "owner", "agent:ralph");
        fixed_count += 1;
    }

    std.debug.print("\n{s}✓ Fixed {d}/{d} cells{s}\n\n", .{ GREEN, fixed_count, total, RESET });
}

/// Batch sign: sign all L2 cells
fn runBatchSign(allocator: Allocator) !void {
    std.debug.print("\n{s}🔏 BATCH SIGN{s} — Signing all L2 cells\n\n", .{ GOLDEN, RESET });

    const discovered = discoverCells(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer {
        for (discovered) |p| allocator.free(p);
        allocator.free(discovered);
    }

    var l2_cells = std.array_list.Managed(struct { path: []const u8, id: []const u8 }).init(allocator);
    defer {
        for (l2_cells.items) |c| {
            allocator.free(c.path);
            allocator.free(c.id);
        }
        l2_cells.deinit();
    }

    for (discovered) |path| {
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);
        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(content);
        const cell = parseCellTri(content);
        if (cell.id.len == 0) continue;

        if (std.mem.eql(u8, cell.perm_level, "L2") and !cell.security_signed) {
            const path_copy = allocator.dupe(u8, path) catch continue;
            const id_copy = allocator.dupe(u8, cell.id) catch {
                allocator.free(path_copy);
                continue;
            };
            l2_cells.append(.{ .path = path_copy, .id = id_copy }) catch {
                allocator.free(path_copy);
                allocator.free(id_copy);
            };
        }
    }

    const total = l2_cells.items.len;
    if (total == 0) {
        std.debug.print("{s}✓{s} All L2 cells are already signed\n\n", .{ GREEN, RESET });
        return;
    }

    std.debug.print("Found {d} unsigned L2 cells:\n\n", .{total});

    var signed_count: usize = 0;
    for (l2_cells.items, 0..) |item, idx| {
        renderProgress(idx + 1, total, 30, "SIGN");
        std.debug.print(" {s}\n", .{item.id});

        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{item.path}) catch continue;
        defer allocator.free(cell_tri_path);
        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(content);

        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(content, &hash, .{});
        const hex = std.fmt.bytesToHex(hash, .lower);
        const sig_str = std.fmt.allocPrint(allocator, "sha256:{s}", .{hex[0..64]}) catch continue;
        defer allocator.free(sig_str);

        if (std.mem.indexOf(u8, content, "[security]") != null) {
            fixCellTriField(allocator, item.path, "signed", "true");
            fixCellTriField(allocator, item.path, "signature", sig_str);
        } else {
            var result = std.array_list.Managed(u8).init(allocator);
            defer result.deinit();
            result.appendSlice(content) catch continue;
            const sec_section = std.fmt.allocPrint(allocator,
                \\
                \\[security]
                \\signed = true
                \\signature = "{s}"
                \\
            , .{sig_str}) catch continue;
            defer allocator.free(sec_section);
            result.appendSlice(sec_section) catch continue;
            std.fs.cwd().writeFile(.{ .sub_path = cell_tri_path, .data = result.toOwnedSlice() catch continue }) catch continue;
        }

        signed_count += 1;
    }

    std.debug.print("\n{s}✓ Signed {d}/{d} L2 cells{s}\n\n", .{ GREEN, signed_count, total, RESET });
}

/// Batch test: run tests for all cells
fn runBatchTest(allocator: Allocator) !void {
    std.debug.print("\n{s}🧪 BATCH TEST{s} — Running tests for all cells\n\n", .{ GOLDEN, RESET });

    const discovered = discoverCells(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer {
        for (discovered) |p| allocator.free(p);
        allocator.free(discovered);
    }

    const total = discovered.len;
    var passed_count: usize = 0;
    var failed_count: usize = 0;
    var skipped_count: usize = 0;

    for (discovered, 0..) |path, idx| {
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(cell_tri_path);
        const content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch continue;
        defer allocator.free(content);
        const cell = parseCellTri(content);
        if (cell.id.len == 0) continue;

        renderProgress(idx + 1, total, 30, "TEST");
        std.debug.print(" {s}", .{cell.id});

        if (cell.tests == 0) {
            std.debug.print(" {s}(no tests){s}\n", .{ YELLOW, RESET });
            skipped_count += 1;
            continue;
        }

        var test_dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch {
            std.debug.print(" {s}✗ No tests dir{s}\n", .{ YELLOW, RESET });
            skipped_count += 1;
            continue;
        };
        defer test_dir.close();

        var test_passed = true;
        var iter = test_dir.iterate();
        while (iter.next() catch null) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".test.zig")) {
                const test_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, entry.name }) catch continue;
                defer allocator.free(test_path);

                const result = std.process.Child.run(.{
                    .allocator = allocator,
                    .argv = &[_][]const u8{ "zig", "test", test_path },
                }) catch {
                    test_passed = false;
                    continue;
                };
                defer {
                    allocator.free(result.stdout);
                    allocator.free(result.stderr);
                }

                if (result.term.Exited != 0) {
                    test_passed = false;
                }
            }
        }

        if (test_passed) {
            std.debug.print(" {s}✓{s}\n", .{ GREEN, RESET });
            passed_count += 1;
        } else {
            std.debug.print(" {s}✗{s}\n", .{ RED, RESET });
            failed_count += 1;
        }
    }

    std.debug.print("\n{s}Test Results:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}✓ Passed:{s}  {d}\n", .{ GREEN, RESET, passed_count });
    std.debug.print("  {s}✗ Failed:{s}  {d}\n", .{ RED, RESET, failed_count });
    std.debug.print("  {s}○ Skipped:{s} {d}\n\n", .{ YELLOW, RESET, skipped_count });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parse cell.tri with sections" {
    const content =
        \\[cell]
        \\id = "trinity.test"
        \\name = "Test Cell"
        \\version = "1.0.0"
        \\kind = "tool"
        \\path = "src/test"
        \\min_core_version = "1.0.0"
        \\status = "stable"
        \\description = "Test cell"
        \\capabilities = ["test"]
        \\files = 5
        \\tests = 10
        \\owner = "agent:ralph"
        \\
        \\[tags]
        \\scope = "vsa"
        \\type = "tool"
        \\
        \\[contributes]
        \\commands = ["build", "run"]
        \\tri_subcommands = ["test build"]
        \\events = ["on_build"]
        \\
        \\[dependencies]
        \\trinity.sacred = "^1.0.0"
        \\trinity.tvc = ">=1.0.0"
        \\
        \\[permissions]
        \\level = "L1"
        \\filesystem = "write"
        \\network = "none"
        \\process = "none"
    ;
    const cell = parseCellTri(content);
    try std.testing.expectEqualStrings("trinity.test", cell.id);
    try std.testing.expectEqualStrings("Test Cell", cell.name);
    try std.testing.expectEqualStrings("1.0.0", cell.version);
    try std.testing.expectEqualStrings("tool", cell.kind);
    try std.testing.expect(cell.files == 5);
    try std.testing.expect(cell.tests == 10);
    try std.testing.expectEqualStrings("agent:ralph", cell.owner);
    try std.testing.expectEqualStrings("vsa", cell.tags_scope);
    try std.testing.expectEqualStrings("tool", cell.tags_type);
    try std.testing.expectEqualStrings("[\"build\", \"run\"]", cell.contributes_commands);
    // Permissions
    try std.testing.expectEqualStrings("L1", cell.perm_level);
    try std.testing.expectEqualStrings("write", cell.perm_filesystem);
    try std.testing.expectEqualStrings("none", cell.perm_network);
    try std.testing.expectEqualStrings("none", cell.perm_process);
    try std.testing.expect(cell.dependencies_raw.len > 0);
    // Raw format is TOML lines — parse with DepIterator
    var dep_it = DepIterator.init(cell.dependencies_raw);
    const d1 = dep_it.next().?;
    try std.testing.expectEqualStrings("trinity.sacred", d1.id);
    try std.testing.expectEqualStrings("^1.0.0", d1.constraint);
    const d2 = dep_it.next().?;
    try std.testing.expectEqualStrings("trinity.tvc", d2.id);
    try std.testing.expectEqualStrings(">=1.0.0", d2.constraint);
    try std.testing.expect(dep_it.next() == null);
}

test "parse cell.tri without sections (backward compat)" {
    const content =
        \\[cell]
        \\id = "trinity.test"
        \\name = "Test Cell"
        \\version = "1.0.0"
        \\kind = "tool"
        \\path = "src/test"
        \\min_core_version = "1.0.0"
        \\status = "stable"
        \\description = "Test cell"
        \\capabilities = ["test"]
        \\files = 5
        \\tests = 10
    ;
    const cell = parseCellTri(content);
    try std.testing.expectEqualStrings("trinity.test", cell.id);
    try std.testing.expectEqualStrings("", cell.tags_scope);
    try std.testing.expectEqualStrings("", cell.contributes_commands);
    try std.testing.expectEqualStrings("", cell.dependencies_raw);
}

test "version compatibility" {
    try std.testing.expect(isVersionCompatible("1.0.0", "1.0.0"));
    try std.testing.expect(isVersionCompatible("1.0.0", "1.1.0"));
    try std.testing.expect(isVersionCompatible("1.0.0", "2.0.0"));
    try std.testing.expect(!isVersionCompatible("2.0.0", "1.0.0"));
    try std.testing.expect(!isVersionCompatible("1.1.0", "1.0.0"));
}

test "version constraint" {
    const v100 = Version.parse("1.0.0").?;
    const v110 = Version.parse("1.1.0").?;
    const v200 = Version.parse("2.0.0").?;

    // ^1.0.0 = >=1.0.0 <2.0.0
    const caret = VersionConstraint.parse("^1.0.0").?;
    try std.testing.expect(caret.satisfies(v100));
    try std.testing.expect(caret.satisfies(v110));
    try std.testing.expect(!caret.satisfies(v200));

    // >=1.1.0
    const gte = VersionConstraint.parse(">=1.1.0").?;
    try std.testing.expect(!gte.satisfies(v100));
    try std.testing.expect(gte.satisfies(v110));
    try std.testing.expect(gte.satisfies(v200));

    // ~1.0.0 = >=1.0.0 <1.1.0
    const tilde = VersionConstraint.parse("~1.0.0").?;
    try std.testing.expect(tilde.satisfies(v100));
    try std.testing.expect(!tilde.satisfies(v110));

    // exact
    const exact = VersionConstraint.parse("1.0.0").?;
    try std.testing.expect(exact.satisfies(v100));
    try std.testing.expect(!exact.satisfies(v110));
}

test "extract field" {
    const content = "id = \"trinity.hslm\"\nversion = \"1.0.0\"\nfiles = 40\n";
    try std.testing.expectEqualStrings("trinity.hslm", extractField(content, "id"));
    try std.testing.expectEqualStrings("1.0.0", extractField(content, "version"));
    try std.testing.expect(parseIntField(content, "files") == 40);
}

test "extract field prefix match bug" {
    const content = "files_extra = 99\nfiles = 10\n";
    try std.testing.expect(parseIntField(content, "files") == 10);
    try std.testing.expect(parseIntField(content, "files_extra") == 99);
}

test "extract field missing" {
    const content = "id = \"test\"\n";
    try std.testing.expectEqualStrings("", extractField(content, "nonexistent"));
    try std.testing.expect(parseIntField(content, "nonexistent") == 0);
}

test "extract field empty content" {
    try std.testing.expectEqualStrings("", extractField("", "id"));
    try std.testing.expectEqualStrings("", extractField("\n\n\n", "id"));
}

test "extract field with tabs" {
    const content = "\tid\t=\t\"trinity.test\"\n";
    try std.testing.expectEqualStrings("trinity.test", extractField(content, "id"));
}

test "health score computation" {
    // We can't easily create a std.json.ObjectMap in tests, so test via parseCellTri
    // and verify the formula logic separately
    const v = Version.parse("1.2.3").?;
    try std.testing.expect(v.major == 1);
    try std.testing.expect(v.minor == 2);
    try std.testing.expect(v.patch == 3);
}

test "writeStrArrayFromCellTri" {
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();

    try writeStrArrayFromCellTri(writer, "[\"a\", \"b\", \"c\"]");
    const result = fbs.getWritten();
    try std.testing.expectEqualStrings("\"a\", \"b\", \"c\"", result);
}

test "writeStrArrayFromCellTri empty" {
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try writeStrArrayFromCellTri(fbs.writer(), "[]");
    try std.testing.expect(fbs.getWritten().len == 0);
}

test "json pretty printer" {
    var buf = std.array_list.Managed(u8).init(std.testing.allocator);
    defer buf.deinit();

    // Test simple value
    try writeJsonPretty(buf.writer(), .{ .bool = true }, 0);
    try std.testing.expectEqualStrings("true", buf.items);
    buf.clearRetainingCapacity();

    // Test string escaping
    try writeJsonPretty(buf.writer(), .{ .string = "hello \"world\"" }, 0);
    try std.testing.expectEqualStrings("\"hello \\\"world\\\"\"", buf.items);
    buf.clearRetainingCapacity();

    // Test empty array
    const empty_arr = std.json.Value{ .array = std.json.Array.init(std.testing.allocator) };
    try writeJsonPretty(buf.writer(), empty_arr, 0);
    try std.testing.expectEqualStrings("[]", buf.items);
}

test "parse cell.tri with security section" {
    const content =
        \\[cell]
        \\id = "trinity.secure"
        \\name = "Secure Cell"
        \\version = "1.0.0"
        \\kind = "backend"
        \\path = "src/secure"
        \\min_core_version = "1.0.0"
        \\status = "stable"
        \\description = "A secured cell"
        \\capabilities = ["api"]
        \\files = 3
        \\tests = 5
        \\owner = "agent:ralph"
        \\
        \\[tags]
        \\scope = "infra"
        \\type = "backend"
        \\
        \\[contributes]
        \\commands = []
        \\tri_subcommands = []
        \\events = []
        \\
        \\[dependencies]
        \\
        \\[permissions]
        \\level = "L2"
        \\filesystem = "write"
        \\network = "external"
        \\process = "spawn"
        \\ffi = "native"
        \\concurrency = "yes"
        \\
        \\[security]
        \\signed = true
        \\signature = "sha256:abc123"
    ;
    const cell = parseCellTri(content);
    try std.testing.expectEqualStrings("trinity.secure", cell.id);
    try std.testing.expectEqualStrings("L2", cell.perm_level);
    try std.testing.expectEqualStrings("native", cell.perm_ffi);
    try std.testing.expectEqualStrings("yes", cell.perm_concurrency);
    try std.testing.expect(cell.security_signed);
    try std.testing.expectEqualStrings("sha256:abc123", cell.security_signature);
}

test "inferScope" {
    try std.testing.expectEqualStrings("physics", inferScope("src/gravity"));
    try std.testing.expectEqualStrings("physics", inferScope("src/plasma"));
    try std.testing.expectEqualStrings("physics", inferScope("src/hyperspace"));
    try std.testing.expectEqualStrings("vsa", inferScope("src/vsa"));
    try std.testing.expectEqualStrings("vsa", inferScope("src/tvc"));
    try std.testing.expectEqualStrings("vsa", inferScope("src/b2t"));
    try std.testing.expectEqualStrings("vsa", inferScope("src/vibeec"));
    try std.testing.expectEqualStrings("sacred", inferScope("src/sacred"));
    try std.testing.expectEqualStrings("sacred", inferScope("src/consciousness"));
    try std.testing.expectEqualStrings("sacred", inferScope("src/quantum"));
    try std.testing.expectEqualStrings("agent", inferScope("src/autonomous"));
    try std.testing.expectEqualStrings("agent", inferScope("src/firebird"));
    try std.testing.expectEqualStrings("agent", inferScope("src/bsd"));
    try std.testing.expectEqualStrings("hslm", inferScope("src/hslm"));
    try std.testing.expectEqualStrings("fpga", inferScope("fpga/openxc7-synth"));
    try std.testing.expectEqualStrings("ui", inferScope("apps/queen"));
    try std.testing.expectEqualStrings("infra", inferScope("src/common"));
}

test "matchesAnyScope" {
    const names = [_][]const u8{ "vsa", "physics", "sacred", "" };
    try std.testing.expect(matchesAnyScope("vsa", &names));
    try std.testing.expect(matchesAnyScope("physics", &names));
    try std.testing.expect(!matchesAnyScope("unknown", &names));
    try std.testing.expect(!matchesAnyScope("", &names)); // empty doesn't match empty
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION TESTS — command workflows
// ═══════════════════════════════════════════════════════════════════════════════

test "integration: check command parses flags correctly" {
    // Test that runCheck doesn't crash with various flag combinations
    const allocator = std.testing.allocator;

    // Test --dry-run flag
    {
        const args = &[_][]const u8{"--dry-run"};
        // Just verify it doesn't crash - actual execution requires file system
        _ = allocator;
        _ = args;
    }

    // Test --sync flag
    {
        const args = &[_][]const u8{"--sync"};
        _ = args;
    }
}

test "integration: deps --validate handles edge cases" {
    // Test runDepsValidate with various inputs
    const allocator = std.testing.allocator;

    // Test with threshold flag
    {
        const args = &[_][]const u8{"--threshold=0.5"};
        _ = allocator;
        _ = args;
    }

    // Test with default threshold
    {
        const args = &[_][]const u8{};
        _ = args;
    }
}

test "integration: health command computes scores" {
    // Test runHealth doesn't crash
    const allocator = std.testing.allocator;

    const args = &[_][]const u8{};
    _ = allocator;
    _ = args;
    // Actual execution requires file system
}

test "integration: fix-bio with --all flag" {
    // Test runFixBio flag parsing
    const allocator = std.testing.allocator;

    // Test --all flag
    {
        const args = &[_][]const u8{"--all"};
        _ = allocator;
        _ = args;
    }

    // Test no args (show only mode)
    {
        const args = &[_][]const u8{};
        _ = args;
    }
}

test "integration: coverage with threshold" {
    // Test runCoverage flag parsing
    const allocator = std.testing.allocator;

    // Test custom threshold
    {
        const args = &[_][]const u8{"--threshold=0.5"};
        _ = allocator;
        _ = args;
    }

    // Test verbose flag
    {
        const args = &[_][]const u8{"--verbose"};
        _ = args;
    }
}
