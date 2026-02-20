//! Markdown Parser - Parse .ralph/*.md files
//! Supports: fix_plan.md, TECH_TREE.md, SUCCESS_HISTORY.md, REGRESSION_PATTERNS.md

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

// ============================================================================
// Fix Plan Parser
// ============================================================================

/// Parse fix_plan.md into task entries
/// Format:
///   - [ ] Task description (priority: P0)
///     - [ ] Subtask 1
///     - [x] Subtask 2
///   Acceptance criteria:
///   - [ ] Criterion 1
///   - [x] Criterion 2
pub fn parseFixPlan(allocator: Allocator, content: []const u8) ![]types.TaskEntry {
    var tasks = try std.ArrayList(types.TaskEntry).initCapacity(allocator, 0);
    errdefer {
        for (tasks.items) |*t| t.deinit(allocator);
        tasks.deinit(allocator);
    }

    // Global acceptance criteria (apply to all tasks)
    var global_criteria = try std.ArrayList(types.AcceptanceCriterion).initCapacity(allocator, 0);
    errdefer {
        for (global_criteria.items) |*c| c.deinit(allocator);
        global_criteria.deinit(allocator);
    }

    var current_task_subtasks = try std.ArrayList(types.Subtask).initCapacity(allocator, 0);
    errdefer {
        for (current_task_subtasks.items) |*s| s.deinit(allocator);
        current_task_subtasks.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, content, '\n');
    var task_counter: usize = 0;
    var in_criteria_section = false;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // Skip empty lines and comments
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        // Count leading spaces to determine indentation level
        var leading_spaces: usize = 0;
        for (line) |c| {
            if (c == ' ') leading_spaces += 1 else break;
        }

        // Check for acceptance criteria section header
        if (std.mem.indexOf(u8, trimmed, "Acceptance criteria") != null) {
            in_criteria_section = true;
            continue;
        }

        // Acceptance criteria: - [ ] description
        if (in_criteria_section and trimmed.len > 4 and trimmed[0] == '-' and trimmed[2] == '[') {
            const checked = trimmed[3] == 'x' or trimmed[3] == 'X';
            const desc_start = if (trimmed.len > 5) std.mem.indexOfNone(u8, trimmed[5..], &[_]u8{ ' ', '\t' }) orelse 0 else 0;
            const description = std.mem.trim(u8, trimmed[5 + desc_start ..], " \t\r");

            if (description.len > 0) {
                try global_criteria.append(allocator, types.AcceptanceCriterion{
                    .description = try allocator.dupe(u8, description),
                });
            }
            continue;
        }

        // Top level task: - [ ] description (0 or 1 leading space)
        if (leading_spaces <= 1 and trimmed.len > 4 and trimmed[0] == '-' and trimmed[2] == '[') {
            // Save previous task's subtasks
            if (tasks.items.len > 0) {
                const last_task = &tasks.items[tasks.items.len - 1];
                last_task.subtasks = try current_task_subtasks.toOwnedSlice(allocator);
                current_task_subtasks.clearRetainingCapacity();
            }

            const checked = trimmed[3] == 'x' or trimmed[3] == 'X';
            const desc_start = if (trimmed.len > 5) std.mem.indexOfNone(u8, trimmed[5..], &[_]u8{ ' ', '\t' }) orelse 0 else 0;
            var description = std.mem.trim(u8, trimmed[5 + desc_start ..], " \t\r");

            // Extract priority from description (e.g., "(priority: P0)")
            var priority: types.TaskPriority = .p2_medium;
            if (std.mem.indexOf(u8, description, "P0") != null or std.mem.indexOf(u8, description, "critical") != null) {
                priority = .p0_critical;
            } else if (std.mem.indexOf(u8, description, "P1") != null or std.mem.indexOf(u8, description, "high") != null) {
                priority = .p1_high;
            } else if (std.mem.indexOf(u8, description, "P3") != null or std.mem.indexOf(u8, description, "low") != null) {
                priority = .p3_low;
            }

            // Create task ID
            const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{task_counter});
            task_counter += 1;

            // Determine status based on checked state
            const status = if (checked) types.TaskStatus.complete else types.TaskStatus.pending;

            try tasks.append(allocator, types.TaskEntry{
                .id = task_id,
                .description = try allocator.dupe(u8, description),
                .priority = priority,
                .status = status,
                .tech_tree_node = "",
                .subtasks = &.{},
                .blocker_reason = "",
                .acceptance_criteria = &.{}, // Will fill after parsing
            });

            in_criteria_section = false;
        }
        // Subtask: indented - [ ] description (2+ leading spaces)
        else if (leading_spaces >= 2 and trimmed.len > 4 and trimmed[0] == '-' and trimmed[2] == '[') {
            const checked = trimmed[3] == 'x' or trimmed[3] == 'X';
            const desc_start = if (trimmed.len > 5) std.mem.indexOfNone(u8, trimmed[5..], &[_]u8{ ' ', '\t' }) orelse 0 else 0;
            const description = std.mem.trim(u8, trimmed[5 + desc_start ..], " \t\r");

            if (description.len > 0) {
                try current_task_subtasks.append(allocator, types.Subtask{
                    .description = try allocator.dupe(u8, description),
                    .checked = checked,
                });
            }
        }
    }

    // Save last task's subtasks
    if (tasks.items.len > 0) {
        const last_task = &tasks.items[tasks.items.len - 1];
        last_task.subtasks = try current_task_subtasks.toOwnedSlice(allocator);
    }

    // Assign global criteria to all tasks
    const criteria_slice = try global_criteria.toOwnedSlice(allocator);
    defer {
        for (criteria_slice) |*c| c.deinit(allocator);
        allocator.free(criteria_slice);
    }

    for (tasks.items) |*task| {
        task.acceptance_criteria = try allocator.dupe(types.AcceptanceCriterion, criteria_slice);
    }

    return tasks.toOwnedSlice(allocator);
}

// ============================================================================
// Tech Tree Parser
// ============================================================================

/// Parsed tech tree with categorized nodes
pub const TechTree = struct {
    in_progress: []TechTreeNode,
    available: []TechTreeNode,
    completed: []TechTreeNode,
    locked: []TechTreeNode,

    pub fn deinit(self: *TechTree, allocator: Allocator) void {
        for (self.in_progress) |*n| n.deinit(allocator);
        allocator.free(self.in_progress);

        for (self.available) |*n| n.deinit(allocator);
        allocator.free(self.available);

        for (self.completed) |*n| n.deinit(allocator);
        allocator.free(self.completed);

        for (self.locked) |*n| n.deinit(allocator);
        allocator.free(self.locked);
    }
};

/// Tech tree node (extended with parsing metadata)
pub const TechTreeNode = struct {
    id: []const u8,
    name: []const u8,
    branch: types.BranchType,
    impact: f64,
    complexity: f64,
    dependencies: [][]const u8,
    status: types.NodeStatus,

    pub fn deinit(self: *TechTreeNode, allocator: Allocator) void {
        allocator.free(self.id);
        allocator.free(self.name);

        for (self.dependencies) |dep| {
            allocator.free(dep);
        }
        allocator.free(self.dependencies);
    }
};

/// Parse TECH_TREE.md into categorized nodes
/// Format: Markdown tables with sections
pub fn parseTechTree(allocator: Allocator, content: []const u8) !TechTree {
    var in_progress = try std.ArrayList(TechTreeNode).initCapacity(allocator, 0);
    errdefer {
        for (in_progress.items) |*n| n.deinit(allocator);
        in_progress.deinit(allocator);
    }

    var available = try std.ArrayList(TechTreeNode).initCapacity(allocator, 0);
    errdefer {
        for (available.items) |*n| n.deinit(allocator);
        available.deinit(allocator);
    }

    var completed = try std.ArrayList(TechTreeNode).initCapacity(allocator, 0);
    errdefer {
        for (completed.items) |*n| n.deinit(allocator);
        completed.deinit(allocator);
    }

    var locked = try std.ArrayList(TechTreeNode).initCapacity(allocator, 0);
    errdefer {
        for (locked.items) |*n| n.deinit(allocator);
        locked.deinit(allocator);
    }

    var current_section: []const u8 = "";
    var lines = std.mem.splitScalar(u8, content, '\n');

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // Detect section headers
        if (std.mem.startsWith(u8, trimmed, "## In Progress")) {
            current_section = "in_progress";
            continue;
        } else if (std.mem.startsWith(u8, trimmed, "## Available")) {
            current_section = "available";
            continue;
        } else if (std.mem.startsWith(u8, trimmed, "## Completed")) {
            current_section = "completed";
            continue;
        } else if (std.mem.startsWith(u8, trimmed, "## Locked")) {
            current_section = "locked";
            continue;
        }

        // Skip table separators and headers
        if (trimmed.len == 0 or trimmed[0] == '|' and trimmed[1] == '-') continue;
        if (std.mem.indexOf(u8, trimmed, "ID") != null) continue;

        // Parse table rows: | ID | Name | Branch | Impact | Complexity | Dependencies |
        if (trimmed[0] == '|') {
            var cells = std.mem.splitScalar(u8, trimmed[1..], '|');
            var cell_idx: usize = 0;

            var id: []const u8 = "";
            var name: []const u8 = "";
            var branch_str: []const u8 = "";
            var impact: f64 = 5.0;
            var complexity: f64 = 5.0;
            var dependencies_str: []const u8 = "";

            while (cells.next()) |cell| {
                const cell_trimmed = std.mem.trim(u8, cell, " \t\r");
                if (cell_trimmed.len == 0) continue;

                switch (cell_idx) {
                    0 => id = cell_trimmed,
                    1 => name = cell_trimmed,
                    2 => branch_str = cell_trimmed,
                    3 => impact = std.fmt.parseFloat(f64, cell_trimmed) catch 5.0,
                    4 => complexity = std.fmt.parseFloat(f64, cell_trimmed) catch 5.0,
                    5 => dependencies_str = cell_trimmed,
                    else => {},
                }
                cell_idx += 1;
            }

            if (id.len == 0) continue;

            const branch = types.BranchType.fromString(branch_str) catch .core;

            // Parse dependencies
            var deps = try std.ArrayList([]const u8).initCapacity(allocator, 0);
            if (dependencies_str.len > 0 and !std.mem.eql(u8, dependencies_str, "-")) {
                var dep_iter = std.mem.splitScalar(u8, dependencies_str, ',');
                while (dep_iter.next()) |dep| {
                    const dep_trimmed = std.mem.trim(u8, dep, " \t\r");
                    if (dep_trimmed.len > 0) {
                        try deps.append(allocator, try allocator.dupe(u8, dep_trimmed));
                    }
                }
            }

            const node = TechTreeNode{
                .id = try allocator.dupe(u8, id),
                .name = try allocator.dupe(u8, name),
                .branch = branch,
                .impact = impact,
                .complexity = complexity,
                .dependencies = try deps.toOwnedSlice(allocator),
                .status = if (std.mem.eql(u8, current_section, "in_progress"))
                    types.NodeStatus.in_progress
                else if (std.mem.eql(u8, current_section, "available"))
                    types.NodeStatus.available
                else if (std.mem.eql(u8, current_section, "completed"))
                    types.NodeStatus.completed
                else if (std.mem.eql(u8, current_section, "locked"))
                    types.NodeStatus.locked
                else
                    types.NodeStatus.locked,
            };

            if (std.mem.eql(u8, current_section, "in_progress")) {
                try in_progress.append(allocator, node);
            } else if (std.mem.eql(u8, current_section, "available")) {
                try available.append(allocator, node);
            } else if (std.mem.eql(u8, current_section, "completed")) {
                try completed.append(allocator, node);
            } else if (std.mem.eql(u8, current_section, "locked")) {
                try locked.append(allocator, node);
            }
        }
    }

    return TechTree{
        .in_progress = try in_progress.toOwnedSlice(allocator),
        .available = try available.toOwnedSlice(allocator),
        .completed = try completed.toOwnedSlice(allocator),
        .locked = try locked.toOwnedSlice(allocator),
    };
}

// ============================================================================
// Success History Parser
// ============================================================================

pub const SuccessPattern = struct {
    commit_sha: []const u8,
    description: []const u8,
    timestamp: i64,

    pub fn deinit(self: *SuccessPattern, allocator: Allocator) void {
        allocator.free(self.commit_sha);
        allocator.free(self.description);
    }
};

/// Parse SUCCESS_HISTORY.md
/// Format: ## sha + description
pub fn parseSuccessHistory(allocator: Allocator, content: []const u8) ![]SuccessPattern {
    var patterns = try std.ArrayList(SuccessPattern).initCapacity(allocator, 0);
    errdefer {
        for (patterns.items) |*p| p.deinit(allocator);
        patterns.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, content, '\n');

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // Parse ## sha pattern
        if (std.mem.startsWith(u8, trimmed, "## ")) {
            const rest = trimmed[2..];
            var parts = std.mem.splitScalar(u8, rest, ' ');

            const sha = if (parts.next()) |s| std.mem.trim(u8, s, " \t\r") else "";
            const description = if (parts.rest().len > 0)
                std.mem.trim(u8, parts.rest(), " \t\r")
            else
                "";

            if (sha.len > 0) {
                try patterns.append(allocator, SuccessPattern{
                    .commit_sha = try allocator.dupe(u8, sha),
                    .description = try allocator.dupe(u8, description),
                    .timestamp = std.time.timestamp(),
                });
            }
        }
    }

    return patterns.toOwnedSlice(allocator);
}

// ============================================================================
// Regression Patterns Parser
// ============================================================================

pub const RegressionPattern = struct {
    pattern_name: []const u8,
    description: []const u8,
    root_cause: []const u8,
    solution: []const u8,

    pub fn deinit(self: *RegressionPattern, allocator: Allocator) void {
        allocator.free(self.pattern_name);
        allocator.free(self.description);
        allocator.free(self.root_cause);
        allocator.free(self.solution);
    }
};

/// Parse REGRESSION_PATTERNS.md
/// Format:
///   ## Pattern Name
///   **Description:** ...
///   **Root Cause:** ...
///   **Solution:** ...
pub fn parseRegressionPatterns(allocator: Allocator, content: []const u8) ![]RegressionPattern {
    var patterns = try std.ArrayList(RegressionPattern).initCapacity(allocator, 0);
    errdefer {
        for (patterns.items) |*p| p.deinit(allocator);
        patterns.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, content, '\n');
    var current_pattern: ?RegressionPattern = null;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // New pattern starts with ##
        if (std.mem.startsWith(u8, trimmed, "## ")) {
            // Save previous pattern
            if (current_pattern) |p| {
                try patterns.append(allocator, p);
            }

            const name = trimmed[2..];
            current_pattern = RegressionPattern{
                .pattern_name = try allocator.dupe(u8, name),
                .description = &.{},
                .root_cause = &.{},
                .solution = &.{},
            };
        }
        // Parse fields
        else if (current_pattern != null) {
            var p = &current_pattern.?;

            if (std.mem.indexOf(u8, trimmed, "**Description:**") != null) {
                const desc_start = std.mem.indexOf(u8, trimmed, ":") orelse 0;
                const desc = trimmed[desc_start + 1 ..];
                p.description = try allocator.dupe(u8, std.mem.trim(u8, desc, " \t\r"));
            } else if (std.mem.indexOf(u8, trimmed, "**Root Cause:**") != null) {
                const cause_start = std.mem.indexOf(u8, trimmed, ":") orelse 0;
                const cause = trimmed[cause_start + 1 ..];
                p.root_cause = try allocator.dupe(u8, std.mem.trim(u8, cause, " \t\r"));
            } else if (std.mem.indexOf(u8, trimmed, "**Solution:**") != null) {
                const sol_start = std.mem.indexOf(u8, trimmed, ":") orelse 0;
                const sol = trimmed[sol_start + 1 ..];
                p.solution = try allocator.dupe(u8, std.mem.trim(u8, sol, " \t\r"));
            }
        }
    }

    // Save last pattern
    if (current_pattern) |p| {
        try patterns.append(allocator, p);
    }

    return patterns.toOwnedSlice(allocator);
}

// ============================================================================
// Tests
// ============================================================================

test "parser: parse fix plan" {
    const allocator = std.testing.allocator;

    const content =
        \\- [ ] Task 1 (P0)
        \\  - [ ] Subtask 1.1
        \\  - [x] Subtask 1.2
        \\- [x] Task 2
        \\Acceptance criteria:
        \\  - [ ] Criterion 1
        \\  - [x] Criterion 2
    ;

    const tasks = try parseFixPlan(allocator, content);
    defer {
        for (tasks) |*t| t.deinit(allocator);
        allocator.free(tasks);
    }

    try std.testing.expectEqual(@as(usize, 2), tasks.len);

    // Task 1 has 2 subtasks
    try std.testing.expectEqual(@as(usize, 2), tasks[0].subtasks.len);
    try std.testing.expectEqualStrings("Task 1", tasks[0].description);
    try std.testing.expect(tasks[0].priority == .p0_critical);

    // Tasks should have acceptance criteria
    try std.testing.expect(tasks[0].acceptance_criteria.len > 0);
}

test "parser: parse tech tree" {
    const allocator = std.testing.allocator;

    const content =
        \\## Available
        \\| ID | Name | Branch | Impact | Complexity | Dependencies |
        \\|----|------|--------|--------|------------|-------------|
        \\| T1 | Test | core | 8.0 | 3.0 | - |
    ;

    const tree = try parseTechTree(allocator, content);
    defer tree.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), tree.available.len);
    try std.testing.expectEqualStrings("T1", tree.available[0].id);
    try std.testing.expectEqual(types.BranchType.core, tree.available[0].branch);
    try std.testing.expectEqual(@as(f64, 8.0), tree.available[0].impact);
}

test "parser: parse success history" {
    const allocator = std.testing.allocator;

    const content =
        \\## abc123 Task completed successfully
        \\## def456 Another task
    ;

    const patterns = try parseSuccessHistory(allocator, content);
    defer {
        for (patterns) |*p| p.deinit(allocator);
        allocator.free(patterns);
    }

    try std.testing.expectEqual(@as(usize, 2), patterns.len);
    try std.testing.expectEqualStrings("abc123", patterns[0].commit_sha);
}

test "parser: parse regression patterns" {
    const allocator = std.testing.allocator;

    const content =
        \\## Pattern 1
        \\**Description:** Test pattern
        \\**Root Cause:** Memory leak
        \\**Solution:** Free memory
    ;

    const patterns = try parseRegressionPatterns(allocator, content);
    defer {
        for (patterns) |*p| p.deinit(allocator);
        allocator.free(patterns);
    }

    try std.testing.expectEqual(@as(usize, 1), patterns.len);
    try std.testing.expectEqualStrings("Pattern 1", patterns[0].pattern_name);
    try std.testing.expectEqualStrings("Test pattern", patterns[0].description);
    try std.testing.expectEqualStrings("Memory leak", patterns[0].root_cause);
    try std.testing.expectEqualStrings("Free memory", patterns[0].solution);
}
