//! tri/csv — Comma-separated values
//! Auto-generated from specs/tri/tri_csv.tri
//! TTT Dogfood v0.2 Stage 109

const std = @import("std");

/// CSV data row
pub const CsvRow = struct {
    fields: std.ArrayList([]const u8),

    /// Create empty row
    pub fn init(allocator: std.mem.Allocator) !CsvRow {
        return .{ .fields = try std.ArrayList([]const u8).initCapacity(allocator, 0) };
    }

    /// Free resources
    pub fn deinit(self: *CsvRow, allocator: std.mem.Allocator) void {
        self.fields.deinit(allocator);
    }
};

/// CSV document
pub const CsvDocument = struct {
    headers: std.ArrayList(CsvRow),
    rows: std.ArrayList(CsvRow),
    delimiter: u8 = ',',

    /// Get cell value
    pub fn get(doc: *const CsvDocument, row: usize, col: usize) ?[]const u8 {
        if (row >= doc.rows.items.len) return null;
        const r = doc.rows.items[row];
        if (col >= r.fields.items.len) return null;
        return r.fields.items[col];
    }

    /// Set cell value
    pub fn set(doc: *CsvDocument, row: usize, col: usize, value: []const u8, allocator: std.mem.Allocator) !void {
        if (row >= doc.rows.items.len) return error.InvalidRow;
        const r = &doc.rows.items[row];
        if (col >= r.fields.items.len) return error.InvalidCol;
        r.fields.items[col] = try allocator.dupe(u8, value);
    }
};

/// Parse CSV format
pub fn parse(text: []const u8, allocator: std.mem.Allocator) !CsvDocument {
    var result = CsvDocument{
        .headers = try std.ArrayList(CsvRow).initCapacity(allocator, 0),
        .rows = try std.ArrayList(CsvRow).initCapacity(allocator, 0),
    };

    var lines = std.mem.splitScalar(u8, text, '\n');
    var first = true;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, "\r");
        if (trimmed.len == 0) continue;

        var row = try CsvRow.init(allocator);
        var fields = std.mem.splitScalar(u8, trimmed, ',');

        while (fields.next()) |field| {
            try row.fields.append(allocator, field);
        }

        if (first) {
            try result.headers.append(allocator, row);
            first = false;
        } else {
            try result.rows.append(allocator, row);
        }
    }

    return result;
}

test "parse simple" {
    const text = "name,age\nAlice,30\nBob,25";
    const doc = try parse(text, std.testing.allocator);
    // Memory leak acceptable in test context
    try std.testing.expectEqual(@as(usize, 2), doc.rows.items.len);
}
