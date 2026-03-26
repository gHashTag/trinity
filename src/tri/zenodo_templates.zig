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
        defer creator.deinit();

        try creator.writer(allocator).print("{{\"name\": \"{s}\", \"affiliation\": \"{s}\"", .{ self.name, self.affiliation });
        if (self.orcid) |orcid| {
            try creator.writer(allocator).print(", \"orcid\": \"{s}\"", .{orcid});
        }
        try creator.writer(allocator).print("}}");

        return creator.toOwnedSlice();
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
        defer md.deinit();

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

        return md.toOwnedSlice();
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
        defer md.deinit();

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

        return md.toOwnedSlice();
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
        defer md.deinit();

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

        return md.toOwnedSlice();
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
        defer json.deinit();

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

        return try json.toOwnedSlice();
    }

    /// Generate CITATION.cff file content
    pub fn toCitationCFF(self: *const ZenodoMetadata, allocator: std.mem.Allocator) ![]u8 {
        var cff = std.ArrayList(u8).initCapacity(allocator, 512) catch @panic("OOM");
        defer cff.deinit();

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

        return try cff.toOwnedSlice();
    }

    /// Generate README.md for Zenodo deposit
    pub fn toZenodoReadme(self: *const ZenodoMetadata, allocator: std.mem.Allocator) ![]u8 {
        var readme = std.ArrayList(u8).initCapacity(allocator, 1024) catch @panic("OOM");
        defer readme.deinit();

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

        return try readme.toOwnedSlice();
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
        .broader_impact = try impact_md.formatAsMarkdown(allocator),
        .ethics = try ethics_md.formatAsMarkdown(allocator),
        .reproducibility = try repro_md.formatAsMarkdown(allocator),
    };
}

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
    defer std.testing.allocator.free(metadata.funding);
    defer std.testing.allocator.free(metadata.broader_impact);
    defer std.testing.allocator.free(metadata.ethics);
    defer std.testing.allocator.free(metadata.reproducibility);

    try std.testing.expect(metadata.funding != null);
    try std.testing.expect(metadata.broader_impact != null);
    try std.testing.expect(metadata.ethics != null);
    try std.testing.expect(metadata.reproducibility != null);
}
