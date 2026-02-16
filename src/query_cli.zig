// query_cli — Interactive Knowledge Graph Query CLI using Trinity VSA
//
// Usage:
//   zig build query -- "entity" "relation"         # Query a relation
//   zig build query -- "Paris" "capital_of"         # → France
//   zig build query -- "Einstein" "works_at"        # → Princeton
//   zig build query -- --list                       # List all entities
//   zig build query -- --relations                  # List all relations
//   zig build query -- --info                       # Show KG info
//   zig build query -- --chain "Eiffel" "landmark_in" "city_country"  # Multi-hop
//
// Level 11.24 — Interactive CLI Binary for Trinity Symbolic Reasoning

const std = @import("std");
const vsa = @import("vsa.zig");
const hybrid = @import("hybrid.zig");

const HybridBigInt = hybrid.HybridBigInt;

const DIM = 1024;
const NUM_ENTITIES = 30;
const NUM_RELATIONS = 5;

// ═══════════════════════════════════════════════════════════════════════════════
// Entity names — 30 entities across 6 categories
// ═══════════════════════════════════════════════════════════════════════════════
const entity_names = [NUM_ENTITIES][]const u8{
    // Cities (0-4)
    "Paris",    "Tokyo",    "Rome",     "London",   "Cairo",
    // Countries (5-9)
    "France",   "Japan",    "Italy",    "UK",       "Egypt",
    // Landmarks (10-14)
    "Eiffel",   "Fuji",     "Colosseum", "BigBen",  "Pyramids",
    // Foods (15-19)
    "Croissant", "Sushi",   "Pizza",    "FishChips", "Falafel",
    // Languages (20-24)
    "French",   "Japanese", "Italian",  "English",  "Arabic",
    // Climates (25-29)
    "Temperate", "Humid",   "Mediterranean", "Oceanic", "Arid",
};

// ═══════════════════════════════════════════════════════════════════════════════
// Relation definitions
// ═══════════════════════════════════════════════════════════════════════════════
const relation_names = [NUM_RELATIONS][]const u8{
    "capital_of",     // city → country
    "landmark_in",    // landmark → city
    "cuisine_of",     // food → country
    "language_of",    // language → country
    "climate_of",     // climate → country
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

// ═══════════════════════════════════════════════════════════════════════════════
// Bipolar random vector generator (matches minimal_forward.zig)
// ═══════════════════════════════════════════════════════════════════════════════
fn bipolarRandom(dim: usize, seed: u64) HybridBigInt {
    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = @min(dim, hybrid.MAX_TRITS);

    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    for (0..result.trit_len) |i| {
        result.unpacked_cache[i] = if (random.boolean()) @as(i8, 1) else @as(i8, -1);
    }
    return result;
}

fn hvBind(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    return vsa.bind(a, b);
}

fn hvUnbind(bound: *HybridBigInt, key: *HybridBigInt) HybridBigInt {
    return vsa.unbind(bound, key);
}

fn hvSimilarity(a: *HybridBigInt, b: *HybridBigInt) f64 {
    return vsa.cosineSimilarity(a, b);
}

fn hvBundle2(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    return vsa.bundle2(a, b);
}

fn treeBundleN(items: []HybridBigInt) HybridBigInt {
    if (items.len == 0) unreachable;
    if (items.len == 1) return items[0];
    if (items.len == 2) return hvBundle2(&items[0], &items[1]);

    var count = items.len;
    while (count > 1) {
        var write: usize = 0;
        var read: usize = 0;
        while (read + 1 < count) : (read += 2) {
            items[write] = hvBundle2(&items[read], &items[read + 1]);
            write += 1;
        }
        if (read < count) {
            items[write] = items[read];
            write += 1;
        }
        count = write;
    }
    return items[0];
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

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        std.process.exit(1);
    }

    // Handle flags
    if (std.mem.eql(u8, args[1], "--info")) {
        printInfo();
        return;
    }
    if (std.mem.eql(u8, args[1], "--list")) {
        printEntities();
        return;
    }
    if (std.mem.eql(u8, args[1], "--relations")) {
        printRelations();
        return;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Build Knowledge Graph
    // ═══════════════════════════════════════════════════════════════════════
    print("Building knowledge graph ({d} entities, {d} relations, DIM={d})...\n", .{ NUM_ENTITIES, NUM_RELATIONS, DIM });

    // Create entity vectors
    var entities: [NUM_ENTITIES]HybridBigInt = undefined;
    for (0..NUM_ENTITIES) |i| {
        entities[i] = bipolarRandom(DIM, 0xCCDD000 + @as(u64, @intCast(i)) * 7919);
    }

    // Build relation memories (2-way split: a=0..2, b=3..4)
    const all_pairs = [NUM_RELATIONS][5][2]usize{
        capital_of_pairs,
        landmark_in_pairs,
        cuisine_of_pairs,
        language_of_pairs,
        climate_of_pairs,
    };

    var mem_a: [NUM_RELATIONS]HybridBigInt = undefined;
    var mem_b: [NUM_RELATIONS]HybridBigInt = undefined;

    for (0..NUM_RELATIONS) |rel| {
        var binds: [5]HybridBigInt = undefined;
        for (0..5) |i| {
            var k = entities[all_pairs[rel][i][0]];
            var v = entities[all_pairs[rel][i][1]];
            binds[i] = hvBind(&k, &v);
        }
        mem_a[rel] = treeBundleN(binds[0..3]);
        mem_b[rel] = treeBundleN(binds[3..5]);
    }

    print("KG ready.\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════
    // Process query
    // ═══════════════════════════════════════════════════════════════════════

    if (std.mem.eql(u8, args[1], "--chain") and args.len >= 4) {
        // Multi-hop chain query
        const entity_name = args[2];
        const entity_idx = findEntity(entity_name) orelse {
            print("Error: Unknown entity \"{s}\"\n", .{entity_name});
            print("Use --list to see available entities.\n", .{});
            std.process.exit(1);
        };

        print("Chain query: {s}", .{entity_names[entity_idx]});
        var current_idx = entity_idx;

        var hop: usize = 3;
        while (hop < args.len) : (hop += 1) {
            const rel_name = args[hop];
            const rel_idx = findRelation(rel_name) orelse {
                print("\nError: Unknown relation \"{s}\"\n", .{rel_name});
                print("Use --relations to see available relations.\n", .{});
                std.process.exit(1);
            };

            var key = entities[current_idx];
            var res_a = hvUnbind(&mem_a[rel_idx], &key);
            var res_b = hvUnbind(&mem_b[rel_idx], &key);

            var best_idx: usize = 0;
            var best_sim: f64 = -2.0;
            for (0..NUM_ENTITIES) |j| {
                var cj = entities[j];
                const sim_a = hvSimilarity(&res_a, &cj);
                const sim_b = hvSimilarity(&res_b, &cj);
                const sim = @max(sim_a, sim_b);
                if (sim > best_sim) { best_sim = sim; best_idx = j; }
            }

            print(" --[{s}]--> {s} (sim={d:.3})", .{ relation_names[rel_idx], entity_names[best_idx], best_sim });
            current_idx = best_idx;
        }
        print("\n", .{});
    } else if (args.len >= 3) {
        // Direct query: entity relation
        const entity_name = args[1];
        const rel_name = args[2];

        const entity_idx = findEntity(entity_name) orelse {
            print("Error: Unknown entity \"{s}\"\n", .{entity_name});
            print("Use --list to see available entities.\n", .{});
            std.process.exit(1);
        };

        const rel_idx = findRelation(rel_name) orelse {
            print("Error: Unknown relation \"{s}\"\n", .{rel_name});
            print("Use --relations to see available relations.\n", .{});
            std.process.exit(1);
        };

        var key = entities[entity_idx];
        var res_a = hvUnbind(&mem_a[rel_idx], &key);
        var res_b = hvUnbind(&mem_b[rel_idx], &key);

        var best_idx: usize = 0;
        var best_sim: f64 = -2.0;
        for (0..NUM_ENTITIES) |j| {
            var cj = entities[j];
            const sim_a = hvSimilarity(&res_a, &cj);
            const sim_b = hvSimilarity(&res_b, &cj);
            const sim = @max(sim_a, sim_b);
            if (sim > best_sim) { best_sim = sim; best_idx = j; }
        }

        print("Query: {s}({s}) = {s}\n", .{ relation_names[rel_idx], entity_names[entity_idx], entity_names[best_idx] });
        print("Similarity: {d:.4}\n", .{best_sim});
    } else {
        printUsage();
        std.process.exit(1);
    }
}

fn printUsage() void {
    print("Trinity Query CLI v1.0.0 -- Symbolic Knowledge Graph Query\n\n", .{});
    print("Usage:\n", .{});
    print("  zig build query -- <entity> <relation>            Direct query\n", .{});
    print("  zig build query -- --chain <entity> <rel1> <rel2> Multi-hop chain\n", .{});
    print("  zig build query -- --list                          List entities\n", .{});
    print("  zig build query -- --relations                     List relations\n", .{});
    print("  zig build query -- --info                          Show KG info\n\n", .{});
    print("Examples:\n", .{});
    print("  zig build query -- Paris capital_of\n", .{});
    print("  zig build query -- Eiffel landmark_in\n", .{});
    print("  zig build query -- --chain Eiffel landmark_in capital_of\n", .{});
}

fn printInfo() void {
    print("Trinity Query CLI v1.0.0\n", .{});
    print("Engine:     Trinity VSA (Bipolar)\n", .{});
    print("Dimension:  {d}\n", .{DIM});
    print("Entities:   {d} (6 categories)\n", .{NUM_ENTITIES});
    print("Relations:  {d} (split 2-way memories)\n", .{NUM_RELATIONS});
    print("Categories: Cities, Countries, Landmarks, Foods, Languages, Climates\n", .{});
    print("Level 11.24 -- Interactive CLI Binary\n", .{});
    print("Golden Chain #134\n", .{});
}

fn printEntities() void {
    const categories = [_][]const u8{ "Cities", "Countries", "Landmarks", "Foods", "Languages", "Climates" };
    print("Entities ({d}):\n", .{NUM_ENTITIES});
    for (categories, 0..) |cat, ci| {
        print("  {s}: ", .{cat});
        for (0..5) |i| {
            if (i > 0) print(", ", .{});
            print("{s}", .{entity_names[ci * 5 + i]});
        }
        print("\n", .{});
    }
}

fn printRelations() void {
    print("Relations ({d}):\n", .{NUM_RELATIONS});
    const descriptions = [NUM_RELATIONS][]const u8{
        "city → country",
        "landmark → city",
        "food → country",
        "language → country",
        "climate → country",
    };
    for (relation_names, 0..) |rn, i| {
        print("  {s}: {s}\n", .{ rn, descriptions[i] });
    }
}
