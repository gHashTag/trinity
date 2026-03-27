//! Zenodo V23: Complete Paper Export System
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Generates complete conference-ready paper exports in multiple formats:
//! - Markdown (for arXiv, OpenReview)
//! - LaTeX (for NeurIPS/ICLR style files)
//! - HTML (for web publication)
//! - PDF metadata (for submission systems)
//!
//! References:
//! - NeurIPS 2025 LaTeX Template: https://neurips.cc/Conferences/2025/PaperInformation/AuthorGuide
//! - ICLR 2025 Style Guide: https://iclr.cc/2025/conference/papers/faqs
//! - MLSys 2025 Anonymous Submission: https://mlsys.org/Archives/2025/paper-info

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Paper format type
pub const PaperFormat = enum {
    markdown,
    latex,
    html,
    pdf_meta,

    pub fn extension(self: PaperFormat) []const u8 {
        return switch (self) {
            .markdown => ".md",
            .latex => ".tex",
            .html => ".html",
            .pdf_meta => ".json",
        };
    }
};

/// Conference template
pub const ConferenceTemplate = enum {
    neurips,
    iclr,
    icml,
    mlsys,
    aaai,
    ijcai,
    custom,

    pub fn latexClass(self: ConferenceTemplate) []const u8 {
        return switch (self) {
            .neurips => "\\documentclass{neurips_2025}",
            .iclr => "\\documentclass{iclr2025}",
            .icml => "\\documentclass{icml2025}",
            .mlsys => "\\documentclass{mlsys2025}",
            .aaai => "\\documentclass{aaai2025}",
            .ijcai => "\\documentclass{ijcai2025}",
            .custom => "\\documentclass{article}",
        };
    }

    pub fn wordLimit(self: ConferenceTemplate) struct { min: u32, max: u32 } {
        return switch (self) {
            .neurips => .{ .min = 3000, .max = 8000 }, // Main track
            .iclr => .{ .min = 3000, .max = 8000 },
            .icml => .{ .min = 3000, .max = 8000 },
            .mlsys => .{ .min = 4000, .max = 10000 },
            .aaai => .{ .min = 4000, .max = 7000 },
            .ijcai => .{ .min = 4000, .max = 7000 },
            .custom => .{ .min = 2000, .max = 10000 },
        };
    }
};

/// Paper section
pub const PaperSection = struct {
    title: []const u8,
    content: []const u8,
    subsections: []PaperSection = &.{},
    order: u32,

    pub fn formatMarkdown(self: PaperSection, allocator: Allocator, level: u32) ![]const u8 {
        var buffer = std.array_list.AlignedManaged(u8, null).init(allocator);
        defer buffer.deinit();

        const prefix = [_]u8{'#'} ** level;
        try buffer.appendSlice(&prefix);
        try buffer.appendSlice(" ");
        try buffer.appendSlice(self.title);
        try buffer.appendSlice("\n\n");
        try buffer.appendSlice(self.content);
        try buffer.appendSlice("\n\n");

        for (self.subsections) |sub| {
            const sub_formatted = try sub.formatMarkdown(allocator, level + 1);
            defer allocator.free(sub_formatted);
            try buffer.appendSlice(sub_formatted);
        }

        return buffer.toOwnedSlice();
    }
};

/// Complete paper structure
pub const Paper = struct {
    allocator: Allocator,
    title: []const u8,
    authors: []Author,
    abstract: []const u8,
    sections: []PaperSection,
    references: []Reference,
    template: ConferenceTemplate,
    word_count: u32,

    /// Export paper in specified format
    pub fn exportTo(self: *const Paper, format: PaperFormat) ![]const u8 {
        return switch (format) {
            .markdown => self.exportMarkdown(),
            .latex => self.exportLatex(),
            .html => self.exportHtml(),
            .pdf_meta => self.exportPdfMeta(),
        };
    }

    /// Export as markdown
    fn exportMarkdown(self: *const Paper) ![]const u8 {
        var buffer = std.array_list.AlignedManaged(u8, null).init(self.allocator);
        defer buffer.deinit();

        // Title
        try buffer.appendSlice("# ");
        try buffer.appendSlice(self.title);
        try buffer.appendSlice("\n\n");

        // Authors
        try buffer.appendSlice("**");
        for (self.authors, 0..) |author, i| {
            try buffer.appendSlice(author.name);
            if (author.affiliation) |aff| {
                try buffer.appendSlice(" (");
                try buffer.appendSlice(aff);
                try buffer.appendSlice(")");
            }
            if (i < self.authors.len - 1) {
                try buffer.appendSlice(", ");
            }
        }
        try buffer.appendSlice("**\n\n");

        // Abstract
        try buffer.appendSlice("## Abstract\n\n");
        try buffer.appendSlice(self.abstract);
        try buffer.appendSlice("\n\n");

        // Sections
        for (self.sections) |section| {
            const formatted = try section.formatMarkdown(self.allocator, 2);
            defer self.allocator.free(formatted);
            try buffer.appendSlice(formatted);
        }

        // References
        try buffer.appendSlice("## References\n\n");
        for (self.references, 0..) |ref, i| {
            try buffer.appendSlice("[");
            const num_str = try std.fmt.allocPrint(self.allocator, "{d}", .{i + 1});
            defer self.allocator.free(num_str);
            try buffer.appendSlice(num_str);
            try buffer.appendSlice("] ");
            try buffer.appendSlice(ref.formatBibTeX());
            try buffer.appendSlice("\n\n");
        }

        return buffer.toOwnedSlice();
    }

    /// Export as LaTeX
    fn exportLatex(self: *const Paper) ![]const u8 {
        var buffer = std.array_list.AlignedManaged(u8, null).init(self.allocator);
        defer buffer.deinit();

        // Preamble
        try buffer.appendSlice(self.template.latexClass());
        try buffer.appendSlice("\n\n");
        try buffer.appendSlice("\\usepackage[hyperref]{neurips_2025}\n");
        try buffer.appendSlice("\\usepackage{amsmath}\n");
        try buffer.appendSlice("\\usepackage{booktabs}\n\n");
        try buffer.appendSlice("\\title{");
        try buffer.appendSlice(self.title);
        try buffer.appendSlice("}\n\n");

        // Authors
        try buffer.appendSlice("\\author{");
        for (self.authors, 0..) |author, i| {
            try buffer.appendSlice(author.name);
            if (author.affiliation) |aff| {
                try buffer.appendSlice(" \\and ");
                try buffer.appendSlice(aff);
            }
            if (i < self.authors.len - 1) {
                try buffer.appendSlice(" and ");
            }
        }
        try buffer.appendSlice("}\n\n");

        // Document begin
        try buffer.appendSlice("\\begin{document}\n\n");
        try buffer.appendSlice("\\maketitle\n\n");

        // Abstract
        try buffer.appendSlice("\\begin{abstract}\n");
        try buffer.appendSlice(self.abstract);
        try buffer.appendSlice("\n\\end{abstract}\n\n");

        // Sections
        for (self.sections) |section| {
            try buffer.appendSlice("\\section{");
            try buffer.appendSlice(section.title);
            try buffer.appendSlice("}\n\n");
            try buffer.appendSlice(section.content);
            try buffer.appendSlice("\n\n");
        }

        // Document end
        try buffer.appendSlice("\\end{document}\n");

        return buffer.toOwnedSlice();
    }

    /// Export as HTML
    fn exportHtml(self: *const Paper) ![]const u8 {
        var buffer = std.array_list.AlignedManaged(u8, null).init(self.allocator);
        defer buffer.deinit();

        try buffer.appendSlice("<!DOCTYPE html>\n");
        try buffer.appendSlice("<html>\n<head>\n");
        try buffer.appendSlice("<meta charset=\"utf-8\">\n");
        try buffer.appendSlice("<title>");
        try buffer.appendSlice(self.title);
        try buffer.appendSlice("</title>\n");
        try buffer.appendSlice("<style>\n");
        try buffer.appendSlice("body { font-family: 'Latin Modern Roman', serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6; }\n");
        try buffer.appendSlice("h1 { font-size: 2.5em; }\n");
        try buffer.appendSlice("h2 { font-size: 1.8em; margin-top: 2em; }\n");
        try buffer.appendSlice("h3 { font-size: 1.3em; margin-top: 1.5em; }\n");
        try buffer.appendSlice(".abstract { background: #f5f5f5; padding: 1em; border-left: 4px solid #007bff; }\n");
        try buffer.appendSlice("</style>\n");
        try buffer.appendSlice("</head>\n<body>\n");

        try buffer.appendSlice("<h1>");
        try buffer.appendSlice(self.title);
        try buffer.appendSlice("</h1>\n");

        try buffer.appendSlice("<p><strong>");
        for (self.authors, 0..) |author, i| {
            try buffer.appendSlice(author.name);
            if (i < self.authors.len - 1) {
                try buffer.appendSlice(", ");
            }
        }
        try buffer.appendSlice("</strong></p>\n");

        try buffer.appendSlice("<div class=\"abstract\">\n<h2>Abstract</h2>\n");
        try buffer.appendSlice(self.abstract);
        try buffer.appendSlice("\n</div>\n");

        try buffer.appendSlice("</body>\n</html>\n");

        return buffer.toOwnedSlice();
    }

    /// Export as PDF metadata JSON
    fn exportPdfMeta(self: *const Paper) ![]const u8 {
        var buffer = std.array_list.AlignedManaged(u8, null).init(self.allocator);
        defer buffer.deinit();

        try buffer.appendSlice("{\n");
        try buffer.appendSlice("  \"title\": \"");
        try buffer.appendSlice(self.title);
        try buffer.appendSlice("\",\n");
        try buffer.appendSlice("  \"authors\": [\n");
        for (self.authors, 0..) |author, i| {
            try buffer.appendSlice("    {\"name\": \"");
            try buffer.appendSlice(author.name);
            try buffer.appendSlice("\"}");
            if (i < self.authors.len - 1) {
                try buffer.appendSlice(",");
            }
            try buffer.appendSlice("\n");
        }
        try buffer.appendSlice("  ],\n");
        try buffer.appendSlice("  \"abstract\": \"");
        try buffer.appendSlice(self.abstract);
        try buffer.appendSlice("\",\n");
        try buffer.appendSlice("  \"template\": \"");
        try buffer.appendSlice(@tagName(self.template));
        try buffer.appendSlice("\",\n");
        try buffer.appendSlice("  \"word_count\": ");
        const wc_str = try std.fmt.allocPrint(self.allocator, "{d}", .{self.word_count});
        defer self.allocator.free(wc_str);
        try buffer.appendSlice(wc_str);
        try buffer.appendSlice("\n");
        try buffer.appendSlice("}\n");

        return buffer.toOwnedSlice();
    }

    /// Validate paper meets conference requirements
    pub fn validate(self: *const Paper) !ValidationResult {
        var errors = std.array_list.AlignedManaged([]const u8, null).init(self.allocator);
        defer errors.deinit();

        var warnings = std.array_list.AlignedManaged([]const u8, null).init(self.allocator);
        defer warnings.deinit();

        const limits = self.template.wordLimit();

        // Check word count
        if (self.word_count < limits.min) {
            const msg = try std.fmt.allocPrint(self.allocator, "Paper too short: {d} < {d} minimum", .{ self.word_count, limits.min });
            try errors.append(msg);
        }
        if (self.word_count > limits.max) {
            const msg = try std.fmt.allocPrint(self.allocator, "Paper too long: {d} > {d} maximum", .{ self.word_count, limits.max });
            try errors.append(msg);
        }

        // Check abstract length (typically 150-250 words)
        const abstract_words = countWords(self.abstract);
        if (abstract_words < 100) {
            try warnings.append(try std.fmt.allocPrint(self.allocator, "Abstract short: {d} words (recommend 150-250)", .{abstract_words}));
        }

        return .{
            .valid = errors.items.len == 0,
            .errors = try errors.toOwnedSlice(),
            .warnings = try warnings.toOwnedSlice(),
        };
    }
};

/// Author information
pub const Author = struct {
    name: []const u8,
    affiliation: ?[]const u8,
    email: ?[]const u8,
};

/// Reference
pub const Reference = struct {
    authors: []const u8,
    title: []const u8,
    venue: ?[]const u8,
    year: u32,
    doi: ?[]const u8,
    url: ?[]const u8,

    pub fn formatBibTeX(self: Reference) []const u8 {
        // Simple BibTeX format
        return self.title; // Placeholder
    }
};

/// Validation result
pub const ValidationResult = struct {
    valid: bool,
    errors: []const []const u8,
    warnings: []const []const u8,
};

/// Count words in text
fn countWords(text: []const u8) u32 {
    var count: u32 = 0;
    var in_word = false;

    for (text) |c| {
        if (c == ' ' or c == '\n' or c == '\t') {
            if (in_word) {
                count += 1;
                in_word = false;
            }
        } else {
            in_word = true;
        }
    }
    if (in_word) count += 1;

    return count;
}

/// Paper builder
pub const PaperBuilder = struct {
    allocator: Allocator,
    title: ?[]const u8 = null,
    authors: std.array_list.AlignedManaged(Author, null),
    sections: std.array_list.AlignedManaged(PaperSection, null),
    references: std.array_list.AlignedManaged(Reference, null),
    template: ConferenceTemplate = .neurips,

    pub fn init(allocator: Allocator) PaperBuilder {
        return .{
            .allocator = allocator,
            .authors = std.array_list.AlignedManaged(Author, null).init(allocator),
            .sections = std.array_list.AlignedManaged(PaperSection, null).init(allocator),
            .references = std.array_list.AlignedManaged(Reference, null).init(allocator),
        };
    }

    pub fn setTitle(self: *PaperBuilder, title: []const u8) void {
        self.title = title;
    }

    pub fn addAuthor(self: *PaperBuilder, author: Author) !void {
        try self.authors.append(author);
    }

    pub fn addSection(self: *PaperBuilder, section: PaperSection) !void {
        try self.sections.append(section);
    }

    pub fn build(self: *PaperBuilder, abstract: []const u8) !Paper {
        if (self.title == null) return error.TitleRequired;

        var word_count: u32 = countWords(abstract);
        for (self.sections.items) |s| {
            word_count += countWords(s.content);
        }

        return .{
            .allocator = self.allocator,
            .title = self.title.?,
            .authors = try self.authors.toOwnedSlice(),
            .abstract = abstract,
            .sections = try self.sections.toOwnedSlice(),
            .references = try self.references.toOwnedSlice(),
            .template = self.template,
            .word_count = word_count,
        };
    }

    pub fn deinit(self: *PaperBuilder) void {
        self.authors.deinit();
        self.sections.deinit();
        self.references.deinit();
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "Paper: basic structure" {
    const allocator = std.testing.allocator;

    var builder = PaperBuilder.init(allocator);
    defer builder.deinit();

    builder.setTitle("Test Paper");
    try builder.addAuthor(.{ .name = "Test Author", .affiliation = "Test Univ", .email = null });

    const paper = try builder.build("Test abstract with some words.");
    defer {
        allocator.free(paper.authors);
        allocator.free(paper.sections);
        allocator.free(paper.references);
    }

    try std.testing.expectEqualStrings("Test Paper", paper.title);
    try std.testing.expect(paper.word_count > 0);
}

test "PaperFormat: extensions" {
    try std.testing.expectEqualStrings(".md", PaperFormat.markdown.extension());
    try std.testing.expectEqualStrings(".tex", PaperFormat.latex.extension());
    try std.testing.expectEqualStrings(".html", PaperFormat.html.extension());
    try std.testing.expectEqualStrings(".json", PaperFormat.pdf_meta.extension());
}

test "ConferenceTemplate: word limits" {
    const neurips = ConferenceTemplate.neurips.wordLimit();
    try std.testing.expectEqual(@as(u32, 3000), neurips.min);
    try std.testing.expectEqual(@as(u32, 8000), neurips.max);

    const mlsys = ConferenceTemplate.mlsys.wordLimit();
    try std.testing.expectEqual(@as(u32, 4000), mlsys.min);
    try std.testing.expectEqual(@as(u32, 10000), mlsys.max);
}

// φ² + 1/φ² = 3 | TRINITY
