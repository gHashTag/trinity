// ═══════════════════════════════════════════════════════════════════════════════
// SACRED WORLDS — 27 Practical Panels of the Trinity Kingdom
// 999 = 37 × 27 = SACRED_MULTIPLIER × TRIDEVYATITSA
// 27 = 3³ = (φ² + 1/φ²)³
// V = n × 3^k × π^m × φ^p × e^q
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════════

pub const RealmId = enum(u8) {
    razum = 0, // φ — AI & Communication (Gold)
    materiya = 1, // π — Tools & System (Cyan)
    dukh = 2, // e — Content & Knowledge (Purple)
};

pub const DomainId = enum(u8) {
    // Realm 1: RAZUM — AI
    ai_chat = 0,
    ai_code = 1,
    ai_create = 2,
    // Realm 2: MATERIYA — Tools
    filesystem = 3,
    devtools = 4,
    infrastructure = 5,
    // Realm 3: DUKH — Content
    knowledge = 6,
    content = 7,
    community = 8,
};

pub const WorldId = enum(u8) {
    // Realm 1: RAZUM (φ) — AI & Communication, blocks 0-8
    chat = 0,
    code = 1,
    explain = 2,
    debug = 3,
    review = 4,
    translate = 5,
    vibee = 6,
    voice = 7,
    compose = 8,
    // Realm 2: MATERIYA (π) — Tools & System, blocks 9-17
    files = 9,
    editor = 10,
    build = 11,
    test_run = 12,
    terminal = 13,
    git = 14,
    deploy = 15,
    monitor = 16,
    settings = 17,
    // Realm 3: DUKH (e) — Content & Knowledge, blocks 18-26
    docs = 18,
    reels = 19,
    feed = 20,
    roadmap = 21,
    benchmarks = 22,
    research = 23,
    formulas = 24,
    community_world = 25,
    about = 26,
};

// ═══════════════════════════════════════════════════════════════════════════════
// WORLD INFO
// ═══════════════════════════════════════════════════════════════════════════════

pub const WorldInfo = struct {
    id: WorldId,
    realm: RealmId,
    domain: DomainId,
    name: [24]u8,
    name_len: u8,
    formula: [48]u8,
    formula_len: u8,
    sacred_value: f32,
};

fn mkName(comptime s: []const u8) [24]u8 {
    var buf: [24]u8 = [_]u8{0} ** 24;
    for (s, 0..) |c, i| buf[i] = c;
    return buf;
}

fn mkFormula(comptime s: []const u8) [48]u8 {
    var buf: [48]u8 = [_]u8{0} ** 48;
    for (s, 0..) |c, i| buf[i] = c;
    return buf;
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATIC DATA TABLE — 27 WORLDS
// ═══════════════════════════════════════════════════════════════════════════════

pub const WORLDS: [27]WorldInfo = .{
    // ── Realm 1: RAZUM (φ) — AI & Communication, blocks 0-8 ──
    // Domain: AI Chat
    .{ .id = .chat, .realm = .razum, .domain = .ai_chat, .name = mkName("CHAT"), .name_len = 4, .formula = mkFormula("phi = 1.618"), .formula_len = 11, .sacred_value = 1.618 },
    .{ .id = .code, .realm = .razum, .domain = .ai_chat, .name = mkName("CODE"), .name_len = 4, .formula = mkFormula("pi*phi*e = 13.82"), .formula_len = 16, .sacred_value = 13.82 },
    .{ .id = .explain, .realm = .razum, .domain = .ai_chat, .name = mkName("EXPLAIN"), .name_len = 7, .formula = mkFormula("L(10) = 123"), .formula_len = 11, .sacred_value = 123.0 },
    // Domain: AI Code
    .{ .id = .debug, .realm = .razum, .domain = .ai_code, .name = mkName("DEBUG"), .name_len = 5, .formula = mkFormula("1/a = 137.036"), .formula_len = 13, .sacred_value = 137.036 },
    .{ .id = .review, .realm = .razum, .domain = .ai_code, .name = mkName("REVIEW"), .name_len = 6, .formula = mkFormula("phi2 = phi+1 = 2.618"), .formula_len = 20, .sacred_value = 2.618 },
    .{ .id = .translate, .realm = .razum, .domain = .ai_code, .name = mkName("TRANSLATE"), .name_len = 9, .formula = mkFormula("Feigenbaum d = 4.669"), .formula_len = 20, .sacred_value = 4.669 },
    // Domain: AI Create
    .{ .id = .tri, .realm = .razum, .domain = .ai_create, .name = mkName("VIBEE"), .name_len = 5, .formula = mkFormula("F(7) = 13"), .formula_len = 9, .sacred_value = 13.0 },
    .{ .id = .voice, .realm = .razum, .domain = .ai_create, .name = mkName("VOICE"), .name_len = 5, .formula = mkFormula("sqrt(5) = 2.236"), .formula_len = 15, .sacred_value = 2.236 },
    .{ .id = .compose, .realm = .razum, .domain = .ai_create, .name = mkName("COMPOSE"), .name_len = 7, .formula = mkFormula("999 = 37 x 27"), .formula_len = 13, .sacred_value = 999.0 },

    // ── Realm 2: MATERIYA (π) — Tools & System, blocks 9-17 ──
    // Domain: Filesystem
    .{ .id = .files, .realm = .materiya, .domain = .filesystem, .name = mkName("FILES"), .name_len = 5, .formula = mkFormula("pi = 3.14159"), .formula_len = 12, .sacred_value = 3.14159 },
    .{ .id = .editor, .realm = .materiya, .domain = .filesystem, .name = mkName("EDITOR"), .name_len = 6, .formula = mkFormula("27 = 3^3"), .formula_len = 8, .sacred_value = 27.0 },
    .{ .id = .build, .realm = .materiya, .domain = .filesystem, .name = mkName("BUILD"), .name_len = 5, .formula = mkFormula("CHSH = 2*sqrt(2) = 2.83"), .formula_len = 22, .sacred_value = 2.828 },
    // Domain: Dev Tools
    .{ .id = .test_run, .realm = .materiya, .domain = .devtools, .name = mkName("TEST"), .name_len = 4, .formula = mkFormula("m_p/m_e = 1836"), .formula_len = 14, .sacred_value = 1836.15 },
    .{ .id = .terminal, .realm = .materiya, .domain = .devtools, .name = mkName("TERMINAL"), .name_len = 8, .formula = mkFormula("pi2 = 9.87"), .formula_len = 10, .sacred_value = 9.87 },
    .{ .id = .git, .realm = .materiya, .domain = .devtools, .name = mkName("GIT"), .name_len = 3, .formula = mkFormula("e^pi = 23.14"), .formula_len = 12, .sacred_value = 23.14 },
    // Domain: Infrastructure
    .{ .id = .deploy, .realm = .materiya, .domain = .infrastructure, .name = mkName("DEPLOY"), .name_len = 6, .formula = mkFormula("E8 dim = 248"), .formula_len = 12, .sacred_value = 248.0 },
    .{ .id = .monitor, .realm = .materiya, .domain = .infrastructure, .name = mkName("DePIN NODE"), .name_len = 10, .formula = mkFormula("phi2+1/phi2 = 3 = $TRI"), .formula_len = 22, .sacred_value = 3.0 },
    .{ .id = .settings, .realm = .materiya, .domain = .infrastructure, .name = mkName("SETTINGS"), .name_len = 8, .formula = mkFormula("76 photons"), .formula_len = 10, .sacred_value = 76.0 },

    // ── Realm 3: DUKH (e) — Content & Knowledge, blocks 18-26 ──
    // Domain: Knowledge
    .{ .id = .docs, .realm = .dukh, .domain = .knowledge, .name = mkName("DOCS"), .name_len = 4, .formula = mkFormula("phi2+1/phi2 = 3 = TRINITY"), .formula_len = 24, .sacred_value = 3.0 },
    .{ .id = .reels, .realm = .dukh, .domain = .knowledge, .name = mkName("REELS"), .name_len = 5, .formula = mkFormula("tau = 2*pi = 6.283"), .formula_len = 18, .sacred_value = 6.283 },
    .{ .id = .feed, .realm = .dukh, .domain = .knowledge, .name = mkName("FEED"), .name_len = 4, .formula = mkFormula("Menger D = ln20/ln3"), .formula_len = 19, .sacred_value = 2.727 },
    // Domain: Content
    .{ .id = .roadmap, .realm = .dukh, .domain = .content, .name = mkName("ROADMAP"), .name_len = 7, .formula = mkFormula("mu = 0.0382"), .formula_len = 11, .sacred_value = 0.0382 },
    .{ .id = .benchmarks, .realm = .dukh, .domain = .content, .name = mkName("BENCHMARKS"), .name_len = 10, .formula = mkFormula("chi = 0.0618"), .formula_len = 12, .sacred_value = 0.0618 },
    .{ .id = .research, .realm = .dukh, .domain = .content, .name = mkName("RESEARCH"), .name_len = 8, .formula = mkFormula("sigma = phi = 1.618"), .formula_len = 19, .sacred_value = 1.618 },
    // Domain: Community
    .{ .id = .formulas, .realm = .dukh, .domain = .community, .name = mkName("FORMULAS"), .name_len = 8, .formula = mkFormula("e = 2.71828"), .formula_len = 11, .sacred_value = 2.718 },
    .{ .id = .community_world, .realm = .dukh, .domain = .community, .name = mkName("COMMUNITY"), .name_len = 9, .formula = mkFormula("Universe = 13.82 Gyr"), .formula_len = 20, .sacred_value = 13.82 },
    .{ .id = .about, .realm = .dukh, .domain = .community, .name = mkName("ABOUT"), .name_len = 5, .formula = mkFormula("H0 = 70.74 km/s/Mpc"), .formula_len = 19, .sacred_value = 70.74 },
};

// ═══════════════════════════════════════════════════════════════════════════════
// REALM NAMES & COLORS
// ═══════════════════════════════════════════════════════════════════════════════

pub const REALM_NAMES = [3][12]u8{
    [_]u8{ 'R', 'A', 'Z', 'U', 'M', 0, 0, 0, 0, 0, 0, 0 }, // φ
    [_]u8{ 'M', 'A', 'T', 'E', 'R', 'I', 'Y', 'A', 0, 0, 0, 0 }, // π
    [_]u8{ 'D', 'U', 'K', 'H', 0, 0, 0, 0, 0, 0, 0, 0 }, // e
};
pub const REALM_NAME_LENS = [3]u8{ 5, 8, 4 };

pub const REALM_SYMBOLS = [3][6]u8{
    [_]u8{ 'p', 'h', 'i', 0, 0, 0 }, // φ
    [_]u8{ 'p', 'i', 0, 0, 0, 0 }, // π
    [_]u8{ 'e', 0, 0, 0, 0, 0 }, // e
};
pub const REALM_SYMBOL_LENS = [3]u8{ 3, 2, 1 };

// Realm colors: Gold, Cyan, Purple (RGBA)
pub const REALM_COLORS_R = [3]u8{ 0xFF, 0x50, 0xBD };
pub const REALM_COLORS_G = [3]u8{ 0xD7, 0xFA, 0x93 };
pub const REALM_COLORS_B = [3]u8{ 0x00, 0xFA, 0xF9 };

pub const DOMAIN_NAMES = [9][16]u8{
    mkDomain("AI Chat"),
    mkDomain("AI Code"),
    mkDomain("AI Create"),
    mkDomain("Filesystem"),
    mkDomain("Dev Tools"),
    mkDomain("Infrastructure"),
    mkDomain("Knowledge"),
    mkDomain("Content"),
    mkDomain("Community"),
};
pub const DOMAIN_NAME_LENS = [9]u8{ 7, 7, 9, 10, 9, 14, 9, 7, 9 };

fn mkDomain(comptime s: []const u8) [16]u8 {
    var buf: [16]u8 = [_]u8{0} ** 16;
    for (s, 0..) |c, i| buf[i] = c;
    return buf;
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOOKUP FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Get WorldInfo by block index (0-26)
pub fn getWorldByBlock(block_index: usize) WorldInfo {
    if (block_index >= 27) return WORLDS[0];
    return WORLDS[block_index];
}

/// Get RealmId from block index
pub fn blockToRealm(block_index: usize) RealmId {
    if (block_index < 9) return .razum;
    if (block_index < 18) return .materiya;
    return .dukh;
}

/// Get realm color components
pub fn realmColorR(realm: RealmId) u8 {
    return REALM_COLORS_R[@intFromEnum(realm)];
}
pub fn realmColorG(realm: RealmId) u8 {
    return REALM_COLORS_G[@intFromEnum(realm)];
}
pub fn realmColorB(realm: RealmId) u8 {
    return REALM_COLORS_B[@intFromEnum(realm)];
}
