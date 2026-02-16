// WASM stub for igla_knowledge_graph — replaces VSA-dependent KG engine
// Provides the same public interface but returns null for all queries

const std = @import("std");

pub const KG_SIMILARITY_THRESHOLD: f64 = 0.10;
pub const KG_ENERGY_WH: f64 = 0.0008;

pub const KGQueryResult = struct {
    answer: []const u8,
    similarity: f64,
    relation: []const u8,
    subject: []const u8,
    multi_hop: bool,
};

pub const KGStats = struct {
    num_facts: usize,
    num_entities: usize,
    num_relations: usize,
    query_count: u64,
    hit_count: u64,

    pub fn getHitRate(self: *const KGStats) f64 {
        if (self.query_count == 0) return 0.0;
        return @as(f64, @floatFromInt(self.hit_count)) / @as(f64, @floatFromInt(self.query_count));
    }
};

pub const ChatKnowledgeGraph = struct {
    stats: KGStats,

    const Self = @This();

    pub fn init(_: std.mem.Allocator) Self {
        return Self{
            .stats = KGStats{
                .num_facts = 0,
                .num_entities = 0,
                .num_relations = 0,
                .query_count = 0,
                .hit_count = 0,
            },
        };
    }

    pub fn deinit(_: *Self) void {}

    pub fn addFact(_: *Self, _: []const u8, _: []const u8, _: []const u8) !void {}

    pub fn queryTriple(_: *Self, _: []const u8, _: []const u8) !?KGQueryResult {
        return null;
    }

    pub fn queryMultiHop(_: *Self, _: []const u8, _: []const u8, _: []const u8) !?KGQueryResult {
        return null;
    }

    pub fn queryNaturalLanguage(_: *Self, _: []const u8) !?KGQueryResult {
        return null;
    }

    pub fn loadDataset(_: *Self) !void {}

    pub fn getStats(self: *const Self) KGStats {
        return self.stats;
    }
};
