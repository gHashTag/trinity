//! Zenodo V19: OpenAlex + COAR Integration
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Scientific publication enhancements:
//! - OpenAlex work type classification
//! - COAR notification system
//! - Enhanced metadata validation
//!
//! @origin(manual) @regen(manual-impl)

const std = @import("std");

pub const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// OpenAlex Work Type Classification
// ═══════════════════════════════════════════════════════════════════════════════

/// OpenAlex work type classification
/// See: https://docs.openalex.org/api-schema/entities/works/
pub const WorkType = enum(u8) {
    /// Peer-reviewed journal article
    journal_article,
    /// Conference paper
    conference_paper,
    /// Preprint (arXiv, bioRxiv, etc.)
    preprint,
    /// Software code
    software,
    /// Dataset
    dataset,
    /// Book chapter
    chapter,
    /// PhD dissertation
    dissertation,
    /// Technical report
    report,
    /// Other/unknown
    other,

    pub fn jsonString(self: WorkType) []const u8 {
        return switch (self) {
            .journal_article => "journal-article",
            .conference_paper => "conference-paper",
            .preprint => "posted-content",
            .software => "software",
            .dataset => "dataset",
            .chapter => "book-chapter",
            .dissertation => "dissertation",
            .report => "report",
            .other => "other",
        };
    }
};

/// Bundle specification summary for classification
pub const BundleSpec = struct {
    has_types: bool = false,
    has_algorithms: bool = false,
    has_behaviors: bool = false,
    has_constants: bool = false,
    has_tests: bool = false,
    title: []const u8,

    /// Classify bundle into OpenAlex work type
    pub fn classifyWorkType(self: BundleSpec) WorkType {
        // Software: has executable types/behaviors
        if (self.has_types and self.has_behaviors)
            return .software;

        // Publication: has algorithms (theoretical contribution)
        if (self.has_algorithms)
            return .conference_paper;

        // Dataset: has constants/test data
        if (self.has_constants)
            return .dataset;

        // Default: software (all bundles are code)
        return .software;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COAR Notification System
// ═══════════════════════════════════════════════════════════════════════════════

/// COAR Notify result
/// See: https://notify.coar-repositories.org/
pub const COARNotifyResult = struct {
    crossref_registered: bool = false,
    datacite_doi: ?[]const u8 = null,
    openalex_indexed: bool = false,
    timestamp: i64 = 0,

    pub fn format(self: COARNotifyResult, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\
            \\COAR Notify Result:
            \\  Crossref: {s}
            \\  DataCite DOI: {s}
            \\  OpenAlex: {s}
            \\  Timestamp: {d}
        , .{
            if (self.crossref_registered) "✓ Registered" else "✗ Pending",
            if (self.datacite_doi) |doi| doi else "N/A",
            if (self.openalex_indexed) "✓ Indexed" else "✗ Pending",
            self.timestamp,
        });
    }
};

/// Notify COAR services of new publication
pub fn notifyCOAR(doi: []const u8, work_type: WorkType) !COARNotifyResult {
    _ = doi;
    _ = work_type;

    // TODO: Implement actual HTTP calls to:
    // 1. Crossref Link headers (preprint registration)
    // 2. DataCite DOI minting
    // 3. OpenAlex indexing API

    const timestamp = std.time.timestamp();
    return COARNotifyResult{
        .crossref_registered = false,
        .datacite_doi = null,
        .openalex_indexed = false,
        .timestamp = timestamp,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Enhanced Metadata Validation
// ═══════════════════════════════════════════════════════════════════════════════

/// Validation result
pub const ValidationResult = struct {
    is_valid: bool = false,
    errors: []const []const u8 = &.{},
    warnings: []const []const u8 = &.{},
    score: f64 = 0.0, // 0.0 - 100.0

    pub fn addError(self: *ValidationResult, allocator: Allocator, msg: []const u8) !void {
        const new_errors = try allocator.alloc([]const u8, self.errors.len + 1);
        @memcpy(new_errors[0..self.errors.len], self.errors);
        new_errors[self.errors.len] = msg;
        self.errors = new_errors;
        self.is_valid = false;
    }

    pub fn addWarning(self: *ValidationResult, allocator: Allocator, msg: []const u8) !void {
        const new_warnings = try allocator.alloc([]const u8, self.warnings.len + 1);
        @memcpy(new_warnings[0..self.warnings.len], self.warnings);
        new_warnings[self.warnings.len] = msg;
        self.warnings = new_warnings;
    }
};

/// Validate Zenodo metadata against best practices
pub fn validateMetadata(allocator: Allocator, metadata: Metadata) !ValidationResult {
    var result = ValidationResult{
        .is_valid = true,
        .score = 100.0,
    };

    // Check title length
    if (metadata.title.len < 10) {
        try result.addError(allocator, "Title too short (min 10 chars)");
        result.score -= 20;
    }
    if (metadata.title.len > 200) {
        try result.addError(allocator, "Title too long (max 200 chars)");
        result.score -= 10;
    }

    // Check authors
    if (metadata.creators.len == 0) {
        try result.addError(allocator, "No authors specified");
        result.score -= 30;
    }
    for (metadata.creators) |author| {
        if (author.orcid == null) {
            try result.addWarning(allocator, "Author missing ORCID");
            result.score -= 5;
        }
    }

    // Check description
    if (metadata.description.len < 50) {
        try result.addError(allocator, "Description too short (min 50 chars)");
        result.score -= 15;
    }

    // Check keywords
    if (metadata.keywords.len < 3) {
        try result.addWarning(allocator, "Fewer than 3 keywords");
        result.score -= 5;
    }

    // Check license
    if (!isValidSPDX(metadata.license)) {
        try result.addError(allocator, "Invalid SPDX license identifier");
        result.score -= 20;
    }

    result.is_valid = result.errors.len == 0;
    return result;
}

/// Check if license string is valid SPDX identifier
fn isValidSPDX(license: []const u8) bool {
    const valid_licenses = [_][]const u8{
        "MIT",       "Apache-2.0",   "GPL-3.0",
        "LGPL-3.0",  "BSD-3-Clause", "BSD-2-Clause",
        "CC-BY-4.0", "CC-BY-SA-4.0", "CC0-1.0",
        "ISC",       "Unlicense",    "MPL-2.0",
    };

    for (valid_licenses) |valid| {
        if (std.mem.eql(u8, license, valid))
            return true;
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Metadata Structures
// ═══════════════════════════════════════════════════════════════════════════════

pub const Metadata = struct {
    title: []const u8,
    creators: []const Creator,
    description: []const u8,
    keywords: []const []const u8,
    license: []const u8,
    doi: ?[]const u8 = null,
    publication_date: ?[]const u8 = null,
    version: ?[]const u8 = null,
};

pub const Creator = struct {
    name: []const u8,
    orcid: ?[]const u8 = null,
    affiliation: ?[]const u8 = null,
    email: ?[]const u8 = null,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "WorkType classification" {
    const software_bundle = BundleSpec{
        .has_types = true,
        .has_behaviors = true,
        .title = "HSLM",
    };
    try std.testing.expectEqual(WorkType.software, software_bundle.classifyWorkType());

    const dataset_bundle = BundleSpec{
        .has_constants = true,
        .title = "Constants",
    };
    try std.testing.expectEqual(WorkType.dataset, dataset_bundle.classifyWorkType());
}

test "Metadata validation" {
    const metadata = Metadata{
        .title = "Trinity HSLM: 1.95M Parameter Ternary Language Model",
        .creators = &[_]Creator{
            .{
                .name = "Vasilev, Dmitrii",
                .orcid = "0009-0008-4294-6159",
            },
        },
        .description = "HSLM is a 1.95M parameter ternary language model achieving perplexity 125.3 on TinyStories dataset using balanced ternary weights {-1, 0, +1}.",
        .keywords = &[_][]const u8{ "ternary", "neural", "networks", "FPGA" },
        .license = "MIT",
    };

    const result = try validateMetadata(std.testing.allocator, metadata);
    defer {
        std.testing.allocator.free(result.errors);
        std.testing.allocator.free(result.warnings);
    }

    try std.testing.expect(result.is_valid);
    try std.testing.expect(result.score >= 90.0);
}

test "SPDX license validation" {
    try std.testing.expect(isValidSPDX("MIT"));
    try std.testing.expect(isValidSPDX("Apache-2.0"));
    try std.testing.expect(isValidSPDX("CC-BY-4.0"));
    try std.testing.expect(!isValidSPDX("INVALID"));
    try std.testing.expect(!isValidSPDX(""));
}

// φ² + 1/φ² = 3 | TRINITY
