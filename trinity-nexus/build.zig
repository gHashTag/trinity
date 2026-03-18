const std = @import("std");

// =============================================================================
// TRINITY NEXUS — Master Build (Zig 0.15.x)
// NEXUS-008: Workspace wiring with inter-module dependencies
// Dependency graph: core -> lang -> symb -> network, core -> canvas, tools -> all
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // =========================================================================
    // Module: trinity-core (no dependencies — foundation)
    // =========================================================================
    const core_mod = b.createModule(.{
        .root_source_file = b.path("core/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const core_lib = b.addLibrary(.{
        .name = "trinity-core",
        .linkage = .static,
        .root_module = core_mod,
    });
    b.installArtifact(core_lib);

    // =========================================================================
    // Module: trinity-lang (depends on: core)
    // =========================================================================
    const lang_mod = b.createModule(.{
        .root_source_file = b.path("lang/src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "trinity-core", .module = core_mod },
        },
    });

    const lang_lib = b.addLibrary(.{
        .name = "trinity-lang",
        .linkage = .static,
        .root_module = lang_mod,
    });
    b.installArtifact(lang_lib);

    // =========================================================================
    // Module: trinity-symb (depends on: core, lang)
    // =========================================================================
    const symb_mod = b.createModule(.{
        .root_source_file = b.path("symb/src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "trinity-core", .module = core_mod },
            .{ .name = "trinity-lang", .module = lang_mod },
        },
    });

    const symb_lib = b.addLibrary(.{
        .name = "trinity-symb",
        .linkage = .static,
        .root_module = symb_mod,
    });
    b.installArtifact(symb_lib);

    // =========================================================================
    // Module: trinity-network (depends on: core, symb)
    // =========================================================================
    const network_mod = b.createModule(.{
        .root_source_file = b.path("network/src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "trinity-core", .module = core_mod },
            .{ .name = "trinity-symb", .module = symb_mod },
        },
    });

    const network_lib = b.addLibrary(.{
        .name = "trinity-network",
        .linkage = .static,
        .root_module = network_mod,
    });
    b.installArtifact(network_lib);

    // =========================================================================
    // Module: trinity-canvas (depends on: core)
    // =========================================================================
    const canvas_mod = b.createModule(.{
        .root_source_file = b.path("canvas/src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "trinity-core", .module = core_mod },
        },
    });

    const canvas_lib = b.addLibrary(.{
        .name = "trinity-canvas",
        .linkage = .static,
        .root_module = canvas_mod,
    });
    b.installArtifact(canvas_lib);

    // =========================================================================
    // Module: trinity-tools (depends on: all modules)
    // =========================================================================
    const tools_mod = b.createModule(.{
        .root_source_file = b.path("tools/src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "trinity-core", .module = core_mod },
            .{ .name = "trinity-lang", .module = lang_mod },
            .{ .name = "trinity-symb", .module = symb_mod },
            .{ .name = "trinity-network", .module = network_mod },
            .{ .name = "trinity-canvas", .module = canvas_mod },
        },
    });

    const tools_lib = b.addLibrary(.{
        .name = "trinity-tools",
        .linkage = .static,
        .root_module = tools_mod,
    });
    b.installArtifact(tools_lib);

    // =========================================================================
    // Test steps — one per module + unified "test" step
    // Uses the wired modules so tests can resolve cross-module imports
    // =========================================================================
    const test_step = b.step("test", "Run all Trinity Nexus module tests");

    // Core tests (no deps)
    const core_tests = b.addTest(.{ .root_module = core_mod });
    const run_core_tests = b.addRunArtifact(core_tests);
    const core_test_step = b.step("test-core", "Run trinity-core tests");
    core_test_step.dependOn(&run_core_tests.step);
    test_step.dependOn(&run_core_tests.step);

    // Lang tests (deps: core)
    const lang_tests = b.addTest(.{ .root_module = lang_mod });
    const run_lang_tests = b.addRunArtifact(lang_tests);
    const lang_test_step = b.step("test-lang", "Run trinity-lang tests");
    lang_test_step.dependOn(&run_lang_tests.step);
    test_step.dependOn(&run_lang_tests.step);

    // Symb tests (deps: core, lang)
    const symb_tests = b.addTest(.{ .root_module = symb_mod });
    const run_symb_tests = b.addRunArtifact(symb_tests);
    const symb_test_step = b.step("test-symb", "Run trinity-symb tests");
    symb_test_step.dependOn(&run_symb_tests.step);
    test_step.dependOn(&run_symb_tests.step);

    // Network tests (deps: core, symb)
    const network_tests = b.addTest(.{ .root_module = network_mod });
    const run_network_tests = b.addRunArtifact(network_tests);
    const network_test_step = b.step("test-network", "Run trinity-network tests");
    network_test_step.dependOn(&run_network_tests.step);
    test_step.dependOn(&run_network_tests.step);

    // Canvas tests (deps: core)
    const canvas_tests = b.addTest(.{ .root_module = canvas_mod });
    const run_canvas_tests = b.addRunArtifact(canvas_tests);
    const canvas_test_step = b.step("test-canvas", "Run trinity-canvas tests");
    canvas_test_step.dependOn(&run_canvas_tests.step);
    test_step.dependOn(&run_canvas_tests.step);

    // Tools tests (deps: all)
    const tools_tests = b.addTest(.{ .root_module = tools_mod });
    const run_tools_tests = b.addRunArtifact(tools_tests);
    const tools_test_step = b.step("test-tools", "Run trinity-tools tests");
    tools_test_step.dependOn(&run_tools_tests.step);
    test_step.dependOn(&run_tools_tests.step);
}
