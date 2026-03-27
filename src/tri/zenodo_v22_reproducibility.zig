//! Zenodo V22: Reproducibility Checklist Generator for NeurIPS/ICLR 2025
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const CheckStatus = enum(u8) {
    pending,
    complete,
    incomplete,
    na,

    pub fn emoji(self: CheckStatus) []const u8 {
        return switch (self) {
            .pending => "⏳",
            .complete => "✅",
            .incomplete => "❌",
            .na => "➖",
        };
    }
};

pub const CheckItem = struct {
    description: []const u8,
    status: CheckStatus,
    notes: []const u8 = "",
};

pub const ChecklistCategory = struct {
    name: []const u8,
    items: []const CheckItem,

    pub fn completion(self: ChecklistCategory) f64 {
        if (self.items.len == 0) return 100.0;
        var complete: usize = 0;
        var total: usize = 0;
        for (self.items) |item| {
            if (item.status != .na) {
                total += 1;
                if (item.status == .complete) complete += 1;
            }
        }
        if (total == 0) return 100.0;
        return @as(f64, @floatFromInt(complete)) * 100.0 / @as(f64, @floatFromInt(total));
    }
};

pub const ReproducibilityChecklist = struct {
    categories: []const ChecklistCategory,

    pub fn overallCompletion(self: ReproducibilityChecklist) f64 {
        if (self.categories.len == 0) return 100.0;
        var total_items: usize = 0;
        var complete_items: usize = 0;
        for (self.categories) |cat| {
            for (cat.items) |item| {
                if (item.status != .na) {
                    total_items += 1;
                    if (item.status == .complete) complete_items += 1;
                }
            }
        }
        if (total_items == 0) return 100.0;
        return @as(f64, @floatFromInt(complete_items)) * 100.0 / @as(f64, @floatFromInt(total_items));
    }

    pub fn formatNeurips(self: *const ReproducibilityChecklist, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayListUnmanaged(u8){};
        defer buffer.deinit(allocator);

        try buffer.appendSlice(allocator, "# Reproducibility Checklist\n\n");

        for (self.categories) |cat| {
            try buffer.appendSlice(allocator, "**");
            try buffer.appendSlice(allocator, cat.name);
            try buffer.appendSlice(allocator, "**\n\n");

            for (cat.items) |item| {
                try buffer.appendSlice(allocator, "- [");
                const mark = switch (item.status) {
                    .complete => "x",
                    else => " ",
                };
                try buffer.appendSlice(allocator, mark);
                try buffer.appendSlice(allocator, "] ");
                try buffer.appendSlice(allocator, item.description);
                try buffer.appendSlice(allocator, "\n");
            }
            try buffer.appendSlice(allocator, "\n");
        }

        try buffer.appendSlice(allocator, "\n---\n\nφ² + 1/φ² = 3 | TRINITY\n");
        return buffer.toOwnedSlice(allocator);
    }
};

pub fn defaultTrinityChecklist(_: Allocator) !ReproducibilityChecklist {
    const code_items = [_]CheckItem{
        .{ .description = "Code available with permissive license", .status = .complete, .notes = "MIT License" },
        .{ .description = "README with build instructions", .status = .complete },
        .{ .description = "Docker image", .status = .incomplete, .notes = "TODO" },
    };

    const categories = [_]ChecklistCategory{
        .{ .name = "Code", .items = &code_items },
    };

    return ReproducibilityChecklist{
        .categories = &categories,
    };
}

test "ReproducibilityChecklist: formatNeurips" {
    const checklist = try defaultTrinityChecklist(std.testing.allocator);
    const formatted = try checklist.formatNeurips(std.testing.allocator);
    defer std.testing.allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "Reproducibility Checklist") != null);
}

// φ² + 1/φ² = 3 | TRINITY
