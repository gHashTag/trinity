const std = @import("std");

// =============================================================================
// TRINITY NEXUS — Master Build (Zig 0.15.x)
// Aggregates all module builds into a unified workspace
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // =========================================================================
    // Module: trinity-core (no dependencies)
    // =========================================================================
    const core_mod = b.createModule(.{
        .root_source_file = b.path("core/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const core_lib = b.addLibrary(.{
        .name = "trinity-core",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("core/src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(core_lib);

    // =========================================================================
    // Module: trinity-lang (depends on: core)
    // =========================================================================
    const lang_mod = b.createModule(.{
        .root_source_file = b.path("lang/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lang_lib = b.addLibrary(.{
        .name = "trinity-lang",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("lang/src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lang_lib);

    // =========================================================================
    // Module: trinity-symb (depends on: core, lang)
    // =========================================================================
    const symb_mod = b.createModule(.{
        .root_source_file = b.path("symb/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const symb_lib = b.addLibrary(.{
        .name = "trinity-symb",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("symb/src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(symb_lib);

    // =========================================================================
    // Module: trinity-network (depends on: core, symb)
    // =========================================================================
    const network_mod = b.createModule(.{
        .root_source_file = b.path("network/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const network_lib = b.addLibrary(.{
        .name = "trinity-network",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("network/src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(network_lib);

    // =========================================================================
    // Module: trinity-canvas (depends on: core)
    // =========================================================================
    const canvas_mod = b.createModule(.{
        .root_source_file = b.path("canvas/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const canvas_lib = b.addLibrary(.{
        .name = "trinity-canvas",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("canvas/src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(canvas_lib);

    // =========================================================================
    // Module: trinity-tools (depends on: all)
    // =========================================================================
    const tools_mod = b.createModule(.{
        .root_source_file = b.path("tools/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tools_lib = b.addLibrary(.{
        .name = "trinity-tools",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(tools_lib);

    // =========================================================================
    // Test steps — one per module + unified "test" step
    // =========================================================================
    const test_step = b.step("test", "Run all Trinity Nexus module tests");

    const modules = .{
        .{ "core", "core/src/root.zig" },
        .{ "lang", "lang/src/root.zig" },
        .{ "symb", "symb/src/root.zig" },
        .{ "network", "network/src/root.zig" },
        .{ "canvas", "canvas/src/root.zig" },
        .{ "tools", "tools/src/root.zig" },
    };

    inline for (modules) |entry| {
        const name = entry[0];
        const root = entry[1];

        const mod_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(root),
                .target = target,
                .optimize = optimize,
            }),
        });
        const run_mod_tests = b.addRunArtifact(mod_tests);

        const mod_test_step = b.step("test-" ++ name, "Run trinity-" ++ name ++ " tests");
        mod_test_step.dependOn(&run_mod_tests.step);
        test_step.dependOn(&run_mod_tests.step);
    }

    // Suppress unused variable warnings for module references
    _ = core_mod;
    _ = lang_mod;
    _ = symb_mod;
    _ = network_mod;
    _ = canvas_mod;
    _ = tools_mod;
}
