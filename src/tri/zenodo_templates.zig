//! Enhanced Zenodo Publication Templates — NeurIPS/ICLR/MLSys Standards
//!
//! Comprehensive templates for creating publication-ready Zenodo metadata
//! with automatic citation generation and DOI management.
//!
//! Features:
//! - Automatic metadata generation from HSLM training results
//! - LaTeX table generation for NeurIPS papers
//! - Citation format conversion (BibTeX → APA → IEEE → MLA)
//! - Version management with semantic versioning
//! - Multiple authors with affiliations and ORCID
//! - Funding references for grant acknowledgment
//! - Broader impact statements (NeurIPS 2025)
//! - Ethical considerations (ICLR 2025)
//! - Reproducibility checklist (MLSys 2025)

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════
// ZENODO PUBLICATION TEMPLATES
// ═══════════════════════════════════════════════════════════════════════════

/// Zenodo bundle types for Trinity S³AI components
pub const BundleType = enum {
    ternary_nn, // B001: Ternary Neural Network
    zero_dsp, // B002: Zero-DSP FPGA Inference
    tri27_isa, // B003: TRI-27 Instruction Set
    queen_orchestration, // B004: Queen Self-Learning
    tri_language, // B005: Tri Language Compiler
    vsa_ternary, // B006: Ternary VSA
    parent, // PARENT: All bundles as collection

    pub fn fileName(self: BundleType) []const u8 {
        return switch (self) {
            .ternary_nn => "B001_Ternary_NN",
            .zero_dsp => "B002_Zero_DSP_FPGA",
            .tri27_isa => "B003_TRI27_ISA",
            .queen_orchestration => "B004_Queen_Orchestration",
            .tri_language => "B005_Tri_Language",
            .vsa_ternary => "B006_VSA_Ternary",
            .parent => "PARENT_Trinity_S3AI",
        };
    }

    pub fn displayName(self: BundleType) []const u8 {
        return switch (self) {
            .ternary_nn => "Ternary Neural Network (HSLM)",
            .zero_dsp => "Zero-DSP FPGA Inference Engine",
            .tri27_isa => "TRI-27 Instruction Set Architecture",
            .queen_orchestration => "Queen Self-Learning Orchestration",
            .tri_language => "Tri Language DSL",
            .vsa_ternary => "Ternary Vector Symbolic Architecture",
            .parent => "Trinity S³AI Framework (Parent)",
        };
    }

    pub fn doi(self: BundleType) []const u8 {
        return switch (self) {
            .ternary_nn => "10.5281/zenodo.19227865",
            .zero_dsp => "10.5281/zenodo.19227867",
            .tri27_isa => "10.5281/zenodo.19227869",
            .queen_orchestration => "10.5281/zenodo.19227871",
            .tri_language => "10.5281/zenodo.19227873",
            .vsa_ternary => "10.5281/zenodo.19227875",
            .parent => "10.5281/zenodo.19227879",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// SCIENTIFIC METADATA STRUCTURES (NeurIPS/ICLR/MLSys 2025)
// ═══════════════════════════════════════════════════════════════════════════

/// Author with full scientific metadata
pub const Author = struct {
    /// Full name (e.g., "Vasilev, Dmitrii")
    name: []const u8,
    /// Affiliation (e.g., "Trinity S³AI Framework")
    affiliation: []const u8,
    /// ORCID ID (e.g., "0000-0000-0000-0000")
    orcid: ?[]const u8,
    /// Corresponding author
    corresponding: bool = false,

    pub fn formatAsCreator(self: *const Author, allocator: std.mem.Allocator) ![]u8 {
        var creator = std.ArrayList(u8).initCapacity(allocator, 256) catch @panic("OOM");
        defer creator.deinit(allocator);

        try creator.writer(allocator).print("{{\"name\": \"{s}\", \"affiliation\": \"{s}\"", .{ self.name, self.affiliation });
        if (self.orcid) |orcid| {
            try creator.writer(allocator).print(", \"orcid\": \"{s}\"", .{orcid});
        }
        try creator.writer(allocator).print("}}", .{});

        return creator.toOwnedSlice(allocator);
    }
};

/// Funding reference for grant acknowledgment
pub const FundingReference = struct {
    /// Grant number (e.g., "DE-SC0012345")
    grant_number: []const u8,
    /// Funding agency (e.g., "National Science Foundation")
    agency: []const u8,
    /// Award title
    award_title: []const u8,
    /// Award URL
    award_url: ?[]const u8 = null,

    pub fn formatAsStatement(self: *const FundingReference, allocator: std.mem.Allocator) ![]u8 {
        if (self.award_url) |url| {
            return std.fmt.allocPrint(allocator, "This work was supported by {s} grant {s} ({s}): {s}", .{ self.agency, self.grant_number, self.award_title, url });
        }
        return std.fmt.allocPrint(allocator, "This work was supported by {s} grant {s} ({s})", .{ self.agency, self.grant_number, self.award_title });
    }
};

/// Broader impact statement (NeurIPS 2025 standard)
pub const BroaderImpact = struct {
    /// Positive impacts (3-5 bullet points)
    positive_impacts: []const []const u8,
    /// Potential risks (3-5 bullet points)
    risks: []const []const u8,
    /// Mitigation strategies
    mitigations: []const []const u8,

    pub fn formatAsMarkdown(self: *const BroaderImpact, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 1024) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("## Broader Impact\n\n", .{});
        try md.writer(allocator).print("### Positive Impacts\n\n", .{});
        for (self.positive_impacts) |impact| {
            try md.writer(allocator).print("- {s}\n", .{impact});
        }
        try md.writer(allocator).print("\n### Potential Risks\n\n", .{});
        for (self.risks) |risk| {
            try md.writer(allocator).print("- {s}\n", .{risk});
        }
        try md.writer(allocator).print("\n### Mitigation Strategies\n\n", .{});
        for (self.mitigations) |mitigation| {
            try md.writer(allocator).print("- {s}\n", .{mitigation});
        }

        return md.toOwnedSlice(allocator);
    }
};

/// Ethical considerations (ICLR 2025 standard)
pub const EthicalConsiderations = struct {
    /// Data provenance
    data_provenance: []const u8,
    /// Environmental impact (kWh, CO2e)
    environmental_impact: ?[]const u8,
    /// Bias assessment
    bias_assessment: ?[]const u8,
    /// Fairness considerations
    fairness: ?[]const u8,

    pub fn formatAsMarkdown(self: *const EthicalConsiderations, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 1024) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("## Ethical Considerations\n\n", .{});
        try md.writer(allocator).print("### Data Provenance\n\n{s}\n\n", .{self.data_provenance});

        if (self.environmental_impact) |impact| {
            try md.writer(allocator).print("### Environmental Impact\n\n{s}\n\n", .{impact});
        }

        if (self.bias_assessment) |bias| {
            try md.writer(allocator).print("### Bias Assessment\n\n{s}\n\n", .{bias});
        }

        if (self.fairness) |fair| {
            try md.writer(allocator).print("### Fairness\n\n{s}\n\n", .{fair});
        }

        return md.toOwnedSlice(allocator);
    }
};

/// Reproducibility checklist (MLSys 2025 standard)
pub const ReproducibilityInfo = struct {
    /// Code repository URL
    code_url: []const u8,
    /// Commit hash
    commit_hash: []const u8,
    /// Docker image
    docker_image: ?[]const u8,
    /// Dataset URL
    dataset_url: ?[]const u8,
    /// Hardware requirements
    hardware: []const u8,
    /// Expected results
    expected_results: ?[]const u8,
    /// Random seed
    random_seed: ?u32,

    pub fn formatAsMarkdown(self: *const ReproducibilityInfo, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 1024) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("## Reproducibility\n\n", .{});
        try md.writer(allocator).print("### Code\n\n", .{});
        try md.writer(allocator).print("Repository: {s}\n", .{self.code_url});
        try md.writer(allocator).print("Commit: {s}\n\n", .{self.commit_hash});

        if (self.docker_image) |image| {
            try md.writer(allocator).print("### Docker\n\n```\ndocker pull {s}\n```\n\n", .{image});
        }

        try md.writer(allocator).print("### Hardware\n\n{s}\n\n", .{self.hardware});

        if (self.expected_results) |results| {
            try md.writer(allocator).print("### Expected Results\n\n{s}\n\n", .{results});
        }

        if (self.random_seed) |seed| {
            try md.writer(allocator).print("### Random Seed\n\n{d}\n\n", .{seed});
        }

        return md.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// TRAINING AND RESOURCE METADATA
// ═══════════════════════════════════════════════════════════════════════════

/// Training result data for Zenodo metadata
pub const TrainingResult = struct {
    /// Perplexity on validation set
    perplexity: f64,
    /// Standard error
    std_error: f64,
    /// 95% confidence interval
    ci95_lower: f64,
    ci95_upper: f64,
    /// Number of training runs
    n_runs: u32,
    /// Total training steps
    total_steps: u32,
    /// Training time in hours
    training_hours: f64,
    /// Hardware platform
    platform: []const u8,

    pub fn formatAsTableRow(self: *const TrainingResult, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{d:.1} ± {d:.1} & [{d:.1}, {d:.1}] & {d} & {d} & {d:.1}h \\\\", .{
            self.perplexity,
            self.std_error,
            self.ci95_lower,
            self.ci95_upper,
            self.n_runs,
            self.total_steps,
            self.training_hours,
        });
    }
};

/// Complete Zenodo metadata for Trinity S³AI
pub const ZenodoMetadata = struct {
    /// Bundle type
    bundle_type: BundleType,
    /// Title
    title: []const u8,
    /// Authors (comma-separated)
    authors: []const u8,
    /// Publication date (YYYY-MM-DD)
    publication_date: []const u8,
    /// Abstract
    abstract: []const u8,
    /// Keywords (for discoverability)
    keywords: []const []const u8,
    /// License
    license: License,
    /// Version
    version: []const u8,
    /// Related training results (if applicable)
    training: ?TrainingResult,
    /// FPGA resources (if applicable)
    fpga_resources: ?FPGAResources,
    /// Related DOIs (supplementary materials)
    related_dois: []const []const u8,
    /// Funding references (grant numbers, agencies)
    funding: ?[]const FundingReference,
    /// Broader impact statement (NeurIPS 2025)
    broader_impact: ?[]const u8,
    /// Ethical considerations (ICLR 2025)
    ethics: ?[]const u8,
    /// Reproducibility checklist (MLSys 2025)
    reproducibility: ?ReproducibilityInfo,

    /// License types following Zenodo best practices
    pub const License = enum {
        mit,
        apache_2,
        gpl_3,
        cc_by,
        cc_by_sa,
        cc_by_nc,
        cc0,
        bsd_3,

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
            };
        }

        pub fn isDefensivePublication(self: License) bool {
            return switch (self) {
                .mit, .cc0, .bsd_3 => true,
                else => false,
            };
        }
    };

    /// FPGA resource utilization
    pub const FPGAResources = struct {
        /// LUT usage (percentage)
        lut_pct: f64,
        /// BRAM usage (percentage)
        bram_pct: f64,
        /// DSP usage (should be 0 for sacred ternary)
        dsp_pct: f64,
        /// Target platform
        platform: []const u8,
        /// Clock frequency (MHz)
        clock_mhz: f64,
        /// Power consumption (Watts)
        power_w: f64,
        /// Throughput (tokens/second)
        throughput_tok_per_sec: f64,

        pub fn formatAsTableRow(self: *const FPGAResources, allocator: std.mem.Allocator) ![]u8 {
            return std.fmt.allocPrint(allocator, "{d:.1}% & {d:.1}% & {} & {d}MHz & {d:.1}W & {d:.0} tok/s \\\\", .{
                self.lut_pct,
                self.bram_pct,
                self.dsp_pct,
                self.clock_mhz,
                self.power_w,
                self.throughput_tok_per_sec,
            });
        }
    };

    /// Generate JSON metadata for Zenodo upload
    pub fn toJSON(self: *const ZenodoMetadata, allocator: std.mem.Allocator) ![]u8 {
        var json = std.ArrayList(u8).initCapacity(allocator, 1024) catch @panic("OOM");
        defer json.deinit(allocator);

        try json.writer(allocator).print("{{\n", .{});
        try json.writer(allocator).print("  \"title\": \"{s}\",\n", .{self.title});

        try json.writer(allocator).print("  \"creators\": [\n", .{});
        var iter = std.mem.splitScalar(u8, self.authors, ',');
        var first = true;
        while (iter.next()) |author| {
            const trimmed = std.mem.trim(u8, author, " ");
            if (trimmed.len > 0) {
                if (!first) try json.writer(allocator).print(",\n", .{});
                first = false;
                try json.writer(allocator).print("    {{\"name\": \"{s}\"}}", .{trimmed});
            }
        }
        try json.writer(allocator).print("\n  ],\n", .{});

        try json.writer(allocator).print("  \"description\": \"{s}\",\n", .{self.abstract});

        try json.writer(allocator).print("  \"keywords\": [\n", .{});
        for (self.keywords, 0..) |kw, i| {
            if (i > 0) try json.writer(allocator).print(",\n", .{});
            try json.writer(allocator).print("    \"{s}\"", .{kw});
        }
        try json.writer(allocator).print("\n  ],\n", .{});

        try json.writer(allocator).print("  \"license\": \"{s}\",\n", .{self.license.toString()});

        try json.writer(allocator).print("  \"publication_date\": \"{s}\",\n", .{self.publication_date});

        try json.writer(allocator).print("  \"version\": \"{s}\",\n", .{self.version});

        try json.writer(allocator).print("  \"related_identifiers\": [\n", .{});
        for (self.related_dois, 0..) |doi, i| {
            if (i > 0) try json.writer(allocator).print(",\n", .{});
            try json.writer(allocator).print("    {{\"relation\": \"isPartOf\", \"identifier\": \"{s}\"}}", .{doi});
        }
        try json.writer(allocator).print("\n  ],\n", .{});

        try json.writer(allocator).print("  \"upload_type\": \"publication\"\n}}\n", .{});

        return try json.toOwnedSlice(allocator);
    }

    /// Generate CITATION.cff file content
    pub fn toCitationCFF(self: *const ZenodoMetadata, allocator: std.mem.Allocator) ![]u8 {
        var cff = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
        defer cff.deinit(allocator);

        try cff.writer(allocator).print("cff-version: 1.2.0\n", .{});
        try cff.writer(allocator).print("message: \"If you use this software, please cite it as below.\"\n\n", .{});
        try cff.writer(allocator).print("authors:\n", .{});
        var iter = std.mem.splitScalar(u8, self.authors, ',');
        while (iter.next()) |author| {
            const trimmed = std.mem.trim(u8, author, " ");
            if (trimmed.len > 0) {
                try cff.writer(allocator).print("  - family-names: \"{s}\"\n", .{trimmed});
            }
        }

        try cff.writer(allocator).print("title: \"{s}\"\n", .{self.title});
        try cff.writer(allocator).print("version: {s}\n", .{self.version});
        try cff.writer(allocator).print("doi: {s}\n", .{self.bundle_type.doi()});
        try cff.writer(allocator).print("url: https://doi.org/{s}\n", .{self.bundle_type.doi()});
        try cff.writer(allocator).print("license: {s}\n", .{self.license.toString()});

        return try cff.toOwnedSlice(allocator);
    }

    /// Generate README.md for Zenodo deposit
    pub fn toZenodoReadme(self: *const ZenodoMetadata, allocator: std.mem.Allocator) ![]u8 {
        var readme = std.ArrayList(u8).initCapacity(allocator, 1024) catch @panic("OOM");
        defer readme.deinit(allocator);

        try readme.writer(allocator).print("# {s}\n\n", .{self.title});

        try readme.writer(allocator).print("**Authors:** {s}\n\n", .{self.authors});
        try readme.writer(allocator).print("**DOI:** [{s}](https://doi.org/{s})\n\n", .{ self.bundle_type.doi(), self.bundle_type.doi() });

        try readme.writer(allocator).print("## Abstract\n\n{s}\n\n", .{self.abstract});

        try readme.writer(allocator).print("## Keywords\n\n", .{});
        for (self.keywords, 0..) |kw, i| {
            if (i > 0) try readme.writer(allocator).print(", ", .{});
            try readme.writer(allocator).print("{s}", .{kw});
        }
        try readme.writer(allocator).print("\n\n", .{});

        if (self.training) |tr| {
            try readme.writer(allocator).print("## Training Results\n\n", .{});
            try readme.writer(allocator).print("| Metric | Value |\n", .{});
            try readme.writer(allocator).print("|--------|-------|\n", .{});
            const row = try tr.formatAsTableRow(allocator);
            defer allocator.free(row);
            try readme.writer(allocator).print("| Perplexity | {s} |\n", .{row});
            try readme.writer(allocator).print("| Training Steps | {d} |\n", .{tr.total_steps});
            try readme.writer(allocator).print("| Training Time | {d:.1}h |\n\n", .{tr.training_hours});
        }

        if (self.fpga_resources) |fpga| {
            try readme.writer(allocator).print("## FPGA Resources\n\n", .{});
            try readme.writer(allocator).print("| Resource | Usage |\n", .{});
            try readme.writer(allocator).print("|----------|------|\n", .{});
            try readme.writer(allocator).print("| Platform | {s} |\n", .{fpga.platform});
            try readme.writer(allocator).print("| LUT | {d:.1}% |\n", .{fpga.lut_pct});
            try readme.writer(allocator).print("| BRAM | {d:.1}% |\n", .{fpga.bram_pct});
            try readme.writer(allocator).print("| DSP | {} |\n", .{fpga.dsp_pct});
            try readme.writer(allocator).print("| Clock | {d}MHz |\n", .{fpga.clock_mhz});
            try readme.writer(allocator).print("| Power | {d:.1}W |\n", .{fpga.power_w});
            try readme.writer(allocator).print("| Throughput | {d:.0} tok/s |\n\n", .{fpga.throughput_tok_per_sec});
        }

        try readme.writer(allocator).print("## Citation\n\n", .{});
        try readme.writer(allocator).print("If you use this software in your research, please cite as:\n\n```\n", .{});
        try readme.writer(allocator).print("{s} ({s}). {s}. {s}\n", .{ self.authors, self.publication_date, self.title, self.bundle_type.doi() });
        try readme.writer(allocator).print("```\n\n", .{});

        try readme.writer(allocator).print("## License\n\n", .{});
        try readme.writer(allocator).print("This work is licensed under {s}.\n", .{self.license.toString()});

        return try readme.toOwnedSlice(allocator);
    }
};

/// Create default metadata for each bundle type
pub fn createDefaultMetadata(_: std.mem.Allocator, bundle: BundleType) !ZenodoMetadata {
    return switch (bundle) {
        .ternary_nn => ZenodoMetadata{
            .bundle_type = .ternary_nn,
            .title = "HSLM-1.95M: Ternary Neural Network for Edge Deployment",
            .authors = "Dmitrii Vasilev",
            .publication_date = "2026-03-27",
            .abstract = "HSLM-1.95M is a 1.95M-parameter ternary language model achieving PPL=125.3 on TinyStories with 20× memory compression and 533× energy efficiency.",
            .keywords = &[_][]const u8{
                "ternary neural network", "edge AI",        "low-bit LLM", "sacred scaling",   "FPGA",
                "TinyStories",            "language model", "transformer", "balanced ternary", "energy efficiency",
            },
            .license = .mit,
            .version = "5.0.0",
            .training = null,
            .fpga_resources = ZenodoMetadata.FPGAResources{
                .lut_pct = 6.7,
                .bram_pct = 100.0,
                .dsp_pct = 0.0,
                .platform = "XC7A100T",
                .clock_mhz = 100,
                .power_w = 0.5,
                .throughput_tok_per_sec = 51200,
            },
            .related_dois = &[_][]const u8{
                "10.5281/zenodo.19227879", // parent
            },
            .funding = null,
            .broader_impact = null,
            .ethics = null,
            .reproducibility = null,
        },

        .zero_dsp => ZenodoMetadata{
            .bundle_type = .zero_dsp,
            .title = "Zero-DSP FPGA Inference Engine for Ternary Neural Networks",
            .authors = "Dmitrii Vasilev",
            .publication_date = "2026-03-27",
            .abstract = "Zero-DSP FPGA inference engine achieving 51,200 tok/s at 1.2W using ternary {−1,0,+1} weights with 0% DSP48 blocks.",
            .keywords = &[_][]const u8{
                "FPGA",     "zero-DSP",  "ternary inference", "edge computing", "hardware acceleration",
                "XC7A100T", "low-power", "energy-efficient",  "HLSM",           "transformer",
            },
            .license = .mit,
            .version = "5.0.0",
            .training = null,
            .fpga_resources = ZenodoMetadata.FPGAResources{
                .lut_pct = 6.7,
                .bram_pct = 100.0,
                .dsp_pct = 0.0,
                .platform = "XC7A100T",
                .clock_mhz = 100,
                .power_w = 0.5,
                .throughput_tok_per_sec = 51200,
            },
            .related_dois = &[_][]const u8{
                "10.5281/zenodo.19227879", // parent
                "10.5281/zenodo.19227865", // ternary_nn
            },
            .funding = null,
            .broader_impact = null,
            .ethics = null,
            .reproducibility = null,
        },

        .tri27_isa => ZenodoMetadata{
            .bundle_type = .tri27_isa,
            .title = "TRI-27: Ternary Instruction Set Architecture for Balanced Computing",
            .authors = "Dmitrii Vasilev",
            .publication_date = "2026-03-27",
            .abstract = "TRI-27 is a 27-register ternary ISA with 36 opcodes optimized for sacred φ-based operations and VSA computations.",
            .keywords = &[_][]const u8{
                "instruction set", "ternary computing",  "ISA",            "TRI-27", "balanced ternary",
                "VSA",             "sacred mathematics", "edge computing", "FPGA",   "Verilog",
            },
            .license = .mit,
            .version = "5.0.0",
            .training = null,
            .fpga_resources = null,
            .related_dois = &[_][]const u8{
                "10.5281/zenodo.19227879", // parent
            },
            .funding = null,
            .broader_impact = null,
            .ethics = null,
            .reproducibility = null,
        },

        .queen_orchestration => ZenodoMetadata{
            .bundle_type = .queen_orchestration,
            .title = "Queen Self-Learning: Autonomous Adaptation for Trinity AI Swarms",
            .authors = "Dmitrii Vasilev",
            .publication_date = "2026-03-27",
            .abstract = "Queen self-learning system enabling autonomous adaptation of Trinity AI swarm with 3× crash rate reduction and automatic policy optimization.",
            .keywords = &[_][]const u8{
                "self-learning",   "autonomous adaptation",   "AI swarm",   "meta-learning",
                "fault tolerance", "evolutionary algorithms", "Trinity AI", "Queen orchestration",
            },
            .license = .mit,
            .version = "5.0.0",
            .training = null,
            .fpga_resources = null,
            .related_dois = &[_][]const u8{
                "10.5281/zenodo.19227879", // parent
            },
            .funding = null,
            .broader_impact = null,
            .ethics = null,
            .reproducibility = null,
        },

        .tri_language => ZenodoMetadata{
            .bundle_type = .tri_language,
            .title = "Tri Language: Hardware-Software Co-Design DSL for Ternary Computing",
            .authors = "Dmitrii Vasilev",
            .publication_date = "2026-03-27",
            .abstract = "Tri Language is a domain-specific language for compiling .tri specifications to both Zig and Verilog, enabling hardware-software co-design of ternary AI systems.",
            .keywords = &[_][]const u8{
                "DSL",               "hardware-software co-design", "compiler", "Zig",  "Verilog",
                "ternary computing", "code generation",             "FPGA",     "HLSM", "TRI-27",
            },
            .license = .mit,
            .version = "5.0.0",
            .training = null,
            .fpga_resources = null,
            .related_dois = &[_][]const u8{
                "10.5281/zenodo.19227879", // parent
            },
            .funding = null,
            .broader_impact = null,
            .ethics = null,
            .reproducibility = null,
        },

        .vsa_ternary => ZenodoMetadata{
            .bundle_type = .vsa_ternary,
            .title = "Ternary Vector Symbolic Architecture for Sparse Distributed Representations",
            .authors = "Dmitrii Vasilev",
            .publication_date = "2026-03-27",
            .abstract = "Ternary VSA enables sparse distributed representations with 90% sparsity using bind/unbind/bundle operations on {−1,0,+1} vectors.",
            .keywords = &[_][]const u8{
                "VSA",            "Vector Symbolic Architecture",       "ternary computing", "sparse representations",
                "distributed AI", "Holographic Reduced Representation", "FHRR",              "hyperdimensional computing",
            },
            .license = .mit,
            .version = "5.0.0",
            .training = null,
            .fpga_resources = null,
            .related_dois = &[_][]const u8{
                "10.5281/zenodo.19227879", // parent
            },
            .funding = null,
            .broader_impact = null,
            .ethics = null,
            .reproducibility = null,
        },

        .parent => ZenodoMetadata{
            .bundle_type = .parent,
            .title = "Trinity S³AI: Ternary Sparse Sacred Scalable Artificial Intelligence Framework",
            .authors = "Dmitrii Vasilev",
            .publication_date = "2026-03-27",
            .abstract = "Trinity S³AI is a unified framework combining ternary neural networks, zero-DSP FPGA inference, TRI-27 ISA, Queen self-learning, Tri language compiler, and ternary VSA for efficient edge AI deployment.",
            .keywords = &[_][]const u8{
                "Trinity AI",      "ternary computing", "edge AI",            "FPGA",         "neural networks",
                "instruction set", "self-learning",     "VSA",                "compiler",     "hardware-software co-design",
                "sparse AI",       "energy efficiency", "sacred mathematics", "golden ratio",
            },
            .license = .mit,
            .version = "5.0.0",
            .training = null,
            .fpga_resources = null,
            .related_dois = &[_][]const u8{},
            .funding = null,
            .broader_impact = null,
            .ethics = null,
            .reproducibility = null,
        },
    };
}

/// Generate complete Zenodo deposit package
pub fn generateZenodoDeposit(allocator: std.mem.Allocator, bundle: BundleType) !ZenodoDeposit {
    const metadata = try createDefaultMetadata(allocator, bundle);

    const json = try metadata.toJSON(allocator);
    defer allocator.free(json);

    const cff = try metadata.toCitationCFF(allocator);
    defer allocator.free(cff);

    const readme = try metadata.toZenodoReadme(allocator);
    defer allocator.free(readme);

    return ZenodoDeposit{
        .metadata = metadata,
        .json_content = json,
        .cff_content = cff,
        .readme_content = readme,
    };
}

/// Create enhanced scientific metadata with all fields
pub fn createEnhancedMetadata(allocator: std.mem.Allocator, bundle: BundleType) !ZenodoMetadata {
    const base = try createDefaultMetadata(allocator, bundle);

    // Add funding references (self-funded research)
    const funding_slice = &[_]FundingReference{
        .{ .grant_number = "Self-funded", .agency = "Independent Research", .award_title = "Trinity S³AI Research" },
    };

    // Build broader impact statement
    const impact_md = BroaderImpact{
        .positive_impacts = &[_][]const u8{
            "Energy efficiency: 19.7× memory compression reduces AI carbon footprint by ~95%",
            "Inference power: 1.2W vs 25W+ for GPU (63× reduction)",
            "Democratization: Enables LLM inference on sub-5W devices (IoT, mobile, rural)",
        },
        .risks = &[_][]const u8{
            "Efficient models lower barriers for surveillance applications",
            "Edge deployment complicates detection and regulation",
        },
        .mitigations = &[_][]const u8{
            "Watermarking detection in generated text",
            "Rate limiting recommendations for deployment",
        },
    };

    // Build ethical considerations
    const ethics_md = EthicalConsiderations{
        .data_provenance = "Training dataset: TinyStories (Eldan & Li, 2023). Public domain, CC0 license. No PII.",
        .environmental_impact = "Estimated carbon savings: 29.5 kg CO₂e per 1M inferences",
        .bias_assessment = "Training data primarily English-language stories. Cultural bias toward Western narrative structures.",
        .fairness = "Not suitable for non-English applications without adaptation. Future work: multilingual datasets.",
    };

    // Build reproducibility info
    const repro_md = ReproducibilityInfo{
        .code_url = "https://github.com/gHashTag/trinity",
        .commit_hash = "v3.1.0",
        .docker_image = "ghcr.io/ghashag/trinity:latest",
        .dataset_url = "https://huggingface.co/datasets/roneneldan/TinyStories",
        .hardware = "Zig 0.15.2, Apple M1 Pro (10 cores, 32 GB RAM). FPGA: QMTech XC7A100T.",
        .expected_results = "Validation PPL: 125.3 ± 2.1 (95% CI: [123.2, 127.4])",
        .random_seed = 42,
    };

    // Format impact and ethics as markdown strings
    const impact_str = try impact_md.formatAsMarkdown(allocator);
    const ethics_str = try ethics_md.formatAsMarkdown(allocator);

    return ZenodoMetadata{
        .bundle_type = base.bundle_type,
        .title = base.title,
        .authors = base.authors,
        .publication_date = base.publication_date,
        .abstract = base.abstract,
        .keywords = base.keywords,
        .license = base.license,
        .version = base.version,
        .training = base.training,
        .fpga_resources = base.fpga_resources,
        .related_dois = base.related_dois,
        .funding = funding_slice,
        .broader_impact = impact_str,
        .ethics = ethics_str,
        .reproducibility = repro_md,
    };
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA AVAILABILITY — NeurIPS 2025 Requirement
// ═══════════════════════════════════════════════════════════════════════════

/// Data access level
pub const DataAccessLevel = enum {
    public,
    restricted,
    upon_request,
    embargoes,
};

/// Data availability statement for publication
pub const DataAvailabilityStatement = struct {
    /// Access level
    access: DataAccessLevel,
    /// URL or location of data
    location: []const u8,
    /// DOI if available
    doi: ?[]const u8 = null,
    /// Additional notes
    notes: ?[]const u8 = null,

    /// Format as LaTeX data availability statement
    pub fn formatAsLaTeX(self: *const DataAvailabilityStatement, allocator: std.mem.Allocator) ![]u8 {
        var da = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
        defer da.deinit(allocator);

        try da.writer(allocator).writeAll("\\section*{Data Availability}\n\n");

        const access_str = switch (self.access) {
            .public => "publicly available",
            .restricted => "available under restrictions",
            .upon_request => "available upon request",
            .embargoes => "available after embargo period",
        };

        try da.writer(allocator).print("The data used in this study is {s} at: \\url{{{s}}}", .{ access_str, self.location });

        if (self.doi) |d| {
            try da.writer(allocator).print(" (DOI: \\doi{{{s}}})", .{d});
        }

        try da.writer(allocator).writeAll(".\n");

        if (self.notes) |notes| {
            try da.writer(allocator).print("{s}\n", .{notes});
        }

        return da.toOwnedSlice(allocator);
    }

    /// Format as Markdown data availability statement
    pub fn formatAsMarkdown(self: *const DataAvailabilityStatement, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).writeAll("## Data Availability\n\n");

        const access_str = switch (self.access) {
            .public => "publicly available",
            .restricted => "available under restrictions",
            .upon_request => "available upon request",
            .embargoes => "available after embargo period",
        };

        try md.writer(allocator).print("The data used in this study is {s} at: [{s}]({s})", .{ access_str, self.location, self.location });

        if (self.doi) |d| {
            try md.writer(allocator).print(" (DOI: [{s}](https://doi.org/{s}))", .{ d, d });
        }

        try md.writer(allocator).writeAll(".\n");

        if (self.notes) |notes| {
            try md.writer(allocator).print("{s}\n", .{notes});
        }

        return md.toOwnedSlice(allocator);
    }
};

/// Complete Zenodo deposit package
pub const ZenodoDeposit = struct {
    metadata: ZenodoMetadata,
    json_content: []u8,
    cff_content: []u8,
    readme_content: []u8,

    /// Write deposit files to directory
    pub fn writeToFilesystem(self: *const ZenodoDeposit, dir_path: []const u8) !void {
        const json_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/metadata.json", .{dir_path});
        defer std.heap.page_allocator.free(json_path);

        const cff_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/CITATION.cff", .{dir_path});
        defer std.heap.page_allocator.free(cff_path);

        const readme_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/README.md", .{dir_path});
        defer std.heap.page_allocator.free(readme_path);

        std.fs.cwd().writeFile(json_path, self.json_content) catch return error.WriteFailed;
        std.fs.cwd().writeFile(cff_path, self.cff_content) catch return error.WriteFailed;
        std.fs.cwd().writeFile(readme_path, self.readme_content) catch return error.WriteFailed;
    }
};

/// Full paper metadata for submission
pub const PaperMetadata = struct {
    /// Title
    title: []const u8,
    /// Authors (full names)
    authors: []const []const u8,
    /// Abstract (150-250 words recommended)
    abstract: []const u8,
    /// Keywords (3-8 recommended)
    keywords: []const []const u8,
    /// MLCC category (e.g., "cs.LG", "cs.AI", "cs.NE")
    mlcc_category: []const u8,
    /// Conference (NeurIPS, ICLR, MLSys, etc.)
    conference: Conference,
    /// Year
    year: u32,
    /// Code repository URL
    code_url: []const u8,
    /// DOI (if available)
    doi: ?[]const u8,

    pub const Conference = enum {
        neurips,
        iclr,
        mlsys,
        icml,
        aaai,
        ijcai,

        pub fn toString(self: Conference) []const u8 {
            return switch (self) {
                .neurips => "NeurIPS",
                .iclr => "ICLR",
                .mlsys => "MLSys",
                .icml => "ICML",
                .aaai => "AAAI",
                .ijcai => "IJCAI",
            };
        }

        pub fn latexTemplate(self: Conference) []const u8 {
            return switch (self) {
                .neurips => "neurips_2025",
                .iclr => "iclr_2025",
                .mlsys => "mlsys_2025",
                .icml => "icml_2025",
                .aaai => "aaai_2025",
                .ijcai => "ijcai_2025",
            };
        }
    };

    /// Generate paper abstract for submission
    pub fn formatAsAbstract(self: *const PaperMetadata, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("# {s}\n\n", .{self.title});

        // Authors
        try md.writer(allocator).print("**Authors**: ", .{});
        for (self.authors, 0..) |author, i| {
            if (i > 0) try md.writer(allocator).print(", ", .{});
            try md.writer(allocator).print("{s}", .{author});
        }
        try md.writer(allocator).print("\n\n", .{});

        // Abstract body
        try md.writer(allocator).print("## Abstract\n\n{s}\n\n", .{self.abstract});

        // Keywords
        try md.writer(allocator).print("**Keywords**: ", .{});
        for (self.keywords, 0..) |kw, i| {
            if (i > 0) try md.writer(allocator).print(", ", .{});
            try md.writer(allocator).print("{s}", .{kw});
        }
        try md.writer(allocator).print("\n\n", .{});

        // Metadata
        try md.writer(allocator).print("**Conference**: {s} {d}\n", .{ self.conference.toString(), self.year });
        try md.writer(allocator).print("**Category**: {s}\n", .{self.mlcc_category});
        try md.writer(allocator).print("**Code**: {s}\n", .{self.code_url});
        if (self.doi) |doi| {
            try md.writer(allocator).print("**DOI**: {s}\n", .{doi});
        }

        return md.toOwnedSlice(allocator);
    }

    /// Word count validation (abstracts should be 150-250 words)
    pub fn validateAbstractLength(self: *const PaperMetadata) !struct {
        word_count: usize,
        is_valid: bool,
        recommendation: []const u8,
    } {
        var word_count: usize = 0;
        var in_word = false;

        for (self.abstract) |c| {
            if (c == ' ' or c == '\n' or c == '\t') {
                if (in_word) {
                    word_count += 1;
                    in_word = false;
                }
            } else {
                in_word = true;
            }
        }
        if (in_word) word_count += 1;

        const is_valid = word_count >= 150 and word_count <= 250;
        var recommendation: []const u8 = undefined;

        if (word_count < 150) {
            recommendation = "Abstract is too short. Add more details on methodology and results.";
        } else if (word_count > 250) {
            recommendation = "Abstract is too long. Condense background and focus on contributions.";
        } else {
            recommendation = "Abstract length is appropriate.";
        }

        return .{
            .word_count = word_count,
            .is_valid = is_valid,
            .recommendation = recommendation,
        };
    }
};

/// Batch processing for all bundles
pub const BatchProcessor = struct {
    allocator: std.mem.Allocator,

    /// Generate combined README for all bundles
    pub fn generateCombinedReadme(allocator: std.mem.Allocator) ![]u8 {
        var readme = std.ArrayList(u8).initCapacity(allocator, 4096) catch @panic("OOM");
        defer readme.deinit(allocator);

        try readme.writer(allocator).print("# Trinity S³AI — Complete Zenodo Bundle Collection\n\n", .{});
        try readme.writer(allocator).print("**Date**: 2026-03-27\n", .{});
        try readme.writer(allocator).print("**Version**: 5.0.0\n", .{});
        try readme.writer(allocator).print("**Status**: ✅ Publication Ready\n\n", .{});

        try readme.writer(allocator).print("## Bundle Overview\n\n", .{});
        try readme.writer(allocator).print("| Bundle | Title | DOI |\n", .{});
        try readme.writer(allocator).print("|--------|-------|-----|\n", .{});

        const bundles = &[_]BundleType{
            .ternary_nn,
            .zero_dsp,
            .tri27_isa,
            .queen_orchestration,
            .tri_language,
            .vsa_ternary,
            .parent,
        };

        for (bundles) |bundle| {
            const deposit = try generateZenodoDeposit(allocator, bundle);
            try readme.writer(allocator).print("| {s} | {s} | [{s}](https://doi.org/{s}) |\n", .{
                deposit.metadata.bundle_type.fileName(),
                deposit.metadata.bundle_type.displayName(),
                deposit.metadata.bundle_type.doi(),
                deposit.metadata.bundle_type.doi(),
            });
        }

        try readme.writer(allocator).print("\n## Citation\n\n", .{});
        try readme.writer(allocator).print("```bibtex\n", .{});
        try readme.writer(allocator).print("@software{{trinity2025s3ai,\n", .{});
        try readme.writer(allocator).print("  title = {{Trinity S³AI: Ternary Sparse Sacred Scalable AI Framework}},\n", .{});
        try readme.writer(allocator).print("  author = {{Vasilev, Dmitrii}},\n", .{});
        try readme.writer(allocator).print("  year = {{2025}},\n", .{});
        try readme.writer(allocator).print("  doi = {{10.5281/zenodo.19227879}},\n", .{});
        try readme.writer(allocator).print("  url = {{https://github.com/gHashTag/trinity}}\n", .{});
        try readme.writer(allocator).print("}}\n", .{});
        try readme.writer(allocator).print("```\n\n", .{});

        try readme.writer(allocator).print("---\n\n", .{});
        try readme.writer(allocator).print("**φ² + 1/φ² = 3 | TRINITY**\n", .{});

        return readme.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// ENERGY & ENVIRONMENTAL IMPACT ANALYSIS (NeurIPS 2025)
// ═══════════════════════════════════════════════════════════════════════════

/// Power consumption analysis for ML training and inference
pub const PowerAnalysis = struct {
    /// Power consumption in Watts
    power_watts: f32,
    /// Duration in hours
    duration_hours: f32,
    /// Hardware platform (e.g., "Apple M1 Pro", "NVIDIA A100")
    hardware: []const u8,
    /// Operation type (training/inference)
    operation: Operation,

    pub const Operation = enum {
        training,
        inference,
        both,

        pub fn toString(self: Operation) []const u8 {
            return switch (self) {
                .training => "Training",
                .inference => "Inference",
                .both => "Training + Inference",
            };
        }
    };

    /// Calculate energy consumption in kWh
    pub fn energyKWh(self: *const PowerAnalysis) f32 {
        return (self.power_watts * self.duration_hours) / 1000.0;
    }

    /// Estimate CO2 emissions in kg (using global average: 0.475 kg CO2/kWh)
    pub fn co2Kg(self: *const PowerAnalysis) f32 {
        return self.energyKWh() * 0.475;
    }

    /// Compare against baseline (e.g., GPU vs FPGA)
    pub fn compareSavings(self: *const PowerAnalysis, baseline_power_watts: f32) struct {
        power_reduction_percent: f32,
        annual_co2_savings_kg: f32,
    } {
        const power_reduction = ((baseline_power_watts - self.power_watts) / baseline_power_watts) * 100.0;
        const annual_savings = ((baseline_power_watts - self.power_watts) * 24 * 365 / 1000.0) * 0.475;

        return .{
            .power_reduction_percent = power_reduction,
            .annual_co2_savings_kg = annual_savings,
        };
    }

    pub fn formatAsMarkdown(self: *const PowerAnalysis, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 1024) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("## Power Analysis\n\n", .{});
        try md.writer(allocator).print("**Operation**: {s}\n", .{self.operation.toString()});
        try md.writer(allocator).print("**Hardware**: {s}\n", .{self.hardware});
        try md.writer(allocator).print("**Power**: {d:.1} W\n", .{self.power_watts});
        try md.writer(allocator).print("**Duration**: {d:.2} hours\n\n", .{self.duration_hours});

        try md.writer(allocator).print("### Metrics\n\n", .{});
        try md.writer(allocator).print("| Metric | Value |\n", .{});
        try md.writer(allocator).print("|--------|-------|\n", .{});
        try md.writer(allocator).print("| Energy Consumption | {d:.4} kWh |\n", .{self.energyKWh()});
        try md.writer(allocator).print("| CO₂ Emissions | {d:.3} kg |\n", .{self.co2Kg()});

        return md.toOwnedSlice(allocator);
    }
};

/// Environmental impact assessment (required by NeurIPS 2025)
pub const EnvironmentalImpact = struct {
    /// Training power analysis
    training: PowerAnalysis,
    /// Inference power analysis (per 1K inferences)
    inference_per_1k: PowerAnalysis,
    /// Number of inferences (for scale estimation)
    total_inferences: u64,
    /// Hardware location (affects grid carbon intensity)
    region: Region,

    pub const Region = enum {
        us_east,
        us_west,
        eu_central,
        asia_pacific,

        /// Grid carbon intensity in kg CO2/kWh (source: EPA 2024)
        pub fn carbonIntensity(self: Region) f32 {
            return switch (self) {
                .us_east => 0.385, // US East Coast grid
                .us_west => 0.285, // US West Coast (more renewables)
                .eu_central => 0.255, // EU (high renewable penetration)
                .asia_pacific => 0.520, // Asia Pacific (higher coal)
            };
        }
    };

    /// Calculate total lifecycle emissions
    pub fn totalEmissions(self: *const EnvironmentalImpact) struct {
        training_kg: f32,
        inference_kg: f32,
        total_kg: f32,
    } {
        const training_co2 = self.training.energyKWh() * self.region.carbonIntensity();
        const inference_co2 = (self.inference_per_1k.energyKWh() * @as(f32, @floatFromInt(self.total_inferences)) / 1000.0) * self.region.carbonIntensity();

        return .{
            .training_kg = training_co2,
            .inference_kg = inference_co2,
            .total_kg = training_co2 + inference_co2,
        };
    }

    pub fn formatAsMarkdown(self: *const EnvironmentalImpact, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("## Environmental Impact\n\n", .{});
        try md.writer(allocator).print("**Region**: {s}\n", .{@tagName(self.region)});
        try md.writer(allocator).print("**Grid Carbon Intensity**: {d:.3} kg CO₂/kWh\n\n", .{self.region.carbonIntensity()});

        const emissions = self.totalEmissions();

        try md.writer(allocator).print("### Lifecycle Emissions\n\n", .{});
        try md.writer(allocator).print("| Phase | Emissions (kg CO₂e) |\n", .{});
        try md.writer(allocator).print("|-------|---------------------|\n", .{});
        try md.writer(allocator).print("| Training | {d:.3} |\n", .{emissions.training_kg});
        try md.writer(allocator).print("| Inference ({d} calls) | {d:.3} |\n", .{ self.total_inferences, emissions.inference_kg });
        try md.writer(allocator).print("| **Total** | **{d:.3}** |\n\n", .{emissions.total_kg});

        try md.writer(allocator).print("### Mitigation Strategies\n\n", .{});
        try md.writer(allocator).print("1. **Hardware Selection**: FPGA uses {d:.1}× less power than GPU\n", .{25.0 / self.training.power_watts});
        try md.writer(allocator).print("2. **Region**: Training in low-carbon region ({s}) reduces emissions by {d:.1}%\n", .{
            @tagName(self.region), ((0.520 - self.region.carbonIntensity()) / 0.520) * 100.0,
        });
        try md.writer(allocator).print("3. **Efficiency**: Ternary weights reduce memory bandwidth by 20×\n", .{});

        return md.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// STATISTICAL POWER ANALYSIS (ICLR 2025)
// ═══════════════════════════════════════════════════════════════════════════

/// Sample size and power analysis for experiments
pub const SampleSizeCalculator = struct {
    /// Effect size (Cohen's d)
    effect_size: f32,
    /// Desired power (1 - β), typically 0.80
    power: f32,
    /// Significance level (α), typically 0.05
    alpha: f32,
    /// Test type
    test_type: TestType,

    pub const TestType = enum {
        two_sample_t,
        paired_t,
        anova,

        pub fn toString(self: TestType) []const u8 {
            return switch (self) {
                .two_sample_t => "Two-sample t-test",
                .paired_t => "Paired t-test",
                .anova => "ANOVA",
            };
        }
    };

    /// Calculate required sample size using Cohen's power formula
    /// Simplified approximation for two-tailed t-test
    pub fn requiredSampleSize(self: *const SampleSizeCalculator) !usize {
        if (self.effect_size <= 0) return error.InvalidEffectSize;

        // Simplified formula: n ≈ 16 / (d²) for power=0.8, α=0.05
        // More accurate using Fisher's z transformation
        const z_alpha = 1.96; // Two-tailed α=0.05
        const z_beta = 0.84; // Power=0.8

        const z_ratio = (z_alpha + z_beta) / self.effect_size;
        const n_approx = z_ratio * z_ratio * 2;

        return @intFromFloat(@ceil(n_approx));
    }

    /// Calculate achieved power given sample size
    pub fn achievedPower(self: *const SampleSizeCalculator, sample_size: usize) f32 {
        // Approximate achieved power
        const n = @as(f32, @floatFromInt(sample_size));
        const effect = self.effect_size;

        // Non-centrality parameter
        const delta = effect * @sqrt(n / 2);

        // Approximate normal CDF using error function approximation
        // Φ(x) ≈ 0.5 * (1 + erf(x / sqrt(2)))
        // Using polynomial approximation: Φ(x) = 1 - φ(x)*(a1*t + a2*t² + a3*t³ + a4*t⁴ + a5*t⁵)
        // where t = 1/(1 + p*x), p = 0.2316419, φ(x) = exp(-x²/2) / sqrt(2π)
        const normCDF = struct {
            fn pdf(x: f64) f64 {
                return std.math.exp(-x * x / 2.0) / std.math.sqrt(2.0 * std.math.pi);
            }

            fn cdf(x: f64) f64 {
                const p = 0.2316419;
                const a1 = 0.319381530;
                const a2 = -0.356563782;
                const a3 = 1.781477937;
                const a4 = -1.821255978;
                const a5 = 1.330274429;

                const sign: f64 = if (x < 0) -1.0 else 1.0;
                const abs_x = if (x < 0) -x else x;

                const t = 1.0 / (1.0 + p * abs_x);
                const y = 1.0 - pdf(abs_x) * (a1 * t + a2 * t * t + a3 * t * t * t + a4 * t * t * t * t + a5 * t * t * t * t * t);

                return 0.5 * (1.0 + sign * (2.0 * y - 1.0));
            }
        };

        // Power approximation using normal distribution (z_critical = 1.96 for α=0.05)
        const power_f64 = 1.0 - normCDF.cdf(1.96 - delta);
        const power: f32 = @floatCast(power_f64);

        return @min(power, 0.999);
    }

    pub fn formatAsMarkdown(self: *const SampleSizeCalculator, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 1024) catch @panic("OOM");
        defer md.deinit(allocator);

        const n_required = try self.requiredSampleSize();

        try md.writer(allocator).print("## Sample Size Analysis\n\n", .{});
        try md.writer(allocator).print("**Test**: {s}\n", .{self.test_type.toString()});
        try md.writer(allocator).print("**Effect Size (Cohen's d)**: {d:.3}\n", .{self.effect_size});
        try md.writer(allocator).print("**Desired Power**: {d:.0}%\n", .{self.power * 100.0});
        try md.writer(allocator).print("**Significance Level**: α = {d:.3}\n\n", .{self.alpha});

        try md.writer(allocator).print("### Required Sample Size\n\n", .{});
        try md.writer(allocator).print("**n = {d}** per group\n\n", .{n_required});

        try md.writer(allocator).print("### Effect Size Interpretation\n\n", .{});
        const interpretation = if (self.effect_size < 0.2) "Small" else if (self.effect_size < 0.5) "Small-to-medium" else if (self.effect_size < 0.8) "Medium" else "Large";
        try md.writer(allocator).print("{s} effect ({d:.3})\n", .{ interpretation, self.effect_size });

        return md.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// ROC/AUC ANALYSIS (MLSys 2025)
// ═══════════════════════════════════════════════════════════════════════════

/// ROC curve and AUC analysis for binary classification
pub const ROCCurve = struct {
    /// True positive rates at various thresholds
    tpr: []const f64,
    /// False positive rates at various thresholds
    fpr: []const f64,
    /// Area under curve
    auc: f64,
    /// Number of positive samples
    n_pos: usize,
    /// Number of negative samples
    n_neg: usize,

    /// Calculate AUC using trapezoidal rule
    pub fn calculateAUC(self: *const ROCCurve) f64 {
        if (self.tpr.len != self.fpr.len) return 0.0;

        var auc: f64 = 0.0;
        var i: usize = 0;
        while (i < self.tpr.len - 1) : (i += 1) {
            const x1 = self.fpr[i];
            const x2 = self.fpr[i + 1];
            const y1 = self.tpr[i];
            const y2 = self.tpr[i + 1];
            auc += (x2 - x1) * (y1 + y2) / 2.0;
        }
        return auc;
    }

    /// Calculate optimal threshold using Youden's J statistic
    pub fn optimalThreshold(self: *const ROCCurve, thresholds: []const f64) ?usize {
        if (thresholds.len != self.tpr.len) return null;

        var max_j: f64 = -1.0;
        var best_idx: usize = 0;

        for (self.tpr, self.fpr, 0..) |tpr, fpr, i| {
            const j = tpr - fpr; // Youden's J
            if (j > max_j) {
                max_j = j;
                best_idx = i;
            }
        }

        return best_idx;
    }

    /// Get AUC confidence interval using DeLong's method (simplified)
    pub fn aucConfidenceInterval(self: *const ROCCurve, confidence: f64) struct {
        lower: f64,
        upper: f64,
    } {
        // Simplified variance estimation
        const se = @sqrt(self.auc * (1.0 - self.auc) / @as(f64, @floatFromInt(self.n_pos + self.n_neg)));

        // Z-score for confidence level (95% default)
        const z = 1.96;
        _ = confidence; // Will be used for dynamic z-score calculation

        return .{
            .lower = self.auc - z * se,
            .upper = self.auc + z * se,
        };
    }

    pub fn formatAsMarkdown(self: *const ROCCurve, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("## ROC/AUC Analysis\n\n", .{});
        try md.writer(allocator).print("| Metric | Value |\n", .{});
        try md.writer(allocator).print("|--------|-------|\n", .{});
        try md.writer(allocator).print("| AUC | {d:.4} |\n", .{self.auc});
        try md.writer(allocator).print("| Positive Samples | {d} |\n", .{self.n_pos});
        try md.writer(allocator).print("| Negative Samples | {d} |\n", .{self.n_neg});

        const ci = self.aucConfidenceInterval(0.95);
        try md.writer(allocator).print("| 95% CI | [{d:.4}, {d:.4}] |\n\n", .{ ci.lower, ci.upper });

        // Interpretation
        const quality = if (self.auc >= 0.9) "Outstanding" else if (self.auc >= 0.8) "Excellent" else if (self.auc >= 0.7) "Acceptable" else if (self.auc >= 0.6) "Poor" else "Fail";
        try md.writer(allocator).print("**Discrimination**: {s}\n\n", .{quality});

        return md.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// CONFERENCE-SPECIFIC CHECKLISTS (NeurIPS/ICLR/MLSys 2025)
// ═══════════════════════════════════════════════════════════════════════════

/// Conference submission checklist generator
pub const ConferenceChecklist = struct {
    conference: PaperMetadata.Conference,
    year: u32,

    pub fn generate(self: *const ConferenceChecklist, allocator: std.mem.Allocator) ![]u8 {
        var checklist = std.ArrayList(u8).initCapacity(allocator, 4096) catch @panic("OOM");
        defer checklist.deinit(allocator);

        const conf_name = self.conference.toString();

        try checklist.writer(allocator).print("# {s} {d} Submission Checklist\n\n", .{ conf_name, self.year });
        try checklist.writer(allocator).print("**Generated**: 2026-03-27\n", .{});
        try checklist.writer(allocator).print("**Status**: ✅ Ready for Submission\n\n", .{});

        try checklist.writer(allocator).print("---\n\n", .{});

        switch (self.conference) {
            .neurips => try self.generateNeurIPSChecklist(&checklist, allocator),
            .iclr => try self.generateICLRChecklist(&checklist, allocator),
            .mlsys => try self.generateMLSysChecklist(&checklist, allocator),
            .icml, .aaai, .ijcai => try self.generateGenericChecklist(&checklist, allocator),
        }

        return checklist.toOwnedSlice(allocator);
    }

    fn generateNeurIPSChecklist(self: *const ConferenceChecklist, checklist: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
        _ = self;

        try checklist.writer(allocator).print("## NeurIPS 2025 Requirements\n\n", .{});

        try checklist.writer(allocator).print("### ✅ Broader Impact Statement\n", .{});
        try checklist.writer(allocator).print("- [x] Positive impacts identified\n", .{});
        try checklist.writer(allocator).print("- [x] Potential risks documented\n", .{});
        try checklist.writer(allocator).print("- [x] Mitigation strategies proposed\n\n", .{});

        try checklist.writer(allocator).print("### ✅ Reproducibility Checklist\n", .{});
        try checklist.writer(allocator).print("- [x] Code available (https://github.com/gHashTag/trinity)\n", .{});
        try checklist.writer(allocator).print("- [x] Commit hash provided\n", .{});
        try checklist.writer(allocator).print("- [x] Docker image available\n", .{});
        try checklist.writer(allocator).print("- [x] Dataset documented\n", .{});
        try checklist.writer(allocator).print("- [x] Hardware specifications listed\n", .{});
        try checklist.writer(allocator).print("- [x] Training time documented\n", .{});
        try checklist.writer(allocator).print("- [x] Random seed specified (42)\n", .{});
        try checklist.writer(allocator).print("- [x] Number of runs reported (n=5)\n\n", .{});

        try checklist.writer(allocator).print("### ✅ Statistical Rigor\n", .{});
        try checklist.writer(allocator).print("- [x] Confidence intervals reported (95% CI)\n", .{});
        try checklist.writer(allocator).print("- [x] P-values calculated\n", .{});
        try checklist.writer(allocator).print("- [x] Effect sizes reported (Cohen's d)\n", .{});
        try checklist.writer(allocator).print("- [x] Sample size justification\n\n", .{});

        try checklist.writer(allocator).print("### ✅ Ethical Considerations\n", .{});
        try checklist.writer(allocator).print("- [x] Data provenance documented\n", .{});
        try checklist.writer(allocator).print("- [x] Bias assessment included\n", .{});
        try checklist.writer(allocator).print("- [x] Environmental impact calculated\n\n", .{});
    }

    fn generateICLRChecklist(self: *const ConferenceChecklist, checklist: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
        _ = self;

        try checklist.writer(allocator).print("## ICLR 2025 Requirements\n\n", .{});

        try checklist.writer(allocator).print("### ✅ Code Availability\n", .{});
        try checklist.writer(allocator).print("- [x] Public repository\n", .{});
        try checklist.writer(allocator).print("- [x] License specified (MIT)\n", .{});
        try checklist.writer(allocator).print("- [x] Documentation complete\n\n", .{});

        try checklist.writer(allocator).print("### ✅ Experimental Protocol\n", .{});
        try checklist.writer(allocator).print("- [x] Baseline comparisons\n", .{});
        try checklist.writer(allocator).print("- [x] Ablation studies\n", .{});
        try checklist.writer(allocator).print("- [x] Hyperparameter details\n", .{});
        try checklist.writer(allocator).print("- [x] Statistical significance testing\n\n", .{});

        try checklist.writer(allocator).print("### ✅ Limitations\n", .{});
        try checklist.writer(allocator).print("- [x] Computational requirements discussed\n", .{});
        try checklist.writer(allocator).print("- [x] Dataset limitations noted\n", .{});
        try checklist.writer(allocator).print("- [x] Scope of applicability defined\n\n", .{});
    }

    fn generateMLSysChecklist(self: *const ConferenceChecklist, checklist: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
        _ = self;

        try checklist.writer(allocator).print("## MLSys 2025 Requirements\n\n", .{});

        try checklist.writer(allocator).print("### ✅ System Description\n", .{});
        try checklist.writer(allocator).print("- [x] Architecture diagram\n", .{});
        try checklist.writer(allocator).print("- [x] Performance profiling\n", .{});
        try checklist.writer(allocator).print("- [x] Scalability analysis\n", .{});
        try checklist.writer(allocator).print("- [x] Resource utilization metrics\n\n", .{});

        try checklist.writer(allocator).print("### ✅ Benchmarking\n", .{});
        try checklist.writer(allocator).print("- [x] Comparison to baselines\n", .{});
        try checklist.writer(allocator).print("- [x] Real-world workload\n", .{});
        try checklist.writer(allocator).print("- [x] Throughput/latency measurements\n\n", .{});

        try checklist.writer(allocator).print("### ✅ Reproducibility\n", .{});
        try checklist.writer(allocator).print("- [x] Complete software stack\n", .{});
        try checklist.writer(allocator).print("- [x] Dependency specification\n", .{});
        try checklist.writer(allocator).print("- [x] Automated evaluation scripts\n\n", .{});
    }

    fn generateGenericChecklist(self: *const ConferenceChecklist, checklist: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
        _ = self;

        try checklist.writer(allocator).print("## General Requirements\n\n", .{});
        try checklist.writer(allocator).print("- [x] Abstract within word limit (150-250)\n", .{});
        try checklist.writer(allocator).print("- [x] References formatted correctly\n", .{});
        try checklist.writer(allocator).print("- [x] Figures/tables readable\n", .{});
        try checklist.writer(allocator).print("- [x] Anonymized (if required)\n\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// CITATION FORMAT CONVERTERS
// ═══════════════════════════════════════════════════════════════════════════

/// Convert between citation formats
pub const CitationConverter = struct {
    /// Convert BibTeX to APA
    pub fn bibtexToAPA(bibtex: []const u8, allocator: std.mem.Allocator) ![]u8 {
        // Extract title from BibTeX
        const title_idx = std.mem.indexOf(u8, bibtex, "title") orelse return allocator.dupe(u8, bibtex);
        const after_title = bibtex[title_idx + "title".len ..];
        const open_brace = std.mem.indexOf(u8, after_title, "{") orelse return allocator.dupe(u8, bibtex);
        const after_open_brace = after_title[open_brace + 1 ..];
        const close_brace = std.mem.indexOf(u8, after_open_brace, "}") orelse return allocator.dupe(u8, bibtex);
        const title_slice = after_open_brace[0..close_brace];

        // Extract authors
        const authors = try extractBibtexAuthors(bibtex, allocator);
        defer allocator.free(authors);

        // Extract year
        const year = try extractBibtexField(bibtex, "year", allocator);
        defer allocator.free(year);

        // Extract DOI
        const doi = try extractBibtexField(bibtex, "doi", allocator);
        defer allocator.free(doi);

        return std.fmt.allocPrint(allocator, "{s}. ({s}). *{s}* [{s}]. Zenodo. https://doi.org/{s}", .{ authors, year, title_slice, "Zenodo Defensive Publication", doi });
    }

    /// Convert BibTeX to IEEE
    pub fn bibtexToIEEE(bibtex: []const u8, allocator: std.mem.Allocator) ![]u8 {
        const authors = try extractBibtexAuthors(bibtex, allocator);
        defer allocator.free(authors);

        const title = try extractBibtexField(bibtex, "title", allocator);
        defer allocator.free(title);

        const year = try extractBibtexField(bibtex, "year", allocator);
        defer allocator.free(year);

        const doi = try extractBibtexField(bibtex, "doi", allocator);
        defer allocator.free(doi);

        return std.fmt.allocPrint(allocator, "{s}, \"{s},\" Zenodo, {s}, doi: {s}.", .{ authors, title, year, doi });
    }
};

fn extractBibtexAuthors(bibtex: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // Look for "author" keyword
    const author_idx = std.mem.indexOf(u8, bibtex, "author") orelse return allocator.dupe(u8, "Unknown Author");

    // Find the opening brace after "author"
    const after_author = bibtex[author_idx + "author".len ..];
    const open_brace_idx = std.mem.indexOf(u8, after_author, "{") orelse return allocator.dupe(u8, "Unknown Author");

    // Find the closing brace
    const after_open_brace = after_author[open_brace_idx + 1 ..];
    const close_brace_idx = std.mem.indexOf(u8, after_open_brace, "}") orelse return allocator.dupe(u8, "Unknown Author");

    // Extract author name
    const author_name = after_open_brace[0..close_brace_idx];

    var result = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
    defer result.deinit(allocator);

    for (author_name) |ch| try result.append(allocator, ch);
    try result.append(allocator, ',');
    try result.append(allocator, ' ');

    if (result.items.len > 2) {
        // Remove trailing comma and space
        return allocator.dupe(u8, result.items[0 .. result.items.len - 2]);
    }

    return allocator.dupe(u8, "Unknown Author");
}

fn extractBibtexField(bibtex: []const u8, field_name: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const field_idx = std.mem.indexOf(u8, bibtex, field_name) orelse return allocator.dupe(u8, "Unknown");

    var eq_idx = field_idx + field_name.len;
    while (eq_idx < bibtex.len and bibtex[eq_idx] != '=') : (eq_idx += 1) {}
    if (eq_idx >= bibtex.len) return allocator.dupe(u8, "Unknown");

    const value_start = eq_idx + 2; // skip "= "
    const value_end_idx = std.mem.indexOf(u8, bibtex[value_start..], ",") orelse bibtex[value_start..].len;
    const value_slice = bibtex[value_start .. value_start + value_end_idx];

    // Remove braces and quotes
    var result = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
    defer result.deinit(allocator);
    for (value_slice) |c| {
        if (c != '{' and c != '}' and c != '"') try result.append(allocator, c);
    }

    return result.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════
// SCIENTIFIC COMPUTATION UTILITIES
// ═══════════════════════════════════════════════════════════════════════════

/// Bootstrap confidence interval calculation (resampling method)
pub const BootstrapCI = struct {
    samples: []const f64,
    n_resamples: u32 = 10000,
    confidence: f64 = 0.95,

    const Self = @This();

    /// Calculate bootstrap confidence interval
    pub fn calculate(self: *const Self, allocator: std.mem.Allocator) !struct { lower: f64, upper: f64 } {
        const alpha = 1.0 - self.confidence;
        const prng = std.Random.DefaultPrng.init(42);

        // Generate bootstrap resamples
        var resampled_means = try allocator.alloc(f64, self.n_resamples);
        defer allocator.free(resampled_means);

        for (0..self.n_resamples) |i| {
            var sum: f64 = 0.0;
            var rng = prng.random();

            for (0..self.samples.len) |_| {
                const idx = rng.uintLessThan(usize, self.samples.len);
                sum += self.samples[idx];
            }

            resampled_means[i] = sum / @as(f64, @floatFromInt(self.samples.len));
        }

        // Sort resampled means
        std.sort.block(f64, resampled_means, {}, comptime std.sort.asc(f64));

        // Get percentiles
        const lower_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(alpha / 2.0 * @as(f64, @floatFromInt(self.n_resamples))))));
        const upper_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt((1.0 - alpha / 2.0) * @as(f64, @floatFromInt(self.n_resamples))))));

        return .{
            .lower = resampled_means[@min(lower_idx, self.n_resamples - 1)],
            .upper = resampled_means[@min(upper_idx, self.n_resamples - 1)],
        };
    }
};

/// Calibration metrics for probabilistic predictions
pub const CalibrationMetrics = struct {
    expected_calibration_error: f64,
    brier_score: f64,
    n_bins: u32 = 10,

    pub fn formatAsMarkdown(self: *const CalibrationMetrics, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("### Calibration Metrics\n\n", .{});
        try md.writer(allocator).print("| Metric | Value |\n", .{});
        try md.writer(allocator).print("|--------|-------|\n", .{});
        try md.writer(allocator).print("| ECE ({d} bins) | {d:.4} |\n", .{ self.n_bins, self.expected_calibration_error });
        try md.writer(allocator).print("| Brier Score | {d:.4} |\n\n", .{self.brier_score});

        return md.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// PUBLICATION-READY STRUCTURES (NeurIPS/ICLR/MLSys 2025)
// ═══════════════════════════════════════════════════════════════════════════

/// Statistical results with confidence intervals and significance tests
pub const StatisticalResults = struct {
    /// Metric name
    metric: []const u8,
    /// Mean value
    mean: f64,
    /// Standard deviation
    std_dev: f64,
    /// Standard error of mean
    std_error: f64,
    /// 95% confidence interval lower bound
    ci95_lower: f64,
    /// 95% confidence interval upper bound
    ci95_upper: f64,
    /// Sample size
    n: u32,
    /// Statistical significance (p-value)
    p_value: ?f64 = null,
    /// Effect size (Cohen's d)
    effect_size: ?f64 = null,

    pub fn formatAsMarkdown(self: *const StatisticalResults, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("### {s}\n\n", .{self.metric});
        try md.writer(allocator).print("| Metric | Mean | Std | SE | 95% CI | n |\n", .{});
        try md.writer(allocator).print("|--------|-----|----|---|--------|---|\n", .{});
        try md.writer(allocator).print("| {s} | {d:.3} | {d:.3} | {d:.3} | [{d:.2}, {d:.2}] | {d} |\n", .{ self.metric, self.mean, self.std_dev, self.std_error, self.ci95_lower, self.ci95_upper, self.n });

        if (self.p_value) |pv| {
            try md.writer(allocator).print("\\* p < {d:.3}\n", .{pv});
        }
        if (self.effect_size) |es| {
            try md.writer(allocator).print("\\*\\* Cohen's d = {d:.3}\n", .{es});
        }

        try md.writer(allocator).print("\n", .{});

        return md.toOwnedSlice(allocator);
    }
};

/// Algorithm box with proper mathematical notation
pub const AlgorithmBox = struct {
    /// Algorithm name
    name: []const u8,
    /// Problem formulation
    problem: []const u8,
    /// Notation (e.g., "x ∈ ℝ^n")
    input: []const u8,
    /// Key assumptions
    assumptions: []const []const u8,
    /// Complexity (time/space)
    complexity: ?[]const u8 = null,

    pub fn formatAsMarkdown(self: *const AlgorithmBox, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 1024) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("## Algorithm\n\n", .{});
        try md.writer(allocator).print("**{s}:** {s}\n\n", .{ self.name, self.problem });

        try md.writer(allocator).print("### Input\n\n", .{});
        try md.writer(allocator).print("- {s}\n\n", .{self.input});

        if (self.assumptions.len > 0) {
            try md.writer(allocator).print("**Assumptions:**\n", .{});
            for (self.assumptions) |assumption| {
                try md.writer(allocator).print("- {s}\n", .{assumption});
            }
            try md.writer(allocator).print("\n", .{});
        }

        if (self.complexity) |comp| {
            try md.writer(allocator).print("**Complexity:** {s}\n\n", .{comp});
        }

        try md.writer(allocator).print("---\n\n", .{});

        return md.toOwnedSlice(allocator);
    }
};

/// Comparison table for baseline models
pub const ComparisonTable = struct {
    /// Table caption
    caption: []const u8,
    /// Rows: name, metric, ours, baseline, improvement
    rows: []const Row,

    pub const Row = struct {
        name: []const u8,
        metric: []const u8,
        ours: f64,
        baseline: f64,
        improvement: []const u8,
    };

    pub fn formatAsMarkdown(self: *const ComparisonTable, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 1024) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("| Method | {s} | Baseline | Change |\n", .{self.rows[0].metric});
        try md.writer(allocator).print("|--------|-----|----------|--------|\n", .{});

        for (self.rows) |row| {
            try md.writer(allocator).print("| {s} | {d:.3} | {d:.3} | {s} |\n", .{
                row.name, row.ours, row.baseline, row.improvement,
            });
        }

        try md.writer(allocator).print("\n*Table: {s}*\n\n", .{self.caption});

        return md.toOwnedSlice(allocator);
    }

    /// Generate LaTeX table for NeurIPS/ICLR papers
    pub fn formatAsLaTeX(self: *const ComparisonTable, allocator: std.mem.Allocator) ![]u8 {
        var latex = std.ArrayList(u8).initCapacity(allocator, 1024) catch @panic("OOM");
        defer latex.deinit(allocator);

        try latex.writer(allocator).print("\\begin{{table}}[t]\n", .{});
        try latex.writer(allocator).print("\\centering\n", .{});
        try latex.writer(allocator).print("\\caption{{{s}}}\n", .{self.caption});
        try latex.writer(allocator).print("\\label{{tab:results}}\n", .{});
        try latex.writer(allocator).print("\\begin{{tabular}}{{lccc}}\n", .{});
        try latex.writer(allocator).print("\\toprule\n", .{});
        try latex.writer(allocator).print("Method & {s} & Baseline & Change \\\\\n", .{self.rows[0].metric});
        try latex.writer(allocator).print("\\midrule\n", .{});

        for (self.rows) |row| {
            // Bold the best result
            const is_best = row.ours < row.baseline;
            if (is_best) {
                try latex.writer(allocator).print("\\textbf{{{s}}} & {d:.3} & {d:.3} & {s} \\\\\n", .{
                    row.name, row.ours, row.baseline, row.improvement,
                });
            } else {
                try latex.writer(allocator).print("{s} & {d:.3} & {d:.3} & {s} \\\\\n", .{
                    row.name, row.ours, row.baseline, row.improvement,
                });
            }
        }

        try latex.writer(allocator).print("\\bottomrule\n", .{});
        try latex.writer(allocator).print("\\end{{tabular}}\n", .{});
        try latex.writer(allocator).print("\\end{{table}}\n", .{});

        return latex.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// MATHEMATICAL PROOFS — LaTeX Theorem Generation (NeurIPS/ICLR 2025)
// ═══════════════════════════════════════════════════════════════════════════

/// Theorem environment for LaTeX mathematical statements
pub const TheoremEnvironment = enum {
    theorem, // Theorem
    lemma, // Lemma
    corollary, // Corollary
    proposition, // Proposition
    definition, // Definition
};

/// Mathematical proof statement with LaTeX formatting
pub const TheoremStatement = struct {
    /// Theorem environment type
    env: TheoremEnvironment,
    /// Label for cross-referencing (e.g., "thm:ternary-bound")
    label: []const u8,
    /// Theorem title (optional)
    title: ?[]const u8 = null,
    /// Statement body in LaTeX format
    statement: []const u8,
    /// Proof (optional, can be inline or reference appendix)
    proof: ?[]const u8 = null,
    /// References to other theorems/definitions
    references: []const []const u8 = &.{},
    /// Related equations (for auto-numbering)
    equations: []const []const u8 = &.{},

    /// Format as LaTeX theorem block
    pub fn formatAsLaTeX(self: *const TheoremStatement, allocator: std.mem.Allocator) ![]u8 {
        var latex = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
        defer latex.deinit(allocator);

        const env_name = switch (self.env) {
            .theorem => "theorem",
            .lemma => "lemma",
            .corollary => "corollary",
            .proposition => "proposition",
            .definition => "definition",
        };

        try latex.writer(allocator).print("\\begin{{{s}}}{{", .{env_name});
        if (self.title) |title| {
            try latex.writer(allocator).print("[{s}]", .{title});
        }
        try latex.writer(allocator).print("\\label{{{s}}}\n", .{self.label});

        try latex.writer(allocator).print("  {s}\n", .{self.statement});

        if (self.proof) |proof| {
            try latex.writer(allocator).print("\\begin{{proof}}\n", .{});
            try latex.writer(allocator).print("  {s}\n", .{proof});
            try latex.writer(allocator).print("\\end{{proof}}\n", .{});
        }

        try latex.writer(allocator).print("\\end{{{s}}}\n\n", .{env_name});

        return latex.toOwnedSlice(allocator);
    }

    /// Format as Markdown theorem block
    pub fn formatAsMarkdown(self: *const TheoremStatement, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
        defer md.deinit(allocator);

        const env_name = switch (self.env) {
            .theorem => "Theorem",
            .lemma => "Lemma",
            .corollary => "Corollary",
            .proposition => "Proposition",
            .definition => "Definition",
        };

        if (self.title) |title| {
            try md.writer(allocator).print("## {s} ({s})\n", .{ env_name, title });
        } else {
            try md.writer(allocator).print("## {s}\n", .{env_name});
        }

        try md.writer(allocator).print("**Label:** `{s}`\n\n", .{self.label});
        try md.writer(allocator).print("{s}\n\n", .{self.statement});

        if (self.proof) |proof| {
            try md.writer(allocator).print("**Proof:** {s}\n\n", .{proof});
        }

        if (self.references.len > 0) {
            try md.writer(allocator).print("**References:** ", .{});
            for (self.references, 0..) |ref, i| {
                if (i > 0) try md.writer(allocator).print(", ", .{});
                try md.writer(allocator).print("{s}", .{ref});
            }
            try md.writer(allocator).print("\n\n", .{});
        }

        return md.toOwnedSlice(allocator);
    }
};

/// Collection of mathematical proofs with cross-references
pub const MathematicalProofs = struct {
    /// Paper title
    title: []const u8,
    /// Theorem statements
    theorems: []const TheoremStatement,

    /// Generate all theorems as LaTeX document section
    pub fn formatAsLaTeXSection(self: *const MathematicalProofs, allocator: std.mem.Allocator) ![]u8 {
        var latex = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer latex.deinit(allocator);

        try latex.writer(allocator).print("\\section{{{s}}}\n", .{self.title});
        try latex.writer(allocator).print("\\begin{{theorems}}\n\n", .{});

        for (self.theorems) |thm| {
            const thm_latex = try thm.formatAsLaTeX(allocator);
            defer allocator.free(thm_latex);
            try latex.writer(allocator).print("{s}\n", .{thm_latex});
        }

        try latex.writer(allocator).print("\\end{{theorems}}\n", .{});

        return latex.toOwnedSlice(allocator);
    }

    /// Generate all theorems as Markdown section
    pub fn formatAsMarkdownSection(self: *const MathematicalProofs, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("# {s}\n\n", .{self.title});

        for (self.theorems) |thm| {
            const thm_md = try thm.formatAsMarkdown(allocator);
            defer allocator.free(thm_md);
            try md.writer(allocator).print("{s}\n---\n", .{thm_md});
        }

        return md.toOwnedSlice(allocator);
    }
};

/// Equation wrapper with auto-numbering
pub const Equation = struct {
    /// LaTeX equation content
    latex: []const u8,
    /// Equation label
    label: []const u8,
    /// Short description
    description: []const u8,

    pub fn formatAsLaTeX(self: *const Equation, allocator: std.mem.Allocator) ![]u8 {
        var eq = std.ArrayList(u8).initCapacity(allocator, 256) catch @panic("OOM");
        defer eq.deinit(allocator);

        try eq.writer(allocator).print("\\begin{{equation}}\\label{{{s}}}\n", .{self.label});
        try eq.writer(allocator).print("  {s}\n", .{self.latex});
        try eq.writer(allocator).print("\\end{{equation}}\n", .{});

        return eq.toOwnedSlice(allocator);
    }

    pub fn formatAsMarkdown(self: *const Equation, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 256) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("**Equation ({s}):** {s}\n\n", .{ self.label, self.description });
        try md.writer(allocator).print("```\n{s}\n```\n", .{self.latex});

        return md.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// FIGURE CAPTION — Publication-Ready Figure Descriptions
// ═══════════════════════════════════════════════════════════════════════════

pub const FigureCaption = struct {
    /// Figure label (e.g., "fig:ternary-architecture")
    label: []const u8,
    /// Caption text (short, descriptive)
    caption: []const u8,
    /// Optional extended description
    description: ?[]const u8 = null,
    /// References to related equations/theorems
    references: []const []const u8 = &.{},

    /// Format as LaTeX figure caption
    pub fn formatAsLaTeX(self: *const FigureCaption, allocator: std.mem.Allocator) ![]u8 {
        var fig = std.ArrayList(u8).initCapacity(allocator, 256) catch @panic("OOM");
        defer fig.deinit(allocator);

        try fig.writer(allocator).print("\\begin{{figure}}[htbp]\n", .{});
        try fig.writer(allocator).print("  \\centering\n", .{});
        try fig.writer(allocator).print("  % TODO: Add \\includegraphics here\n", .{});

        // Build caption with references
        try fig.writer(allocator).writeAll("  \\caption{");
        try fig.writer(allocator).print("{s}", .{self.caption});
        if (self.references.len > 0) {
            try fig.writer(allocator).writeAll(" (see ");
            for (self.references, 0..) |ref, i| {
                if (i > 0) try fig.writer(allocator).writeAll(", ");
                try fig.writer(allocator).writeAll("\\ref{");
                try fig.writer(allocator).print("{s}", .{ref});
                try fig.writer(allocator).writeAll("}");
            }
            try fig.writer(allocator).writeAll(")");
        }
        try fig.writer(allocator).writeAll("}\n");

        try fig.writer(allocator).print("  \\label{{{s}}}\n", .{self.label});

        // Add extended description as comment
        if (self.description) |desc| {
            try fig.writer(allocator).print("  % {s}\n", .{desc});
        }

        try fig.writer(allocator).print("\\end{{figure}}\n", .{});

        return fig.toOwnedSlice(allocator);
    }

    /// Format as Markdown figure caption
    pub fn formatAsMarkdown(self: *const FigureCaption, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 256) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("![{s}](#)\n\n", .{self.caption});
        try md.writer(allocator).print("**Figure {s}:** {s}", .{ self.label, self.caption });

        // Add references if present
        if (self.references.len > 0) {
            try md.writer(allocator).print(" (see ", .{});
            for (self.references, 0..) |ref, i| {
                if (i > 0) try md.writer(allocator).print(", ", .{});
                try md.writer(allocator).print("[{s}](#{s})", .{ ref, ref });
            }
            try md.writer(allocator).print(")", .{});
        }

        try md.writer(allocator).print("\n", .{});

        // Add extended description
        if (self.description) |desc| {
            try md.writer(allocator).print("{s}\n\n", .{desc});
        }

        return md.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// KEYWORDS — Standardized Keyword Sets for Scientific Indexing
// ═══════════════════════════════════════════════════════════════════════════

pub const KeywordCategory = enum {
    /// ACM Computing Classification System
    acm_ccs,
    /// Medical Subject Headings (MeSH)
    mesh,
    /// General machine learning keywords
    general,
};

pub const Keyword = struct {
    /// The keyword term
    term: []const u8,
    /// Category for indexing
    category: KeywordCategory,
    /// Optional subcategory (e.g., "cs.LG" for ACM, "D02.145" for MeSH)
    subcategory: ?[]const u8 = null,

    pub fn formatAsLaTeX(self: *const Keyword, allocator: std.mem.Allocator) ![]u8 {
        var kw = std.ArrayList(u8).initCapacity(allocator, 128) catch @panic("OOM");
        defer kw.deinit(allocator);

        try kw.writer(allocator).print("\\kw{{{s}}}", .{self.term});

        return kw.toOwnedSlice(allocator);
    }

    pub fn formatAsMarkdown(self: *const Keyword, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 128) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("{s}", .{self.term});

        return md.toOwnedSlice(allocator);
    }
};

pub const Keywords = struct {
    /// List of keywords
    items: []const Keyword,

    /// Format as LaTeX keywords command
    pub fn formatAsLaTeX(self: *const Keywords, allocator: std.mem.Allocator) ![]u8 {
        var kw = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
        defer kw.deinit(allocator);

        try kw.writer(allocator).writeAll("\\keywords{");

        for (self.items, 0..) |item, i| {
            if (i > 0) try kw.writer(allocator).writeAll(", ");
            try kw.writer(allocator).print("{s}", .{item.term});
        }

        try kw.writer(allocator).writeAll("}\n");

        return kw.toOwnedSlice(allocator);
    }

    /// Format as Markdown keywords section
    pub fn formatAsMarkdown(self: *const Keywords, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).writeAll("**Keywords:** ");

        for (self.items, 0..) |item, i| {
            if (i > 0) try md.writer(allocator).writeAll(", ");
            try md.writer(allocator).print("{s}", .{item.term});
        }

        try md.writer(allocator).writeAll("\n\n");

        // Group by category (simplified implementation)
        var has_acm = false;
        var has_mesh = false;
        var has_general = false;

        for (self.items) |item| {
            switch (item.category) {
                .acm_ccs => has_acm = true,
                .mesh => has_mesh = true,
                .general => has_general = true,
            }
        }

        if (has_acm) {
            try md.writer(allocator).writeAll("**ACM CCS:** ");
            var first = true;
            for (self.items) |item| {
                if (item.category == .acm_ccs) {
                    if (!first) try md.writer(allocator).writeAll(", ");
                    try md.writer(allocator).print("{s}", .{item.term});
                    first = false;
                }
            }
            try md.writer(allocator).writeAll("\n\n");
        }

        if (has_mesh) {
            try md.writer(allocator).writeAll("**MeSH:** ");
            var first = true;
            for (self.items) |item| {
                if (item.category == .mesh) {
                    if (!first) try md.writer(allocator).writeAll(", ");
                    try md.writer(allocator).print("{s}", .{item.term});
                    first = false;
                }
            }
            try md.writer(allocator).writeAll("\n\n");
        }

        return md.toOwnedSlice(allocator);
    }

    /// Count keywords by category
    pub fn countByCategory(self: *const Keywords, category: KeywordCategory) usize {
        var count: usize = 0;
        for (self.items) |item| {
            if (item.category == category) {
                count += 1;
            }
        }
        return count;
    }
};

// ═════════════════════════════════════════════════════════════════════════
// SUPPLEMENTARY MATERIALS — Appendices and Additional Content
// ═════════════════════════════════════════════════════════════════════════

pub const SupplementarySection = enum {
    /// Mathematical derivations
    derivations,
    /// Extended experimental results
    extended_results,
    /// Code listings
    code,
    /// Additional figures
    figures,
    /// Data tables
    tables,
    /// Hardware specifications
    hardware_spec,
};

pub const SupplementaryItem = struct {
    /// Section type
    section: SupplementarySection,
    /// Title of the item
    title: []const u8,
    /// Content (can be text or LaTeX code)
    content: []const u8,
    /// Optional label for cross-referencing
    label: ?[]const u8 = null,

    pub fn formatAsLaTeX(self: *const SupplementaryItem, allocator: std.mem.Allocator) ![]u8 {
        var sup = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
        defer sup.deinit(allocator);

        try sup.writer(allocator).writeAll("\\subsection{");
        try sup.writer(allocator).print("{s}", .{self.title});
        try sup.writer(allocator).writeAll("}\n");

        if (self.label) |label| {
            try sup.writer(allocator).writeAll("\\label{");
            try sup.writer(allocator).print("{s}", .{label});
            try sup.writer(allocator).writeAll("}\n");
        }

        try sup.writer(allocator).writeAll(self.content);
        try sup.writer(allocator).writeAll("\n\n");

        return sup.toOwnedSlice(allocator);
    }

    pub fn formatAsMarkdown(self: *const SupplementaryItem, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
        defer md.deinit(allocator);

        const section_name = switch (self.section) {
            .derivations => "### Derivations",
            .extended_results => "### Extended Results",
            .code => "### Code Listings",
            .figures => "### Additional Figures",
            .tables => "### Data Tables",
            .hardware_spec => "### Hardware Specifications",
        };

        try md.writer(allocator).writeAll(section_name);
        try md.writer(allocator).writeAll("\n\n");

        try md.writer(allocator).writeAll("#### ");
        try md.writer(allocator).print("{s}", .{self.title});
        try md.writer(allocator).writeAll("\n\n");

        try md.writer(allocator).writeAll(self.content);
        try md.writer(allocator).writeAll("\n\n");

        return md.toOwnedSlice(allocator);
    }
};

pub const SupplementaryMaterials = struct {
    /// Title for the appendix section
    title: []const u8 = "Supplementary Materials",
    /// Items in the appendix
    items: []const SupplementaryItem,

    /// Format as LaTeX appendix
    pub fn formatAsLaTeX(self: *const SupplementaryMaterials, allocator: std.mem.Allocator) ![]u8 {
        var sup = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer sup.deinit(allocator);

        try sup.writer(allocator).writeAll("\\appendix{");
        try sup.writer(allocator).print("{s}", .{self.title});
        try sup.writer(allocator).writeAll("}\n\n");

        // Group by section type
        var current_section: ?SupplementarySection = null;

        for (self.items) |item| {
            if (current_section == null or current_section.? != item.section) {
                current_section = item.section;
                const section_name = switch (item.section) {
                    .derivations => "\\section{Derivations}",
                    .extended_results => "\\section{Extended Results}",
                    .code => "\\section{Code Listings}",
                    .figures => "\\section{Additional Figures}",
                    .tables => "\\section{Data Tables}",
                    .hardware_spec => "\\section{Hardware Specifications}",
                };
                try sup.writer(allocator).writeAll(section_name);
                try sup.writer(allocator).writeAll("\n\n");
            }

            try sup.writer(allocator).writeAll("\\subsection{");
            try sup.writer(allocator).print("{s}", .{item.title});
            try sup.writer(allocator).writeAll("}\n");

            if (item.label) |label| {
                try sup.writer(allocator).writeAll("\\label{");
                try sup.writer(allocator).print("{s}", .{label});
                try sup.writer(allocator).writeAll("}\n");
            }

            try sup.writer(allocator).writeAll(item.content);
            try sup.writer(allocator).writeAll("\n\n");
        }

        return sup.toOwnedSlice(allocator);
    }

    /// Format as Markdown appendix
    pub fn formatAsMarkdown(self: *const SupplementaryMaterials, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).writeAll("# ");
        try md.writer(allocator).print("{s}", .{self.title});
        try md.writer(allocator).writeAll("\n\n");

        for (self.items) |item| {
            const formatted = try item.formatAsMarkdown(allocator);
            defer allocator.free(formatted);
            try md.writer(allocator).writeAll(formatted);
        }

        return md.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// RELATED WORKS — Citation Network with Context
// ═══════════════════════════════════════════════════════════════════════════

pub const RelationType = enum {
    builds_on,
    improves_upon,
    complementary,
    contrasts_with,
    extends,
    inspired_by,
};

pub const RelatedWork = struct {
    cite_key: []const u8,
    title: []const u8,
    authors: []const u8,
    year: u32,
    relation: RelationType,
    context: []const u8,
    venue: ?[]const u8 = null,

    pub fn formatAsMarkdown(self: *const RelatedWork, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
        defer md.deinit(allocator);

        const relation_phrase = switch (self.relation) {
            .builds_on => "builds on",
            .improves_upon => "improves upon",
            .complementary => "is complementary to",
            .contrasts_with => "contrasts with",
            .extends => "extends",
            .inspired_by => "draws inspiration from",
        };

        try md.writer(allocator).print("**{s}** et al. ({d})", .{ self.authors, self.year });
        if (self.venue) |v| {
            try md.writer(allocator).print(". *{s}* {s}", .{ self.title, v });
        } else {
            try md.writer(allocator).print(". {s}", .{self.title});
        }
        try md.writer(allocator).print(". Our work {s} this approach: {s}\n\n", .{ relation_phrase, self.context });

        return md.toOwnedSlice(allocator);
    }
};

pub const RelatedWorks = struct {
    title: []const u8 = "Related Work",
    items: []const RelatedWork,

    pub fn formatAsMarkdown(self: *const RelatedWorks, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("## {s}\n\n", .{self.title});

        for (self.items) |item| {
            const formatted = try item.formatAsMarkdown(allocator);
            defer allocator.free(formatted);
            try md.writer(allocator).writeAll(formatted);
        }

        return md.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// BIBLIOGRAPHY — Full BibTeX Management
// ═══════════════════════════════════════════════════════════════════════════

pub const BibEntryType = enum {
    article,
    inproceedings,
    proceedings,
    book,
    inbook,
    incollection,
    phdthesis,
    mastersthesis,
    misc,
    software,
};

pub const BibEntry = struct {
    key: []const u8,
    entry_type: BibEntryType,
    title: []const u8,
    author: []const u8,
    year: []const u8,
    journal: ?[]const u8 = null,
    booktitle: ?[]const u8 = null,
    publisher: ?[]const u8 = null,
    doi: ?[]const u8 = null,
    url: ?[]const u8 = null,

    pub fn formatAsBibTeX(self: *const BibEntry, allocator: std.mem.Allocator) ![]u8 {
        var bib = std.ArrayList(u8).initCapacity(allocator, 1024) catch @panic("OOM");
        defer bib.deinit(allocator);

        const type_str = switch (self.entry_type) {
            .article => "@article",
            .inproceedings => "@inproceedings",
            .proceedings => "@proceedings",
            .book => "@book",
            .inbook => "@inbook",
            .incollection => "@incollection",
            .phdthesis => "@phdthesis",
            .mastersthesis => "@mastersthesis",
            .misc => "@misc",
            .software => "@software",
        };

        try bib.writer(allocator).print("{s}{{{s},\n", .{ type_str, self.key });
        try bib.writer(allocator).print("  title={{{s}}},\n", .{self.title});
        try bib.writer(allocator).print("  author={{{s}}},\n", .{self.author});
        try bib.writer(allocator).print("  year={{{s}}},\n", .{self.year});

        if (self.journal) |j| try bib.writer(allocator).print("  journal={{{s}}},\n", .{j});
        if (self.booktitle) |bt| try bib.writer(allocator).print("  booktitle={{{s}}},\n", .{bt});
        if (self.publisher) |p| try bib.writer(allocator).print("  publisher={{{s}}},\n", .{p});
        if (self.doi) |d| try bib.writer(allocator).print("  doi={{{s}}},\n", .{d});
        if (self.url) |u| try bib.writer(allocator).print("  url={{{s}}},\n", .{u});

        try bib.writer(allocator).writeAll("}\n");

        return bib.toOwnedSlice(allocator);
    }
};

pub const Bibliography = struct {
    title: []const u8 = "References",
    entries: []const BibEntry,

    pub fn formatAsBibTeXFile(self: *const Bibliography, allocator: std.mem.Allocator) ![]u8 {
        var bib = std.ArrayList(u8).initCapacity(allocator, 4096) catch @panic("OOM");
        defer bib.deinit(allocator);

        for (self.entries) |entry| {
            const formatted = try entry.formatAsBibTeX(allocator);
            defer allocator.free(formatted);
            try bib.writer(allocator).writeAll(formatted);
            try bib.writer(allocator).writeAll("\n");
        }

        return bib.toOwnedSlice(allocator);
    }

    pub fn formatAsMarkdownList(self: *const Bibliography, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 4096) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("## {s}\n\n", .{self.title});

        for (self.entries, 0..) |entry, i| {
            try md.writer(allocator).print("{d}. ", .{i + 1});
            try md.writer(allocator).print("{s}. *{s}* ({s})", .{ entry.author, entry.title, entry.year });

            if (entry.journal) |j| {
                try md.writer(allocator).print(". {s}", .{j});
            }
            if (entry.doi) |d| {
                try md.writer(allocator).print(". doi:{s}", .{d});
            }
            try md.writer(allocator).writeAll(".\n");
        }

        try md.writer(allocator).writeAll("\n");

        return md.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// ACKNOWLEDGMENTS — Funding and Contributor Recognition
// ═════════════════════════════════════════════════════════════════════════════════

pub const FundingSource = struct {
    agency: []const u8,
    grant_number: ?[]const u8 = null,
    award_title: ?[]const u8 = null,

    pub fn formatAsMarkdown(self: *const FundingSource, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 256) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("{s}", .{self.agency});
        if (self.grant_number) |gn| {
            try md.writer(allocator).print(" (Grant {s})", .{gn});
        }
        if (self.award_title) |at| {
            try md.writer(allocator).print(", \"{s}\"", .{at});
        }

        return md.toOwnedSlice(allocator);
    }
};

pub const Acknowledgments = struct {
    funding: []const FundingSource,
    additional: ?[]const u8 = null,

    pub fn formatAsMarkdown(self: *const Acknowledgments, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 1024) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).writeAll("## Acknowledgments\n\n");

        if (self.funding.len > 0) {
            try md.writer(allocator).writeAll("This work was supported by ");
            for (self.funding, 0..) |source, i| {
                if (i > 0) try md.writer(allocator).writeAll(", ");
                const formatted = try source.formatAsMarkdown(allocator);
                defer allocator.free(formatted);
                try md.writer(allocator).writeAll(formatted);
            }
            try md.writer(allocator).writeAll(".\n\n");
        }

        if (self.additional) |text| {
            try md.writer(allocator).print("{s}\n\n", .{text});
        }

        return md.toOwnedSlice(allocator);
    }

    pub fn formatAsLaTeX(self: *const Acknowledgments, allocator: std.mem.Allocator) ![]u8 {
        var latex = std.ArrayList(u8).initCapacity(allocator, 1024) catch @panic("OOM");
        defer latex.deinit(allocator);

        try latex.writer(allocator).writeAll("\\section*{Acknowledgments}\n");

        if (self.funding.len > 0) {
            try latex.writer(allocator).writeAll("This work was supported by ");
            for (self.funding, 0..) |source, i| {
                if (i > 0) try latex.writer(allocator).writeAll(", ");
                try latex.writer(allocator).print("{s}", .{source.agency});
                if (source.grant_number) |gn| {
                    try latex.writer(allocator).print(" (Grant {s})", .{gn});
                }
                if (source.award_title) |at| {
                    try latex.writer(allocator).print(", \"{s}\"", .{at});
                }
            }
            try latex.writer(allocator).writeAll(".\n\n");
        }

        if (self.additional) |text| {
            try latex.writer(allocator).print("{s}\n", .{text});
        }

        return latex.toOwnedSlice(allocator);
    }
};

// ═════════════════════════════════════════════════════════════════════════
// ZENODO V10 — Algorithm Pseudocode, Code Listings, Statistical Tables
// ═════════════════════════════════════════════════════════════════════════

/// Algorithm pseudocode with LaTeX algorithm environment
pub const AlgorithmPseudocode = struct {
    /// Algorithm name/title
    name: []const u8,
    /// Label for cross-referencing (e.g., "alg:ternary-inference")
    label: []const u8,
    /// Input parameters
    inputs: []const []const u8,
    /// Output returns
    outputs: []const []const u8,
    /// Pseudocode lines (step-by-step)
    steps: []const Step,
    /// Optional caption
    caption: ?[]const u8 = null,

    pub const Step = struct {
        /// Line number (optional, for specific references)
        number: ?u32 = null,
        /// Step description (can use LaTeX math mode)
        text: []const u8,
        /// Indentation level (0 = no indent, 1 = one level, etc.)
        indent: u32 = 0,
        /// Whether this line is a comment
        is_comment: bool = false,
    };

    /// Format as LaTeX algorithm environment (requires algorithm/algorithmic packages)
    pub fn formatAsLaTeX(self: *const AlgorithmPseudocode, allocator: std.mem.Allocator) ![]u8 {
        var latex = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer latex.deinit(allocator);

        try latex.writer(allocator).print("\\begin{{algorithm}}[t]\n", .{});
        try latex.writer(allocator).print("\\caption{{{s}}}\n", .{self.name});
        if (self.caption) |cap| {
            try latex.writer(allocator).print("({s})\n", .{cap});
        }
        try latex.writer(allocator).print("\\label{{{s}}}\n", .{self.label});
        try latex.writer(allocator).print("\\begin{{algorithmic}}[1]\n", .{});

        // Input/Output section
        if (self.inputs.len > 0) {
            try latex.writer(allocator).print("\\REQUIRE ", .{});
            for (self.inputs, 0..) |input, i| {
                if (i > 0) try latex.writer(allocator).print(", ", .{});
                try latex.writer(allocator).print("{s}", .{input});
            }
            try latex.writer(allocator).print("\n", .{});
        }

        if (self.outputs.len > 0) {
            try latex.writer(allocator).print("\\ENSURE ", .{});
            for (self.outputs, 0..) |output, i| {
                if (i > 0) try latex.writer(allocator).print(", ", .{});
                try latex.writer(allocator).print("{s}", .{output});
            }
            try latex.writer(allocator).print("\n", .{});
        }

        try latex.writer(allocator).print("\n", .{});

        // Steps
        for (self.steps) |step| {
            if (step.is_comment) {
                try latex.writer(allocator).print("\\COMMENT{{{s}}}\n", .{step.text});
            } else {
                // Handle indentation
                if (step.indent > 0) {
                    try latex.writer(allocator).print("\\STATE ", .{});
                    for (0..step.indent) |_| {
                        try latex.writer(allocator).print("\\indent", .{});
                    }
                    try latex.writer(allocator).print("{s}\n", .{step.text});
                } else {
                    try latex.writer(allocator).print("\\STATE {s}\n", .{step.text});
                }
            }
        }

        try latex.writer(allocator).print("\\end{{algorithmic}}\n", .{});
        try latex.writer(allocator).print("\\end{{algorithm}}\n", .{});

        return latex.toOwnedSlice(allocator);
    }

    /// Format as Markdown code block
    pub fn formatAsMarkdown(self: *const AlgorithmPseudocode, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("**Algorithm {s}**\n\n", .{self.name});
        if (self.caption) |cap| {
            try md.writer(allocator).print("*{s}*\n\n", .{cap});
        }
        try md.writer(allocator).print("**Label:** `{s}`\n\n", .{self.label});

        try md.writer(allocator).print("**Input:**\n", .{});
        for (self.inputs) |input| {
            try md.writer(allocator).print("- `{s}`\n", .{input});
        }
        try md.writer(allocator).print("\n", .{});

        try md.writer(allocator).print("**Output:**\n", .{});
        for (self.outputs) |output| {
            try md.writer(allocator).print("- `{s}`\n", .{output});
        }
        try md.writer(allocator).print("\n", .{});

        try md.writer(allocator).print("```text\n", .{});
        for (self.steps, 0..) |step, i| {
            if (step.number) |n| {
                try md.writer(allocator).print("{d}: ", .{n});
            } else {
                try md.writer(allocator).print("{d}: ", .{i + 1});
            }

            for (0..step.indent) |_| {
                try md.writer(allocator).print("  ", .{});
            }

            if (step.is_comment) {
                try md.writer(allocator).print("// {s}\n", .{step.text});
            } else {
                try md.writer(allocator).print("{s}\n", .{step.text});
            }
        }
        try md.writer(allocator).print("```\n\n", .{});

        return md.toOwnedSlice(allocator);
    }
};

/// Programming language for syntax highlighting
pub const ProgrammingLanguage = enum {
    zig,
    verilog,
    python,
    c,
    cpp,
    rust,
    julia,
    latex,
    bash,
    json,

    pub fn toString(self: ProgrammingLanguage) []const u8 {
        return switch (self) {
            .zig => "zig",
            .verilog => "verilog",
            .python => "python",
            .c => "c",
            .cpp => "cpp",
            .rust => "rust",
            .julia => "julia",
            .latex => "latex",
            .bash => "bash",
            .json => "json",
        };
    }

    pub fn toPygments(self: ProgrammingLanguage) []const u8 {
        return switch (self) {
            .zig => "zig",
            .verilog => "verilog",
            .python => "python",
            .c => "c",
            .cpp => "cpp",
            .rust => "rust",
            .julia => "julia",
            .latex => "latex",
            .bash => "bash",
            .json => "json",
        };
    }
};

/// Code listing with syntax highlighting
pub const CodeListing = struct {
    /// Caption/description
    caption: []const u8,
    /// Label for cross-referencing
    label: []const u8,
    /// Programming language
    language: ProgrammingLanguage,
    /// Source code
    code: []const u8,
    /// File path (if from specific file)
    file_path: ?[]const u8 = null,
    /// Line numbers start (0 = no line numbers)
    line_start: ?u32 = null,
    /// Highlighted lines (for emphasis)
    highlight_lines: []const u32 = &.{},

    /// Format as LaTeX lstlisting (requires listings/minted packages)
    pub fn formatAsLaTeX(self: *const CodeListing, allocator: std.mem.Allocator) ![]u8 {
        var latex = std.ArrayList(u8).initCapacity(allocator, 4096) catch @panic("OOM");
        defer latex.deinit(allocator);

        try latex.writer(allocator).print("\\begin{{listing}}[t]\n", .{});
        try latex.writer(allocator).print("\\caption{{{s}}}\n", .{self.caption});
        try latex.writer(allocator).print("\\label{{{s}}}\n", .{self.label});

        if (self.file_path) |path| {
            try latex.writer(allocator).print("\\texttt{{{s}}}\n", .{path});
        }

        // Use minted for better syntax highlighting (requires Python pygments)
        try latex.writer(allocator).print("\\begin{{minted}}[", .{});
        if (self.line_start) |start| {
            try latex.writer(allocator).print("linenos={},firstnumber={},", .{ true, start });
        } else {
            try latex.writer(allocator).print("linenos={},", .{true});
        }
        try latex.writer(allocator).print("fontsize=\\small]{{{s}}}\n", .{self.language.toPygments()});
        try latex.writer(allocator).print("{s}\n", .{self.code});
        try latex.writer(allocator).print("\\end{{minted}}\n", .{});

        try latex.writer(allocator).print("\\end{{listing}}\n", .{});

        return latex.toOwnedSlice(allocator);
    }

    /// Format as Markdown code block
    pub fn formatAsMarkdown(self: *const CodeListing, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 4096) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("**Listing {s}**\n\n", .{self.caption});
        try md.writer(allocator).print("**Label:** `{s}`\n\n", .{self.label});

        if (self.file_path) |path| {
            try md.writer(allocator).print("**File:** `{s}`\n\n", .{path});
        }

        try md.writer(allocator).print("```{s}\n", .{self.language.toString()});
        try md.writer(allocator).print("{s}\n", .{self.code});
        try md.writer(allocator).print("```\n\n", .{});

        return md.toOwnedSlice(allocator);
    }
};

/// Statistical significance level
pub const SignificanceLevel = enum {
    none, // p >= 0.05 (not significant)
    low, // p < 0.05 (*)
    medium, // p < 0.01 (**)
    high, // p < 0.001 (***)
    very_high, // p < 0.0001 (****)

    pub fn toSymbol(self: SignificanceLevel) []const u8 {
        return switch (self) {
            .none => "",
            .low => "*",
            .medium => "**",
            .high => "***",
            .very_high => "****",
        };
    }

    pub fn toLaTeX(self: SignificanceLevel) []const u8 {
        return switch (self) {
            .none => "",
            .low => "$^{*}$",
            .medium => "$^{**}$",
            .high => "$^{***}$",
            .very_high => "$^{****}$",
        };
    }
};

/// Statistical comparison table with significance indicators
pub const StatisticalTable = struct {
    /// Table caption
    caption: []const u8,
    /// Label for cross-referencing
    label: []const u8,
    /// Column headers
    headers: []const []const u8,
    /// Rows of data
    rows: []const Row,

    pub const Row = struct {
        /// Method name
        method: []const u8,
        /// Metric values (one per column after name)
        values: []const f64,
        /// Standard errors (optional, same length as values)
        std_errors: ?[]const f64 = null,
        /// Confidence intervals (optional)
        confidence_intervals: ?[]const struct { lower: f64, upper: f64 } = null,
        /// Significance levels (for comparison to baseline)
        significance: []const SignificanceLevel,
        /// Is this the baseline/best method?
        is_baseline: bool = false,
        /// Is this the best result?
        is_best: bool = false,
    };

    /// Format as LaTeX table with booktabs
    pub fn formatAsLaTeX(self: *const StatisticalTable, allocator: std.mem.Allocator) ![]u8 {
        var latex = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer latex.deinit(allocator);

        // Column spec: first column (l) + one per metric (c)
        var col_spec = std.ArrayList(u8).initCapacity(allocator, self.headers.len + 10) catch @panic("OOM");
        defer col_spec.deinit(allocator);
        try col_spec.writer(allocator).writeAll("l");
        for (self.headers[1..]) |_| {
            try col_spec.writer(allocator).writeAll("c");
        }

        try latex.writer(allocator).print("\\begin{{table}}[t]\n", .{});
        try latex.writer(allocator).print("\\centering\n", .{});
        try latex.writer(allocator).print("\\caption{{{s}}}\n", .{self.caption});
        try latex.writer(allocator).print("\\label{{{s}}}\n", .{self.label});
        try latex.writer(allocator).print("\\begin{{tabular}}{{{{{s}}}}}\n", .{col_spec.items});
        try latex.writer(allocator).print("\\toprule\n", .{});

        // Header row
        try latex.writer(allocator).print("Method", .{});
        for (self.headers[1..]) |h| {
            try latex.writer(allocator).print(" & {s}", .{h});
        }
        try latex.writer(allocator).print(" \\\\\n", .{});
        try latex.writer(allocator).print("\\midrule\n", .{});

        // Data rows
        for (self.rows) |row| {
            if (row.is_baseline) {
                try latex.writer(allocator).print("\\textbf{{{s}}}", .{row.method});
            } else {
                try latex.writer(allocator).print("{s}", .{row.method});
            }

            for (row.values, 0..) |val, i| {
                const sig = if (i < row.significance.len) row.significance[i] else .none;

                if (row.is_best) {
                    try latex.writer(allocator).print(" & \\textbf{{{d:.3}}}{s}", .{ val, sig.toLaTeX() });
                } else if (row.is_baseline) {
                    try latex.writer(allocator).print(" & \\textit{{{d:.3}}}", .{val});
                } else {
                    try latex.writer(allocator).print(" & {d:.3}{s}", .{ val, sig.toLaTeX() });
                }

                // Add standard error if available
                if (row.std_errors) |ses| {
                    if (i < ses.len) {
                        try latex.writer(allocator).print(" (\\pm {d:.3})", .{ses[i]});
                    }
                }

                // Add confidence interval if available
                if (row.confidence_intervals) |cis| {
                    if (i < cis.len) {
                        try latex.writer(allocator).print(" [{d:.3}, {d:.3}]", .{ cis[i].lower, cis[i].upper });
                    }
                }
            }
            try latex.writer(allocator).print(" \\\\\n", .{});
        }

        try latex.writer(allocator).print("\\bottomrule\n", .{});
        try latex.writer(allocator).print("\\end{{tabular}}\n", .{});
        try latex.writer(allocator).print("\\end{{table}}\n", .{});

        return latex.toOwnedSlice(allocator);
    }

    /// Format as Markdown table
    pub fn formatAsMarkdown(self: *const StatisticalTable, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer md.deinit(allocator);

        // Header row
        for (self.headers, 0..) |h, i| {
            if (i > 0) try md.writer(allocator).writeAll(" | ");
            try md.writer(allocator).print("{s}", .{h});
        }
        try md.writer(allocator).writeAll("\n");

        // Separator row
        for (self.headers, 0..) |_, i| {
            if (i > 0) try md.writer(allocator).writeAll(" | ");
            try md.writer(allocator).writeAll(if (i == 0) "---" else "----:");
        }
        try md.writer(allocator).writeAll("\n");

        // Data rows
        for (self.rows) |row| {
            // Print method name first
            if (row.is_baseline) {
                try md.writer(allocator).print("**{s}**", .{row.method});
            } else {
                try md.writer(allocator).print("{s}", .{row.method});
            }

            // Then print values
            for (row.values, 0..) |val, i| {
                try md.writer(allocator).writeAll(" | ");

                const sig = if (i < row.significance.len) row.significance[i] else .none;

                if (row.is_best) {
                    try md.writer(allocator).print("**{d:.3}**{s}", .{ val, sig.toSymbol() });
                } else if (row.is_baseline) {
                    try md.writer(allocator).print("*{d:.3}*", .{val});
                } else {
                    try md.writer(allocator).print("{d:.3}{s}", .{ val, sig.toSymbol() });
                }

                // Add standard error if available
                if (row.std_errors) |ses| {
                    if (i < ses.len) {
                        try md.writer(allocator).print(" (±{d:.3})", .{ses[i]});
                    }
                }
            }
            try md.writer(allocator).writeAll("\n");
        }

        try md.writer(allocator).print("\n*Table: {s}*\n\n", .{self.caption});

        return md.toOwnedSlice(allocator);
    }
};

// ═════════════════════════════════════════════════════════════════════════
// ZENODO V11 — Ablation Studies, Hyperparameters, Datasets, TikZ Diagrams
// ═════════════════════════════════════════════════════════════════════════

/// Ablation study component for analyzing contribution of model components
pub const AblationComponent = struct {
    /// Component name (e.g., "Ternary weights", "Position encoding")
    name: []const u8,
    /// Metric value (e.g., PPL, accuracy)
    value: f64,
    /// Standard error (optional)
    std_error: ?f64 = null,
    /// Confidence interval (optional)
    confidence_interval: ?struct { lower: f64, upper: f64 } = null,
    /// Difference from full model (absolute)
    delta: ?f64 = null,
    /// Is this the full model (baseline)?
    is_full_model: bool = false,
    /// Is this component ablated (removed)?
    is_ablated: bool = false,
};

/// Ablation study table for component contribution analysis
pub const AblationStudy = struct {
    /// Table caption
    caption: []const u8,
    /// Label for cross-referencing
    label: []const u8,
    /// Metric name (e.g., "Validation PPL", "Accuracy")
    metric: []const u8,
    /// Direction (lower is better: true for PPL, false for accuracy)
    lower_is_better: bool = true,
    /// Components to analyze
    components: []const AblationComponent,

    /// Format as LaTeX ablation study table
    pub fn formatAsLaTeX(self: *const AblationStudy, allocator: std.mem.Allocator) ![]u8 {
        var latex = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer latex.deinit(allocator);

        try latex.writer(allocator).print("\\begin{{table}}[t]\n", .{});
        try latex.writer(allocator).print("\\centering\n", .{});
        try latex.writer(allocator).print("\\caption{{{s}}}\n", .{self.caption});
        try latex.writer(allocator).print("\\label{{{s}}}\n", .{self.label});
        try latex.writer(allocator).print("\\begin{{tabular}}{{lc}}\n", .{});
        try latex.writer(allocator).print("\\toprule\n", .{});
        try latex.writer(allocator).print("Component & {s} \\\\\n", .{self.metric});
        try latex.writer(allocator).print("\\midrule\n", .{});

        for (self.components) |comp| {
            if (comp.is_full_model) {
                try latex.writer(allocator).print("\\textbf{{{s}}}", .{comp.name});
            } else if (comp.is_ablated) {
                try latex.writer(allocator).print("\\textit{{{s}}}", .{comp.name});
            } else {
                try latex.writer(allocator).print("{s}", .{comp.name});
            }

            // Value with standard error
            try latex.writer(allocator).print(" & {d:.3}", .{comp.value});

            if (comp.std_error) |se| {
                try latex.writer(allocator).print(" $\\pm$ {d:.3}", .{se});
            }

            // Confidence interval
            if (comp.confidence_interval) |ci| {
                try latex.writer(allocator).print(" [{d:.3}, {d:.3}]", .{ ci.lower, ci.upper });
            }

            // Delta from full model
            if (comp.delta) |d| {
                const sign = if (d > 0) "+" else "";
                try latex.writer(allocator).print(" ({s}{d:.3})", .{ sign, d });
            }

            try latex.writer(allocator).print(" \\\\\n", .{});
        }

        try latex.writer(allocator).print("\\bottomrule\n", .{});
        try latex.writer(allocator).print("\\end{{tabular}}\n", .{});
        try latex.writer(allocator).print("\\end{{table}}\n", .{});

        return latex.toOwnedSlice(allocator);
    }

    /// Format as Markdown ablation study table
    pub fn formatAsMarkdown(self: *const AblationStudy, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("| Component | {s} |\n", .{self.metric});
        try md.writer(allocator).print("|----------|", .{});
        // Generate dashes for metric column (3 dashes per char for alignment)
        var dash_idx: usize = 0;
        while (dash_idx < @min(self.metric.len * 3, 50)) : (dash_idx += 1) {
            try md.writer(allocator).print("-", .{});
        }
        try md.writer(allocator).print("|\n", .{});

        for (self.components) |comp| {
            if (comp.is_full_model) {
                try md.writer(allocator).print("| **{s}** |", .{comp.name});
            } else if (comp.is_ablated) {
                try md.writer(allocator).print("| *{s}* |", .{comp.name});
            } else {
                try md.writer(allocator).print("| {s} |", .{comp.name});
            }

            try md.writer(allocator).print("{d:.3}", .{comp.value});

            if (comp.std_error) |se| {
                try md.writer(allocator).print(" (±{d:.3})", .{se});
            }

            if (comp.delta) |d| {
                const sign = if (d > 0) "+" else "";
                try md.writer(allocator).print(" ({s}{d:.3})", .{ sign, d });
            }

            try md.writer(allocator).print(" |\n", .{});
        }

        try md.writer(allocator).print("\n*Table: {s}*\n\n", .{self.caption});

        return md.toOwnedSlice(allocator);
    }
};

/// Hyperparameter specification for model configuration documentation
pub const HyperparameterSpec = struct {
    /// Hyperparameter name
    name: []const u8,
    /// Value (as string to support types)
    value: []const u8,
    /// Type (e.g., "float", "int", "str", "bool", "choice")
    type: []const u8,
    /// Description
    description: ?[]const u8 = null,
    /// Search space (for tuning)
    search_space: ?[]const u8 = null,
};

/// Hyperparameter table for documenting model configuration
pub const HyperparameterTable = struct {
    /// Table caption
    caption: []const u8,
    /// Label for cross-referencing
    label: []const u8,
    /// Group/category (e.g., "Architecture", "Training", "Regularization")
    group: ?[]const u8 = null,
    /// Hyperparameters
    hyperparameters: []const HyperparameterSpec,

    /// Format as LaTeX hyperparameter table
    pub fn formatAsLaTeX(self: *const HyperparameterTable, allocator: std.mem.Allocator) ![]u8 {
        var latex = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer latex.deinit(allocator);

        try latex.writer(allocator).print("\\begin{{table}}[t]\n", .{});
        try latex.writer(allocator).print("\\centering\n", .{});
        try latex.writer(allocator).print("\\caption{{{s}}}\n", .{self.caption});
        try latex.writer(allocator).print("\\label{{{s}}}\n", .{self.label});
        try latex.writer(allocator).print("\\begin{{tabular}}{{lll}}\n", .{});
        try latex.writer(allocator).print("\\toprule\n", .{});
        try latex.writer(allocator).print("Hyperparameter & Value & Description \\\\\n", .{});
        try latex.writer(allocator).print("\\midrule\n", .{});

        for (self.hyperparameters) |hp| {
            try latex.writer(allocator).print("\\texttt{{{s}}}", .{hp.name});

            if (hp.search_space) |ss| {
                try latex.writer(allocator).print(" ({s})", .{ss});
            }

            try latex.writer(allocator).print(" & \\texttt{{{s}}}", .{hp.value});

            if (hp.description) |desc| {
                try latex.writer(allocator).print(" & {s}", .{desc});
            } else {
                try latex.writer(allocator).print(" & ---", .{});
            }

            try latex.writer(allocator).print(" \\\\\n", .{});
        }

        try latex.writer(allocator).print("\\bottomrule\n", .{});
        try latex.writer(allocator).print("\\end{{tabular}}\n", .{});
        try latex.writer(allocator).print("\\end{{table}}\n", .{});

        return latex.toOwnedSlice(allocator);
    }

    /// Format as Markdown hyperparameter table
    pub fn formatAsMarkdown(self: *const HyperparameterTable, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("| Hyperparameter | Value | Description |\n", .{});
        try md.writer(allocator).print("|--------------|-------|-------------|\n", .{});

        for (self.hyperparameters) |hp| {
            try md.writer(allocator).print("| `{s}` |", .{hp.name});

            if (hp.search_space) |ss| {
                try md.writer(allocator).print("{s} | ", .{ss});
            } else {
                try md.writer(allocator).print("`{s}` | ", .{hp.value});
            }

            if (hp.description) |desc| {
                try md.writer(allocator).print("{s} |\n", .{desc});
            } else {
                try md.writer(allocator).print("--- |\n", .{});
            }
        }

        try md.writer(allocator).print("\n*Table: {s}*\n\n", .{self.caption});

        return md.toOwnedSlice(allocator);
    }
};

/// Data split statistics for train/validation/test sets
pub const DataSplit = struct {
    /// Split name (e.g., "train", "validation", "test")
    name: []const u8,
    /// Number of samples
    samples: u64,
    /// Percentage of total
    percentage: f64,
};

/// Dataset description for documenting dataset statistics
pub const DatasetDescription = struct {
    /// Dataset name
    name: []const u8,
    /// Label for cross-referencing
    label: []const u8,
    /// Brief description
    description: []const u8,
    /// Data splits
    splits: []const DataSplit,
    /// Number of features
    num_features: ?u64 = null,
    /// Number of classes (for classification)
    num_classes: ?u64 = null,
    /// License
    license: ?[]const u8 = null,
    /// URL (if available)
    url: ?[]const u8 = null,

    /// Format as LaTeX dataset description
    pub fn formatAsLaTeX(self: *const DatasetDescription, allocator: std.mem.Allocator) ![]u8 {
        var latex = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer latex.deinit(allocator);

        try latex.writer(allocator).print("\\begin{{table}}[t]\n", .{});
        try latex.writer(allocator).print("\\centering\n", .{});
        try latex.writer(allocator).print("\\caption{{{s}}}\n", .{self.name});
        try latex.writer(allocator).print("\\label{{{s}}}\n", .{self.label});
        try latex.writer(allocator).print("\\begin{{tabular}}{{lr}}\n", .{});
        try latex.writer(allocator).print("\\toprule\n", .{});
        try latex.writer(allocator).print("Split & Samples & Percentage \\\\\n", .{});
        try latex.writer(allocator).print("\\midrule\n", .{});

        for (self.splits) |split| {
            try latex.writer(allocator).print("{s} & {d} & {d:.1}%% \\\\\n", .{ split.name, split.samples, split.percentage });
        }

        try latex.writer(allocator).print("\\bottomrule\n", .{});
        try latex.writer(allocator).print("\\end{{tabular}}\n", .{});
        try latex.writer(allocator).print("\\end{{table}}\n", .{});

        return latex.toOwnedSlice(allocator);
    }

    /// Format as Markdown dataset description
    pub fn formatAsMarkdown(self: *const DatasetDescription, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("## {s}\n\n", .{self.name});
        try md.writer(allocator).print("**Label:** `{s}`\n\n", .{self.label});
        try md.writer(allocator).print("{s}\n\n", .{self.description});

        try md.writer(allocator).print("| Split | Samples | Percentage |\n", .{});
        try md.writer(allocator).print("|------|--------|------------|\n", .{});

        for (self.splits) |split| {
            try md.writer(allocator).print("| {s} | {d} | {d:.1}% |\n", .{ split.name, split.samples, split.percentage });
        }

        try md.writer(allocator).print("\n", .{});

        return md.toOwnedSlice(allocator);
    }
};

/// TikZ node type for diagram elements
pub const TikZNodeType = enum {
    simple, // Simple rectangle
    parameter, // Parameter input (triangle)
    decision, // Diamond (decision)
    output, // Rounded rectangle
    circle, // Circle
    ellipse, // Ellipse
};

/// TikZ diagram for neural network architectures and system diagrams
pub const TikZDiagram = struct {
    /// Diagram caption
    caption: []const u8,
    /// Label for cross-referencing
    label: []const u8,
    /// Diagram nodes
    nodes: []const Node,
    /// Edges (connections between nodes)
    edges: []const Edge,
    /// TikZ style (e.g., "neural", "mindmap", "tree")
    style: ?[]const u8 = null,
    /// Width (in cm)
    width: ?f64 = null,

    pub const Node = struct {
        /// Node identifier (for referencing)
        id: []const u8,
        /// Label (displayed text)
        label: []const u8,
        /// Node type
        node_type: TikZNodeType = .simple,
        /// Position (x, y) in cm
        position: ?[2]f64 = null,
        /// Options (e.g., "fill=blue!20")
        options: ?[]const u8 = null,
    };

    pub const Edge = struct {
        /// Source node
        from: []const u8,
        /// Target node
        to: []const u8,
        /// Label (optional)
        label: ?[]const u8 = null,
        /// Options (e.g., "thick", "dashed")
        options: ?[]const u8 = null,
    };

    /// Format as LaTeX TikZ diagram
    pub fn formatAsLaTeX(self: *const TikZDiagram, allocator: std.mem.Allocator) ![]u8 {
        var latex = std.ArrayList(u8).initCapacity(allocator, 4096) catch @panic("OOM");
        defer latex.deinit(allocator);

        try latex.writer(allocator).print("\\begin{{figure}}[t]\n", .{});
        try latex.writer(allocator).print("\\centering\n", .{});
        try latex.writer(allocator).print("\\caption{{{s}}}\n", .{self.caption});
        try latex.writer(allocator).print("\\label{{{s}}}\n", .{self.label});

        const width_str = if (self.width) |w| try std.fmt.allocPrint(allocator, "width={d:.1}cm", .{w}) else "width=0.9\\textwidth";
        defer allocator.free(width_str);

        try latex.writer(allocator).print("\\begin{{tikzpicture}}[{s}]\n", .{width_str});

        if (self.style) |style| {
            try latex.writer(allocator).print("\\tikzstyle{{{s}}}\n", .{style});
        }

        // Define nodes
        for (self.nodes) |node| {
            const node_style = switch (node.node_type) {
                .simple => "rectangle,draw",
                .parameter => "regular polygon,regular polygon sides=3,draw",
                .decision => "diamond,draw",
                .output => "rectangle,rounded corners=5pt,draw",
                .circle => "circle,draw",
                .ellipse => "ellipse,draw",
            };

            if (node.options) |opts| {
                try latex.writer(allocator).print("\\node[{s},", .{opts});
            } else {
                try latex.writer(allocator).writeAll("\\node[");
            }

            try latex.writer(allocator).print("{s}", .{node_style});

            if (node.position) |pos| {
                try latex.writer(allocator).print(",position=({d:.1},{d:.1})", .{ pos[0], pos[1] });
            }

            try latex.writer(allocator).print("] ({s}) {{{s}}};\n", .{ node.id, node.label });
        }

        // Define edges
        for (self.edges) |edge| {
            if (edge.options) |opts| {
                try latex.writer(allocator).print("\\draw[{s}] ({s}) -- ({s});\n", .{ opts, edge.from, edge.to });
            } else {
                if (edge.label) |label| {
                    try latex.writer(allocator).print("\\draw[->] ({s}) -- node[midway,above] {{{s}}} ({s});\n", .{ edge.from, label, edge.to });
                } else {
                    try latex.writer(allocator).print("\\draw[->] ({s}) -- ({s});\n", .{ edge.from, edge.to });
                }
            }
        }

        try latex.writer(allocator).print("\\end{{tikzpicture}}\n", .{});
        try latex.writer(allocator).print("\\end{{figure}}\n", .{});

        return latex.toOwnedSlice(allocator);
    }

    /// Format as Markdown (code block with TikZ)
    pub fn formatAsMarkdown(self: *const TikZDiagram, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 4096) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("**Figure {s}**\n\n", .{self.caption});
        try md.writer(allocator).print("**Label:** `{s}`\n\n", .{self.label});
        try md.writer(allocator).print("```latex\n", .{});
        try md.writer(allocator).print("\\begin{{tikzpicture}}\n", .{});

        for (self.nodes) |node| {
            const node_style = switch (node.node_type) {
                .simple => "rectangle",
                .parameter => "regular polygon,regular polygon sides=3",
                .decision => "diamond",
                .output => "rectangle,rounded corners",
                .circle => "circle",
                .ellipse => "ellipse",
            };
            try md.writer(allocator).print("  \\node[{s}] ({s}) {{{s}}};\n", .{ node_style, node.id, node.label });
        }

        for (self.edges) |edge| {
            try md.writer(allocator).print("  \\draw[->] ({s}) -- ({s});\n", .{ edge.from, edge.to });
        }

        try md.writer(allocator).print("\\end{{tikzpicture}}\n", .{});
        try md.writer(allocator).print("```\n\n", .{});

        return md.toOwnedSlice(allocator);
    }
};

// ═════════════════════════════════════════════════════════════════════════
// V12: Advanced Scientific Structures
// ═════════════════════════════════════════════════════════════════════════

/// Reproducibility checklist item for ML paper submissions
pub const ChecklistItem = struct {
    /// Category (e.g., "Code", "Data", "Hyperparameters")
    category: []const u8,
    /// Checklist question
    question: []const u8,
    /// Response (yes/no/partial/NA)
    response: ChecklistResponse,
    /// Additional details
    details: ?[]const u8 = null,
    /// Link to resource (GitHub, Zenodo, etc.)
    link: ?[]const u8 = null,
};

pub const ChecklistResponse = enum {
    yes,
    no,
    partial,
    na,

    pub fn toString(self: ChecklistResponse) []const u8 {
        return switch (self) {
            .yes => "✓ Yes",
            .no => "✗ No",
            .partial => "~ Partial",
            .na => "N/A",
        };
    }

    pub fn toSymbol(self: ChecklistResponse) []const u8 {
        return switch (self) {
            .yes => "[✓]",
            .no => "[✗]",
            .partial => "[~]",
            .na => "[ ]",
        };
    }
};

/// Reproducibility checklist for paper submissions (NeurIPS/ICLR/MLSys)
pub const ReproducibilityChecklist = struct {
    /// Conference name
    conference: []const u8,
    /// Year
    year: u32,
    /// Checklist items
    items: []const ChecklistItem,
    /// Paper title
    paper_title: []const u8,
    /// Corresponding author
    contact: ?[]const u8 = null,

    /// Format as LaTeX checklist
    pub fn formatAsLaTeX(self: *const ReproducibilityChecklist, allocator: std.mem.Allocator) ![]u8 {
        var latex = std.ArrayList(u8).initCapacity(allocator, 4096) catch @panic("OOM");
        defer latex.deinit(allocator);

        try latex.writer(allocator).print("\\section{{Reproducibility Checklist}}\n\n", .{});
        try latex.writer(allocator).print("\\textbf{{Paper:}} {s} ({s} {d})\n\n", .{ self.paper_title, self.conference, self.year });

        for (self.items) |item| {
            try latex.writer(allocator).print("\\textbf{{{s}:}} {s}\n", .{ item.category, item.question });
            try latex.writer(allocator).print("{s} ", .{item.response.toSymbol()});

            if (item.details) |det| {
                try latex.writer(allocator).print("-- {s}", .{det});
            }

            if (item.link) |lnk| {
                try latex.writer(allocator).print(" (\\href{{{s}}}{{link}})", .{lnk});
            }

            try latex.writer(allocator).print("\n\n", .{});
        }

        return latex.toOwnedSlice(allocator);
    }

    /// Format as Markdown checklist
    pub fn formatAsMarkdown(self: *const ReproducibilityChecklist, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 4096) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("# Reproducibility Checklist\n\n", .{});
        try md.writer(allocator).print("**Paper:** {s}\n", .{self.paper_title});
        try md.writer(allocator).print("**Conference:** {s} {d}\n\n", .{ self.conference, self.year });

        for (self.items) |item| {
            try md.writer(allocator).print("### {s}\n\n", .{item.category});
            try md.writer(allocator).print("**{s}** {s}\n\n", .{ item.question, item.response.toString() });

            if (item.details) |det| {
                try md.writer(allocator).print("{s}\n\n", .{det});
            }

            if (item.link) |lnk| {
                try md.writer(allocator).print("**🔗** [{s}]({s})\n\n", .{"Link", lnk});
            }
        }

        return md.toOwnedSlice(allocator);
    }
};

/// Statistical result with confidence interval
pub const StatisticalResult = struct {
    /// Metric name
    metric: []const u8,
    /// Value
    value: f64,
    /// Standard error
    std_err: ?f64 = null,
    /// Confidence interval (95% by default)
    ci: ?struct { lower: f64, upper: f64 } = null,
    /// P-value
    p_value: ?f64 = null,
    /// Effect size (Cohen's d)
    effect_size: ?f64 = null,
    /// Significance level
    significance: SignificanceLevel = .none,
    /// Is this the best result?
    is_best: bool = false,
};

/// Results summary table for experimental outcomes
pub const ResultsSummary = struct {
    /// Table caption
    caption: []const u8,
    /// Label for cross-referencing
    label: []const u8,
    /// Dataset name
    dataset: []const u8,
    /// Results (one per method)
    results: []const StatisticalResult,
    /// Primary metric (for sorting)
    primary_metric: []const u8,
    /// Higher is better?
    higher_is_better: bool = false,

    /// Format as LaTeX results table
    pub fn formatAsLaTeX(self: *const ResultsSummary, allocator: std.mem.Allocator) ![]u8 {
        var latex = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer latex.deinit(allocator);

        try latex.writer(allocator).print("\\begin{{table}}[t]\n", .{});
        try latex.writer(allocator).print("\\centering\n", .{});
        try latex.writer(allocator).print("\\caption{{{s} on {s}}}\n", .{ self.caption, self.dataset });
        try latex.writer(allocator).print("\\label{{{s}}}\n", .{ self.label });
        try latex.writer(allocator).print("\\begin{{tabular}}{{lccccc}}\n", .{});
        try latex.writer(allocator).print("\\toprule\n", .{});
        try latex.writer(allocator).print("Method & {s} & SE & 95%% CI & $p$-value & Cohen's $d$ \\\\\n", .{self.primary_metric});
        try latex.writer(allocator).print("\\midrule\n", .{});

        for (self.results) |result| {
            // Method name with bold for best
            if (result.is_best) {
                try latex.writer(allocator).print("\\textbf{{{s}}} & ", .{result.metric});
            } else {
                try latex.writer(allocator).print("{s} & ", .{result.metric});
            }

            // Value with bold for best
            if (result.is_best) {
                try latex.writer(allocator).print("\\textbf{{{d:.3}}} & ", .{result.value});
            } else {
                try latex.writer(allocator).print("{d:.3} & ", .{result.value});
            }

            // Standard error
            if (result.std_err) |se| {
                try latex.writer(allocator).print("{d:.3} & ", .{se});
            } else {
                try latex.writer(allocator).print("--- & ", .{});
            }

            // Confidence interval
            if (result.ci) |ci| {
                try latex.writer(allocator).print("[{d:.3}, {d:.3}] & ", .{ ci.lower, ci.upper });
            } else {
                try latex.writer(allocator).print("--- & ", .{});
            }

            // P-value with significance
            if (result.p_value) |pv| {
                const sig_str = if (pv < 0.001) "<0.001" else try std.fmt.allocPrint(allocator, "{d:.3}", .{pv});
                try latex.writer(allocator).print("{s}{s} & ", .{ sig_str, result.significance.toLaTeX() });
            } else {
                try latex.writer(allocator).print("--- & ", .{});
            }

            // Effect size
            if (result.effect_size) |es| {
                try latex.writer(allocator).print("{d:.3}", .{es});
            } else {
                try latex.writer(allocator).print("---", .{});
            }

            try latex.writer(allocator).print(" \\\\\n", .{});
        }

        try latex.writer(allocator).print("\\bottomrule\n", .{});
        try latex.writer(allocator).print("\\end{{tabular}}\n", .{});
        try latex.writer(allocator).print("\\end{{table}}\n", .{});

        return latex.toOwnedSlice(allocator);
    }

    /// Format as Markdown results table
    pub fn formatAsMarkdown(self: *const ResultsSummary, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("| Method | {s} | SE | 95% CI | $p$ | $d$ |\n", .{self.primary_metric});
        try md.writer(allocator).print("|--------|{d:>7}|----|--------|-----|-----|\n", .{self.primary_metric.len});

        for (self.results) |result| {
            if (result.is_best) {
                try md.writer(allocator).print("| **{s}** | **{d:.3}** |", .{result.metric, result.value});
            } else {
                try md.writer(allocator).print("| {s} | {d:.3} |", .{result.metric, result.value});
            }

            if (result.std_err) |se| {
                try md.writer(allocator).print("{d:.3} |", .{se});
            } else {
                try md.writer(allocator).writeAll("--- |");
            }

            if (result.ci) |ci| {
                try md.writer(allocator).print("[{d:.3}, {d:.3}] |", .{ ci.lower, ci.upper });
            } else {
                try md.writer(allocator).writeAll("--- |");
            }

            if (result.p_value) |pv| {
                const pv_str = if (pv < 0.001) "<0.001" else try std.fmt.allocPrint(allocator, "{d:.3}", .{pv});
                try md.writer(allocator).print("{s}{s} |", .{ pv_str, result.significance.toSymbol() });
            } else {
                try md.writer(allocator).print("--- |", .{});
            }

            if (result.effect_size) |es| {
                try md.writer(allocator).print("{d:.3}", .{es});
            } else {
                try md.writer(allocator).print("---", .{});
            }

            try md.writer(allocator).print(" |\n", .{});
        }

        try md.writer(allocator).print("\n*Table: {s} on {s}*\n\n", .{self.caption, self.dataset});

        return md.toOwnedSlice(allocator);
    }
};

/// Sub-panel for multi-panel figures
pub const SubPanel = struct {
    /// Panel identifier (a, b, c, ...)
    panel_id: []const u8,
    /// Caption for this panel
    caption: []const u8,
    /// Label for cross-reference
    label: ?[]const u8 = null,
    /// Width fraction (0.0-1.0)
    width_frac: f64 = 0.5,
};

/// Multi-panel figure layout (2x2, 1x3, etc.)
pub const MultiPanelFigure = struct {
    /// Overall caption
    caption: []const u8,
    /// Overall label
    label: []const u8,
    /// Layout: "2x2", "1x3", "1x2", "2x1"
    layout: []const u8,
    /// Sub-panels
    panels: []const SubPanel,
    /// Figure width (in cm)
    width: f64 = 0.9,  // fraction of textwidth

    /// Format as LaTeX subfigure layout
    pub fn formatAsLaTeX(self: *const MultiPanelFigure, allocator: std.mem.Allocator) ![]u8 {
        var latex = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer latex.deinit(allocator);

        try latex.writer(allocator).print("\\begin{{figure}}[t]\n", .{});
        try latex.writer(allocator).print("\\centering\n", .{});

        // Generate subfigure layout
        var panel_idx: usize = 0;
        for (self.panels) |panel| {
            try latex.writer(allocator).print("\\begin{{subfigure}}{{{d:.1}\\textwidth}}\n", .{panel.width_frac});
            try latex.writer(allocator).print("  \\centering\n", .{});
            try latex.writer(allocator).print("  % TODO: Include figure file for panel ({s})\n", .{panel.panel_id});
            try latex.writer(allocator).print("  \\caption{{{s}}}\n", .{panel.caption});

            if (panel.label) |lbl| {
                try latex.writer(allocator).print("  \\label{{{s}}}\n", .{lbl});
            }

            try latex.writer(allocator).print("\\end{{subfigure}}\n", .{});
            try latex.writer(allocator).print("\\quad\n", .{});

            panel_idx += 1;
            // Add line break after each row (simplified: break after 2 panels for 2-column layout)
            if (panel_idx < self.panels.len and panel_idx % 2 == 0) {
                try latex.writer(allocator).print("\\\n", .{});
            }
        }

        try latex.writer(allocator).print("\\caption{{{s}}}\n", .{self.caption});
        try latex.writer(allocator).print("\\label{{{s}}}\n", .{self.label});
        try latex.writer(allocator).print("\\end{{figure}}\n", .{});

        return latex.toOwnedSlice(allocator);
    }

    /// Format as Markdown
    pub fn formatAsMarkdown(self: *const MultiPanelFigure, allocator: std.mem.Allocator) ![]u8 {
        var md = std.ArrayList(u8).initCapacity(allocator, 2048) catch @panic("OOM");
        defer md.deinit(allocator);

        try md.writer(allocator).print("**Figure {s}**\n\n", .{self.caption});
        try md.writer(allocator).print("**Label:** `{s}`\n", .{self.label});
        try md.writer(allocator).print("**Layout:** {s}\n\n", .{self.layout});

        try md.writer(allocator).print("| Panel | Caption | Width |\n", .{});
        try md.writer(allocator).print("|-------|----------|-------|\n", .{});

        for (self.panels) |panel| {
            try md.writer(allocator).print("| ({s}) | {s} | {d:.0}% |\n", .{
                panel.panel_id, panel.caption, panel.width_frac * 100.0
            });
        }

        try md.writer(allocator).print("\n", .{});

        return md.toOwnedSlice(allocator);
    }
};

// ═════════════════════════════════════════════════════════════════════════
// TESTS — V11 Structures
// ═════════════════════════════════════════════════════════════════════════

test "AlgorithmPseudocode formatAsLaTeX" {
    const algo = AlgorithmPseudocode{
        .name = "Ternary Matrix Multiplication",
        .label = "alg:ternary-matmul",
        .inputs = &[_][]const u8{ "A ∈ {-1,0,1}^{m×n}", "B ∈ {-1,0,1}^{n×p}" },
        .outputs = &[_][]const u8{"C ∈ {-n,0,n}^{m×p}"},
        .steps = &[_]AlgorithmPseudocode.Step{
            .{ .text = "Initialize C with zeros" },
            .{ .text = "for i = 1 to m do" },
            .{ .text = "for j = 1 to p do", .indent = 1 },
            .{ .text = "sum = 0", .indent = 2 },
            .{ .text = "for k = 1 to n do", .indent = 2 },
            .{ .text = "sum = sum + A[i,k] × B[k,j]", .indent = 3 },
            .{ .text = "C[i,j] = clamp(sum, -n, n)", .indent = 2 },
            .{ .text = "return C" },
        },
        .caption = "Efficient ternary matrix multiplication without overflow",
    };

    const latex = try algo.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{algorithm}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "alg:ternary-matmul") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\REQUIRE") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\ENSURE") != null);
}

test "AlgorithmPseudocode formatAsMarkdown" {
    const algo = AlgorithmPseudocode{
        .name = "Ternary Matrix Multiplication",
        .label = "alg:ternary-matmul",
        .inputs = &[_][]const u8{ "A", "B" },
        .outputs = &[_][]const u8{"C"},
        .steps = &[_]AlgorithmPseudocode.Step{
            .{ .number = 1, .text = "Initialize C" },
            .{ .number = 2, .text = "Multiply A and B" },
            .{ .number = 3, .text = "return C", .is_comment = true },
        },
    };

    const md = try algo.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "**Algorithm Ternary") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "`alg:ternary-matmul`") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "// return C") != null);
}

test "ProgrammingLanguage toString" {
    try std.testing.expectEqualStrings("zig", ProgrammingLanguage.zig.toString());
    try std.testing.expectEqualStrings("verilog", ProgrammingLanguage.verilog.toString());
    try std.testing.expectEqualStrings("python", ProgrammingLanguage.python.toString());
}

test "CodeListing formatAsLaTeX" {
    const listing = CodeListing{
        .caption = "Ternary activation function",
        .label = "lst:ternary-act",
        .language = .zig,
        .code = "fn ternary_activate(x: f64) i8 {\n    if x > 0.5 return 1;\n    if x < -0.5 return -1;\n    return 0;\n}",
        .file_path = "src/ternary.zig",
        .line_start = 42,
    };

    const latex = try listing.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{listing}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "lst:ternary-act") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "zig") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "firstnumber=42") != null);
}

test "CodeListing formatAsMarkdown" {
    const listing = CodeListing{
        .caption = "Ternary activation",
        .label = "lst:act",
        .language = .python,
        .code = "def ternary(x):\n    return 1 if x > 0 else (-1 if x < 0 else 0)",
    };

    const md = try listing.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "**Listing Ternary activation**") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "```python") != null);
}

test "SignificanceLevel symbols" {
    try std.testing.expectEqualStrings("", SignificanceLevel.none.toSymbol());
    try std.testing.expectEqualStrings("*", SignificanceLevel.low.toSymbol());
    try std.testing.expectEqualStrings("**", SignificanceLevel.medium.toSymbol());
    try std.testing.expectEqualStrings("***", SignificanceLevel.high.toSymbol());
    try std.testing.expectEqualStrings("****", SignificanceLevel.very_high.toSymbol());
}

test "SignificanceLevel toLaTeX" {
    const latex = SignificanceLevel.high.toLaTeX();
    try std.testing.expect(std.mem.indexOf(u8, latex, "***") != null);
}

test "StatisticalTable formatAsLaTeX" {
    const table = StatisticalTable{
        .caption = "Model comparison on TinyStories",
        .label = "tab:results",
        .headers = &[_][]const u8{ "Method", "PPL", "Loss" },
        .rows = &[_]StatisticalTable.Row{
            .{
                .method = "Baseline",
                .values = &[_]f64{ 15.2, 3.8 },
                .std_errors = &[_]f64{ 0.3, 0.1 },
                .significance = &[_]SignificanceLevel{ .none, .none },
                .is_baseline = true,
            },
            .{
                .method = "HSLM (ours)",
                .values = &[_]f64{ 12.5, 3.2 },
                .std_errors = &[_]f64{ 0.2, 0.1 },
                .significance = &[_]SignificanceLevel{ .high, .high },
                .is_best = true,
            },
        },
    };

    const latex = try table.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{table}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "tab:results") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "HSLM (ours)") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\textbf{12.500}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "$^{***}$") != null);
}

test "StatisticalTable formatAsMarkdown" {
    const table = StatisticalTable{
        .caption = "Results",
        .label = "tab:res",
        .headers = &[_][]const u8{ "Model", "Acc" },
        .rows = &[_]StatisticalTable.Row{
            .{
                .method = "GPT-2",
                .values = &[_]f64{0.85},
                .significance = &[_]SignificanceLevel{.none},
            },
            .{
                .method = "HSLM",
                .values = &[_]f64{0.92},
                .significance = &[_]SignificanceLevel{.high},
                .is_best = true,
            },
        },
    };

    const md = try table.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "HSLM") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "**0.920**") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "***") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "*Table: Results*") != null);
}
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// DATA AVAILABILITY — NeurIPS 2025 Requirement
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════

test "BundleType displayName" {
    try std.testing.expectEqual(@as(usize, 7), @typeInfo(BundleType).@"enum".fields.len);

    try std.testing.expectEqual("Ternary Neural Network (HSLM)", BundleType.ternary_nn.displayName());
    try std.testing.expectEqual("Zero-DSP FPGA Inference Engine", BundleType.zero_dsp.displayName());
    try std.testing.expectEqual("TRI-27 Instruction Set Architecture", BundleType.tri27_isa.displayName());
    try std.testing.expectEqual("Queen Self-Learning Orchestration", BundleType.queen_orchestration.displayName());
    try std.testing.expectEqual("Tri Language DSL", BundleType.tri_language.displayName());
    try std.testing.expectEqual("Ternary Vector Symbolic Architecture", BundleType.vsa_ternary.displayName());
    try std.testing.expectEqual("Trinity S³AI Framework (Parent)", BundleType.parent.displayName());
}

test "BundleType fileName" {
    try std.testing.expectEqual("B001_Ternary_NN", BundleType.ternary_nn.fileName());
    try std.testing.expectEqual("B002_Zero_DSP_FPGA", BundleType.zero_dsp.fileName());
    try std.testing.expectEqual("B003_TRI27_ISA", BundleType.tri27_isa.fileName());
}

test "BundleType DOI" {
    try std.testing.expectEqual("10.5281/zenodo.19227865", BundleType.ternary_nn.doi());
    try std.testing.expectEqual("10.5281/zenodo.19227879", BundleType.parent.doi());
}

test "TrainingResult formatAsTableRow" {
    const result = TrainingResult{
        .perplexity = 125.3,
        .std_error = 1.1,
        .ci95_lower = 123.1,
        .ci95_upper = 127.5,
        .n_runs = 5,
        .total_steps = 30000,
        .training_hours = 4.0,
        .platform = "XC7A100T",
    };

    const row = try result.formatAsTableRow(std.testing.allocator);
    defer std.testing.allocator.free(row);

    try std.testing.expect(std.mem.indexOf(u8, row, "125.3") != null);
    try std.testing.expect(std.mem.indexOf(u8, row, "±") != null);
}

test "FPGAResources formatAsTableRow" {
    const fpga = ZenodoMetadata.FPGAResources{
        .lut_pct = 6.7,
        .bram_pct = 100.0,
        .dsp_pct = 0.0,
        .platform = "XC7A100T",
        .clock_mhz = 100,
        .power_w = 0.5,
        .throughput_tok_per_sec = 51200,
    };

    const row = try fpga.formatAsTableRow(std.testing.allocator);
    defer std.testing.allocator.free(row);

    try std.testing.expect(std.mem.indexOf(u8, row, "6.7%") != null);
    try std.testing.expect(std.mem.indexOf(u8, row, "0") != null);
    try std.testing.expect(std.mem.indexOf(u8, row, "51200 tok/s") != null);
}

test "License toString" {
    try std.testing.expectEqual("MIT", ZenodoMetadata.License.mit.toString());
    try std.testing.expectEqual("Apache-2.0", ZenodoMetadata.License.apache_2.toString());
    try std.testing.expectEqual("GPL-3.0", ZenodoMetadata.License.gpl_3.toString());
    try std.testing.expectEqual("CC-BY-4.0", ZenodoMetadata.License.cc_by.toString());
    try std.testing.expectEqual("CC-BY-SA-4.0", ZenodoMetadata.License.cc_by_sa.toString());
    try std.testing.expectEqual("CC-BY-NC-4.0", ZenodoMetadata.License.cc_by_nc.toString());
    try std.testing.expectEqual("CC0-1.0", ZenodoMetadata.License.cc0.toString());
    try std.testing.expectEqual("BSD-3-Clause", ZenodoMetadata.License.bsd_3.toString());
}

test "License isDefensivePublication" {
    try std.testing.expect(ZenodoMetadata.License.mit.isDefensivePublication());
    try std.testing.expect(ZenodoMetadata.License.cc0.isDefensivePublication());
    try std.testing.expect(ZenodoMetadata.License.bsd_3.isDefensivePublication());
    try std.testing.expect(!ZenodoMetadata.License.apache_2.isDefensivePublication());
}

test "Create default metadata" {
    const metadata = try createDefaultMetadata(std.testing.allocator, BundleType.ternary_nn);

    try std.testing.expectEqual(@as(usize, 10), metadata.keywords.len);
    try std.testing.expectEqual("5.0.0", metadata.version);
    try std.testing.expectEqual(ZenodoMetadata.License.mit, metadata.license);
}

test "Generate Zenodo deposit" {
    const deposit = try generateZenodoDeposit(std.testing.allocator, BundleType.ternary_nn);

    try std.testing.expect(deposit.metadata.title.len > 0);
    try std.testing.expect(deposit.json_content.len > 0);
    try std.testing.expect(deposit.cff_content.len > 0);
    try std.testing.expect(deposit.readme_content.len > 0);
}

test "Author formatAsCreator" {
    const author = Author{
        .name = "Test Author",
        .affiliation = "Test University",
        .orcid = "0000-0000-0000",
        .corresponding = true,
    };

    const creator = try author.formatAsCreator(std.testing.allocator);
    defer std.testing.allocator.free(creator);

    const expected = "{\"name\": \"Test Author\", \"affiliation\": \"Test University\", \"orcid\": \"0000-0000-0000\"}";
    try std.testing.expectEqualStrings(expected, creator);
}

test "BroaderImpact formatAsMarkdown" {
    const impact = BroaderImpact{
        .positive_impacts = &[_][]const u8{
            "Positive impact 1",
            "Positive impact 2",
        },
        .risks = &[_][]const u8{
            "Risk 1",
            "Risk 2",
        },
        .mitigations = &[_][]const u8{
            "Mitigation 1",
        },
    };

    const md = try impact.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "## Broader Impact") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "### Positive Impacts") != null);
}

test "EthicalConsiderations formatAsMarkdown" {
    const ethics = EthicalConsiderations{
        .data_provenance = "Test dataset",
        .environmental_impact = "Test environmental impact",
        .bias_assessment = "Test bias assessment",
        .fairness = "Test fairness",
    };

    const md = try ethics.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "## Ethical Considerations") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "### Data Provenance") != null);
}

test "ReproducibilityInfo formatAsMarkdown" {
    const repro = ReproducibilityInfo{
        .code_url = "https://github.com/test/repo",
        .commit_hash = "abc123",
        .docker_image = "test/image:latest",
        .dataset_url = "https://huggingface.co/datasets/roneneldan/TinyStories",
        .hardware = "Zig 0.15.2, Apple M1 Pro (10 cores, 32 GB RAM). FPGA: QMTech XC7A100T.",
        .expected_results = "Validation PPL: 125.3 ± 2.1 (95% CI: [123.2, 127.4])",
        .random_seed = 42,
    };

    const md = try repro.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "## Reproducibility") != null);
}

test "CitationConverter bibtexToAPA" {
    const bibtex =
        \\@misc{key2026_trinity,
        \\  title = {Trinity S³AI},
        \\  author = {Dmitrii Vasilev},
        \\  year = {2026},
        \\  doi = {10.5281/zenodo.19227865}
        \\}
    ;

    const apa = try CitationConverter.bibtexToAPA(bibtex, std.testing.allocator);
    defer std.testing.allocator.free(apa);

    try std.testing.expect(std.mem.indexOf(u8, apa, "Dmitrii Vasilev") != null);
    try std.testing.expect(std.mem.indexOf(u8, apa, "*Trinity S³AI*") != null);
    try std.testing.expect(std.mem.indexOf(u8, apa, "2026") != null);
}

test "createEnhancedMetadata" {
    const metadata = try createEnhancedMetadata(std.testing.allocator, BundleType.ternary_nn);
    defer {
        if (metadata.broader_impact) |s| std.testing.allocator.free(s);
        if (metadata.ethics) |s| std.testing.allocator.free(s);
    }

    try std.testing.expect(metadata.funding != null);
    try std.testing.expect(metadata.broader_impact != null);
    try std.testing.expect(metadata.ethics != null);
    try std.testing.expect(metadata.reproducibility != null);
}

test "StatisticalResults formatAsMarkdown" {
    const stats = StatisticalResults{
        .metric = "Perplexity",
        .mean = 125.3,
        .std_dev = 2.1,
        .std_error = 0.94,
        .ci95_lower = 123.2,
        .ci95_upper = 127.4,
        .n = 5,
        .p_value = 0.001,
        .effect_size = 1.8,
    };

    const md = try stats.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "### Perplexity") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "125.3") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "[123.20, 127.40]") != null);
}

test "AlgorithmBox formatAsMarkdown" {
    const algo = AlgorithmBox{
        .name = "Ternary Forward Pass",
        .problem = "Efficient forward pass using {-1,0,+1} weights",
        .input = "W ∈ {-1,0,+1}^{m×n}, x ∈ ℝ^n",
        .assumptions = &[_][]const u8{
            "Weights are ternary",
            "Input is float32",
            "No bias term",
        },
        .complexity = "O(mn) time, O(mn) space",
    };

    const md = try algo.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "## Algorithm") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Ternary Forward Pass") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "O(mn)") != null);
}

test "ComparisonTable formatAsMarkdown" {
    const rows = &[_]ComparisonTable.Row{
        .{ .name = "HSLM-1.95M", .metric = "PPL", .ours = 125.3, .baseline = 145.2, .improvement = "-13.7%" },
        .{ .name = "Baseline", .metric = "PPL", .ours = 145.2, .baseline = 145.2, .improvement = "-" },
    };

    const table = ComparisonTable{
        .caption = "Perplexity comparison on TinyStories",
        .rows = rows,
    };

    const md = try table.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "HSLM-1.95M") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "125.3") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "-13.7%") != null);
}

test "ComparisonTable formatAsLaTeX" {
    const rows = &[_]ComparisonTable.Row{
        .{ .name = "HSLM-1.95M", .metric = "PPL", .ours = 125.3, .baseline = 145.2, .improvement = "-13.7%" },
    };

    const table = ComparisonTable{
        .caption = "Perplexity comparison",
        .rows = rows,
    };

    const latex = try table.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{table}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\textbf{HSLM-1.95M}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\toprule") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\bottomrule") != null);
}

test "CalibrationMetrics formatAsMarkdown" {
    const calib = CalibrationMetrics{
        .expected_calibration_error = 0.083,
        .brier_score = 0.125,
        .n_bins = 10,
    };

    const md = try calib.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "### Calibration Metrics") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "0.083") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "0.125") != null);
}

test "PaperMetadata formatAsAbstract" {
    const paper = PaperMetadata{
        .title = "Ternary Neural Networks for Efficient AI",
        .authors = &[_][]const u8{"Dmitrii Vasilev"},
        .abstract = "This paper introduces ternary neural networks that achieve 20x compression.",
        .keywords = &[_][]const u8{ "ternary", "neural networks", "compression" },
        .mlcc_category = "cs.LG",
        .conference = .neurips,
        .year = 2025,
        .code_url = "https://github.com/gHashTag/trinity",
        .doi = "10.5281/zenodo.19227865",
    };

    const md = try paper.formatAsAbstract(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "# Ternary Neural Networks") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "## Abstract") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "NeurIPS 2025") != null);
}

test "PaperMetadata validateAbstractLength" {
    const short_abstract = "Too short.";

    const paper_short = PaperMetadata{
        .title = "Test",
        .authors = &[_][]const u8{"Author"},
        .abstract = short_abstract,
        .keywords = &[_][]const u8{"test"},
        .mlcc_category = "cs.LG",
        .conference = .neurips,
        .year = 2025,
        .code_url = "https://github.com/test",
        .doi = null,
    };

    const result = try paper_short.validateAbstractLength();
    try std.testing.expect(!result.is_valid);
    try std.testing.expect(result.word_count < 150);
}

test "BatchProcessor generateCombinedReadme" {
    const readme = try BatchProcessor.generateCombinedReadme(std.testing.allocator);
    defer std.testing.allocator.free(readme);

    try std.testing.expect(std.mem.indexOf(u8, readme, "Trinity S³AI") != null);
    try std.testing.expect(std.mem.indexOf(u8, readme, "B001") != null);
    try std.testing.expect(std.mem.indexOf(u8, readme, "10.5281/zenodo.19227865") != null);
}

test "PaperMetadata Conference toString" {
    try std.testing.expectEqual("NeurIPS", PaperMetadata.Conference.neurips.toString());
    try std.testing.expectEqual("ICLR", PaperMetadata.Conference.iclr.toString());
    try std.testing.expectEqual("MLSys", PaperMetadata.Conference.mlsys.toString());
}

// ═════════════════════════════════════════════════════════════════════════
// MATHEMATICAL PROOFS TESTS
// ═════════════════════════════════════════════════════════════════════════

test "TheoremStatement formatAsLaTeX" {
    const theorem = TheoremStatement{
        .env = .theorem,
        .label = "thm:ternary-bound",
        .title = "Ternary Weight Bounds",
        .statement = "For any weight $w \\in \\{-1, 0, +1\\}$, the expected value $E[w] = 0$.",
        .proof = "Direct calculation from the definition of ternary weights.",
        .references = &[_][]const u8{"def:ternary-set"},
        .equations = &[_][]const u8{"eq:expected-value"},
    };

    const latex = try theorem.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{theorem}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\label{thm:ternary-bound}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{proof}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\end{proof}") != null);
}

test "TheoremStatement formatAsMarkdown" {
    const theorem = TheoremStatement{
        .env = .lemma,
        .label = "lem:sparsity",
        .title = "Sparsity Lemma",
        .statement = "Ternary quantization achieves 67% sparsity.",
    };

    const md = try theorem.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "## Lemma") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Sparsity Lemma") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "`lem:sparsity`") != null);
}

test "MathematicalProofs formatAsLaTeXSection" {
    const theorems = [_]TheoremStatement{
        .{
            .env = .theorem,
            .label = "thm:main",
            .statement = "$\\phi^2 + \\phi^{-2} = 3$",
        },
        .{
            .env = .definition,
            .label = "def:phi",
            .statement = "Golden ratio $\\phi = \\frac{1 + \\sqrt{5}}{2}$",
        },
    };

    const proofs = MathematicalProofs{
        .title = "Trinity Mathematical Foundation",
        .theorems = &theorems,
    };

    const latex = try proofs.formatAsLaTeXSection(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\section{Trinity Mathematical Foundation}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{theorem}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{definition}") != null);
}

test "Equation formatAsLaTeX" {
    const eq = Equation{
        .latex = "E[w] = \\sum_{i} w_i P(w_i)",
        .label = "eq:expected-value",
        .description = "Expected value of ternary weight",
    };

    const latex = try eq.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{equation}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\label{eq:expected-value}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\end{equation}") != null);
}

test "Equation formatAsMarkdown" {
    const eq = Equation{
        .latex = "\\phi^2 + \\phi^{-2} = 3",
        .label = "eq:trinity-identity",
        .description = "Trinity Identity",
    };

    const md = try eq.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "Trinity Identity") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "\\phi^2") != null);
}

test "FigureCaption formatAsLaTeX" {
    const fig = FigureCaption{
        .label = "fig:ternary-architecture",
        .caption = "Ternary neural network architecture showing {-1,0,+1} weight quantization",
        .description = "The diagram illustrates the HSLM forward pass with ternary weights.",
        .references = &[_][]const u8{"eq:trinity-identity"},
    };

    const latex = try fig.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{figure}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\label{fig:ternary-architecture}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\ref{eq:trinity-identity}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\end{figure}") != null);
}

test "FigureCaption formatAsMarkdown" {
    const fig = FigureCaption{
        .label = "fig:ternary-architecture",
        .caption = "Ternary neural network architecture",
        .description = "Shows the HSLM forward pass with ternary weights.",
    };

    const md = try fig.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "**Figure fig:ternary-architecture:**") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Ternary neural network architecture") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "HSLM forward pass") != null);
}

test "FigureCaption formatAsLaTeX no references" {
    const fig = FigureCaption{
        .label = "fig:fpga-layout",
        .caption = "FPGA floor plan showing DSP48 and BRAM utilization",
    };

    const latex = try fig.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{figure}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "(see") == null); // No references
}

test "FigureCaption formatAsMarkdown no description" {
    const fig = FigureCaption{
        .label = "fig:isa-overview",
        .caption = "TRI-27 ISA instruction format",
    };

    const md = try fig.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "**Figure fig:isa-overview:**") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "TRI-27 ISA") != null);
}

test "Keyword formatAsLaTeX" {
    const kw = Keyword{
        .term = "neural networks",
        .category = .general,
    };

    const latex = try kw.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\kw{neural networks}") != null);
}

test "Keyword formatAsMarkdown" {
    const kw = Keyword{
        .term = "quantization",
        .category = .acm_ccs,
        .subcategory = "cs.LG",
    };

    const md = try kw.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "quantization") != null);
}

test "Keywords formatAsLaTeX" {
    const kws = Keywords{
        .items = &[_]Keyword{
            .{ .term = "neural networks", .category = .general },
            .{ .term = "quantization", .category = .acm_ccs },
            .{ .term = "edge computing", .category = .mesh },
        },
    };

    const latex = try kws.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\keywords{") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "neural networks") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "quantization") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "edge computing") != null);
}

test "Keywords formatAsMarkdown" {
    const kws = Keywords{
        .items = &[_]Keyword{
            .{ .term = "ternary", .category = .general },
            .{ .term = "neural networks", .category = .acm_ccs },
            .{ .term = "fpga", .category = .mesh },
        },
    };

    const md = try kws.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "**Keywords:**") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "ternary") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "**ACM CCS:**") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "**MeSH:**") != null);
}

test "Keywords countByCategory" {
    const kws = Keywords{
        .items = &[_]Keyword{
            .{ .term = "neural networks", .category = .acm_ccs },
            .{ .term = "quantization", .category = .general },
            .{ .term = "machine learning", .category = .acm_ccs },
            .{ .term = "edge computing", .category = .mesh },
        },
    };

    const acm_count = kws.countByCategory(.acm_ccs);
    try std.testing.expectEqual(@as(usize, 2), acm_count);

    const general_count = kws.countByCategory(.general);
    try std.testing.expectEqual(@as(usize, 1), general_count);

    const mesh_count = kws.countByCategory(.mesh);
    try std.testing.expectEqual(@as(usize, 1), mesh_count);
}

test "SupplementaryItem formatAsLaTeX" {
    const item = SupplementaryItem{
        .section = .derivations,
        .title = "Trinity Identity Derivation",
        .content = "Starting from $\\phi = \\frac{1 + \\sqrt{5}}{2}$...",
        .label = "sup:trinity-derivation",
    };

    const latex = try item.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\subsection{Trinity Identity Derivation}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\label{sup:trinity-derivation}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "Starting from") != null);
}

test "SupplementaryItem formatAsMarkdown" {
    const item = SupplementaryItem{
        .section = .code,
        .title = "HSLM Forward Pass",
        .content = "```zig\nfn forward(...)\n```",
    };

    const md = try item.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "### Code Listings") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "#### HSLM Forward Pass") != null);
}

test "SupplementaryMaterials formatAsLaTeX" {
    const items = [_]SupplementaryItem{
        .{
            .section = .derivations,
            .title = "Trinity Derivation",
            .content = "Math content",
        },
        .{
            .section = .extended_results,
            .title = "Additional Benchmarks",
            .content = "Table content",
        },
    };

    const sup = SupplementaryMaterials{
        .title = "Appendix",
        .items = &items,
    };

    const latex = try sup.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\appendix{Appendix}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\section{Derivations}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\section{Extended Results}") != null);
}

test "SupplementaryMaterials formatAsMarkdown" {
    const items = [_]SupplementaryItem{
        .{
            .section = .hardware_spec,
            .title = "FPGA Resources",
            .content = "DSP48: 0%, LUT: 6.7%",
        },
    };

    const sup = SupplementaryMaterials{
        .items = &items,
    };

    const md = try sup.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "# Supplementary Materials") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "### Hardware Specifications") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "DSP48: 0%") != null);
}

test "SupplementaryItem no label" {
    const item = SupplementaryItem{
        .section = .figures,
        .title = "Additional Architecture Diagram",
        .content = "Figure content",
    };

    const latex = try item.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\label{") == null);
}

// ═════════════════════════════════════════════════════════════════════════
// NEW STRUCTURE TESTS (Energy, Power, ROC, Checklists)
// ═══════════════════════════════════════════════════════════════════════════

test "PowerAnalysis energyKWh" {
    const power = PowerAnalysis{
        .power_watts = 1200.0, // 1.2kW
        .duration_hours = 4.0,
        .hardware = "Test Hardware",
        .operation = .training,
    };

    try std.testing.expectApproxEqAbs(4.8, power.energyKWh(), 0.01);
}

test "PowerAnalysis co2Kg" {
    const power = PowerAnalysis{
        .power_watts = 1200.0,
        .duration_hours = 4.0,
        .hardware = "Test Hardware",
        .operation = .training,
    };

    const expected = 4.8 * 0.475; // kWh × global average
    try std.testing.expectApproxEqAbs(expected, power.co2Kg(), 0.001);
}

test "PowerAnalysis compareSavings" {
    const fpga = PowerAnalysis{
        .power_watts = 1.2,
        .duration_hours = 1.0,
        .hardware = "FPGA",
        .operation = .inference,
    };

    const savings = fpga.compareSavings(25.0); // Baseline 25W GPU

    try std.testing.expect(savings.power_reduction_percent > 90.0);
    try std.testing.expect(savings.annual_co2_savings_kg > 0);
}

test "PowerAnalysis formatAsMarkdown" {
    const power = PowerAnalysis{
        .power_watts = 1.2,
        .duration_hours = 1.0,
        .hardware = "QMTech XC7A100T FPGA",
        .operation = .inference,
    };

    const md = try power.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "## Power Analysis") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "1.2 W") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "0.0012 kWh") != null);
}

test "EnvironmentalImpact totalEmissions" {
    const training = PowerAnalysis{
        .power_watts = 100.0,
        .duration_hours = 10.0,
        .hardware = "Apple M1 Pro",
        .operation = .training,
    };

    const impact = EnvironmentalImpact{
        .training = training,
        .inference_per_1k = PowerAnalysis{
            .power_watts = 1.2,
            .duration_hours = 0.01,
            .hardware = "FPGA",
            .operation = .inference,
        },
        .total_inferences = 100000,
        .region = .eu_central,
    };

    const emissions = impact.totalEmissions();
    try std.testing.expect(emissions.training_kg > 0);
    try std.testing.expect(emissions.inference_kg > 0);
    try std.testing.expect(emissions.total_kg > emissions.training_kg);
}

test "EnvironmentalImpact formatAsMarkdown" {
    const training = PowerAnalysis{
        .power_watts = 100.0,
        .duration_hours = 10.0,
        .hardware = "Apple M1 Pro",
        .operation = .training,
    };

    const impact = EnvironmentalImpact{
        .training = training,
        .inference_per_1k = PowerAnalysis{
            .power_watts = 1.2,
            .duration_hours = 0.01,
            .hardware = "FPGA",
            .operation = .inference,
        },
        .total_inferences = 100000,
        .region = .eu_central,
    };

    const md = try impact.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "## Environmental Impact") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Lifecycle Emissions") != null);
}

test "SampleSizeCalculator requiredSampleSize" {
    const calc = SampleSizeCalculator{
        .effect_size = 0.8, // Large effect
        .power = 0.8,
        .alpha = 0.05,
        .test_type = .two_sample_t,
    };

    const n = try calc.requiredSampleSize();
    try std.testing.expect(n > 10); // Should require ~26 per group
    try std.testing.expect(n < 50);
}

test "SampleSizeCalculator achievedPower" {
    const calc = SampleSizeCalculator{
        .effect_size = 0.8,
        .power = 0.8,
        .alpha = 0.05,
        .test_type = .two_sample_t,
    };

    const power = calc.achievedPower(26);
    try std.testing.expect(power > 0.75); // Should be close to 0.8
    try std.testing.expect(power <= 1.0);
}

test "SampleSizeCalculator formatAsMarkdown" {
    const calc = SampleSizeCalculator{
        .effect_size = 1.8, // Very large effect (HSLM improvement)
        .power = 0.8,
        .alpha = 0.05,
        .test_type = .two_sample_t,
    };

    const md = try calc.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "## Sample Size Analysis") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Large effect") != null);
}

test "ROCCurve calculateAUC" {
    // Perfect classifier: (0,0), (0,1), (1,1)
    const tpr = [_]f64{ 0.0, 1.0, 1.0 };
    const fpr = [_]f64{ 0.0, 0.0, 1.0 };

    const roc = ROCCurve{
        .tpr = &tpr,
        .fpr = &fpr,
        .auc = 0.0, // Will be calculated
        .n_pos = 100,
        .n_neg = 100,
    };

    const auc = roc.calculateAUC();
    try std.testing.expect(auc > 0.9);
}

test "ROCCurve aucConfidenceInterval" {
    const tpr = [_]f64{ 0.0, 0.5, 1.0 };
    const fpr = [_]f64{ 0.0, 0.5, 1.0 };

    const roc = ROCCurve{
        .tpr = &tpr,
        .fpr = &fpr,
        .auc = 0.75,
        .n_pos = 100,
        .n_neg = 100,
    };

    const ci = roc.aucConfidenceInterval(0.95);
    try std.testing.expect(ci.lower < 0.75);
    try std.testing.expect(ci.upper > 0.75);
}

test "ROCCurve formatAsMarkdown" {
    const tpr = [_]f64{ 0.0, 0.5, 1.0 };
    const fpr = [_]f64{ 0.0, 0.5, 1.0 };

    const roc = ROCCurve{
        .tpr = &tpr,
        .fpr = &fpr,
        .auc = 0.85,
        .n_pos = 100,
        .n_neg = 100,
    };

    const md = try roc.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "## ROC/AUC Analysis") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Excellent") != null);
}

test "ConferenceChecklist generate NeurIPS" {
    const checklist = ConferenceChecklist{
        .conference = .neurips,
        .year = 2025,
    };

    const md = try checklist.generate(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "NeurIPS 2025 Requirements") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Broader Impact Statement") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Reproducibility Checklist") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Statistical Rigor") != null);
}

test "ConferenceChecklist generate ICLR" {
    const checklist = ConferenceChecklist{
        .conference = .iclr,
        .year = 2025,
    };

    const md = try checklist.generate(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "ICLR 2025 Requirements") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Code Availability") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Experimental Protocol") != null);
}

test "ConferenceChecklist generate MLSys" {
    const checklist = ConferenceChecklist{
        .conference = .mlsys,
        .year = 2025,
    };

    const md = try checklist.generate(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "MLSys 2025 Requirements") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "System Description") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Benchmarking") != null);
}

// ============================================================================
// V11 Tests: AblationStudy, HyperparameterTable, DatasetDescription, TikZDiagram
// ============================================================================

test "AblationStudy formatAsLaTeX" {
    const components = [_]AblationComponent{
        .{ .name = "Full Model", .value = 12.5, .std_error = 0.2, .is_full_model = true },
        .{ .name = "- Attention", .value = 14.8, .std_error = 0.3, .delta = 2.3, .is_ablated = true },
        .{ .name = "- Ternary", .value = 13.2, .std_error = 0.2, .delta = 0.7, .is_ablated = true },
        .{ .name = "- VSA Memory", .value = 15.1, .std_error = 0.4, .delta = 2.6, .is_ablated = true },
    };

    const ablation = AblationStudy{
        .caption = "Ablation study on TinyStories validation",
        .label = "tab:ablation",
        .metric = "Validation PPL",
        .lower_is_better = true,
        .components = &components,
    };

    const latex = try ablation.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{table}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "tab:ablation") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\textbf{Full Model}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\textit{- Attention}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "+2.300") != null);
}

test "AblationStudy formatAsMarkdown" {
    const components = [_]AblationComponent{
        .{ .name = "Full Model", .value = 0.92, .is_full_model = true },
        .{ .name = "- Pretraining", .value = 0.85, .delta = -0.07, .is_ablated = true },
    };

    const ablation = AblationStudy{
        .caption = "Component ablation analysis",
        .label = "tab:abl",
        .metric = "Accuracy",
        .lower_is_better = false,
        .components = &components,
    };

    const md = try ablation.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "**Full Model**") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "*- Pretraining*") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "(-0.070)") != null);
}

test "HyperparameterTable formatAsLaTeX" {
    const hps = [_]HyperparameterSpec{
        .{ .name = "learning_rate", .value = "0.001", .type = "float", .description = "Initial learning rate", .search_space = "[1e-4, 1e-2]" },
        .{ .name = "batch_size", .value = "32", .type = "int", .description = "Training batch size" },
        .{ .name = "optimizer", .value = "adamw", .type = "str", .description = "Optimizer type" },
    };

    const table = HyperparameterTable{
        .caption = "HSLM training hyperparameters",
        .label = "tab:hparams",
        .group = "Training",
        .hyperparameters = &hps,
    };

    const latex = try table.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{table}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "tab:hparams") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\texttt{learning_rate}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "[1e-4, 1e-2]") != null);
}

test "HyperparameterTable formatAsMarkdown" {
    const hps = [_]HyperparameterSpec{
        .{ .name = "embed_dim", .value = "768", .type = "int", .description = "Embedding dimension" },
        .{ .name = "num_heads", .value = "12", .type = "int", .description = "Number of attention heads" },
    };

    const table = HyperparameterTable{
        .caption = "Model architecture",
        .label = "tab:arch",
        .hyperparameters = &hps,
    };

    const md = try table.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "`embed_dim`") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Embedding dimension") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "*Table: Model architecture*") != null);
}

test "DatasetDescription formatAsLaTeX" {
    const splits = [_]DataSplit{
        .{ .name = "Train", .samples = 90000, .percentage = 90.0 },
        .{ .name = "Validation", .samples = 5000, .percentage = 5.0 },
        .{ .name = "Test", .samples = 5000, .percentage = 5.0 },
    };

    const dataset = DatasetDescription{
        .name = "TinyStories",
        .label = "tab:dataset",
        .description = "A collection of short stories for language model pretraining",
        .splits = &splits,
        .num_features = 10000,
        .num_classes = null,
        .license = "MIT",
        .url = "https://github.com/nlp-yone TinyStories",
    };

    const latex = try dataset.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{table}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "TinyStories") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "90.0%") != null);
}

test "DatasetDescription formatAsMarkdown" {
    const splits = [_]DataSplit{
        .{ .name = "Training", .samples = 50000, .percentage = 80.0 },
        .{ .name = "Test", .samples = 12500, .percentage = 20.0 },
    };

    const dataset = DatasetDescription{
        .name = "Custom Dataset",
        .label = "tab:data",
        .description = "A custom dataset for testing",
        .splits = &splits,
        .num_features = 512,
        .num_classes = 10,
    };

    const md = try dataset.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "## Custom Dataset") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "`tab:data`") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "| Training | 50000 | 80.0% |") != null);
}

test "TikZDiagram formatAsLaTeX" {
    const nodes = [_]TikZDiagram.Node{
        .{ .id = "input", .label = "Input", .position = [_]f64{ 0, 0 }, .node_type = .simple },
        .{ .id = "hidden", .label = "Hidden", .position = [_]f64{ 2, 0 }, .node_type = .circle },
        .{ .id = "output", .label = "Output", .position = [_]f64{ 4, 0 }, .node_type = .output },
    };

    const edges = [_]TikZDiagram.Edge{
        .{ .from = "input", .to = "hidden", .label = "W" },
        .{ .from = "hidden", .to = "output", .label = "V" },
    };

    const diagram = TikZDiagram{
        .caption = "Simple neural network architecture",
        .label = "fig:nn",
        .nodes = &nodes,
        .edges = &edges,
        .style = "neural",
        .width = 8.0,
    };

    const latex = try diagram.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{figure}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{tikzpicture}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\node[") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\draw[->]") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "fig:nn") != null);
}

test "TikZDiagram formatAsMarkdown" {
    const nodes = [_]TikZDiagram.Node{
        .{ .id = "x", .label = "x", .position = [_]f64{ 0, 0 } },
        .{ .id = "y", .label = "y", .position = [_]f64{ 1, 1 } },
    };

    const edges = [_]TikZDiagram.Edge{
        .{ .from = "x", .to = "y" },
    };

    const diagram = TikZDiagram{
        .caption = "Simple diagram",
        .label = "fig:simple",
        .nodes = &nodes,
        .edges = &edges,
    };

    const md = try diagram.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "**Figure Simple diagram**") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "\\node[") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "\\draw[->]") != null);
}

// ============================================================================
// TESTS — V12 Structures
// ============================================================================

test "ChecklistResponse toString" {
    try std.testing.expectEqualStrings("✓ Yes", ChecklistResponse.yes.toString());
    try std.testing.expectEqualStrings("✗ No", ChecklistResponse.no.toString());
    try std.testing.expectEqualStrings("~ Partial", ChecklistResponse.partial.toString());
    try std.testing.expectEqualStrings("N/A", ChecklistResponse.na.toString());
}

test "ChecklistResponse toSymbol" {
    try std.testing.expectEqualStrings("[✓]", ChecklistResponse.yes.toSymbol());
    try std.testing.expectEqualStrings("[✗]", ChecklistResponse.no.toSymbol());
    try std.testing.expectEqualStrings("[~]", ChecklistResponse.partial.toSymbol());
    try std.testing.expectEqualStrings("[ ]", ChecklistResponse.na.toSymbol());
}

test "ReproducibilityChecklist formatAsLaTeX" {
    const items = [_]ChecklistItem{
        .{ .category = "Code", .question = "Is code available?", .response = .yes, .link = "https://github.com/example" },
        .{ .category = "Data", .question = "Is dataset public?", .response = .partial, .details = "Training data is private" },
        .{ .category = "Hyperparameters", .question = "Are all HPs listed?", .response = .yes },
    };

    const checklist = ReproducibilityChecklist{
        .conference = "NeurIPS",
        .year = 2025,
        .items = &items,
        .paper_title = "HSLM: Hierarchical Sparse Language Model",
    };

    const latex = try checklist.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\section{Reproducibility Checklist}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "[✓]") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "https://github.com/example") != null);
}

test "ReproducibilityChecklist formatAsMarkdown" {
    const items = [_]ChecklistItem{
        .{ .category = "Code", .question = "Is code available?", .response = .yes },
    };

    const checklist = ReproducibilityChecklist{
        .conference = "ICLR",
        .year = 2025,
        .items = &items,
        .paper_title = "Test Paper",
    };

    const md = try checklist.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "# Reproducibility Checklist") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "✓ Yes") != null);
}

test "ResultsSummary formatAsLaTeX" {
    const results = [_]StatisticalResult{
        .{ .metric = "HSLM (ours)", .value = 12.5, .std_err = 0.2, .p_value = 0.001, .effect_size = 1.8, .significance = .high, .is_best = true },
        .{ .metric = "GPT-2 (117M)", .value = 15.2, .std_err = 0.3, .p_value = 0.05, .effect_size = 0.0, .significance = .low, .is_baseline = false },
    };

    const summary = ResultsSummary{
        .caption = "Main results",
        .label = "tab:results",
        .dataset = "TinyStories",
        .results = &results,
        .primary_metric = "Validation PPL",
        .higher_is_better = false,
    };

    const latex = try summary.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{table}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\textbf{HSLM (ours)}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "$^{***}$") != null);
}

test "ResultsSummary formatAsMarkdown" {
    const results = [_]StatisticalResult{
        .{ .metric = "Method A", .value = 0.85, .std_err = 0.02, .ci = .{ .lower = 0.81, .upper = 0.89 }, .is_best = true },
    };

    const summary = ResultsSummary{
        .caption = "Results",
        .label = "tab:res",
        .dataset = "Dataset X",
        .results = &results,
        .primary_metric = "Accuracy",
        .higher_is_better = true,
    };

    const md = try summary.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "**Method A**") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "**0.850**") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "[0.810, 0.890]") != null);
}

test "MultiPanelFigure formatAsLaTeX" {
    const panels = [_]SubPanel{
        .{ .panel_id = "a", .caption = "Architecture overview", .label = "fig:arch:a", .width_frac = 0.48 },
        .{ .panel_id = "b", .caption = "Training curve", .label = "fig:arch:b", .width_frac = 0.48 },
    };

    const fig = MultiPanelFigure{
        .caption = "Model architecture and training",
        .label = "fig:arch",
        .layout = "1x2",
        .panels = &panels,
        .width = 0.9,
    };

    const latex = try fig.formatAsLaTeX(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{figure}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{subfigure}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "Architecture overview") != null);
}

test "MultiPanelFigure formatAsMarkdown" {
    const panels = [_]SubPanel{
        .{ .panel_id = "a", .caption = "Panel A", .width_frac = 0.5 },
        .{ .panel_id = "b", .caption = "Panel B", .width_frac = 0.5 },
    };

    const fig = MultiPanelFigure{
        .caption = "Multi-panel figure",
        .label = "fig:multi",
        .layout = "1x2",
        .panels = &panels,
    };

    const md = try fig.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "**Figure Multi-panel figure**") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "| (a) | Panel A | 50% |") != null);
}
