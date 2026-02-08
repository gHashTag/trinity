// ═══════════════════════════════════════════════════════════════════════════════
// SACRED WORLDS — 27 Worlds of the 999 Kingdom
// Generated from sacred_worlds.vibee + hand-coded data tables
// 999 = 37 × 27 = SACRED_MULTIPLIER × TRIDEVYATITSA
// 27 = 3³ = (φ² + 1/φ²)³
// V = n × 3^k × π^m × φ^p × e^q
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════════

pub const RealmId = enum(u8) {
    razum = 0, // φ — Mind/Intelligence (Gold)
    materiya = 1, // π — Matter/Physical (Cyan)
    dukh = 2, // e — Spirit/Transcendental (Purple)
};

pub const DomainId = enum(u8) {
    // Realm 1: RAZUM
    communication = 0,
    analysis = 1,
    creation = 2,
    // Realm 2: MATERIYA
    system_domain = 3,
    tools_domain = 4,
    hardware = 5,
    // Realm 3: DUKH
    mathematics = 6,
    evolution = 7,
    transcendence = 8,
};

pub const WorldId = enum(u8) {
    // Realm 1: RAZUM (φ) — outer ring blocks 0-8
    chat = 0,
    voice = 1,
    translate = 2,
    code = 3,
    explain = 4,
    debug = 5,
    generate = 6,
    design = 7,
    compose = 8,
    // Realm 2: MATERIYA (π) — middle ring blocks 9-17
    monitor = 9,
    files = 10,
    network = 11,
    build = 12,
    test_world = 13,
    deploy = 14,
    fpga = 15,
    gpu = 16,
    quantum = 17,
    // Realm 3: DUKH (e) — inner ring blocks 18-26
    sacred = 18,
    geometry = 19,
    topology = 20,
    mutation = 21,
    crossover = 22,
    selection = 23,
    meditation = 24,
    vision_world = 25,
    prophecy = 26,
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
    // ── Realm 1: RAZUM (φ) — blocks 0-8 ──
    // Domain: Communication
    .{ .id = .chat, .realm = .razum, .domain = .communication, .name = mkName("CHAT"), .name_len = 4, .formula = mkFormula("phi = 1.618"), .formula_len = 11, .sacred_value = 1.618 },
    .{ .id = .voice, .realm = .razum, .domain = .communication, .name = mkName("VOICE"), .name_len = 5, .formula = mkFormula("pi*phi*e = 13.82"), .formula_len = 16, .sacred_value = 13.82 },
    .{ .id = .translate, .realm = .razum, .domain = .communication, .name = mkName("TRANSLATE"), .name_len = 9, .formula = mkFormula("L(10) = 123"), .formula_len = 11, .sacred_value = 123.0 },
    // Domain: Analysis
    .{ .id = .code, .realm = .razum, .domain = .analysis, .name = mkName("CODE"), .name_len = 4, .formula = mkFormula("1/a = 4pi3+pi2+pi = 137"), .formula_len = 22, .sacred_value = 137.036 },
    .{ .id = .explain, .realm = .razum, .domain = .analysis, .name = mkName("EXPLAIN"), .name_len = 7, .formula = mkFormula("phi2 = phi+1 = 2.618"), .formula_len = 20, .sacred_value = 2.618 },
    .{ .id = .debug, .realm = .razum, .domain = .analysis, .name = mkName("DEBUG"), .name_len = 5, .formula = mkFormula("Feigenbaum d = 4.669"), .formula_len = 20, .sacred_value = 4.669 },
    // Domain: Creation
    .{ .id = .generate, .realm = .razum, .domain = .creation, .name = mkName("GENERATE"), .name_len = 8, .formula = mkFormula("F(7) = 13"), .formula_len = 9, .sacred_value = 13.0 },
    .{ .id = .design, .realm = .razum, .domain = .creation, .name = mkName("DESIGN"), .name_len = 6, .formula = mkFormula("sqrt(5) = 2.236"), .formula_len = 15, .sacred_value = 2.236 },
    .{ .id = .compose, .realm = .razum, .domain = .creation, .name = mkName("COMPOSE"), .name_len = 7, .formula = mkFormula("999 = 37 x 27"), .formula_len = 13, .sacred_value = 999.0 },

    // ── Realm 2: MATERIYA (π) — blocks 9-17 ──
    // Domain: System
    .{ .id = .monitor, .realm = .materiya, .domain = .system_domain, .name = mkName("MONITOR"), .name_len = 7, .formula = mkFormula("pi = 3.14159"), .formula_len = 12, .sacred_value = 3.14159 },
    .{ .id = .files, .realm = .materiya, .domain = .system_domain, .name = mkName("FILES"), .name_len = 5, .formula = mkFormula("27 = 3^3"), .formula_len = 8, .sacred_value = 27.0 },
    .{ .id = .network, .realm = .materiya, .domain = .system_domain, .name = mkName("NETWORK"), .name_len = 7, .formula = mkFormula("CHSH = 2*sqrt(2) = 2.83"), .formula_len = 22, .sacred_value = 2.828 },
    // Domain: Tools
    .{ .id = .build, .realm = .materiya, .domain = .tools_domain, .name = mkName("BUILD"), .name_len = 5, .formula = mkFormula("m_p/m_e = 6pi5 = 1836"), .formula_len = 21, .sacred_value = 1836.15 },
    .{ .id = .test_world, .realm = .materiya, .domain = .tools_domain, .name = mkName("TEST"), .name_len = 4, .formula = mkFormula("pi2 = 9.87"), .formula_len = 10, .sacred_value = 9.87 },
    .{ .id = .deploy, .realm = .materiya, .domain = .tools_domain, .name = mkName("DEPLOY"), .name_len = 6, .formula = mkFormula("e^pi = 23.14"), .formula_len = 12, .sacred_value = 23.14 },
    // Domain: Hardware
    .{ .id = .fpga, .realm = .materiya, .domain = .hardware, .name = mkName("FPGA"), .name_len = 4, .formula = mkFormula("E8 dim = 248"), .formula_len = 12, .sacred_value = 248.0 },
    .{ .id = .gpu, .realm = .materiya, .domain = .hardware, .name = mkName("GPU"), .name_len = 3, .formula = mkFormula("603x = 67 x 3^2"), .formula_len = 15, .sacred_value = 603.0 },
    .{ .id = .quantum, .realm = .materiya, .domain = .hardware, .name = mkName("QUANTUM"), .name_len = 7, .formula = mkFormula("Jiuzhang 76 photons"), .formula_len = 19, .sacred_value = 76.0 },

    // ── Realm 3: DUKH (e) — blocks 18-26 ──
    // Domain: Mathematics
    .{ .id = .sacred, .realm = .dukh, .domain = .mathematics, .name = mkName("SACRED"), .name_len = 6, .formula = mkFormula("phi2+1/phi2 = 3 = TRINITY"), .formula_len = 24, .sacred_value = 3.0 },
    .{ .id = .geometry, .realm = .dukh, .domain = .mathematics, .name = mkName("GEOMETRY"), .name_len = 8, .formula = mkFormula("tau = 2*pi = 6.283"), .formula_len = 18, .sacred_value = 6.283 },
    .{ .id = .topology, .realm = .dukh, .domain = .mathematics, .name = mkName("TOPOLOGY"), .name_len = 8, .formula = mkFormula("Menger D = ln20/ln3"), .formula_len = 19, .sacred_value = 2.727 },
    // Domain: Evolution
    .{ .id = .mutation, .realm = .dukh, .domain = .evolution, .name = mkName("MUTATION"), .name_len = 8, .formula = mkFormula("mu = 1/phi2/10 = 0.0382"), .formula_len = 22, .sacred_value = 0.0382 },
    .{ .id = .crossover, .realm = .dukh, .domain = .evolution, .name = mkName("CROSSOVER"), .name_len = 9, .formula = mkFormula("chi = 1/phi/10 = 0.0618"), .formula_len = 22, .sacred_value = 0.0618 },
    .{ .id = .selection, .realm = .dukh, .domain = .evolution, .name = mkName("SELECTION"), .name_len = 9, .formula = mkFormula("sigma = phi = 1.618"), .formula_len = 19, .sacred_value = 1.618 },
    // Domain: Transcendence
    .{ .id = .meditation, .realm = .dukh, .domain = .transcendence, .name = mkName("MEDITATION"), .name_len = 10, .formula = mkFormula("e = 2.71828"), .formula_len = 11, .sacred_value = 2.718 },
    .{ .id = .vision_world, .realm = .dukh, .domain = .transcendence, .name = mkName("VISION"), .name_len = 6, .formula = mkFormula("Universe = 13.82 Gyr"), .formula_len = 20, .sacred_value = 13.82 },
    .{ .id = .prophecy, .realm = .dukh, .domain = .transcendence, .name = mkName("PROPHECY"), .name_len = 8, .formula = mkFormula("H0 = 70.74 km/s/Mpc"), .formula_len = 19, .sacred_value = 70.74 },
};

// ═══════════════════════════════════════════════════════════════════════════════
// REALM NAMES & COLORS (as RGBA u32 for easy bitcast)
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
    mkDomain("Communication"),
    mkDomain("Analysis"),
    mkDomain("Creation"),
    mkDomain("System"),
    mkDomain("Tools"),
    mkDomain("Hardware"),
    mkDomain("Mathematics"),
    mkDomain("Evolution"),
    mkDomain("Transcendence"),
};
pub const DOMAIN_NAME_LENS = [9]u8{ 13, 8, 8, 6, 5, 8, 11, 9, 13 };

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
