// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN TYPES — Shared types, emoji consts, JSON helpers
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// EMOJI CONSTANTS (regular strings — escapes work here, not in multiline \\)
// ═══════════════════════════════════════════════════════════════════════════════

pub const E_CROWN = "\xf0\x9f\x91\x91"; // 👑
pub const E_BRAIN = "\xf0\x9f\xa7\xa0"; // 🧠
pub const E_SWORDS = "\xe2\x9a\x94\xef\xb8\x8f"; // ⚔️
pub const E_CLIP = "\xf0\x9f\x93\x8b"; // 📋
pub const E_WRENCH = "\xf0\x9f\x94\xa7"; // 🔧
pub const E_DNA = "\xf0\x9f\xa7\xac"; // 🧬
pub const E_CYCLE = "\xf0\x9f\x94\x84"; // 🔄
pub const E_TIMER = "\xe2\x8f\xb1"; // ⏱
pub const E_CHECK = "\xe2\x9c\x85"; // ✅
pub const E_CROSS = "\xe2\x9d\x8c"; // ❌
pub const E_TROPHY = "\xf0\x9f\x8f\x86"; // 🏆
pub const E_SIREN = "\xf0\x9f\x9a\xa8"; // 🚨
pub const E_STOP = "\xf0\x9f\x9b\x91"; // 🛑
pub const E_TRASH = "\xf0\x9f\x97\x91"; // 🗑
pub const E_KEY = "\xf0\x9f\x94\x91"; // 🔑
pub const E_COFFIN = "\xe2\x9a\xb0\xef\xb8\x8f"; // ⚰️
pub const E_ROBOT = "\xf0\x9f\xa4\x96"; // 🤖
pub const E_FIRE = "\xf0\x9f\x94\xa5"; // 🔥
pub const E_STAR = "\xe2\xad\x90"; // ⭐
pub const E_EYE = "\xf0\x9f\x91\x81"; // 👁
pub const E_BOLT = "\xe2\x9a\xa1"; // ⚡
pub const E_DISK = "\xf0\x9f\x92\xbe"; // 💾
pub const E_NET = "\xf0\x9f\x8c\x90"; // 🌐
pub const E_GEAR = "\xe2\x9a\x99\xef\xb8\x8f"; // ⚙️
pub const E_HAND = "\xe2\x9c\x8b"; // ✋
pub const E_CHART = "\xf0\x9f\x93\x88"; // 📈

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const STATE_PATH = ".trinity/queen_state.json";

pub const QueenConfig = struct {
    interval_sec: u64 = 600, // 10 min
    daemon: bool = false,
    dry_run: bool = false,
    allow_auto_actions: bool = false,
    // v3: safety policy
    max_auto_level: u8 = 1, // 0=read-only, 1=soft-write, 2=dangerous
    require_human_approval: bool = true, // Level 2 needs /queen approve

    /// v4: --god-mode = --allow-auto-actions --max-level 2 --no-approval
    pub fn applyGodMode(self: *QueenConfig) void {
        self.allow_auto_actions = true;
        self.max_auto_level = 2;
        self.require_human_approval = false;
    }
};

pub const TgConfig = struct {
    bot_token: []const u8,
    chat_id: []const u8,
    enabled: bool,
};

pub const AlertKind = enum {
    build_broken,
    new_ppl_record,
    senior_killed,
    arena_upset,
    blocked_issue,
    dirty_overload,
    key_expired,

    pub fn emoji(self: AlertKind) []const u8 {
        return switch (self) {
            .build_broken => E_SIREN,
            .new_ppl_record => E_TROPHY,
            .senior_killed => E_COFFIN,
            .arena_upset => E_CYCLE,
            .blocked_issue => E_STOP,
            .dirty_overload => E_TRASH,
            .key_expired => E_KEY,
        };
    }

    pub fn labelRu(self: AlertKind) []const u8 {
        return switch (self) {
            .build_broken => "\xd0\x91\xd0\x98\xd0\x9b\xd0\x94 \xd0\xa1\xd0\x9b\xd0\x9e\xd0\x9c\xd0\x90\xd0\x9d", // БИЛД СЛОМАН
            .new_ppl_record => "\xd0\x9d\xd0\x9e\xd0\x92\xd0\xab\xd0\x99 \xd0\xa0\xd0\x95\xd0\x9a\xd0\x9e\xd0\xa0\xd0\x94 PPL", // НОВЫЙ РЕКОРД PPL
            .senior_killed => "ASHA KILL",
            .arena_upset => "ARENA UPSET",
            .blocked_issue => "ISSUE BLOCKED",
            .dirty_overload => "DIRTY OVERLOAD",
            .key_expired => "KEY EXPIRED",
        };
    }
};

pub const Alert = struct {
    kind: AlertKind,
    detail: [256]u8 = undefined,
    detail_len: usize = 0,

    pub fn detailStr(self: *const Alert) []const u8 {
        return self.detail[0..self.detail_len];
    }
};

pub const EvolutionInfo = struct {
    best_ppl: f32 = 999.0,
    best_name: [64]u8 = undefined,
    best_name_len: usize = 0,
    best_step: u32 = 0,
    total_configs: u32 = 0,
    service_count: u32 = 0,

    pub fn bestNameStr(self: *const EvolutionInfo) []const u8 {
        return self.best_name[0..self.best_name_len];
    }
};

pub const ArenaInfo = struct {
    total_battles: u32 = 0,
    today_battles: u32 = 0,
};

pub const QueenState = struct {
    cycle: u32 = 0,
    last_heartbeat: i64 = 0,
    last_daily: i64 = 0,
    prev_build_ok: bool = true,
    prev_best_ppl: f32 = 999.0,
    prev_dirty: u16 = 0,
    started_at: i64 = 0,
    pinned_msg_id: ?i64 = null,
    // v2: auto-actions
    auto_actions_this_hour: u8 = 0,
    last_auto_action_ts: i64 = 0,
    last_build_heal_cycle: u32 = 0,
    tg_last_update_id: i64 = 0,
    // v3: event stream seq counter
    event_seq: u32 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SENSES
// ═══════════════════════════════════════════════════════════════════════════════

pub const SenseResult = struct {
    build_ok: bool = false,
    test_rate: u8 = 0, // 0-100
    dirty_files: u16 = 0,
    open_issues: u16 = 0,
    agent_count: u8 = 0, // alive agents (heartbeat mtime < 300s)
    farm_services: u8 = 0,
    farm_best_ppl: f32 = 999.0,
    arena_battles: u32 = 0,
    ouroboros_score: f32 = 0.0,
    disk_free_gb: f32 = 0.0,
    keys_present: u8 = 0,
    keys_total: u8 = 5,
    network_ok: bool = false,
    experience_count: u32 = 0,
    // v4: expanded senses
    farm_idle_count: u8 = 0, // services with status=idle/finished
    stale_arena_hours: u16 = 0, // hours since last arena battle
    agent_spawn_issues: u8 = 0, // issues with label agent:spawn
    last_git_push_ts: i64 = 0, // mtime of .git/refs/remotes/origin/main
    finished_containers: u8 = 0, // finished cloud containers
    last_issue_comment_ts: i64 = 0, // last issue comment timestamp
    doctor_quick_fails: u8 = 0, // consecutive doctor_quick failures

    pub fn healthEmoji(self: SenseResult) []const u8 {
        if (!self.build_ok) return E_CROSS;
        if (self.ouroboros_score >= 70) return E_STAR;
        if (self.ouroboros_score >= 40) return E_CHECK;
        return E_WRENCH;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub const ActionKind = enum(u8) {
    // Level 0 — Read-Only (always allowed)
    farm_status = 0,
    arena_status = 1,
    doctor_scan = 2,
    train_status = 3,
    train_diagnose = 4,
    experiment_chart = 5,
    patent_status = 6,
    research_sacred = 7,
    ouroboros_status = 8,
    experience_recall = 9,
    farm_evolve_status = 10,
    swarm_status = 11,

    // Level 1 — Soft Write (auto-allowed with --allow-auto-actions)
    doctor_quick = 12,
    doctor_heal = 13,
    ouroboros_cycle = 14,
    git_commit_state = 15,
    git_push = 16,
    issue_comment = 17,
    notify = 18,
    arena_battle = 19,
    experience_save = 20,
    fmt = 21,

    // Level 2 — Dangerous (needs /queen approve or --no-approval)
    farm_recycle = 22,
    farm_evolve_step = 23,
    cloud_spawn = 24,
    cloud_kill = 25,
    cloud_cleanup = 26,
    issue_create = 27,
    swarm_decompose = 28,

    pub const COUNT = 29;

    pub fn label(self: ActionKind) []const u8 {
        return switch (self) {
            .farm_status => "farm status",
            .arena_status => "arena leaderboard",
            .doctor_scan => "doctor scan",
            .train_status => "train status",
            .train_diagnose => "train diagnose",
            .experiment_chart => "experiment chart",
            .patent_status => "patent status",
            .research_sacred => "research sacred",
            .ouroboros_status => "ouroboros status",
            .experience_recall => "experience recall",
            .farm_evolve_status => "farm evolve status",
            .swarm_status => "swarm status",
            .doctor_quick => "doctor quick",
            .doctor_heal => "doctor heal",
            .ouroboros_cycle => "ouroboros cycle",
            .git_commit_state => "git commit",
            .git_push => "git push",
            .issue_comment => "issue comment",
            .notify => "notify",
            .arena_battle => "arena battle",
            .experience_save => "experience save",
            .fmt => "fmt",
            .farm_recycle => "farm recycle",
            .farm_evolve_step => "farm evolve step",
            .cloud_spawn => "cloud spawn",
            .cloud_kill => "cloud kill",
            .cloud_cleanup => "cloud cleanup",
            .issue_create => "issue create",
            .swarm_decompose => "swarm decompose",
        };
    }

    pub fn emojiIcon(self: ActionKind) []const u8 {
        return switch (self) {
            .farm_status => E_DNA,
            .arena_status => E_SWORDS,
            .doctor_scan => E_EYE,
            .train_status => E_BRAIN,
            .train_diagnose => E_WRENCH,
            .experiment_chart => E_STAR,
            .patent_status => E_KEY,
            .research_sacred => E_BOLT,
            .ouroboros_status => E_CYCLE,
            .experience_recall => E_BRAIN,
            .farm_evolve_status => E_DNA,
            .swarm_status => E_ROBOT,
            .doctor_quick => E_WRENCH,
            .doctor_heal => E_WRENCH,
            .ouroboros_cycle => E_CYCLE,
            .git_commit_state => E_DISK,
            .git_push => E_NET,
            .issue_comment => E_CLIP,
            .notify => E_BOLT,
            .arena_battle => E_SWORDS,
            .experience_save => E_DISK,
            .fmt => E_GEAR,
            .farm_recycle => E_CYCLE,
            .farm_evolve_step => E_DNA,
            .cloud_spawn => E_ROBOT,
            .cloud_kill => E_STOP,
            .cloud_cleanup => E_TRASH,
            .issue_create => E_CLIP,
            .swarm_decompose => E_ROBOT,
        };
    }
};

pub const ActionResult = struct {
    success: bool,
    output: [1024]u8 = undefined,
    output_len: usize = 0,
    duration_ms: u64 = 0,

    pub fn outputStr(self: *const ActionResult) []const u8 {
        return self.output[0..self.output_len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JSON HELPERS (minimal, no allocator needed)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn findJsonF32(data: []const u8, key: []const u8) ?f32 {
    const idx = std.mem.indexOf(u8, data, key) orelse return null;
    const start = idx + key.len;
    if (start >= data.len) return null;
    var end = start;
    while (end < data.len and (data[end] == '-' or data[end] == '.' or (data[end] >= '0' and data[end] <= '9'))) : (end += 1) {}
    if (end == start) return null;
    return std.fmt.parseFloat(f32, data[start..end]) catch null;
}

pub fn findJsonU32(data: []const u8, key: []const u8) ?u32 {
    const idx = std.mem.indexOf(u8, data, key) orelse return null;
    const start = idx + key.len;
    if (start >= data.len) return null;
    var end = start;
    while (end < data.len and data[end] >= '0' and data[end] <= '9') : (end += 1) {}
    if (end == start) return null;
    return std.fmt.parseInt(u32, data[start..end], 10) catch null;
}

pub fn findJsonI64(data: []const u8, key: []const u8) ?i64 {
    const idx = std.mem.indexOf(u8, data, key) orelse return null;
    const start = idx + key.len;
    if (start >= data.len) return null;
    var end = start;
    while (end < data.len and (data[end] == '-' or (data[end] >= '0' and data[end] <= '9'))) : (end += 1) {}
    if (end == start) return null;
    return std.fmt.parseInt(i64, data[start..end], 10) catch null;
}

pub fn findJsonBool(data: []const u8, key: []const u8) ?bool {
    const idx = std.mem.indexOf(u8, data, key) orelse return null;
    const start = idx + key.len;
    if (start + 4 > data.len) return null;
    if (std.mem.startsWith(u8, data[start..], "true")) return true;
    if (std.mem.startsWith(u8, data[start..], "false")) return false;
    return null;
}

pub fn findJsonStr(data: []const u8, key: []const u8) ?[]const u8 {
    const idx = std.mem.indexOf(u8, data, key) orelse return null;
    const start = idx + key.len;
    if (start >= data.len) return null;
    const end = std.mem.indexOfScalarPos(u8, data, start, '"') orelse return null;
    return data[start..end];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TELEGRAM BODY BUILDER (shared by queen.zig and queen_telegram.zig)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn buildTgBody(buf: []u8, chat_id: []const u8, message_id: ?i64, text: []const u8) ?[]const u8 {
    var i: usize = 0;

    const prefix = "{\"chat_id\":\"";
    if (i + prefix.len > buf.len) return null;
    @memcpy(buf[i..][0..prefix.len], prefix);
    i += prefix.len;
    if (i + chat_id.len > buf.len) return null;
    @memcpy(buf[i..][0..chat_id.len], chat_id);
    i += chat_id.len;

    if (message_id) |mid| {
        const mid_prefix = "\",\"message_id\":";
        if (i + mid_prefix.len > buf.len) return null;
        @memcpy(buf[i..][0..mid_prefix.len], mid_prefix);
        i += mid_prefix.len;

        var num_buf: [20]u8 = undefined;
        const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{mid}) catch return null;
        if (i + num_str.len > buf.len) return null;
        @memcpy(buf[i..][0..num_str.len], num_str);
        i += num_str.len;

        const text_prefix = ",\"text\":\"";
        if (i + text_prefix.len > buf.len) return null;
        @memcpy(buf[i..][0..text_prefix.len], text_prefix);
        i += text_prefix.len;
    } else {
        const text_prefix = "\",\"text\":\"";
        if (i + text_prefix.len > buf.len) return null;
        @memcpy(buf[i..][0..text_prefix.len], text_prefix);
        i += text_prefix.len;
    }

    // JSON-escape the text
    for (text) |c| {
        if (i + 2 >= buf.len - 4) break;
        switch (c) {
            '"' => {
                buf[i] = '\\';
                buf[i + 1] = '"';
                i += 2;
            },
            '\\' => {
                buf[i] = '\\';
                buf[i + 1] = '\\';
                i += 2;
            },
            '\n' => {
                buf[i] = '\\';
                buf[i + 1] = 'n';
                i += 2;
            },
            '\r' => {
                buf[i] = '\\';
                buf[i + 1] = 'r';
                i += 2;
            },
            else => {
                buf[i] = c;
                i += 1;
            },
        }
    }

    const suffix = "\"}";
    if (i + suffix.len <= buf.len) {
        @memcpy(buf[i..][0..suffix.len], suffix);
        i += suffix.len;
    }

    return buf[0..i];
}

pub fn initTelegram() TgConfig {
    const bot_token = std.posix.getenv("TELEGRAM_BOT_TOKEN") orelse "";
    const chat_id = std.posix.getenv("TELEGRAM_CHAT_ID") orelse "";
    return .{
        .bot_token = bot_token,
        .chat_id = chat_id,
        .enabled = bot_token.len > 0 and chat_id.len > 0,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Queen types — emoji consts are real UTF-8 bytes" {
    // Crown 👑 = U+1F451 = F0 9F 91 91
    try std.testing.expectEqual(@as(u8, 0xF0), E_CROWN[0]);
    try std.testing.expectEqual(@as(u8, 0x9F), E_CROWN[1]);
    try std.testing.expectEqual(@as(u8, 0x91), E_CROWN[2]);
    try std.testing.expectEqual(@as(u8, 0x91), E_CROWN[3]);
    // Brain 🧠 = U+1F9E0 = F0 9F A7 A0
    try std.testing.expectEqual(@as(u8, 0xF0), E_BRAIN[0]);
    try std.testing.expectEqual(@as(u8, 0xA7), E_BRAIN[2]);
    // Swords ⚔️ — first 3 bytes are ⚔ (U+2694) = E2 9A 94
    try std.testing.expectEqual(@as(u8, 0xE2), E_SWORDS[0]);
    try std.testing.expectEqual(@as(u8, 0x9A), E_SWORDS[1]);
    try std.testing.expectEqual(@as(u8, 0x94), E_SWORDS[2]);
}

test "Queen types — JSON helpers" {
    const data = "{\"best_ppl\":4.6,\"best_step\":100000,\"name\":\"R33\",\"ok\":true}";
    try std.testing.expectApproxEqAbs(@as(f32, 4.6), findJsonF32(data, "\"best_ppl\":").?, 0.01);
    try std.testing.expectEqual(@as(u32, 100000), findJsonU32(data, "\"best_step\":").?);
    try std.testing.expectEqual(true, findJsonBool(data, "\"ok\":").?);
    try std.testing.expectEqualStrings("R33", findJsonStr(data, "\"name\":\"").?);
}

test "Queen types — buildTgBody" {
    var buf: [512]u8 = undefined;
    const result = buildTgBody(&buf, "123", null, "hello") orelse unreachable;
    try std.testing.expect(std.mem.indexOf(u8, result, "\"chat_id\":\"123\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "\"text\":\"hello\"") != null);
}

test "Queen types — buildTgBody with message_id" {
    var buf: [512]u8 = undefined;
    const result = buildTgBody(&buf, "123", 456, "hello") orelse unreachable;
    try std.testing.expect(std.mem.indexOf(u8, result, "\"message_id\":456") != null);
}

test "Queen types — AlertKind" {
    try std.testing.expect(AlertKind.build_broken.emoji().len > 0);
    try std.testing.expect(AlertKind.build_broken.labelRu().len > 0);
}

test "Queen types — SenseResult healthEmoji" {
    const broken = SenseResult{ .build_ok = false };
    try std.testing.expectEqualStrings(E_CROSS, broken.healthEmoji());
    const good = SenseResult{ .build_ok = true, .ouroboros_score = 75 };
    try std.testing.expectEqualStrings(E_STAR, good.healthEmoji());
}

test "Queen types — ActionKind label" {
    try std.testing.expectEqualStrings("doctor quick", ActionKind.doctor_quick.label());
    try std.testing.expectEqualStrings("farm status", ActionKind.farm_status.label());
    try std.testing.expectEqualStrings("farm recycle", ActionKind.farm_recycle.label());
    try std.testing.expectEqualStrings("cloud spawn", ActionKind.cloud_spawn.label());
}

test "Queen types — ActionKind COUNT" {
    try std.testing.expectEqual(@as(u8, 29), ActionKind.COUNT);
}

test "Queen types — QueenConfig god mode" {
    var config = QueenConfig{};
    config.applyGodMode();
    try std.testing.expect(config.allow_auto_actions);
    try std.testing.expectEqual(@as(u8, 2), config.max_auto_level);
    try std.testing.expect(!config.require_human_approval);
}
