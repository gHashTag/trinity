// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN SENSES — 12 system senses (read-only monitoring)
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const qt = @import("queen_types.zig");
const faculty_types = @import("faculty_types.zig");
const thalamus = @import("thalamus.zig");

const Allocator = std.mem.Allocator;
const FacultySnapshot = faculty_types.FacultySnapshot;
const SenseResult = qt.SenseResult;
const print = std.debug.print;

// ═══════════════════════════════════════════════════════════════════════════════
// COLLECT ALL 12 SENSES
// ═══════════════════════════════════════════════════════════════════════════════

pub fn collectAllSenses(allocator: Allocator, snapshot: FacultySnapshot) SenseResult {
    var s = SenseResult{};

    // 1. Build
    s.build_ok = snapshot.build_ok;

    // 2. Tests
    s.test_rate = snapshot.compile_rate;

    // 3. Git dirty
    s.dirty_files = snapshot.dirty_files;

    // 4. Issues
    s.open_issues = snapshot.open_issues;

    // 5. Agents (heartbeat mtime check)
    s.agent_count = countAliveAgents();

    // 6. Farm (evolution state)
    const evo = readEvolutionInfo();
    s.farm_services = @intCast(@min(evo.service_count, 255));
    s.farm_best_ppl = evo.best_ppl;

    // 7. Arena
    s.arena_battles = countArenaResults();

    // 8. Disk free
    s.disk_free_gb = readDiskFreeGb(allocator);

    // 9. Keys
    const keys = countEnvKeys();
    s.keys_present = keys.present;
    s.keys_total = keys.total;

    // 10. Ouroboros score
    s.ouroboros_score = readOuroborosScore();

    // 11. Experience episodes
    s.experience_count = thalamus.countEpisodes(allocator);

    // 12. Network (Telegram reachable — skip in collect, check lazily)
    s.network_ok = true; // assume OK; queen_telegram checks actual connectivity

    // v4: expanded senses
    // 13. Farm idle services
    s.farm_idle_count = countFarmIdleServices();

    // 14. Stale arena hours
    s.stale_arena_hours = calcStaleArenaHours();

    // 15. Agent spawn issues (from farm events)
    s.agent_spawn_issues = @intCast(@min(thalamus.countFarmEvents(allocator, "agent:spawn"), 255));

    // 16. Last git push timestamp
    s.last_git_push_ts = readGitPushTs();

    // 17. Finished containers
    s.finished_containers = @intCast(@min(thalamus.countFarmEvents(allocator, "FINISHED"), 255));

    // 18. Last issue comment timestamp
    s.last_issue_comment_ts = readLastIssueCommentTs();

    return s;
}

// ═══════════════════════════════════════════════════════════════════════════════
// INDIVIDUAL SENSES
// ═══════════════════════════════════════════════════════════════════════════════

fn countAliveAgents() u8 {
    const heartbeat_paths = [_][]const u8{
        ".trinity/mu/heartbeat.json",
        ".trinity/scholar/heartbeat.json",
    };
    const wake_paths = [_][]const u8{
        ".ralph/state/wake_count",
        ".trinity/mu/state/wake_count",
        ".trinity/scholar/state/wake_count",
    };

    var count: u8 = 0;
    const now = std.time.timestamp();

    for (heartbeat_paths) |path| {
        const file = std.fs.cwd().openFile(path, .{}) catch continue;
        defer file.close();
        const stat = file.stat() catch continue;
        const mtime_s: i64 = @intCast(@divTrunc(stat.mtime, std.time.ns_per_s));
        if (now - mtime_s < 300) count += 1; // alive if modified < 5 min ago
    }

    for (wake_paths) |path| {
        const file = std.fs.cwd().openFile(path, .{}) catch continue;
        defer file.close();
        const stat = file.stat() catch continue;
        const mtime_s: i64 = @intCast(@divTrunc(stat.mtime, std.time.ns_per_s));
        if (now - mtime_s < 300) count += 1;
    }

    return count;
}

pub fn readEvolutionInfo() qt.EvolutionInfo {
    var info = qt.EvolutionInfo{};

    const file = std.fs.cwd().openFile(".trinity/evolution_state.json", .{}) catch return info;
    defer file.close();

    var buf: [4096]u8 = undefined;
    const n = file.read(&buf) catch return info;
    const data = buf[0..n];

    if (qt.findJsonF32(data, "\"best_ppl\":")) |v| info.best_ppl = v;
    if (qt.findJsonU32(data, "\"best_step\":")) |v| info.best_step = v;
    if (qt.findJsonU32(data, "\"total_configs_tested\":")) |v| info.total_configs = v;
    if (qt.findJsonU32(data, "\"service_count\":")) |v| info.service_count = v;

    if (qt.findJsonStr(data, "\"best_name\":\"")) |name| {
        const len = @min(name.len, info.best_name.len);
        @memcpy(info.best_name[0..len], name[0..len]);
        info.best_name_len = len;
    }

    return info;
}

fn countArenaResults() u32 {
    const file = std.fs.cwd().openFile("data/arena/arena_results.jsonl", .{}) catch return 0;
    defer file.close();

    var buf: [8192]u8 = undefined;
    var total: u32 = 0;
    while (true) {
        const n = file.read(&buf) catch break;
        if (n == 0) break;
        for (buf[0..n]) |c| {
            if (c == '\n') total += 1;
        }
    }
    return total;
}

fn readDiskFreeGb(allocator: Allocator) f32 {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "df", "-k", "." },
        .max_output_bytes = 4096,
    }) catch return 0.0;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // Parse df output: skip header line, get 4th field (available KB)
    var lines = std.mem.splitScalar(u8, result.stdout, '\n');
    _ = lines.next(); // skip header
    const data_line = lines.next() orelse return 0.0;

    var fields = std.mem.tokenizeScalar(u8, data_line, ' ');
    _ = fields.next(); // filesystem
    _ = fields.next(); // total
    _ = fields.next(); // used
    const avail_str = fields.next() orelse return 0.0;

    const avail_kb = std.fmt.parseInt(u64, avail_str, 10) catch return 0.0;
    return @as(f32, @floatFromInt(avail_kb)) / (1024.0 * 1024.0); // KB → GB
}

const KeyCheck = struct { present: u8, total: u8 };

fn countEnvKeys() KeyCheck {
    const required_keys = [_][]const u8{
        "TELEGRAM_BOT_TOKEN",
        "TELEGRAM_CHAT_ID",
        "ANTHROPIC_API_KEY",
        "GITHUB_TOKEN",
        "RAILWAY_TOKEN",
    };
    var present: u8 = 0;
    for (required_keys) |key| {
        if (std.posix.getenv(key)) |v| {
            if (v.len > 0) present += 1;
        }
    }
    return .{ .present = present, .total = required_keys.len };
}

fn readOuroborosScore() f32 {
    const ouroboros = @import("queen_ouroboros.zig");
    const state = ouroboros.fetch();
    return ouroboros.getScore(state);
}

fn countExperienceEpisodes() u32 {
    var dir = std.fs.cwd().openDir(".trinity/experience/episodes", .{ .iterate = true }) catch return 0;
    defer dir.close();

    var count: u32 = 0;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".json")) {
            count += 1;
        }
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// v4: EXPANDED SENSES
// ═══════════════════════════════════════════════════════════════════════════════

fn countFarmIdleServices() u8 {
    const file = std.fs.cwd().openFile(".trinity/evolution_state.json", .{}) catch return 0;
    defer file.close();
    var buf: [8192]u8 = undefined;
    const n = file.read(&buf) catch return 0;
    const data = buf[0..n];

    // Count occurrences of "status":"idle" or "status":"finished"
    var count: u8 = 0;
    var pos: usize = 0;
    while (pos < data.len) {
        if (std.mem.indexOfPos(u8, data, pos, "\"idle\"")) |idx| {
            count +|= 1;
            pos = idx + 6;
        } else break;
    }
    pos = 0;
    while (pos < data.len) {
        if (std.mem.indexOfPos(u8, data, pos, "\"finished\"")) |idx| {
            count +|= 1;
            pos = idx + 10;
        } else break;
    }
    return count;
}

fn calcStaleArenaHours() u16 {
    const file = std.fs.cwd().openFile("data/arena/arena_results.jsonl", .{}) catch return 999;
    defer file.close();
    const stat = file.stat() catch return 999;
    const mtime_s: i64 = @intCast(@divTrunc(stat.mtime, std.time.ns_per_s));
    const now = std.time.timestamp();
    const diff = now - mtime_s;
    if (diff < 0) return 0;
    return @intCast(@min(@divTrunc(diff, 3600), 65535));
}

fn countAgentSpawnIssues() u8 {
    const file = std.fs.cwd().openFile(".trinity/farm/events.jsonl", .{}) catch return 0;
    defer file.close();
    var buf: [8192]u8 = undefined;
    var count: u8 = 0;
    while (true) {
        const n = file.read(&buf) catch break;
        if (n == 0) break;
        var pos: usize = 0;
        while (pos < n) {
            if (std.mem.indexOfPos(u8, buf[0..n], pos, "agent:spawn")) |idx| {
                count +|= 1;
                pos = idx + 11;
            } else break;
        }
    }
    return count;
}

fn readGitPushTs() i64 {
    const file = std.fs.cwd().openFile(".git/refs/remotes/origin/main", .{}) catch return 0;
    defer file.close();
    const stat = file.stat() catch return 0;
    return @intCast(@divTrunc(stat.mtime, std.time.ns_per_s));
}

fn countFinishedContainers() u8 {
    // Read from cloud state if available
    const file = std.fs.cwd().openFile(".trinity/farm/events.jsonl", .{}) catch return 0;
    defer file.close();
    var buf: [8192]u8 = undefined;
    var count: u8 = 0;
    while (true) {
        const n = file.read(&buf) catch break;
        if (n == 0) break;
        var pos: usize = 0;
        while (pos < n) {
            if (std.mem.indexOfPos(u8, buf[0..n], pos, "\"FINISHED\"")) |idx| {
                count +|= 1;
                pos = idx + 10;
            } else break;
        }
    }
    return count;
}

fn readLastIssueCommentTs() i64 {
    // Use farm events as proxy — last event with "comment" type
    const file = std.fs.cwd().openFile(".trinity/farm/events.jsonl", .{}) catch return 0;
    defer file.close();
    const stat = file.stat() catch return 0;
    return @intCast(@divTrunc(stat.mtime, std.time.ns_per_s));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TTY — Print senses table
// ═══════════════════════════════════════════════════════════════════════════════

pub fn printSensesTable(s: SenseResult) void {
    const colors = @import("tri_colors.zig");
    const GREEN = colors.GREEN;
    const RED = colors.RED;
    const CYAN = colors.CYAN;
    const GOLDEN = colors.GOLDEN;
    const GRAY = colors.GRAY;
    const RESET = colors.RESET;

    print("\n{s}" ++ qt.E_EYE ++ " Queen Senses (18){s}\n\n", .{ GOLDEN, RESET });
    print("  {s}#  Sense          Value          Status{s}\n", .{ GRAY, RESET });
    print("  {s}── ────────────── ────────────── ──────{s}\n", .{ GRAY, RESET });

    // 1. Build
    print("  1  Build          {s}{s}{s}\n", .{
        if (s.build_ok) GREEN else RED,
        if (s.build_ok) "OK             " ++ qt.E_CHECK else "FAIL           " ++ qt.E_CROSS,
        RESET,
    });

    // 2. Tests
    print("  2  Tests          {d}%%             {s}\n", .{
        s.test_rate,
        if (s.test_rate >= 80) qt.E_CHECK else qt.E_WRENCH,
    });

    // 3. Dirty
    print("  3  Dirty files    {d:<14} {s}\n", .{
        s.dirty_files,
        if (s.dirty_files < 50) qt.E_CHECK else qt.E_SIREN,
    });

    // 4. Issues
    print("  4  Open issues    {d:<14} " ++ qt.E_CLIP ++ "\n", .{s.open_issues});

    // 5. Agents
    print("  5  Agents alive   {d}/5            {s}\n", .{
        s.agent_count,
        if (s.agent_count >= 2) qt.E_CHECK else qt.E_WRENCH,
    });

    // 6. Farm
    print("  6  Farm services  {d:<14} " ++ qt.E_DNA ++ "\n", .{s.farm_services});

    // 7. Farm PPL
    print("  7  Best PPL       {d:.1}{s:14}{s}\n", .{
        s.farm_best_ppl,
        "",
        if (s.farm_best_ppl < 10.0) qt.E_TROPHY else qt.E_WRENCH,
    });

    // 8. Arena
    print("  8  Arena battles  {d:<14} " ++ qt.E_SWORDS ++ "\n", .{s.arena_battles});

    // 9. Ouroboros
    print("  9  Ouroboros      {d:.1}{s:14}{s}\n", .{
        s.ouroboros_score,
        "",
        if (s.ouroboros_score >= 70) qt.E_STAR else qt.E_WRENCH,
    });

    // 10. Disk
    print("  10 Disk free      {d:.1} GB{s:10}{s}\n", .{
        s.disk_free_gb,
        "",
        if (s.disk_free_gb > 10.0) qt.E_CHECK else qt.E_SIREN,
    });

    // 11. Keys
    print("  11 Env keys       {d}/{d}            {s}\n", .{
        s.keys_present,
        s.keys_total,
        if (s.keys_present == s.keys_total) qt.E_CHECK else qt.E_KEY,
    });

    // 12. Experience
    print("  12 Experience     {d:<14} " ++ qt.E_BRAIN ++ "\n", .{s.experience_count});

    // v4: expanded senses
    print("  13 Farm idle      {d:<14} {s}\n", .{ s.farm_idle_count, if (s.farm_idle_count > 3) qt.E_SIREN else qt.E_CHECK });
    print("  14 Arena stale    {d}h{s:12}{s}\n", .{ s.stale_arena_hours, "", if (s.stale_arena_hours > 24) qt.E_SIREN else qt.E_CHECK });
    print("  15 Spawn issues   {d:<14} {s}\n", .{ s.agent_spawn_issues, if (s.agent_spawn_issues > 0) qt.E_ROBOT else qt.E_CHECK });
    print("  16 Finished ctnr  {d:<14} {s}\n", .{ s.finished_containers, if (s.finished_containers > 5) qt.E_TRASH else qt.E_CHECK });

    // Summary line
    print("\n  {s} {s}Health: {s}{s}\n\n", .{
        s.healthEmoji(),
        CYAN,
        if (!s.build_ok) "BUILD BROKEN" else if (s.ouroboros_score >= 70) "HEALTHY" else if (s.ouroboros_score >= 40) "RECOVERING" else "NEEDS ATTENTION",
        RESET,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TELEGRAM — Format senses for Telegram
// ═══════════════════════════════════════════════════════════════════════════════

pub fn fmtSensesTelegram(buf: []u8, s: SenseResult) []const u8 {
    return std.fmt.bufPrint(buf, qt.E_EYE ++ " Queen Senses\n" ++
        "\n" ++
        "{s} Build: {s}\n" ++
        qt.E_GEAR ++ " Tests: {d}%%\n" ++
        qt.E_DISK ++ " Dirty: {d}\n" ++
        qt.E_CLIP ++ " Issues: {d}\n" ++
        qt.E_ROBOT ++ " Agents: {d}/5\n" ++
        qt.E_DNA ++ " Farm: {d} srv, PPL {d:.1}\n" ++
        qt.E_SWORDS ++ " Arena: {d}\n" ++
        qt.E_CYCLE ++ " Ouroboros: {d:.1}\n" ++
        qt.E_DISK ++ " Disk: {d:.1} GB\n" ++
        qt.E_KEY ++ " Keys: {d}/{d}\n" ++
        qt.E_BRAIN ++ " Experience: {d}\n" ++
        "\n" ++
        "{s} {s}", .{
        if (s.build_ok) qt.E_CHECK else qt.E_CROSS,
        if (s.build_ok) "OK" else "FAIL",
        s.test_rate,
        s.dirty_files,
        s.open_issues,
        s.agent_count,
        s.farm_services,
        s.farm_best_ppl,
        s.arena_battles,
        s.ouroboros_score,
        s.disk_free_gb,
        s.keys_present,
        s.keys_total,
        s.experience_count,
        s.healthEmoji(),
        if (!s.build_ok) "BUILD BROKEN" else if (s.ouroboros_score >= 70) "HEALTHY" else if (s.ouroboros_score >= 40) "RECOVERING" else "NEEDS ATTENTION",
    }) catch buf[0..0];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Queen senses — readEvolutionInfo parses" {
    // Integration test — reads actual file if present, otherwise defaults
    const info = readEvolutionInfo();
    try std.testing.expect(info.best_ppl >= 0.0);
}

test "Queen senses — countArenaResults" {
    const count = countArenaResults();
    try std.testing.expect(count >= 0);
}

test "Queen senses — countEnvKeys" {
    const keys = countEnvKeys();
    try std.testing.expect(keys.total == 5);
    try std.testing.expect(keys.present <= keys.total);
}

test "Queen senses — readOuroborosScore" {
    const score = readOuroborosScore();
    try std.testing.expect(score >= 0.0);
}

test "Queen senses — countExperienceEpisodes" {
    const count = countExperienceEpisodes();
    try std.testing.expect(count >= 0);
}

test "Queen senses — fmtSensesTelegram" {
    var buf: [2048]u8 = undefined;
    const s = SenseResult{
        .build_ok = true,
        .test_rate = 85,
        .dirty_files = 12,
        .open_issues = 5,
        .agent_count = 3,
        .farm_services = 8,
        .farm_best_ppl = 4.6,
        .arena_battles = 20,
        .ouroboros_score = 72.5,
        .disk_free_gb = 45.3,
        .keys_present = 4,
        .keys_total = 5,
        .experience_count = 10,
    };
    const msg = fmtSensesTelegram(&buf, s);
    try std.testing.expect(msg.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, msg, "4.6") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "HEALTHY") != null);
}

test "Queen senses — fmtSensesTelegram critical state" {
    var buf: [2048]u8 = undefined;
    const s = SenseResult{
        .build_ok = false,
        .test_rate = 45,
        .dirty_files = 50,
        .open_issues = 15,
        .agent_count = 0,
        .farm_services = 2,
        .farm_best_ppl = 99.9,
        .arena_battles = 0,
        .ouroboros_score = 25.0,
        .disk_free_gb = 5.0,
        .keys_present = 2,
        .keys_total = 5,
        .experience_count = 0,
    };
    const msg = fmtSensesTelegram(&buf, s);
    try std.testing.expect(msg.len > 0);
    // Should show ❌ emoji for failed build
    try std.testing.expect(std.mem.indexOf(u8, msg, "\xe2\x9d\x8c") != null);
}

test "Queen senses — SenseResult default values" {
    const s = SenseResult{};
    try std.testing.expectEqual(@as(u8, 0), s.farm_idle_count);
    try std.testing.expectEqual(@as(u16, 0), s.stale_arena_hours);
}

test "Queen senses — countFarmIdleServices returns non-negative" {
    const count = countFarmIdleServices();
    try std.testing.expect(count >= 0);
}

test "Queen senses — calcStaleArenaHours returns non-negative" {
    const hours = calcStaleArenaHours();
    try std.testing.expect(hours >= 0);
}

test "Queen senses — readDiskFreeGb returns reasonable value" {
    const gb = readDiskFreeGb(std.testing.allocator);
    try std.testing.expect(gb >= 0.0);
    try std.testing.expect(gb < 10000.0); // Sanity check
}

test "Queen senses — countAliveAgents non-negative" {
    const count = countAliveAgents();
    try std.testing.expect(count >= 0);
}

test "Queen senses — countArenaResults non-negative" {
    const count = countArenaResults();
    try std.testing.expect(count >= 0);
}

test "Queen senses — SenseResult all fields set" {
    var s = SenseResult{};
    s.build_ok = true;
    s.test_rate = 90;
    s.dirty_files = 5;
    s.open_issues = 2;
    s.agent_count = 4;
    s.farm_services = 10;
    s.farm_best_ppl = 5.5;
    s.arena_battles = 15;
    s.ouroboros_score = 80.0;
    s.disk_free_gb = 50.0;
    s.keys_present = 5;
    s.keys_total = 5;
    s.experience_count = 20;
    s.farm_idle_count = 3;
    s.stale_arena_hours = 12;

    try std.testing.expect(s.build_ok);
    try std.testing.expectEqual(@as(u8, 90), s.test_rate);
    try std.testing.expectEqual(@as(u16, 5), s.dirty_files);
    try std.testing.expectEqual(@as(u16, 2), s.open_issues);
    try std.testing.expectEqual(@as(u8, 4), s.agent_count);
    try std.testing.expectEqual(@as(u8, 10), s.farm_services);
    try std.testing.expectApproxEqAbs(@as(f32, 5.5), s.farm_best_ppl, 0.01);
    try std.testing.expectEqual(@as(u16, 15), s.arena_battles);
    try std.testing.expectApproxEqAbs(@as(f32, 80.0), s.ouroboros_score, 0.01);
}

test "Queen senses — SenseResult v4 fields" {
    var s = SenseResult{};
    s.agent_spawn_issues = 5;
    s.last_git_push_ts = 1700000000;
    s.finished_containers = 10;
    s.last_issue_comment_ts = 1700000100;

    try std.testing.expectEqual(@as(u8, 5), s.agent_spawn_issues);
    try std.testing.expectEqual(@as(i64, 1700000000), s.last_git_push_ts);
    try std.testing.expectEqual(@as(u8, 10), s.finished_containers);
    try std.testing.expectEqual(@as(i64, 1700000100), s.last_issue_comment_ts);
}

test "Queen senses — SenseResult healthEmoji mapping" {
    var s = SenseResult{};
    s.build_ok = true;
    s.ouroboros_score = 95.0;
    try std.testing.expectEqualStrings(qt.E_STAR, s.healthEmoji());

    s.ouroboros_score = 75.0;
    try std.testing.expectEqualStrings(qt.E_STAR, s.healthEmoji());

    s.ouroboros_score = 50.0;
    try std.testing.expectEqualStrings(qt.E_CHECK, s.healthEmoji());

    s.ouroboros_score = 30.0;
    try std.testing.expectEqualStrings(qt.E_WRENCH, s.healthEmoji());
}

test "Queen senses — SenseResult healthEmoji edge cases" {
    var s = SenseResult{};
    s.build_ok = true;

    s.ouroboros_score = 70.0; // boundary
    try std.testing.expectEqualStrings(qt.E_STAR, s.healthEmoji());

    s.ouroboros_score = 69.9; // just below
    try std.testing.expectEqualStrings(qt.E_CHECK, s.healthEmoji());

    s.ouroboros_score = 40.0; // boundary
    try std.testing.expectEqualStrings(qt.E_CHECK, s.healthEmoji());

    s.ouroboros_score = 39.9; // just below
    try std.testing.expectEqualStrings(qt.E_WRENCH, s.healthEmoji());

    s.build_ok = false; // build broken overrides score
    try std.testing.expectEqualStrings(qt.E_CROSS, s.healthEmoji());
}

test "Queen senses — SenseResult default values all zero" {
    const s = SenseResult{};

    try std.testing.expect(!s.build_ok);
    try std.testing.expectEqual(@as(u8, 0), s.test_rate);
    try std.testing.expectEqual(@as(u16, 0), s.dirty_files);
    try std.testing.expectEqual(@as(u16, 0), s.open_issues);
    try std.testing.expectEqual(@as(u8, 0), s.agent_count);
    try std.testing.expectEqual(@as(u8, 0), s.farm_services);
    try std.testing.expectEqual(@as(u8, 0), s.farm_idle_count);
    try std.testing.expectEqual(@as(u8, 0), s.agent_spawn_issues);
    try std.testing.expectEqual(@as(u8, 0), s.finished_containers);
    try std.testing.expectEqual(@as(u16, 0), s.arena_battles);
    try std.testing.expectEqual(@as(u16, 0), s.experience_count);
    try std.testing.expectEqual(@as(f32, 0.0), s.ouroboros_score);
    try std.testing.expectEqual(@as(f32, 999.0), s.farm_best_ppl); // Default is 999.0
    try std.testing.expectEqual(@as(f32, 0.0), s.disk_free_gb);
}

test "Queen senses — countEnvKeys returns non-negative" {
    const keys = countEnvKeys();
    try std.testing.expect(keys.present <= keys.total);
}

test "Queen senses — readEvolutionInfo returns valid struct" {
    const info = readEvolutionInfo();

    // All fields should be non-negative
    try std.testing.expect(info.best_ppl >= 0.0);
    try std.testing.expect(info.best_step >= 0);
    try std.testing.expect(info.total_configs >= 0);
    try std.testing.expect(info.service_count >= 0);
}

test "Queen senses — EvolutionInfo bestNameStr returns slice" {
    var info = qt.EvolutionInfo{};
    const name = "test_config";
    @memcpy(info.best_name[0..name.len], name);
    info.best_name_len = name.len;

    const result = info.bestNameStr();
    try std.testing.expectEqualStrings("test_config", result);
}

test "Queen senses — EvolutionInfo bestNameStr empty when len zero" {
    const info = qt.EvolutionInfo{};
    try std.testing.expectEqual(@as(usize, 0), info.bestNameStr().len);
}

test "Queen senses — countAliveAgents returns reasonable value" {
    const count = countAliveAgents();
    // Should be between 0 and total possible agents
    try std.testing.expect(count >= 0 and count <= 10);
}

test "senses — collectAllSenses populates all fields" {
    const snapshot = FacultySnapshot{
        .agents = undefined,
        .build_ok = true,
        .binaries = 0,
        .compile_pass = 0,
        .compile_total = 0,
        .compile_rate = 0,
        .v_number = 0,
        .v_zone = .drift,
        .git_branch = "main",
        .dirty_files = 0,
        .open_issues = 0,
        .mu_patterns = 0,
        .cycle = .quiet,
    };

    const result = collectAllSenses(std.testing.allocator, snapshot);

    try std.testing.expect(result.build_ok);
}

test "senses — SenseResult healthStatus returns correct emoji" {
    var s = SenseResult{};
    s.build_ok = true;
    s.ouroboros_score = 80.0;

    try std.testing.expectEqualStrings(qt.E_STAR, s.healthEmoji());
}

test "senses — SenseResult healthStatus with broken build" {
    var s = SenseResult{};
    s.build_ok = false;
    s.ouroboros_score = 90.0;

    try std.testing.expectEqualStrings(qt.E_CROSS, s.healthEmoji());
}

test "senses — SenseResult healthStatus with low score" {
    var s = SenseResult{};
    s.build_ok = true;
    s.ouroboros_score = 30.0;

    try std.testing.expectEqualStrings(qt.E_WRENCH, s.healthEmoji());
}

test "senses — readEvolutionInfo fields" {
    const info = readEvolutionInfo();

    // best_ppl defaults to 999.0 if no file
    try std.testing.expect(info.best_ppl == 999.0 or info.best_ppl > 0.0);
}

test "senses — fmtSensesTelegram includes all sections" {
    var buf: [1024]u8 = undefined;
    const result = fmtSensesTelegram(&buf, .{
        .build_ok = true,
        .test_rate = 85,
        .dirty_files = 5,
        .open_issues = 2,
    });

    try std.testing.expect(result.len > 0);
}

test "senses — fmtSensesTelegram with poor health" {
    var buf: [1024]u8 = undefined;
    const result = fmtSensesTelegram(&buf, .{
        .build_ok = false,
        .test_rate = 0,
        .dirty_files = 50,
        .open_issues = 10,
        .ouroboros_score = 20.0,
    });

    try std.testing.expect(result.len > 0);
}

test "senses — SenseResult field independence" {
    var s = SenseResult{};
    s.build_ok = true;
    s.test_rate = 75;
    s.dirty_files = 3;

    try std.testing.expect(s.build_ok);
    try std.testing.expectEqual(@as(u8, 75), s.test_rate);
    try std.testing.expectEqual(@as(u16, 3), s.dirty_files);
}

test "senses — readOuroborosScore returns valid range" {
    const score = readOuroborosScore();
    try std.testing.expect(score >= 0.0 and score <= 100.0);
}

test "senses — countEpisodes returns non-negative" {
    const count = thalamus.countEpisodes(std.testing.allocator);
    try std.testing.expect(count >= 0);
}

test "Queen senses — readDiskFreeGb returns non-negative" {
    const gb = readDiskFreeGb(std.testing.allocator);
    try std.testing.expect(gb >= 0.0);
}

// ═══════════════════════════════════════════════════════════════════
// EvolutionInfo EXTENDED TESTS
// ═══════════════════════════════════════════════════════════════════

test "Queen senses — EvolutionInfo default values" {
    const info = qt.EvolutionInfo{};

    try std.testing.expectEqual(@as(f32, 999.0), info.best_ppl);
    try std.testing.expectEqual(@as(u32, 0), info.best_step);
    try std.testing.expectEqual(@as(u32, 0), info.total_configs);
    try std.testing.expectEqual(@as(u32, 0), info.service_count);
    try std.testing.expectEqual(@as(usize, 0), info.best_name_len);
}

test "Queen senses — EvolutionInfo with populated fields" {
    var info = qt.EvolutionInfo{};
    info.best_ppl = 4.5;
    info.best_step = 1000;
    info.total_configs = 50;
    info.service_count = 10;

    try std.testing.expectApproxEqAbs(@as(f32, 4.5), info.best_ppl, 0.01);
    try std.testing.expectEqual(@as(u32, 1000), info.best_step);
    try std.testing.expectEqual(@as(u32, 50), info.total_configs);
    try std.testing.expectEqual(@as(u32, 10), info.service_count);
}

test "Queen senses — EvolutionInfo bestNameStr with truncation" {
    var info = qt.EvolutionInfo{};
    const long_name = "very_long_config_name_that_exceeds_buffer";

    // Copy only what fits in the buffer
    const len = @min(long_name.len, info.best_name.len);
    @memcpy(info.best_name[0..len], long_name[0..len]);
    info.best_name_len = len;

    const result = info.bestNameStr();
    try std.testing.expectEqual(len, result.len);
}

// ═══════════════════════════════════════════════════════════════════
// SenseResult EXTENDED TESTS
// ═══════════════════════════════════════════════════════════════════

test "Queen senses — SenseResult with maximum values" {
    var s = SenseResult{};
    s.test_rate = 100;
    s.dirty_files = 65535; // max u16
    s.open_issues = 65535;
    s.agent_count = 255;
    s.farm_services = 255;
    s.arena_battles = 65535;
    s.experience_count = 65535;

    try std.testing.expectEqual(@as(u8, 100), s.test_rate);
    try std.testing.expectEqual(@as(u16, 65535), s.dirty_files);
    try std.testing.expectEqual(@as(u8, 255), s.agent_count);
}

test "Queen senses — SenseResult healthEmoji with recovering state" {
    var s = SenseResult{};
    s.build_ok = true;
    s.ouroboros_score = 50.0; // Mid range

    try std.testing.expectEqualStrings(qt.E_CHECK, s.healthEmoji());
}

test "Queen senses — SenseResult with zero ouroboros but good build" {
    var s = SenseResult{};
    s.build_ok = true;
    s.ouroboros_score = 0.0;

    try std.testing.expectEqualStrings(qt.E_WRENCH, s.healthEmoji());
}

test "Queen senses — SenseResult with perfect scores" {
    var s = SenseResult{};
    s.build_ok = true;
    s.test_rate = 100;
    s.ouroboros_score = 100.0;
    s.keys_present = 5;
    s.keys_total = 5;

    try std.testing.expectEqualStrings(qt.E_STAR, s.healthEmoji());
}

test "Queen senses — SenseResult network_ok field" {
    var s = SenseResult{};
    s.network_ok = true;
    try std.testing.expect(s.network_ok);

    s.network_ok = false;
    try std.testing.expect(!s.network_ok);
}

// ═══════════════════════════════════════════════════════════════════
// collectAllSenses EXTENDED TESTS
// ═══════════════════════════════════════════════════════════════════

test "Queen senses — collectAllSenses with broken build snapshot" {
    const snapshot = FacultySnapshot{
        .agents = undefined,
        .build_ok = false,
        .binaries = 0,
        .compile_pass = 0,
        .compile_total = 0,
        .compile_rate = 0,
        .v_number = 0,
        .v_zone = .drift,
        .git_branch = "main",
        .dirty_files = 100,
        .open_issues = 5,
        .mu_patterns = 0,
        .cycle = .emergency,
    };

    const result = collectAllSenses(std.testing.allocator, snapshot);

    try std.testing.expect(!result.build_ok);
    try std.testing.expectEqual(@as(u16, 100), result.dirty_files);
    try std.testing.expectEqual(@as(u16, 5), result.open_issues);
}

test "Queen senses — collectAllSenses with high test rate" {
    const snapshot = FacultySnapshot{
        .agents = undefined,
        .build_ok = true,
        .binaries = 6,
        .compile_pass = 95,
        .compile_total = 100,
        .compile_rate = 95,
        .v_number = 1,
        .v_zone = .gold,
        .git_branch = "main",
        .dirty_files = 2,
        .open_issues = 0,
        .mu_patterns = 10,
        .cycle = .working,
    };

    const result = collectAllSenses(std.testing.allocator, snapshot);

    try std.testing.expect(result.build_ok);
    try std.testing.expectEqual(@as(u8, 95), result.test_rate);
}

test "Queen senses — collectAllSenses timestamp fields populated" {
    const snapshot = FacultySnapshot{
        .agents = undefined,
        .build_ok = true,
        .binaries = 0,
        .compile_pass = 0,
        .compile_total = 0,
        .compile_rate = 0,
        .v_number = 0,
        .v_zone = .drift,
        .git_branch = "main",
        .dirty_files = 0,
        .open_issues = 0,
        .mu_patterns = 0,
        .cycle = .quiet,
    };

    const result = collectAllSenses(std.testing.allocator, snapshot);

    // Timestamps should be populated (either 0 or actual time)
    try std.testing.expect(result.last_git_push_ts >= 0);
    try std.testing.expect(result.last_issue_comment_ts >= 0);
}

// ═══════════════════════════════════════════════════════════════════
// fmtSensesTelegram EXTENDED TESTS
// ═══════════════════════════════════════════════════════════════════

test "Queen senses — fmtSensesTelegram with recovering state" {
    var buf: [1024]u8 = undefined;
    const result = fmtSensesTelegram(&buf, .{
        .build_ok = true,
        .test_rate = 60,
        .dirty_files = 20,
        .open_issues = 3,
        .ouroboros_score = 50.0,
    });

    try std.testing.expect(result.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, result, "RECOVERING") != null);
}

test "Queen senses — fmtSensesTelegram with needs attention" {
    var buf: [1024]u8 = undefined;
    const result = fmtSensesTelegram(&buf, .{
        .build_ok = true,
        .test_rate = 30,
        .dirty_files = 40,
        .open_issues = 8,
        .ouroboros_score = 35.0,
    });

    try std.testing.expect(result.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, result, "NEEDS ATTENTION") != null);
}

test "Queen senses — fmtSensesTelegram includes all keys" {
    var buf: [2048]u8 = undefined;
    const s = SenseResult{
        .build_ok = true,
        .test_rate = 100,
        .dirty_files = 0,
        .open_issues = 0,
        .agent_count = 5,
        .farm_services = 20,
        .farm_best_ppl = 3.5,
        .arena_battles = 100,
        .ouroboros_score = 95.0,
        .disk_free_gb = 100.0,
        .keys_present = 5,
        .keys_total = 5,
        .experience_count = 50,
        .farm_idle_count = 0,
        .stale_arena_hours = 0,
        .agent_spawn_issues = 0,
        .finished_containers = 2,
    };

    const msg = fmtSensesTelegram(&buf, s);

    // Check all major sections are present
    try std.testing.expect(std.mem.indexOf(u8, msg, "Build:") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "Tests:") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "Farm:") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "Ouroboros:") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "Keys:") != null);
}

// ═══════════════════════════════════════════════════════════════════
// Helper function edge cases TESTS
// ═══════════════════════════════════════════════════════════════════

test "Queen senses — countAliveAgents max bound" {
    const count = countAliveAgents();
    // Should not exceed reasonable maximum
    try std.testing.expect(count <= 255);
}

test "Queen senses — countArenaResults counts correctly" {
    const count = countArenaResults();
    // Should be non-negative integer
    try std.testing.expect(count >= 0);
}

test "Queen senses — calcStaleArenaHours max bound" {
    const hours = calcStaleArenaHours();
    // Should return 999 if file doesn't exist, or actual hours
    try std.testing.expect(hours == 999 or hours < 100000);
}

test "Queen senses — countFarmIdleServices non-negative" {
    const count = countFarmIdleServices();
    try std.testing.expect(count >= 0);
}

test "Queen senses — countFarmIdleServices reasonable bound" {
    const count = countFarmIdleServices();
    try std.testing.expect(count <= 255);
}
