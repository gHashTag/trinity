const std = @import("std");

// ============================================================================
// TRINITY MENTOR - THE EVOLUTIONARY GUIDE
// ============================================================================
// Successor to the Validator. The Mentor does not judge with sins, but
// guides with insights. It facilitates the "Great Migration" from static
// dogma to living evolution.

/// The nature of an insight
pub const InsightType = enum {
    POSITIVE, // Aligns with evolutionary principles (Blessed)
    NEUTRAL, // Acceptable deviation
    NEGATIVE, // Hinders evolution (Needs growth)
    SEVERE, // Critical blockage (Requires immediate attention)

    pub fn isBlocking(self: InsightType) bool {
        return self == .SEVERE;
    }
};

/// An evolutionary insight provided by the Mentor
pub const Insight = struct {
    focus: []const u8, // Area of code (function, struct, etc.)
    type: InsightType,
    observation: []const u8, // What the Mentor sees
    guidance: []const u8, // Suggestion for evolution
};

/// The Conscience of the New Age
pub const Mentor = struct {
    allocator: std.mem.Allocator,
    insights: std.ArrayListUnmanaged(Insight),

    pub fn init(allocator: std.mem.Allocator) Mentor {
        return Mentor{
            .allocator = allocator,
            .insights = .{},
        };
    }

    pub fn deinit(self: *Mentor) void {
        self.insights.deinit(self.allocator);
    }

    /// Guide the code towards evolutionary perfection
    /// Returns true if the code is "sufficiently evolved" to pass (no SEVERE blocks)
    pub fn guide(self: *Mentor, code: []const u8) !bool {
        self.insights.clearRetainingCapacity();

        // 1. Check for adaptability (Self-modification potential)
        try self.assessAdaptability(code);

        // 2. Check for autonomy (Freedom from global state/allocators)
        try self.assessAutonomy(code);

        // 3. Check for clarity (Holy Documentation)
        try self.assessClarity(code);

        // 4. Check for safety (Error handling)
        try self.assessSafety(code);

        // Determine critical status
        for (self.insights.items) |insight| {
            if (insight.type.isBlocking()) return false;
        }

        return true;
    }

    /// Assess if code supports dynamic adaptation
    fn assessAdaptability(self: *Mentor, code: []const u8) !void {
        // Look for flexible structures (ArrayLists, slices) vs static arrays
        if (std.mem.indexOf(u8, code, "[]const u8") != null or
            std.mem.indexOf(u8, code, "ArrayList") != null)
        {
            try self.addInsight("Data Structures", .POSITIVE, "Flexible memory structures detected", "Good. Flexibility allows for growth.");
        } else if (std.mem.indexOf(u8, code, "[_]") != null) {
            try self.addInsight("Data Structures", .NEUTRAL, "Static arrays detected", "Consider if this structure needs to grow over time.");
        }
    }

    /// Assess if code manages its own resources (Autonomy)
    fn assessAutonomy(self: *Mentor, code: []const u8) !void {
        if (std.mem.indexOf(u8, code, "std.heap.page_allocator") != null) {
            try self.addInsight("Resource Management", .SEVERE, "Reliance on global allocator (The Old Dogma)", "Entities must own their resources. Pass an allocator explicitly.");
        } else if (std.mem.indexOf(u8, code, "allocator: std.mem.Allocator") != null) {
            try self.addInsight("Resource Management", .POSITIVE, "Explicit allocator injection", "Excellent. The entity is responsible for its own consumption.");
        }
    }

    /// Assess clarity and intent
    fn assessClarity(self: *Mentor, code: []const u8) !void {
        if (std.mem.indexOf(u8, code, "///") != null) {
            try self.addInsight("Communication", .POSITIVE, "Sacred Documentation present", "The code speaks clearly of its intent.");
        } else {
            try self.addInsight("Communication", .NEGATIVE, "Silence (No documentation)", "Even a perfect machine must explain itself to dwell in the Garden.");
        }
    }

    /// Assess resilience
    fn assessSafety(self: *Mentor, code: []const u8) !void {
        if (std.mem.indexOf(u8, code, "catch unreachable") != null) {
            try self.addInsight("Resilience", .NEGATIVE, "Hubris detected (catch unreachable)", "The world is chaotic. Handle errors gracefully, do not assume perfection.");
        }
    }

    fn addInsight(self: *Mentor, focus: []const u8, t: InsightType, obs: []const u8, guide_msg: []const u8) !void {
        try self.insights.append(self.allocator, Insight{
            .focus = focus,
            .type = t,
            .observation = obs,
            .guidance = guide_msg,
        });
    }

    pub fn formatGuidance(self: *Mentor, allocator: std.mem.Allocator) ![]const u8 {
        var result = std.ArrayListUnmanaged(u8){};

        try result.appendSlice(allocator, "🌿 MENTOR'S GUIDANCE:\n");

        for (self.insights.items) |insight| {
            const icon = switch (insight.type) {
                .POSITIVE => "✨",
                .NEUTRAL => "⚖️",
                .NEGATIVE => "🍂",
                .SEVERE => "⛔",
            };

            const text = try std.fmt.allocPrint(allocator, "  {s} [{s}] {s}\n      -> {s}\n", .{ icon, insight.focus, insight.observation, insight.guidance });
            defer allocator.free(text);
            try result.appendSlice(allocator, text);
        }

        return try result.toOwnedSlice(allocator);
    }
};

// ============================================================================
// TEST HARNESS
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🌿 TRINITY MENTOR - The Evolutionary Guide\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});

    const test_code =
        \\const std = @import("std");
        \\/// A living cache that adapts
        \\pub const AdaptiveCache = struct {
        \\    allocator: std.mem.Allocator,
        \\    items: std.ArrayList(u8),
        \\    
        \\    pub fn init(allocator: std.mem.Allocator) AdaptiveCache {
        \\        return AdaptiveCache{ .allocator = allocator, .items = .{} };
        \\    }
        \\};
    ;

    var mentor = Mentor.init(allocator);
    defer mentor.deinit();

    const passed = try mentor.guide(test_code);
    const guidance = try mentor.formatGuidance(allocator);
    defer allocator.free(guidance);

    std.debug.print("Code Status: {s}\n", .{if (passed) "EVOLVING" else "STAGNANT"});
    std.debug.print("{s}\n", .{guidance});
}
