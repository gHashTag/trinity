// ═══════════════════════════════════════════════════════════════════════════════════
// BUILD CONFIG — Conditional compilation options
// ═══════════════════════════════════════════════════════════════════════════════════

// This file is generated from build.zig options
// Values are set at COMPTIME by build configuration
//
// These enable/disable specific modules for tiered builds:
// - enable_farm:   tri_farm (training farm orchestration)
// - enable_cloud:  tri_cloud (cloud deployment)
// - enable_fpga:   tri_fpga (FPGA operations)
// - enable_spec:   tri_spec_command (spec audit tools)
//
// L0: temple_exe  — Always compiles (sacred core only)
// L1: queens_exe    — Always compiles (supervisors, no workers)
// L2: tri           — Full build (all workers enabled)

// Default values (overridden by build.zig options)
pub const enable_farm: bool = true;
pub const enable_cloud: bool = true;
pub const enable_fpga: bool = true;
pub const enable_spec: bool = true;
