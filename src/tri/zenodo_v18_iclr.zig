// ═══════════════════════════════════════════════════════════════════════════════
// Zenodo V18: ICLR 2025 Broader Impact Statement Generator
// ═══════════════════════════════════════════════════════════════════════════════
//
// Generates ICLR 2025 broader impact statements from metadata.
// Covers positive impacts, risks, mitigations, and long-term consequences.
//
// Reference: https://iclr.cc/2025/broader-impact
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// ICLR 2025 Broader Impact Statement
pub const BroaderImpact = struct {
    /// Primary beneficiaries
    beneficiaries: []const Beneficiary = &.{},

    /// Potential negative impacts
    risks: []const Risk = &.{},

    /// Mitigation strategies
    mitigations: []const Mitigation = &.{},

    /// Long-term consequences
    long_term: []const Consequence = &.{},

    /// Calculate overall impact score (-100 to +100)
    pub fn impactScore(self: BroaderImpact) f64 {
        var positive_score: f64 = 0;
        for (self.beneficiaries) |b| {
            const magnitude_score = magnitudeToScore(b.magnitude);
            positive_score += magnitude_score;
        }

        var negative_score: f64 = 0;
        for (self.risks) |r| {
            const severity_score = severityToScore(r.severity);
            negative_score += severity_score * r.likelihood;
        }

        // Mitigation bonus (reduces negative impact)
        var mitigation_bonus: f64 = 0;
        for (self.mitigations) |m| {
            const effectiveness_score = effectivenessToScore(m.effectiveness);
            mitigation_bonus += effectiveness_score;
        }

        return positive_score - negative_score + (mitigation_bonus * 0.5);
    }

    fn magnitudeToScore(magnitude: ImpactMagnitude) f64 {
        return switch (magnitude) {
            .negligible => 5,
            .minor => 15,
            .moderate => 30,
            .major => 50,
            .transformative => 100,
        };
    }

    fn severityToScore(severity: RiskSeverity) f64 {
        return switch (severity) {
            .low => 5,
            .medium => 20,
            .high => 50,
            .critical => 100,
        };
    }

    fn effectivenessToScore(effectiveness: Effectiveness) f64 {
        return switch (effectiveness) {
            .unproven => 5,
            .partial => 20,
            .significant => 50,
            .complete => 100,
        };
    }

    /// Format as ICLR submission text
    pub fn formatSubmission(self: BroaderImpact, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 4096);
        defer buffer.deinit(allocator);

        // Header
        try buffer.appendSlice(allocator, "# Broader Impact Statement\n\n");

        // Positive impacts
        try buffer.appendSlice(allocator, "## Positive Impacts\n\n");
        if (self.beneficiaries.len == 0) {
            try buffer.appendSlice(allocator, "This work primarily contributes to the research community.\n\n");
        } else {
            for (self.beneficiaries) |b| {
                try buffer.appendSlice(allocator, "### ");
                try buffer.appendSlice(allocator, b.group);
                try buffer.appendSlice(allocator, "\n\n");
                try buffer.appendSlice(allocator, b.benefit);
                try buffer.appendSlice(allocator, "\n\n**Impact Magnitude**: ");
                try buffer.appendSlice(allocator, b.magnitude.name());
                try buffer.appendSlice(allocator, "\n\n");
            }
        }

        // Potential negative impacts
        try buffer.appendSlice(allocator, "## Potential Negative Impacts\n\n");
        if (self.risks.len == 0) {
            try buffer.appendSlice(allocator, "We have identified no significant negative impacts associated with this work.\n\n");
        } else {
            for (self.risks) |r| {
                try buffer.appendSlice(allocator, "### Risk: ");
                try buffer.appendSlice(allocator, r.risk);
                try buffer.appendSlice(allocator, "\n\n");
                try buffer.appendSlice(allocator, "**Affected Group**: ");
                try buffer.appendSlice(allocator, r.group);
                try buffer.appendSlice(allocator, "\n");
                try buffer.print(allocator, "**Severity**: {s} (likelihood: {d:.0}%)\n", .{ r.severity.name(), @as(u32, @intFromFloat(r.likelihood * 100)) });
                try buffer.appendSlice(allocator, "\n");
            }
        }

        // Mitigation strategies
        try buffer.appendSlice(allocator, "## Mitigation Strategies\n\n");
        if (self.mitigations.len == 0) {
            try buffer.appendSlice(allocator, "We will monitor for emerging risks and address them as needed.\n\n");
        } else {
            for (self.mitigations) |m| {
                try buffer.appendSlice(allocator, "### ");
                try buffer.appendSlice(allocator, m.risk);
                try buffer.appendSlice(allocator, "\n\n");
                try buffer.appendSlice(allocator, "**Strategy**: ");
                try buffer.appendSlice(allocator, m.strategy);
                try buffer.appendSlice(allocator, "\n");
                try buffer.appendSlice(allocator, "**Effectiveness**: ");
                try buffer.appendSlice(allocator, m.effectiveness.name());
                try buffer.appendSlice(allocator, "\n\n");
            }
        }

        // Long-term consequences
        try buffer.appendSlice(allocator, "## Long-Term Consequences\n\n");
        if (self.long_term.len == 0) {
            try buffer.appendSlice(allocator, "We believe this work will contribute positively to the field, though long-term effects are inherently uncertain.\n\n");
        } else {
            for (self.long_term) |c| {
                try buffer.print(allocator, "### {s}: {s}\n\n", .{ c.direction.name(), c.description });
                try buffer.appendSlice(allocator, c.consequence);
                try buffer.appendSlice(allocator, "\n\n");
            }
        }

        // Overall assessment
        try buffer.appendSlice(allocator, "---\n\n");
        const score = self.impactScore();
        try buffer.print(allocator, "**Overall Impact Score**: {d:.1} (range: -100 to +100)\n\n", .{score});
        if (score > 50) {
            try buffer.appendSlice(allocator, "✅ The positive impacts significantly outweigh the risks.\n");
        } else if (score > 0) {
            try buffer.appendSlice(allocator, "⚠️ Positive impacts outweigh risks, but mitigation is important.\n");
        } else {
            try buffer.appendSlice(allocator, "❌ Risks may outweigh benefits; reconsideration recommended.\n");
        }

        return buffer.toOwnedSlice(allocator);
    }
};

pub const Beneficiary = struct {
    /// Group that benefits
    group: []const u8,

    /// Description of benefit
    benefit: []const u8,

    /// Magnitude of impact
    magnitude: ImpactMagnitude,
};

pub const ImpactMagnitude = enum {
    negligible,
    minor,
    moderate,
    major,
    transformative,

    fn name(self: ImpactMagnitude) []const u8 {
        return switch (self) {
            .negligible => "Negligible",
            .minor => "Minor",
            .moderate => "Moderate",
            .major => "Major",
            .transformative => "Transformative",
        };
    }
};

pub const Risk = struct {
    /// Group at risk
    group: []const u8,

    /// Description of risk
    risk: []const u8,

    /// Severity level
    severity: RiskSeverity,

    /// Likelihood (0-1)
    likelihood: f64,
};

pub const RiskSeverity = enum {
    low,
    medium,
    high,
    critical,

    fn name(self: RiskSeverity) []const u8 {
        return switch (self) {
            .low => "Low",
            .medium => "Medium",
            .high => "High",
            .critical => "Critical",
        };
    }
};

pub const Mitigation = struct {
    /// Risk being mitigated (references risk description)
    risk: []const u8,

    /// Mitigation strategy
    strategy: []const u8,

    /// Effectiveness assessment
    effectiveness: Effectiveness,
};

pub const Effectiveness = enum {
    unproven,
    partial,
    significant,
    complete,

    fn name(self: Effectiveness) []const u8 {
        return switch (self) {
            .unproven => "Unproven",
            .partial => "Partial",
            .significant => "Significant",
            .complete => "Complete",
        };
    }
};

pub const Consequence = struct {
    /// Direction: positive or negative
    direction: ConsequenceDirection,

    /// Description
    description: []const u8,

    /// Detailed consequence
    consequence: []const u8,
};

pub const ConsequenceDirection = enum {
    positive,
    negative,
    uncertain,

    fn name(self: ConsequenceDirection) []const u8 {
        return switch (self) {
            .positive => "Positive",
            .negative => "Negative",
            .uncertain => "Uncertain",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PRESETS
// ═══════════════════════════════════════════════════════════════════════════════

/// Default broader impact for ML framework publications
pub fn defaultMLFrameworkImpact(allocator: std.mem.Allocator) !BroaderImpact {
    const beneficiaries = try allocator.alloc(Beneficiary, 3);
    beneficiaries[0] = .{
        .group = "Research Community",
        .benefit = "Open-source implementation enables reproducibility and further research in ternary neural networks.",
        .magnitude = .major,
    };
    beneficiaries[1] = .{
        .group = "Edge Computing Developers",
        .benefit = "Zero-DSP FPGA deployment enables efficient ML on resource-constrained devices.",
        .magnitude = .moderate,
    };
    beneficiaries[2] = .{
        .group = "Open Science Community",
        .benefit = "Full FAIR compliance and comprehensive documentation serve as a model for reproducible research.",
        .magnitude = .moderate,
    };

    const risks = try allocator.alloc(Risk, 2);
    risks[0] = .{
        .group = "Environment",
        .risk = "Training large models requires significant computational resources, contributing to carbon emissions.",
        .severity = .medium,
        .likelihood = 0.7,
    };
    risks[1] = .{
        .group = "General Public",
        .risk = "Like any language model technology, this could potentially be misused for generating misinformation.",
        .severity = .low,
        .likelihood = 0.3,
    };

    const mitigations = try allocator.alloc(Mitigation, 2);
    mitigations[0] = .{
        .risk = "Environmental impact",
        .strategy = "V17 environmental tracking module reports carbon emissions, encouraging responsible usage. Zero-DSP architecture reduces inference energy by 20x vs baseline.",
        .effectiveness = .significant,
    };
    mitigations[1] = .{
        .risk = "Misuse potential",
        .strategy = "CC-BY-4.0 license requires attribution. Documentation includes intended use cases and limitations.",
        .effectiveness = .partial,
    };

    const long_term = try allocator.alloc(Consequence, 2);
    long_term[0] = .{
        .direction = .positive,
        .description = "Sustainable AI",
        .consequence = "Advances in ternary architectures and neuromorphic computing could lead to more energy-efficient AI systems overall.",
    };
    long_term[1] = .{
        .direction = .uncertain,
        .description = "Unforeseen Applications",
        .consequence = "As with any new technology, novel applications may emerge—continuous community review and ethical consideration are essential.",
    };

    return BroaderImpact{
        .beneficiaries = beneficiaries,
        .risks = risks,
        .mitigations = mitigations,
        .long_term = long_term,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BroaderImpact: impact score calculation" {
    const impact = BroaderImpact{
        .beneficiaries = &[_]Beneficiary{
            .{ .group = "Researchers", .benefit = "Better tools", .magnitude = .major },
            .{ .group = "Students", .benefit = "Learning", .magnitude = .moderate },
        },
        .risks = &[_]Risk{
            .{ .group = "Environment", .risk = "Carbon", .severity = .medium, .likelihood = 0.5 },
        },
        .mitigations = &[_]Mitigation{
            .{ .risk = "Carbon", .strategy = "Tracking", .effectiveness = .significant },
        },
        .long_term = &[_]Consequence{},
    };

    const score = impact.impactScore();
    try std.testing.expect(score > 0); // Should be positive overall
}

test "BroaderImpact: submission formatting" {
    const impact = BroaderImpact{
        .beneficiaries = &[_]Beneficiary{
            .{ .group = "Test", .benefit = "Benefit", .magnitude = .minor },
        },
        .risks = &[_]Risk{},
        .mitigations = &[_]Mitigation{},
        .long_term = &[_]Consequence{},
    };

    const output = try impact.formatSubmission(std.testing.allocator);
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "Broader Impact Statement") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Positive Impacts") != null);
}

test "BroaderImpact: default ML framework impact" {
    const impact = try defaultMLFrameworkImpact(std.testing.allocator);
    defer {
        std.testing.allocator.free(impact.beneficiaries);
        std.testing.allocator.free(impact.risks);
        std.testing.allocator.free(impact.mitigations);
        std.testing.allocator.free(impact.long_term);
    }

    const score = impact.impactScore();
    try std.testing.expect(score > 20); // Should have positive score

    const output = try impact.formatSubmission(std.testing.allocator);
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "Research Community") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Edge Computing") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "FAIR compliance") != null);
}

test "ConsequenceDirection: name formatting" {
    try std.testing.expectEqualStrings("Positive", ConsequenceDirection.positive.name());
    try std.testing.expectEqualStrings("Negative", ConsequenceDirection.negative.name());
    try std.testing.expectEqualStrings("Uncertain", ConsequenceDirection.uncertain.name());
}

test "RiskSeverity: name formatting" {
    try std.testing.expectEqualStrings("Low", RiskSeverity.low.name());
    try std.testing.expectEqualStrings("Critical", RiskSeverity.critical.name());
}

// φ² + 1/φ² = 3 | TRINITY
