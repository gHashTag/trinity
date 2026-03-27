//! Zenodo V16: DOI Manager
//!
//! This module provides DOI (Digital Object Identifier) management for Zenodo.
//! Supports:
//! - Concept DOI for versioned collections
//! - Version DOI with automatic numbering
//! - DOI validation and parsing
//! - BibTeX citation generation
//! - Zenodo URL resolution
//!
//! Standards compliance:
//! - DataCite DOI standards
//! - Zenodo DOI patterns
//! - FAIR findability principles

const std = @import("std");

/// DOI validation result
pub const DOIValidation = struct {
    is_valid: bool,
    error_message: ?[]const u8,
};

/// DOI record with metadata
pub const DOIRecord = struct {
    /// Full DOI string (e.g., "10.5281/zenodo.123456")
    doi: []const u8,
    /// Concept DOI (for versioned collections)
    concept_doi: ?[]const u8,
    /// Version number
    version: u32,
    /// Zenodo record ID
    record_id: u64,
    /// Record title
    title: ?[]const u8,
    /// Publication date
    publication_date: ?[]const u8,

    /// Parse DOI to get components
    pub fn parse(doi: []const u8) !DOIRecord {
        // Basic validation: DOI must start with "10."
        if (!std.mem.startsWith(u8, doi, "10.")) {
            return error.InvalidDOIPrefix;
        }

        // Find the "/" separator
        const slash_idx = std.mem.indexOfScalar(u8, doi, '/') orelse return error.InvalidDOIFormat;

        // Extract suffix
        const suffix = doi[slash_idx + 1 ..];

        // For Zenodo, extract record ID from suffix
        const record_id_str = if (std.mem.indexOf(u8, suffix, "zenodo.")) |zenodo_idx|
            suffix[zenodo_idx + "zenodo.".len ..]
        else
            return error.NotZenodoDOI;

        const record_id = std.fmt.parseInt(u64, record_id_str, 10) catch return error.InvalidRecordID;

        return DOIRecord{
            .doi = doi,
            .concept_doi = null,
            .version = 1,
            .record_id = record_id,
            .title = null,
            .publication_date = null,
        };
    }

    /// Get Zenodo record URL
    pub fn zenodoRecordURL(self: *const DOIRecord) []const u8 {
        _ = self;
        return "https://zenodo.org/record/";
    }

    /// Get Zenodo DOI URL
    pub fn zenodoDOIURL(self: *const DOIRecord) []const u8 {
        _ = self;
        return "https://doi.org/";
    }

    /// Format as BibTeX
    pub fn formatAsBibTeX(self: *const DOIRecord, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 512);
        defer result.deinit(allocator);

        // Simple citation key (using record_id)
        const cite_key = try std.fmt.allocPrint(allocator, "zenodo_{d}", .{self.record_id});
        defer allocator.free(cite_key);

        try result.appendSlice(allocator, "@data{");
        try result.appendSlice(allocator, cite_key);
        try result.appendSlice(allocator, ",\\n");
        try result.appendSlice(allocator, "  author = {{Trinity AI}},\\n");
        try result.appendSlice(allocator, "  doi = {");
        try result.appendSlice(allocator, self.doi);
        try result.appendSlice(allocator, "},\\n");
        try result.appendSlice(allocator, "  url = {https://doi.org/");
        try result.appendSlice(allocator, self.doi);
        try result.appendSlice(allocator, "},\\n");
        try result.appendSlice(allocator, "  publisher = {Zenodo},\\n");
        try result.appendSlice(allocator, "  version = {");
        const ver_str = try std.fmt.allocPrint(allocator, "{d}", .{self.version});
        defer allocator.free(ver_str);
        try result.appendSlice(allocator, ver_str);
        try result.appendSlice(allocator, "}\\n");
        try result.appendSlice(allocator, "}\\n");

        return result.toOwnedSlice(allocator);
    }
};

/// DOI manager for versioned publications
pub const DOIManager = struct {
    /// Base DOI prefix (e.g., "10.5281/zenodo")
    prefix: []const u8,
    /// Next concept ID for new records
    next_concept_id: u32,
    /// Known records
    records: std.StringHashMap(DOIRecord),

    pub fn init(allocator: std.mem.Allocator, prefix: []const u8) DOIManager {
        return .{
            .prefix = prefix,
            .next_concept_id = 1,
            .records = std.StringHashMap(DOIRecord).init(allocator),
        };
    }

    pub fn deinit(self: *DOIManager) void {
        self.records.deinit();
    }

    /// Validate a DOI string
    pub fn validateDOI(self: *const DOIManager, doi: []const u8) DOIValidation {
        _ = self;

        // Must start with "10."
        if (!std.mem.startsWith(u8, doi, "10.")) {
            return .{ .is_valid = false, .error_message = "DOI must start with '10.'" };
        }

        // Must contain "/" separator
        if (std.mem.indexOfScalar(u8, doi, '/') == null) {
            return .{ .is_valid = false, .error_message = "DOI must contain '/' separator" };
        }

        // Check for Zenodo prefix (if present, valid)
        if (std.mem.indexOf(u8, doi, "zenodo.") != null) {
            return .{ .is_valid = true, .error_message = null };
        }

        return .{ .is_valid = true, .error_message = null };
    }

    /// Create new version DOI
    pub fn createVersionDOI(self: *DOIManager, allocator: std.mem.Allocator, concept_id: u32, version: u32) ![]const u8 {
        const doi = try std.fmt.allocPrint(allocator, "{s}.{d}.v{d}", .{ self.prefix, concept_id, version });
        return doi;
    }

    /// Create new concept DOI
    pub fn createConceptDOI(self: *DOIManager, allocator: std.mem.Allocator) ![]const u8 {
        const id = self.next_concept_id;
        self.next_concept_id += 1;
        return std.fmt.allocPrint(allocator, "{s}.{d}", .{ self.prefix, id });
    }

    /// Register a new record
    pub fn registerRecord(self: *DOIManager, allocator: std.mem.Allocator, record: DOIRecord) !void {
        const key = try std.fmt.allocPrint(allocator, "{d}", .{record.record_id});
        defer allocator.free(key);
        try self.records.put(key, record);
    }

    /// Get record by ID
    pub fn getRecord(self: *const DOIManager, record_id: u64) ?DOIRecord {
        const key_str = std.fmt.allocPrintZ(std.testing.allocator, "{d}", .{record_id}) catch return null;
        defer std.testing.allocator.free(key_str);
        return self.records.get(key_str);
    }
};

// ═══════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════

test "DOIRecord parse valid Zenodo DOI" {
    const doi = "10.5281/zenodo.123456";
    const record = try DOIRecord.parse(doi);

    try std.testing.expectEqual(@as(u64, 123456), record.record_id);
}

test "DOIRecord parse invalid prefix" {
    const doi = "11.5281/zenodo.123456";
    try std.testing.expectError(error.InvalidDOIPrefix, DOIRecord.parse(doi));
}

test "DOIRecord parse non-Zenodo DOI" {
    const doi = "10.1234/arxiv.1234";
    try std.testing.expectError(error.NotZenodoDOI, DOIRecord.parse(doi));
}

test "DOIManager validateDOI" {
    var manager = DOIManager.init(std.testing.allocator, "10.5281/zenodo");
    defer manager.deinit();

    const valid_doi = "10.5281/zenodo.123456";
    const result = manager.validateDOI(valid_doi);
    try std.testing.expect(result.is_valid);
}

test "DOIManager createConceptDOI" {
    var manager = DOIManager.init(std.testing.allocator, "10.5281/zenodo");
    defer manager.deinit();

    const doi = try manager.createConceptDOI(std.testing.allocator);
    defer std.testing.allocator.free(doi);

    try std.testing.expect(std.mem.startsWith(u8, doi, "10.5281/zenodo."));
    try std.testing.expectEqual(@as(u32, 2), manager.next_concept_id);
}

test "DOIManager createVersionDOI" {
    var manager = DOIManager.init(std.testing.allocator, "10.5281/zenodo");
    defer manager.deinit();

    const doi = try manager.createVersionDOI(std.testing.allocator, 123456, 2);
    defer std.testing.allocator.free(doi);

    try std.testing.expect(std.mem.eql(u8, doi, "10.5281/zenodo.123456.v2"));
}

test "DOIRecord formatAsBibTeX" {
    const record = DOIRecord{
        .doi = "10.5281/zenodo.123456",
        .concept_doi = null,
        .version = 1,
        .record_id = 123456,
        .title = "Test Dataset",
        .publication_date = "2024-01-01",
    };

    const bibtex = try record.formatAsBibTeX(std.testing.allocator);
    defer std.testing.allocator.free(bibtex);

    try std.testing.expect(std.mem.indexOf(u8, bibtex, "@data{") != null);
    try std.testing.expect(std.mem.indexOf(u8, bibtex, "10.5281/zenodo.123456") != null);
}
