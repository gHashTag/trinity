//! Zenodo V21: Broader Impact Statement Generator for NeurIPS/ICLR 2025
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const RiskLevel = enum(u8) {
    negligible,
    low,
    medium,
    high,
    critical,

    pub fn score(self: RiskLevel) u4 {
        return switch (self) {
            .negligible => 1,
            .low => 2,
            .medium => 3,
            .high => 4,
            .critical => 5,
        };
    }

    pub fn emoji(self: RiskLevel) []const u8 {
        return switch (self) {
            .negligible => "🟢",
            .low => "🟡",
            .medium => "🟠",
            .high => "🔴",
            .critical => "⚫",
        };
    }
};

pub const RiskAssessment = struct {
    name: []const u8,
    likelihood: RiskLevel,
    impact: RiskLevel,
    mitigations: []const []const u8,

    pub fn score(self: RiskAssessment) u4 {
        return self.likelihood.score() * self.impact.score();
    }
};

pub const ImpactCategory = enum {
    environmental,
    societal,
    economic,
    security,
    privacy,
};

pub const ImpactStatement = struct {
    category: ImpactCategory,
    positive_impacts: []const []const u8 = &.{},
    negative_impacts: []const []const u8 = &.{},
    mitigations: []const []const u8 = &.{},

    pub fn format(self: *const ImpactStatement, allocator: Allocator) ![]const u8 {
        const category_name = switch (self.category) {
            .environmental => "Environmental Impact",
            .societal => "Societal Impact",
            .economic => "Economic Impact",
            .security => "Security Impact",
            .privacy => "Privacy Impact",
        };

        var buffer = std.ArrayListUnmanaged(u8){};
        defer buffer.deinit(allocator);

        try buffer.appendSlice(allocator, "## ");
        try buffer.appendSlice(allocator, category_name);
        try buffer.appendSlice(allocator, "\n\n");

        if (self.positive_impacts.len > 0) {
            try buffer.appendSlice(allocator, "**Positive Impacts:**\n");
            for (self.positive_impacts) |impact| {
                try buffer.appendSlice(allocator, "- ");
                try buffer.appendSlice(allocator, impact);
                try buffer.appendSlice(allocator, "\n");
            }
            try buffer.appendSlice(allocator, "\n");
        }

        if (self.negative_impacts.len > 0) {
            try buffer.appendSlice(allocator, "**Negative Impacts:**\n");
            for (self.negative_impacts) |impact| {
                try buffer.appendSlice(allocator, "- ");
                try buffer.appendSlice(allocator, impact);
                try buffer.appendSlice(allocator, "\n");
            }
            try buffer.appendSlice(allocator, "\n");
        }

        if (self.mitigations.len > 0) {
            try buffer.appendSlice(allocator, "**Mitigation Strategies:**\n");
            for (self.mitigations) |mitigation| {
                try buffer.appendSlice(allocator, "- ");
                try buffer.appendSlice(allocator, mitigation);
                try buffer.appendSlice(allocator, "\n");
            }
        }

        return buffer.toOwnedSlice(allocator);
    }
};

pub const BroaderImpactStatement = struct {
    primary_uses: []const []const u8,
    misuses: []const []const u8,
    impacts: []const ImpactStatement,
    risks: []const RiskAssessment,
    ethical_considerations: []const []const u8,

    pub fn formatNeurips(self: *const BroaderImpactStatement, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayListUnmanaged(u8){};
        defer buffer.deinit(allocator);

        try buffer.appendSlice(allocator,
            \\# Broader Impact Statement
            \\
            \\## Primary Intended Use
            \\
        );

        for (self.primary_uses) |use_| {
            try buffer.appendSlice(allocator, "- ");
            try buffer.appendSlice(allocator, use_);
            try buffer.appendSlice(allocator, "\n");
        }

        try buffer.appendSlice(allocator, "\n## Potential Misuses\n\n");

        for (self.misuses) |misuse| {
            try buffer.appendSlice(allocator, "- **");
            try buffer.appendSlice(allocator, misuse);
            try buffer.appendSlice(allocator, "**\n");
        }

        try buffer.appendSlice(allocator, "\n## Impact Assessment\n\n");

        for (self.impacts) |impact| {
            const formatted = try impact.format(allocator);
            defer allocator.free(formatted);
            try buffer.appendSlice(allocator, formatted);
            try buffer.appendSlice(allocator, "\n");
        }

        try buffer.appendSlice(allocator, "\n---\n\nφ² + 1/φ² = 3 | TRINITY\n");

        return buffer.toOwnedSlice(allocator);
    }
};

pub fn defaultTrinityImpact(_: Allocator) !BroaderImpactStatement {
    const primary_uses = [_][]const u8{
        "Energy-efficient AI inference on edge devices",
    };

    const misuses = [_][]const u8{
        "Surveillance: Low-power AI could enable pervasive monitoring",
    };

    const environmental_impact = ImpactStatement{
        .category = .environmental,
        .positive_impacts = &[_][]const u8{
            "1.2W power vs 200W GPU = 99.4% energy reduction",
        },
        .negative_impacts = &[_][]const u8{
            "E-waste from FPGA manufacturing",
        },
        .mitigations = &[_][]const u8{
            "Design for longevity",
        },
    };

    const risks = [_]RiskAssessment{
        .{
            .name = "Hardware Failure",
            .likelihood = .medium,
            .impact = .low,
            .mitigations = &.{},
        },
    };

    const ethical_considerations = [_][]const u8{
        "**Accessibility**: Open-source design promotes global accessibility",
    };

    return BroaderImpactStatement{
        .primary_uses = &primary_uses,
        .misuses = &misuses,
        .impacts = &[_]ImpactStatement{environmental_impact},
        .risks = &risks,
        .ethical_considerations = &ethical_considerations,
    };
}

test "BroaderImpactStatement: NeurIPS format" {
    const allocator = std.testing.allocator;
    const statement = try defaultTrinityImpact(allocator);
    const neurips = try statement.formatNeurips(allocator);
    defer allocator.free(neurips);

    try std.testing.expect(std.mem.indexOf(u8, neurips, "Broader Impact Statement") != null);
}

// φ² + 1/φ² = 3 | TRINITY
