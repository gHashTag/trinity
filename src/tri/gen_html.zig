//! tri/html — HTML5 web markup
//! Auto-generated from specs/tri/tri_html.tri
//! TTT Dogfood v0.2 Stage 116

const std = @import("std");

/// HTML element node
pub const HtmlNode = struct {
    tag: []const u8,
    attributes: std.StringHashMap([]const u8),
    children: std.ArrayList(HtmlNode),
    inner_text: []const u8,

    /// Free resources
    pub fn deinit(self: HtmlNode, allocator: std.mem.Allocator) void {
        @constCast(&self.attributes).deinit();
        for (self.children.items) |*child| {
            child.deinit(allocator);
        }
        @constCast(&self.children).deinit(allocator);
    }

    /// Add child node
    pub fn addChild(self: *HtmlNode, child: HtmlNode, allocator: std.mem.Allocator) !void {
        try self.children.append(allocator, child);
    }
};

/// Parse HTML document (simplified parser)
pub fn parse(html: []const u8, allocator: std.mem.Allocator) !HtmlNode {
    var root = HtmlNode{
        .tag = "html",
        .attributes = std.StringHashMap([]const u8).init(allocator),
        .children = std.ArrayList(HtmlNode).initCapacity(allocator, 0) catch unreachable,
        .inner_text = "",
    };
    errdefer {
        root.attributes.deinit();
        for (root.children.items) |*child| {
            child.deinit(allocator);
        }
        root.children.deinit(allocator);
    }

    var i: usize = 0;
    var current: *HtmlNode = &root;

    while (i < html.len) {
        // Find opening tag
        const tag_start = std.mem.indexOfScalarPos(u8, html, i, '<') orelse break;
        const tag_end = std.mem.indexOfScalarPos(u8, html, tag_start, '>') orelse return error.MalformedHtml;

        // Get tag name
        const tag_content = html[tag_start + 1 .. tag_end];
        const is_closing = tag_content[0] == '/';
        const is_comment = tag_content[0] == '!';
        const tag_name = if (is_closing) tag_content[1..] else tag_content;

        if (is_comment) {
            i = tag_end + 1;
            continue;
        }

        if (!is_closing) {
            // Parse tag name (ignore attributes for simplicity)
            var tag_iter = std.mem.splitScalar(u8, tag_name, ' ');
            const name = tag_iter.first();

            // Self-closing tags
            const self_closing = std.mem.eql(u8, name, "img") or
                std.mem.eql(u8, name, "br") or
                std.mem.eql(u8, name, "hr") or
                std.mem.eql(u8, name, "input") or
                std.mem.eql(u8, name, "meta") or
                std.mem.eql(u8, name, "link");

            var node = HtmlNode{
                .tag = try allocator.dupe(u8, name),
                .attributes = std.StringHashMap([]const u8).init(allocator),
                .children = std.ArrayList(HtmlNode).initCapacity(allocator, 0) catch unreachable,
                .inner_text = "",
            };
            errdefer node.deinit(allocator);

            if (self_closing or isSelfClosingBySyntax(tag_content)) {
                try current.addChild(node, allocator);
            } else {
                try current.addChild(node, allocator);
                current = &current.children.items[current.children.items.len - 1];
            }
        } else {
            // Closing tag - move up to parent
            // Simplified: just stay at current level for nested structure
        }

        i = tag_end + 1;

        // Extract text content
        const next_tag = std.mem.indexOfScalarPos(u8, html, i, '<') orelse html.len;
        if (next_tag > i) {
            const text_content = std.mem.trim(u8, html[i..next_tag], " \t\r\n");
            if (text_content.len > 0 and current.children.items.len == 0) {
                current.inner_text = try allocator.dupe(u8, text_content);
            }
        }
    }

    return root;
}

/// Check if tag ends with />
fn isSelfClosingBySyntax(tag_content: []const u8) bool {
    return tag_content.len > 0 and tag_content[tag_content.len - 1] == '/';
}

/// Find element by CSS selector (simplified - tag name only)
pub fn querySelector(node: *const HtmlNode, selector: []const u8) ?HtmlNode {
    // Check current node
    if (std.mem.eql(u8, node.tag, selector)) {
        // Return a copy (simplified - shallow copy)
        return node.*;
    }

    // Check children
    for (node.children.items) |*child| {
        if (querySelector(child, selector)) |found| {
            return found;
        }
    }

    return null;
}

test "parse simple html" {
    const html = "<div>hello</div>";
    const node = try parse(html, std.testing.allocator);
    defer node.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("html", node.tag);
    try std.testing.expectEqual(@as(usize, 1), node.children.items.len);
    try std.testing.expectEqualStrings("div", node.children.items[0].tag);
}

test "parse nested html" {
    const html = "<div><p>text</p></div>";
    const node = try parse(html, std.testing.allocator);
    defer node.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("html", node.tag);
    try std.testing.expect(node.children.items.len >= 1);
}

test "query selector" {
    const html = "<div><p>text</p><span>other</span></div>";
    const node = try parse(html, std.testing.allocator);
    defer node.deinit(std.testing.allocator);

    const p_tag = querySelector(&node, "p");
    try std.testing.expect(p_tag != null);
    if (p_tag) |p| {
        try std.testing.expectEqualStrings("p", p.tag);
    }

    const span_tag = querySelector(&node, "span");
    try std.testing.expect(span_tag != null);
}

test "parse self-closing tags" {
    const html = "<div><img src=\"test.jpg\"><br></div>";
    const node = try parse(html, std.testing.allocator);
    defer node.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("html", node.tag);
    try std.testing.expect(node.children.items.len >= 1);
}
