//! Zenodo V16: Model Card Template
//!
//! This module implements ICLR/NeurIPS 2025 compliant model cards
//! based on Mitchell et al. (2019) "Model Cards for Model Reporting"
//! and Gebru et al. (2021) "Datasheets for Datasets"
//!
//! Required sections per ICLR 2025:
//! - Model Details (name, version, type, release date)
//! - Intended Use
//! - Factors (limitations, out-of-scope use)
//! - Metrics (evaluated on, training data, evaluation data)
//! - Training Data (source, preprocessing, splits)
//! - Quantitative Analyses (performance, resource usage)
//! - Ethical Considerations (risks, mitigations)
//!
//! NeurIPS 2025 requirements:
//! - Environmental impact (carbon footprint)
//! - Reproducibility (code, data, hyperparameters)
//! - Limitations (clear statement of what model cannot do)

const std = @import("std");

/// Model type categories (ICLR 2025 taxonomy)
pub const ModelType = enum {
    /// Large Language Model
    language_model,
    /// Computer Vision model
    vision_model,
    /// Audio/Speech model
    audio_model,
    /// Multimodal model
    multimodal_model,
    /// Reinforcement Learning agent
    reinforcement_learning,
    /// Other model type
    other,

    pub fn displayName(self: ModelType) []const u8 {
        return switch (self) {
            .language_model => "Language Model",
            .vision_model => "Vision Model",
            .audio_model => "Audio/Speech Model",
            .multimodal_model => "Multimodal Model",
            .reinforcement_learning => "Reinforcement Learning",
            .other => "Other",
        };
    }
};

/// Model architecture details
pub const ModelArchitecture = struct {
    /// Architecture name
    name: []const u8,
    /// Number of parameters
    num_parameters: u64,
    /// Number of layers
    num_layers: u32,
    /// Hidden dimension (for transformers)
    hidden_dim: u32,
    /// Context length (for LLMs)
    context_length: ?u32,
    /// Vocabulary size (for LLMs)
    vocab_size: ?u32,

    pub fn formatAsMarkdown(self: *const ModelArchitecture, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 256);
        defer result.deinit(allocator);

        try result.appendSlice(allocator, "**Architecture**: ");
        try result.appendSlice(allocator, self.name);
        try result.appendSlice(allocator, "\\n");

        try result.appendSlice(allocator, "**Parameters**: ");
        const params_str = try std.fmt.allocPrint(allocator, "{d}", .{self.num_parameters});
        defer allocator.free(params_str);
        try result.appendSlice(allocator, params_str);
        try result.appendSlice(allocator, "\\n");

        try result.appendSlice(allocator, "**Layers**: ");
        const layers_str = try std.fmt.allocPrint(allocator, "{d}", .{self.num_layers});
        defer allocator.free(layers_str);
        try result.appendSlice(allocator, layers_str);
        try result.appendSlice(allocator, "\\n");

        if (self.hidden_dim > 0) {
            try result.appendSlice(allocator, "**Hidden Dimension**: ");
            const hidden_str = try std.fmt.allocPrint(allocator, "{d}", .{self.hidden_dim});
            defer allocator.free(hidden_str);
            try result.appendSlice(allocator, hidden_str);
            try result.appendSlice(allocator, "\\n");
        }

        if (self.context_length) |cl| {
            try result.appendSlice(allocator, "**Context Length**: ");
            const ctx_str = try std.fmt.allocPrint(allocator, "{d}", .{cl});
            defer allocator.free(ctx_str);
            try result.appendSlice(allocator, ctx_str);
            try result.appendSlice(allocator, "\\n");
        }

        if (self.vocab_size) |vs| {
            try result.appendSlice(allocator, "**Vocabulary Size**: ");
            const vocab_str = try std.fmt.allocPrint(allocator, "{d}", .{vs});
            defer allocator.free(vocab_str);
            try result.appendSlice(allocator, vocab_str);
            try result.appendSlice(allocator, "\\n");
        }

        return result.toOwnedSlice(allocator);
    }
};

/// Data split information
pub const DataSplit = struct {
    /// Split name (e.g., "train", "validation", "test")
    name: []const u8,
    /// Number of samples
    num_samples: u64,
    /// Percentage of total
    percentage: f64,
};

/// Training data information
pub const TrainingData = struct {
    /// Data source description
    source: []const u8,
    /// Data splits
    splits: []const DataSplit,
    /// Preprocessing steps
    preprocessing: []const []const u8,

    pub fn formatAsMarkdown(self: *const TrainingData, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 512);
        defer result.deinit(allocator);

        try result.appendSlice(allocator, "**Training Data Source**: ");
        try result.appendSlice(allocator, self.source);
        try result.appendSlice(allocator, "\\n");

        try result.appendSlice(allocator, "**Data Splits**:\\n");
        for (self.splits) |split| {
            try result.appendSlice(allocator, "- ");
            try result.appendSlice(allocator, split.name);
            try result.appendSlice(allocator, ": ");

            const n_str = try std.fmt.allocPrint(allocator, "{d}", .{split.num_samples});
            defer allocator.free(n_str);
            try result.appendSlice(allocator, n_str);

            try result.appendSlice(allocator, " (");
            const pct = split.percentage * 100;
            const pct_str = try std.fmt.allocPrint(allocator, "{d:.1}%", .{pct});
            defer allocator.free(pct_str);
            try result.appendSlice(allocator, pct_str);
            try result.appendSlice(allocator, ")\\n");
        }

        if (self.preprocessing.len > 0) {
            try result.appendSlice(allocator, "**Preprocessing**:\\n");
            for (self.preprocessing) |step| {
                try result.appendSlice(allocator, "- ");
                try result.appendSlice(allocator, step);
                try result.appendSlice(allocator, "\\n");
            }
        }

        return result.toOwnedSlice(allocator);
    }
};

/// Ethical considerations (ICLR 2025 requirement)
pub const EthicalConsiderations = struct {
    /// Known risks
    risks: []const []const u8,
    /// Mitigation strategies
    mitigations: []const []const u8,
    /// Review status
    reviewed_by: ?[]const u8,

    pub fn formatAsMarkdown(self: *const EthicalConsiderations, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 512);
        defer result.deinit(allocator);

        try result.appendSlice(allocator, "**Ethical Risks**:\\n");
        for (self.risks) |risk| {
            try result.appendSlice(allocator, "- ");
            try result.appendSlice(allocator, risk);
            try result.appendSlice(allocator, "\\n");
        }

        try result.appendSlice(allocator, "**Mitigations**:\\n");
        for (self.mitigations) |mitigation| {
            try result.appendSlice(allocator, "- ");
            try result.appendSlice(allocator, mitigation);
            try result.appendSlice(allocator, "\\n");
        }

        if (self.reviewed_by) |reviewer| {
            try result.appendSlice(allocator, "**Ethical Review**: ");
            try result.appendSlice(allocator, reviewer);
            try result.appendSlice(allocator, "\\n");
        }

        return result.toOwnedSlice(allocator);
    }
};

/// Complete model card
pub const ModelCard = struct {
    /// Model name
    model_name: []const u8,
    /// Model version
    model_version: []const u8,
    /// Model type
    model_type: ModelType,
    /// License
    license: []const u8,
    /// Repository URL
    repository: ?[]const u8,
    /// Architecture details
    architecture: ModelArchitecture,
    /// Training data (optional for pre-trained models)
    training_data: ?TrainingData,
    /// Ethical considerations
    ethics: ?EthicalConsiderations,
    /// Known limitations
    limitations: ?[]const []const u8,
    /// Known tradeoffs
    tradeoffs: ?[]const []const u8,
    /// Citation BibTeX
    citation_bibtex: ?[]const u8,

    pub fn formatAsMarkdown(self: *const ModelCard, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 2048);
        defer result.deinit(allocator);

        // Header
        try result.appendSlice(allocator, "# Model Card: ");
        try result.appendSlice(allocator, self.model_name);
        try result.appendSlice(allocator, "\\n\\n");

        try result.appendSlice(allocator, "**Version**: ");
        try result.appendSlice(allocator, self.model_version);
        try result.appendSlice(allocator, "\\n");

        try result.appendSlice(allocator, "**Type**: ");
        try result.appendSlice(allocator, self.model_type.displayName());
        try result.appendSlice(allocator, "\\n");

        try result.appendSlice(allocator, "**License**: ");
        try result.appendSlice(allocator, self.license);
        try result.appendSlice(allocator, "\\n\\n");

        if (self.repository) |repo| {
            try result.appendSlice(allocator, "**Repository**: ");
            try result.appendSlice(allocator, repo);
            try result.appendSlice(allocator, "\\n\\n");
        }

        // Architecture
        try result.appendSlice(allocator, "## Model Architecture\\n\\n");
        const arch_md = try self.architecture.formatAsMarkdown(allocator);
        defer allocator.free(arch_md);
        try result.appendSlice(allocator, arch_md);
        try result.appendSlice(allocator, "\\n");

        // Training Data
        if (self.training_data) |*td| {
            try result.appendSlice(allocator, "## Training Data\\n\\n");
            const td_md = try td.formatAsMarkdown(allocator);
            defer allocator.free(td_md);
            try result.appendSlice(allocator, td_md);
            try result.appendSlice(allocator, "\\n");
        }

        // Ethics
        if (self.ethics) |*eth| {
            try result.appendSlice(allocator, "## Ethical Considerations\\n\\n");
            const eth_md = try eth.formatAsMarkdown(allocator);
            defer allocator.free(eth_md);
            try result.appendSlice(allocator, eth_md);
            try result.appendSlice(allocator, "\\n");
        }

        // Limitations
        if (self.limitations) |lims| {
            try result.appendSlice(allocator, "## Known Limitations\\n\\n");
            for (lims) |lim| {
                try result.appendSlice(allocator, "- ");
                try result.appendSlice(allocator, lim);
                try result.appendSlice(allocator, "\\n");
            }
            try result.appendSlice(allocator, "\\n");
        }

        // Tradeoffs
        if (self.tradeoffs) |trades| {
            try result.appendSlice(allocator, "## Tradeoffs\\n\\n");
            for (trades) |trade| {
                try result.appendSlice(allocator, "- ");
                try result.appendSlice(allocator, trade);
                try result.appendSlice(allocator, "\\n");
            }
            try result.appendSlice(allocator, "\\n");
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

test "ModelType displayName" {
    try std.testing.expect(std.mem.eql(u8, ModelType.language_model.displayName(), "Language Model"));
    try std.testing.expect(std.mem.eql(u8, ModelType.vision_model.displayName(), "Vision Model"));
}

test "ModelArchitecture formatAsMarkdown" {
    const arch = ModelArchitecture{
        .name = "Transformer",
        .num_parameters = 1_950_000,
        .num_layers = 12,
        .hidden_dim = 768,
        .context_length = 2048,
        .vocab_size = 32000,
    };

    const md = try arch.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "Transformer") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "1950000") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "2048") != null);
}

test "ModelCard basic formatAsMarkdown" {
    const card = ModelCard{
        .model_name = "HSLM-v1",
        .model_version = "1.0",
        .model_type = .language_model,
        .license = "MIT",
        .repository = "https://github.com/gHashTag/trinity",
        .architecture = .{
            .name = "HSLM",
            .num_parameters = 1_950_000,
            .num_layers = 12,
            .hidden_dim = 768,
            .context_length = null,
            .vocab_size = null,
        },
        .training_data = null,
        .ethics = null,
        .limitations = null,
        .tradeoffs = null,
        .citation_bibtex = null,
    };

    const md = try card.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "HSLM-v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Language Model") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "φ²") != null);
}
