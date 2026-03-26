//! Supplementary Materials Generator for NeurIPS/ICLR Submissions
//!
//! Generates LaTeX appendices, code listings, and experimental results
//! formatted for top ML conferences.

const std = @import("std");

/// Supplementary material format
pub const MaterialFormat = enum {
    latex,
    markdown,
    pdf,
};

/// Supplementary material section
pub const SuppSection = struct {
    title: []const u8,
    content: []const u8,
    subsections: std.ArrayList(SuppSection),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, title: []const u8) SuppSection {
        return .{
            .title = title,
            .content = "",
            .subsections = std.ArrayList(SuppSection).initCapacity(allocator, 0) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SuppSection) void {
        for (self.subsections.items) |*sub| {
            sub.deinit();
        }
        self.subsections.deinit(self.allocator);
    }

    pub fn addSubsection(self: *SuppSection, title: []const u8) !*SuppSection {
        try self.subsections.append(self.allocator, SuppSection.init(self.allocator, title));
        return &self.subsections.items[self.subsections.items.len - 1];
    }

    pub fn setContent(self: *SuppSection, content: []const u8) !void {
        self.content = try self.allocator.dupe(u8, content);
    }

    /// Generate LaTeX output
    pub fn toLatex(self: SuppSection, writer: anytype, depth: u8) !void {
        const prefix = if (depth == 0) "\\section" else if (depth == 1) "\\subsection" else if (depth == 2) "\\subsubsection" else "\\paragraph";

        try writer.print("{s}{{{s}}}\n", .{ prefix, self.title });

        if (self.content.len > 0) {
            try writer.writeAll(self.content);
            try writer.writeAll("\n\n");
        }

        for (self.subsections.items) |sub| {
            try sub.toLatex(writer, depth + 1);
        }
    }

    /// Generate Markdown output
    pub fn toMarkdown(self: SuppSection, writer: anytype, depth: u8) !void {
        var prefix_buf: [10]u8 = undefined;
        const prefix = prefix_buf[0..depth];
        @memset(prefix, '#');

        try writer.print("{s} {s}\n\n", .{ prefix, self.title });

        if (self.content.len > 0) {
            try writer.writeAll(self.content);
            try writer.writeAll("\n\n");
        }

        for (self.subsections.items) |sub| {
            try sub.toMarkdown(writer, depth + 1);
        }
    }
};

/// Experimental result for supplementary tables
pub const ExperimentalResult = struct {
    name: []const u8,
    value: f64,
    std_error: f64,
    ci95_lower: f64,
    ci95_upper: f64,
    n: usize,
    p_value: ?f64 = null,
    significant: bool = false,
};

/// Supplementary materials generator
pub const SuppGenerator = struct {
    allocator: std.mem.Allocator,
    paper_title: []const u8,
    authors: []const u8,
    sections: std.ArrayList(SuppSection),

    pub fn init(allocator: std.mem.Allocator, title: []const u8, authors: []const u8) SuppGenerator {
        return .{
            .allocator = allocator,
            .paper_title = title,
            .authors = authors,
            .sections = std.ArrayList(SuppSection).initCapacity(allocator, 0) catch unreachable,
        };
    }

    pub fn deinit(self: *SuppGenerator) void {
        for (self.sections.items) |*sec| {
            sec.deinit();
        }
        self.sections.deinit(self.allocator);
    }

    pub fn addSection(self: *SuppGenerator, title: []const u8) !*SuppSection {
        try self.sections.append(self.allocator, SuppSection.init(self.allocator, title));
        return &self.sections.items[self.sections.items.len - 1];
    }

    /// Generate LaTeX appendix
    pub fn generateLatex(self: SuppGenerator, writer: anytype) !void {
        try writer.writeAll(
            \\% Supplementary Materials for Trinity S³AI
            \\% Generated automatically - DO NOT EDIT MANUALLY
            \\
            \\\documentclass{article}
            \\\\usepackage[preprint]{neurips_2024}
            \\\\usepackage[utf8]{inputenc}
            \\\\usepackage[T1]{fontenc}
            \\\\usepackage{hyperref}
            \\\\usepackage{url}
            \\\\usepackage{booktabs}
            \\\\usepackage{amsfonts}
            \\\\usepackage{nicefrac}
            \\\\usepackage{microtype}
            \\\\usepackage{xcolor}
            \\\\usepackage{listings}
            \\\\usepackage{algorithm}
            \\\\usepackage{algpseudocode}
            \\
            \\\\title{
        );

        try writer.print("Supplementary Materials for: {s}\n", .{self.paper_title});
        try writer.writeAll("}\n");

        try writer.print("\\author{{{s}}}\n", .{self.authors});
        try writer.writeAll("\\date{\\today}\n\n");

        try writer.writeAll(
            \\\\begin{document}
            \\
            \\\\maketitle
            \\
        );

        for (self.sections.items) |sec| {
            try sec.toLatex(writer, 0);
        }

        try writer.writeAll("\\end{document}\n");
    }

    /// Generate Markdown appendix
    pub fn generateMarkdown(self: SuppGenerator, writer: anytype) !void {
        try writer.print("# Supplementary Materials: {s}\n\n", .{self.paper_title});
        try writer.print("**Authors:** {s}\n\n", .{self.authors});
        try writer.writeAll("---\n\n");

        for (self.sections.items) |sec| {
            try sec.toMarkdown(writer, 0);
        }
    }

    /// Generate experimental results table (LaTeX)
    pub fn generateResultsTable(
        writer: anytype,
        caption: []const u8,
        results: []const ExperimentalResult,
    ) !void {
        try writer.writeAll("\\begin{table}[t]\n");
        try writer.writeAll("\\centering\n");
        try writer.writeAll("\\caption{");
        try writer.writeAll(caption);
        try writer.writeAll("}\n");

        try writer.writeAll(
            \\\\begin{tabular}{lcccc}
            \\\\toprule
            \\Method & Value & Std Error & CI95 & $n$ \\\\
            \\midrule
        );

        for (results) |result| {
            const sig = if (result.significant) "\\textbf{ " else "";

            try writer.print(
                "{s}{s} & {d:.3} & {d:.3} & [{d:.2}, {d:.2}] & {d} \\\\\n",
                .{
                    sig,
                    result.name,
                    result.value,
                    result.std_error,
                    result.ci95_lower,
                    result.ci95_upper,
                    result.n,
                },
            );
        }

        try writer.writeAll(
            \\\\bottomrule
            \\\\end{tabular}
            \\\\label{tab:results}
            \\\\end{table}
            \\
        );
    }

    /// Generate algorithm box (LaTeX)
    pub fn generateAlgorithm(
        writer: anytype,
        name: []const u8,
        caption: []const u8,
        pseudocode: []const u8,
    ) !void {
        try writer.writeAll("\\begin{algorithm}\n");
        try writer.writeAll("\\caption{");
        try writer.writeAll(caption);
        try writer.writeAll("}\n");
        try writer.print("\\label{{alg:{s}}}\n", .{name});
        try writer.writeAll("\\begin{algorithmic}[1]\n");
        try writer.writeAll(pseudocode);
        try writer.writeAll("\\end{algorithmic}\n");
        try writer.writeAll("\\end{algorithm}\n");
    }

    /// Generate code listing (LaTeX)
    pub fn generateCodeListing(
        writer: anytype,
        caption: []const u8,
        language: []const u8,
        code: []const u8,
    ) !void {
        try writer.writeAll("\\begin{figure}[t]\n");
        try writer.writeAll("\\centering\n");
        try writer.writeAll("\\begin{lstlisting}[\n");
        try writer.print("language={},\n", .{language});
        try writer.writeAll("basicstyle=\\footnotesize,\n");
        try writer.writeAll("breaklines=true,\n");
        try writer.writeAll("showstringspaces=false\n");
        try writer.writeAll("]\n");
        try writer.writeAll(code);
        try writer.writeAll("\\end{lstlisting}\n");
        try writer.writeAll("\\caption{");
        try writer.writeAll(caption);
        try writer.writeAll("}\n");
        try writer.writeAll("\\end{figure}\n");
    }

    /// Generate mathematical proof (LaTeX)
    pub fn generateProof(
        writer: anytype,
        theorem_name: []const u8,
        statement: []const u8,
        proof: []const u8,
    ) !void {
        try writer.writeAll("\\begin{theorem}[");
        try writer.writeAll(theorem_name);
        try writer.writeAll("]\n");
        try writer.writeAll(statement);
        try writer.writeAll("\\end{theorem}\n\n");

        try writer.writeAll("\\begin{proof}\n");
        try writer.writeAll(proof);
        try writer.writeAll("\\end{proof}\n\n");
    }
};

/// Create standard NeurIPS supplementary structure
pub fn createNeurIPSSupplementary(allocator: std.mem.Allocator) !SuppGenerator {
    var gen = SuppGenerator.init(
        allocator,
        "Trinity S³AI: Ternary Sparse AI for Edge Deployment",
        "Dmitrii Vasilev",
    );

    // Section 1: Mathematical Proofs
    _ = try gen.addSection("Mathematical Proofs");

    // Section 2: Experimental Setup
    const exp_sec = try gen.addSection("Experimental Setup");
    {
        _ = try exp_sec.addSubsection("Hardware Configuration");
        _ = try exp_sec.addSubsection("Dataset Details");
        _ = try exp_sec.addSubsection("Hyperparameter Settings");
    }

    // Section 3: Additional Results
    const res_sec = try gen.addSection("Additional Results");
    {
        _ = try res_sec.addSubsection("Ablation Studies");
        _ = try res_sec.addSubsection("Convergence Analysis");
        _ = try res_sec.addSubsection("Energy Measurements");
    }

    // Section 4: Code Listings
    _ = try gen.addSection("Code Listings");

    // Section 5: Reproducibility
    const rep_sec = try gen.addSection("Reproducibility");
    {
        _ = try rep_sec.addSubsection("Environment Setup");
        _ = try rep_sec.addSubsection("Data Acquisition");
        _ = try rep_sec.addSubsection("Running Experiments");
    }

    return gen;
}

/// Generate complete NeurIPS supplementary PDF content
pub fn generateNeurIPSSupplementary(allocator: std.mem.Allocator, writer: anytype) !void {
    const gen = try createNeurIPSSupplementary(allocator);
    defer gen.deinit();

    try gen.generateLatex(writer);
}

// Tests
test "SuppSection hierarchy" {
    const allocator = std.testing.allocator;

    var root = SuppSection.init(allocator, "Root");
    defer root.deinit();

    try root.setContent("Root content");

    const sub1 = try root.addSubsection("Sub1");
    try sub1.setContent("Sub1 content");

    const sub2 = try root.addSubsection("Sub2");
    try sub2.setContent("Sub2 content");

    try std.testing.expectEqual(@as(usize, 2), root.subsections.items.len);
}

test "SuppGenerator structure" {
    const allocator = std.testing.allocator;

    var gen = SuppGenerator.init(allocator, "Test Paper", "Test Author");
    defer gen.deinit();

    _ = try gen.addSection("Introduction");
    _ = try gen.addSection("Method");
    _ = try gen.addSection("Results");

    try std.testing.expectEqual(@as(usize, 3), gen.sections.items.len);
}

test "ExperimentalResult table generation" {
    const allocator = std.testing.allocator;

    const results = [_]ExperimentalResult{
        .{
            .name = "Baseline",
            .value = 128.7,
            .std_error = 1.4,
            .ci95_lower = 125.9,
            .ci95_upper = 131.5,
            .n = 5,
            .p_value = null,
            .significant = false,
        },
        .{
            .name = "Sacred Scaling",
            .value = 125.3,
            .std_error = 1.1,
            .ci95_lower = 123.1,
            .ci95_upper = 127.5,
            .n = 5,
            .p_value = 0.0036,
            .significant = true,
        },
    };

    var buffer = std.ArrayList(u8).initCapacity(allocator, 1024) catch unreachable;
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);
    try SuppGenerator.generateResultsTable(writer, "Perplexity Comparison", &results);

    const output = buffer.items;
    try std.testing.expect(std.mem.indexOf(u8, output, "Sacred Scaling") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\\textbf{") != null);
}
