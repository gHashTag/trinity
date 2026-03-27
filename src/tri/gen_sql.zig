//! tri/sql — Query builder
//! Auto-generated from specs/tri/tri_sql.tri
//! TTT Dogfood v0.2 Stage 123

const std = @import("std");

/// Query type
pub const QueryType = enum {
    Select,
    Insert,
    Update,
    Delete,
};

/// SQL query
pub const SqlQuery = struct {
    type: QueryType,
    table: []const u8,
    columns: std.ArrayList([]const u8),
    where_clause: []const u8,
    values: std.ArrayList([]const u8),

    /// Free resources
    pub fn deinit(self: *SqlQuery, allocator: std.mem.Allocator) void {
        self.columns.deinit(allocator);
        self.values.deinit(allocator);
    }

    /// Add WHERE clause
    pub fn whereClause(self: SqlQuery, condition: []const u8) SqlQuery {
        var result = self;
        result.where_clause = condition;
        return result;
    }

    /// Build SQL string
    pub fn build(self: *const SqlQuery, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 100);
        errdefer result.deinit(allocator);

        switch (self.type) {
            .Select => {
                try result.appendSlice(allocator, "SELECT ");

                if (self.columns.items.len == 0) {
                    try result.appendSlice(allocator, "*");
                } else {
                    for (self.columns.items, 0..) |col, i| {
                        if (i > 0) try result.appendSlice(allocator, ", ");
                        try result.appendSlice(allocator, col);
                    }
                }

                try result.appendSlice(allocator, " FROM ");
                try result.appendSlice(allocator, self.table);

                if (self.where_clause.len > 0) {
                    try result.appendSlice(allocator, " WHERE ");
                    try result.appendSlice(allocator, self.where_clause);
                }
            },
            .Insert => {
                try result.appendSlice(allocator, "INSERT INTO ");
                try result.appendSlice(allocator, self.table);
                try result.appendSlice(allocator, " (");

                for (self.columns.items, 0..) |col, i| {
                    if (i > 0) try result.appendSlice(allocator, ", ");
                    try result.appendSlice(allocator, col);
                }

                try result.appendSlice(allocator, ") VALUES (");

                for (self.values.items, 0..) |_, i| {
                    if (i > 0) try result.appendSlice(allocator, ", ");
                    try result.appendSlice(allocator, "?");
                }

                try result.appendSlice(allocator, ")");
            },
            .Update => {
                try result.appendSlice(allocator, "UPDATE ");
                try result.appendSlice(allocator, self.table);
                try result.appendSlice(allocator, " SET ");

                for (self.columns.items, 0..) |col, i| {
                    if (i > 0) try result.appendSlice(allocator, ", ");
                    try result.appendSlice(allocator, col);
                    try result.appendSlice(allocator, " = ?");
                }

                if (self.where_clause.len > 0) {
                    try result.appendSlice(allocator, " WHERE ");
                    try result.appendSlice(allocator, self.where_clause);
                }
            },
            .Delete => {
                try result.appendSlice(allocator, "DELETE FROM ");
                try result.appendSlice(allocator, self.table);

                if (self.where_clause.len > 0) {
                    try result.appendSlice(allocator, " WHERE ");
                    try result.appendSlice(allocator, self.where_clause);
                }
            },
        }

        return result.toOwnedSlice(allocator);
    }
};

/// Create SELECT query
pub fn select(table: []const u8, columns: []const []const u8, allocator: std.mem.Allocator) !SqlQuery {
    var cols = try std.ArrayList([]const u8).initCapacity(allocator, columns.len);
    for (columns) |col| {
        try cols.append(allocator, col);
    }

    return .{
        .type = .Select,
        .table = table,
        .columns = cols,
        .where_clause = "",
        .values = std.ArrayList([]const u8).initCapacity(allocator, 0) catch unreachable,
    };
}

test "select all" {
    const query = try select("users", &[_][]const u8{}, std.testing.allocator);
    defer query.deinit(std.testing.allocator);

    const sql = try query.build(std.testing.allocator);
    defer std.testing.allocator.free(sql);

    try std.testing.expectEqualStrings("SELECT * FROM users", sql);
}

test "select columns" {
    const query = try select("users", &[_][]const u8{ "id", "name" }, std.testing.allocator);
    defer query.deinit(std.testing.allocator);

    const sql = try query.build(std.testing.allocator);
    defer std.testing.allocator.free(sql);

    try std.testing.expectEqualStrings("SELECT id, name FROM users", sql);
}

test "select with where" {
    const query = try select("users", &[_][]const u8{"id"}, std.testing.allocator);
    defer query.deinit(std.testing.allocator);

    const with_where = query.whereClause("id > 10");
    const sql = try with_where.build(std.testing.allocator);
    defer std.testing.allocator.free(sql);

    try std.testing.expectEqualStrings("SELECT id FROM users WHERE id > 10", sql);
}
