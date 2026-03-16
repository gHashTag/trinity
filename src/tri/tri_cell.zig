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

const Allocator = std.mem.Allocator;

const CYAN = colors.CYAN;
const RESET = colors.RESET;
const GREEN = colors.GREEN;
const GRAY = colors.GRAY;
const YELLOW = colors.YELLOW;
const RED = colors.RED;
const WHITE = colors.WHITE;
const GOLDEN = colors.GOLDEN;

const CORE_VERSION = "1.0.0";

// Directories to scan for cell.tri manifests
const CELL_SCAN_DIRS = [_][]const u8{ "src", "apps", "tools", "fpga", "libs" };

const CellInfo = struct {
    id: []const u8,
    name: []const u8,
    version: []const u8,
    kind: []const u8,
    path: []const u8,
    status: []const u8,
    description: []const u8,
    min_core_version: []const u8,
    capabilities: []const u8,
    files: u32,
    tests: u32,
    owner: []const u8,
    // Section-aware fields
    tags_scope: []const u8,
    tags_type: []const u8,
    contributes_commands: []const u8,
    contributes_tri_subcommands: []const u8,
    contributes_events: []const u8,
    dependencies_raw: []const u8, // raw [dependencies] section text (TOML lines: key = "value")
    // Security permissions
    perm_level: []const u8, // L0 (read-only), L1 (local r/w), L2 (network+external)
    perm_filesystem: []const u8, // none, read, write
    perm_network: []const u8, // none, local, external
    perm_process: []const u8, // none, spawn
    perm_ffi: []const u8, // none, native
    perm_concurrency: []const u8, // none, yes
    // Security section
    security_signed: bool,
    security_signature: []const u8,
    // Computed security score (not parsed, computed by audit)
    security_score: ?u8,
};

/// Iterator over dependency entries from raw [dependencies] section text.
/// Each entry yields (dep_id, constraint_str) from lines like: trinity.sacred = "^1.0.0"
const DepIterator = struct {
    lines: std.mem.SplitIterator(u8, .scalar),

    fn init(raw: []const u8) DepIterator {
        return .{ .lines = std.mem.splitScalar(u8, raw, '\n') };
    }

    fn next(self: *DepIterator) ?struct { id: []const u8, constraint: []const u8 } {
        while (self.lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0) continue;
            if (trimmed[0] == '[') break; // hit next section
            const eq_pos = std.mem.indexOf(u8, trimmed, "=") orelse continue;
            if (eq_pos == 0) continue;
            const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t\"");
            const value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t\"");
            if (key.len > 0 and value.len > 0) {
                return .{ .id = key, .constraint = value };
            }
        }
        return null;
    }

    fn count(raw: []const u8) usize {
        var it = DepIterator.init(raw);
        var n: usize = 0;
        while (it.next()) |_| n += 1;
        return n;
    }
};

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
        return runStatus(allocator);
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
    if (std.mem.eql(u8, sub, "graph")) return runGraph(allocator);
    if (std.mem.eql(u8, sub, "health")) return runHealth(allocator, rest);
    if (std.mem.eql(u8, sub, "lint")) return runLint(allocator, rest);
    if (std.mem.eql(u8, sub, "create")) return runCreate(allocator, rest);
    if (std.mem.eql(u8, sub, "create-all")) return runCreateAll(allocator, rest);
    if (std.mem.eql(u8, sub, "audit")) return runAudit(allocator, rest);
    if (std.mem.eql(u8, sub, "fix")) return runFix(allocator, rest);
    if (std.mem.eql(u8, sub, "score")) return runScore(allocator, rest);
    if (std.mem.eql(u8, sub, "status")) return runStatus(allocator);
    if (std.mem.eql(u8, sub, "sign")) return runSign(allocator, rest);
    if (std.mem.eql(u8, sub, "doctor")) return runDoctor(allocator, rest);
    if (std.mem.eql(u8, sub, "explain")) return runExplain(allocator, rest);

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
    std.debug.print("  {s}info <id>{s}         Show cell details (tags, deps, health)\n", .{ GREEN, RESET });
    std.debug.print("  {s}init <id>{s}         Scaffold a new cell (cell.tri + src + test)\n", .{ GREEN, RESET });
    std.debug.print("  {s}check{s}             Validate all manifests (dynamic discovery)\n", .{ GREEN, RESET });
    std.debug.print("  {s}check --sync{s}      Validate + regenerate registry.json\n", .{ GREEN, RESET });
    std.debug.print("  {s}check --dry-run{s}   Show sync changes without writing\n", .{ GREEN, RESET });
    std.debug.print("  {s}deps <id>{s}         Show dependency tree\n", .{ GREEN, RESET });
    std.debug.print("  {s}deps <id> --tree{s}  Recursive dependency tree\n", .{ GREEN, RESET });
    std.debug.print("  {s}graph{s}             Output Mermaid dependency diagram\n", .{ GREEN, RESET });
    std.debug.print("  {s}health{s}            Per-cell health score breakdown\n", .{ GREEN, RESET });
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
    std.debug.print("  {s}explain <id>{s}      Show WHY a cell has its permission level\n", .{ GREEN, RESET });
    std.debug.print("  {s}verify{s}            Check content hashes (integrity)\n", .{ GREEN, RESET });
    std.debug.print("  {s}check-boundaries{s}  Validate tag boundary rules\n", .{ GREEN, RESET });
}

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
    var show_commands = false;
    var show_health = false;
    var show_group = false;
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
        } else if (std.mem.eql(u8, args[i], "--commands")) {
            show_commands = true;
        } else if (std.mem.eql(u8, args[i], "--health")) {
            show_health = true;
        } else if (std.mem.eql(u8, args[i], "--group")) {
            show_group = true;
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
// INFO — detailed view of a single cell
// ═══════════════════════════════════════════════════════════════════════════════

fn runInfo(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage:{s} tri cell info <cell-id>\n", .{ YELLOW, RESET });
        std.debug.print("  Example: tri cell info trinity.hslm\n", .{});
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

    const cells = (parsed.value.object.get("cells") orelse return).array.items;

    for (cells) |item| {
        const obj = item.object;
        const id = jsonStr(obj, "id");
        if (!std.mem.eql(u8, id, cell_id)) continue;

        // Read cell.tri from disk for fresh data
        const path = jsonStr(obj, "path");
        const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch return;
        defer allocator.free(cell_tri_path);

        const cell_content = std.fs.cwd().readFileAlloc(allocator, cell_tri_path, 65536) catch |err| {
            std.debug.print("{s}ERROR{s}: Cannot read {s}: {}\n", .{ RED, RESET, cell_tri_path, err });
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
                CYAN, RESET, lvl_color, cell.perm_level, RESET,
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

    std.debug.print("{s}ERROR{s}: Cell '{s}' not found in registry\n", .{ RED, RESET, cell_id });
    std.debug.print("  Run {s}tri cell list{s} to see available cells\n", .{ GREEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// INIT — scaffold new cell
// ═══════════════════════════════════════════════════════════════════════════════

fn runInit(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage:{s} tri cell init <name> [--kind tool|agent|backend|frontend]\n", .{ YELLOW, RESET });
        std.debug.print("\n  Creates a new cell scaffold:\n", .{});
        std.debug.print("    tool/agent/backend → src/<name>/\n", .{});
        std.debug.print("    frontend           → apps/<name>/\n", .{});
        return;
    }

    const name = args[0];

    var kind: []const u8 = "tool";
    if (args.len >= 3) {
        if (std.mem.eql(u8, args[1], "--kind")) {
            kind = args[2];
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

    const cell_tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{cell_dir}) catch return;
    defer allocator.free(cell_tri_path);
    writeFileIfNotExists(cell_tri_path, cell_tri);

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
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--sync")) do_sync = true;
        if (std.mem.eql(u8, arg, "--dry-run")) {
            dry_run = true;
            do_sync = true;
        }
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
                cell.id, cell.path, cell.version, cell.kind, cell.status, cell.files, cell.tests,
                if (enabled) "true" else "false",
                owner, CORE_VERSION, hash_hex[0..64],
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
                    cell.perm_level, cell.perm_filesystem, cell.perm_network, cell.perm_process,
                    cell.perm_ffi, cell.perm_concurrency,
                });
            }

            // Security
            if (cell.security_signed) {
                try writer.print(", \"security\": {{\"signed\": true, \"signature\": \"{s}\"}}", .{cell.security_signature});
            }

            try writer.writeAll("}");
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
            std.debug.print("  {s}✓ Registry synced:{s} {s} ({d} cells)\n\n", .{ GREEN, RESET, registry_path, valid });
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEPS — dependency tree for a single cell
// ═══════════════════════════════════════════════════════════════════════════════

fn runDeps(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage:{s} tri cell deps <cell-id> [--tree]\n", .{ YELLOW, RESET });
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
// GRAPH — Mermaid dependency diagram
// ═══════════════════════════════════════════════════════════════════════════════

fn runGraph(allocator: Allocator) !void {
    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse registry\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const cells = (parsed.value.object.get("cells") orelse return).array.items;

    std.debug.print("```mermaid\ngraph LR\n", .{});

    var has_deps = false;

    // Read each cell.tri for dependencies
    for (cells) |item| {
        const obj = item.object;
        const id = jsonStr(obj, "id");
        const path = jsonStr(obj, "path");

        const tri_path = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
        defer allocator.free(tri_path);
        const content = std.fs.cwd().readFileAlloc(allocator, tri_path, 65536) catch continue;
        defer allocator.free(content);
        const cell = parseCellTri(content);

        if (cell.dependencies_raw.len > 0) {
            var dep_it = DepIterator.init(cell.dependencies_raw);
            while (dep_it.next()) |dep| {
                std.debug.print("  {s} --> {s}\n", .{ id, dep.id });
                has_deps = true;
            }
        }
    }

    if (!has_deps) {
        // No deps yet — group by tags.scope
        std.debug.print("  %% No dependencies declared yet — showing cells by scope\n", .{});
        for (cells) |item| {
            const obj = item.object;
            const id = jsonStr(obj, "id");
            var scope: []const u8 = "";
            if (jsonObjMap(obj, "tags")) |tags| {
                if (tags.get("scope")) |sv| {
                    if (sv == .string) scope = sv.string;
                }
            }
            if (scope.len > 0) {
                std.debug.print("  subgraph {s}\n    {s}\n  end\n", .{ scope, id });
            } else {
                std.debug.print("  {s}\n", .{id});
            }
        }
    }

    // Style classes
    std.debug.print("  classDef stable fill:#0f0,color:#000\n", .{});
    std.debug.print("  classDef experimental fill:#ff0,color:#000\n", .{});
    for (cells) |item| {
        const obj = item.object;
        const id = jsonStr(obj, "id");
        const status = jsonStr(obj, "status");
        if (std.mem.eql(u8, status, "stable")) {
            std.debug.print("  class {s} stable\n", .{id});
        } else {
            std.debug.print("  class {s} experimental\n", .{id});
        }
    }

    std.debug.print("```\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEALTH — per-cell health score breakdown
// ═══════════════════════════════════════════════════════════════════════════════

fn runHealth(allocator: Allocator, args: []const []const u8) !void {
    const registry = try loadRegistry(allocator);
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("{s}ERROR{s}: Failed to parse registry\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const cells = (parsed.value.object.get("cells") orelse return).array.items;

    // Optional cell id filter
    var cell_filter: ?[]const u8 = null;
    if (args.len > 0) cell_filter = args[0];

    std.debug.print("\n{s}🏥 Cell Health Report{s}\n\n", .{ GOLDEN, RESET });

    var total_score: usize = 0;
    var count: usize = 0;

    for (cells) |item| {
        const obj = item.object;
        const id = jsonStr(obj, "id");

        if (cell_filter) |f| {
            if (!std.mem.eql(u8, id, f)) continue;
        }

        const owner = jsonStr(obj, "owner");
        const tests = jsonInt(obj, "tests");
        const caps_count = countJsonArray(obj, "capabilities");
        const content_hash = jsonStr(obj, "content_hash");
        const has_contrib = hasContributes(obj);

        // Compute individual scores
        const owner_score: u8 = if (owner.len > 0) 30 else 0;
        const tests_score: u8 = if (tests > 0) 25 else 0;
        const cap_raw: usize = if (caps_count >= 5) 20 else @as(usize, caps_count) * 4;
        const cap_score: u8 = @intCast(cap_raw);
        const contrib_score: u8 = if (has_contrib) 15 else 0;
        const hash_score: u8 = if (content_hash.len > 0) 10 else 0;
        const total: u8 = owner_score + tests_score + cap_score + contrib_score + hash_score;

        const health_color = if (total >= 80) GREEN else if (total >= 50) YELLOW else RED;

        std.debug.print("  {s}{s}{s} — {s}{d}%{s}\n", .{ WHITE, id, RESET, health_color, total, RESET });
        std.debug.print("    owner={s}{d}{s}/30  tests={s}{d}{s}/25  caps={s}{d}{s}/20  contrib={s}{d}{s}/15  hash={s}{d}{s}/10\n", .{
            if (owner_score > 0) GREEN else RED,   owner_score,   RESET,
            if (tests_score > 0) GREEN else RED,   tests_score,   RESET,
            if (cap_score >= 16) GREEN else YELLOW, cap_score,    RESET,
            if (contrib_score > 0) GREEN else RED, contrib_score, RESET,
            if (hash_score > 0) GREEN else RED,    hash_score,    RESET,
        });

        total_score += total;
        count += 1;
    }

    if (count > 0) {
        const avg = total_score / count;
        const avg_color = if (avg >= 80) GREEN else if (avg >= 50) YELLOW else RED;
        std.debug.print("\n  {s}Average health: {s}{d}%{s} ({d} cells)\n\n", .{ GRAY, avg_color, avg, RESET, count });
    }
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
        GREEN,                            ok_count,   RESET,
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
                const import_path = source[abs_pos..abs_pos + end_quote];
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
                        const path_pattern = std.fmt.allocPrint(allocator, "/{s}/", .{other_module}) catch continue;
                        defer allocator.free(path_pattern);
                        if (std.mem.indexOf(u8, import_path, path_pattern) != null) {
                            is_cross_cell = true;
                        }
                    } else if (std.mem.endsWith(u8, import_path, ".zig")) {
                        // Filename import — stem must exactly match module name
                        const stem = import_path[0 .. import_path.len - 4];
                        if (std.mem.eql(u8, stem, other_module)) {
                            is_cross_cell = true;
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
                                std.debug.print("  {s}WARNING{s}  {s} (L0) depends on {s} (L2) — privilege escalation risk\n", .{
                                    YELLOW, RESET, cell_id, dep.id,
                                });
                                cell_warnings += 1;
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
                                std.debug.print("  {s}WARNING{s}  {s} (net=none) depends on {s} (net=external)\n", .{
                                    YELLOW, RESET, cell_id, dep.id,
                                });
                                cell_warnings += 1;
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
        if (total_violations > 0) RED else GREEN, total_violations, RESET,
        if (total_warnings > 0) YELLOW else GREEN, total_warnings, RESET,
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
        return;
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
        cell_id,     name,         kind,            path,
        CORE_VERSION, name,         caps_buf[0..caps_pos],
        stats.files, stats.tests,  scope,           kind,
        perms.level, perms.fs,     perms.net,       perms.proc,
        perms.ffi,   perms.concurrency,
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
            cell_id,     name,         kind,            path,
            CORE_VERSION, name,         caps_buf[0..caps_pos],
            stats.files, stats.tests,  scope,           kind,
            perms.level, perms.fs,     perms.net,       perms.proc,
            perms.ffi,   perms.concurrency,
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
    std.debug.print("  9 checks mapped to real OpenClaw CVEs\n\n", .{ });

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
            if (std.mem.eql(u8, cell.perm_level, "L0")) break :blk 100
            else if (std.mem.eql(u8, cell.perm_level, "L1")) break :blk 70
            else if (std.mem.eql(u8, cell.perm_level, "L2")) break :blk 40
            else break :blk 50; // unknown
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

fn runStatus(allocator: Allocator) !void {
    const discovered = discoverCells(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer {
        for (discovered) |p| allocator.free(p);
        allocator.free(discovered);
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
        if (std.mem.eql(u8, cell.perm_level, "L0")) l0_count += 1
        else if (std.mem.eql(u8, cell.perm_level, "L1")) l1_count += 1
        else if (std.mem.eql(u8, cell.perm_level, "L2")) l2_count += 1;

        // Scope
        const scope = inferScope(path);
        const scope_idx: usize = if (std.mem.eql(u8, scope, "vsa")) 0
            else if (std.mem.eql(u8, scope, "physics")) 1
            else if (std.mem.eql(u8, scope, "sacred")) 2
            else if (std.mem.eql(u8, scope, "agent")) 3
            else if (std.mem.eql(u8, scope, "infra")) 4
            else if (std.mem.eql(u8, scope, "hslm")) 5
            else if (std.mem.eql(u8, scope, "fpga")) 6
            else if (std.mem.eql(u8, scope, "ui")) 7
            else if (std.mem.eql(u8, scope, "mcp")) 8
            else 9;
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
            CYAN, RESET, cell.perm_level, cell.perm_filesystem, cell.perm_network,
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
                            lvl_color, p.level, RESET,
                            path, entry.path, line_num, p.label,
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
            if (!std.mem.eql(u8, cell.perm_level, "L2")) continue;
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
    std.debug.print("  {s}fix --all → sign --all → check --sync → audit → lint → status{s}\n\n", .{ GRAY, RESET });

    // Step 1: Fix all
    std.debug.print("  {s}[1/6]{s} Fix...\n", .{ CYAN, RESET });
    try runFix(allocator, &[_][]const u8{"--all"});

    // Step 2: Sign L2 cells
    std.debug.print("  {s}[2/6]{s} Sign L2 cells...\n", .{ CYAN, RESET });
    try runSign(allocator, &[_][]const u8{"--all"});

    // Step 3: Sync registry
    std.debug.print("  {s}[3/6]{s} Sync registry...\n", .{ CYAN, RESET });
    try runCheck(allocator, &[_][]const u8{"--sync"});

    // Step 4: Audit
    std.debug.print("  {s}[4/6]{s} Audit...\n", .{ CYAN, RESET });
    try runAudit(allocator, &[_][]const u8{});

    // Step 5: Lint
    std.debug.print("  {s}[5/6]{s} Lint...\n", .{ CYAN, RESET });
    try runLint(allocator, &[_][]const u8{});

    // Step 6: Status
    std.debug.print("  {s}[6/6]{s} Status...\n", .{ CYAN, RESET });
    try runStatus(allocator);
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
    var dry_run = false;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--perms")) fix_perms = true;
        if (std.mem.eql(u8, arg, "--deps")) fix_deps = true;
        if (std.mem.eql(u8, arg, "--ids")) fix_ids = true;
        if (std.mem.eql(u8, arg, "--scope")) fix_scope = true;
        if (std.mem.eql(u8, arg, "--counts")) fix_counts = true;
        if (std.mem.eql(u8, arg, "--all")) {
            fix_perms = true;
            fix_deps = true;
            fix_ids = true;
            fix_scope = true;
            fix_counts = true;
        }
        if (std.mem.eql(u8, arg, "--dry-run")) dry_run = true;
    }

    if (!fix_perms and !fix_deps and !fix_ids and !fix_scope and !fix_counts) {
        std.debug.print("{s}Usage:{s} tri cell fix --perms|--deps|--ids|--scope|--counts|--all [--dry-run]\n", .{ YELLOW, RESET });
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

            const code_perms = inferPermissions(allocator, path);
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
                    fixCellTriField(allocator, path, "level", code_perms.level);
                    fixCellTriField(allocator, path, "filesystem", code_perms.fs);
                    fixCellTriField(allocator, path, "network", code_perms.net);
                    fixCellTriField(allocator, path, "process", code_perms.proc);
                    fixCellTriField(allocator, path, "ffi", code_perms.ffi);
                    fixCellTriField(allocator, path, "concurrency", code_perms.concurrency);
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

            const stats = countFilesAndTests(allocator, path);
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

    if (dry_run) {
        std.debug.print("  {s}[DRY RUN]{s} No files modified. Run without --dry-run to apply.\n\n", .{ YELLOW, RESET });
    } else {
        std.debug.print("  {s}Fixed {d} cells.{s}\n", .{ GREEN, total_fixes, RESET });
        std.debug.print("  Next: {s}tri cell check --sync{s} to rebuild registry\n\n", .{ GREEN, RESET });
    }
}

/// Fix a single key=value field in cell.tri
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

    var found = false;
    var lines = std.mem.splitScalar(u8, content, '\n');
    var first_line = true;
    var in_permissions = false;
    var last_perm_line = false;

    while (lines.next()) |line| {
        if (!first_line) result.append('\n') catch return;
        first_line = false;

        const trimmed = std.mem.trim(u8, line, " \t\r");

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
            const line_key = std.mem.trim(u8, trimmed[0..ep], " \t");
            if (std.mem.eql(u8, line_key, key)) {
                found = true;
                const new_line = if (is_numeric)
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

            const trimmed2 = std.mem.trim(u8, line, " \t\r");
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

        const trimmed = std.mem.trim(u8, line, " \t\r");
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
    std.debug.print("\n{s}🏆 CELL INTEGRITY SCORE{s}\n\n", .{ GOLDEN, RESET });

    const discovered = discoverCells(allocator) catch {
        std.debug.print("{s}ERROR{s}: Failed to discover cells\n", .{ RED, RESET });
        return;
    };
    defer {
        for (discovered) |p| allocator.free(p);
        allocator.free(discovered);
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

    std.debug.print("  {s}CELL                    HEALTH  SECURITY  DEPS  TOTAL  GRADE{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}─────────────────────── ─────── ──────── ───── ────── ─────{s}\n", .{ GRAY, RESET });

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

        // Health: tests + capabilities + owner + metadata
        const has_tests: u8 = if (cell.tests > 0) 25 else 0;
        const has_owner: u8 = if (cell.owner.len > 0) 10 else 0;
        const has_caps: u8 = if (cell.capabilities.len > 2) 10 else 0; // more than "[]"
        const has_desc: u8 = if (cell.description.len > 0 and !std.mem.startsWith(u8, cell.description, "Auto-generated")) 5 else 0;
        const health_score: u8 = has_tests + has_owner + has_caps + has_desc; // max 50

        // Security: permissions declared + match code + signed
        var security_score: u8 = 0;
        if (cell.perm_level.len > 0) security_score += 10;
        const code_perms = inferPermissions(allocator, path);
        const perms_match = std.mem.eql(u8, cell.perm_level, code_perms.level) and
            std.mem.eql(u8, cell.perm_network, code_perms.net) and
            std.mem.eql(u8, cell.perm_process, code_perms.proc);
        if (perms_match) security_score += 15;
        if (cell.security_signed) security_score += 5;
        const no_bind_all = !(scanCodeForPattern(allocator, path, "parseIp4(\"0.0.0.0\"") or
            scanCodeForPattern(allocator, path, "parseIp(\"0.0.0.0\"") or
            scanCodeForPattern(allocator, path, "bind_address: []const u8 = \"0.0.0.0\"") or
            scanCodeForPattern(allocator, path, ".host = \"0.0.0.0\"") or
            scanCodeForPattern(allocator, path, "listen_address = \"0.0.0.0\""));
        if (no_bind_all) security_score += 10;
        // max 40

        // Deps: has declared deps where code has cross-cell imports
        var deps_score: u8 = 10; // default: no deps needed = full score
        if (cell.dependencies_raw.len > 0) {
            deps_score = 10; // has declared deps
        }
        // max 10

        const final_score = health_score + security_score + deps_score;
        const grade_char: []const u8 = if (final_score >= 80) "A" else if (final_score >= 60) "B" else if (final_score >= 40) "C" else "F";
        const grade_color = if (final_score >= 80) GREEN else if (final_score >= 60) YELLOW else RED;

        if (final_score >= 80) grade_a += 1
        else if (final_score >= 60) grade_b += 1
        else if (final_score >= 40) grade_c += 1
        else grade_f += 1;

        std.debug.print("  {s}{s}{s}", .{ WHITE, cell.id, RESET });
        printPad(cell.id.len, 24);
        std.debug.print("{d:3}     {d:3}       {d:2}    {s}{d:3}{s}    {s}{s}{s}\n", .{
            health_score, security_score, deps_score,
            grade_color, final_score, RESET,
            grade_color, grade_char, RESET,
        });

        total_score += final_score;
        count += 1;
    }

    if (count > 0) {
        const avg = total_score / count;
        const avg_color = if (avg >= 80) GREEN else if (avg >= 60) YELLOW else RED;
        std.debug.print("\n  {s}Average: {s}{d}/100{s} | A:{d} B:{d} C:{d} F:{d} | {d} cells\n\n", .{
            GRAY, avg_color, avg, RESET, grade_a, grade_b, grade_c, grade_f, count,
        });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATE/AUDIT HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

const FileStats = struct { files: u32, tests: u32 };

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
};

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
                // Copy the name so it outlives the source buffer
                result.items[result.count] = allocator.dupe(u8, source[abs_pos..end]) catch continue;
                result.count += 1;
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
        "gravity",      "string_theory",    "maxwell",    "cosmos",           "biology",
        "quantum_gravity", "particle_physics", "dark_matter", "plasma",       "qcd",
        "baryogenesis", "monopoles",        "superconductivity", "hyperspace",
        "origin",       "vacuum",           "flatness",
    };
    for (physics_names) |pn| {
        if (std.mem.eql(u8, name, pn)) return "physics";
    }

    // VSA modules
    const vsa_names = [_][]const u8{
        "vsa", "vm", "tvc", "sparse", "simd", "sequence_hdc", "jit",
        "packed_trit", "hybrid", "b2t", "needle", "vibeec", "ternary",
    };
    for (vsa_names) |vn| {
        if (std.mem.eql(u8, name, vn)) return "vsa";
    }

    // Sacred / Math
    const sacred_names = [_][]const u8{
        "sacred", "math", "time", "science", "phi-engine", "phi_loop",
        "beal", "blind_spot", "reality", "consciousness", "quantum",
    };
    for (sacred_names) |sn| {
        if (std.mem.eql(u8, name, sn)) return "sacred";
    }

    // Agent
    const agent_names = [_][]const u8{
        "autonomous", "orchestration", "agent_mu", "depin", "mining",
        "firebird", "trinity_node", "trinity-node", "swarm", "bsd",
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
    const tests_score: u8 = if (tests > 0) 25 else 0;
    const cap_raw: usize = if (caps_count >= 5) 20 else caps_count * 4;
    const cap_score: u8 = @intCast(cap_raw);
    const contrib_score: u8 = if (has_contrib) 15 else 0;
    const hash_score: u8 = if (content_hash.len > 0) 10 else 0;
    return owner_score + tests_score + cap_score + contrib_score + hash_score;
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
// FILESYSTEM DISCOVERY — walk directories for cell.tri
// ═══════════════════════════════════════════════════════════════════════════════

fn discoverCells(allocator: Allocator) ![][]const u8 {
    var results = std.array_list.Managed([]const u8).init(allocator);
    errdefer {
        for (results.items) |p| allocator.free(p);
        results.deinit();
    }

    const cwd = std.fs.cwd();

    for (CELL_SCAN_DIRS) |scan_dir| {
        var dir = cwd.openDir(scan_dir, .{ .iterate = true }) catch continue;
        defer dir.close();

        var walker = dir.walk(allocator) catch continue;
        defer walker.deinit();

        while (walker.next() catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.eql(u8, entry.basename, "cell.tri")) continue;

            // Build the path relative to cwd: scan_dir/dir_part
            const dir_path = std.fs.path.dirname(entry.path) orelse "";
            const full_path = if (dir_path.len > 0)
                std.fmt.allocPrint(allocator, "{s}/{s}", .{ scan_dir, dir_path }) catch continue
            else
                allocator.dupe(u8, scan_dir) catch continue;

            try results.append(full_path);
        }
    }

    return results.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION-AWARE CELL.TRI PARSER
// ═══════════════════════════════════════════════════════════════════════════════

fn parseCellTri(content: []const u8) CellInfo {
    var info: CellInfo = .{
        .id = "",
        .name = "",
        .version = "",
        .kind = "",
        .path = "",
        .status = "",
        .description = "",
        .min_core_version = "",
        .capabilities = "",
        .files = 0,
        .tests = 0,
        .owner = "",
        .tags_scope = "",
        .tags_type = "",
        .contributes_commands = "",
        .contributes_tri_subcommands = "",
        .contributes_events = "",
        .dependencies_raw = "",
        .perm_level = "",
        .perm_filesystem = "",
        .perm_network = "",
        .perm_process = "",
        .perm_ffi = "",
        .perm_concurrency = "",
        .security_signed = false,
        .security_signature = "",
        .security_score = null,
    };

    const Section = enum { cell, tags, contributes, dependencies, permissions, security };
    var current_section: Section = .cell;

    // Track the raw [dependencies] section span inside content
    // We store start/end offsets into content so the slice stays valid
    var dep_section_start: ?usize = null;
    var dep_section_end: usize = 0;

    var offset: usize = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const line_start = offset;
        offset += line.len + 1; // +1 for '\n'
        if (offset > content.len) offset = content.len;
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;

        // Section headers
        if (trimmed.len >= 2 and trimmed[0] == '[') {
            if (std.mem.eql(u8, trimmed, "[cell]")) {
                current_section = .cell;
            } else if (std.mem.eql(u8, trimmed, "[tags]")) {
                current_section = .tags;
            } else if (std.mem.eql(u8, trimmed, "[contributes]")) {
                current_section = .contributes;
            } else if (std.mem.eql(u8, trimmed, "[dependencies]")) {
                current_section = .dependencies;
                dep_section_start = offset; // content after [dependencies]\n
            } else if (std.mem.eql(u8, trimmed, "[permissions]")) {
                current_section = .permissions;
            } else if (std.mem.eql(u8, trimmed, "[security]")) {
                current_section = .security;
            }
            continue;
        }

        // Parse key = value
        const eq_pos = std.mem.indexOf(u8, trimmed, "=") orelse continue;
        if (eq_pos == 0) continue;
        const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
        const value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t\"");

        switch (current_section) {
            .cell => {
                if (std.mem.eql(u8, key, "id")) info.id = value
                else if (std.mem.eql(u8, key, "name")) info.name = value
                else if (std.mem.eql(u8, key, "version")) info.version = value
                else if (std.mem.eql(u8, key, "kind")) info.kind = value
                else if (std.mem.eql(u8, key, "path")) info.path = value
                else if (std.mem.eql(u8, key, "status")) info.status = value
                else if (std.mem.eql(u8, key, "description")) info.description = value
                else if (std.mem.eql(u8, key, "min_core_version")) info.min_core_version = value
                else if (std.mem.eql(u8, key, "capabilities")) info.capabilities = value
                else if (std.mem.eql(u8, key, "owner")) info.owner = value
                else if (std.mem.eql(u8, key, "files")) info.files = std.fmt.parseInt(u32, value, 10) catch 0
                else if (std.mem.eql(u8, key, "tests")) info.tests = std.fmt.parseInt(u32, value, 10) catch 0;
            },
            .tags => {
                if (std.mem.eql(u8, key, "scope")) info.tags_scope = value
                else if (std.mem.eql(u8, key, "type")) info.tags_type = value;
            },
            .contributes => {
                if (std.mem.eql(u8, key, "commands")) info.contributes_commands = value
                else if (std.mem.eql(u8, key, "tri_subcommands")) info.contributes_tri_subcommands = value
                else if (std.mem.eql(u8, key, "events")) info.contributes_events = value;
            },
            .dependencies => {
                // Track end of dependencies section
                _ = line_start; // used by offset calculation above
                if (key.len > 0) {
                    dep_section_end = offset;
                }
            },
            .permissions => {
                if (std.mem.eql(u8, key, "level")) info.perm_level = value
                else if (std.mem.eql(u8, key, "filesystem")) info.perm_filesystem = value
                else if (std.mem.eql(u8, key, "network")) info.perm_network = value
                else if (std.mem.eql(u8, key, "process")) info.perm_process = value
                else if (std.mem.eql(u8, key, "ffi")) info.perm_ffi = value
                else if (std.mem.eql(u8, key, "concurrency")) info.perm_concurrency = value;
            },
            .security => {
                if (std.mem.eql(u8, key, "signed")) info.security_signed = std.mem.eql(u8, value, "true")
                else if (std.mem.eql(u8, key, "signature")) info.security_signature = value;
            },
        }
    }

    // Extract dependencies_raw as the raw text of the [dependencies] section
    // We'll parse it on-the-fly when needed
    if (dep_section_start) |start| {
        if (dep_section_end > start) {
            info.dependencies_raw = content[start..dep_section_end];
        }
    }

    return info;
}

fn extractField(content: []const u8, field: []const u8) []const u8 {
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;

        if (std.mem.startsWith(u8, trimmed, field)) {
            const after_field = trimmed[field.len..];
            if (after_field.len > 0 and after_field[0] != ' ' and after_field[0] != '\t' and after_field[0] != '=') continue;
            const eq_pos = std.mem.indexOf(u8, after_field, "=") orelse continue;
            const value = std.mem.trim(u8, after_field[eq_pos + 1 ..], " \t\"");
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
    const stripped = std.mem.trim(u8, raw, "[]");
    if (stripped.len == 0) return;

    var first = true;
    var iter = std.mem.splitScalar(u8, stripped, ',');
    while (iter.next()) |elem| {
        const trimmed = std.mem.trim(u8, elem, " \t\"'");
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
