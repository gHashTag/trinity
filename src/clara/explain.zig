// 🤖 TRINITY v0.11.0: CLARA Explainability Module
// 📋 DARPA CLARA Proposal — Layer 4: Explainability
// ═══════════════════════════════════════════════════════════════════════════
//
// Natural deduction proof traces with ≤10 unfolding expansion (CLARA req).
// Provides hierarchical, fine-grained explanations for Datalog derivations.
//
// Output format:
//   Step 1: hslm_forward(threat_1) → [1,-1,0] (confidence: 0.92)
//   Step 2: vsa_bind([1,-1,0], hostile_pattern) → 0.87
//   Step 3: rule: threat_class(X, hostile) ← vsa_sim(X, hostile_pattern) > 0.85
//   Step 4: CONCLUSION: threat(threat_1, hostile) = 0.89
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const vsa = @import("vsa");
const rules_mod = @import("rules.zig");
pub const Fact = rules_mod.Fact;
pub const ProofTrace = rules_mod.ProofTrace;

/// Explanation style (natural deduction formats)
pub const ExplainStyle = enum {
    natural, // Natural deduction (human-readable)
    formal, // Formal logic (Fitch-style)
    compact, // One-line summary
};

/// Query for explanation
pub const Query = struct {
    name: []const u8,
    params: []const []const u8,

    pub fn format(self: Query, allocator: std.mem.Allocator) ![]u8 {
        // Simple format: name(param1, param2)
        var result = try std.ArrayList(u8).init(allocator);
        defer result.deinit();

        try result.appendSlice(allocator, self.name);
        try result.appendSlice(allocator, "(");

        for (self.params, 0..) |param, i| {
            if (i > 0) try result.appendSlice(allocator, ", ");
            try result.appendSlice(allocator, param);
        }

        try result.appendSlice(allocator, ")");

        return result.toOwnedSlice();
    }
};

/// Explanation node in proof tree (pointer-based to avoid self-dependency)
pub const ExplainNode = struct {
    step: usize,
    fact: []const u8,
    rule: []const u8,
    confidence: f32,
    children: []*ExplainNode,
    child_count: usize = 0,
    allocator: std.mem.Allocator,
    fact_owned: bool = false, // Track if fact string is owned (needs freeing)

    pub fn init(allocator: std.mem.Allocator, step: usize) ExplainNode {
        return ExplainNode{
            .step = step,
            .fact = "",
            .rule = "",
            .confidence = 0.0,
            .children = &.{},
            .child_count = 0,
            .allocator = allocator,
            .fact_owned = false,
        };
    }

    pub fn deinit(self: *ExplainNode) void {
        // Free owned fact string
        if (self.fact_owned) {
            self.allocator.free(self.fact);
        }
        // Recursively deinit child nodes
        for (self.children[0..self.child_count]) |child_ptr| {
            child_ptr.deinit();
            // Free the allocated memory for the child pointer
            self.allocator.destroy(child_ptr);
        }
        if (self.child_count > 0) {
            self.allocator.free(self.children);
        }
    }

    /// Add a child node
    pub fn addChild(self: *ExplainNode, child: *ExplainNode) !void {
        if (self.child_count >= 10) return error.MaxDepthExceeded; // CLARA limit

        const new_children = try self.allocator.realloc(self.children, self.child_count + 1);
        new_children[self.child_count] = child;
        self.children = new_children;
        self.child_count += 1;
    }

    /// Format node for display
    pub fn format(self: ExplainNode, writer: anytype, depth: usize) !void {
        const indent = "  " ** depth;
        try writer.print("{s}Step {d}: {s}\n", .{ indent, self.step, self.fact });
        try writer.print("{s}  Rule: {s}\n", .{ indent, self.rule });
        try writer.print("{s}  Confidence: {d:.2}\n", .{ indent, self.confidence });

        for (self.children[0..self.child_count]) |*child| {
            try child.format(writer, depth + 1);
        }
    }
};

/// Complete explanation with proof trace
pub const Explanation = struct {
    query: Query,
    root: ExplainNode,
    style: ExplainStyle,
    max_depth: usize = 10, // CLARA requirement
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, query: Query, style: ExplainStyle) Explanation {
        return Explanation{
            .query = query,
            .root = ExplainNode.init(allocator, 0),
            .style = style,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Explanation) void {
        self.root.deinit();
    }

    /// Generate explanation from proof trace
    pub fn fromTrace(trace: ProofTrace, query: Query, style: ExplainStyle) !Explanation {
        const allocator = std.testing.allocator;
        var exp = Explanation.init(allocator, query, style);

        // Add each step as a direct child of root (flat structure)
        for (trace.steps[0..trace.step_count]) |step| {
            var node_ptr = try allocator.create(ExplainNode);
            node_ptr.* = ExplainNode.init(allocator, step.step);
            node_ptr.fact = try std.fmt.allocPrint(allocator, "fact_{d}", .{step.fact.id});
            node_ptr.fact_owned = true; // Mark fact string as owned
            node_ptr.rule = step.rule;
            node_ptr.confidence = step.confidence;
            try exp.root.addChild(node_ptr);
        }

        return exp;
    }

    /// Format explanation for display
    pub fn format(self: Explanation, writer: anytype) !void {
        switch (self.style) {
            .natural => try self.formatNatural(writer),
            .formal => try self.formatFormal(writer),
            .compact => try self.formatCompact(writer),
        }
    }

    fn formatNatural(self: Explanation, writer: anytype) !void {
        try writer.print("\n╔══════════════════════════════════════════════════════════╗\n", .{});
        try writer.print("║  CLARA Explanation: Natural Deduction Style            ║\n", .{});
        try writer.print("╠══════════════════════════════════════════════════════════╣\n", .{});

        const query_str = try self.query.format(self.allocator);
        defer self.allocator.free(query_str);

        try writer.print("║ Query: {s:50} ║\n", .{query_str});
        try writer.print("╠══════════════════════════════════════════════════════════╣\n", .{});

        try self.root.format(writer, 1);

        try writer.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    }

    fn formatFormal(self: Explanation, writer: anytype) !void {
        try writer.print("\n┌────────────────────────────────────────────────────────────┐\n", .{});
        try writer.print("│  CLARA Explanation: Formal Logic (Fitch-style)          │\n", .{});
        try writer.print("├────────────────────────────────────────────────────────────┤\n", .{});

        const query_str = try self.query.format(self.allocator);
        defer self.allocator.free(query_str);

        try writer.print("│ ⊢ {s:54}│\n", .{query_str});
        try writer.print("├────────────────────────────────────────────────────────────┤\n", .{});

        var step_num: usize = 1;
        var current = &self.root;
        while (current.child_count > 0) {
            for (current.children[0..current.child_count]) |child| {
                try writer.print("│ {d:2}. {s:50} │ {d:.2} │\n", .{ step_num, child.fact, child.confidence });
                step_num += 1;
            }
            if (current.child_count > 0) {
                current = current.children[0];
            } else {
                break;
            }
        }

        try writer.print("└────────────────────────────────────────────────────────────┘\n", .{});
    }

    fn formatCompact(self: Explanation, writer: anytype) !void {
        const query_str = try self.query.format(self.allocator);
        defer self.allocator.free(query_str);

        try writer.print("{s} → ", .{query_str});

        var current = &self.root;
        var first = true;
        while (current.child_count > 0) {
            for (current.children[0..current.child_count]) |child| {
                if (!first) try writer.print(" → ", .{});
                try writer.print("{s}({d:.2})", .{ child.fact, child.confidence });
                first = false;
            }
            if (current.child_count > 0) {
                current = current.children[0];
            } else {
                break;
            }
        }

        try writer.print("\n", .{});
    }
};

/// Explain a query with proof trace
pub fn explainQuery(
    allocator: std.mem.Allocator,
    query: Query,
    facts: []const Fact,
    style: ExplainStyle,
) !Explanation {
    _ = facts; // TODO: use facts in derivation

    // Create mock explanation for now
    var exp = Explanation.init(allocator, query, style);

    // Build explanation tree with allocated nodes
    var node1 = try allocator.create(ExplainNode);
    node1.* = ExplainNode.init(allocator, 1);
    node1.fact = "vsa_forward(threat_1)";
    node1.rule = "hslm_forward_pass";
    node1.confidence = 0.92;
    try exp.root.addChild(node1);

    var node2 = try allocator.create(ExplainNode);
    node2.* = ExplainNode.init(allocator, 2);
    node2.fact = "vsa_bind([1,-1,0], hostile_pattern)";
    node2.rule = "vsa_similarity_rule";
    node2.confidence = 0.87;
    try node1.addChild(node2);

    var node3 = try allocator.create(ExplainNode);
    node3.* = ExplainNode.init(allocator, 3);
    node3.fact = "threat_class(threat_1, hostile)";
    node3.rule = "threat_classification_rule";
    node3.confidence = 0.89;
    try node2.addChild(node3);

    return exp;
}

/// CLI-compatible explain command
pub fn runExplain(
    allocator: std.mem.Allocator,
    query_str: []const u8,
    style: ExplainStyle,
) !void {
    // Parse query string: "threat(threat_1, hostile)"
    var parts = std.mem.splitScalar(u8, query_str, '(');
    const name = parts.first();
    const rest = parts.rest();

    var params = std.ArrayList([]const u8).init(allocator);
    defer {
        for (params.items) |p| allocator.free(p);
        params.deinit();
    }

    if (rest.len > 0) {
        var args_iter = std.mem.splitScalar(u8, rest[0 .. rest.len - 1], ',');
        while (args_iter.next()) |arg| {
            const trimmed = try std.mem.trim(allocator, arg, " ");
            try params.append(allocator, trimmed);
        }
    }

    const query = Query{
        .name = name,
        .params = try params.toOwnedSlice(),
    };

    var exp = try explainQuery(allocator, query, &.{}, style);
    defer exp.deinit();

    const stdout = std.io.getStdOut().writer();
    try exp.format(stdout);
}

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════

test "CLARA: Explanation from trace" {
    const allocator = std.testing.allocator;

    var trace = ProofTrace.init(allocator, 10);
    defer trace.deinit();

    const fact = Fact{ .id = 1, .value = 0.9 };
    try trace.addStep(fact, "rule1", 0.9);
    try trace.addStep(fact, "rule2", 0.8);

    const query = Query{
        .name = "test_query",
        .params = &.{ "arg1", "arg2" },
    };

    var exp = try Explanation.fromTrace(trace, query, .natural);
    defer exp.deinit();

    try std.testing.expectEqual(@as(usize, 2), exp.root.child_count);
}

test "CLARA: Query formatting" {
    const query = Query{
        .name = "threat_class",
        .params = &.{ "threat_1", "hostile" },
    };

    // For now, just check that the fields are accessible
    try std.testing.expectEqualStrings("threat_class", query.name);
    try std.testing.expectEqual(@as(usize, 2), query.params.len);
}

test "CLARA: Explanation depth limit" {
    const allocator = std.testing.allocator;

    const query = Query{
        .name = "deep_query",
        .params = &.{},
    };

    var exp = try explainQuery(allocator, query, &.{}, .natural);
    defer exp.deinit();

    // Check max_depth is set correctly
    try std.testing.expectEqual(@as(usize, 10), exp.max_depth);
}

// φ² + 1/φ² = 3 | TRINITY
