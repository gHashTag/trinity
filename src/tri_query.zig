// @origin(spec:tri_query.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI QUERY COMMAND
// ═══════════════════════════════════════════════════════════════════════════════
//
// Knowledge Graph Query CLI using Trinity VSA
// Usage: tri query <entity> <relation>
//        tri query --chain <entity> <rel1> <rel2> ...
//        tri query --list | --relations | --info
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ANSI color codes (inline to avoid module conflicts)
const GREEN = "\x1b[32m";
const GOLDEN = "\x1b[33m";
const CYAN = "\x1b[36m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const RESET = "\x1b[0m";

const DIM = 1024;
const NUM_ENTITIES = 30;
const NUM_RELATIONS = 5;

// Simple Bipolar BigInt for VSA operations (standalone to avoid module conflicts)
const BipolarBigInt = struct {
    trits: []i8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, dim: usize) !BipolarBigInt {
        const trits = try allocator.alloc(i8, dim);
        @memset(trits, 0);
        return BipolarBigInt{ .trits = trits, .allocator = allocator };
    }

    pub fn random(allocator: std.mem.Allocator, dim: usize, seed: u64) !BipolarBigInt {
        var result = try BipolarBigInt.init(allocator, dim);
        var rng = std.Random.DefaultPrng.init(seed);
        const rand = rng.random();
        for (0..dim) |i| {
            result.trits[i] = if (rand.boolean()) @as(i8, 1) else @as(i8, -1);
        }
        return result;
    }

    pub fn deinit(self: *BipolarBigInt) void {
        self.allocator.free(self.trits);
    }

    pub fn bind(self: BipolarBigInt, other: BipolarBigInt) !BipolarBigInt {
        var result = BipolarBigInt{ .trits = undefined, .allocator = self.allocator };
        result.trits = try self.allocator.alloc(i8, self.trits.len);
        for (0..self.trits.len) |i| {
            result.trits[i] = self.trits[i] * other.trits[i];
        }
        return result;
    }

    pub fn unbind(self: BipolarBigInt, key: BipolarBigInt) !BipolarBigInt {
        // Unbind = bind with inverse (same as bind for bipolar)
        return try self.bind(key);
    }

    pub fn cosineSimilarity(self: BipolarBigInt, other: BipolarBigInt) f64 {
        var dot: i32 = 0;
        var norm_a: f64 = 0;
        var norm_b: f64 = 0;
        for (0..self.trits.len) |i| {
            dot += @as(i32, self.trits[i]) * @as(i32, other.trits[i]);
            norm_a += @as(f64, @floatFromInt(self.trits[i])) * @as(f64, @floatFromInt(self.trits[i]));
            norm_b += @as(f64, @floatFromInt(other.trits[i])) * @as(f64, @floatFromInt(other.trits[i]));
        }
        const denom = @sqrt(norm_a) * @sqrt(norm_b);
        if (denom == 0) return 0;
        return @as(f64, @floatFromInt(dot)) / denom;
    }

    pub fn bundle(self: BipolarBigInt, other: BipolarBigInt) !BipolarBigInt {
        var result = BipolarBigInt{ .trits = undefined, .allocator = self.allocator };
        result.trits = try self.allocator.alloc(i8, self.trits.len);
        for (0..self.trits.len) |i| {
            const sum = self.trits[i] + other.trits[i];
            result.trits[i] = if (sum > 0) @as(i8, 1) else if (sum < 0) @as(i8, -1) else @as(i8, 0);
        }
        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Entity names — 30 entities across 6 categories
// ═══════════════════════════════════════════════════════════════════════════════
const entity_names = [NUM_ENTITIES][]const u8{
    // Cities (0-4)
    "Paris",     "Tokyo",    "Rome",          "London",    "Cairo",
    // Countries (5-9)
    "France",    "Japan",    "Italy",         "UK",        "Egypt",
    // Landmarks (10-14)
    "Eiffel",    "Fuji",     "Colosseum",     "BigBen",    "Pyramids",
    // Foods (15-19)
    "Croissant", "Sushi",    "Pizza",         "FishChips", "Falafel",
    // Languages (20-24)
    "French",    "Japanese", "Italian",       "English",   "Arabic",
    // Climates (25-29)
    "Temperate", "Humid",    "Mediterranean", "Oceanic",   "Arid",
};

// ═══════════════════════════════════════════════════════════════════════════════
// Relation definitions
// ═══════════════════════════════════════════════════════════════════════════════
const relation_names = [NUM_RELATIONS][]const u8{
    "capital_of", // city -> country
    "landmark_in", // landmark -> city
    "cuisine_of", // food -> country
    "language_of", // language -> country
    "climate_of", // climate -> country
};

// Relation pairs: [key_idx, val_idx]
const capital_of_pairs = [5][2]usize{ .{ 0, 5 }, .{ 1, 6 }, .{ 2, 7 }, .{ 3, 8 }, .{ 4, 9 } };
const landmark_in_pairs = [5][2]usize{ .{ 10, 0 }, .{ 11, 1 }, .{ 12, 2 }, .{ 13, 3 }, .{ 14, 4 } };
const cuisine_of_pairs = [5][2]usize{ .{ 15, 5 }, .{ 16, 6 }, .{ 17, 7 }, .{ 18, 8 }, .{ 19, 9 } };
const language_of_pairs = [5][2]usize{ .{ 20, 5 }, .{ 21, 6 }, .{ 22, 7 }, .{ 23, 8 }, .{ 24, 9 } };
const climate_of_pairs = [5][2]usize{ .{ 25, 5 }, .{ 26, 6 }, .{ 27, 7 }, .{ 28, 8 }, .{ 29, 9 } };

fn print(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

// Find entity index by name (case-insensitive prefix match)
fn findEntity(name: []const u8) ?usize {
    // Exact match first
    for (entity_names, 0..) |en, i| {
        if (std.ascii.eqlIgnoreCase(name, en)) return i;
    }
    // Prefix match
    for (entity_names, 0..) |en, i| {
        if (name.len >= 3 and en.len >= name.len) {
            var match = true;
            for (0..name.len) |c| {
                if (std.ascii.toLower(name[c]) != std.ascii.toLower(en[c])) {
                    match = false;
                    break;
                }
            }
            if (match) return i;
        }
    }
    return null;
}

// Find relation index by name
fn findRelation(name: []const u8) ?usize {
    for (relation_names, 0..) |rn, i| {
        if (std.ascii.eqlIgnoreCase(name, rn)) return i;
    }
    // Partial match
    for (relation_names, 0..) |rn, i| {
        if (name.len >= 3 and rn.len >= name.len) {
            var match = true;
            for (0..name.len) |c| {
                if (std.ascii.toLower(name[c]) != std.ascii.toLower(rn[c])) {
                    match = false;
                    break;
                }
            }
            if (match) return i;
        }
    }
    return null;
}

/// Main entry point for tri query command
pub fn runQueryCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    // Handle info-only flags (no KG needed)
    if (args.len >= 1 and (std.mem.eql(u8, args[0], "--info") or std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h"))) {
        printQueryHelp();
        return;
    }
    if (args.len >= 1 and std.mem.eql(u8, args[0], "--list")) {
        printEntities();
        return;
    }
    if (args.len >= 1 and std.mem.eql(u8, args[0], "--relations")) {
        printRelations();
        return;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Build Knowledge Graph
    // ═══════════════════════════════════════════════════════════════════════
    print("Building knowledge graph ({d} entities, {d} relations, DIM={d})...\n", .{ NUM_ENTITIES, NUM_RELATIONS, DIM });

    // Create entity vectors
    var entities: [NUM_ENTITIES]BipolarBigInt = undefined;
    for (0..NUM_ENTITIES) |i| {
        entities[i] = try BipolarBigInt.random(std.heap.page_allocator, DIM, 0xCCDD000 + @as(u64, @intCast(i)) * 7919);
    }

    // Build relation memories (bundle pairs)
    const all_pairs = [NUM_RELATIONS][5][2]usize{
        capital_of_pairs,
        landmark_in_pairs,
        cuisine_of_pairs,
        language_of_pairs,
        climate_of_pairs,
    };

    var mem: [NUM_RELATIONS]BipolarBigInt = undefined;

    for (0..NUM_RELATIONS) |rel| {
        var binds: [5]BipolarBigInt = undefined;
        for (0..5) |i| {
            binds[i] = try entities[all_pairs[rel][i][0]].bind(entities[all_pairs[rel][i][1]]);
        }
        // Bundle all 5 pairs
        mem[rel] = try (try (try (try binds[0].bundle(binds[1])).bundle(binds[2])).bundle(binds[3])).bundle(binds[4]);
    }

    print("KG ready.\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════
    // Process query
    // ═══════════════════════════════════════════════════════════════════════

    if (args.len >= 1 and std.mem.eql(u8, args[0], "--chain")) {
        // Multi-hop chain query
        if (args.len < 3) {
            print("{s}Error:{s} --chain requires at least 2 arguments: <entity> <relation>\n", .{ RED, RESET });
            return;
        }

        const entity_name = args[1];
        const entity_idx = findEntity(entity_name) orelse {
            print("{s}Error:{s} Unknown entity \"{s}\"\n", .{ RED, RESET, entity_name });
            print("Use {s}tri query --list{s} to see available entities.\n", .{ CYAN, RESET });
            return;
        };

        print("{s}Chain query:{s} {s}", .{ GOLDEN, RESET, entity_names[entity_idx] });
        var current_idx = entity_idx;

        var hop: usize = 2;
        while (hop < args.len) : (hop += 1) {
            const rel_name = args[hop];
            const rel_idx = findRelation(rel_name) orelse {
                print("\n{s}Error:{s} Unknown relation \"{s}\"\n", .{ RED, RESET, rel_name });
                print("Use {s}tri query --relations{s} to see available relations.\n", .{ CYAN, RESET });
                return;
            };

            const key = entities[current_idx];
            var res = try mem[rel_idx].unbind(key);

            var best_idx: usize = 0;
            var best_sim: f64 = -2.0;
            for (0..NUM_ENTITIES) |j| {
                const sim = res.cosineSimilarity(entities[j]);
                if (sim > best_sim) {
                    best_sim = sim;
                    best_idx = j;
                }
            }

            print(" {s}--[{s}]--> {s}{s}{s} (sim={d:.3})", .{ YELLOW, relation_names[rel_idx], CYAN, entity_names[best_idx], RESET, best_sim });
            current_idx = best_idx;
        }
        print("\n", .{});
    } else if (args.len >= 2) {
        // Direct query: entity relation
        const entity_name = args[0];
        const rel_name = args[1];

        const entity_idx = findEntity(entity_name) orelse {
            print("{s}Error:{s} Unknown entity \"{s}\"\n", .{ RED, RESET, entity_name });
            print("Use {s}tri query --list{s} to see available entities.\n", .{ CYAN, RESET });
            return;
        };

        const rel_idx = findRelation(rel_name) orelse {
            print("{s}Error:{s} Unknown relation \"{s}\"\n", .{ RED, RESET, rel_name });
            print("Use {s}tri query --relations{s} to see available relations.\n", .{ CYAN, RESET });
            return;
        };

        const key = entities[entity_idx];
        var res = mem[rel_idx].unbind(key);

        var best_idx: usize = 0;
        var best_sim: f64 = -2.0;
        for (0..NUM_ENTITIES) |j| {
            const sim = res.cosineSimilarity(entities[j]);
            if (sim > best_sim) {
                best_sim = sim;
                best_idx = j;
            }
        }

        print("\n{s}Query:{s} {s}({s}) = {s}{s}{s}\n", .{ GOLDEN, RESET, relation_names[rel_idx], entity_names[entity_idx], GREEN, entity_names[best_idx], RESET });
        print("{s}Similarity:{s} {d:.4}\n\n", .{ GOLDEN, RESET, best_sim });
    } else {
        print("{s}Error:{s} Invalid arguments\n\n", .{ RED, RESET });
        printQueryHelp();
    }
}

fn printQueryHelp() void {
    std.debug.print(
        \\╔════════════════════════════════════════════════════════════════════════════╗
        \\║                    {s}TRINITY KNOWLEDGE GRAPH QUERY{s}                           ║
        \\╠════════════════════════════════════════════════════════════════════════════╣
        \\║  {s}USAGE{s}                                                                   ║
        \\║    tri query <entity> <relation>            Direct query                       ║
        \\║    tri query --chain <entity> <rel1> ...    Multi-hop chain                   ║
        \\║    tri query --list                        List entities                     ║
        \\║    tri query --relations                   List relations                    ║
        \\║    tri query --info                        Show KG info                       ║
        \\║                                                                            ║
        \\║  {s}EXAMPLES{s}                                                                ║
        \\║    tri query Paris capital_of              What city is Paris the capital of?║
        \\║    tri query Eiffel landmark_in             Where is the Eiffel Tower?        ║
        \\║    tri query --chain Eiffel landmark_in capital_of                          ║
        \\║                                            (multi-hop: landmark -> city ->   ║
        \\║                                             country)                         ║
        \\║                                                                            ║
        \\║  {s}ENTITIES{s} (30 total)                                                      ║
        \\║    Cities: Paris, Tokyo, Rome, London, Cairo                                ║
        \\║    Countries: France, Japan, Italy, UK, Egypt                                ║
        \\║    Landmarks: Eiffel, Fuji, Colosseum, BigBen, Pyramids                      ║
        \\║    Foods: Croissant, Sushi, Pizza, FishChips, Falafel                        ║
        \\║    Languages: French, Japanese, Italian, English, Arabic                      ║
        \\║    Climates: Temperate, Humid, Mediterranean, Oceanic, Arid                   ║
        \\║                                                                            ║
        \\║  {s}RELATIONS{s}                                                               ║
        \\║    capital_of    city -> country                                              ║
        \\║    landmark_in   landmark -> city                                             ║
        \\║    cuisine_of    food -> country                                              ║
        \\║    language_of   language -> country                                          ║
        \\║    climate_of    climate -> country                                           ║
        \\║                                                                            ║
        \\╚════════════════════════════════════════════════════════════════════════════╝
        \\
    , .{ GREEN, RESET, CYAN, RESET, GOLDEN, RESET, YELLOW, RESET, CYAN, RESET });
    std.debug.print("\n{s}VSA Engine:{s} Bipolar {d}D vectors with bind/unbind/bundle operations\n", .{ GOLDEN, RESET, DIM });
    std.debug.print("{s}Level:{s} 11.25 — Symbolic Reasoning\n", .{ GOLDEN, RESET });
    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GREEN, RESET });
}

fn printEntities() void {
    const categories = [_][]const u8{ "Cities", "Countries", "Landmarks", "Foods", "Languages", "Climates" };
    print("\n{s}Entities ({d}):{s}\n", .{ GOLDEN, NUM_ENTITIES, RESET });
    for (categories, 0..) |cat, ci| {
        print("  {s}{s}:{s} ", .{ CYAN, cat, RESET });
        for (0..5) |i| {
            if (i > 0) print(", ", .{});
            print("{s}", .{entity_names[ci * 5 + i]});
        }
        print("\n", .{});
    }
    print("\n", .{});
}

fn printRelations() void {
    const descriptions = [NUM_RELATIONS][]const u8{
        "city -> country",
        "landmark -> city",
        "food -> country",
        "language -> country",
        "climate -> country",
    };
    print("\n{s}Relations ({d}):{s}\n", .{ GOLDEN, NUM_RELATIONS, RESET });
    for (relation_names, 0..) |rn, i| {
        print("  {s}{s}:{s} {s}\n", .{ CYAN, rn, RESET, descriptions[i] });
    }
    print("\n", .{});
}
