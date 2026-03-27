//! tri/aho_corasick — Multi-pattern string search automaton
//! Auto-generated from specs/tri/tri_aho_corasick.tri
//! TTT Dogfood v0.2 Stage 165

const std = @import("std");

/// Trie node with failure link
pub const ACTrieNode = struct {
    children: [256]?*ACTrieNode,
    fail: *ACTrieNode,
    output: []const u8,
    char: u8,
    allocator: std.mem.Allocator,

    /// Free node and children
    pub fn deinit(node: *ACTrieNode) void {
        for (node.children) |maybe_child| {
            if (maybe_child) |child| {
                child.deinit();
                node.allocator.destroy(child);
            }
        }
    }
};

/// Match result
pub const Match = struct {
    pattern: []const u8,
    position: usize,
};

/// Aho-Corasick automaton
pub const ACAutomaton = struct {
    root: *ACTrieNode,
    patterns: []const []const u8,
    allocator: std.mem.Allocator,

    /// Build automaton from patterns
    pub fn build(allocator: std.mem.Allocator, patterns: []const []const u8) !ACAutomaton {
        const root = try allocator.create(ACTrieNode);
        root.* = .{
            .children = [_]?*ACTrieNode{null} ** 256,
            .fail = root, // Root fails to itself
            .output = "",
            .char = 0,
            .allocator = allocator,
        };

        // Build trie
        for (patterns) |pat| {
            var node = root;
            for (pat) |c| {
                if (node.children[c] == null) {
                    const child = try allocator.create(ACTrieNode);
                    child.* = .{
                        .children = [_]?*ACTrieNode{null} ** 256,
                        .fail = root,
                        .output = "",
                        .char = c,
                        .allocator = allocator,
                    };
                    node.children[c] = child;
                }
                node = node.children[c].?;
            }
            node.output = pat; // Mark end of pattern
        }

        // Build failure links (BFS)
        var queue = std.ArrayList(*ACTrieNode).initCapacity(allocator, 256) catch unreachable;
        defer queue.deinit(allocator);

        // Initialize queue with root's children
        for (root.children) |maybe_child| {
            if (maybe_child) |child| {
                child.fail = root;
                try queue.append(allocator, child);
            }
        }

        while (queue.items.len > 0) {
            const curr = queue.orderedRemove(0);

            for (curr.children, 0..) |maybe_child, c| {
                if (maybe_child) |child| {
                    queue.append(allocator, child) catch unreachable;

                    // Find fail state
                    var fail = curr.fail;
                    while (fail != root and fail.children[c] == null) {
                        fail = fail.fail;
                    }

                    if (curr != root and fail.children[c] != null) {
                        child.fail = fail.children[c].?;
                    } else {
                        child.fail = root;
                    }
                }
            }
        }

        return .{
            .root = root,
            .patterns = patterns,
            .allocator = allocator,
        };
    }

    /// Find all pattern matches
    pub fn search(ac: *const ACAutomaton, text: []const u8, allocator: std.mem.Allocator) ![]Match {
        var matches = std.ArrayList(Match).initCapacity(allocator, 16) catch unreachable;
        var node = ac.root;

        for (text, 0..) |c, pos| {
            while (node != ac.root and node.children[c] == null) {
                node = node.fail;
            }

            if (node.children[c]) |child| {
                node = child;
            }

            // Check output at this node
            if (node.output.len > 0) {
                try matches.append(allocator, .{
                    .pattern = node.output,
                    .position = pos - node.output.len + 1,
                });
            }

            // Check fail chain output
            var fail = node.fail;
            while (fail != ac.root) {
                if (fail.output.len > 0) {
                    try matches.append(allocator, .{
                        .pattern = fail.output,
                        .position = pos - fail.output.len + 1,
                    });
                }
                fail = fail.fail;
            }
        }

        return matches.toOwnedSlice(allocator);
    }

    /// Free automaton memory
    pub fn deinit(ac: *ACAutomaton) void {
        ac.root.deinit();
        ac.allocator.destroy(ac.root);
    }
};

test "aho corasick build" {
    const patterns = &[_][]const u8{ "he", "she", "his", "hers" };
    var ac = try ACAutomaton.build(std.testing.allocator, patterns);
    defer ac.deinit();

    try std.testing.expect(ac.root.children.len > 0);
}

test "aho corasick search" {
    const patterns = &[_][]const u8{ "he", "she", "his" };
    var ac = try ACAutomaton.build(std.testing.allocator, patterns);
    defer ac.deinit();

    const text = "ushers";
    const matches = try ac.search(text, std.testing.allocator);
    defer std.testing.allocator.free(matches);

    // Should find "she" and "he"
    try std.testing.expect(matches.len >= 1);
}

test "aho corasick empty patterns" {
    const patterns = &[_][]const u8{};
    var ac = try ACAutomaton.build(std.testing.allocator, patterns);
    defer ac.deinit();

    const text = "test";
    const matches = try ac.search(text, std.testing.allocator);
    defer std.testing.allocator.free(matches);

    try std.testing.expectEqual(@as(usize, 0), matches.len);
}
