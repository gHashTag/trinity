//! Zenodo V21: Broader Impact Statement Generator for NeurIPS/ICLR 2025
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Generates structured broader impact statements required by top ML conferences.
//! Implements NeurIPS 2025 and ICLR 2025 broader impact guidelines.
//!
//! References:
//! - NeurIPS 2025: Broader Impact Statement Guide
//! - ICLR 2025: Ethical Statement Requirements
//! - ACM FAccT: Impact Assessment Framework

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// BROADER IMPACT STATEMENT STRUCTURES
// ============================================================================

/// Risk level assessment
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

    pub fn color(self: RiskLevel) []const u8 {
        return switch (self) {
            .negligible => "🟢",
            .low => "🟡",
            .medium => "🟠",
            .high => "🔴",
            .critical => "⚫",
        };
    }
};

/// Risk assessment entry
pub const RiskAssessment = struct {
    /// Risk description
    name: []const u8,
    /// Likelihood (1-5)
    likelihood: RiskLevel,
    /// Impact severity (1-5)
    impact: RiskLevel,
    /// Mitigation strategies
    mitigations: []const []const u8,
    /// Overall risk score (likelihood × impact)
    pub fn score(self: RiskAssessment) u4 {
        return self.likelihood.score() * self.impact.score();
    }
};

/// Impact category
pub const ImpactCategory = enum {
    /// Environmental impact (energy, emissions, e-waste)
    environmental,
    /// Societal impact (bias, fairness, accessibility)
    societal,
    /// Economic impact (job displacement, market effects)
    economic,
    /// Security impact (adversarial attacks, dual-use)
    security,
    /// Privacy impact (data protection, surveillance)
    privacy,
};

/// Impact statement component
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

/// Complete broader impact statement
pub const BroaderImpactStatement = struct {
    /// Primary intended uses
    primary_uses: []const []const u8,
    /// Potential misuses
    misuses: []const []const u8,
    /// Impact statements by category
    impacts: []const ImpactStatement,
    /// Risk assessments
    risks: []const RiskAssessment,
    /// Overall ethical considerations
    ethical_considerations: []const []const u8,

    /// Generate NeurIPS-formatted broader impact statement
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

        try buffer.appendSlice(allocator, "\n## Risk Assessment\n\n");
        try buffer.appendSlice(allocator,
            \\| Risk | Likelihood | Impact | Score | Mitigation |
            \\|------|------------|--------|-------|------------|
        );

        for (self.risks) |risk| {
            try buffer.appendSlice(allocator, "| ");
            try buffer.appendSlice(allocator, risk.name);
            try buffer.appendSlice(allocator, " | ");
            try buffer.appendSlice(allocator, risk.likelihood.color());
            try buffer.appendSlice(allocator, " ");
            try buffer.print(allocator, "{d}", .{risk.likelihood.score()});
            try buffer.appendSlice(allocator, " | ");
            try buffer.appendSlice(allocator, risk.impact.color());
            try buffer.print(allocator, " {d}", .{risk.impact.score()});
            try buffer.appendSlice(allocator, " | **");
            try buffer.print(allocator, "{d}**", .{risk.score()});
            try buffer.appendSlice(allocator, " | ");

            if (risk.mitigations.len > 0) {
                try buffer.appendSlice(allocator, risk.mitigations[0]);
                if (risk.mitigations.len > 1) {
                    try buffer.print(allocator, " (+{d} more)", .{risk.mitigations.len - 1});
                }
            }
            try buffer.appendSlice(allocator, " |\n");
        }

        try buffer.appendSlice(allocator, "\n## Ethical Considerations\n\n");

        for (self.ethical_considerations) |consideration| {
            try buffer.appendSlice(allocator, "- ");
            try buffer.appendSlice(allocator, consideration);
            try buffer.appendSlice(allocator, "\n");
        }

        try buffer.appendSlice(allocator, "\n---\n\nφ² + 1/φ² = 3 | TRINITY\n");

        return buffer.toOwnedSlice(allocator);
    }

    /// Generate ICLR-formatted ethical statement
    pub fn formatIclr(self: *const BroaderImpactStatement, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayListUnmanaged(u8){};
        defer buffer.deinit(allocator);

        try buffer.appendSlice(allocator,
            \\# Ethical Statement
            \\
            \\## Potential Societal Consequences
            \\
        );

        for (self.primary_uses) |use_| {
            try buffer.appendSlice(allocator, "- ");
            try buffer.appendSlice(allocator, use_);
            try buffer.appendSlice(allocator, "\n");
        }

        try buffer.appendSlice(allocator, "\n## Dual-Use Concerns\n\n");

        for (self.misuses) |misuse| {
            try buffer.appendSlice(allocator, "- ");
            try buffer.appendSlice(allocator, misuse);
            try buffer.appendSlice(allocator, "\n");
        }

        try buffer.appendSlice(allocator, "\n## Data Privacy and Consent\n\n");

        // Find privacy impact
        for (self.impacts) |impact| {
            if (impact.category == .privacy) {
                const formatted = try impact.format(allocator);
                defer allocator.free(formatted);
                try buffer.appendSlice(allocator, formatted);
                try buffer.appendSlice(allocator, "\n");
            }
        }

        try buffer.appendSlice(allocator, "\n## Environmental Impact\n\n");

        // Find environmental impact
        for (self.impacts) |impact| {
            if (impact.category == .environmental) {
                const formatted = try impact.format(allocator);
                defer allocator.free(formatted);
                try buffer.appendSlice(allocator, formatted);
                try buffer.appendSlice(allocator, "\n");
            }
        }

        try buffer.appendSlice(allocator, "\n## Mitigation Strategies\n\n");

        for (self.risks) |risk| {
            if (risk.mitigations.len > 0) {
                try buffer.appendSlice(allocator, "**");
                try buffer.appendSlice(allocator, risk.name);
                try buffer.appendSlice(allocator, ":**\n");
                for (risk.mitigations) |mitigation| {
                    try buffer.appendSlice(allocator, "- ");
                    try buffer.appendSlice(allocator, mitigation);
                    try buffer.appendSlice(allocator, "\n");
                }
                try buffer.appendSlice(allocator, "\n");
            }
        }

        try buffer.appendSlice(allocator, "\n---\n\nφ² + 1/φ² = 3 | TRINITY\n");

        return buffer.toOwnedSlice(allocator);
    }
};

// ============================================================================
// TRINITY-SPECIFIC PRESETS
// ============================================================================

/// Default broader impact statement for Trinity S³AI
pub fn defaultTrinityImpact(_: Allocator) !BroaderImpactStatement {
    const primary_uses = [_][]const u8{
        "Energy-efficient AI inference on edge devices (IoT, mobile, embedded)",
        "Natural language processing on microcontrollers",
        "Scientific computing in field deployments",
        "On-device AI for privacy-preserving applications",
    };

    const misuses = [_][]const u8{
        "Surveillance: Low-power AI could enable pervasive monitoring",
        "Autonomous Weapons: Ternary computing could enable military applications",
        "Adversarial Attacks: Efficient models lower barrier for attackers",
    };

    const environmental_impact = ImpactStatement{
        .category = .environmental,
        .positive_impacts = &[_][]const u8{
            "1.2W power vs 200W GPU = 99.4% energy reduction",
            "Enables carbon-neutral AI deployment",
            "Reduces datacenter cooling requirements",
        },
        .negative_impacts = &[_][]const u8{
            "Increased AI deployment may increase overall compute demand (Jevons paradox)",
            "E-waste from FPGA manufacturing",
        },
        .mitigations = &[_][]const u8{
            "Design for longevity and repairability",
            "Use lead-free solder and recyclable materials",
            "Provide end-of-life recycling programs",
        },
    };

    const societal_impact = ImpactStatement{
        .category = .societal,
        .positive_impacts = &[_][]const u8{
            "Open-source promotes democratization of AI",
            "On-device inference avoids data transmission (privacy)",
            "Enables AI in resource-constrained regions",
        },
        .negative_impacts = &[_][]const u8{
            "Training data may contain societal biases",
            "Low barrier to entry may enable malicious uses",
        },
        .mitigations = &[_][]const u8{
            "Auditing tools for bias detection",
            "Diverse training data requirements",
            "Responsible use documentation",
        },
    };

    const security_impact = ImpactStatement{
        .category = .security,
        .positive_impacts = &[_][]const u8{
            "On-device processing reduces attack surface",
            "Open-source allows security auditing",
        },
        .negative_impacts = &[_][]const u8{
            "Ternary models may have unique adversarial vulnerabilities",
            "FPGA bitstreams could be extracted and cloned",
        },
        .mitigations = &[_][]const u8{
            "Adversarial training robustness",
            "Bitstream encryption and authentication",
            "Regular security audits",
        },
    };

    const privacy_impact = ImpactStatement{
        .category = .privacy,
        .positive_impacts = &[_][]const u8{
            "On-device inference avoids data transmission",
            "No cloud dependency for processing",
            "User controls their own data",
        },
        .negative_impacts = &[_][]const u8{
            "Model inversion attacks still possible",
            "Side-channel attacks on FPGA",
        },
        .mitigations = &[_][]const u8{
            "Differential privacy training",
            "Secure enclaves for sensitive data",
            "Side-channel resistance design",
        },
    };

    const risks = [_]RiskAssessment{
        .{
            .name = "Hardware Failure",
            .likelihood = .medium,
            .impact = .low,
            .mitigations = &[_][]const u8{
                "Redundancy and fallback mechanisms",
                "Comprehensive testing and validation",
            },
        },
        .{
            .name = "Adversarial Attacks",
            .likelihood = .medium,
            .impact = .medium,
            .mitigations = &[_][]const u8{
                "Robustness training",
                "Input sanitization",
                "Adversarial detection",
            },
        },
        .{
            .name = "Supply Chain Disruption",
            .likelihood = .low,
            .impact = .high,
            .mitigations = &[_][]const u8{
                "Multi-source FPGA procurement",
                "Design portability across vendors",
            },
        },
        .{
            .name = "Misuse for Surveillance",
            .likelihood = .medium,
            .impact = .high,
            .mitigations = &[_][]const u8{
                "Explicit dual-use licensing restrictions",
                "Refusal of military contracts",
                "Transparency reports",
            },
        },
    };

    const ethical_considerations = [_][]const u8{
        "**Accessibility**: Open-source design promotes global accessibility",
        "**Bias**: We acknowledge potential biases in training data and commit to ongoing audits",
        "**Transparency**: All research, code, and data are openly published",
        "**Accountability**: Clear guidelines for responsible use are provided",
        "**Privacy-by-Design**: On-device processing minimizes data exposure",
    };

    return BroaderImpactStatement{
        .primary_uses = &primary_uses,
        .misuses = &misuses,
        .impacts = &[_]ImpactStatement{
            environmental_impact,
            societal_impact,
            security_impact,
            privacy_impact,
        },
        .risks = &risks,
        .ethical_considerations = &ethical_considerations,
    };
}

// ============================================================================
// TESTS
// ============================================================================

test "RiskLevel: scoring" {
    try std.testing.expectEqual(@as(u4, 1), RiskLevel.negligible.score());
    try std.testing.expectEqual(@as(u4, 2), RiskLevel.low.score());
    try std.testing.expectEqual(@as(u4, 3), RiskLevel.medium.score());
    try std.testing.expectEqual(@as(u4, 4), RiskLevel.high.score());
    try std.testing.expectEqual(@as(u4, 5), RiskLevel.critical.score());
}

test "RiskAssessment: overall score" {
    const risk = RiskAssessment{
        .name = "Test",
        .likelihood = .medium,
        .impact = .high,
        .mitigations = &.{},
    };
    try std.testing.expectEqual(@as(u4, 12), risk.score()); // 3 × 4
}

test "ImpactStatement: formatting" {
    const allocator = std.testing.allocator;

    const impact = ImpactStatement{
        .category = .environmental,
        .positive_impacts = &[_][]const u8{"Low power usage"},
        .negative_impacts = &[_][]const u8{"E-waste"},
        .mitigations = &[_][]const u8{"Recycling program"},
    };

    const formatted = try impact.format(allocator);
    defer allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "Environmental Impact") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Low power usage") != null);
}

test "BroaderImpactStatement: NeurIPS format" {
    const allocator = std.testing.allocator;

    const statement = try defaultTrinityImpact(allocator);

    const neurips = try statement.formatNeurips(allocator);
    defer allocator.free(neurips);

    try std.testing.expect(std.mem.indexOf(u8, neurips, "Broader Impact Statement") != null);
    try std.testing.expect(std.mem.indexOf(u8, neurips, "Primary Intended Use") != null);
    try std.testing.expect(std.mem.indexOf(u8, neurips, "Risk Assessment") != null);
}

test "BroaderImpactStatement: ICLR format" {
    const allocator = std.testing.allocator;

    const statement = try defaultTrinityImpact(allocator);

    const iclr = try statement.formatIclr(allocator);
    defer allocator.free(iclr);

    try std.testing.expect(std.mem.indexOf(u8, iclr, "Ethical Statement") != null);
    try std.testing.expect(std.mem.indexOf(u8, iclr, "Potential Societal Consequences") != null);
}

test "BroaderImpactStatement: risk score calculation" {
    const allocator = std.testing.allocator;

    const statement = try defaultTrinityImpact(allocator);

    // Check that all risks have valid scores
    for (statement.risks) |risk| {
        const score = risk.score();
        try std.testing.expect(score >= 1 and score <= 25); // Min: 1×1, Max: 5×5
    }
}

// φ² + 1/φ² = 3 | TRINITY
