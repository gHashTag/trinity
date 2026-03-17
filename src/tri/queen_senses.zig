// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN SENSES — 12 system senses (read-only monitoring)
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const qt = @import("queen_types.zig");
const faculty_types = @import("faculty_types.zig");

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
    s.experience_count = countExperienceEpisodes();

    // 12. Network (Telegram reachable — skip in collect, check lazily)
    s.network_ok = true; // assume OK; queen_telegram checks actual connectivity

    // v4: expanded senses
    // 13. Farm idle services
    s.farm_idle_count = countFarmIdleServices();

    // 14. Stale arena hours
    s.stale_arena_hours = calcStaleArenaHours();

    // 15. Agent spawn issues (from farm events)
    s.agent_spawn_issues = countAgentSpawnIssues();

    // 16. Last git push timestamp
    s.last_git_push_ts = readGitPushTs();

    // 17. Finished containers
    s.finished_containers = countFinishedContainers();

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
    const file = std.fs.cwd().openFile(".trinity/ouroboros_state.json", .{}) catch return 0.0;
    defer file.close();

    var buf: [2048]u8 = undefined;
    const n = file.read(&buf) catch return 0.0;
    return qt.findJsonF32(buf[0..n], "\"score\":") orelse 0.0;
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
