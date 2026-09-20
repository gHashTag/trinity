//! GoldenFloat — φ-Optimized Zig Kernel Build System
//! Zig 0.15 package system — module-only library
//!
//! **Build Targets:**
//! - `zig build` — Build module only
//! - `zig build test` — Run all tests
//! - `zig build shared` — Build libgoldenfloat.{so,dylib,dll}
//! - `zig build c-abi-test` — Test C-ABI layer

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ─────────────────────────────────────────────────────────────────
    // Library module (what users import via @import("golden-float"))
    // ─────────────────────────────────────────────────────────────────
    _ = b.addModule("golden-float", .{
        .root_source_file = b.path("src/root.zig"),
    });

    // ─────────────────────────────────────────────────────────────────
    // tri_gen executable — code generator from .tri specs
    // ─────────────────────────────────────────────────────────────────
    const tri_gen_module = b.createModule(.{
        .root_source_file = b.path("tools/gen/tri_gen.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tri_gen = b.addExecutable(.{
        .name = "tri_gen",
        .root_module = tri_gen_module,
    });

    // NOT installed by default, and not because it is broken.
    //
    // tri_gen and tri_reader are written against Zig 0.16 on purpose -- their own
    // comments say so, and they use std.Io, std.Io.Dir and std.process.Init,
    // none of which exist in 0.15. This package declares
    // minimum_zig_version 0.15.0 and both of its consumers build with 0.15.2, so
    // installing a 0.16-only tool by default made the LIBRARY unbuildable for
    // everybody in order to keep a tool nobody can run at that version.
    //
    // The library itself compiles on 0.15 -- the only failure was here. So the
    // tool moves behind an explicit step and the version claim becomes true
    // rather than aspirational. `zig build gen` still builds and runs it, on a
    // toolchain that has the API it was written for.
    //
    // This is not making a build green by deleting what failed: what failed is
    // still built, by a step that names the toolchain it needs.
    const tools_step = b.step("tools", "Build the .tri code generator (requires Zig 0.16)");
    tools_step.dependOn(&b.addInstallArtifact(tri_gen, .{}).step);

    const run_tri_gen = b.addRunArtifact(tri_gen);
    const gen_step = b.step("gen", "Generate code from .tri specs");
    gen_step.dependOn(&run_tri_gen.step);

    // ─────────────────────────────────────────────────────────────────
    // C-ABI Shared Library — libgoldenfloat.{so,dylib,dll}
    // ─────────────────────────────────────────────────────────────────
    const c_abi_module = b.createModule(.{
        .root_source_file = b.path("src/c_abi.zig"),
        .target = target,
        .optimize = optimize,
    });

    const c_abi_lib = b.addLibrary(.{
        .name = "goldenfloat",
        .root_module = c_abi_module,
        .linkage = .dynamic,
        .version = .{ .major = 2, .minor = 1, .patch = 0 },
    });

    b.installArtifact(c_abi_lib);

    // Install C header alongside library
    const header_install = b.addInstallHeaderFile(b.path("src/c/gf16.h"), "gf16.h");

    const shared_step = b.step("shared", "Build C-ABI shared library (libgoldenfloat)");
    shared_step.dependOn(&b.addInstallArtifact(c_abi_lib, .{}).step);
    shared_step.dependOn(&header_install.step);

    // ─────────────────────────────────────────────────────────────────
    // C-ABI Tests
    // ─────────────────────────────────────────────────────────────────
    const c_abi_test_module = b.createModule(.{
        .root_source_file = b.path("src/c_abi.zig"),
        .target = target,
        .optimize = optimize,
    });

    // The module root, analysed in full. Nothing rooted src/root.zig before, so
    // the surface consumers actually import was the one part never compiled.
    const root_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const c_abi_tests = b.addTest(.{
        .name = "c-abi-tests",
        .root_module = c_abi_test_module,
    });

    const run_c_abi_tests = b.addRunArtifact(c_abi_tests);
    const c_abi_test_step = b.step("c-abi-test", "Run C-ABI tests");
    c_abi_test_step.dependOn(&run_c_abi_tests.step);

    // ─────────────────────────────────────────────────────────────────
    // Tests — formats (GF16/TF3)
    // ─────────────────────────────────────────────────────────────────
    const formats_tests_root = b.createModule(.{
        .root_source_file = b.path("src/formats/golden_float16.zig"),
        .target = target,
        .optimize = optimize,
    });
    const formats_tests = b.addTest(.{
        .name = "formats-tests",
        .root_module = formats_tests_root,
    });

    // ─────────────────────────────────────────────────────────────────
    // Tests — GF-T ternary-exponent ladder (GF-T4/8/16/32)
    // ─────────────────────────────────────────────────────────────────
    const gft_tests_root = b.createModule(.{
        .root_source_file = b.path("src/formats/gft.zig"),
        .target = target,
        .optimize = optimize,
    });
    const gft_tests = b.addTest(.{
        .name = "gft-tests",
        .root_module = gft_tests_root,
    });
    const run_gft_tests = b.addRunArtifact(gft_tests);

    // ─────────────────────────────────────────────────────────────────
    // Tests — GF binary-exponent ladder factory (GF4/8/12/16/20/24/32)
    // ─────────────────────────────────────────────────────────────────
    const gf_binary_tests_root = b.createModule(.{
        .root_source_file = b.path("src/formats/gf_binary.zig"),
        .target = target,
        .optimize = optimize,
    });
    const gf_binary_tests = b.addTest(.{
        .name = "gf-binary-tests",
        .root_module = gf_binary_tests_root,
    });
    const run_gf_binary_tests = b.addRunArtifact(gf_binary_tests);

    // ─────────────────────────────────────────────────────────────────
    // Tests — transcendental functions (Wave 4B)
    // ─────────────────────────────────────────────────────────────────
    const transcendent_tests_root = b.createModule(.{
        .root_source_file = b.path("src/math/transcendental.zig"),
        .target = target,
        .optimize = optimize,
    });
    const transcendent_tests = b.addTest(.{
        .name = "transcendent-tests",
        .root_module = transcendent_tests_root,
    });

    // ─────────────────────────────────────────────────────────────────
    // Tests — .tri spec parser (tri_reader)
    // Spec files live in specs/, outside tools/gen/, so they cannot be
    // @embedFile'd directly (module-path restriction). Supply them as named
    // anonymous imports the test embeds via @embedFile("spec_gf8"/"spec_gf16").
    // ─────────────────────────────────────────────────────────────────
    const tri_reader_tests_root = b.createModule(.{
        .root_source_file = b.path("tools/gen/tri_reader.zig"),
        .target = target,
        .optimize = optimize,
    });
    tri_reader_tests_root.addAnonymousImport("spec_gf8", .{
        .root_source_file = b.path("specs/gf8.tri"),
    });
    tri_reader_tests_root.addAnonymousImport("spec_gf16", .{
        .root_source_file = b.path("specs/gf16.tri"),
    });
    const tri_reader_tests = b.addTest(.{
        .name = "tri-reader-tests",
        .root_module = tri_reader_tests_root,
    });
    const run_tri_reader_tests = b.addRunArtifact(tri_reader_tests);

    const run_tests = b.addRunArtifact(formats_tests);
    const run_transcendent_tests = b.addRunArtifact(transcendent_tests);

    const trinity_tests_root = b.createModule(.{
        .root_source_file = b.path("src/trinity_constants.zig"),
        .target = target,
        .optimize = optimize,
    });
    const trinity_tests = b.addTest(.{
        .name = "trinity-constants-tests",
        .root_module = trinity_tests_root,
    });
    const run_trinity_tests = b.addRunArtifact(trinity_tests);

    const phi_attention_tests_root = b.createModule(.{
        .root_source_file = b.path("src/phi_attention.zig"),
        .target = target,
        .optimize = optimize,
    });
    const phi_attention_tests = b.addTest(.{
        .name = "phi-attention-tests",
        .root_module = phi_attention_tests_root,
    });
    const run_phi_attention_tests = b.addRunArtifact(phi_attention_tests);

    const trinity_init_tests_root = b.createModule(.{
        .root_source_file = b.path("src/trinity_init.zig"),
        .target = target,
        .optimize = optimize,
    });
    const trinity_init_tests = b.addTest(.{
        .name = "trinity-init-tests",
        .root_module = trinity_init_tests_root,
    });
    const run_trinity_init_tests = b.addRunArtifact(trinity_init_tests);

    const jepa_t_tests_root = b.createModule(.{
        .root_source_file = b.path("src/jepa_t.zig"),
        .target = target,
        .optimize = optimize,
    });
    const jepa_t_tests = b.addTest(.{
        .name = "jepa-t-tests",
        .root_module = jepa_t_tests_root,
    });
    const run_jepa_t_tests = b.addRunArtifact(jepa_t_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_gft_tests.step);
    test_step.dependOn(&run_gf_binary_tests.step);
    test_step.dependOn(&run_transcendent_tests.step);
    test_step.dependOn(&run_c_abi_tests.step);
    test_step.dependOn(&run_trinity_tests.step);
    test_step.dependOn(&run_phi_attention_tests.step);
    test_step.dependOn(&run_trinity_init_tests.step);
    test_step.dependOn(&run_jepa_t_tests.step);
    test_step.dependOn(&run_tri_reader_tests.step);

    const igla_bench_module = b.createModule(.{
        .root_source_file = b.path("benches/igla_gf16_bench.zig"),
        .target = target,
        .optimize = optimize,
    });
    const igla_bench = b.addExecutable(.{
        .name = "igla_gf16_bench",
        .root_module = igla_bench_module,
    });
    const run_igla_bench = b.addRunArtifact(igla_bench);
    const igla_bench_step = b.step("bench-igla", "Run IGLA-GF16 architecture verification (Module 7)");
    igla_bench_step.dependOn(&run_igla_bench.step);
    test_step.dependOn(&b.addRunArtifact(root_tests).step);
}
