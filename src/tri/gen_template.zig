//! tri/template — Text templating
//! Auto-generated from specs/tri/tri_template.tri
//! TTT Dogfood v0.2 Stage 124

const std = @import("std");

/// Template part
pub const TemplatePart = struct {
    is_literal: bool,
    text: []const u8,
    variable: []const u8,
};

/// Compiled template
pub const Template = struct {
    parts: std.ArrayList(TemplatePart),

    /// Free resources
    pub fn deinit(self: *Template, allocator: std.mem.Allocator) void {
        self.parts.deinit(allocator);
    }

    /// Render template with context
    pub fn render(self: *const Template, context: std.StringHashMap([]const u8), allocator: std.mem.Allocator) ![]u8 {
        var result = std.ArrayList(u8).initCapacity(allocator, 100) catch unreachable;
        errdefer result.deinit(allocator);

        for (self.parts.items) |part| {
            if (part.is_literal) {
                try result.appendSlice(allocator, part.text);
            } else {
                const value = context.get(part.variable);
                if (value) |v| {
                    try result.appendSlice(allocator, v);
                }
            }
        }

        return result.toOwnedSlice(allocator);
    }
};

/// Compile template
pub fn compile(source: []const u8, allocator: std.mem.Allocator) !Template {
    var parts = try std.ArrayList(TemplatePart).initCapacity(allocator, 10);
    errdefer parts.deinit(allocator);

    var i: usize = 0;
    while (i < source.len) {
        const open_brace = std.mem.indexOfScalarPos(u8, source, i, '{') orelse {
            // No more braces, rest is literal
            try parts.append(allocator, .{
                .is_literal = true,
                .text = try allocator.dupe(u8, source[i..]),
                .variable = "",
            });
            break;
        };

        if (open_brace + 1 < source.len and source[open_brace + 1] == '{') {
            // Found opening {{
            if (open_brace > i) {
                // Add literal before braces
                try parts.append(allocator, .{
                    .is_literal = true,
                    .text = try allocator.dupe(u8, source[i..open_brace]),
                    .variable = "",
                });
            }

            const close_brace = std.mem.indexOfScalarPos(u8, source, open_brace, '}') orelse return error.UnterminatedVariable;
            if (close_brace + 1 >= source.len or source[close_brace + 1] != '}') return error.UnterminatedVariable;

            // Add variable
            const var_name = std.mem.trim(u8, source[open_brace + 2 .. close_brace], " ");
            try parts.append(allocator, .{
                .is_literal = false,
                .text = "",
                .variable = try allocator.dupe(u8, var_name),
            });

            i = close_brace + 2;
        } else {
            // Single brace, treat as literal
            i = open_brace + 1;
        }
    }

    return .{ .parts = parts };
}

test "compile literal only" {
    const tmpl = try compile("Hello, World!", std.testing.allocator);
    defer tmpl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), tmpl.parts.items.len);
    try std.testing.expect(tmpl.parts.items[0].is_literal);
}

test "compile with variable" {
    const tmpl = try compile("Hello, {{name}}!", std.testing.allocator);
    defer tmpl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), tmpl.parts.items.len);
    try std.testing.expect(tmpl.parts.items[0].is_literal);
    try std.testing.expect(!tmpl.parts.items[1].is_literal);
    try std.testing.expectEqualStrings("name", tmpl.parts.items[1].variable);
}

test "render template" {
    const tmpl = try compile("Hello, {{name}}!", std.testing.allocator);
    defer tmpl.deinit(std.testing.allocator);

    var context = std.StringHashMap([]const u8).init(std.testing.allocator);
    try context.put("name", "World");

    const result = try tmpl.render(context, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("Hello, World!", result);
}

test "render missing variable" {
    const tmpl = try compile("Hello, {{name}}!", std.testing.allocator);
    defer tmpl.deinit(std.testing.allocator);

    var context = std.StringHashMap([]const u8).init(std.testing.allocator);

    const result = try tmpl.render(context, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("Hello, !", result);
}
