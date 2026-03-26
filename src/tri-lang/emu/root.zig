// TRI-27 Emulation — VM, assembler, executor, loader
// Re-exports all emu modules for Anti-Fragile Import Law
//
// φ² + 1/φ² = 3 | TRINITY

// Core VM components
pub const decoder = @import("decoder.zig");
pub const asm_parser = @import("asm_parser.zig");
pub const executor = @import("executor.zig");
pub const cpu_state = @import("cpu_state.zig");

// TRI-27 VM implementation
pub const tri_cpu = @import("tri_cpu.zig");
pub const tri_memory = @import("tri_memory.zig");
pub const tri_loader = @import("tri_loader.zig");
pub const tri_exec = @import("tri_exec.zig");

// Assembly tooling
pub const asm_lexer = @import("asm_lexer.zig");
pub const encoder_simple = @import("encoder_simple.zig");
pub const tri_asm = @import("tri_asm.zig");
