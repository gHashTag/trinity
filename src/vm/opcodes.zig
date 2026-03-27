//! VM Core Opcodes Selector — Generated from specs/vm/opcodes.tri
//! φ² + 1/φ² = 3 | TRINITY

const gen = @import("gen_opcodes.zig");

pub const Opcode = gen.Opcode;
pub const Instruction = gen.Instruction;

// Re-export functions
pub const opcodeFromByte = gen.opcodeFromByte;
pub const opcodeToString = gen.opcodeToString;

// Re-export constants
pub const MAX_STACK_DEPTH = gen.MAX_STACK_DEPTH;
pub const MAX_MEMORY_SIZE = gen.MAX_MEMORY_SIZE;
