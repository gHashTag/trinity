// ═══════════════════════════════════════════════════════════════════════════════
// ISOLATED VIBEE BUILD — Cycle 78
// ═══════════════════════════════════════════════════════════════════════════════
//
// Minimal build file for VIBEE codegen engine ONLY.
// Bypasses all other project dependencies (igla, trinity-canvas, etc.)
//
// Usage: zig build --build-file build_vibee.zig
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ═══════════════════════════════════════════════════════════════════════════════
    // VIBEE Compiler — Holy Core Codegen Engine
    // ═══════════════════════════════════════════════════════════════════════════════

    const vibee = b.addExecutable(.{
        .name = "vibee",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/gen_cmd.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(vibee);

    // Run step: zig build --build-file build_vibee.zig vibee
    const run_vibee = b.addRunArtifact(vibee);
    if (b.args) |args| {
        run_vibee.addArgs(args);
    }
    const vibee_step = b.step("vibee", "Run VIBEE Compiler CLI");
    vibee_step.dependOn(&run_vibee.step);

    // ═══════════════════════════════════════════════════════════════════════════════
    // VIBEE Self-Improvement Engine (optional)
    // ═══════════════════════════════════════════════════════════════════════════════

    const self_improve = b.addExecutable(.{
        .name = "vibee-self-improve",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/self_improver.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(self_improve);

    const run_self_improve = b.addRunArtifact(self_improve);
    const self_improve_step = b.step("self-improve", "Run VIBEE Self-Improvement Loop");
    self_improve_step.dependOn(&run_self_improve.step);
}
