const std = @import("std");

// Build file for trinity-tools module (Zig 0.15.x)
// Part of Trinity Nexus modular architecture — NEXUS-008 wired
// Dependencies: trinity-core, trinity-lang, trinity-symb, trinity-network, trinity-canvas

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Resolve dependencies from build.zig.zon
    const core_dep = b.dependency("trinity_core", .{
        .target = target,
        .optimize = optimize,
    });
    const lang_dep = b.dependency("trinity_lang", .{
        .target = target,
        .optimize = optimize,
    });
    const symb_dep = b.dependency("trinity_symb", .{
        .target = target,
        .optimize = optimize,
    });
    const network_dep = b.dependency("trinity_network", .{
        .target = target,
        .optimize = optimize,
    });
    const canvas_dep = b.dependency("trinity_canvas", .{
        .target = target,
        .optimize = optimize,
    });

    // Module with all dependencies
    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "trinity-core", .module = core_dep.module("trinity_core") },
            .{ .name = "trinity-lang", .module = lang_dep.module("trinity_lang") },
            .{ .name = "trinity-symb", .module = symb_dep.module("trinity_symb") },
            .{ .name = "trinity-network", .module = network_dep.module("trinity_network") },
            .{ .name = "trinity-canvas", .module = canvas_dep.module("trinity_canvas") },
        },
    });

    // Library
    const lib = b.addLibrary(.{
        .name = "trinity-tools",
        .linkage = .static,
        .root_module = mod,
    });
    b.installArtifact(lib);

    // Tests
    const tests = b.addTest(.{ .root_module = mod });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run trinity-tools tests");
    test_step.dependOn(&run_tests.step);

    // Ralph CLI - Autonomous Development Assistant
    // Import the ralph module (maxwell/ralph/agent.zig)
    const ralph_mod = b.createModule(.{
        .root_source_file = b.path("src/maxwell/ralph/agent.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Import swarm_watch module from generated directory (at project root)
    const swarm_watch_mod = b.createModule(.{
        .root_source_file = b.path("../../generated/swarm_watch.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create CLI module
    const ralph_cli_mod = b.createModule(.{
        .root_source_file = b.path("src/ralph_cli.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "ralph", .module = ralph_mod },
            .{ .name = "swarm_watch", .module = swarm_watch_mod },
            .{ .name = "trinity-symb", .module = symb_dep.module("trinity_symb") },
        },
    });

    const ralph_cli = b.addExecutable(.{
        .name = "ralph",
        .root_module = ralph_cli_mod,
    });

    b.installArtifact(ralph_cli);

    // Run Ralph CLI
    const run_ralph_cmd = b.addRunArtifact(ralph_cli);
    run_ralph_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_ralph_cmd.addArgs(args);
    }
    const ralph_step = b.step("ralph", "Run Ralph Autonomous Development Assistant");
    ralph_step.dependOn(&run_ralph_cmd.step);
}
