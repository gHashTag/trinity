// ═══════════════════════════════════════════════════════════════════════════════
// TREESITTER ANALYZER — AST-based idiomatic Zig analysis (Cycle 78)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Deep AST analysis of generated Zig code using tree-sitter FFI bindings.
// Complements the string-based idiom_analyzer.zig (Cycle 77) with 5 new checks:
//
// 1. Variable shadowing in nested scopes (MEDIUM)
// 2. Scope-aware defer for allocations (MEDIUM)
// 3. Comptime misuse — runtime calls in comptime blocks (HIGH)
// 4. Missing return paths in branching functions (MEDIUM)
// 5. Missing type annotations on variables (LOW)
//
// Requires: -Dtreesitter=true (optional C dependency)
// Graceful: Returns empty report if tree-sitter-zig grammar unavailable
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ts_bridge = @import("ts_bridge.zig");
const idiom_mod = @import("idiom_analyzer.zig");

const Violation = idiom_mod.Violation;
const ViolationKind = idiom_mod.ViolationKind;
const Severity = idiom_mod.Severity;
const Report = idiom_mod.Report;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC ANALYZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const TreeSitterAnalyzer = struct {
    allocator: std.mem.Allocator,
    source: []const u8,

    /// Run all 5 AST-based checks. Returns empty report if tree-sitter unavailable.
    pub fn analyze(self: *TreeSitterAnalyzer) !Report {
        var report = Report{ .allocator = self.allocator };

        if (comptime !ts_bridge.available) {
            return report;
        }

        // Try to create parser — may fail if tree-sitter-zig grammar not installed
        var parser = ts_bridge.zig_parser.createZigParser() catch |err| {
            switch (err) {
                error.LanguageNotFound => {
                    // tree-sitter-zig grammar not installed — graceful fallback
                    return report;
                },
                else => return err,
            }
        };
        defer parser.deinit();

        const tree_ptr = parser.parseString(self.source) catch |err| {
            switch (err) {
                error.ParseFailed => return report,
                else => return err,
            }
        };
        // Wrap raw *c.TSTree into the Tree struct for safe deinit
        var tree = ts_bridge.zig_parser.Tree{ .ptr = tree_ptr };
        defer tree.deinit();

        const root = tree.root();
        if (root.isNull()) return report;

        // Run all 5 AST checks
        try self.checkVariableShadowing(root, &report);
        try self.checkScopeAwareDefer(root, &report);
        try self.checkComptimeMisuse(root, &report);
        try self.checkReturnPaths(root, &report);
        try self.checkTypeAnnotations(root, &report);

        return report;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CHECK 1: Variable Shadowing
    // ═══════════════════════════════════════════════════════════════════════════

    fn checkVariableShadowing(self: *TreeSitterAnalyzer, root: ts_bridge.zig_parser.Node, report: *Report) !void {
        // Track variable names by scope depth using a simple stack
        var scope_names: [64][32]u8 = undefined;
        var scope_name_lens: [64]u8 = [_]u8{0} ** 64;
        var scope_depths: [64]u8 = [_]u8{0} ** 64;
        var scope_count: usize = 0;

        try self.walkForShadowing(root, report, &scope_names, &scope_name_lens, &scope_depths, &scope_count, 0);
    }

    fn walkForShadowing(
        self: *TreeSitterAnalyzer,
        node: ts_bridge.zig_parser.Node,
        report: *Report,
        scope_names: *[64][32]u8,
        scope_name_lens: *[64]u8,
        scope_depths: *[64]u8,
        scope_count: *usize,
        depth: u8,
    ) !void {
        if (node.isNull()) return;

        const node_type = node.getType();

        // Check if this is a variable declaration (var or const)
        const is_var_decl = std.mem.eql(u8, node_type, "variable_declaration") or
            std.mem.eql(u8, node_type, "const_declaration");

        if (is_var_decl) {
            // Extract variable name from first named child
            const name_node = node.namedChild(0);
            if (!name_node.isNull()) {
                const name = name_node.text(self.source);
                if (name.len > 0 and name.len < 32) {
                    // Check if name exists in an outer scope
                    for (0..scope_count.*) |i| {
                        const slen = scope_name_lens.*[i];
                        if (slen == name.len and scope_depths.*[i] < depth) {
                            if (std.mem.eql(u8, scope_names.*[i][0..slen], name)) {
                                const line = node.startPoint().toLineNumber();
                                try report.violations.append(self.allocator, .{
                                    .kind = .variable_shadowing,
                                    .line = line,
                                    .message = "Variable shadows outer scope declaration",
                                    .severity = .medium,
                                });
                                break;
                            }
                        }
                    }

                    // Add to scope tracker
                    if (scope_count.* < 64) {
                        @memcpy(scope_names.*[scope_count.*][0..name.len], name);
                        scope_name_lens.*[scope_count.*] = @intCast(name.len);
                        scope_depths.*[scope_count.*] = depth;
                        scope_count.* += 1;
                    }
                }
            }
        }

        // Recurse into children — blocks increase depth
        const new_depth = if (std.mem.eql(u8, node_type, "block"))
            depth +| 1
        else
            depth;

        const saved_count = scope_count.*;
        var iter = node.iterateChildren();
        while (iter.next()) |child_node| {
            try self.walkForShadowing(child_node, report, scope_names, scope_name_lens, scope_depths, scope_count, new_depth);
        }

        // Pop scope names when leaving a block
        if (std.mem.eql(u8, node_type, "block")) {
            scope_count.* = saved_count;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CHECK 2: Scope-Aware Defer
    // ═══════════════════════════════════════════════════════════════════════════

    fn checkScopeAwareDefer(self: *TreeSitterAnalyzer, root: ts_bridge.zig_parser.Node, report: *Report) !void {
        try self.walkForDefer(root, report);
    }

    fn walkForDefer(self: *TreeSitterAnalyzer, node: ts_bridge.zig_parser.Node, report: *Report) !void {
        if (node.isNull()) return;

        const node_type = node.getType();

        // Look for function bodies (block nodes inside function declarations)
        if (std.mem.eql(u8, node_type, "function_declaration") or
            std.mem.eql(u8, node_type, "fn_decl"))
        {
            // Scan function body for alloc calls without matching defer
            var has_alloc = false;
            var has_defer = false;
            var alloc_line: u32 = 0;

            var iter = node.iterateChildren();
            while (iter.next()) |child_node| {
                if (child_node.isNull()) continue;
                const child_text = child_node.text(self.source);

                // Check for allocation patterns
                if (std.mem.indexOf(u8, child_text, ".alloc(") != null or
                    std.mem.indexOf(u8, child_text, ".create(") != null or
                    std.mem.indexOf(u8, child_text, ".init(") != null)
                {
                    if (!has_alloc) {
                        has_alloc = true;
                        alloc_line = child_node.startPoint().toLineNumber();
                    }
                }

                if (std.mem.indexOf(u8, child_text, "defer ") != null or
                    std.mem.indexOf(u8, child_text, "errdefer ") != null)
                {
                    has_defer = true;
                }
            }

            if (has_alloc and !has_defer) {
                try report.violations.append(self.allocator, .{
                    .kind = .scope_aware_defer,
                    .line = alloc_line,
                    .message = "Allocation without defer/errdefer in same scope",
                    .severity = .medium,
                });
            }
            return; // Don't recurse into children again for function nodes
        }

        // Recurse for non-function nodes
        var iter2 = node.iterateChildren();
        while (iter2.next()) |child_node| {
            try self.walkForDefer(child_node, report);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CHECK 3: Comptime Misuse
    // ═══════════════════════════════════════════════════════════════════════════

    fn checkComptimeMisuse(self: *TreeSitterAnalyzer, root: ts_bridge.zig_parser.Node, report: *Report) !void {
        try self.walkForComptime(root, report, false);
    }

    fn walkForComptime(self: *TreeSitterAnalyzer, node: ts_bridge.zig_parser.Node, report: *Report, in_comptime: bool) !void {
        if (node.isNull()) return;

        const node_type = node.getType();

        const now_comptime = in_comptime or
            std.mem.eql(u8, node_type, "comptime_block") or
            std.mem.eql(u8, node_type, "comptime");

        if (now_comptime and !in_comptime) {
            // Entering comptime block — scan for runtime-only calls
            const block_text = node.text(self.source);

            const runtime_patterns = [_][]const u8{
                "std.debug.print",
                "std.fs.",
                "std.net.",
                "std.os.",
                "allocator.",
                "std.io.",
            };

            for (runtime_patterns) |pattern| {
                if (std.mem.indexOf(u8, block_text, pattern) != null) {
                    try report.violations.append(self.allocator, .{
                        .kind = .comptime_misuse,
                        .line = node.startPoint().toLineNumber(),
                        .message = "Runtime-only call inside comptime block",
                        .severity = .high,
                    });
                    break; // One violation per comptime block
                }
            }
        }

        // Recurse
        var iter = node.iterateChildren();
        while (iter.next()) |child_node| {
            try self.walkForComptime(child_node, report, now_comptime);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CHECK 4: Missing Return Paths
    // ═══════════════════════════════════════════════════════════════════════════

    fn checkReturnPaths(self: *TreeSitterAnalyzer, root: ts_bridge.zig_parser.Node, report: *Report) !void {
        try self.walkForReturnPaths(root, report);
    }

    fn walkForReturnPaths(self: *TreeSitterAnalyzer, node: ts_bridge.zig_parser.Node, report: *Report) !void {
        if (node.isNull()) return;

        const node_type = node.getType();

        if (std.mem.eql(u8, node_type, "function_declaration") or
            std.mem.eql(u8, node_type, "fn_decl"))
        {
            // Check if function has non-void return type
            const fn_text = node.text(self.source);

            // Simple heuristic: has return type annotation that isn't void
            const has_return_type = blk: {
                if (std.mem.indexOf(u8, fn_text, ") void {")) |_| break :blk false;
                if (std.mem.indexOf(u8, fn_text, ") !void {")) |_| break :blk false;
                if (std.mem.indexOf(u8, fn_text, ") void\n")) |_| break :blk false;
                // Check if there's a return type between ) and {
                const close_paren = std.mem.indexOfScalar(u8, fn_text, ')') orelse break :blk false;
                const open_brace = std.mem.indexOfScalarPos(u8, fn_text, close_paren, '{') orelse break :blk false;
                const between = std.mem.trim(u8, fn_text[close_paren + 1 .. open_brace], " \t\n");
                break :blk between.len > 0;
            };

            if (has_return_type) {
                // Check for if/switch without else
                const has_if_without_else = std.mem.indexOf(u8, fn_text, "if (") != null and
                    std.mem.indexOf(u8, fn_text, "} else ") == null and
                    std.mem.indexOf(u8, fn_text, "} else{") == null;

                if (has_if_without_else) {
                    // Check that the function body has a return after the if
                    // This is a heuristic — real analysis would need control flow graph
                    report.total_functions += 1;
                    try report.violations.append(self.allocator, .{
                        .kind = .missing_return_path,
                        .line = node.startPoint().toLineNumber(),
                        .message = "Function with non-void return has if-without-else (possible missing return path)",
                        .severity = .medium,
                    });
                }
            }
        }

        // Recurse
        var iter = node.iterateChildren();
        while (iter.next()) |child_node| {
            try self.walkForReturnPaths(child_node, report);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CHECK 5: Missing Type Annotations
    // ═══════════════════════════════════════════════════════════════════════════

    fn checkTypeAnnotations(self: *TreeSitterAnalyzer, root: ts_bridge.zig_parser.Node, report: *Report) !void {
        try self.walkForTypeAnnotations(root, report, false);
    }

    fn walkForTypeAnnotations(self: *TreeSitterAnalyzer, node: ts_bridge.zig_parser.Node, report: *Report, in_for_or_while: bool) !void {
        if (node.isNull()) return;

        const node_type = node.getType();

        // Skip iterator variables in for/while loops
        const is_loop = std.mem.eql(u8, node_type, "for_expression") or
            std.mem.eql(u8, node_type, "while_expression") or
            std.mem.eql(u8, node_type, "for_statement") or
            std.mem.eql(u8, node_type, "while_statement");

        const is_var_decl = std.mem.eql(u8, node_type, "variable_declaration") or
            std.mem.eql(u8, node_type, "var_decl");

        if (is_var_decl and !in_for_or_while) {
            const decl_text = node.text(self.source);

            // Check if declaration uses `var` (not `const` — const inference is idiomatic)
            if (std.mem.startsWith(u8, std.mem.trimLeft(u8, decl_text, " \t"), "var ")) {
                // Check if there's an explicit type annotation (: Type =)
                if (std.mem.indexOf(u8, decl_text, ": ") == null) {
                    try report.violations.append(self.allocator, .{
                        .kind = .type_annotation_missing,
                        .line = node.startPoint().toLineNumber(),
                        .message = "Variable declaration without explicit type annotation",
                        .severity = .low,
                    });
                }
            }
        }

        // Recurse
        var iter = node.iterateChildren();
        while (iter.next()) |child_node| {
            try self.walkForTypeAnnotations(child_node, report, is_loop or in_for_or_while);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "treesitter_analyzer_creation" {
    // Basic creation test — always works regardless of tree-sitter availability
    var analyzer = TreeSitterAnalyzer{
        .allocator = std.testing.allocator,
        .source = "pub fn test_fn() void {}",
    };
    var report = try analyzer.analyze();
    defer report.deinit();

    // When tree-sitter is unavailable, report should be empty
    if (comptime !ts_bridge.available) {
        try std.testing.expectEqual(@as(usize, 0), report.violations.items.len);
    }
}

test "treesitter_analyzer_empty_source" {
    var analyzer = TreeSitterAnalyzer{
        .allocator = std.testing.allocator,
        .source = "",
    };
    var report = try analyzer.analyze();
    defer report.deinit();
    try std.testing.expectEqual(@as(usize, 0), report.violations.items.len);
}
