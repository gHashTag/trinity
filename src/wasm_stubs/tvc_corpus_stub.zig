// WASM stub for tvc_corpus — replaces file-dependent TVC corpus
// Provides the same public interface but stores nothing

const std = @import("std");

pub const TVC_MAX_ENTRIES = 1024;
pub const TVC_MAX_QUERY_LEN = 256;
pub const TVC_MAX_RESPONSE_LEN = 512;

pub const TVCEntry = struct {
    query_text: [TVC_MAX_QUERY_LEN]u8 = [_]u8{0} ** TVC_MAX_QUERY_LEN,
    query_len: u16 = 0,
    response_text: [TVC_MAX_RESPONSE_LEN]u8 = [_]u8{0} ** TVC_MAX_RESPONSE_LEN,
    response_len: u16 = 0,
    entry_id: u64 = 0,
    timestamp: i64 = 0,
    usage_count: u32 = 0,
    avg_similarity: f32 = 0,
    source_node: [16]u8 = [_]u8{0} ** 16,
};

pub const TVCCorpus = struct {
    count: usize = 0,
    version: u32 = 1,
    node_id: [16]u8 = [_]u8{0} ** 16,
    next_entry_id: u64 = 1,
    total_queries: u64 = 0,
    total_hits: u64 = 0,
    total_stores: u64 = 0,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn initInPlace(self: *Self) void {
        self.* = Self{};
    }

    pub fn initWithNodeId(node_id: [16]u8) Self {
        var s = Self{};
        s.node_id = node_id;
        return s;
    }

    pub fn initHeap(allocator: std.mem.Allocator) !*Self {
        const ptr = try allocator.create(Self);
        ptr.* = Self{};
        return ptr;
    }

    pub fn initHeapWithNodeId(allocator: std.mem.Allocator, node_id: [16]u8) !*Self {
        const ptr = try allocator.create(Self);
        ptr.* = Self.initWithNodeId(node_id);
        return ptr;
    }

    pub fn deinitHeap(self: *Self, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }
};
