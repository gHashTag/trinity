//! Zenodo V19: CFF 1.2.0 Citation File Format Generator
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Generates CITATION.cff files compliant with CFF 1.2.0 specification
//! Reference: https://citation-file-format.github.io/1.2.0/
//!
//! Features:
//! - Complete CFF 1.2.0 metadata
//! - ORCID integration
//! - Multiple authors
//! - Zenodo DOI linking

const std = @import("std");
const Allocator = std.mem.Allocator;

const orcid = @import("zenodo_v19_orcid.zig");

// ============================================================================
// CFF 1.2.0 STRUCTURE
// ============================================================================

/// CFF 1.2.0 citation file format
pub const CffFile = struct {
    /// CFF version (must be "1.2.0")
    cff_version: []const u8 = "1.2.0",
    /// Message to users
    message: []const u8 = "If you use this software, please cite it as below.",
    /// Title of the work
    title: []const u8,
    /// Authors list
    authors: []const CffAuthor,
    /// Version (e.g., "0.12.0")
    version: []const u8,
    /// DOI (e.g., "10.5281/zenodo.19227879")
    doi: ?[]const u8,
    /// Date released (YYYY-MM-DD)
    date_released: ?[]const u8,
    /// URL to repository
    url: ?[]const u8,
    /// License (SPDX identifier)
    license: ?[]const u8,
    /// Abstract/summary
    abstract: ?[]const u8,
    /// Keywords
    keywords: []const []const u8,
    /// Commit hash
    commit: ?[]const u8,

    /// Generate CFF YAML content
    pub fn generate(self: *const CffFile, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayListUnmanaged(u8){};
        defer buffer.deinit(allocator);

        const writer = buffer.writer(allocator);

        // CFF version
        try writer.writeAll("cff-version: \"1.2.0\"\n");

        // Message
        try writer.writeAll("message: \"If you use this software, please cite it as below.\"\n");

        // Title
        try writer.print("title: \"{s}\"\n", .{self.title});

        // Authors
        try writer.writeAll("authors:\n");
        for (self.authors) |author| {
            try writer.print("  - family-names: \"{s}\"\n", .{author.family_names});

            if (author.given_names) |given| {
                try writer.print("    given-names: \"{s}\"\n", .{given});
            }

            if (author.orcid) |o| {
                try writer.print("    orcid: \"{s}\"\n", .{o});
            }

            if (author.email) |e| {
                try writer.print("    email: \"{s}\"\n", .{e});
            }

            if (author.affiliation) |aff| {
                try writer.print("    affiliation: \"{s}\"\n", .{aff});
            }
        }

        // Version
        try writer.print("version: \"{s}\"\n", .{self.version});

        // DOI
        if (self.doi) |doi| {
            try writer.print("doi: \"{s}\"\n", .{doi});
        }

        // Date released
        if (self.date_released) |date| {
            try writer.print("date-released: {s}\n", .{date});
        }

        // URL
        if (self.url) |url| {
            try writer.print("url: \"{s}\"\n", .{url});
        }

        // License
        if (self.license) |lic| {
            try writer.print("license: {s}\n", .{lic});
        }

        // Abstract
        if (self.abstract) |abs| {
            try writer.writeAll("abstract: |\n");
            var lines = std.mem.splitScalar(u8, abs, '\n');
            while (lines.next()) |line| {
                try writer.print("  {s}\n", .{line});
            }
        }

        // Keywords
        if (self.keywords.len > 0) {
            try writer.writeAll("keywords:\n");
            for (self.keywords) |kw| {
                try writer.print("  - \"{s}\"\n", .{kw});
            }
        }

        // Commit
        if (self.commit) |commit| {
            try writer.print("commit: \"{s}\"\n", .{commit});
        }

        return buffer.toOwnedSlice(allocator);
    }

    /// Escape special YAML characters in string
    fn escapeYaml(s: []const u8, allocator: Allocator) ![]const u8 {
        // Simple escaping for quotes and backslashes
        var escaped = std.ArrayList(u8).init(allocator);
        errdefer escaped.deinit();

        for (s) |c| {
            switch (c) {
                '\\', '"' => try escaped.append('\\'),
                else => {},
            }
            try escaped.append(c);
        }

        return escaped.toOwnedSlice();
    }
};

/// CFF Author structure
pub const CffAuthor = struct {
    /// Family name (last name)
    family_names: []const u8,
    /// Given names (first name(s))
    given_names: ?[]const u8 = null,
    /// ORCID iD (https://orcid.org/XXXX-XXXX-XXXX-XXXX)
    orcid: ?[]const u8 = null,
    /// Email address
    email: ?[]const u8 = null,
    /// Institution
    affiliation: ?[]const u8 = null,
};

/// Convert ORCID Author to CFF Author
pub fn authorToCff(author: orcid.Author, allocator: Allocator) !CffAuthor {
    // Parse name: "Last, First" or "First Last"
    var family_names: []const u8 = "";
    var given_names: ?[]const u8 = null;

    if (std.mem.indexOfScalar(u8, author.name, ',')) |comma_idx| {
        // "Last, First" format
        family_names = author.name[0..comma_idx];
        if (author.name.len > comma_idx + 2) {
            given_names = author.name[comma_idx + 2 ..];
        }
    } else {
        // "First Last" format - extract last name
        const last_space = std.mem.lastIndexOfScalar(u8, author.name, ' ');
        if (last_space) |idx| {
            family_names = author.name[idx + 1 ..];
            given_names = author.name[0..idx];
        } else {
            family_names = author.name;
        }
    }

    // Get affiliation (first one if multiple)
    const affiliation = if (author.affiliations.len > 0)
        author.affiliations[0]
    else
        null;

    return .{
        .family_names = try allocator.dupe(u8, family_names),
        .given_names = if (given_names) |gn| try allocator.dupe(u8, gn) else null,
        .orcid = if (author.orcid) |o| try std.fmt.allocPrint(allocator, "https://orcid.org/{s}", .{o}) else null,
        .email = if (author.email) |e| try allocator.dupe(u8, e) else null,
        .affiliation = if (affiliation) |aff| try allocator.dupe(u8, aff) else null,
    };
}

/// Create CFF file for Trinity S³AI
pub fn createTrinityCff(allocator: Allocator, version: []const u8, doi: ?[]const u8) !CffFile {
    const authors = &[_]CffAuthor{
        .{
            .family_names = "Vasilev",
            .given_names = "Dmitrii",
            .orcid = "https://orcid.org/0000-0002-1825-0097",
        },
    };

    const keywords = &[_][]const u8{
        "ternary neural networks",
        "FPGA",
        "balanced ternary",
        "VSA",
        "Vector Symbolic Architectures",
        "Hyperdimensional Computing",
        "Trinity",
    };

    const abstract =
        \\Trinity S³AI is a scalable sparse symbolic AI system using ternary computing.
        \\Implements HSLM (1.95M parameter language model), VSA operations, and FPGA deployment.
        \\Key features: 0% DSP utilization, 19.6% LUT on XC7A100T, 1.2W power consumption.
        \\Mathematical foundation: φ² + 1/φ² = 3 where φ = (1 + √5) / 2.
    ;

    return .{
        .title = try allocator.dupe(u8, "Trinity S³AI: Ternary Neural Networks"),
        .authors = authors[0..],
        .version = try allocator.dupe(u8, version),
        .doi = if (doi) |d| try allocator.dupe(u8, d) else null,
        .date_released = try allocator.dupe(u8, "2026-03-27"),
        .url = try allocator.dupe(u8, "https://github.com/gHashTag/trinity"),
        .license = try allocator.dupe(u8, "MIT"),
        .abstract = try allocator.dupe(u8, abstract),
        .keywords = keywords[0..],
        .commit = null,
    };
}

/// Write CFF file to disk
pub fn writeCffFile(cff: *const CffFile, allocator: Allocator, path: []const u8) !void {
    const content = try cff.generate(allocator);
    defer allocator.free(content);

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll(content);
}

// ============================================================================
// TESTS
// ============================================================================

/// Helper to create a minimal CffFile for testing
fn createTestCff(title: []const u8, version: []const u8) CffFile {
    const empty_authors = [_]CffAuthor{.{ .family_names = "Test" }};
    const empty_keywords = [_][]const u8{};

    return .{
        .title = title,
        .authors = &empty_authors,
        .version = version,
        .doi = null,
        .date_released = null,
        .url = null,
        .license = null,
        .abstract = null,
        .keywords = &empty_keywords,
        .commit = null,
    };
}

test "CFF: generate basic CFF file" {
    const allocator = std.testing.allocator;

    var cff = createTestCff("Test Title", "1.0.0");

    const yaml = try cff.generate(allocator);
    defer allocator.free(yaml);

    try std.testing.expect(std.mem.indexOf(u8, yaml, "cff-version: \"1.2.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "title: \"Test Title\"") != null);
}

test "CFF: createTrinityCff generates valid structure" {
    const allocator = std.testing.allocator;

    const cff = try createTrinityCff(allocator, "0.12.0", "10.5281/zenodo.19227879");
    defer {
        allocator.free(cff.title);
        allocator.free(cff.version);
        if (cff.doi) |d| allocator.free(d);
        if (cff.date_released) |d| allocator.free(d);
        if (cff.url) |u| allocator.free(u);
        if (cff.license) |l| allocator.free(l);
        if (cff.abstract) |a| allocator.free(a);
    }

    try std.testing.expectEqualStrings("Trinity S³AI: Ternary Neural Networks", cff.title);
    try std.testing.expectEqualStrings("0.12.0", cff.version);
    try std.testing.expect(cff.doi != null);
    try std.testing.expect(cff.authors.len > 0);
}

test "CFF: authorToCff parses name correctly" {
    const allocator = std.testing.allocator;

    const author1 = orcid.Author{
        .name = "Smith, John",
    };
    const cff1 = try authorToCff(author1, allocator);
    defer {
        allocator.free(cff1.family_names);
        if (cff1.given_names) |gn| allocator.free(gn);
    }

    try std.testing.expectEqualStrings("Smith", cff1.family_names);
    try std.testing.expectEqualStrings("John", cff1.given_names.?);

    const author2 = orcid.Author{
        .name = "John Smith",
    };
    const cff2 = try authorToCff(author2, allocator);
    defer {
        allocator.free(cff2.family_names);
        if (cff2.given_names) |gn| allocator.free(gn);
    }

    try std.testing.expectEqualStrings("Smith", cff2.family_names);
    try std.testing.expectEqualStrings("John", cff2.given_names.?);
}

test "CFF: generate with ORCID" {
    const allocator = std.testing.allocator;

    const authors = [_]CffAuthor{.{
        .family_names = "Vasilev",
        .given_names = "Dmitrii",
        .orcid = "https://orcid.org/0000-0002-1825-0097",
    }};

    var cff = CffFile{
        .title = "ORCID Test",
        .authors = &authors,
        .version = "1.0.0",
        .doi = null,
        .date_released = null,
        .url = null,
        .license = null,
        .abstract = null,
        .keywords = &[_][]const u8{},
        .commit = null,
    };

    const yaml = try cff.generate(allocator);
    defer allocator.free(yaml);

    try std.testing.expect(std.mem.indexOf(u8, yaml, "https://orcid.org/0000-0002-1825-0097") != null);
}

test "CFF: generate with keywords" {
    const allocator = std.testing.allocator;

    const keywords = [_][]const u8{
        "keyword1",
        "keyword2",
    };

    const authors = [_]CffAuthor{.{ .family_names = "Test" }};

    var cff = CffFile{
        .title = "Keywords Test",
        .authors = &authors,
        .version = "1.0.0",
        .doi = null,
        .date_released = null,
        .url = null,
        .license = null,
        .abstract = null,
        .keywords = &keywords,
        .commit = null,
    };

    const yaml = try cff.generate(allocator);
    defer allocator.free(yaml);

    try std.testing.expect(std.mem.indexOf(u8, yaml, "keywords:") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "\"keyword1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "\"keyword2\"") != null);
}

// φ² + 1/φ² = 3 | TRINITY
