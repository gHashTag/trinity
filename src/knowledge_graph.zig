// Trinity VSA Knowledge Graph
// [CYR:Граф] зonнandй on оwithноinе Vector Symbolic Architecture
//
// [CYR:Стру]to[CYR:тура]: Triple = (Subject, Predicate, Object)
// [CYR:Код]andроinанandе: bind(subject, bind(predicate, object))
// [CYR:Граф]: bundle inwithех трand[CYR:плето]in
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

/// Magic bytes for and[CYR:дент]andфandtoацandand fileа
pub const FILE_MAGIC = [4]u8{ 'T', 'R', 'K', 'G' };

/// [CYR:Вер]withandя [CYR:формата] fileа
pub const FILE_VERSION: u32 = 1;

/// [CYR:Размер] packed inеto[CYR:тора] in [CYR:байтах]
pub const PACKED_VECTOR_BYTES = (VECTOR_DIM + 4) / 5; // 5 трandтоin on [CYR:байт]

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:КОНФИГУРАЦИЯ]
// ═══════════════════════════════════════════════════════════════════════════════

/// [CYR:Размерно]withть VSA inеto[CYR:торо]in (toолandчеwithтinо трandтоin)
pub const VECTOR_DIM = 500;

/// Маtowithand[CYR:мальное] toолandчеwithтinо with[CYR:ущно]with[CYR:тей] in [CYR:графе]
pub const MAX_ENTITIES = 100;

/// Маtowithand[CYR:мальное] toолandчеwithтinо трand[CYR:плето]in
pub const MAX_TRIPLES = 200;

/// [CYR:Порог] with[CYR:ход]withтinа for tuning
pub const SIMILARITY_THRESHOLD = 0.3;

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:БАЗОВЫЕ] [CYR:СТРУКТУРЫ]
// ═══════════════════════════════════════════════════════════════════════════════

/// [CYR:Сущно]withть in [CYR:графе] зonнandй (andwithby[CYR:льзует] PackedBigInt for эto[CYR:оном]andand [CYR:памят]and)
pub const Entity = struct {
    name: []const u8,
    vector: PackedBigInt,
    id: u32,

    const Self = @This();

    /// [CYR:Соз]yesть with[CYR:ущно]withть andз and[CYR:мен]and
    pub fn init(name: []const u8, id: u32) Self {
        // Геnotрand[CYR:руем] vector andз [CYR:хэша] and[CYR:мен]and
        const seed = hashString(name);
        const packed_vec = packed_vsa.randomPackedVector(VECTOR_DIM, seed);
        return Self{
            .name = name,
            .vector = packed_vec,
            .id = id,
        };
    }

    /// [CYR:Хэш] with[CYR:тро]toand for seed
    pub fn hashString(s: []const u8) u64 {
        var hash: u64 = 5381;
        for (s) |c| {
            hash = ((hash << 5) +% hash) +% c;
        }
        return hash;
    }
};

/// [CYR:Отношен]andе between with[CYR:ущно]with[CYR:тям]and
pub const Relation = struct {
    name: []const u8,
    vector: PackedBigInt,
    id: u32,

    const Self = @This();

    pub fn init(name: []const u8, id: u32) Self {
        const seed = Entity.hashString(name) ^ 0xDEADBEEF; // [CYR:Другой] seed for from[CYR:ношен]andй
        const packed_vec = packed_vsa.randomPackedVector(VECTOR_DIM, seed);
        return Self{
            .name = name,
            .vector = packed_vec,
            .id = id,
        };
    }
};

/// Трand[CYR:плет] (Subject, Predicate, Object)
pub const Triple = struct {
    subject_id: u32,
    predicate_id: u32,
    object_id: u32,
    vector: PackedBigInt,

    const Self = @This();

    /// [CYR:Соз]yesть трand[CYR:плет] and заtoодandроin[CYR:ать] in vector
    pub fn init(
        subject: *const Entity,
        predicate: *const Relation,
        object: *const Entity,
    ) Self {
        // [CYR:Код]andроinанandе: bind(subject, bind(predicate, object))
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

/// [CYR:Граф] зonнandй on оwithноinе VSA (andwithby[CYR:льзует] PackedBigInt)
pub const KnowledgeGraph = struct {
    /// Вwithе with[CYR:ущно]withтand
    entities: [MAX_ENTITIES]?Entity,
    entity_count: u32,

    /// Вwithе from[CYR:ношен]andя
    relations: [MAX_ENTITIES]?Relation,
    relation_count: u32,

    /// Вwithе трand[CYR:плеты]
    triples: [MAX_TRIPLES]?Triple,
    triple_count: u32,

    /// [CYR:Супер]byзandцandя inwithех трand[CYR:плето]in ([CYR:граф] how одandн vector)
    graph_vector: PackedBigInt,

    const Self = @This();

    /// [CYR:Соз]yesть пуwith[CYR:той] [CYR:граф]
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

    /// [CYR:Доба]inandть or onйтand with[CYR:ущно]withть
    pub fn getOrCreateEntity(self: *Self, name: []const u8) *Entity {
        // Поandwithto with[CYR:уще]withтin[CYR:ующей]
        for (0..self.entity_count) |i| {
            if (self.entities[i]) |*e| {
                if (std.mem.eql(u8, e.name, name)) {
                    return e;
                }
            }
        }

        // [CYR:Соз]yesть ноinую
        const id = self.entity_count;
        self.entities[id] = Entity.init(name, id);
        self.entity_count += 1;
        return &self.entities[id].?;
    }

    /// [CYR:Доба]inandть or onйтand from[CYR:ношен]andе
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

    /// [CYR:Доба]inandть трand[CYR:плет] in [CYR:граф]
    pub fn addTriple(self: *Self, subject: []const u8, predicate: []const u8, object: []const u8) void {
        const subj = self.getOrCreateEntity(subject);
        const pred = self.getOrCreateRelation(predicate);
        const obj = self.getOrCreateEntity(object);

        const triple = Triple.init(subj, pred, obj);

        // [CYR:Доба]inandть in list трand[CYR:плето]in
        self.triples[self.triple_count] = triple;
        self.triple_count += 1;

        // [CYR:Обно]inandть [CYR:граф]-vector (bundle)
        if (self.triple_count == 1) {
            self.graph_vector = triple.vector;
        } else {
            self.graph_vector = packed_vsa.packedBundle(&self.graph_vector, &triple.vector);
        }
    }

    /// [CYR:Запро]with: onйтand object by subject and predicate
    /// query(subject, predicate, ?) → object
    /// Иwithby[CYR:льзует] unbind: result = unbind(graph, bind(subject, predicate))
    pub fn queryObject(self: *Self, subject: []const u8, predicate: []const u8) ?*Entity {
        const subj = self.findEntity(subject) orelse return null;
        const pred = self.findRelation(predicate) orelse return null;

        // [CYR:Соз]yesём pattern [CYR:запро]withа: bind(subject, predicate)
        const query_pattern = packed_vsa.packedBind(&subj.vector, &pred.vector);

        // Unbind from [CYR:графа]: unbind(graph, query_pattern) ≈ object
        const result_vec = packed_vsa.packedUnbind(&self.graph_vector, &query_pattern);

        // [CYR:Найт]and блand[CYR:жайшую] with[CYR:ущно]withть to resultу
        return self.findClosestEntityPacked(&result_vec);
    }

    /// [CYR:Запро]with: onйтand subject by predicate and object
    /// query(?, predicate, object) → subject
    /// Иwithby[CYR:льзует] unbind: result = unbind(graph, bind(predicate, object))
    pub fn querySubject(self: *Self, predicate: []const u8, object: []const u8) ?*Entity {
        const pred = self.findRelation(predicate) orelse return null;
        const obj = self.findEntity(object) orelse return null;

        // [CYR:Соз]yesём pattern [CYR:запро]withа: bind(predicate, object)
        const query_pattern = packed_vsa.packedBind(&pred.vector, &obj.vector);

        // Unbind from [CYR:графа]: unbind(graph, query_pattern) ≈ subject
        const result_vec = packed_vsa.packedUnbind(&self.graph_vector, &query_pattern);

        return self.findClosestEntityPacked(&result_vec);
    }

    /// [CYR:Найт]and N onandmore by[CYR:хож]andх with[CYR:ущно]with[CYR:тей]
    pub fn findSimilar(self: *Self, entity_name: []const u8, n: usize) [10]?struct { entity: *Entity, similarity: f64 } {
        var results: [10]?struct { entity: *Entity, similarity: f64 } = [_]?struct { entity: *Entity, similarity: f64 }{null} ** 10;

        const target = self.findEntity(entity_name) orelse return results;

        // [CYR:Выч]andwithлandть with[CYR:ход]withтinо withо inwithемand with[CYR:ущно]with[CYR:тям]and
        var similarities: [MAX_ENTITIES]f64 = [_]f64{0} ** MAX_ENTITIES;

        for (0..self.entity_count) |i| {
            if (self.entities[i]) |*e| {
                if (!std.mem.eql(u8, e.name, entity_name)) {
                    similarities[i] = packed_vsa.packedCosineSimilarity(&target.vector, &e.vector);
                }
            }
        }

        // [CYR:Найт]and [CYR:топ]-N ([CYR:про]with[CYR:тая] sorting)
        const result_count = @min(n, 10);
        for (0..result_count) |r| {
            var best_idx: ?usize = null;
            var best_sim: f64 = -2.0;

            for (0..self.entity_count) |i| {
                if (similarities[i] > best_sim) {
                    // [CYR:Про]inерandть what [CYR:ещё] not beforeбаin[CYR:лен]
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

    /// [CYR:Найт]and with[CYR:ущно]withть by and[CYR:мен]and
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

    /// [CYR:Найт]and from[CYR:ношен]andе by and[CYR:мен]and
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

    /// [CYR:Найт]and блand[CYR:жайшую] with[CYR:ущно]withть to packed inеto[CYR:тору]
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

    /// [CYR:Стат]andwithтandtoа [CYR:графа]
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

    /// [CYR:Сохран]andть [CYR:граф] in file
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

    /// [CYR:Загруз]andть [CYR:граф] andз fileа
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

        // Иwithby[CYR:льзуем] buffer for and[CYR:мён]
        var name_offset: usize = 0;

        // Entities
        for (0..entity_count) |i| {
            const name_len = try reader.readInt(u16, .little);

            // Чand[CYR:таем] andмя in buffer
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
// [CYR:ТЕСТЫ]
// ═══════════════════════════════════════════════════════════════════════════════

test "Entity creation" {
    const paris = Entity.init("Paris", 0);
    const france = Entity.init("France", 1);

    // [CYR:Разные] with[CYR:ущно]withтand before[CYR:лжны] and[CYR:меть] [CYR:разные] inеto[CYR:торы]
    const sim = packed_vsa.packedCosineSimilarity(&paris.vector, &france.vector);
    try std.testing.expect(sim < 0.5); // [CYR:Почт]and орthaton[CYR:льны]
}

test "KnowledgeGraph basic operations" {
    var kg = KnowledgeGraph.init();

    // Add фаtoты о with[CYR:тол]and[CYR:цах]
    kg.addTriple("Paris", "capital_of", "France");
    kg.addTriple("Berlin", "capital_of", "Germany");
    kg.addTriple("Rome", "capital_of", "Italy");

    const s = kg.stats();
    try std.testing.expectEqual(@as(u32, 6), s.entities); // 3 [CYR:горо]yes + 3 with[CYR:траны]
    try std.testing.expectEqual(@as(u32, 1), s.relations); // capital_of
    try std.testing.expectEqual(@as(u32, 3), s.triples);
}

test "KnowledgeGraph query object with unbind" {
    var kg = KnowledgeGraph.init();

    kg.addTriple("Paris", "capital_of", "France");
    kg.addTriple("Berlin", "capital_of", "Germany");
    kg.addTriple("Rome", "capital_of", "Italy");

    // [CYR:Запро]with: [CYR:Пар]andж - with[CYR:тол]andца [CYR:чего]?
    // unbind(graph, bind(Paris, capital_of)) → France
    const result = kg.queryObject("Paris", "capital_of");

    std.debug.print("\n\nQuery: Paris capital_of ?\n", .{});
    if (result) |entity| {
        std.debug.print("Result: {s}\n", .{entity.name});
        // Check what result - France
        try std.testing.expectEqualStrings("France", entity.name);
    } else {
        std.debug.print("Result: null\n", .{});
        // Еwithлand null, test [CYR:про]in[CYR:ален]
        try std.testing.expect(false);
    }
}

test "KnowledgeGraph query subject with unbind" {
    var kg = KnowledgeGraph.init();

    kg.addTriple("Paris", "capital_of", "France");
    kg.addTriple("Berlin", "capital_of", "Germany");

    // [CYR:Запро]with: what is with[CYR:тол]and[CYR:цей] [CYR:Франц]andand?
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
    // [CYR:Соз]yesём [CYR:граф]
    var kg = KnowledgeGraph.init();
    kg.addTriple("Paris", "capital_of", "France");
    kg.addTriple("Berlin", "capital_of", "Germany");
    kg.addTriple("Rome", "capital_of", "Italy");

    const original_stats = kg.stats();

    // [CYR:Сохраняем]
    try kg.save("/tmp/test_kg.trkg");

    // [CYR:Загружаем]
    var name_buffer: [4096]u8 = undefined;
    var loaded_kg = try KnowledgeGraph.load("/tmp/test_kg.trkg", &name_buffer);

    // Check with[CYR:тат]andwithтandtoу
    const loaded_stats = loaded_kg.stats();
    try std.testing.expectEqual(original_stats.entities, loaded_stats.entities);
    try std.testing.expectEqual(original_stats.relations, loaded_stats.relations);
    try std.testing.expectEqual(original_stats.triples, loaded_stats.triples);

    std.debug.print("\n\nSave/Load roundtrip:\n", .{});
    std.debug.print("Original: {d} entities, {d} relations, {d} triples\n", .{ original_stats.entities, original_stats.relations, original_stats.triples });
    std.debug.print("Loaded: {d} entities, {d} relations, {d} triples\n", .{ loaded_stats.entities, loaded_stats.relations, loaded_stats.triples });

    // Delete testоinый file
    std.fs.cwd().deleteFile("/tmp/test_kg.trkg") catch {};
}

test "queries work after load" {
    // [CYR:Соз]yesём and with[CYR:охраняем] [CYR:граф]
    var kg = KnowledgeGraph.init();
    kg.addTriple("Paris", "capital_of", "France");
    kg.addTriple("Berlin", "capital_of", "Germany");

    try kg.save("/tmp/test_kg_query.trkg");

    // [CYR:Загружаем]
    var name_buffer: [4096]u8 = undefined;
    var loaded_kg = try KnowledgeGraph.load("/tmp/test_kg_query.trkg", &name_buffer);

    // Check [CYR:запро]withы
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

    // Delete testоinый file
    std.fs.cwd().deleteFile("/tmp/test_kg_query.trkg") catch {};
}

test "benchmark KnowledgeGraph" {
    var kg = KnowledgeGraph.init();

    // Add [CYR:много] фаtoтоin
    const countries = [_][]const u8{ "France", "Germany", "Italy", "Spain", "UK", "Poland", "Sweden", "Norway", "Finland", "Denmark" };
    const capitals = [_][]const u8{ "Paris", "Berlin", "Rome", "Madrid", "London", "Warsaw", "Stockholm", "Oslo", "Helsinki", "Copenhagen" };

    var timer = std.time.Timer.start() catch unreachable;

    // [CYR:Доба]in[CYR:лен]andе трand[CYR:плето]in
    for (countries, capitals) |country, capital| {
        kg.addTriple(capital, "capital_of", country);
    }

    const add_ns = timer.read();

    // [CYR:Запро]withы
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
