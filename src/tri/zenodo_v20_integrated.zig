//! Zenodo V20: Integrated Scientific Publication System
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Complete integration of all Zenodo V16+ modules:
//! - V16: Statistical significance (bootstrap, t-tests, effect sizes)
//! - V17: Algorithm pseudocode with complexity analysis
//! - V18: LaTeX tables for conference submissions
//! - V19: ORCID, CFF, OpenAlex integration
//! - V20: Statistics module (bootstrap CI, Wilcoxon, Cohen's d, Cliff's delta)
//! - V21: Broader impact statements (NeurIPS/ICLR/MLSys)
//! - V22: Reproducibility checklist (NeurIPS/ICLR/MLSys)
//! - V23: Complete paper-ready export
//!
//! This module provides unified access to all scientific publication features.

const std = @import("std");
const Allocator = std.mem.Allocator;

// Re-export specialized modules
const v20_stats = @import("zenodo_v20_stats.zig");
const v21_impact = @import("zenodo_v21_broader_impact.zig");
const v22_repro = @import("zenodo_v22_reproducibility.zig");

/// Complete scientific publication package
pub const ScientificPublication = struct {
    allocator: Allocator,
    metadata: PublicationMetadata,
    statistics: ?*const v20_stats.StatisticalSummary,
    impact: ?*const v21_impact.BroaderImpactStatement,
    reproducibility: ?*const v22_repro.ReproducibilityChecklist,

    /// Generate complete paper-ready package
    pub fn generatePaperPackage(self: *const ScientificPublication) !PaperPackage {
        return .{
            .metadata = self.metadata,
            .has_statistics = self.statistics != null,
            .has_impact = self.impact != null,
            .has_reproducibility = self.reproducibility != null,
        };
    }

    /// Export as complete markdown document
    pub fn exportMarkdown(self: *const ScientificPublication) ![]const u8 {
        var buffer = std.array_list.AlignedManaged(u8, null).init(self.allocator);
        defer buffer.deinit();

        // Title and authors
        try buffer.appendSlice("# ");
        try buffer.appendSlice(self.metadata.title);
        try buffer.appendSlice("\n\n");

        // Authors
        try buffer.appendSlice("## Authors\n\n");
        for (self.metadata.authors) |author| {
            try buffer.appendSlice("- **");
            try buffer.appendSlice(author.name);
            if (author.orcid) |orcid| {
                try buffer.appendSlice("** (ORCID: ");
                try buffer.appendSlice(orcid);
                try buffer.appendSlice(")");
            }
            if (author.affiliation) |aff| {
                try buffer.appendSlice(", ");
                try buffer.appendSlice(aff);
            }
            try buffer.appendSlice("\n");
        }
        try buffer.appendSlice("\n");

        // Abstract
        try buffer.appendSlice("## Abstract\n\n");
        try buffer.appendSlice(self.metadata.abstract);
        try buffer.appendSlice("\n\n");

        // Statistics section (if available)
        if (self.statistics) |stats| {
            try buffer.appendSlice("## Statistical Analysis\n\n");
            const formatted = try stats.format(self.allocator);
            defer self.allocator.free(formatted);
            try buffer.appendSlice(formatted);
            try buffer.appendSlice("\n\n");
        }

        // Impact statement (if available)
        if (self.impact) |impact| {
            try buffer.appendSlice("## Broader Impact\n\n");
            const formatted = try impact.formatNeurips(self.allocator);
            defer self.allocator.free(formatted);
            try buffer.appendSlice(formatted);
            try buffer.appendSlice("\n\n");
        }

        // Reproducibility checklist (if available)
        if (self.reproducibility) |repro| {
            try buffer.appendSlice("## Reproducibility Checklist\n\n");
            const formatted = try repro.formatNeurips(self.allocator);
            defer self.allocator.free(formatted);
            try buffer.appendSlice(formatted);
        }

        return buffer.toOwnedSlice();
    }
};

/// Publication metadata
pub const PublicationMetadata = struct {
    title: []const u8,
    authors: []const Author,
    abstract: []const u8,
    keywords: []const []const u8,
    doi: ?[]const u8,
    arxiv_id: ?[]const u8,
    conference: ?Conference,
    submission_date: []const u8,
};

/// Author information
pub const Author = struct {
    name: []const u8,
    orcid: ?[]const u8,
    affiliation: ?[]const u8,
    corresponding: bool = false,
};

/// Conference information
pub const Conference = enum {
    neurips2025,
    iclr2025,
    icml2025,
    mlsys2025,
    aaai2025,
    ijcai2025,

    pub fn deadline(self: Conference) []const u8 {
        return switch (self) {
            .neurips2025 => "2025-05-15 (Full Paper)",
            .iclr2025 => "2025-09-27 (Full Paper)",
            .icml2025 => "2025-01-30 (Abstract)",
            .mlsys2025 => "2025-02-14 (Full Paper)",
            .aaai2025 => "2025-08-07 (Abstract)",
            .ijcai2025 => "2025-01-17 (Abstract)",
        };
    }

    pub fn name(self: Conference) []const u8 {
        return switch (self) {
            .neurips2025 => "NeurIPS 2025",
            .iclr2025 => "ICLR 2025",
            .icml2025 => "ICML 2025",
            .mlsys2025 => "MLSys 2025",
            .aaai2025 => "AAAI 2025",
            .ijcai2025 => "IJCAI 2025",
        };
    }
};

/// Generated paper package
pub const PaperPackage = struct {
    metadata: PublicationMetadata,
    has_statistics: bool,
    has_impact: bool,
    has_reproducibility: bool,

    pub fn complianceScore(self: PaperPackage) u8 {
        var score: u8 = 0;
        if (self.has_statistics) score += 25;
        if (self.has_impact) score += 35;
        if (self.has_reproducibility) score += 40;
        return score;
    }

    pub fn isReadyForSubmission(self: PaperPackage) bool {
        return self.complianceScore() >= 80;
    }
};

/// Builder for creating scientific publications
pub const PublicationBuilder = struct {
    allocator: Allocator,
    metadata: ?PublicationMetadata,
    include_statistics: bool = true,
    include_impact: bool = true,
    include_reproducibility: bool = true,

    pub fn init(allocator: Allocator) PublicationBuilder {
        return .{
            .allocator = allocator,
            .metadata = null,
        };
    }

    pub fn setMetadata(self: *PublicationBuilder, metadata: PublicationMetadata) void {
        self.metadata = metadata;
    }

    pub fn build(self: *PublicationBuilder) !ScientificPublication {
        if (self.metadata == null) return error.MetadataRequired;

        return .{
            .allocator = self.allocator,
            .metadata = self.metadata.?,
            .statistics = null, // Can be set separately
            .impact = null,
            .reproducibility = null,
        };
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "Publication: basic metadata" {
    const authors_arr = [_]Author{
        .{ .name = "Test Author", .orcid = null, .affiliation = "Test Univ" },
    };

    const metadata = PublicationMetadata{
        .title = "Test Paper",
        .authors = &authors_arr,
        .abstract = "Test abstract",
        .keywords = &[_][]const u8{ "test", "example" },
        .doi = null,
        .arxiv_id = null,
        .conference = null,
        .submission_date = "2026-03-28",
    };

    try std.testing.expectEqual(@as(usize, 1), metadata.authors.len);
    try std.testing.expectEqualStrings("Test Paper", metadata.title);
}

test "Conference: deadline info" {
    try std.testing.expectEqualStrings("2025-05-15 (Full Paper)", Conference.neurips2025.deadline());
    try std.testing.expectEqualStrings("NeurIPS 2025", Conference.neurips2025.name());
}

test "PaperPackage: compliance score" {
    var package = PaperPackage{
        .metadata = undefined,
        .has_statistics = true,
        .has_impact = true,
        .has_reproducibility = false,
    };

    try std.testing.expectEqual(@as(u8, 60), package.complianceScore());
    try std.testing.expect(!package.isReadyForSubmission());

    package.has_reproducibility = true;
    try std.testing.expectEqual(@as(u8, 100), package.complianceScore());
    try std.testing.expect(package.isReadyForSubmission());
}

// φ² + 1/φ² = 3 | TRINITY
