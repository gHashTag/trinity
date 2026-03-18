//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEE v10.6: Factory Orchestrator
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Reads .tri specifications, generates synthetic seeds,
//! validates through 4-tier system, and stores verified seeds in Golden DB.
//!
//! φ² + 1/φ² = 3
//!
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayListManaged = std.array_list.AlignedManaged;

const vibee_parser = @import("vibee_parser.zig");
const golden_db = @import("golden_db.zig");
const synthetic_seed_gen = @import("synthetic_seed_gen.zig");
const verified_seed_validator = @import("verified_seed_validator.zig");

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    std.debug.print(
        \\╔════════════════════════════════════════════════════════════════╗
        \\║  VIBEE v10.6: Factory Orchestrator                             ║
        \\╚════════════════════════════════════════════════════════════════╝
        \\
    , .{});

    // Initialize components
    var db = try golden_db.GoldenDB.init(gpa);
    defer db.deinit();

    var validator = try verified_seed_validator.VerifiedSeedValidator.init(gpa, &db);
    defer validator.deinit();

    var gen = synthetic_seed_gen.SyntheticSeedGenerator.init(gpa, &db);

    // Find and parse all .tri files
    const spec_files = try findVibeeFiles(gpa, "specs/tri");
    defer gpa.free(spec_files);

    std.debug.print("  Found {d} .tri specification files\n", .{spec_files.len});

    var total_behaviors: u32 = 0;
    var generated_seeds: u32 = 0;
    var verified_seeds: u32 = 0;

    // Stats for tracking
    var stats = verified_seed_validator.VerificationStats{};

    // Process each spec file
    for (spec_files) |file_path| {
        const spec_name = std.fs.path.basename(file_path);

        // Parse the spec file
        var spec = vibee_parser.VibeeSpec.init(gpa);
        defer spec.deinit();

        // Simple YAML parser to extract behaviors
        const behaviors = try extractBehaviorsFromFile(gpa, file_path);
        defer {
            for (behaviors) |b| {
                gpa.free(b.name);
                gpa.free(b.given);
                gpa.free(b.when);
                gpa.free(b.then);
            }
            gpa.free(behaviors);
        }

        std.debug.print("  [{s}] {d} behaviors\n", .{ spec_name, behaviors.len });
        total_behaviors += @intCast(behaviors.len);

        // Generate and validate seeds for each behavior
        for (behaviors) |behavior| {
            // Generate synthetic seed
            const seed_opt = try gen.generateForBehavior(behavior.name, 0.75);
            if (seed_opt) |seed| {
                generated_seeds += 1;

                // Validate through 4-tier system
                const result = try validator.validateSeed(&seed);

                // Track stats
                stats.total_processed += 1;
                if (result.compile.compiled) stats.compile_passed += 1;
                if (result.runtime.passed) stats.runtime_passed += 1;
                if (result.semantic.isPassing(validator.min_quality)) stats.semantic_passed += 1;
                if (result.uniqueness.is_unique) stats.unique_seeds += 1;
                if (result.verified) {
                    stats.verified += 1;
                    verified_seeds += 1;
                    stats.total_tri_earned += result.tri_reward;

                    // Add to Golden DB
                    try db.addNewSeed(
                        seed.name,
                        seed.signature,
                        seed.body,
                        seed.category,
                    );
                }
            }
        }
    }

    // Save Golden DB
    try db.save();

    // Calculate pass rates
    const tier1_rate: f32 = if (stats.total_processed > 0)
        @as(f32, @floatFromInt(stats.compile_passed)) / @as(f32, @floatFromInt(stats.total_processed)) * 100
    else
        0;

    const tier2_rate: f32 = if (stats.compile_passed > 0)
        @as(f32, @floatFromInt(stats.runtime_passed)) / @as(f32, @floatFromInt(stats.compile_passed)) * 100
    else
        0;

    const tier3_rate: f32 = if (stats.runtime_passed > 0)
        @as(f32, @floatFromInt(stats.semantic_passed)) / @as(f32, @floatFromInt(stats.runtime_passed)) * 100
    else
        0;

    // Print final report
    std.debug.print(
        \\
        \\╔════════════════════════════════════════════════════════════════╗
        \\║  FACTORY REPORT                                              ║
        \\╠════════════════════════════════════════════════════════════════╣
        \\║  Total Behaviors:      {d:6}                               ║
        \\║  Seeds Generated:       {d:6}                               ║
        \\║  ───────────────────────────────────────────────────────────  ║
        \\║  Tier 1 (Compile):      {d:5} / {d:5} ({d:.1}%)                ║
        \\║  Tier 2 (Runtime):      {d:5} / {d:5} ({d:.1}%)                ║
        \\║  Tier 3 (Semantic):     {d:5} / {d:5} ({d:.1}%)                ║
        \\║  Tier 4 (Unique):       {d:5} / {d:5} ({d:.1}%)                ║
        \\║  ───────────────────────────────────────────────────────────  ║
        \\║  *** VERIFIED: {d:6} ***                                     ║
        \\║  $TRI Earned:         {d:.1}                               ║
        \\╚════════════════════════════════════════════════════════════════╝
        \\
    , .{
        total_behaviors,
        generated_seeds,
        stats.compile_passed,
        stats.total_processed,
        tier1_rate,
        stats.runtime_passed,
        stats.compile_passed,
        tier2_rate,
        stats.semantic_passed,
        stats.runtime_passed,
        tier3_rate,
        stats.unique_seeds,
        stats.semantic_passed,
        @as(f32, @floatFromInt(stats.unique_seeds)) / @as(f32, @floatFromInt(stats.semantic_passed)) * 100,
        stats.verified,
        stats.total_tri_earned,
    });

    // Success check
    if (stats.verified >= 300) {
        std.debug.print("\n  ✅ SUCCESS: Target of 300 verified seeds achieved!\n", .{});
    } else {
        std.debug.print("\n  ⚠ WARNING: {d} / 300 verified seeds ({d:.1}%)\n", .{ stats.verified, @as(f32, @floatFromInt(stats.verified)) / 300 * 100 });
    }
}

/// Find all .tri files in a directory
fn findVibeeFiles(allocator: Allocator, dir_path: []const u8) ![][]const u8 {
    var files = ArrayListManaged([]const u8, null).init(allocator);

    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".tri")) {
            const paths = &[_][]const u8{ dir_path, entry.name };
            const full_path = try std.fs.path.join(allocator, paths);
            try files.append(full_path);
        }
    }

    return files.toOwnedSlice();
}

/// Behavior struct returned by extractBehaviorsFromFile
const BehaviorStruct = struct {
    name: []const u8,
    given: []const u8,
    when: []const u8,
    then: []const u8,
};

/// Simple YAML parser to extract behavior names from a .tri file
fn extractBehaviorsFromFile(allocator: Allocator, file_path: []const u8) ![]const BehaviorStruct {
    const content = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024);
    defer allocator.free(content);

    var behaviors = ArrayListManaged(BehaviorStruct, null).init(allocator);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var in_behaviors = false;
    var current_behavior: ?BehaviorStruct = null;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        if (std.mem.startsWith(u8, trimmed, "behaviors:")) {
            in_behaviors = true;
            continue;
        }

        if (!in_behaviors) continue;

        // Check for behavior entry: "- name: something"
        if (std.mem.startsWith(u8, trimmed, "- name:")) {
            // Save previous behavior if exists
            if (current_behavior) |cb| {
                try behaviors.append(cb);
            }

            const name = std.mem.trim(u8, trimmed["- name:".len..], " \t\r");
            current_behavior = .{
                .name = try allocator.dupe(u8, name),
                .given = "",
                .when = "",
                .then = "",
            };
        } else if (current_behavior != null) {
            if (std.mem.startsWith(u8, trimmed, "given:")) {
                const value = std.mem.trim(u8, trimmed["given:".len..], " \t\r");
                const cb = &current_behavior.?;
                cb.given = try allocator.dupe(u8, value);
            } else if (std.mem.startsWith(u8, trimmed, "when:")) {
                const value = std.mem.trim(u8, trimmed["when:".len..], " \t\r");
                const cb = &current_behavior.?;
                cb.when = try allocator.dupe(u8, value);
            } else if (std.mem.startsWith(u8, trimmed, "then:")) {
                const value = std.mem.trim(u8, trimmed["then:".len..], " \t\r");
                const cb = &current_behavior.?;
                cb.then = try allocator.dupe(u8, value);
            }
        }
    }

    // Save last behavior
    if (current_behavior) |cb| {
        try behaviors.append(cb);
    }

    // Return array of behaviors
    return behaviors.toOwnedSlice();
}
