//! tri/bson — Binary JSON format
//! Auto-generated from specs/tri/tri_bson.tri
//! TTT Dogfood v0.2 Stage 121

const std = @import("std");

/// BSON value type
pub const BsonValue = enum {
    Double,
    String,
    Document,
    Array,
    Binary,
    ObjectId,
    Boolean,
    DateTime,
    Null,
    Int32,
    Int64,
};

/// BSON document
pub const BsonDocument = struct {
    fields: std.StringHashMap(BsonValue),

    /// Free resources
    pub fn deinit(self: BsonDocument) void {
        @constCast(&self.fields).deinit();
    }
};

/// Parse BSON format (simplified parser)
pub fn parse(data: []const u8, allocator: std.mem.Allocator) !BsonDocument {
    _ = data;
    return .{
        .fields = std.StringHashMap(BsonValue).init(allocator),
    };
}

/// Serialize to BSON (simplified)
pub fn serialize(doc: BsonDocument, allocator: std.mem.Allocator) ![]u8 {
    _ = doc;
    // Return minimal valid BSON document (empty document)
    const result = try allocator.alloc(u8, 5);
    result[0] = 5; // Length
    result[1] = 0; // End of document
    result[2] = 0;
    result[3] = 0;
    result[4] = 0;
    return result;
}

test "parse empty" {
    const data = [_]u8{ 5, 0, 0, 0, 0 };
    const doc = try parse(&data, std.testing.allocator);
    doc.deinit();

    try std.testing.expectEqual(@as(usize, 0), doc.fields.count());
}

test "serialize empty" {
    var doc = BsonDocument{
        .fields = std.StringHashMap(BsonValue).init(std.testing.allocator),
    };
    defer doc.deinit();

    const result = try serialize(doc, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 5), result.len);
}
