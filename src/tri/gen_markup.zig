//! tri/markup — Lightweight markdown
//! Auto-generated from specs/tri/tri_markup.tri
//! TTT Dogfood v0.2 Stage 126

const std = @import("std");

/// Markdown AST node
pub const MarkdownNode = struct {
    type: []const u8,
    content: []const u8,
    children: std.ArrayList(MarkdownNode),

    /// Free resources
    pub fn deinit(self: *MarkdownNode, allocator: std.mem.Allocator) void {
        for (self.children.items) |*child| {
            child.deinit(allocator);
        }
        self.children.deinit(allocator);
    }
};

/// Parse markdown to AST
pub fn parse(markdown: []const u8, allocator: std.mem.Allocator) ![]MarkdownNode {
    var nodes = try std.ArrayList(MarkdownNode).initCapacity(allocator, 10);
    errdefer {
        for (nodes.items) |*node| {
            node.deinit(allocator);
        }
        nodes.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, markdown, '\n');

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \r");
        if (trimmed.len == 0) continue;

        if (trimmed[0] == '#') {
            // Header
            const level = std.mem.indexOfNone(u8, trimmed, "#").?;
            const content = std.mem.trim(u8, trimmed[level..], " ");
            try nodes.append(allocator, .{
                .type = "h",
                .content = try allocator.dupe(u8, content),
                .children = std.ArrayList(MarkdownNode).initCapacity(allocator, 0) catch unreachable,
            });
        } else if (trimmed[0] == '-' or trimmed[0] == '*') {
            // List item
            const content = std.mem.trim(u8, trimmed[1..], " ");
            try nodes.append(allocator, .{
                .type = "li",
                .content = try allocator.dupe(u8, content),
                .children = std.ArrayList(MarkdownNode).initCapacity(allocator, 0) catch unreachable,
            });
        } else if (std.mem.startsWith(u8, trimmed, "```")) {
            // Code block (simplified - just skip)
        } else {
            // Paragraph
            try nodes.append(allocator, .{
                .type = "p",
                .content = try allocator.dupe(u8, trimmed),
                .children = std.ArrayList(MarkdownNode).initCapacity(allocator, 0) catch unreachable,
            });
        }
    }

    return nodes.toOwnedSlice(allocator);
}

/// Convert markdown AST to HTML
pub fn toHtml(nodes: []MarkdownNode, allocator: std.mem.Allocator) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, 100);
    errdefer result.deinit(allocator);

    for (nodes) |node| {
        try result.appendSlice(allocator, "<");
        try result.appendSlice(allocator, node.type);
        try result.appendSlice(allocator, ">");

        if (node.content.len > 0) {
            try result.appendSlice(allocator, node.content);
        }

        if (node.children.items.len > 0) {
            const children_html = try toHtml(node.children.items, allocator);
            defer allocator.free(children_html);
            try result.appendSlice(allocator, children_html);
        }

        try result.appendSlice(allocator, "</");
        try result.appendSlice(allocator, node.type);
        try result.appendSlice(allocator, ">\n");
    }

    return result.toOwnedSlice(allocator);
}

test "parse header" {
    const markdown = "# Hello";
    const nodes = try parse(markdown, std.testing.allocator);
    defer {
        for (nodes) |*node| {
            node.deinit(std.testing.allocator);
        }
        std.testing.allocator.free(nodes);
    }

    try std.testing.expectEqual(@as(usize, 1), nodes.len);
    try std.testing.expectEqualStrings("h", nodes[0].type);
    try std.testing.expectEqualStrings("Hello", nodes[0].content);
}

test "parse paragraph" {
    const markdown = "This is a paragraph";
    const nodes = try parse(markdown, std.testing.allocator);
    defer {
        for (nodes) |*node| {
            node.deinit(std.testing.allocator);
        }
        std.testing.allocator.free(nodes);
    }

    try std.testing.expectEqual(@as(usize, 1), nodes.len);
    try std.testing.expectEqualStrings("p", nodes[0].type);
}

test "to html" {
    const markdown = "# Title\n\nParagraph text";
    const nodes = try parse(markdown, std.testing.allocator);
    defer {
        for (nodes) |*node| {
            node.deinit(std.testing.allocator);
        }
        std.testing.allocator.free(nodes);
    }

    const html = try toHtml(nodes, std.testing.allocator);
    defer std.testing.allocator.free(html);

    try std.testing.expect(html.len > 0);
}
