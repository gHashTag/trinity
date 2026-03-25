// TRI-27 Emulation — VM, assembler, executor, loader
// Re-exports all emu/ modules for Anti-Fragile Import Law
//
// φ² + 1/φ² = 3 | TRINITY

// Core VM components
pub const decoder = @import("emu/decoder.zig");
pub const asm_parser = @import("emu/asm_parser.zig");
pub const executor = @import("emu/executor.zig");
pub const cpu_state = @import("emu/cpu_state.zig");

// TRI-27 VM implementation
pub const tri_cpu = @import("emu/tri_cpu.zig");
pub const tri_memory = @import("emu/tri_memory.zig");
pub const tri_loader = @import("emu/tri_loader.zig");
pub const tri_exec = @import("emu/tri_exec.zig");

// Assembly tooling
pub const asm_lexer = @import("emu/asm_lexer.zig");
pub const encoder_simple = @import("emu/encoder_simple.zig");
