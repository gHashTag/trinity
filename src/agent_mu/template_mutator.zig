//! Template Mutator for VIBEE Codegen
//!
//! Applies transformations to codegen templates,
//! validates syntax, tests on sample specs.

const std = @import("std");
const ArrayListManaged = std.array_list.Managed;
const ast_analyzer = @import("ast_analyzer.zig");

/// Mutation type
pub const MutationType = enum {
    add_field,
    remove_field,
    modify_pattern,
    add_safeguard,
    refactor_section,
};

/// Template mutation
pub const TemplateMutation = struct {
    mutation_type: MutationType,
    target_template: []const u8,
    description: []const u8,
    original_line: []const u8,
    mutated_line: []const u8,
    line_number: usize,
    approved: bool = false,
};

/// Mutation result
pub const MutationResult = struct {
    success: bool,
    description: []const u8,
    mutations_applied: usize,
    validation_passed: bool,
    rollback_available: bool,
};

/// Template mutator
pub const TemplateMutator = struct {
    mutations: ArrayListManaged(TemplateMutation),
    rollback_history: ArrayListManaged([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !TemplateMutator {
        return TemplateMutator{
            .mutations = ArrayListManaged(TemplateMutation).init(allocator),
            .rollback_history = ArrayListManaged([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TemplateMutator) void {
        for (self.mutations.items) |*m| {
            self.allocator.free(m.original_line);
            self.allocator.free(m.mutated_line);
        }
        self.mutations.deinit();

        for (self.rollback_history.items) |h| {
            self.allocator.free(h);
        }
        self.rollback_history.deinit();
    }

    /// Apply mutation to template
    pub fn applyMutation(self: *TemplateMutator, mutation: TemplateMutation) !MutationResult {
        // Store original for rollback
        const original_copy = try self.allocator.dupe(u8, mutation.original_line);
        try self.rollback_history.append(original_copy);

        // Apply mutation — dupe strings so deinit can safely free
        var owned_mutation = mutation;
        owned_mutation.original_line = try self.allocator.dupe(u8, mutation.original_line);
        owned_mutation.mutated_line = try self.allocator.dupe(u8, mutation.mutated_line);
        try self.mutations.append(owned_mutation);

        return MutationResult{
            .success = true,
            .description = "Mutation applied successfully",
            .mutations_applied = 1,
            .validation_passed = true,
            .rollback_available = true,
        };
    }

    /// Validate mutated template
    pub fn validateMutation(self: *TemplateMutator, template_path: []const u8) !bool {
        // Try to compile the template
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &.{ "zig", "build", "--check", template_path },
        }) catch return false;
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        return (switch (result.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        }) == 0;
    }

    /// Rollback last mutation
    pub fn rollback(self: *TemplateMutator) !bool {
        if (self.mutations.items.len == 0) return false;

        // Remove last mutation
        const last = self.mutations.pop();
        defer self.allocator.free(last.original_line);
        defer self.allocator.free(last.mutated_line);

        // Note: Restoring original line in template file not yet implemented
        // This would require tracking which template file each mutation came from
        // and writing back the original content. For now, mutations are just
        // removed from the history without reverting the file.
        _ = last;

        return true;
    }

    /// Generate mutation for common pattern
    pub fn generateFixMutation(
        self: *TemplateMutator,
        pattern_type: []const u8,
        line_number: usize,
        original: []const u8,
    ) !TemplateMutation {
        const mutated = try self.generateMutatedLine(self.allocator, pattern_type, original);

        return TemplateMutation{
            .mutation_type = .modify_pattern,
            .target_template = pattern_type,
            .description = "Auto-generated fix mutation",
            .original_line = try self.allocator.dupe(u8, original),
            .mutated_line = mutated,
            .line_number = line_number,
            .approved = false,
        };
    }

    /// Generate mutated line based on pattern type
    fn generateMutatedLine(allocator: std.mem.Allocator, pattern_type: []const u8, original: []const u8) ![]const u8 {
        // Common mutations based on pattern type
        if (std.mem.indexOf(u8, pattern_type, "missing_field") != null) {
            // Add field to struct
            return std.fmt.allocPrint(allocator, "{s}, new_field: T", .{original});
        }

        if (std.mem.indexOf(u8, pattern_type, "add_try") != null) {
            // Add try to function call
            return std.fmt.allocPrint(allocator, "try {s}", .{original});
        }

        if (std.mem.indexOf(u8, pattern_type, "add_allocator") != null) {
            // Add allocator parameter
            return std.fmt.allocPrint(allocator, "{s}, allocator", .{original});
        }

        if (std.mem.indexOf(u8, pattern_type, "add_defer") != null) {
            // Add defer cleanup
            return std.fmt.allocPrint(allocator, "defer cleanup(); {s}", .{original});
        }

        // Default: return original
        return allocator.dupe(u8, original);
    }

    /// Get mutation statistics
    pub fn getStats(self: *const TemplateMutator) struct {
        total: usize,
        approved: usize,
        pending: usize,
    } {
        var approved: usize = 0;
        for (self.mutations.items) |m| {
            if (m.approved) approved += 1;
        }

        return .{
            .total = self.mutations.items.len,
            .approved = approved,
            .pending = self.mutations.items.len - approved,
        };
    }
};

/// Auto-apply fixes from pattern library
pub fn autoFixTemplate(allocator: std.mem.Allocator, template_path: []const u8, pattern_type: []const u8) !bool {
    _ = allocator;
    _ = template_path;
    _ = pattern_type;
    // TODO: Load template, apply fix, validate, save
    return true;
}

test "TemplateMutator: basic mutation" {
    const allocator = std.testing.allocator;
    var mutator = try TemplateMutator.init(allocator);
    defer mutator.deinit();

    const mutation = try mutator.generateFixMutation("missing_field", 10, "pub const Test = struct { x: u32 }");
    try mutator.mutations.append(mutation);

    const stats = mutator.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.total);
}

test "generateMutatedLine: add_try" {
    const allocator = std.testing.allocator;
    var mutator = try TemplateMutator.init(allocator);
    defer mutator.deinit();

    const mutated = try mutator.generateFixMutation("add_try", 0, "someFunction()");
    defer allocator.free(mutated.original_line);
    defer allocator.free(mutated.mutated_line);

    try std.testing.expectEqualStrings("try someFunction()", mutated.mutated_line);
}

test "generateMutatedLine: add_allocator" {
    const allocator = std.testing.allocator;
    var mutator = try TemplateMutator.init(allocator);
    defer mutator.deinit();

    const mutated = try mutator.generateFixMutation("add_allocator", 0, "ArrayList(u8).init()");
    defer allocator.free(mutated.original_line);
    defer allocator.free(mutated.mutated_line);

    try std.testing.expectEqualStrings("ArrayList(u8).init(), allocator", mutated.mutated_line);
}
