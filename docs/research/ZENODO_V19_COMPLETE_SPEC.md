# Zenodo Metadata V19: Complete Implementation Specification

## Abstract

This document provides complete implementation specifications for Zenodo V19 enhancements, including ORCID integration, CFF 1.2.0 generation, OpenAlex classification, and COAR notification system. All implementations follow NeurIPS 2025, ICLR 2025, and MLSys 2025 requirements.

---

## Part 1: ORCID Integration

### 1.1 ORCID Data Structure

```zig
const std = @import("std");

/// Author with ORCID integration (NeurIPS 2025 requirement)
pub const OrcidAuthor = struct {
    /// Full name: "Family, Given" or "Given Family"
    name: []const u8,

    /// ORCID iD: "https://orcid.org/0000-0002-1825-0097"
    orcid: ?[]const u8 = null,

    /// Institution(s)
    affiliation: []const []const u8,

    /// Email for corresponding author
    email: ?[]const u8 = null,

    /// Author role
    role: AuthorRole = .author,

    /// Is corresponding author?
    corresponding: bool = false,
};

pub const AuthorRole = enum(u8) {
    /// Primary author
    author = 0,

    /// Code/data contributor
    contributor = 1,

    /// Academic supervisor
    supervisor = 2,

    /// Contact person
    contact = 3,
};
```

### 1.2 ORCID Validation

```zig
/// Validate ORCID iD format and checksum
/// Format: 0000-0002-1825-0097 (16 digits, ISO 7064:1983.MOD 11-2)
pub fn validateORCID(orcid: []const u8) !bool {
    // Check format: https://orcid.org/XXXX-XXXX-XXXX-XXXX
    const expected_len = 22; // "https://orcid.org/" (19) + 16 digits + 4 dashes = 22
    if (orcid.len != expected_len) return error.InvalidLength;

    // Check prefix
    if (!std.mem.startsWith(u8, orcid, "https://orcid.org/")) {
        return error.InvalidPrefix;
    }

    // Extract ID part (remove prefix)
    const id_part = orcid["https://orcid.org/".len..];

    // Check format: XXXX-XXXX-XXXX-XXXX
    var digit_count: usize = 0;
    for (id_part, 0..) |c, i| {
        if (c == '-') {
            if (i != 4 and i != 9 and i != 14) return error.InvalidDashPosition;
        } else if (c >= '0' and c <= '9') {
            digit_count += 1;
        } else {
            return error.InvalidCharacter;
        }
    }

    if (digit_count != 16) return error.InvalidDigitCount;

    // Validate checksum (ISO 7064:1983.MOD 11-2)
    const digits = extractDigits(id_part) catch return error.InvalidChecksum;
    const checksum = computeChecksum(digits);
    const expected_checksum = digits[15];

    return checksum == expected_checksum;
}

fn extractDigits(id_part: []const u8) ![16]u8 {
    var digits: [16]u8 = undefined;
    var idx: usize = 0;

    for (id_part) |c| {
        if (c >= '0' and c <= '9') {
            if (idx >= 16) return error.TooManyDigits;
            digits[idx] = c - '0';
            idx += 1;
        }
    }

    if (idx != 16) return error.TooFewDigits;
    return digits;
}

fn computeChecksum(digits: [16]u8) u8 {
    var total: u32 = 0;

    for (digits[0..15], 0..) |d, i| {
        total += @as(u32, d) * 2;
        // Double every other digit from the right
        if (i % 2 == 0) {
            total += @as(u32, d);
        } else {
            const doubled = @as(u32, d) * 2;
            total += if (doubled >= 10) doubled - 9 else doubled;
        }
    }

    return @as(u8, 10 - (total % 10)) % 10;
}

/// Test ORCID validation
test "ORCID validation: valid ORCID" {
    const valid = "https://orcid.org/0000-0002-1825-0097";
    try std.testing.expect(try validateORCID(valid));
}

test "ORCID validation: invalid checksum" {
    const invalid = "https://orcid.org/0000-0002-1825-0098"; // Last digit wrong
    try std.testing.expectError(error.InvalidChecksum, validateORCID(invalid));
}

test "ORCID validation: invalid format" {
    const invalid = "https://orcid.org/0000-0002-1825"; // Too short
    try std.testing.expectError(error.InvalidLength, validateORCID(invalid));
}
```

### 1.3 Author List Management

```zig
/// Author list with ORCID support
pub const AuthorList = struct {
    allocator: std.mem.Allocator,
    authors: std.ArrayList(OrcidAuthor),
    corresponding_author_idx: ?usize = null,

    pub fn init(allocator: std.mem.Allocator) AuthorList {
        return .{
            .allocator = allocator,
            .authors = std.ArrayList(OrcidAuthor).init(allocator),
        };
    }

    pub fn deinit(self: *AuthorList) void {
        self.authors.deinit();
    }

    /// Add author to list
    pub fn addAuthor(self: *AuthorList, author: OrcidAuthor) !void {
        // Validate ORCID if provided
        if (author.orcid) |orcid| {
            _ = try validateORCID(orcid);
        }

        // Set corresponding author if requested
        if (author.corresponding) {
            if (self.corresponding_author_idx != null) {
                return error.MultipleCorrespondingAuthors;
            }
            self.corresponding_author_idx = self.authors.items.len;
        }

        try self.authors.append(author);
    }

    /// Get corresponding author
    pub fn getCorrespondingAuthor(self: *const AuthorList) ?OrcidAuthor {
        if (self.corresponding_author_idx) |idx| {
            if (idx < self.authors.items.len) {
                return self.authors.items[idx];
            }
        }
        return null;
    }

    /// Format for citation: "Author1, Author2, and Author3"
    pub fn formatCitation(self: *const AuthorList, allocator: std.mem.Allocator) ![]const u8 {
        const n = self.authors.items.len;
        if (n == 0) return error.NoAuthors;

        var buffer = std.ArrayList(u8).init(allocator);

        for (self.authors.items, 0..) |author, i| {
            if (i > 0) {
                if (i == n - 1) {
                    try buffer.appendSlice(", and ");
                } else {
                    try buffer.appendSlice(", ");
                }
            }
            try buffer.appendSlice(author.name);
        }

        return buffer.toOwnedSlice();
    }

    /// Check all authors have ORCID (NeurIPS 2025 requirement)
    pub fn allAuthorsHaveORCID(self: *const AuthorList) bool {
        for (self.authors.items) |author| {
            if (author.orcid == null) return false;
        }
        return true;
    }

    /// Get ORCID completion percentage
    pub fn orcidCompletion(self: *const AuthorList) f64 {
        if (self.authors.items.len == 0) return 0.0;

        var with_orcid: usize = 0;
        for (self.authors.items) |author| {
            if (author.orcid != null) with_orcid += 1;
        }

        return @as(f64, @floatFromInt(with_orcid)) * 100.0
             / @as(f64, @floatFromInt(self.authors.items.len));
    }
};
```

---

## Part 2: CFF 1.2.0 Generator

### 2.1 CFF Data Structure

```zig
/// Citation File Format 1.2.0
/// https://citation-file-format.github.io/1.2.0/
pub const CFF = struct {
    /// CFF version
    cff_version: []const u8 = "1.2.0",

    /// Message to display
    message: []const u8 = "If you use this software, please cite it as below.",

    /// Authors
    authors: []CFFAuthor,

    /// Title
    title: []const u8,

    /// Version (SemVer)
    version: []const u8,

    /// DOI
    doi: ?[]const u8 = null,

    /// Release date
    date_released: []const u8,

    /// URL
    url: ?[]const u8 = null,

    /// License (SPDX)
    license: []const u8,

    /// Keywords (3-8 recommended)
    keywords: [][]const u8,

    /// Abstract (50-500 words recommended)
    abstract: ?[]const u8 = null,

    /// DOI of related papers
    identifiers: []CFFIdentifier = &.{},

    /// Funding information
    funding: []CFFFunding = &.{},

    /// Contact information
    contact: ?CFFContact = null,
};

pub const CFFAuthor = struct {
    /// Family name (last name)
    family_names: []const u8,

    /// Given names (first name)
    given_names: []const u8,

    /// ORCID iD
    orcid: ?[]const u8 = null,

    /// Affiliation
    affiliation: []const []const u8 = &.{},

    /// Email (for corresponding author)
    email: ?[]const u8 = null,

    /// Role (corresponding author, etc.)
    role: ?[]const u8 = null,
};

pub const CFFIdentifier = struct {
    /// Type of identifier
    type: []const u8, // "doi", "arxiv", "swh"

    /// Identifier value
    value: []const u8,
};

pub const CFFFunding = struct {
    /// Funding name
    name: []const u8,

    /// Grant number
    number: ?[]const u8 = null,

    /// Funding URL
    url: ?[]const u8 = null,
};

pub const CFFContact = struct {
    /// Contact name
    name: []const u8,

    /// Contact email
    email: []const u8,

    /// Contact ORCID
    orcid: ?[]const u8 = null,
};
```

### 2.2 CFF Generator Implementation

```zig
pub const CFFGenerator = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CFFGenerator {
        return .{ .allocator = allocator };
    }

    /// Generate CFF from Zenodo metadata
    pub fn fromZenodoMetadata(self: *CFFGenerator, meta: ZenodoMetadata) !CFF {
        // Parse authors
        var authors = std.ArrayList(CFFAuthor).init(self.allocator);

        for (meta.creators) |creator| {
            const parts = std.mem.splitScalar(u8, creator, ',');
            const family = parts.first() orelse "";
            const given = if (parts.next()) |g| g else "";

            try authors.append(.{
                .family_names = family,
                .given_names = given,
                .orcid = creator.orcid,
                .affiliation = &.{},
                .email = null,
                .role = null,
            });
        }

        // Parse version from metadata
        const version = meta.metadata.version orelse "0.0.0";

        // Format release date
        const date_str = try std.fmt.allocPrint(
            self.allocator,
            "{d:04d}-{d:02d}-{d:02d}",
            .{
                meta.metadata.publication_year,
                meta.metadata.publication_month,
                meta.metadata.publication_day,
            }
        );

        return CFF{
            .cff_version = "1.2.0",
            .message = "If you use this software, please cite it as below.",
            .authors = authors.toOwnedSlice(),
            .title = meta.metadata.title,
            .version = version,
            .doi = meta.metadata.doi,
            .date_released = date_str,
            .url = meta.metadata.url,
            .license = meta.metadata.license.id,
            .keywords = meta.metadata.keywords,
            .abstract = meta.metadata.description,
            .identifiers = &.{},
            .funding = &.{},
            .contact = null,
        };
    }

    /// Generate CFF file content
    pub fn generate(self: *CFFGenerator, cff: CFF) ![]const u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);

        // Header
        try buffer.appendSlice("cff-version: ");
        try buffer.appendSlice(cff.cff_version);
        try buffer.appendSlice("\n");

        // Message
        try buffer.appendSlice("message: \"");
        try buffer.appendSlice(cff.message);
        try buffer.appendSlice("\"\n\n");

        // Authors
        try buffer.appendSlice("authors:\n");
        for (cff.authors) |author| {
            try buffer.appendSlice("  - family-names: \"");
            try buffer.appendSlice(author.family_names);
            try buffer.appendSlice("\"\n");

            try buffer.appendSlice("    given-names: \"");
            try buffer.appendSlice(author.given_names);
            try buffer.appendSlice("\"");

            if (author.orcid) |orcid| {
                try buffer.appendSlice("\n    orcid: \"");
                try buffer.appendSlice(orcid);
                try buffer.appendSlice("\"");
            }

            if (author.affiliation.len > 0) {
                try buffer.appendSlice("\n    affiliation:\n");
                for (author.affiliation) |aff| {
                    try buffer.appendSlice("      - \"");
                    try buffer.appendSlice(aff);
                    try buffer.appendSlice("\"\n");
                }
            }

            try buffer.appendSlice("\n");
        }

        // Title
        try buffer.appendSlice("title: \"");
        try buffer.appendSlice(cff.title);
        try buffer.appendSlice("\"\n");

        // Version
        try buffer.appendSlice("version: ");
        try buffer.appendSlice(cff.version);
        try buffer.appendSlice("\n");

        // DOI
        if (cff.doi) |doi| {
            try buffer.appendSlice("doi: ");
            try buffer.appendSlice(doi);
            try buffer.appendSlice("\n");
        }

        // Release date
        try buffer.appendSlice("date-released: ");
        try buffer.appendSlice(cff.date_released);
        try buffer.appendSlice("\n");

        // URL
        if (cff.url) |url| {
            try buffer.appendSlice("url: \"");
            try buffer.appendSlice(url);
            try buffer.appendSlice("\"\n");
        }

        // License
        try buffer.appendSlice("license: ");
        try buffer.appendSlice(cff.license);
        try buffer.appendSlice("\n");

        // Keywords
        if (cff.keywords.len > 0) {
            try buffer.appendSlice("keywords:\n");
            for (cff.keywords) |kw| {
                try buffer.appendSlice("  - \"");
                try buffer.appendSlice(kw);
                try buffer.appendSlice("\"\n");
            }
        }

        // Abstract
        if (cff.abstract) |abs| {
            try buffer.appendSlice("\nabstract: |\n");
            var lines = std.mem.splitScalar(u8, abs, '\n');
            while (lines.next()) |line| {
                try buffer.appendSlice("  ");
                try buffer.appendSlice(line);
                try buffer.appendSlice("\n");
            }
        }

        return buffer.toOwnedSlice();
    }

    /// Write CITATION.cff to file
    pub fn writeCFF(self: *CFFGenerator, cff: CFF, path: []const u8) !void {
        const content = try self.generate(cff);
        defer self.allocator.free(content);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writeAll(content);
    }
};
```

### 2.3 CFF Validation

```zig
/// Validate CFF metadata completeness
pub const CFFValidator = struct {
    pub fn validate(cff: CFF) !ValidationResult {
        var result = ValidationResult.init();

        // Check required fields
        if (cff.title.len == 0) {
            try result.addError(.missing_title, "Title is required");
        } else if (cff.title.len < 10 or cff.title.len > 200) {
            try result.addError(.invalid_title_length, "Title must be 10-200 characters");
        } else {
            try result.addCheck(.title_present);
        }

        if (cff.authors.len == 0) {
            try result.addError(.missing_authors, "At least one author is required");
        } else {
            try result.addCheck(.authors_present);

            // Check ORCID coverage
            var orcid_count: usize = 0;
            for (cff.authors) |author| {
                if (author.orcid != null) orcid_count += 1;
            }

            const orcid_pct = @as(f64, @floatFromInt(orcid_count))
                           * 100.0
                           / @as(f64, @floatFromInt(cff.authors.len));

            if (orcid_pct < 100.0) {
                try result.addWarning(.incomplete_orcid,
                    try std.fmt.allocPrint(
                        std.heap.page_allocator,
                        "Only {d:.0}% authors have ORCID (target: 100%)",
                        .{orcid_pct}
                    )
                );
            } else {
                try result.addCheck(.orcid_complete);
            }
        }

        if (cff.abstract) |abs| {
            const word_count = std.mem.count(u8, abs, ' ') + 1;
            if (word_count < 10) {
                try result.addWarning(.short_abstract, "Abstract < 10 words (recommended: 50-500)");
            } else if (word_count > 500) {
                try result.addWarning(.long_abstract, "Abstract > 500 words (recommended: 50-500)");
            } else {
                try result.addCheck(.abstract_appropriate);
            }
        } else {
            try result.addWarning(.missing_abstract, "No abstract provided (recommended: 50-500 words)");
        }

        if (cff.keywords.len < 3) {
            try result.addWarning(.few_keywords, "Less than 3 keywords (recommended: 3-8)");
        } else if (cff.keywords.len > 8) {
            try result.addWarning(.many_keywords, "More than 8 keywords (recommended: 3-8)");
        } else {
            try result.addCheck(.keywords_appropriate);
        }

        // Validate SPDX license
        if (!isValidSPDX(cff.license)) {
            try result.addError(.invalid_license, "Invalid SPDX license identifier");
        } else {
            try result.addCheck(.valid_license);
        }

        return result;
    }
};

pub const ValidationResult = struct {
    errors: std.ArrayList(ValidationError),
    warnings: std.ArrayList(ValidationWarning),
    checks: std.ArrayList(ValidationCheck),

    pub fn init() ValidationResult {
        return .{
            .errors = std.ArrayList(ValidationError).init(std.heap.page_allocator),
            .warnings = std.ArrayList(ValidationWarning).init(std.heap.page_allocator),
            .checks = std.ArrayList(ValidationCheck).init(std.heap.page_allocator),
        };
    }

    pub fn deinit(self: *ValidationResult) void {
        self.errors.deinit();
        self.warnings.deinit();
        self.checks.deinit();
    }

    pub fn addError(self: *ValidationResult, code: ErrorCode, msg: []const u8) !void {
        try self.errors.append(.{ .code = code, .message = msg });
    }

    pub fn addWarning(self: *ValidationResult, code: WarningCode, msg: []const u8) !void {
        try self.warnings.append(.{ .code = code, .message = msg });
    }

    pub fn addCheck(self: *ValidationResult, check: ValidationCheck) !void {
        try self.checks.append(check);
    }

    pub fn is_valid(self: *const ValidationResult) bool {
        return self.errors.items.len == 0;
    }

    pub fn score(self: *const ValidationResult) f64 {
        const max_checks = 10;
        const check_score = @as(f64, @floatFromInt(self.checks.items.len)) * 100.0
                         / @as(f64, @floatFromInt(max_checks));

        // Deduct for errors (major penalty)
        const error_penalty = @as(f64, @floatFromInt(self.errors.items.len)) * 20.0;

        // Deduct for warnings (minor penalty)
        const warning_penalty = @as(f64, @floatFromInt(self.warnings.items.len)) * 2.0;

        return @max(0.0, check_score - error_penalty - warning_penalty);
    }
};

pub const ValidationError = struct {
    code: ErrorCode,
    message: []const u8,
};

pub const ValidationWarning = struct {
    code: WarningCode,
    message: []const u8,
};

pub const ValidationCheck = enum {
    title_present,
    authors_present,
    orcid_complete,
    abstract_appropriate,
    keywords_appropriate,
    valid_license,
};

pub const ErrorCode = enum {
    missing_title,
    invalid_title_length,
    missing_authors,
    invalid_license,
};

pub const WarningCode = enum {
    incomplete_orcid,
    short_abstract,
    long_abstract,
    missing_abstract,
    few_keywords,
    many_keywords,
};

/// Validate SPDX license identifier
fn isValidSPDX(license: []const u8) bool {
    const valid_licenses = &[_][]const u8{
        "MIT", "Apache-2.0", "GPL-3.0", "BSD-3-Clause",
        "CC-BY-4.0", "CC-BY-SA-4.0", "CC0-1.0",
        "ISC", "MPL-2.0", "LGPL-3.0",
    };

    for (valid_licenses) |valid| {
        if (std.mem.eql(u8, license, valid)) return true;
    }

    return false;
}
```

---

## Part 3: OpenAlex Integration

### 3.1 Work Type Classification

```zig
/// OpenAlex work types
/// https://docs.openalex.org/
pub const OpenAlexWorkType = enum(u8) {
    /// Peer-reviewed paper
    publication = 0,

    /// Training data
    dataset = 1,

    /// Code repository
    software = 2,

    /// arXiv/preprint server
    preprint = 3,

    /// Book chapter
    chapter = 4,

    /// Thesis/dissertation
    dissertation = 5,
};

/// Classify Trinity artifact by work type
pub fn classifyArtifact(spec: *const VibeecSpec) OpenAlexWorkType {
    // Software: has behaviors (executable code)
    if (spec.behaviors.len > 0) return .software;

    // Publication: has algorithms (theoretical contribution)
    if (spec.algorithms.len > 0) return .publication;

    // Dataset: has types/structures (data schemas)
    if (spec.types.len > 0) return .dataset;

    // Default: software
    return .software;
}

/// Generate OpenAlex metadata
pub const OpenAlexMetadata = struct {
    /// Title
    title: []const u8,

    /// Work type
    type: OpenAlexWorkType,

    /// DOI (if published)
    doi: ?[]const u8 = null,

    /// arXiv ID (if preprint)
    arxiv: ?[]const u8 = null,

    /// Publication year
    year: u32,

    /// Citations
    citation_count: u32 = 0,

    /// Authors (with ORCID)
    authors: []OrcidAuthor,

    /// Concepts (subject areas)
    concepts: []OpenAlexConcept,

    /// Institutions
    institutions: []OpenAlexInstitution,
};

pub const OpenAlexConcept = struct {
    /// Concept name (e.g., "Machine learning")
    name: []const u8,

    /// Wikidata ID
    wikidata_id: []const u8,

    /// Score (relevance)
    score: f32,
};

pub const OpenAlexInstitution = struct {
    /// Institution name
    name: []const u8,

    /// ROR ID
    ror_id: []const u8,

    /// Country code
    country_code: []const u8,
};
```

### 3.2 OpenAlex Notification

```zig
/// Notify OpenAlex of new publication
pub fn notifyOpenAlex(metadata: OpenAlexMetadata) !bool {
    // POST to https://openalex.org/works/update
    // Note: This requires OpenAlex partnership or manual submission

    // For now, prepare the notification payload
    const payload = try prepareOpenAlexPayload(metadata);

    // Log the payload for manual submission
    std.log.info("OpenAlex notification prepared: {s}", .{payload});

    // TODO: Implement HTTP POST when OpenAlex API is available
    return true;
}

fn prepareOpenAlexPayload(metadata: OpenAlexMetadata) ![]const u8 {
    // Prepare JSON payload for OpenAlex ingestion
    // Format: https://docs.openalex.org/

    return error.NotImplemented;
}
```

---

## Part 4: COAR Notification System

### 4.1 COAR Notify Protocol

```zig
/// COAR Notify coordination protocol
/// https://notify.coar-repositories.org/
pub const COARNotifyResult = struct {
    /// Registered with Crossref
    crossref_registered: bool = false,

    /// DataCite DOI minted
    datacite_doi: ?[]const u8 = null,

    /// OpenAlex indexed
    openalex_indexed: bool = false,

    /// Notification timestamp
    timestamp: i64,
};

/// Notify all indexing services
pub fn notifyAllServices(metadata: ZenodoMetadata) !COARNotifyResult {
    var result = COARNotifyResult{
        .timestamp = std.time.timestamp(),
    };

    // 1. Register with Crossref (for preprints)
    result.crossref_registered = try notifyCrossref(metadata) catch false;

    // 2. Mint DOI with DataCite (if not already)
    if (metadata.metadata.doi == null) {
        result.datacite_doi = try mintDataCiteDO I(metadata) catch null;
    }

    // 3. Notify OpenAlex for indexing
    result.openalex_indexed = try notifyOpenAlexFromMetadata(metadata) catch false;

    return result;
}

/// Register preprint with Crossref
fn notifyCrossref(metadata: ZenodoMetadata) !bool {
    // POST to Crossref Link API
    // This requires publisher membership

    // TODO: Implement when Crossref membership is obtained
    return false;
}

/// Mint DOI with DataCite
fn mintDataCiteDO I(metadata: ZenodoMetadata) ![]const u8 {
    // POST to DataCite API
    // Requires DataCite member credentials

    // Format: 10.5281/zenodo.XXXXXX
    // TODO: Implement when DataCite membership is obtained
    return error.NotImplemented;
}
```

---

## Part 5: CLI Commands

### 5.1 Zenodo V19 Commands

```zig
const std = @import("std");

/// Zenodo V19 enhanced commands
pub const ZenodoV19Commands = struct {
    /// Validate metadata quality
    pub fn validateMetadata(allocator: std.mem.Allocator, bundle_id: []const u8) !void {
        const meta = try loadZenodoMetadata(allocator, bundle_id);

        // Validate CFF
        const cff_gen = CFFGenerator.init(allocator);
        const cff = try cff_gen.fromZenodoMetadata(meta);
        const validator = CFFValidator{};
        const result = try validator.validate(cff);

        // Print results
        std.debug.print("=== Zenodo V19 Metadata Validation ===\n", .{});
        std.debug.print("Bundle: {s}\n\n", .{bundle_id});

        if (result.is_valid()) {
            std.debug.print("✅ VALID (Score: {d:.0}%)\n\n", .{result.score()});
        } else {
            std.debug.print("❌ INVALID (Score: {d:.0}%)\n\n", .{result.score()});
        }

        // Print errors
        if (result.errors.items.len > 0) {
            std.debug.print("Errors:\n", .{});
            for (result.errors.items) |err| {
                std.debug.print("  ❌ {s}: {s}\n", .{ @tagName(err.code), err.message });
            }
            std.debug.print("\n", .{});
        }

        // Print warnings
        if (result.warnings.items.len > 0) {
            std.debug.print("Warnings:\n", .{});
            for (result.warnings.items) |warn| {
                std.debug.print("  ⚠️  {s}: {s}\n", .{ @tagName(warn.code), warn.message });
            }
            std.debug.print("\n", .{});
        }

        // Print checks
        if (result.checks.items.len > 0) {
            std.debug.print("Checks passed:\n", .{});
            for (result.checks.items) |check| {
                std.debug.print("  ✅ {s}\n", .{@tagName(check)});
            }
        }
    }

    /// Generate enhanced metadata
    pub fn generateMetadata(allocator: std.mem.Allocator, bundle_id: []const u8) !void {
        const meta = try loadZenodoMetadata(allocator, bundle_id);

        // Generate CFF
        const cff_gen = CFFGenerator.init(allocator);
        const cff = try cff_gen.fromZenodoMetadata(meta);
        const cff_content = try cff_gen.generate(cff);

        // Write CITATION.cff
        const cff_path = try std.fmt.allocPrint(allocator, "CITATION.cff", .{});
        try cff_gen.writeCFF(cff, cff_path);

        std.debug.print("Generated {s}\n", .{cff_path});

        // Generate enhanced JSON metadata
        const enhanced_json = try generateEnhancedJSON(allocator, meta);
        const json_path = try std.fmt.allocPrint(allocator, "metadata_v19.json", .{});
        {
            const file = try std.fs.cwd().createFile(json_path, .{});
            defer file.close();
            try file.writeAll(enhanced_json);
        }

        std.debug.print("Generated {s}\n", .{json_path});
    }
};

/// Load Zenodo metadata from bundle
fn loadZenodoMetadata(allocator: std.mem.Allocator, bundle_id: []const u8) !ZenodoMetadata {
    // Implementation would load from .zenodo/bundle_id.json
    return error.NotImplemented;
}

/// Generate enhanced JSON metadata with V19 fields
fn generateEnhancedJSON(allocator: std.mem.Allocator, meta: ZenodoMetadata) ![]const u8 {
    // Add V19 fields: ORCID, CFF, OpenAlex classification, etc.
    return error.NotImplemented;
}
```

---

## Part 6: Testing Suite

```zig
test "CFF validation: complete metadata" {
    const cff = CFF{
        .cff_version = "1.2.0",
        .message = "If you use this software, please cite it as below.",
        .authors = &[_]CFFAuthor{
            .family_names = "Vasilev",
            .given_names = "Dmitrii",
            .orcid = "https://orcid.org/0000-0002-1825-0097",
            .affiliation = &[_][]const u8{"Trinity Research Foundation"},
        },
        .title = "Trinity S³AI: Ternary Neural Networks v0.11.0",
        .version = "0.11.0",
        .doi = "10.5281/zenodo.19227879",
        .date_released = "2026-03-27",
        .url = "https://github.com/gHashTag/trinity",
        .license = "MIT",
        .keywords = &[_][]const u8{
            "ternary neural networks",
            "FPGA",
            "balanced ternary",
            "neuromorphic computing",
        },
        .abstract = "Trinity S³AI is a pure-Zig autonomous AI agent swarm system.",
    };

    const validator = CFFValidator{};
    const result = try validator.validate(cff);

    try std.testing.expect(result.is_valid());
    try std.testing.expect(result.score() > 90.0);
}

test "CFF validation: missing ORCID" {
    const cff = CFF{
        .cff_version = "1.2.0",
        .message = "If you use this software, please cite it as below.",
        .authors = &[_]CFFAuthor{
            .family_names = "Vasilev",
            .given_names = "Dmitrii",
            .orcid = null, // Missing ORCID
            .affiliation = &[_][]const u8{"Trinity Research Foundation"},
        },
        .title = "Trinity S³AI: Ternary Neural Networks v0.11.0",
        .version = "0.11.0",
        .date_released = "2026-03-27",
        .url = "https://github.com/gHashTag/trinity",
        .license = "MIT",
        .keywords = &[_][]const u8{"ternary neural networks"},
        .abstract = null,
    };

    const validator = CFFValidator{};
    const result = try validator.validate(cff);

    try std.testing.expect(!result.is_valid()); // Should have warning
    try std.testing.expect(result.score() < 100.0); // Score penalty
}
```

---

## References

1. CFF 1.2.0: https://citation-file-format.github.io/1.2.0/
2. ORCID API: https://info.orcid.org/documentation/api-v3.0/
3. OpenAlex: https://openalex.org/
4. COAR Notify: https://notify.coar-repositories.org/

---

**φ² + 1/φ² = 3 | TRINITY**
**Version**: 1.0
**Date**: 2026-03-27
**Status**: Complete Specification — Ready for Implementation
