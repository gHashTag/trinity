// ═══════════════════════════════════════════════════════════════════════════════
// Zenodo V18: JSON-LD Metadata Generator
// ═══════════════════════════════════════════════════════════════════════════════
//
// Generates machine-readable JSON-LD metadata for web crawlers and FAIR compliance.
// Implements Schema.org and DataCite 4.5 standards.
//
// References:
// - Schema.org: https://schema.org/SoftwareSourceCode
// - DataCite 4.5: https://schema.datacite.org/meta/kernel-4.5/
// - JSON-LD: https://www.w3.org/TR/json-ld/
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// JSON-LD metadata generator
pub const JsonLdGenerator = struct {
    /// Base metadata
    metadata: ZenodoMetadata,

    /// Additional Schema.org properties
    schema_properties: []const SchemaProperty = &.{},

    /// Additional DataCite properties
    datacite_properties: []const DataCiteProperty = &.{},

    /// Generate complete JSON-LD document
    pub fn generate(self: JsonLdGenerator, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 8192);
        defer buffer.deinit(allocator);

        try buffer.appendSlice(allocator, "{\n");

        // @context
        try buffer.appendSlice(allocator, "  \"@context\": [\n");
        try buffer.appendSlice(allocator, "    \"https://schema.org\",\n");
        try buffer.appendSlice(allocator, "    \"https://w3id.org/dcso/ns\"\n");
        try buffer.appendSlice(allocator, "  ],\n");

        // @type
        try buffer.appendSlice(allocator, "  \"@type\": \"SoftwareSourceCode\",\n");

        // Identifier (DOI)
        if (self.metadata.doi) |doi| {
            try buffer.appendSlice(allocator, "  \"identifier\": \"");
            try buffer.appendSlice(allocator, doi);
            try buffer.appendSlice(allocator, "\",\n");
        }

        // Name
        try buffer.appendSlice(allocator, "  \"name\": \"");
        try appendEscaped(allocator, &buffer, self.metadata.title);
        try buffer.appendSlice(allocator, "\",\n");

        // Description
        if (self.metadata.description.len > 0) {
            try buffer.appendSlice(allocator, "  \"description\": \"");
            try appendEscaped(allocator, &buffer, self.metadata.description);
            try buffer.appendSlice(allocator, "\",\n");
        }

        // Authors
        if (self.metadata.authors.len > 0) {
            try buffer.appendSlice(allocator, "  \"author\": [\n");
            for (self.metadata.authors, 0..) |author, i| {
                try buffer.appendSlice(allocator, "    {\n");
                try buffer.appendSlice(allocator, "      \"@type\": \"Person\",\n");
                try buffer.appendSlice(allocator, "      \"name\": \"");
                try appendEscaped(allocator, &buffer, author);
                try buffer.appendSlice(allocator, "\"");
                try buffer.appendSlice(allocator, if (i < self.metadata.authors.len - 1) "\n    }," else "\n    }");
                try buffer.appendSlice(allocator, "\n");
            }
            try buffer.appendSlice(allocator, "  ],\n");
        }

        // License
        if (self.metadata.license) |license| {
            try buffer.appendSlice(allocator, "  \"license\": \"");
            try buffer.appendSlice(allocator, license);
            try buffer.appendSlice(allocator, "\",\n");
        }

        // Programming language
        if (self.metadata.programming_language) |pl| {
            try buffer.appendSlice(allocator, "  \"programmingLanguage\": \"");
            try buffer.appendSlice(allocator, pl);
            try buffer.appendSlice(allocator, "\",\n");
        }

        // Keywords
        if (self.metadata.keywords.len > 0) {
            try buffer.appendSlice(allocator, "  \"keywords\": [");
            for (self.metadata.keywords, 0..) |kw, i| {
                try buffer.appendSlice(allocator, "\"");
                try appendEscaped(allocator, &buffer, kw);
                try buffer.appendSlice(allocator, "\"");
                if (i < self.metadata.keywords.len - 1) try buffer.appendSlice(allocator, ", ");
            }
            try buffer.appendSlice(allocator, "],\n");
        }

        // Date published
        if (self.metadata.publication_date) |date| {
            try buffer.appendSlice(allocator, "  \"datePublished\": \"");
            try buffer.appendSlice(allocator, date);
            try buffer.appendSlice(allocator, "\",\n");
        }

        // Version
        if (self.metadata.version) |ver| {
            try buffer.appendSlice(allocator, "  \"version\": \"");
            try buffer.appendSlice(allocator, ver);
            try buffer.appendSlice(allocator, "\",\n");
        }

        // Code repository
        if (self.metadata.code_repository) |repo| {
            try buffer.appendSlice(allocator, "  \"codeRepository\": \"");
            try buffer.appendSlice(allocator, repo);
            try buffer.appendSlice(allocator, "\",\n");
        }

        // Is part of (parent DOI)
        if (self.metadata.parent_doi) |parent| {
            try buffer.appendSlice(allocator, "  \"isPartOf\": {\n");
            try buffer.appendSlice(allocator, "    \"@type\": \"SoftwareSourceCode\",\n");
            try buffer.appendSlice(allocator, "    \"identifier\": \"");
            try buffer.appendSlice(allocator, parent);
            try buffer.appendSlice(allocator, "\"\n");
            try buffer.appendSlice(allocator, "  },\n");
        }

        // Close main object
        // Remove trailing comma if needed
        if (buffer.items.len > 0 and buffer.items[buffer.items.len - 1] == ',') {
            _ = buffer.pop();
        }
        try buffer.appendSlice(allocator, "\n}\n");

        return buffer.toOwnedSlice(allocator);
    }

    /// Generate HTML script tag for embedding
    pub fn generateHtmlScript(self: JsonLdGenerator, allocator: std.mem.Allocator) ![]const u8 {
        const json = try self.generate(allocator);
        defer allocator.free(json);

        return std.fmt.allocPrint(allocator,
            \\<!-- JSON-LD structured data for FAIR compliance -->
            \\<script type="application/ld+json">
            \\{s}
            \\</script>
        , .{json});
    }

    /// Validate against Schema.org
    pub fn validateSchemaOrg(self: JsonLdGenerator, allocator: std.mem.Allocator) !ValidationResult {
        var errors = try std.ArrayList([]const u8).initCapacity(allocator, 10);
        defer errors.deinit(allocator);

        // Required fields
        if (self.metadata.title.len == 0) {
            try errors.append(allocator, "Schema.org: 'name' is required");
        }
        if (self.metadata.authors.len == 0) {
            try errors.append(allocator, "Schema.org: 'author' is required");
        }

        // Recommended fields
        if (self.metadata.description.len < 50) {
            try errors.append(allocator, "Schema.org: 'description' should be at least 50 characters");
        }
        if (self.metadata.keywords.len < 3) {
            try errors.append(allocator, "Schema.org: at least 3 'keywords' recommended");
        }

        return ValidationResult{
            .valid = errors.items.len == 0,
            .errors = try errors.toOwnedSlice(allocator),
        };
    }

    /// Escape JSON string
    fn appendEscaped(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8), input: []const u8) !void {
        for (input) |c| {
            switch (c) {
                '\\' => try buffer.appendSlice(allocator, "\\\\"),
                '"' => try buffer.appendSlice(allocator, "\\\""),
                '\n' => try buffer.appendSlice(allocator, "\\n"),
                '\r' => try buffer.appendSlice(allocator, "\\r"),
                '\t' => try buffer.appendSlice(allocator, "\\t"),
                else => try buffer.append(allocator, c),
            }
        }
    }
};

/// Zenodo metadata (minimal subset for JSON-LD generation)
pub const ZenodoMetadata = struct {
    title: []const u8 = "",
    authors: []const []const u8 = &.{},
    description: []const u8 = "",
    keywords: []const []const u8 = &.{},
    license: ?[]const u8 = null,
    doi: ?[]const u8 = null,
    publication_date: ?[]const u8 = null,
    version: ?[]const u8 = null,
    code_repository: ?[]const u8 = null,
    parent_doi: ?[]const u8 = null,
    programming_language: ?[]const u8 = null,
};

/// Schema.org property
pub const SchemaProperty = struct {
    name: []const u8,
    value: []const u8,
};

/// DataCite property
pub const DataCiteProperty = struct {
    name: []const u8,
    value: []const u8,
};

/// Validation result
pub const ValidationResult = struct {
    valid: bool,
    errors: []const []const u8,

    pub fn deinit(self: ValidationResult, allocator: std.mem.Allocator) void {
        for (self.errors) |err| {
            allocator.free(err);
        }
        if (self.errors.len > 0) {
            allocator.free(self.errors);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PRESETS
// ═══════════════════════════════════════════════════════════════════════════════

/// Default metadata for Trinity bundles
pub fn defaultTrinityMetadata(allocator: std.mem.Allocator, bundle_id: []const u8, version: []const u8) !ZenodoMetadata {
    const title = try std.fmt.allocPrint(allocator, "Trinity {s}: Ternary Neural Networks v{s}", .{ bundle_id, version });
    const description =
        \\Trinity S³AI is a pure-Zig autonomous AI agent swarm system implementing
        \\ternary neural networks with zero-DSP FPGA deployment.
        \\
        \\Key features:
        \\- Balanced ternary weights {-1, 0, +1}
        \\- 1.95M parameter HSLM achieving perplexity 125 on TinyStories
        \\- Zero-DSP FPGA deployment on XC7A100T
        \\- Full FAIR compliance and reproducibility
        \\
        \\φ² + 1/φ² = 3 | TRINITY
    ;

    return ZenodoMetadata{
        .title = title,
        .authors = &[_][]const u8{"Vasilev, Dmitrii"},
        .description = description,
        .keywords = &[_][]const u8{
            "ternary neural networks",
            "HSLM",
            "FPGA",
            "balanced ternary",
            "neuromorphic computing",
            "Zig",
            "zero-DSP",
        },
        .license = "MIT",
        .doi = null, // Set by caller
        .publication_date = "2026-03-27",
        .version = version,
        .code_repository = "https://github.com/gHashTag/trinity",
        .parent_doi = "10.5281/zenodo.19227879",
        .programming_language = "Zig",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "JsonLdGenerator: basic generation" {
    const metadata = ZenodoMetadata{
        .title = "Test Software",
        .authors = &[_][]const u8{"Test Author"},
        .description = "Test description",
        .keywords = &[_][]const u8{ "test", "software" },
        .license = "MIT",
        .doi = "10.5281/test",
    };

    const gen = JsonLdGenerator{ .metadata = metadata };
    const json = try gen.generate(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "@context") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "SoftwareSourceCode") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "Test Software") != null);
}

test "JsonLdGenerator: HTML script generation" {
    const metadata = ZenodoMetadata{
        .title = "Test",
        .authors = &[_][]const u8{"Author"},
    };

    const gen = JsonLdGenerator{ .metadata = metadata };
    const html = try gen.generateHtmlScript(std.testing.allocator);
    defer std.testing.allocator.free(html);

    try std.testing.expect(std.mem.indexOf(u8, html, "<script") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "application/ld+json") != null);
}

test "JsonLdGenerator: Schema.org validation" {
    const metadata_empty = ZenodoMetadata{};
    const gen_empty = JsonLdGenerator{ .metadata = metadata_empty };
    const result_empty = try gen_empty.validateSchemaOrg(std.testing.allocator);
    // Note: result_empty has dynamically allocated errors, skip deinit for simplicity

    try std.testing.expect(!result_empty.valid); // Should fail validation

    const metadata_full = ZenodoMetadata{
        .title = "Test Software",
        .authors = &[_][]const u8{"Author"},
        .description = "This is a test description that is long enough to pass validation",
        .keywords = &[_][]const u8{ "kw1", "kw2", "kw3" },
    };
    const gen_full = JsonLdGenerator{ .metadata = metadata_full };
    const result_full = try gen_full.validateSchemaOrg(std.testing.allocator);
    defer result_full.deinit(std.testing.allocator);

    try std.testing.expect(result_full.valid); // Should pass validation
}

test "JsonLdGenerator: JSON escaping" {
    const metadata = ZenodoMetadata{
        .title = "Test \"Quoted\" Title",
        .authors = &[_][]const u8{"Author\nWith\nNewlines"},
        .description = "Line 1\nLine 2\\Line 3",
    };

    const gen = JsonLdGenerator{ .metadata = metadata };
    const json = try gen.generate(std.testing.allocator);
    defer std.testing.allocator.free(json);

    // Check for escaped quotes
    try std.testing.expect(std.mem.indexOf(u8, json, "\\\"") != null);
    // Check for escaped newlines
    try std.testing.expect(std.mem.indexOf(u8, json, "\\n") != null);
}

test "ZenodoMetadata: default Trinity metadata" {
    const metadata = try defaultTrinityMetadata(std.testing.allocator, "B001", "9.0");

    try std.testing.expect(std.mem.indexOf(u8, metadata.title, "B001") != null);
    try std.testing.expectEqual(@as(usize, 7), metadata.keywords.len);
    try std.testing.expect(std.mem.eql(u8, "MIT", metadata.license.?));
}

// φ² + 1/φ² = 3 | TRINITY
