// Trinity VSA Knowledge Graph
//  onand on within Vector Symbolic Architecture
//
// to: Triple = (Subject, Predicate, Object)
// [CYR:Code]andinand: bind(subject, bind(predicate, object))
// : bundle inwith andin
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");
const vsa = @import("vsa.zig");
const hybrid = @import("hybrid.zig");
const packed_vsa = @import("packed_vsa.zig");
const packed_trit = @import("packed_trit.zig");

const HybridBigInt = hybrid.HybridBigInt;
const PackedBigInt = packed_trit.PackedBigInt;

// ═══════════════════════════════════════════════════════════════════════════════
// FILE FORMAT CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Magic bytes for andandtoand file
pub const FILE_MAGIC = [4]u8{ 'T', 'R', 'K', 'G' };

/// withandI  file
pub const FILE_VERSION: u32 = 1;

///  packed into in 
pub const PACKED_VECTOR_BYTES = (VECTOR_DIM + 4) / 5; // 5 andin on 

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:A]
// ═══════════════════════════════════════════════════════════════════════════════

/// with VSA intoin (toandwithin andin)
pub const VECTOR_DIM = 500;

/// towithand[CYR:lno] toandwithin with in 
pub const MAX_ENTITIES = 100;

/// towithand[CYR:lno] toandwithin andin
pub const MAX_TRIPLES = 200;

///  within for andwithto
pub const SIMILARITY_THRESHOLD = 0.3;

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:A] 
// ═══════════════════════════════════════════════════════════════════════════════

/// with in  onand (andwithl] PackedBigInt for toand [CYR:I]and)
pub const Entity = struct {
    name: []const u8,
    vector: PackedBigInt,
    id: u32,

    const Self = @This();

    /// [CYR:ate] with and and[CYR:me]and
    pub fn init(name: []const u8, id: u32) Self {
        // notand into and  and[CYR:me]and
        const seed = hashString(name);
        const packed_vec = packed_vsa.randomPackedVector(VECTOR_DIM, seed);
        return Self{
            .name = name,
            .vector = packed_vec,
            .id = id,
        };
    }

    ///  withtoand for seed
    pub fn hashString(s: []const u8) u64 {
        var hash: u64 = 5381;
        for (s) |c| {
            hash = ((hash << 5) +% hash) +% c;
        }
        return hash;
    }
};

/// and  withI]and
pub const Relation = struct {
    name: []const u8,
    vector: PackedBigInt,
    id: u32,

    const Self = @This();

    pub fn init(name: []const u8, id: u32) Self {
        const seed = Entity.hashString(name) ^ 0xDEADBEEF; // [CYR:go] seed for fromand
        const packed_vec = packed_vsa.randomPackedVector(VECTOR_DIM, seed);
        return Self{
            .name = name,
            .vector = packed_vec,
            .id = id,
        };
    }
};

/// and (Subject, Predicate, Object)
pub const Triple = struct {
    subject_id: u32,
    predicate_id: u32,
    object_id: u32,
    vector: PackedBigInt,

    const Self = @This();

    /// [CYR:ate] and and toandin[CYR:ate] in into
    pub fn init(
        subject: *const Entity,
        predicate: *const Relation,
        object: *const Entity,
    ) Self {
        // [CYR:Code]andinand: bind(subject, bind(predicate, object))
        const pred_obj = packed_vsa.packedBind(&predicate.vector, &object.vector);
        const triple_vec = packed_vsa.packedBind(&subject.vector, &pred_obj);

        return Self{
            .subject_id = subject.id,
            .predicate_id = predicate.id,
            .object_id = object.id,
            .vector = triple_vec,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// KNOWLEDGE GRAPH
// ═══════════════════════════════════════════════════════════════════════════════

///  onand on within VSA (andwithl] PackedBigInt)
pub const KnowledgeGraph = struct {
    /// with withand
    entities: [MAX_ENTITIES]?Entity,
    entity_count: u32,

    /// with fromandI
    relations: [MAX_ENTITIES]?Relation,
    relation_count: u32,

    /// with and[CYR:y]
    triples: [MAX_TRIPLES]?Triple,
    triple_count: u32,

    /// andI inwith andin ( toto and into)
    graph_vector: PackedBigInt,

    const Self = @This();

    /// [CYR:ate] with 
    pub fn init() Self {
        return Self{
            .entities = [_]?Entity{null} ** MAX_ENTITIES,
            .entity_count = 0,
            .relations = [_]?Relation{null} ** MAX_ENTITIES,
            .relation_count = 0,
            .triples = [_]?Triple{null} ** MAX_TRIPLES,
            .triple_count = 0,
            .graph_vector = PackedBigInt.zero(),
        };
    }

    /// inand or onand with
    pub fn getOrCreateEntity(self: *Self, name: []const u8) *Entity {
        // andwithto within
        for (0..self.entity_count) |i| {
            if (self.entities[i]) |*e| {
                if (std.mem.eql(u8, e.name, name)) {
                    return e;
                }
            }
        }

        // [CYR:ate] in
        const id = self.entity_count;
        self.entities[id] = Entity.init(name, id);
        self.entity_count += 1;
        return &self.entities[id].?;
    }

    /// inand or onand fromand
    pub fn getOrCreateRelation(self: *Self, name: []const u8) *Relation {
        for (0..self.relation_count) |i| {
            if (self.relations[i]) |*r| {
                if (std.mem.eql(u8, r.name, name)) {
                    return r;
                }
            }
        }

        const id = self.relation_count;
        self.relations[id] = Relation.init(name, id);
        self.relation_count += 1;
        return &self.relations[id].?;
    }

    /// inand and in 
    pub fn addTriple(self: *Self, subject: []const u8, predicate: []const u8, object: []const u8) void {
        const subj = self.getOrCreateEntity(subject);
        const pred = self.getOrCreateRelation(predicate);
        const obj = self.getOrCreateEntity(object);

        const triple = Triple.init(subj, pred, obj);

        // inand in withandwithto andin
        self.triples[self.triple_count] = triple;
        self.triple_count += 1;

        // inand -into (bundle)
        if (self.triple_count == 1) {
            self.graph_vector = triple.vector;
        } else {
            self.graph_vector = packed_vsa.packedBundle(&self.graph_vector, &triple.vector);
        }
    }

    /// [CYR:pro]with: onand object  subject and predicate
    /// query(subject, predicate, ?) → object
    /// withl] unbind: result = unbind(graph, bind(subject, predicate))
    pub fn queryObject(self: *Self, subject: []const u8, predicate: []const u8) ?*Entity {
        const subj = self.findEntity(subject) orelse return null;
        const pred = self.findRelation(predicate) orelse return null;

        //   [CYR:pro]with: bind(subject, predicate)
        const query_pattern = packed_vsa.packedBind(&subj.vector, &pred.vector);

        // Unbind from : unbind(graph, query_pattern) ≈ object
        const result_vec = packed_vsa.packedUnbind(&self.graph_vector, &query_pattern);

        // and and with to result
        return self.findClosestEntityPacked(&result_vec);
    }

    /// [CYR:pro]with: onand subject  predicate and object
    /// query(?, predicate, object) → subject
    /// withl] unbind: result = unbind(graph, bind(predicate, object))
    pub fn querySubject(self: *Self, predicate: []const u8, object: []const u8) ?*Entity {
        const pred = self.findRelation(predicate) orelse return null;
        const obj = self.findEntity(object) orelse return null;

        //   [CYR:pro]with: bind(predicate, object)
        const query_pattern = packed_vsa.packedBind(&pred.vector, &obj.vector);

        // Unbind from : unbind(graph, query_pattern) ≈ subject
        const result_vec = packed_vsa.packedUnbind(&self.graph_vector, &query_pattern);

        return self.findClosestEntityPacked(&result_vec);
    }

    /// and N onand and with
    pub fn findSimilar(self: *Self, entity_name: []const u8, n: usize) [10]?struct { entity: *Entity, similarity: f64 } {
        var results: [10]?struct { entity: *Entity, similarity: f64 } = [_]?struct { entity: *Entity, similarity: f64 }{null} ** 10;

        const target = self.findEntity(entity_name) orelse return results;

        // [CYR:Vy]andwithand within with inwithand withI]and
        var similarities: [MAX_ENTITIES]f64 = [_]f64{0} ** MAX_ENTITIES;

        for (0..self.entity_count) |i| {
            if (self.entities[i]) |*e| {
                if (!std.mem.eql(u8, e.name, entity_name)) {
                    similarities[i] = packed_vsa.packedCosineSimilarity(&target.vector, &e.vector);
                }
            }
        }

        // and -N ([CYR:pro]withI] withandinto)
        const result_count = @min(n, 10);
        for (0..result_count) |r| {
            var best_idx: ?usize = null;
            var best_sim: f64 = -2.0;

            for (0..self.entity_count) |i| {
                if (similarities[i] > best_sim) {
                    // inand that  not in
                    var already_added = false;
                    for (0..r) |prev| {
                        if (results[prev]) |res| {
                            if (res.entity.id == @as(u32, @intCast(i))) {
                                already_added = true;
                                break;
                            }
                        }
                    }
                    if (!already_added) {
                        best_sim = similarities[i];
                        best_idx = i;
                    }
                }
            }

            if (best_idx) |idx| {
                if (self.entities[idx]) |*e| {
                    results[r] = .{ .entity = e, .similarity = best_sim };
                }
            }
        }

        return results;
    }

    /// and with  and[CYR:me]and
    fn findEntity(self: *Self, name: []const u8) ?*Entity {
        for (0..self.entity_count) |i| {
            if (self.entities[i]) |*e| {
                if (std.mem.eql(u8, e.name, name)) {
                    return e;
                }
            }
        }
        return null;
    }

    /// and fromand  and[CYR:me]and
    fn findRelation(self: *Self, name: []const u8) ?*Relation {
        for (0..self.relation_count) |i| {
            if (self.relations[i]) |*r| {
                if (std.mem.eql(u8, r.name, name)) {
                    return r;
                }
            }
        }
        return null;
    }

    /// and and with to packed into
    fn findClosestEntityPacked(self: *Self, query_vec: *const PackedBigInt) ?*Entity {
        var best_entity: ?*Entity = null;
        var best_similarity: f64 = SIMILARITY_THRESHOLD;

        for (0..self.entity_count) |i| {
            if (self.entities[i]) |*e| {
                const sim = packed_vsa.packedCosineSimilarity(query_vec, &e.vector);
                if (sim > best_similarity) {
                    best_similarity = sim;
                    best_entity = e;
                }
            }
        }

        return best_entity;
    }

    /// andwithandto 
    pub fn stats(self: *const Self) struct { entities: u32, relations: u32, triples: u32 } {
        return .{
            .entities = self.entity_count,
            .relations = self.relation_count,
            .triples = self.triple_count,
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PERSISTENCE - Save/Load
    // ═══════════════════════════════════════════════════════════════════════════

    /// and  in file
    pub fn save(self: *const Self, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        var writer = file.writer();

        // Header
        try writer.writeAll(&FILE_MAGIC);
        try writer.writeInt(u32, FILE_VERSION, .little);
        try writer.writeInt(u32, self.entity_count, .little);
        try writer.writeInt(u32, self.relation_count, .little);

        // Entities
        for (0..self.entity_count) |i| {
            if (self.entities[i]) |e| {
                // Name length and name
                const name_len: u16 = @intCast(e.name.len);
                try writer.writeInt(u16, name_len, .little);
                try writer.writeAll(e.name);
                // ID
                try writer.writeInt(u32, e.id, .little);
                // Vector data
                const trit_len: u32 = @intCast(e.vector.trit_len);
                try writer.writeInt(u32, trit_len, .little);
                const packed_len = (e.vector.trit_len + 4) / 5;
                try writer.writeAll(e.vector.data[0..packed_len]);
            }
        }

        // Relations
        for (0..self.relation_count) |i| {
            if (self.relations[i]) |r| {
                const name_len: u16 = @intCast(r.name.len);
                try writer.writeInt(u16, name_len, .little);
                try writer.writeAll(r.name);
                try writer.writeInt(u32, r.id, .little);
                const trit_len: u32 = @intCast(r.vector.trit_len);
                try writer.writeInt(u32, trit_len, .little);
                const packed_len = (r.vector.trit_len + 4) / 5;
                try writer.writeAll(r.vector.data[0..packed_len]);
            }
        }

        // Triples
        try writer.writeInt(u32, self.triple_count, .little);
        for (0..self.triple_count) |i| {
            if (self.triples[i]) |t| {
                try writer.writeInt(u32, t.subject_id, .little);
                try writer.writeInt(u32, t.predicate_id, .little);
                try writer.writeInt(u32, t.object_id, .little);
                const trit_len: u32 = @intCast(t.vector.trit_len);
                try writer.writeInt(u32, trit_len, .little);
                const packed_len = (t.vector.trit_len + 4) / 5;
                try writer.writeAll(t.vector.data[0..packed_len]);
            }
        }

        // Graph vector
        const graph_trit_len: u32 = @intCast(self.graph_vector.trit_len);
        try writer.writeInt(u32, graph_trit_len, .little);
        const graph_packed_len = (self.graph_vector.trit_len + 4) / 5;
        try writer.writeAll(self.graph_vector.data[0..graph_packed_len]);
    }

    /// and  and file
    pub fn load(path: []const u8, name_buffer: []u8) !Self {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var reader = file.reader();
        var result = Self.init();

        // Header
        var magic: [4]u8 = undefined;
        _ = try reader.readAll(&magic);
        if (!std.mem.eql(u8, &magic, &FILE_MAGIC)) {
            return error.InvalidFileFormat;
        }

        const version = try reader.readInt(u32, .little);
        if (version != FILE_VERSION) {
            return error.UnsupportedVersion;
        }

        const entity_count = try reader.readInt(u32, .little);
        const relation_count = try reader.readInt(u32, .little);

        // withl] buffer for and
        var name_offset: usize = 0;

        // Entities
        for (0..entity_count) |i| {
            const name_len = try reader.readInt(u16, .little);

            // and andI in buffer
            const name_start = name_offset;
            _ = try reader.readAll(name_buffer[name_offset .. name_offset + name_len]);
            name_offset += name_len;

            const id = try reader.readInt(u32, .little);
            const trit_len = try reader.readInt(u32, .little);
            const packed_len = (trit_len + 4) / 5;

            var vec = PackedBigInt.zero();
            vec.trit_len = trit_len;
            _ = try reader.readAll(vec.data[0..packed_len]);

            result.entities[i] = Entity{
                .name = name_buffer[name_start .. name_start + name_len],
                .vector = vec,
                .id = id,
            };
            result.entity_count += 1;
        }

        // Relations
        for (0..relation_count) |i| {
            const name_len = try reader.readInt(u16, .little);

            const name_start = name_offset;
            _ = try reader.readAll(name_buffer[name_offset .. name_offset + name_len]);
            name_offset += name_len;

            const id = try reader.readInt(u32, .little);
            const trit_len = try reader.readInt(u32, .little);
            const packed_len = (trit_len + 4) / 5;

            var vec = PackedBigInt.zero();
            vec.trit_len = trit_len;
            _ = try reader.readAll(vec.data[0..packed_len]);

            result.relations[i] = Relation{
                .name = name_buffer[name_start .. name_start + name_len],
                .vector = vec,
                .id = id,
            };
            result.relation_count += 1;
        }

        // Triples
        const triple_count = try reader.readInt(u32, .little);
        for (0..triple_count) |i| {
            const subject_id = try reader.readInt(u32, .little);
            const predicate_id = try reader.readInt(u32, .little);
            const object_id = try reader.readInt(u32, .little);
            const trit_len = try reader.readInt(u32, .little);
            const packed_len = (trit_len + 4) / 5;

            var vec = PackedBigInt.zero();
            vec.trit_len = trit_len;
            _ = try reader.readAll(vec.data[0..packed_len]);

            result.triples[i] = Triple{
                .subject_id = subject_id,
                .predicate_id = predicate_id,
                .object_id = object_id,
                .vector = vec,
            };
            result.triple_count += 1;
        }

        // Graph vector
        const graph_trit_len = try reader.readInt(u32, .little);
        const graph_packed_len = (graph_trit_len + 4) / 5;
        result.graph_vector.trit_len = graph_trit_len;
        _ = try reader.readAll(result.graph_vector.data[0..graph_packed_len]);

        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// 
// ═══════════════════════════════════════════════════════════════════════════════

test "Entity creation" {
    const paris = Entity.init("Paris", 0);
    const france = Entity.init("France", 1);

    // [CYR:y] withand [CYR:y] and [CYR:y] infory]
    const sim = packed_vsa.packedCosineSimilarity(&paris.vector, &france.vector);
    try std.testing.expect(sim < 0.5); // and thaton[CYR:ly]
}

test "KnowledgeGraph basic operations" {
    var kg = KnowledgeGraph.init();

    // in[CYR:I] toy  withand
    kg.addTriple("Paris", "capital_of", "France");
    kg.addTriple("Berlin", "capital_of", "Germany");
    kg.addTriple("Rome", "capital_of", "Italy");

    const s = kg.stats();
    try std.testing.expectEqual(@as(u32, 6), s.entities); // 3 [CYR:go] + 3 withy]
    try std.testing.expectEqual(@as(u32, 1), s.relations); // capital_of
    try std.testing.expectEqual(@as(u32, 3), s.triples);
}

test "KnowledgeGraph query object with unbind" {
    var kg = KnowledgeGraph.init();

    kg.addTriple("Paris", "capital_of", "France");
    kg.addTriple("Berlin", "capital_of", "Germany");
    kg.addTriple("Rome", "capital_of", "Italy");

    // [CYR:pro]with: and - withand [CYR:go]?
    // unbind(graph, bind(Paris, capital_of)) → France
    const result = kg.queryObject("Paris", "capital_of");

    std.debug.print("\n\nQuery: Paris capital_of ?\n", .{});
    if (result) |entity| {
        std.debug.print("Result: {s}\n", .{entity.name});
        // in[CYR:I] that result - France
        try std.testing.expectEqualStrings("France", entity.name);
    } else {
        std.debug.print("Result: null\n", .{});
        // withand null, with [CYR:pro]in
        try std.testing.expect(false);
    }
}

test "KnowledgeGraph query subject with unbind" {
    var kg = KnowledgeGraph.init();

    kg.addTriple("Paris", "capital_of", "France");
    kg.addTriple("Berlin", "capital_of", "Germany");

    // [CYR:pro]with: that Iin[CYR:I]withI withand and?
    // unbind(graph, bind(capital_of, France)) → Paris
    const result = kg.querySubject("capital_of", "France");

    std.debug.print("\n\nQuery: ? capital_of France\n", .{});
    if (result) |entity| {
        std.debug.print("Result: {s}\n", .{entity.name});
        try std.testing.expectEqualStrings("Paris", entity.name);
    } else {
        std.debug.print("Result: null\n", .{});
        try std.testing.expect(false);
    }
}

test "save and load roundtrip" {
    //  
    var kg = KnowledgeGraph.init();
    kg.addTriple("Paris", "capital_of", "France");
    kg.addTriple("Berlin", "capital_of", "Germany");
    kg.addTriple("Rome", "capital_of", "Italy");

    const original_stats = kg.stats();

    // [CYR:I]
    try kg.save("/tmp/test_kg.trkg");

    // 
    var name_buffer: [4096]u8 = undefined;
    var loaded_kg = try KnowledgeGraph.load("/tmp/test_kg.trkg", &name_buffer);

    // in[CYR:I] withandwithandto
    const loaded_stats = loaded_kg.stats();
    try std.testing.expectEqual(original_stats.entities, loaded_stats.entities);
    try std.testing.expectEqual(original_stats.relations, loaded_stats.relations);
    try std.testing.expectEqual(original_stats.triples, loaded_stats.triples);

    std.debug.print("\n\nSave/Load roundtrip:\n", .{});
    std.debug.print("Original: {d} entities, {d} relations, {d} triples\n", .{ original_stats.entities, original_stats.relations, original_stats.triples });
    std.debug.print("Loaded: {d} entities, {d} relations, {d} triples\n", .{ loaded_stats.entities, loaded_stats.relations, loaded_stats.triples });

    // [CYR:I] withiny file
    std.fs.cwd().deleteFile("/tmp/test_kg.trkg") catch {};
}

test "queries work after load" {
    //  and withI] 
    var kg = KnowledgeGraph.init();
    kg.addTriple("Paris", "capital_of", "France");
    kg.addTriple("Berlin", "capital_of", "Germany");

    try kg.save("/tmp/test_kg_query.trkg");

    // 
    var name_buffer: [4096]u8 = undefined;
    var loaded_kg = try KnowledgeGraph.load("/tmp/test_kg_query.trkg", &name_buffer);

    // in[CYR:I] [CYR:pro]withy
    const result = loaded_kg.queryObject("Paris", "capital_of");

    std.debug.print("\n\nQuery after load:\n", .{});
    std.debug.print("Query: Paris capital_of ?\n", .{});

    if (result) |entity| {
        std.debug.print("Result: {s}\n", .{entity.name});
        try std.testing.expectEqualStrings("France", entity.name);
    } else {
        std.debug.print("Result: null (FAILED)\n", .{});
        try std.testing.expect(false);
    }

    // [CYR:I] withiny file
    std.fs.cwd().deleteFile("/tmp/test_kg_query.trkg") catch {};
}

test "benchmark KnowledgeGraph" {
    var kg = KnowledgeGraph.init();

    // in[CYR:I] [CYR:go] toin
    const countries = [_][]const u8{ "France", "Germany", "Italy", "Spain", "UK", "Poland", "Sweden", "Norway", "Finland", "Denmark" };
    const capitals = [_][]const u8{ "Paris", "Berlin", "Rome", "Madrid", "London", "Warsaw", "Stockholm", "Oslo", "Helsinki", "Copenhagen" };

    var timer = std.time.Timer.start() catch unreachable;

    // inand andin
    for (countries, capitals) |country, capital| {
        kg.addTriple(capital, "capital_of", country);
    }

    const add_ns = timer.read();

    // [CYR:pro]withy
    timer.reset();
    const iterations = 100;
    for (0..iterations) |_| {
        _ = kg.queryObject("Paris", "capital_of");
    }
    const query_ns = timer.read();

    std.debug.print("\n\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           KNOWLEDGE GRAPH BENCHMARK                           ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Entities: {d:4} | Relations: {d:4} | Triples: {d:4}              ║\n", .{ kg.entity_count, kg.relation_count, kg.triple_count });
    std.debug.print("║ Add 10 triples: {d:6} us                                      ║\n", .{add_ns / 1000});
    std.debug.print("║ Query (100 iter): {d:6} us ({d:4} us/query)                   ║\n", .{ query_ns / 1000, query_ns / 1000 / iterations });
    std.debug.print("╚═══════════════════════════════════════════════════════════════╝\n", .{});
}
