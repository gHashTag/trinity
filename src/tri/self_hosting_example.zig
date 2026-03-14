// @origin(spec:self_hosting_example.tri) @regen(manual-impl)
//! Self-Hosting Loop Example
//!
//! This example demonstrates how to use the Sacred Intelligence
//! self-hosting loop to autonomously improve the agent's own source code.
// @origin(generated) @regen(done)

const std = @import("std");
const self_hosting = @import("self_hosting_loop.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print(
        \\
        \\========================================
        \\SACRED INTELLIGENCE SELF-HOSTING LOOP
        \\========================================
        \\
        \\The agent that improves itself...
        \\
        \\
    , .{});

    // Configure the self-hosting session
    var config = self_hosting.SelfHostingConfig{
        .max_patches = 3, // Maximum 3 self-patches per session
        .confidence_threshold = 0.999, // 99.9% confidence required
        .require_human_approval = false, // Auto-approve high-confidence patches
        .branch_prefix = "self-improve",
        .auto_rebuild = false, // Don't rebuild automatically
        .auto_commit = true, // Commit successful patches
        .auto_push = false, // Don't push to remote
        .test_timeout = 60,
        .verbose = true, // Enable verbose logging
    };

    std.debug.print("Configuration:\n", .{});
    std.debug.print("  Max patches: {d}\n", .{config.max_patches});
    std.debug.print("  Confidence threshold: {d:.3}%\n", .{config.confidence_threshold * 100});
    std.debug.print("  Human approval: {}\n", .{config.require_human_approval});
    std.debug.print("\n", .{});

    std.debug.print("Starting self-hosting session...\n\n", .{});

    // Run the self-hosting loop
    const result = try self_hosting.runSelfHostingLoop(allocator, config);

    // Display results
    std.debug.print("\n", .{});
    std.debug.print("========================================\n", .{});
    std.debug.print("SESSION COMPLETE\n", .{});
    std.debug.print("========================================\n", .{});
    std.debug.print("Success: {}\n", .{result.success});
    std.debug.print("Patches applied: {d}\n", .{result.patches_applied});
    std.debug.print("Patches successful: {d}\n", .{result.patches_successful});

    if (result.branch_name) |branch| {
        std.debug.print("Branch: {s}\n", .{branch});
        allocator.free(branch);
    }

    if (result.commit_hash) |hash| {
        std.debug.print("Commit: {s}\n", .{hash});
        allocator.free(hash);
    }

    if (result.error_message) |msg| {
        std.debug.print("Error: {s}\n", .{msg});
        allocator.free(msg);
    }

    std.debug.print("\n", .{});
    std.debug.print("The Sacred Intelligence agent has improved itself.\n", .{});
    std.debug.print("φ² + 1/φ² = 3  (Trinity Identity)\n", .{});
}
