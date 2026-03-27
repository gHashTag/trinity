// ═══════════════════════════════════════════════════════════════════════════════
// Zenodo V17: FAIR Score Calculator
// ═══════════════════════════════════════════════════════════════════════════════
//
// FAIR Principles (Wilkinson et al. 2016, Scientific Data)
// - Findable: F1F (Identifier), F2F (Metadata), F3F (Search), F4F (Identify)
// - Accessible: A1 (Protocol), A2 (Authentication), A1.1 (Metadata access)
// - Interoperable: I1 (Format), I2 (Vocabulary), I3 (References)
// - Reusable: R1 (License), R1.1 (Provenance), R1.2 (Community standards)
//
// NeurIPS 2025 Dataset Track Requirement: FAIR score ≥ 80/100
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// ZENODO METADATA TYPES (minimal subset for V17)
// ═══════════════════════════════════════════════════════════════════════════════

/// Zenodo access rights
pub const ZenodoAccessRight = enum {
    open,
    embargoed,
    restricted,
    closed,
};

/// Minimal Zenodo metadata for V17 calculations
pub const ZenodoMetadata = struct {
    title: []const u8 = "",
    authors: []const []const u8 = &.{},
    description: []const u8 = "",
    access_right: ZenodoAccessRight = .open,
    publication_year: u16 = 0,
    keywords: []const []const u8 = &.{},
    formats: []const []const u8 = &.{},
    references: []const []const u8 = &.{},
    communities: []const []const u8 = &.{},
    license: ?[]const u8 = null,
    doi: ?[]const u8 = null,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// FAIR Score Components (0-100 each)
pub const FairScore = struct {
    findable: u8 = 0,
    accessible: u8 = 0,
    interoperable: u8 = 0,
    reusable: u8 = 0,

    /// Overall FAIR score (0-100)
    pub fn overall(self: FairScore) f64 {
        return (@as(f64, @floatFromInt(self.findable)) +
            @as(f64, @floatFromInt(self.accessible)) +
            @as(f64, @floatFromInt(self.interoperable)) +
            @as(f64, @floatFromInt(self.reusable))) / 4.0;
    }

    /// Letter grade (A/B/C/D/F)
    pub fn grade(self: FairScore) []const u8 {
        const score = self.overall();
        if (score >= 90) return "A";
        if (score >= 80) return "B";
        if (score >= 70) return "C";
        if (score >= 60) return "D";
        return "F";
    }

    /// Detailed breakdown text
    pub fn format(self: FairScore, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\FAIR Score: {d:.0}/100 (Grade: {s})
            \\├─ Findable (F): {d}/100
            \\├─ Accessible (A): {d}/100
            \\├─ Interoperable (I): {d}/100
            \\└─ Reusable (R): {d}/100
        , .{
            self.overall(),     self.grade(),
            self.findable,      self.accessible,
            self.interoperable, self.reusable,
        });
    }
};

/// FAIR Checklist Item
pub const ChecklistItem = struct {
    id: []const u8,
    name: []const u8,
    description: []const u8,
    score: u8,
    max_score: u8,
    passed: bool,
};

/// FAIR Assessment Result
pub const FairAssessment = struct {
    score: FairScore,
    checklist: []ChecklistItem,
    recommendations: [][]const u8,

    pub fn formatDetailed(self: FairAssessment, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 0);
        defer buffer.deinit(allocator);

        // Header
        try buffer.appendSlice(allocator, "═══════════════════════════════════════════════════════════════\n");
        try buffer.appendSlice(allocator, "FAIR PRINCIPLES ASSESSMENT (Wilkinson et al. 2016)\n");
        try buffer.appendSlice(allocator, "═══════════════════════════════════════════════════════════════\n\n");

        // Score
        const score_text = try self.score.format(allocator);
        defer allocator.free(score_text);
        try buffer.appendSlice(allocator, score_text);
        try buffer.appendSlice(allocator, "\n\n");

        // Checklist by principle
        try buffer.appendSlice(allocator, "Checklist:\n");

        for (self.checklist) |item| {
            const status = if (item.passed) "✅" else "❌";
            try buffer.print(allocator, "{s} {s}: {s} ({d}/{d})\n", .{
                status, item.id, item.name, item.score, item.max_score,
            });
        }

        try buffer.appendSlice(allocator, "\n");

        // Recommendations
        if (self.recommendations.len > 0) {
            try buffer.appendSlice(allocator, "Recommendations:\n");
            for (self.recommendations) |rec| {
                try buffer.print(allocator, "  • {s}\n", .{rec});
            }
        }

        try buffer.appendSlice(allocator, "\n");
        try buffer.appendSlice(allocator, "═══════════════════════════════════════════════════════════════\n");

        return buffer.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CALCULATION FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Calculate FAIR score from Zenodo metadata
pub fn calculateFairScore(allocator: std.mem.Allocator, metadata: ZenodoMetadata) !FairAssessment {
    var checklist = try std.ArrayList(ChecklistItem).initCapacity(allocator, 0);
    defer checklist.deinit(allocator);

    // Findable (F1F, F2F, F3F, F4F)
    const findable_score = try calculateFindable(allocator, metadata, &checklist);

    // Accessible (A1, A2, A1.1)
    const accessible_score = calculateAccessible(metadata);

    // Interoperable (I1, I2, I3)
    const interoperable_score = try calculateInteroperable(allocator, metadata, &checklist);

    // Reusable (R1, R1.1, R1.2)
    const reusable_score = try calculateReusable(allocator, metadata, &checklist);

    const score = FairScore{
        .findable = findable_score,
        .accessible = accessible_score,
        .interoperable = interoperable_score,
        .reusable = reusable_score,
    };

    // Generate recommendations
    var recommendations = try std.ArrayList([]const u8).initCapacity(allocator, 0);
    try generateRecommendations(allocator, score, &recommendations);

    return FairAssessment{
        .score = score,
        .checklist = try checklist.toOwnedSlice(allocator),
        .recommendations = try recommendations.toOwnedSlice(allocator),
    };
}

/// Calculate Findable score (F1F-F4F)
fn calculateFindable(
    allocator: std.mem.Allocator,
    metadata: ZenodoMetadata,
    checklist: *std.ArrayList(ChecklistItem),
) !u8 {
    var score: u8 = 0;

    // F1F: DOI assigned (25 points)
    const has_doi = metadata.doi != null and metadata.doi.?.len > 0;
    try checklist.append(allocator, .{
        .id = "F1F",
        .name = "Identifier (DOI)",
        .description = "Globally unique and persistent identifier",
        .score = if (has_doi) 25 else 0,
        .max_score = 25,
        .passed = has_doi,
    });
    if (has_doi) score += 25;

    // F2F: Rich metadata (25 points)
    const has_metadata = metadata.title.len > 0 and
        metadata.authors.len > 0 and
        metadata.description.len > 100;
    try checklist.append(allocator, .{
        .id = "F2F",
        .name = "Rich Metadata",
        .description = "Title, authors, description, keywords",
        .score = if (has_metadata) 25 else 0,
        .max_score = 25,
        .passed = has_metadata,
    });
    if (has_metadata) score += 25;

    // F3F: Searchable (25 points) - automatic on Zenodo
    try checklist.append(allocator, .{
        .id = "F3F",
        .name = "Searchable",
        .description = "Indexed by search engines",
        .score = 25,
        .max_score = 25,
        .passed = true,
    });
    score += 25;

    // F4F: Identifier in metadata (25 points)
    const doi_in_desc = metadata.doi != null and
        std.mem.indexOf(u8, metadata.description, metadata.doi.?) != null;
    try checklist.append(allocator, .{
        .id = "F4F",
        .name = "Identifier Quoted",
        .description = "DOI cited in metadata",
        .score = if (doi_in_desc) 25 else 0,
        .max_score = 25,
        .passed = doi_in_desc,
    });
    if (doi_in_desc) score += 25;

    return score;
}

/// Calculate Accessible score (A1, A2, A1.1)
fn calculateAccessible(metadata: ZenodoMetadata) u8 {
    var score: u8 = 0;

    // A1: Open access protocol (40 points)
    const is_open = metadata.access_right == ZenodoAccessRight.open;
    if (is_open) score += 40;

    // A2: No authentication required (30 points)
    // Zenodo provides this automatically
    score += 30;

    // A1.1: Metadata accessible (30 points)
    if (metadata.description.len > 0) score += 30;

    return score;
}

/// Calculate Interoperable score (I1-I3)
fn calculateInteroperable(
    allocator: std.mem.Allocator,
    metadata: ZenodoMetadata,
    checklist: *std.ArrayList(ChecklistItem),
) !u8 {
    var score: u8 = 0;

    // I1: Formal format (33 points)
    const has_format = metadata.formats.len > 0;
    try checklist.append(allocator, .{
        .id = "I1",
        .name = "Formal Format",
        .description = "Uses standard file formats",
        .score = if (has_format) 33 else 0,
        .max_score = 33,
        .passed = has_format,
    });
    if (has_format) score += 33;

    // I2: Vocabulary (33 points)
    const has_keywords = metadata.keywords.len > 0;
    try checklist.append(allocator, .{
        .id = "I2",
        .name = "Vocabulary",
        .description = "Uses controlled keywords",
        .score = if (has_keywords) 33 else 0,
        .max_score = 33,
        .passed = has_keywords,
    });
    if (has_keywords) score += 33;

    // I3: References (34 points)
    const has_refs = metadata.references.len > 0;
    try checklist.append(allocator, .{
        .id = "I3",
        .name = "Qualified References",
        .description = "Cites related works",
        .score = if (has_refs) 34 else 0,
        .max_score = 34,
        .passed = has_refs,
    });
    if (has_refs) score += 34;

    return score;
}

/// Calculate Reusable score (R1-R1.2)
fn calculateReusable(
    allocator: std.mem.Allocator,
    metadata: ZenodoMetadata,
    checklist: *std.ArrayList(ChecklistItem),
) !u8 {
    var score: u8 = 0;

    // R1: License (40 points)
    const has_license = metadata.license != null and metadata.license.?.len > 0;
    try checklist.append(allocator, .{
        .id = "R1",
        .name = "License",
        .description = "Clear usage license specified",
        .score = if (has_license) 40 else 0,
        .max_score = 40,
        .passed = has_license,
    });
    if (has_license) score += 40;

    // R1.1: Provenance (30 points)
    const has_provenance = metadata.publication_year > 2000;
    try checklist.append(allocator, .{
        .id = "R1.1",
        .name = "Provenance",
        .description = "Origin and history documented",
        .score = if (has_provenance) 30 else 0,
        .max_score = 30,
        .passed = has_provenance,
    });
    if (has_provenance) score += 30;

    // R1.2: Community standards (30 points)
    const has_community = metadata.communities.len > 0;
    try checklist.append(allocator, .{
        .id = "R1.2",
        .name = "Community Standards",
        .description = "Follows domain standards",
        .score = if (has_community) 30 else 0,
        .max_score = 30,
        .passed = has_community,
    });
    if (has_community) score += 30;

    return score;
}

/// Generate improvement recommendations
fn generateRecommendations(
    allocator: std.mem.Allocator,
    score: FairScore,
    recommendations: *std.ArrayList([]const u8),
) !void {
    if (score.findable < 100) {
        try recommendations.append(allocator, "Add DOI to description metadata");
    }
    if (score.accessible < 100) {
        try recommendations.append(allocator, "Set access_right to 'open'");
    }
    if (score.interoperable < 100) {
        try recommendations.append(allocator, "Add machine-readable metadata (JSON-LD)");
        try recommendations.append(allocator, "Specify vocabulary (schema.org, DataCite)");
    }
    if (score.reusable < 100) {
        try recommendations.append(allocator, "Add community-specific standards");
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "FAIR score: minimal metadata" {
    const metadata = ZenodoMetadata{
        .title = "Test",
        .authors = &[_][]const u8{"Test Author"},
        .description = "Test",
        .access_right = .open,
        .publication_year = 2025,
        .keywords = &[_][]const u8{},
        .formats = &[_][]const u8{},
        .references = &[_][]const u8{},
        .communities = &[_][]const u8{},
        .license = null,
        .doi = null,
    };

    const assessment = try calculateFairScore(std.testing.allocator, metadata);
    defer {
        std.testing.allocator.free(assessment.checklist);
        std.testing.allocator.free(assessment.recommendations);
    }

    // Minimal metadata should score below 50
    try std.testing.expect(assessment.score.overall() < 50);
}

test "FAIR score: full metadata" {
    const metadata = ZenodoMetadata{
        .title = "Trinity HSLM v1.0",
        .authors = &[_][]const u8{"Research Team"},
        .description = "Hyper-Sacred Language Model with 1.9M parameters. DOI: 10.5281/zenodo.19227865",
        .access_right = .open,
        .publication_year = 2025,
        .keywords = &[_][]const u8{ "machine learning", "ternary computing" },
        .formats = &[_][]const u8{ "application/zig", "application/json" },
        .references = &[_][]const u8{"10.5281/zenodo.19227863"},
        .communities = &[_][]const u8{ "zenodo", "machine-learning" },
        .license = "MIT",
        .doi = "10.5281/zenodo.19227865",
    };

    const assessment = try calculateFairScore(std.testing.allocator, metadata);
    defer {
        std.testing.allocator.free(assessment.checklist);
        std.testing.allocator.free(assessment.recommendations);
    }

    // Full metadata should score >= 90
    try std.testing.expect(assessment.score.overall() >= 90);
    try std.testing.expectEqualStrings("A", assessment.score.grade());
}

test "FAIR grade boundaries" {
    const score_a = FairScore{ .findable = 95, .accessible = 90, .interoperable = 88, .reusable = 92 };
    try std.testing.expectEqualStrings("A", score_a.grade());

    const score_b = FairScore{ .findable = 85, .accessible = 80, .interoperable = 78, .reusable = 82 };
    try std.testing.expectEqualStrings("B", score_b.grade());

    const score_f = FairScore{ .findable = 30, .accessible = 40, .interoperable = 35, .reusable = 25 };
    try std.testing.expectEqualStrings("F", score_f.grade());
}

test "FAIR assessment formatting" {
    const metadata = ZenodoMetadata{
        .title = "Test",
        .authors = &[_][]const u8{"Author"},
        .description = "Test description",
        .access_right = .open,
        .publication_year = 2025,
        .keywords = &[_][]const u8{},
        .formats = &[_][]const u8{},
        .references = &[_][]const u8{},
        .communities = &[_][]const u8{},
        .license = "MIT",
        .doi = "10.5281/test",
    };

    const assessment = try calculateFairScore(std.testing.allocator, metadata);
    defer {
        std.testing.allocator.free(assessment.checklist);
        std.testing.allocator.free(assessment.recommendations);
    }

    const formatted = try assessment.formatDetailed(std.testing.allocator);
    defer std.testing.allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "FAIR PRINCIPLES ASSESSMENT") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Wilkinson") != null);
}

// φ² + 1/φ² = 3 | TRINITY
