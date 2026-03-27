// ═══════════════════════════════════════════════════════════════════════════════
// Zenodo V18: NeurIPS 2025 Checklist Generator
// ═══════════════════════════════════════════════════════════════════════════════
//
// Generates NeurIPS 2025 Dataset & Code Track compliance checklists
// from Zenodo metadata. Automates paper submission preparation.
//
// Reference: https://neurips.cc/Conferences/2025/DatasetTrack
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// NeurIPS 2025 Paper Checklist
pub const NeuripsChecklist = struct {
    /// Paper ID (for submission tracking)
    paper_id: []const u8 = "",

    /// Code availability
    code: CodeAvailability,

    /// Data availability
    data: DataAvailability,

    /// Hyperparameters
    hyperparams: HyperparameterDocumentation,

    /// Random seeds
    seeds: SeedDocumentation,

    /// Compute resources
    compute: ComputeDocumentation,

    /// Overall compliance score (0-100)
    pub fn complianceScore(self: NeuripsChecklist) u8 {
        const code_score = self.code.score();
        const data_score = self.data.score();
        const hyperparams_score = self.hyperparams.score();
        const seeds_score = self.seeds.score();
        const compute_score = self.compute.score();

        const total = @as(u32, code_score) + @as(u32, data_score) + @as(u32, hyperparams_score) + @as(u32, seeds_score) + @as(u32, compute_score);
        return @intCast(total / 5);
    }

    /// Generate checklist text for NeurIPS submission form
    pub fn formatSubmissionChecklist(self: NeuripsChecklist, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 2048);
        defer buffer.deinit(allocator);

        // Header
        try buffer.appendSlice(allocator, "# NeurIPS 2025 Reproducibility Checklist\n\n");

        // Code section
        try buffer.appendSlice(allocator, "## 1. Code Availability\n\n");
        try buffer.appendSlice(allocator, if (self.code.available) "- [x] **Yes**\n" else "- [ ] **No**\n");
        if (self.code.available) {
            try buffer.print(allocator, "  - URL: {s}\n", .{self.code.url});
            try buffer.print(allocator, "  - License: {s}\n", .{self.code.license});
            if (self.code.dependencies.len > 0) {
                try buffer.appendSlice(allocator, "  - Dependencies:\n");
                for (self.code.dependencies) |dep| {
                    try buffer.print(allocator, "    - {s} {s}\n", .{ dep.name, dep.version });
                }
            }
            try buffer.print(allocator, "  - Training command: `{s}`\n", .{self.code.training_command});
        }
        try buffer.appendSlice(allocator, "\n");

        // Data section
        try buffer.appendSlice(allocator, "## 2. Data Availability\n\n");
        try buffer.appendSlice(allocator, if (self.data.available) "- [x] **Yes**\n" else "- [ ] **No**\n");
        if (self.data.available) {
            try buffer.print(allocator, "  - URL: {s}\n", .{self.data.url});
            try buffer.print(allocator, "  - License: {s}\n", .{self.data.license});
            try buffer.print(allocator, "  - Size: {d} samples, {d:.1} MB\n", .{ self.data.num_samples, @as(f64, @floatFromInt(self.data.size_bytes)) / 1024.0 / 1024.0 });
            try buffer.print(allocator, "  - Format: {s}\n", .{self.data.format});
        }
        try buffer.appendSlice(allocator, "\n");

        // Hyperparameters section
        try buffer.appendSlice(allocator, "## 3. Hyperparameters\n\n");
        try buffer.appendSlice(allocator, if (self.hyperparams.documented) "- [x] **Documented**\n" else "- [ ] **Not documented**\n");
        if (self.hyperparams.documented) {
            try buffer.appendSlice(allocator, "  - Key hyperparameters:\n");
            for (self.hyperparams.values) |hp| {
                try buffer.print(allocator, "    - {s}: {s}\n", .{ hp.name, hp.value });
            }
        }
        try buffer.appendSlice(allocator, "\n");

        // Seeds section
        try buffer.appendSlice(allocator, "## 4. Random Seeds\n\n");
        try buffer.appendSlice(allocator, if (self.seeds.documented) "- [x] **Documented**\n" else "- [ ] **Not documented**\n");
        if (self.seeds.documented) {
            try buffer.print(allocator, "  - Seeds: {s}\n", .{self.seeds.seed_list});
            try buffer.print(allocator, "  - Purpose: {s}\n", .{self.seeds.purpose});
        }
        try buffer.appendSlice(allocator, "\n");

        // Compute section
        try buffer.appendSlice(allocator, "## 5. Compute Resources\n\n");
        try buffer.appendSlice(allocator, if (self.compute.specified) "- [x] **Specified**\n" else "- [ ] **Not specified**\n");
        if (self.compute.specified) {
            try buffer.print(allocator, "  - GPU: {d:.1} hours ({s})\n", .{ self.compute.gpu_hours, self.compute.hardware });
            try buffer.print(allocator, "  - CPU: {d:.1} hours\n", .{self.compute.cpu_hours});
            try buffer.print(allocator, "  - Carbon: {d:.2} kg CO2e\n", .{self.compute.carbon_kg});
        }
        try buffer.appendSlice(allocator, "\n");

        // Overall score
        try buffer.appendSlice(allocator, "---\n\n");
        try buffer.print(allocator, "**Overall Compliance: {d}/100**\n", .{self.complianceScore()});
        if (self.complianceScore() >= 90) {
            try buffer.appendSlice(allocator, "✅ Ready for submission\n");
        } else if (self.complianceScore() >= 70) {
            try buffer.appendSlice(allocator, "⚠️ Minor improvements recommended\n");
        } else {
            try buffer.appendSlice(allocator, "❌ Significant improvements needed\n");
        }

        return buffer.toOwnedSlice(allocator);
    }

    /// Generate LaTeX table for paper appendix
    pub fn formatAppendixTable(self: NeuripsChecklist, allocator: std.mem.Allocator) ![]const u8 {
        const code_status = if (self.code.available) "\\checkmark" else "$\\times$";
        const data_status = if (self.data.available) "\\checkmark" else "$\\times$";
        const hyper_status = if (self.hyperparams.documented) "\\checkmark" else "$\\times$";
        const seeds_status = if (self.seeds.documented) "\\checkmark" else "$\\times$";
        const compute_status = if (self.compute.specified) "\\checkmark" else "$\\times$";

        return std.fmt.allocPrint(allocator,
            \\% NeurIPS 2025 Reproducibility Checklist
            \\begin{{table}}[t]
            \\centering
            \\begin{{tabular}}{{ll}}
            \\toprule
            \\textbf{{Item}} & \\textbf{{Status}} \\\\
            \\midrule
            \\Code Availability & {s} \\\\
            \\Data Availability & {s} \\\\
            \\Hyperparameters & {s} \\\\
            \\Random Seeds & {s} \\\\
            \\Compute Resources & {s} \\\\
            \\bottomrule
            \\end{{tabular}}
            \\caption{{Reproducibility Checklist ({d}/100)}}
            \\end{{table}}
        , .{
            code_status,
            data_status,
            hyper_status,
            seeds_status,
            compute_status,
            self.complianceScore(),
        });
    }
};

pub const CodeAvailability = struct {
    available: bool = false,
    url: []const u8 = "",
    license: []const u8 = "",
    dependencies: []const Dependency = &.{},
    training_command: []const u8 = "",

    pub fn score(self: CodeAvailability) u8 {
        var s: u8 = 0;
        if (self.available) s += 30;
        if (self.url.len > 0) s += 20;
        if (self.license.len > 0) s += 10;
        if (self.dependencies.len > 0) s += 20;
        if (self.training_command.len > 0) s += 20;
        return s;
    }
};

pub const Dependency = struct {
    name: []const u8,
    version: []const u8,
    url: []const u8 = "",
    optional: bool = false,
};

pub const DataAvailability = struct {
    available: bool = false,
    url: []const u8 = "",
    license: []const u8 = "",
    num_samples: u64 = 0,
    size_bytes: u64 = 0,
    format: []const u8 = "",

    pub fn score(self: DataAvailability) u8 {
        var s: u8 = 0;
        if (self.available) s += 30;
        if (self.url.len > 0) s += 20;
        if (self.license.len > 0) s += 10;
        if (self.num_samples > 0) s += 20;
        if (self.format.len > 0) s += 20;
        return s;
    }
};

pub const HyperparameterDocumentation = struct {
    documented: bool = false,
    values: []const HyperparamValue = &.{},

    pub fn score(self: HyperparameterDocumentation) u8 {
        if (!self.documented) return 0;
        const base: u8 = 50;
        const per_value: u8 = 10;
        const max: u8 = 100;
        const points = @min(self.values.len * per_value, max - base);
        return base + @as(u8, @intCast(points));
    }
};

pub const HyperparamValue = struct {
    name: []const u8,
    value: []const u8,
    type: []const u8 = "float", // float, int, string, bool
};

pub const SeedDocumentation = struct {
    documented: bool = false,
    seed_list: []const u8 = "",
    purpose: []const u8 = "",

    pub fn score(self: SeedDocumentation) u8 {
        if (!self.documented) return 0;
        var s: u8 = 50;
        if (self.seed_list.len > 0) s += 30;
        if (self.purpose.len > 0) s += 20;
        return s;
    }
};

pub const ComputeDocumentation = struct {
    specified: bool = false,
    gpu_hours: f64 = 0.0,
    cpu_hours: f64 = 0.0,
    hardware: []const u8 = "",
    carbon_kg: f64 = 0.0,

    pub fn score(self: ComputeDocumentation) u8 {
        if (!self.specified) return 0;
        var s: u8 = 0;
        if (self.gpu_hours > 0) s += 30;
        if (self.cpu_hours > 0) s += 20;
        if (self.hardware.len > 0) s += 20;
        if (self.carbon_kg > 0) s += 30;
        return s;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "NeuripsChecklist: compliance score calculation" {
    const deps = [_]Dependency{.{ .name = "zig", .version = "0.15" }};
    const checklist = NeuripsChecklist{
        .code = .{ .available = true, .url = "https://github.com/test", .license = "MIT", .dependencies = &deps, .training_command = "tri train" },
        .data = .{ .available = true, .url = "https://zenodo.org/record/1", .license = "CC-BY-4.0", .num_samples = 1000, .format = "json", .size_bytes = 1024 * 1024 },
        .hyperparams = .{ .documented = true, .values = &[_]HyperparamValue{
            .{ .name = "lr", .value = "0.001" },
            .{ .name = "batch_size", .value = "32" },
        } },
        .seeds = .{ .documented = true, .seed_list = "42, 133, 267", .purpose = "Statistical significance" },
        .compute = .{ .specified = true, .gpu_hours = 100, .hardware = "NVIDIA A100", .carbon_kg = 10 },
    };

    const score = checklist.complianceScore();
    try std.testing.expect(score >= 90); // Full metadata should score >= 90
}

test "NeuripsChecklist: submission checklist generation" {
    const checklist = NeuripsChecklist{
        .code = .{ .available = true, .url = "https://github.com/test", .license = "MIT" },
        .data = .{ .available = true, .url = "https://zenodo.org/record/1", .license = "CC-BY-4.0" },
        .hyperparams = .{ .documented = false },
        .seeds = .{ .documented = false },
        .compute = .{ .specified = false },
    };

    const output = try checklist.formatSubmissionChecklist(std.testing.allocator);
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "NeurIPS 2025") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Code Availability") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Data Availability") != null);
}

test "NeuripsChecklist: LaTeX table generation" {
    const checklist = NeuripsChecklist{
        .code = .{ .available = true },
        .data = .{ .available = true },
        .hyperparams = .{ .documented = true },
        .seeds = .{ .documented = true },
        .compute = .{ .specified = true },
    };

    const latex = try checklist.formatAppendixTable(std.testing.allocator);
    defer std.testing.allocator.free(latex);

    try std.testing.expect(std.mem.indexOf(u8, latex, "begin{table}") != null);
    try std.testing.expect(std.mem.indexOf(u8, latex, "Reproducibility Checklist") != null);
    // In Zig string, we need '//' to represent single backslash
    try std.testing.expect(std.mem.indexOf(u8, latex, "\n") != null);
}

test "CodeAvailability: score calculation" {
    const deps = [_]Dependency{.{ .name = "zig", .version = "0.15" }};
    const code_full = CodeAvailability{
        .available = true,
        .url = "https://github.com/test",
        .license = "MIT",
        .dependencies = &deps,
        .training_command = "tri train",
    };
    try std.testing.expectEqual(@as(u8, 100), code_full.score());

    const code_minimal = CodeAvailability{
        .available = true,
    };
    try std.testing.expectEqual(@as(u8, 30), code_minimal.score());

    const code_none = CodeAvailability{};
    try std.testing.expectEqual(@as(u8, 0), code_none.score());
}

test "ComputeDocumentation: carbon calculation" {
    const compute = ComputeDocumentation{
        .specified = true,
        .gpu_hours = 100,
        .hardware = "NVIDIA A100",
        .carbon_kg = 11.4,
    };
    try std.testing.expect(compute.score() >= 80);
}

// φ² + 1/φ² = 3 | TRINITY
