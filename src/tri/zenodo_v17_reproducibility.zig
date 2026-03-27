// ═══════════════════════════════════════════════════════════════════════════════════
// Zenodo V17: Reproducibility Checklist (NeurIPS 2025 / ICLR 2025)
// ═════════════════════════════════════════════════════════════════════════════════════
//
// NeurIPS 2025 Dataset Track Requirements:
// - Code: Publicly available with open license
// - Data: Publicly available with clear provenance
// - Hyperparameters: Fully documented
// - Random Seeds: All experiments use documented seeds
// - Compute: Hardware and time requirements specified
//
// ICLR 2025 Requirements:
// - Checklist must be completed for submission
// - Failure to comply = desk rejection
// ═════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════════
// TYPES
// ═════════════════════════════════════════════════════════════════════════════════════

/// Code Availability
pub const CodeAvailability = enum {
    unavailable,
    on_request,
    restricted_access,
    open_source,

    pub fn toScore(self: CodeAvailability) u8 {
        return switch (self) {
            .unavailable => 0,
            .on_request => 10,
            .restricted_access => 20,
            .open_source => 30,
        };
    }
};

/// Data Availability
pub const DataAvailability = enum {
    unavailable,
    synthetic_only,
    partial,
    full_with_license,
    full_cc_by,

    pub fn toScore(self: DataAvailability) u8 {
        return switch (self) {
            .unavailable => 0,
            .synthetic_only => 10,
            .partial => 15,
            .full_with_license => 20,
            .full_cc_by => 25,
        };
    }
};

/// Reproducibility Checklist (NeurIPS 2025)
pub const ReproducibilityChecklist = struct {
    // Code availability (30 points max)
    code_available: bool = false,
    code_url: ?[]const u8 = null,
    code_license: ?[]const u8 = null,

    // Data availability (25 points max)
    data_available: bool = false,
    data_url: ?[]const u8 = null,
    data_license: ?[]const u8 = null,
    data_size_bytes: u64 = 0,

    // Hyperparameters (15 points max)
    hyperparams_documented: bool = false,
    hyperparams_url: ?[]const u8 = null,

    // Random seeds (10 points max)
    seeds_documented: bool = false,
    seed_value: ?u64 = null,

    // Compute requirements (20 points max)
    compute_specified: bool = false,
    gpu_hours: ?f64 = null,
    cpu_hours: ?f64 = null,
    hardware: ?[]const u8 = null,
    framework: ?[]const u8 = null,

    /// Overall score (0-100)
    pub fn score(self: ReproducibilityChecklist) u8 {
        var s: u8 = 0;

        // Code (30 points max)
        if (self.code_available) s += 15;
        if (self.code_url != null) s += 10;
        if (self.code_license != null) s += 5;

        // Data (25 points max)
        if (self.data_available) s += 15;
        if (self.data_url != null) s += 5;
        if (self.data_license != null) s += 5;

        // Hyperparameters (15 points max)
        if (self.hyperparams_documented) s += 10;
        if (self.hyperparams_url != null) s += 5;

        // Seeds (10 points max)
        if (self.seeds_documented) s += 10;

        // Compute (20 points max)
        if (self.compute_specified) s += 5;
        if (self.gpu_hours != null) s += 5;
        if (self.hardware != null) s += 5;
        if (self.framework != null) s += 5;

        return @min(s, 100);
    }

    /// Grade (A/B/C/D/F)
    pub fn grade(self: ReproducibilityChecklist) []const u8 {
        const s = self.score();
        if (s >= 90) return "A (Excellent)";
        if (s >= 75) return "B (Good)";
        if (s >= 60) return "C (Acceptable)";
        if (s >= 40) return "D (Poor)";
        return "F (Unacceptable)";
    }

    /// Meets conference requirements
    pub fn meetsConference(self: ReproducibilityChecklist) bool {
        return self.score() >= 80; // NeurIPS minimum
    }

    /// Format as checklist (for paper submission)
    pub fn formatPaperChecklist(self: ReproducibilityChecklist, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 0);
        defer buffer.deinit(allocator);

        try buffer.appendSlice(allocator, "═════════════════════════════════════════════════════════════\n");
        try buffer.appendSlice(allocator, "Reproducibility Checklist (NeurIPS 2025 / ICLR 2025)\n");
        try buffer.appendSlice(allocator, "═════════════════════════════════════════════════════════════\n\n");

        // 1. Code
        const code_status = if (self.code_available) "[Yes]" else "[No]";
        try buffer.appendSlice(allocator, "1. Code: ");
        try buffer.appendSlice(allocator, code_status);
        if (self.code_url) |url| {
            try buffer.print(allocator, " Available at {s}\n", .{url});
        } else {
            try buffer.appendSlice(allocator, "\n");
        }
        if (self.code_license) |license| {
            try buffer.print(allocator, "   - License: {s}\n", .{license});
        }

        // 2. Data
        const data_status = if (self.data_available) "[Yes]" else "[No]";
        try buffer.appendSlice(allocator, "2. Data: ");
        try buffer.appendSlice(allocator, data_status);
        if (self.data_url) |url| {
            try buffer.print(allocator, " Available at {s}\n", .{url});
        } else {
            try buffer.appendSlice(allocator, "\n");
        }
        if (self.data_license) |license| {
            try buffer.print(allocator, "   - License: {s}\n", .{license});
        }
        if (self.data_size_bytes > 0) {
            const size_mb = @as(f64, @floatFromInt(self.data_size_bytes)) / 1024.0 / 1024.0;
            try buffer.print(allocator, "   - Size: {d:.1} MB\n", .{size_mb});
        }

        // 3. Hyperparameters
        const hyperparams_status = if (self.hyperparams_documented) "[Yes]" else "[No]";
        try buffer.appendSlice(allocator, "3. Hyperparameters: ");
        try buffer.appendSlice(allocator, hyperparams_status);
        if (self.hyperparams_url) |url| {
            try buffer.print(allocator, " Documented at {s}\n", .{url});
        } else {
            try buffer.appendSlice(allocator, "\n");
        }

        // 4. Random Seeds
        const seeds_status = if (self.seeds_documented) "[Yes]" else "[No]";
        try buffer.appendSlice(allocator, "4. Random Seeds: ");
        try buffer.appendSlice(allocator, seeds_status);
        if (self.seed_value) |seed| {
            try buffer.print(allocator, " All experiments use seed={d}\n", .{seed});
        } else {
            try buffer.appendSlice(allocator, "\n");
        }

        // 5. Compute Requirements
        const compute_status = if (self.compute_specified) "[Yes]" else "[No]";
        try buffer.appendSlice(allocator, "5. Compute: ");
        try buffer.appendSlice(allocator, compute_status);
        if (self.hardware) |hw| {
            try buffer.print(allocator, " Hardware: {s}\n", .{hw});
        }
        if (self.gpu_hours) |hours| {
            try buffer.print(allocator, " GPU-hours: {d:.1}\n", .{hours});
        }
        if (self.framework) |fw| {
            try buffer.print(allocator, " Framework: {s}\n", .{fw});
        }

        try buffer.appendSlice(allocator, "\n");
        try buffer.print(allocator, "Overall Score: {d}/100 ({s})\n", .{ self.score(), self.grade() });
        try buffer.appendSlice(allocator, "Conference Ready: ");
        try buffer.appendSlice(allocator, if (self.meetsConference()) "Yes" else "No");
        try buffer.appendSlice(allocator, "\n");

        try buffer.appendSlice(allocator, "═════════════════════════════════════════════════════════════\n");

        return buffer.toOwnedSlice(allocator);
    }

    /// Format recommendations
    pub fn formatRecommendations(self: ReproducibilityChecklist, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 0);
        defer buffer.deinit(allocator);

        if (!self.code_available) {
            try buffer.appendSlice(allocator, "• Publish code to GitHub with open license (MIT/Apache2.0)\n");
        }
        if (self.code_url == null and self.code_available) {
            try buffer.appendSlice(allocator, "• Add code URL to metadata\n");
        }
        if (self.code_license == null and self.code_available) {
            try buffer.appendSlice(allocator, "• Specify code license (MIT recommended)\n");
        }

        if (!self.data_available) {
            try buffer.appendSlice(allocator, "• Publish dataset to Zenodo with CC-BY license\n");
        }
        if (self.data_url == null and self.data_available) {
            try buffer.appendSlice(allocator, "• Add dataset URL to metadata\n");
        }

        if (!self.hyperparams_documented) {
            try buffer.appendSlice(allocator, "• Document all hyperparameters in Table format\n");
            try buffer.appendSlice(allocator, "  Include: learning rate, batch size, optimizer, scheduler\n");
        }

        if (!self.seeds_documented) {
            try buffer.appendSlice(allocator, "• Specify random seeds for all experiments\n");
            try buffer.appendSlice(allocator, "  Use a fixed seed for reproducibility testing\n");
        }

        if (!self.compute_specified) {
            try buffer.appendSlice(allocator, "• Specify hardware and compute requirements\n");
            try buffer.appendSlice(allocator, "  Include: GPU type, GPU-hours, framework version\n");
        }

        if (buffer.items.len == 0) {
            try buffer.appendSlice(allocator, "✅ All requirements met! Excellent reproducibility.\n");
        }

        return buffer.toOwnedSlice(allocator);
    }
};

/// Checklist item for detailed breakdown
pub const ChecklistDetail = struct {
    category: []const u8,
    item: []const u8,
    points: u8,
    max_points: u8,
    passed: bool,
};

/// Detailed checklist with breakdown
pub const DetailedChecklist = struct {
    items: []ChecklistDetail,

    pub fn init(allocator: std.mem.Allocator) DetailedChecklist {
        return .{ .items = std.ArrayList(ChecklistDetail).initCapacity(allocator, 0) };
    }

    pub fn deinit(self: *DetailedChecklist) void {
        self.items.deinit();
    }

    /// Add item
    pub fn add(self: *DetailedChecklist, item: ChecklistDetail) !void {
        try self.items.append(item);
    }

    /// Total score
    pub fn score(self: DetailedChecklist) u8 {
        var total: u8 = 0;
        for (self.items.items) |item| {
            if (item.passed) total += item.points;
        }
        return total;
    }

    /// Format detailed output
    pub fn format(self: DetailedChecklist, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 0);
        defer buffer.deinit(allocator);

        try buffer.appendSlice(allocator, "═══════════════════════════════════════════════════════════════\n");
        try buffer.appendSlice(allocator, "Detailed Reproducibility Checklist\n");
        try buffer.appendSlice(allocator, "═════════════════════════════════════════════════════════════\n\n");

        var current_category: ?[]const u8 = null;
        for (self.items.items) |item| {
            // Category header
            if (current_category == null or !std.mem.eql(u8, item.category, current_category.?)) {
                try buffer.print(allocator, "\n[{s}]\n", .{item.category});
                current_category = item.category;
            }

            const status = if (item.passed) "✅" else "❌";
            try buffer.print(allocator, "  {s} {s}: {d}/{d}\n", .{ status, item.item, item.points, item.max_points });
        }

        try buffer.print(allocator, "\nTotal Score: {d}/100\n", .{self.score()});

        try buffer.appendSlice(allocator, "═════════════════════════════════════════════════════════════\n");

        return buffer.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════════

/// Create HSLM training checklist (Trinity specific)
pub fn createHSLMChecklist(
    gpu_hours: f64,
    data_url: []const u8,
) ReproducibilityChecklist {
    return .{
        // Code
        .code_available = true,
        .code_url = "https://github.com/gHashTag/trinity",
        .code_license = "MIT",

        // Data
        .data_available = true,
        .data_url = data_url,
        .data_license = "CC-BY-4.0",
        .data_size_bytes = 386 * 1024, // 386 KB model

        // Hyperparameters
        .hyperparams_documented = true,
        .hyperparams_url = "https://github.com/gHashTag/trinity/blob/main/docs/HYPERPARAMETERS.md",

        // Seeds
        .seeds_documented = true,
        .seed_value = 42,

        // Compute
        .compute_specified = true,
        .gpu_hours = gpu_hours,
        .hardware = "NVIDIA A100 80GB",
        .framework = "Zig 0.15 + custom CUDA kernel",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════

test "Reproducibility: empty checklist score" {
    const empty = ReproducibilityChecklist{};
    try std.testing.expectEqual(@as(u8, 0), empty.score());
    try std.testing.expect(!empty.meetsConference());
}

test "Reproducibility: full checklist score" {
    const full = ReproducibilityChecklist{
        .code_available = true,
        .code_url = "https://github.com/test",
        .code_license = "MIT",
        .data_available = true,
        .data_url = "https://zenodo.org/test",
        .data_license = "CC-BY-4.0",
        .hyperparams_documented = true,
        .hyperparams_url = "https://github.com/test/hyperparams",
        .seeds_documented = true,
        .seed_value = 42,
        .compute_specified = true,
        .gpu_hours = 100.0,
        .hardware = "NVIDIA A100",
        .framework = "PyTorch",
    };

    try std.testing.expect(full.score() >= 95);
    try std.testing.expect(full.meetsConference());
    try std.testing.expect(std.mem.eql(u8, "A (Excellent)", full.grade()));
}

test "Reproducibility: HSLM checklist" {
    const hslm = createHSLMChecklist(150.0, "https://zenodo.org/test");
    try std.testing.expect(hslm.meetsConference());
    try std.testing.expect(hslm.score() >= 90);
}

test "Reproducibility: paper checklist formatting" {
    const checklist = ReproducibilityChecklist{
        .code_available = true,
        .code_url = "https://github.com/test",
        .code_license = "MIT",
        .data_available = true,
        .data_url = "https://zenodo.org/test",
        .data_license = "CC-BY-4.0",
        .hyperparams_documented = true,
        .seeds_documented = true,
        .seed_value = 42,
        .compute_specified = true,
        .gpu_hours = 100.0,
        .hardware = "NVIDIA A100",
        .framework = "Zig",
    };

    const formatted = try checklist.formatPaperChecklist(std.testing.allocator);
    defer std.testing.allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "NeurIPS 2025") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Code: [Yes]") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Conference Ready: Yes") != null);
}

test "Reproducibility: recommendations for empty" {
    const empty = ReproducibilityChecklist{};
    const recs = try empty.formatRecommendations(std.testing.allocator);
    defer std.testing.allocator.free(recs);

    try std.testing.expect(std.mem.indexOf(u8, recs, "GitHub") != null);
    try std.testing.expect(std.mem.indexOf(u8, recs, "Zenodo") != null);
}

// φ² + 1/φ² = 3 | TRINITY
