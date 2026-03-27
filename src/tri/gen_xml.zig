//! tri/xml — XML markup format
//! Auto-generated from specs/tri/tri_xml.tri
//! TTT Dogfood v0.2 Stage 115

const std = @import("std");

/// XML node
pub const XmlNode = struct {
    tag: []const u8,
    attributes: std.StringHashMap([]const u8),
    children: std.ArrayList(XmlNode),
    text: []const u8,

    /// Free resources
    pub fn deinit(self: XmlNode, allocator: std.mem.Allocator) void {
        @constCast(&self.attributes).deinit();
        for (self.children.items) |*child| {
            child.deinit(allocator);
        }
        @constCast(&self.children).deinit(allocator);
    }

    /// Add child node
    pub fn addChild(self: *XmlNode, child: XmlNode, allocator: std.mem.Allocator) !void {
        try self.children.append(allocator, child);
    }
};

/// Parse XML document (simplified parser)
pub fn parse(text: []const u8, allocator: std.mem.Allocator) !XmlNode {
    var root = XmlNode{
        .tag = "",
        .attributes = std.StringHashMap([]const u8).init(allocator),
        .children = std.ArrayList(XmlNode).initCapacity(allocator, 0) catch unreachable,
        .text = "",
    };
    errdefer {
        root.attributes.deinit();
        for (root.children.items) |*child| {
            child.deinit(allocator);
        }
        root.children.deinit(allocator);
    }

    var i: usize = 0;
    var current: *XmlNode = &root;

    while (i < text.len) {
        // Find opening tag
        const tag_start = std.mem.indexOfScalarPos(u8, text, i, '<') orelse break;
        const tag_end = std.mem.indexOfScalarPos(u8, text, tag_start, '>') orelse return error.MalformedXml;

        // Get tag name
        const tag_content = text[tag_start + 1 .. tag_end];
        const is_closing = tag_content[0] == '/';
        const tag_name = if (is_closing) tag_content[1..] else tag_content;

        // Parse attributes (simplified - no quoted strings support)
        var tag = std.mem.splitScalar(u8, tag_name, ' ');
        const name = tag.first();

        if (!is_closing) {
            // Check for self-closing tag
            const self_closing = tag_content[tag_content.len - 1] == '/';

            var node = XmlNode{
                .tag = try allocator.dupe(u8, name),
                .attributes = std.StringHashMap([]const u8).init(allocator),
                .children = std.ArrayList(XmlNode).initCapacity(allocator, 0) catch unreachable,
                .text = "",
            };
            errdefer node.deinit(allocator);

            // Parse attributes
            var attr_iter = std.mem.splitScalar(u8, tag_content, ' ');
            _ = attr_iter.next(); // Skip tag name
            while (attr_iter.next()) |attr| {
                if (attr.len == 0) continue;
                if (std.mem.indexOfScalar(u8, attr, '=')) |eq_idx| {
                    const key = attr[0..eq_idx];
                    const value = if (eq_idx + 1 < attr.len) attr[eq_idx + 1 ..] else "";
                    try node.attributes.put(key, value);
                }
            }

            if (current.tag.len == 0) {
                // Set as root
                current.tag = node.tag;
                current.attributes = node.attributes;
                current.children = node.children;
                current.text = node.text;
            } else {
                try current.addChild(node, allocator);
                if (!self_closing) {
                    current = &current.children.items[current.children.items.len - 1];
                }
            }
        } else {
            // Closing tag - move up
            current = &root; // Simplified - just go to root
        }

        i = tag_end + 1;

        // Extract text content
        const next_tag = std.mem.indexOfScalarPos(u8, text, i, '<') orelse text.len;
        if (next_tag > i) {
            const text_content = std.mem.trim(u8, text[i..next_tag], " \t\r\n");
            if (text_content.len > 0) {
                current.text = try allocator.dupe(u8, text_content);
            }
        }
    }

    return root;
}

/// Serialize to XML
pub fn format(node: XmlNode, allocator: std.mem.Allocator) ![]u8 {
    var result = std.ArrayList(u8).initCapacity(allocator, 0) catch unreachable;
    errdefer result.deinit(allocator);

    try result.appendSlice(allocator, "<");
    try result.appendSlice(allocator, node.tag);

    // Write attributes
    var attr_iter = node.attributes.iterator();
    while (attr_iter.next()) |entry| {
        try result.appendSlice(allocator, " ");
        try result.appendSlice(allocator, entry.key_ptr.*);
        try result.appendSlice(allocator, "=\"");
        try result.appendSlice(allocator, entry.value_ptr.*);
        try result.appendSlice(allocator, "\"");
    }

    if (node.children.items.len == 0 and node.text.len == 0) {
        try result.appendSlice(allocator, "/>");
        return result.toOwnedSlice(allocator);
    }

    try result.appendSlice(allocator, ">");

    // Write text content
    if (node.text.len > 0) {
        try result.appendSlice(allocator, node.text);
    }

    // Write children
    for (node.children.items) |child| {
        const child_xml = try format(child, allocator);
        defer allocator.free(child_xml);
        try result.appendSlice(allocator, child_xml);
    }

    try result.appendSlice(allocator, "</");
    try result.appendSlice(allocator, node.tag);
    try result.appendSlice(allocator, ">");

    return result.toOwnedSlice(allocator);
}

test "parse simple xml" {
    const xml = "<root>hello</root>";
    const node = try parse(xml, std.testing.allocator);
    defer node.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("root", node.tag);
    try std.testing.expectEqualStrings("hello", node.text);
}

test "parse xml with attributes" {
    const xml = "<root id=\"1\" name=\"test\">content</root>";
    const node = try parse(xml, std.testing.allocator);
    defer node.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("root", node.tag);
    const id = node.attributes.get("id");
    try std.testing.expect(id != null);
    try std.testing.expectEqualStrings("1", id.?);
}

test "format xml" {
    var node = XmlNode{
        .tag = "root",
        .attributes = std.StringHashMap([]const u8).init(std.testing.allocator),
        .children = std.ArrayList(XmlNode).initCapacity(std.testing.allocator, 0) catch unreachable,
        .text = "hello",
    };
    defer node.deinit(std.testing.allocator);

    const formatted = try format(node, std.testing.allocator);
    defer std.testing.allocator.free(formatted);

    try std.testing.expectEqualStrings("<root>hello</root>", formatted);
}
