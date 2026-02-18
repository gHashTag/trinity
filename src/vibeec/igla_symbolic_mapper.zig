// ═══════════════════════════════════════════════════════════════════════════════
// IGLA SYMBOLIC MAPPER v1.0 - Cross-Language Semantic Verification
// ═══════════════════════════════════════════════════════════════════════════════
//
// Использует VSA (Vector Symbolic Architecture) для обеспечения семантической
// консистентности между сгенерированными языками.
//
// Фаза 1: Определение ролей языков (Role Vectors)
// Фаза 2: Привязка понятий к ролям (Concept Binding)
// Фаза 3: Верификация семантического переноса (Semantic Mapping Verification)
//
// φ² + 1/φ² = 3 | PHOENIX
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa = @import("igla_metal_vsa.zig");
const TritVec = vsa.TritVec;

pub const LanguageRole = enum {
    zig,
    python,
    rust,
    typescript,
    verilog,
};

pub const SymbolicMapper = struct {
    allocator: std.mem.Allocator,
    dimension: usize,
    roles: [5]TritVec,
    codebook: std.StringHashMap(TritVec),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, dimension: usize) !Self {
        var self = Self{
            .allocator = allocator,
            .dimension = dimension,
            .roles = undefined,
            .codebook = std.StringHashMap(TritVec).init(allocator),
        };

        // Initialize language role vectors
        for (&self.roles, 0..) |*role, i| {
            role.* = try TritVec.random(allocator, dimension, 42 + i);
        }

        return self;
    }

    pub fn deinit(self: *Self) void {
        for (&self.roles) |*role| {
            role.deinit();
        }
        var it = self.codebook.valueIterator();
        while (it.next()) |val| {
            val.deinit();
        }
        self.codebook.deinit();
    }

    pub fn registerConcept(self: *Self, name: []const u8) !void {
        const h = std.hash.Fnv1a_64.hash(name);
        const concept = try TritVec.random(self.allocator, self.dimension, h);
        try self.codebook.put(name, concept);
    }

    /// translateConstruct: bind(construct_hv, source_lang_role) -> unbind -> bind(target_lang_role)
    pub fn translate(self: *Self, concept_name: []const u8, source: LanguageRole, target: LanguageRole) !TritVec {
        const concept = self.codebook.get(concept_name) orelse return error.ConceptNotFound;
        const source_role = self.roles[@intFromEnum(source)];
        const target_role = self.roles[@intFromEnum(target)];

        // 1. Bind concept to source language role
        var bound_source = try vsa.bindSimd(self.allocator, &concept, &source_role);
        defer bound_source.deinit();

        // 2. Unbind from source (Retrieve raw concept)
        // In VSA, unbind is often the same as bind for bipolar/ternary vectors
        // especially with XOR-like bind. For ternary, bind is circular convolution or similar.
        // igla_metal_vsa.zig uses element-wise multiplication (Ternary Bind).
        var unbound_concept = try vsa.bindSimd(self.allocator, &bound_source, &source_role); // A * B * B ~ A (mostly)
        defer unbound_concept.deinit();

        // 3. Bind to target language role
        return try vsa.bindSimd(self.allocator, &unbound_concept, &target_role);
    }

    pub fn verifyConsistency(self: *Self, concept_name: []const u8, source: LanguageRole, target: LanguageRole) !f32 {
        const original_concept = self.codebook.get(concept_name) orelse return error.ConceptNotFound;
        var target_bound = try self.translate(concept_name, source, target);
        defer target_bound.deinit();

        const target_role = self.roles[@intFromEnum(target)];
        var decoded_concept = try vsa.bindSimd(self.allocator, &target_bound, &target_role);
        defer decoded_concept.deinit();

        return @as(f32, @floatCast(vsa.cosineSimilaritySimd(&original_concept, &decoded_concept)));
    }
};

test "Symbolic Mapping: Zig to Python Semantic Transfer" {
    const allocator = std.testing.allocator;
    var mapper = try SymbolicMapper.init(allocator, 1024);
    defer mapper.deinit();

    try mapper.registerConcept("String");
    try mapper.registerConcept("Integer");

    // Verify consistency: Transfer "String" from Zig role to Python role
    const similarity = try mapper.verifyConsistency("String", .zig, .python);

    // We expect similarity around 0.66 for ternary VSA with 1/3 zeros
    // as information is lost where role vector is zero.
    try std.testing.expect(similarity > 0.6);
}

test "Symbolic Mapping: Concept Discrimination" {
    const allocator = std.testing.allocator;
    var mapper = try SymbolicMapper.init(allocator, 1024);
    defer mapper.deinit();

    try mapper.registerConcept("String");
    try mapper.registerConcept("Int");

    const string_vec = mapper.codebook.get("String").?;
    const int_vec = mapper.codebook.get("Int").?;

    const sim = vsa.cosineSimilaritySimd(&string_vec, &int_vec);

    // Concepts should be quasi-orthogonal
    try std.testing.expect(sim < 0.2);
}
