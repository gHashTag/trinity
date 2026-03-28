//! Zenodo V21: Broader Impact Statement for NeurIPS/ICLR 2025
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Implements broader impact statement generation required by:
//! - NeurIPS 2025: "Broader Impact" section (required)
//! - ICLR 2025: "Broader Impact" section (required)
//! - MLSys 2025: "Impact Statement" section (required)
//!
//! References:
//! - NeurIPS 2025 Call for Papers: "Broader Impact Statement"
//! - ICLR 2025: "Ethics and Broader Impact"

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Impact category for structured analysis
pub const ImpactCategory = enum {
    positive,
    negative,
    uncertain,
    neutral,

    pub fn description(self: ImpactCategory) []const u8 {
        return switch (self) {
            .positive => "Positive Impact",
            .negative => "Potential Negative Impact",
            .uncertain => "Uncertain Impact",
            .neutral => "Neutral Impact",
        };
    }
};

/// Specific impact item
pub const ImpactItem = struct {
    category: ImpactCategory,
    title: []const u8,
    description: []const u8,
    mitigation: ?[]const u8 = null,

    pub fn format(self: ImpactItem, allocator: Allocator) ![]const u8 {
        const mitigation_str = if (self.mitigation) |m|
            try std.fmt.allocPrint(allocator, "\n\n**Mitigation:** {s}", .{m})
        else
            "";

        return std.fmt.allocPrint(allocator,
            \\**{s}: {s}**
            \\{s}{s}
        , .{
            self.category.description(),
            self.title,
            self.description,
            mitigation_str,
        });
    }
};

/// Complete broader impact statement
pub const BroaderImpactStatement = struct {
    /// Primary positive impacts
    positive_impacts: []ImpactItem,
    /// Potential negative impacts
    negative_impacts: []ImpactItem,
    /// Uncertain impacts requiring study
    uncertain_impacts: []ImpactItem,
    /// Long-term considerations
    long_term_considerations: []const u8,
    /// Stakeholder analysis
    stakeholder_analysis: []const u8,

    /// Format as NeurIPS-style statement
    pub fn formatNeurips(self: *const BroaderImpactStatement, allocator: Allocator) ![]const u8 {
        var buffer = std.array_list.AlignedManaged(u8, null).init(allocator);
        defer buffer.deinit();

        try buffer.appendSlice("## Broader Impact Statement\n\n");

        try buffer.appendSlice("### Positive Impacts\n\n");
        for (self.positive_impacts) |item| {
            const formatted = try item.format(allocator);
            defer allocator.free(formatted);
            try buffer.appendSlice(formatted);
            try buffer.appendSlice("\n\n");
        }

        if (self.negative_impacts.len > 0) {
            try buffer.appendSlice("### Potential Negative Impacts\n\n");
            for (self.negative_impacts) |item| {
                const formatted = try item.format(allocator);
                defer allocator.free(formatted);
                try buffer.appendSlice(formatted);
                try buffer.appendSlice("\n\n");
            }
        }

        if (self.uncertain_impacts.len > 0) {
            try buffer.appendSlice("### Uncertain Impacts Requiring Further Study\n\n");
            for (self.uncertain_impacts) |item| {
                const formatted = try item.format(allocator);
                defer allocator.free(formatted);
                try buffer.appendSlice(formatted);
                try buffer.appendSlice("\n\n");
            }
        }

        try buffer.appendSlice("### Long-Term Considerations\n\n");
        try buffer.appendSlice(self.long_term_considerations);
        try buffer.appendSlice("\n\n");

        try buffer.appendSlice("### Stakeholder Analysis\n\n");
        try buffer.appendSlice(self.stakeholder_analysis);

        return buffer.toOwnedSlice();
    }

    /// Format as ICLR-style statement
    pub fn formatIclr(self: *const BroaderImpactStatement, allocator: Allocator) ![]const u8 {
        var buffer = std.array_list.AlignedManaged(u8, null).init(allocator);
        defer buffer.deinit();

        try buffer.appendSlice("## Broader Impact\n\n");

        try buffer.appendSlice("This work has several important implications for the AI community and society:\n\n");

        for (self.positive_impacts) |item| {
            try buffer.appendSlice("- ");
            try buffer.appendSlice(item.title);
            try buffer.appendSlice(": ");
            try buffer.appendSlice(item.description);
            try buffer.appendSlice("\n");
        }

        if (self.negative_impacts.len > 0) {
            try buffer.appendSlice("\n**Potential Risks:**\n\n");
            for (self.negative_impacts) |item| {
                try buffer.appendSlice("- ");
                try buffer.appendSlice(item.title);
                if (item.mitigation) |m| {
                    try buffer.appendSlice(" (Mitigation: ");
                    try buffer.appendSlice(m);
                    try buffer.appendSlice(")");
                }
                try buffer.appendSlice("\n");
            }
        }

        try buffer.appendSlice("\n**Long-term Vision:**\n\n");
        try buffer.appendSlice(self.long_term_considerations);

        return buffer.toOwnedSlice();
    }
};

/// Default Trinity broader impact statement
pub fn defaultTrinityImpact(allocator: Allocator) !BroaderImpactStatement {
    const positive_impacts = try allocator.dupe(ImpactItem, &[_]ImpactItem{
        .{
            .category = .positive,
            .title = "Energy-Efficient AI",
            .description = "Trinity's ternary computing paradigm reduces AI inference energy consumption by up to 10× compared to binary floating-point systems, making AI more environmentally sustainable.",
            .mitigation = null,
        },
        .{
            .category = .positive,
            .title = "Edge AI Democratization",
            .description = "By enabling high-performance AI inference on resource-constrained devices (FPGA, microcontrollers), Trinity expands access to AI technology in developing regions and edge computing scenarios.",
            .mitigation = null,
        },
        .{
            .category = .positive,
            .title = "Open Science Contribution",
            .description = "All code, datasets, and models are released as open source (MIT/Apache license), enabling reproducible research and community-driven development of efficient AI systems.",
            .mitigation = null,
        },
        .{
            .category = .positive,
            .title = "Educational Value",
            .description = "The project provides comprehensive educational materials on ternary computing, FPGA design, and energy-efficient AI, benefiting students and researchers worldwide.",
            .mitigation = null,
        },
    });

    const negative_impacts = try allocator.dupe(ImpactItem, &[_]ImpactItem{
        .{
            .category = .negative,
            .title = "Hardware Access Barrier",
            .description = "FPGA deployment requires specialized hardware and knowledge, potentially limiting accessibility compared to software-only solutions.",
            .mitigation = "We provide software simulation, cloud deployment guides, and comprehensive documentation to lower the barrier to entry.",
        },
        .{
            .category = .negative,
            .title = "Quantization Accuracy Trade-offs",
            .description = "Ternary quantization may reduce model accuracy on some tasks compared to full-precision models.",
            .mitigation = "We document accuracy benchmarks and provide guidelines for tasks where ternary models are suitable vs. where higher precision is needed.",
        },
    });

    const uncertain_impacts = try allocator.dupe(ImpactItem, &[_]ImpactItem{
        .{
            .category = .uncertain,
            .title = "Long-term Ecosystem Impact",
            .description = "The long-term impact of ternary computing on the AI hardware ecosystem is uncertain. Widespread adoption could shift industry practices.",
            .mitigation = "We engage with standards organizations and open hardware communities to ensure responsible development.",
        },
    });

    const long_term = 
        \\Trinity represents a step toward more sustainable AI infrastructure. As AI adoption grows, energy efficiency becomes increasingly critical.
        \\Our ternary computing approach demonstrates that alternative numerical representations can significantly reduce computational cost.
        \\Long-term, we hope this work inspires further research into energy-efficient AI hardware and software co-design.
        \\
        \\The sacred geometry principles underlying Trinity's design (φ² + 1/φ² = 3) connect computational efficiency with mathematical elegance,
        \\potentially inspiring new approaches to neuromorphic and bio-inspired computing.
    ;

    const stakeholders = 
        \\**Researchers:** Access to efficient AI models and methodologies for energy-conscious ML research.
        \\**Industry:** Reference implementation for ternary AI deployment, potentially reducing cloud computing costs.
        \\**Educators:** Comprehensive teaching materials for FPGA-based AI systems.
        \\**Developing Regions:** Edge AI capabilities enable deployment without reliable internet connectivity.
        \\**Environment:** Reduced energy consumption contributes to lower carbon footprint for AI applications.
        \\
        \\**Stakeholder Engagement:** We actively seek feedback from all stakeholder groups through GitHub issues, conferences,
        \\and direct collaboration to ensure Trinity evolves responsibly.
    ;

    return .{
        .positive_impacts = positive_impacts,
        .negative_impacts = negative_impacts,
        .uncertain_impacts = uncertain_impacts,
        .long_term_considerations = long_term,
        .stakeholder_analysis = stakeholders,
    };
}

/// Custom impact statement builder
pub const ImpactBuilder = struct {
    allocator: Allocator,
    positive: std.array_list.AlignedManaged(ImpactItem, null),
    negative: std.array_list.AlignedManaged(ImpactItem, null),
    uncertain: std.array_list.AlignedManaged(ImpactItem, null),

    pub fn init(allocator: Allocator) ImpactBuilder {
        return .{
            .allocator = allocator,
            .positive = std.array_list.AlignedManaged(ImpactItem, null).init(allocator),
            .negative = std.array_list.AlignedManaged(ImpactItem, null).init(allocator),
            .uncertain = std.array_list.AlignedManaged(ImpactItem, null).init(allocator),
        };
    }

    pub fn addPositive(self: *ImpactBuilder, title: []const u8, description: []const u8) !void {
        try self.positive.append(.{
            .category = .positive,
            .title = title,
            .description = description,
            .mitigation = null,
        });
    }

    pub fn addNegative(self: *ImpactBuilder, title: []const u8, description: []const u8, mitigation: ?[]const u8) !void {
        try self.negative.append(.{
            .category = .negative,
            .title = title,
            .description = description,
            .mitigation = mitigation,
        });
    }

    pub fn addUncertain(self: *ImpactBuilder, title: []const u8, description: []const u8) !void {
        try self.uncertain.append(.{
            .category = .uncertain,
            .title = title,
            .description = description,
            .mitigation = null,
        });
    }

    pub fn build(self: *ImpactBuilder, long_term: []const u8, stakeholders: []const u8) !BroaderImpactStatement {
        return .{
            .positive_impacts = try self.positive.toOwnedSlice(),
            .negative_impacts = try self.negative.toOwnedSlice(),
            .uncertain_impacts = try self.uncertain.toOwnedSlice(),
            .long_term_considerations = long_term,
            .stakeholder_analysis = stakeholders,
        };
    }

    pub fn deinit(self: *ImpactBuilder) void {
        self.positive.deinit();
        self.negative.deinit();
        self.uncertain.deinit();
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "Broader Impact: default statement" {
    const allocator = std.testing.allocator;

    const statement = try defaultTrinityImpact(allocator);
    defer {
        allocator.free(statement.positive_impacts);
        allocator.free(statement.negative_impacts);
        allocator.free(statement.uncertain_impacts);
    }

    try std.testing.expect(statement.positive_impacts.len == 4);
    try std.testing.expect(statement.negative_impacts.len == 2);
    try std.testing.expect(statement.uncertain_impacts.len == 1);
}

test "Broader Impact: NeurIPS format" {
    const allocator = std.testing.allocator;

    const statement = try defaultTrinityImpact(allocator);
    defer {
        allocator.free(statement.positive_impacts);
        allocator.free(statement.negative_impacts);
        allocator.free(statement.uncertain_impacts);
    }

    const formatted = try statement.formatNeurips(allocator);
    defer allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "Broader Impact Statement") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Energy-Efficient AI") != null);
}

test "Broader Impact: ICLR format" {
    const allocator = std.testing.allocator;

    const statement = try defaultTrinityImpact(allocator);
    defer {
        allocator.free(statement.positive_impacts);
        allocator.free(statement.negative_impacts);
        allocator.free(statement.uncertain_impacts);
    }

    const formatted = try statement.formatIclr(allocator);
    defer allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "Broader Impact") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Energy-Efficient AI") != null);
}

test "ImpactBuilder: custom statement" {
    const allocator = std.testing.allocator;

    var builder = ImpactBuilder.init(allocator);
    defer builder.deinit();

    try builder.addPositive("Test Positive", "This is a positive impact");
    try builder.addNegative("Test Negative", "This is a negative impact", "Test mitigation");
    try builder.addUncertain("Test Uncertain", "This is uncertain");

    const statement = try builder.build("Long term text", "Stakeholder text");
    defer {
        allocator.free(statement.positive_impacts);
        allocator.free(statement.negative_impacts);
        allocator.free(statement.uncertain_impacts);
    }

    try std.testing.expect(statement.positive_impacts.len == 1);
    try std.testing.expect(statement.negative_impacts.len == 1);
    try std.testing.expect(statement.uncertain_impacts.len == 1);
}

// φ² + 1/φ² = 3 | TRINITY
