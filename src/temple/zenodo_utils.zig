//! Zenodo Scientific Publication Utilities
//!
//! Comprehensive utilities for managing Zenodo publications with
//! NeurIPS/ICLR/MLSys scientific standards compliance.
//!
//! Features:
//! - Metadata generation per venue standards
//! - Citation format generation (BibTeX, APA, IEEE, MLA)
//! - Version management helpers
//! - DOI management utilities

const std = @import("std");

/// Scientific publication venues
pub const Venue = enum {
    neurips,
    iclr,
    mlsys,
    icml,
    aaai,
    acl,
    arxiv,
    zenodo_defensive, // Defensive publication (prior art)

    pub fn toString(self: Venue) []const u8 {
        return switch (self) {
            .neurips => "NeurIPS",
            .iclr => "ICLR",
            .mlsys => "MLSys",
            .icml => "ICML",
            .aaai => "AAAI",
            .acl => "ACL",
            .arxiv => "arXiv",
            .zenodo_defensive => "Zenodo Defensive Publication",
        };
    }

    /// Get citation format template for venue
    pub fn getCitationStyle(self: Venue) CitationStyle {
        return switch (self) {
            .neurips, .iclr, .mlsys, .icml => .ieee,
            .aaai, .acl => .apa,
            .arxiv => .bibtex,
            .zenodo_defensive => .ieee,
        };
    }
};

/// Citation format styles
pub const CitationStyle = enum {
    bibtex,
    apa,
    ieee,
    mla,
    chicago,
};

/// Publication metadata (NeurIPS/ICLR compliant)
pub const PublicationMetadata = struct {
    /// Unique identifier
    id: []const u8,
    /// DOI (10.5281/zenodo.XXXXXX)
    doi: []const u8,
    /// Title
    title: []const u8,
    /// Authors (comma-separated)
    authors: []const u8,
    /// Publication year
    year: u16,
    /// Publication month (1-12)
    month: u8,
    /// Venue/conference
    venue: Venue,
    /// Abstract
    abstract: []const u8,
    /// Keywords (for searchability)
    keywords: []const []const u8,
    /// License (usually MIT, CC-BY, CC0)
    license: License,
    /// Version
    version: []const u8,
    /// Related DOIs (supplementary materials)
    related_dois: []const []const u8,

    allocator: std.mem.Allocator,

    /// Create new metadata
    pub fn init(allocator: std.mem.Allocator) PublicationMetadata {
        return .{
            .id = "",
            .doi = "",
            .title = "",
            .authors = "",
            .year = 2026,
            .month = 1,
            .venue = .zenodo_defensive,
            .abstract = "",
            .keywords = &[_][]const u8{},
            .license = .mit,
            .version = "1.0.0",
            .related_dois = &[_][]const u8{},
            .allocator = allocator,
        };
    }

    /// Validate metadata completeness
    pub fn validate(self: *const PublicationMetadata) !void {
        if (self.title.len == 0) return error.MissingTitle;
        if (self.authors.len == 0) return error.MissingAuthors;
        if (self.year < 2000 or self.year > 2100) return error.InvalidYear;
        if (self.month < 1 or self.month > 12) return error.InvalidMonth;
        if (self.doi.len == 0) return error.MissingDOI;
        if (self.license == .unknown) return error.MissingLicense;
    }

    /// Format author list
    pub fn formatAuthors(self: *const PublicationMetadata) ![]u8 {
        // Simple formatting without ArrayList for Zig 0.15 compatibility
        // Count authors first
        var count: usize = 0;
        var iter = std.mem.splitScalar(u8, self.authors, ',');
        while (iter.next()) |author| {
            const trimmed = std.mem.trim(u8, author, " ");
            if (trimmed.len > 0) count += 1;
        }

        if (count == 0) {
            return try self.allocator.dupe(u8, "Unknown Author");
        }

        // Collect author names
        var authors = try self.allocator.alloc([]const u8, count);
        defer {
            for (authors) |a| self.allocator.free(a);
            self.allocator.free(authors);
        }

        var idx: usize = 0;
        iter = std.mem.splitScalar(u8, self.authors, ',');
        while (iter.next()) |author| {
            const trimmed = std.mem.trim(u8, author, " ");
            if (trimmed.len > 0) {
                authors[idx] = try self.allocator.dupe(u8, trimmed);
                idx += 1;
            }
        }

        if (count == 1) {
            return try self.allocator.dupe(u8, authors[0]);
        }

        if (count == 2) {
            return std.fmt.allocPrint(self.allocator, "{s} and {s}", .{ authors[0], authors[1] });
        }

        // Oxford comma style (3+ authors)
        // Calculate total size needed:
        // - Each of first (count-1) authors: author.len + 2 for ", "
        // - Plus ", and " (6 chars)
        // - Plus last author length
        var total_len: usize = 0;
        for (authors[0 .. count - 1]) |author| {
            total_len += author.len + 2; // +2 for ", "
        }
        total_len += 6; // ", and "
        total_len += authors[count - 1].len; // Last author

        var result = try self.allocator.alloc(u8, total_len);
        var pos: usize = 0;

        for (authors[0 .. count - 1], 0..) |author, i| {
            @memcpy(result[pos..][0..author.len], author);
            pos += author.len;
            if (i < count - 2) {
                @memcpy(result[pos..][0..2], ", ");
                pos += 2;
            }
        }
        @memcpy(result[pos..][0..6], ", and ");
        pos += 6;
        @memcpy(result[pos..], authors[count - 1]);

        return result;
    }

    /// Generate BibTeX citation
    pub fn toBibTeX(self: *const PublicationMetadata) ![]u8 {
        const formatted_authors = try self.formatAuthors();
        defer self.allocator.free(formatted_authors);

        // Create citation key from first author + year + first word
        var first_author_iter = std.mem.splitScalar(u8, self.authors, ',');
        const first_author = first_author_iter.next() orelse "unknown";
        var first_word_iter = std.mem.splitScalar(u8, self.title, ' ');
        const first_word = first_word_iter.next() orelse "notitle";

        const key = try std.fmt.allocPrint(self.allocator, "{s}{d}_{s}", .{ std.mem.trim(u8, first_author, " "), self.year, first_word });
        defer self.allocator.free(key);

        return std.fmt.allocPrint(self.allocator,
            \\@misc{{{s},
            \\  title = {{{s}}},
            \\  author = {{{s}}},
            \\  year = {{{d}}},
            \\  month = {{{s}}},
            \\  doi = {{{s}}},
            \\  url = {{https://doi.org/{s}}},
            \\  note = {{{s} - Trinity S³AI}}
            \\}}
        , .{
            key,
            self.title,
            formatted_authors,
            self.year,
            self.monthName(),
            self.doi,
            self.doi,
            self.venue.toString(),
        });
    }

    /// Generate APA citation
    pub fn toAPA(self: *const PublicationMetadata) ![]u8 {
        const formatted_authors = try self.formatAuthors();
        defer self.allocator.free(formatted_authors);

        return std.fmt.allocPrint(self.allocator, "{s} ({d}). *{s}* [{s}]. Zenodo. https://doi.org/{s}", .{ formatted_authors, self.year, self.title, self.venue.toString(), self.doi });
    }

    /// Generate IEEE citation
    pub fn toIEEE(self: *const PublicationMetadata) ![]u8 {
        const formatted_authors = try self.formatAuthors();
        defer self.allocator.free(formatted_authors);

        return std.fmt.allocPrint(self.allocator, "{s}, \"{s},\" *{s}*, Zenodo, {d}, doi: {s}.", .{ formatted_authors, self.title, self.venue.toString(), self.year, self.doi });
    }

    /// Generate MLA citation
    pub fn toMLA(self: *const PublicationMetadata) ![]u8 {
        const formatted_authors = try self.formatAuthors();
        defer self.allocator.free(formatted_authors);

        return std.fmt.allocPrint(self.allocator, "{s}. \"{s}.\" *{s}*, {d}, Zenodo, doi:{s}.", .{ formatted_authors, self.title, self.venue.toString(), self.year, self.doi });
    }

    /// Generate citation in specified style
    pub fn cite(self: *const PublicationMetadata, style: CitationStyle) ![]u8 {
        return switch (style) {
            .bibtex => self.toBibTeX(),
            .apa => self.toAPA(),
            .ieee => self.toIEEE(),
            .mla => self.toMLA(),
            .chicago => self.toAPA(), // Similar to APA
        };
    }

    /// Get month name
    fn monthName(self: *const PublicationMetadata) []const u8 {
        const months = [_][]const u8{
            "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
        };
        if (self.month >= 1 and self.month <= 12) {
            return months[self.month - 1];
        }
        return "Jan";
    }

    /// Export as JSON (for Zenodo API)
    pub fn toJSON(self: *const PublicationMetadata) ![]u8 {
        const formatted_authors = try self.formatAuthors();
        defer self.allocator.free(formatted_authors);

        // Build JSON string
        var json = std.ArrayList(u8).init(self.allocator);
        try json.append('{');

        try json.appendSlice("\"title\":\"");
        try json.appendSlice(self.title);
        try json.appendSlice("\",");

        try json.appendSlice("\"authors\":\"");
        try json.appendSlice(self.authors);
        try json.appendSlice("\",");

        try json.appendSlice("\"year\":");
        try std.fmt.formatInt(&json, self.year, 10, .lower, .{});

        try json.appendSlice(",\"month\":");
        try std.fmt.formatInt(&json, self.month, 10, .lower, .{});

        try json.appendSlice(",\"doi\":\"");
        try json.appendSlice(self.doi);
        try json.appendSlice("\",");

        try json.appendSlice("\"venue\":\"");
        try json.appendSlice(self.venue.toString());
        try json.appendSlice("\",");

        try json.appendSlice("\"abstract\":\"");
        // Escape quotes in abstract
        const escaped_abstract = try escapeJSON(self.allocator, self.abstract);
        defer self.allocator.free(escaped_abstract);
        try json.appendSlice(escaped_abstract);
        try json.appendSlice("\",");

        try json.appendSlice("\"license\":\"");
        try json.appendSlice(self.license.toString());
        try json.appendSlice("\",");

        try json.appendSlice("\"version\":\"");
        try json.appendSlice(self.version);
        try json.appendSlice("\"}");

        return json.toOwnedSlice();
    }
};

/// Escape JSON string
fn escapeJSON(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);

    for (s) |c| {
        switch (c) {
            '\\' => try result.appendSlice("\\\\"),
            '"' => try result.appendSlice("\\\""),
            '\n' => try result.appendSlice("\\n"),
            '\r' => try result.appendSlice("\\r"),
            '\t' => try result.appendSlice("\\t"),
            else => try result.append(c),
        }
    }

    return result.toOwnedSlice();
}

/// License types
pub const License = enum {
    mit,
    apache_2,
    gpl_3,
    cc_by,
    cc_by_sa,
    cc_by_nc,
    cc0,
    bsd_3,
    unknown,

    pub fn toString(self: License) []const u8 {
        return switch (self) {
            .mit => "MIT",
            .apache_2 => "Apache-2.0",
            .gpl_3 => "GPL-3.0",
            .cc_by => "CC-BY-4.0",
            .cc_by_sa => "CC-BY-SA-4.0",
            .cc_by_nc => "CC-BY-NC-4.0",
            .cc0 => "CC0-1.0",
            .bsd_3 => "BSD-3-Clause",
            .unknown => "Unknown",
        };
    }

    /// Is this license suitable for defensive publication?
    pub fn isDefensivePublication(self: License) bool {
        return switch (self) {
            .mit, .cc0, .bsd_3 => true,
            else => false,
        };
    }
};

/// Version management helper
pub const VersionManager = struct {
    allocator: std.mem.Allocator,
    current_version: Version,

    pub const Version = struct {
        major: u8,
        minor: u8,
        patch: u8,

        pub fn format(self: Version, allocator: std.mem.Allocator) ![]u8 {
            return std.fmt.allocPrint(allocator, "{d}.{d}.{d}", .{ self.major, self.minor, self.patch });
        }

        pub fn incrementMajor(self: Version) Version {
            return .{ .major = self.major + 1, .minor = 0, .patch = 0 };
        }

        pub fn incrementMinor(self: Version) Version {
            return .{ .major = self.major, .minor = self.minor + 1, .patch = 0 };
        }

        pub fn incrementPatch(self: Version) Version {
            return .{ .major = self.major, .minor = self.minor, .patch = self.patch + 1 };
        }

        pub fn compare(self: Version, other: Version) std.math.Order {
            if (self.major != other.major) {
                return std.math.order(self.major, other.major);
            }
            if (self.minor != other.minor) {
                return std.math.order(self.minor, other.minor);
            }
            return std.math.order(self.patch, other.patch);
        }
    };

    pub fn init(allocator: std.mem.Allocator, major: u8, minor: u8, patch: u8) VersionManager {
        return .{
            .allocator = allocator,
            .current_version = .{ .major = major, .minor = minor, .patch = patch },
        };
    }

    /// Determine version increment type based on changes
    pub fn suggestBump(self: *VersionManager, changes: []const ChangeType) Version {
        var has_breaking = false;
        var has_feature = false;

        for (changes) |change| {
            switch (change) {
                .breaking => has_breaking = true,
                .feature => has_feature = true,
                else => {},
            }
        }

        if (has_breaking) {
            return self.current_version.incrementMajor();
        } else if (has_feature) {
            return self.current_version.incrementMinor();
        } else {
            return self.current_version.incrementPatch();
        }
    }

    pub fn getCurrent(self: *const VersionManager) Version {
        return self.current_version;
    }

    pub fn setCurrent(self: *VersionManager, version: Version) void {
        self.current_version = version;
    }
};

/// Change types for version bumping
pub const ChangeType = enum {
    breaking, // Incompatible API changes
    feature, // New functionality
    fix, // Bug fixes
    docs, // Documentation only
    refactor, // Refactoring (no user-visible changes)
    tests, // Test changes only
    chore, // Build process/dependency changes
};

/// DOI helper utilities
pub const DOIHelper = struct {
    /// Extract numeric ID from Zenodo DOI
    pub fn extractZenodoID(doi: []const u8) !u64 {
        // DOI format: 10.5281/zenodo.XXXXXX
        const prefix = "10.5281/zenodo.";
        if (!std.mem.startsWith(u8, doi, prefix)) {
            return error.InvalidZenodoDOI;
        }

        const id_str = doi[prefix.len..];
        return std.fmt.parseUnsigned(u64, id_str, 10);
    }

    /// Build Zenodo URL from DOI
    pub fn buildURL(doi: []const u8, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "https://doi.org/{s}", .{doi});
    }

    /// Validate DOI format
    pub fn validateDOI(doi: []const u8) bool {
        // Basic DOI validation: must contain "10." and a "/"
        if (std.mem.indexOf(u8, doi, "10.") == null) return false;
        if (std.mem.indexOf(u8, doi, "/") == null) return false;
        return doi.len > 10;
    }

    /// Generate citation for Trinity component bundle
    pub fn generateTrinityBundleCitation(title: []const u8, doi: []const u8, style: CitationStyle, allocator: std.mem.Allocator) ![]u8 {
        var meta = PublicationMetadata.init(allocator);
        meta.title = title;
        meta.authors = "Dmitrii Vasilev";
        meta.year = 2026;
        meta.month = 3;
        meta.venue = .zenodo_defensive;
        meta.doi = doi;
        meta.version = "5.0.0";
        meta.license = .mit;

        return meta.cite(style);
    }
};

/// NeurIPS-specific metadata helper
pub const NeurIPSMetadata = struct {
    /// Generate NeurIPS-compliant metadata
    pub fn generate(allocator: std.mem.Allocator, title: []const u8, authors: []const u8, abstract: []const u8, keywords: []const []const u8) !PublicationMetadata {
        var meta = PublicationMetadata.init(allocator);
        meta.title = try allocator.dupe(u8, title);
        meta.authors = try allocator.dupe(u8, authors);
        meta.abstract = try allocator.dupe(u8, abstract);
        meta.keywords = try allocator.dupe([]const u8, keywords);
        meta.venue = .neurips;
        meta.license = .cc_by; // NeurIPS standard
        meta.year = 2026;
        meta.month = 12; // NeurIPS is in December

        return meta;
    }

    /// Check if metadata meets NeurIPS requirements
    pub fn validate(meta: *const PublicationMetadata) !void {
        try meta.validate();

        // NeurIPS-specific checks
        if (meta.abstract.len < 150) return error.AbstractTooShort;
        if (meta.abstract.len > 250) return error.AbstractTooLong;
        if (meta.keywords.len < 3) return error.TooFewKeywords;
        if (meta.keywords.len > 6) return error.TooManyKeywords;
    }
};

// Tests
test "PublicationMetadata validation" {
    var meta = PublicationMetadata.init(std.testing.allocator);
    meta.title = "Test Paper";
    meta.authors = "John Doe";
    meta.year = 2026;
    meta.month = 3;
    meta.doi = "10.5281/zenodo.123456";
    meta.license = .mit;

    try meta.validate();
}

test "BibTeX generation" {
    var meta = PublicationMetadata.init(std.testing.allocator);
    meta.title = "Trinity S³AI";
    meta.authors = "Dmitrii Vasilev";
    meta.year = 2026;
    meta.month = 3;
    meta.doi = "10.5281/zenodo.123456";
    meta.license = .mit;
    meta.venue = .neurips;

    const bibtex = try meta.toBibTeX();
    defer std.testing.allocator.free(bibtex);

    try std.testing.expect(std.mem.indexOf(u8, bibtex, "@misc{") != null);
    try std.testing.expect(std.mem.indexOf(u8, bibtex, "Trinity S³AI") != null);
    try std.testing.expect(std.mem.indexOf(u8, bibtex, "10.5281/zenodo.123456") != null);
}

test "VersionManager bump suggestion" {
    var vm = VersionManager.init(std.testing.allocator, 1, 2, 3);

    const changes = [_]ChangeType{ .fix, .docs };
    const suggested = vm.suggestBump(&changes);
    try std.testing.expectEqual(@as(u8, 1), suggested.major);
    try std.testing.expectEqual(@as(u8, 2), suggested.minor);
    try std.testing.expectEqual(@as(u8, 4), suggested.patch);

    const feature_changes = [_]ChangeType{ .feature, .fix };
    const suggested_feature = vm.suggestBump(&feature_changes);
    try std.testing.expectEqual(@as(u8, 1), suggested_feature.major);
    try std.testing.expectEqual(@as(u8, 3), suggested_feature.minor);

    const breaking_changes = [_]ChangeType{ .breaking, .fix };
    const suggested_breaking = vm.suggestBump(&breaking_changes);
    try std.testing.expectEqual(@as(u8, 2), suggested_breaking.major);
}

test "DOIHelper extraction" {
    const id = try DOIHelper.extractZenodoID("10.5281/zenodo.123456");
    try std.testing.expectEqual(@as(u64, 123456), id);
}

test "DOIHelper validation" {
    try std.testing.expect(DOIHelper.validateDOI("10.5281/zenodo.123456"));
    try std.testing.expect(DOIHelper.validateDOI("10.1234/example.test"));
    try std.testing.expect(!DOIHelper.validateDOI("invalid"));
    try std.testing.expect(!DOIHelper.validateDOI("10.test"));
}
