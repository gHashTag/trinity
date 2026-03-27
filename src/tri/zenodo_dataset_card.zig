//! Zenodo V16: Dataset Card Template
//!
//! This module implements NeurIPS 2025 compliant dataset cards
//! based on Gebru et al. (2021) "Datasheets for Datasets"
//!
//! Required sections per NeurIPS 2025:
//! - Motivation (why was this dataset created?)
//! - Composition (what data is it?)
//! - Collection Process (how was data collected?)
//! - Preprocessing (what cleaning steps?)
//! - Uses (what is this dataset used for?)
//! - Distribution (is data distributed?)
//! - Maintenance (who maintains it?)
//!
//! Additional requirements:
//! - Bias assessment (known biases in data)
//! - Sensitive personal information (SPI) disclosure
//! - Fairness considerations

const std = @import("std");

/// Dataset motivation categories
pub const DatasetMotivation = enum {
    /// Academic research
    academic_research,
    /// Commercial application
    commercial,
    /// Educational purposes
    educational,
    /// Government/public sector
    government,
    /// Personal/individual use
    personal,
    /// Other motivation
    other,

    pub fn displayName(self: DatasetMotivation) []const u8 {
        return switch (self) {
            .academic_research => "Academic Research",
            .commercial => "Commercial Application",
            .educational => "Educational",
            .government => "Government/Public Sector",
            .personal => "Personal/Individual",
            .other => "Other",
        };
    }
};

/// Data source information (provenance tracking)
pub const DataSource = struct {
    /// Source type (e.g., "synthetic", "crawled", "human-annotated")
    source_type: []const u8,
    /// Source URL or identifier
    source_url: ?[]const u8,
    /// Collection date range
    collection_date_start: ?[]const u8,
    collection_date_end: ?[]const u8,
    /// Collection cost (if applicable)
    collection_cost_usd: ?f64,

    pub fn formatAsMarkdown(self: *const DataSource, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 256);
        defer result.deinit(allocator);

        try result.appendSlice(allocator, "**Source Type**: ");
        try result.appendSlice(allocator, self.source_type);
        try result.appendSlice(allocator, "\\n");

        if (self.source_url) |url| {
            try result.appendSlice(allocator, "**Source URL**: ");
            try result.appendSlice(allocator, url);
            try result.appendSlice(allocator, "\\n");
        }

        if (self.collection_date_start) |start| {
            try result.appendSlice(allocator, "**Collection Period**: ");
            try result.appendSlice(allocator, start);
            if (self.collection_date_end) |end| {
                try result.appendSlice(allocator, " to ");
                try result.appendSlice(allocator, end);
            }
            try result.appendSlice(allocator, "\\n");
        }

        if (self.collection_cost_usd) |cost| {
            try result.appendSlice(allocator, "**Collection Cost**: ");
            const cost_str = try std.fmt.allocPrint(allocator, "${d:.2}", .{cost});
            defer allocator.free(cost_str);
            try result.appendSlice(allocator, cost_str);
            try result.appendSlice(allocator, "\\n");
        }

        return result.toOwnedSlice(allocator);
    }
};

/// Data split information
pub const DataSplit = struct {
    /// Split name (e.g., "train", "validation", "test")
    name: []const u8,
    /// Number of examples
    num_examples: u64,
    /// Percentage of total
    percentage: f64,
    /// Split description (optional)
    description: ?[]const u8,
};

/// Preprocessing step
pub const PreprocessingStep = struct {
    /// Step name
    name: []const u8,
    /// Step description
    description: ?[]const u8,
    /// Parameters used (optional)
    parameters: ?[]const []const u8,
};

/// Bias assessment (NeurIPS 2025 requirement)
pub const BiasAssessment = struct {
    /// Known biases in dataset
    known_biases: []const []const u8,
    /// Steps taken to mitigate bias
    mitigation_steps: []const []const u8,
    /// Whether bias was measured
    bias_measured: bool,
    /// Measurement results (if applicable)
    bias_metrics: ?[]const []const u8,

    pub fn formatAsMarkdown(self: *const BiasAssessment, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 512);
        defer result.deinit(allocator);

        try result.appendSlice(allocator, "**Known Biases**:\\n");
        for (self.known_biases) |bias| {
            try result.appendSlice(allocator, "- ");
            try result.appendSlice(allocator, bias);
            try result.appendSlice(allocator, "\\n");
        }

        try result.appendSlice(allocator, "**Bias Mitigation**:\\n");
        for (self.mitigation_steps) |step| {
            try result.appendSlice(allocator, "- ");
            try result.appendSlice(allocator, step);
            try result.appendSlice(allocator, "\\n");
        }

        if (self.bias_measured) {
            try result.appendSlice(allocator, "**Bias Measured**: Yes\\n");
        } else {
            try result.appendSlice(allocator, "**Bias Measured**: No\\n");
        }

        if (self.bias_metrics) |metrics| {
            try result.appendSlice(allocator, "**Bias Metrics**:\\n");
            for (metrics) |metric| {
                try result.appendSlice(allocator, "- ");
                try result.appendSlice(allocator, metric);
                try result.appendSlice(allocator, "\\n");
            }
        }

        return result.toOwnedSlice(allocator);
    }
};

/// Complete dataset card
pub const DatasetCard = struct {
    /// Dataset name
    dataset_name: []const u8,
    /// Dataset version
    dataset_version: []const u8,
    /// Dataset description
    description: []const u8,
    /// License
    license: []const u8,
    /// Total size in bytes
    size_bytes: u64,
    /// Total number of examples
    num_examples: u64,
    /// Motivation for dataset creation
    motivation: DatasetMotivation,
    /// Intended use cases
    intended_use: []const u8,
    /// Out-of-scope uses
    out_of_scope_use: ?[]const []const u8,
    /// Data splits
    splits: []const DataSplit,
    /// Data source
    source: DataSource,
    /// Preprocessing steps
    preprocessing: []const PreprocessingStep,
    /// Bias assessment
    bias_assessment: BiasAssessment,
    /// Curation rationale
    curation_rationale: ?[]const u8,
    /// Maintenance information
    maintenance: ?[]const u8,
    /// Citation BibTeX
    citation_bibtex: ?[]const u8,

    pub fn formatAsMarkdown(self: *const DatasetCard, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 4096);
        defer result.deinit(allocator);

        // Header
        try result.appendSlice(allocator, "# Dataset Card: ");
        try result.appendSlice(allocator, self.dataset_name);
        try result.appendSlice(allocator, "\\n\\n");

        try result.appendSlice(allocator, "**Version**: ");
        try result.appendSlice(allocator, self.dataset_version);
        try result.appendSlice(allocator, "\\n");

        try result.appendSlice(allocator, "**License**: ");
        try result.appendSlice(allocator, self.license);
        try result.appendSlice(allocator, "\\n");

        try result.appendSlice(allocator, "**Size**: ");
        const size_mb = @as(f64, @floatFromInt(self.size_bytes)) / (1024 * 1024);
        const size_str = try std.fmt.allocPrint(allocator, "{d:.2} MB", .{size_mb});
        defer allocator.free(size_str);
        try result.appendSlice(allocator, size_str);
        try result.appendSlice(allocator, "\\n");

        try result.appendSlice(allocator, "**Examples**: ");
        const num_str = try std.fmt.allocPrint(allocator, "{d}", .{self.num_examples});
        defer allocator.free(num_str);
        try result.appendSlice(allocator, num_str);
        try result.appendSlice(allocator, "\\n\\n");

        // Description
        try result.appendSlice(allocator, "## Description\\n\\n");
        try result.appendSlice(allocator, self.description);
        try result.appendSlice(allocator, "\\n\\n");

        // Motivation
        try result.appendSlice(allocator, "## Motivation\\n\\n");
        try result.appendSlice(allocator, "**Purpose**: ");
        try result.appendSlice(allocator, self.motivation.displayName());
        try result.appendSlice(allocator, "\\n");
        try result.appendSlice(allocator, "**Intended Use**: ");
        try result.appendSlice(allocator, self.intended_use);
        try result.appendSlice(allocator, "\\n\\n");

        // Out of Scope
        if (self.out_of_scope_use) |oos| {
            try result.appendSlice(allocator, "## Out-of-Scope Uses\\n\\n");
            for (oos) |use| {
                try result.appendSlice(allocator, "- ");
                try result.appendSlice(allocator, use);
                try result.appendSlice(allocator, "\\n");
            }
            try result.appendSlice(allocator, "\\n");
        }

        // Data Splits
        try result.appendSlice(allocator, "## Data Splits\\n\\n");
        try result.appendSlice(allocator, "| Split | Examples | Percentage |\\n");
        try result.appendSlice(allocator, "|-------|----------|------------|\\n");
        for (self.splits) |split| {
            try result.appendSlice(allocator, "| ");
            try result.appendSlice(allocator, split.name);
            try result.appendSlice(allocator, " | ");

            const n_str = try std.fmt.allocPrint(allocator, "{d}", .{split.num_examples});
            defer allocator.free(n_str);
            try result.appendSlice(allocator, n_str);
            try result.appendSlice(allocator, " | ");

            const pct = split.percentage * 100;
            const pct_str = try std.fmt.allocPrint(allocator, "{d:.1}%", .{pct});
            defer allocator.free(pct_str);
            try result.appendSlice(allocator, pct_str);
            try result.appendSlice(allocator, " |\\n");
        }
        try result.appendSlice(allocator, "\\n");

        // Data Source
        try result.appendSlice(allocator, "## Data Source\\n\\n");
        const source_md = try self.source.formatAsMarkdown(allocator);
        defer allocator.free(source_md);
        try result.appendSlice(allocator, source_md);
        try result.appendSlice(allocator, "\\n");

        // Preprocessing
        if (self.preprocessing.len > 0) {
            try result.appendSlice(allocator, "## Preprocessing\\n\\n");
            for (self.preprocessing) |step| {
                try result.appendSlice(allocator, "- **");
                try result.appendSlice(allocator, step.name);
                try result.appendSlice(allocator, "**");

                if (step.description) |desc| {
                    try result.appendSlice(allocator, ": ");
                    try result.appendSlice(allocator, desc);
                }

                if (step.parameters) |params| {
                    try result.appendSlice(allocator, " (");
                    for (params, 0..) |param, i| {
                        try result.appendSlice(allocator, param);
                        if (i < params.len - 1) {
                            try result.appendSlice(allocator, ", ");
                        }
                    }
                    try result.appendSlice(allocator, ")");
                }

                try result.appendSlice(allocator, "\\n");
            }
            try result.appendSlice(allocator, "\\n");
        }

        // Bias Assessment
        try result.appendSlice(allocator, "## Bias Assessment\\n\\n");
        const bias_md = try self.bias_assessment.formatAsMarkdown(allocator);
        defer allocator.free(bias_md);
        try result.appendSlice(allocator, bias_md);
        try result.appendSlice(allocator, "\\n");

        // Curation Rationale
        if (self.curation_rationale) |rationale| {
            try result.appendSlice(allocator, "## Curation Rationale\\n\\n");
            try result.appendSlice(allocator, rationale);
            try result.appendSlice(allocator, "\\n\\n");
        }

        // Maintenance
        if (self.maintenance) |maint| {
            try result.appendSlice(allocator, "## Maintenance\\n\\n");
            try result.appendSlice(allocator, maint);
            try result.appendSlice(allocator, "\\n\\n");
        }

        // Citation
        if (self.citation_bibtex) |cite| {
            try result.appendSlice(allocator, "## Citation\\n\\n");
            try result.appendSlice(allocator, "```bibtex\\n");
            try result.appendSlice(allocator, cite);
            try result.appendSlice(allocator, "\\n```\\n");
        }

        try result.appendSlice(allocator, "*Generated by Trinity Zenodo V16 Framework*\\n");
        try result.appendSlice(allocator, "*φ² + 1/φ² = 3 | TRINITY*\\n");

        return result.toOwnedSlice(allocator);
    }
};

// ═════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════

test "DatasetMotivation displayName" {
    try std.testing.expect(std.mem.eql(u8, DatasetMotivation.academic_research.displayName(), "Academic Research"));
    try std.testing.expect(std.mem.eql(u8, DatasetMotivation.commercial.displayName(), "Commercial Application"));
}

test "DataSource formatAsMarkdown" {
    const source = DataSource{
        .source_type = "synthetic",
        .source_url = "https://example.com",
        .collection_date_start = "2024-01-01",
        .collection_date_end = "2024-12-31",
        .collection_cost_usd = null,
    };

    const md = try source.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "synthetic") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "2024-01-01") != null);
}

test "BiasAssessment formatAsMarkdown" {
    const bias = BiasAssessment{
        .known_biases = &[_][]const u8{ "English language bias", "Western cultural bias" },
        .mitigation_steps = &[_][]const u8{ "Balanced sampling", "Cross-cultural validation" },
        .bias_measured = true,
        .bias_metrics = null,
    };

    const md = try bias.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "English language bias") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Balanced sampling") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Yes") != null);
}

test "DatasetCard basic formatAsMarkdown" {
    const card = DatasetCard{
        .dataset_name = "TinyStories-Ternary",
        .dataset_version = "1.0",
        .description = "Ternary-encoded version for HSLM training.",
        .license = "MIT",
        .size_bytes = 57_000_000,
        .num_examples = 57_000_000,
        .motivation = .academic_research,
        .intended_use = "Research in ternary language models",
        .out_of_scope_use = null,
        .splits = &[_]DataSplit{
            .{ .name = "train", .num_examples = 57_000_000, .percentage = 1.0, .description = null },
        },
        .source = .{ .source_type = "synthetic", .source_url = null, .collection_date_start = null, .collection_date_end = null, .collection_cost_usd = null },
        .preprocessing = &[_]PreprocessingStep{},
        .bias_assessment = .{ .known_biases = &[_][]const u8{"English language bias"}, .mitigation_steps = &[_][]const u8{}, .bias_measured = false, .bias_metrics = null },
        .curation_rationale = null,
        .maintenance = null,
        .citation_bibtex = null,
    };

    const md = try card.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "TinyStories-Ternary") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Academic Research") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "English language bias") != null);
}
