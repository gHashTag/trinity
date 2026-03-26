// ═══════════════════════════════════════════════════════════════════════════════
// Linear Types + Ownership Modes (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_linear_types.zig");

pub const SourceLocation = gen.SourceLocation;
pub const OwnershipMode = gen.OwnershipMode;
pub const Linear = gen.Linear;
pub const Bank = gen.Bank;
pub const Banked = gen.Banked;
pub const LinearTracker = gen.LinearTracker;
pub const BankError = gen.BankError;
pub const validateOpcodeBank = gen.validateOpcodeBank;
pub const MustUse = gen.MustUse;
pub const BorrowKind = gen.BorrowKind;
pub const BorrowChecker = gen.BorrowChecker;

// Manual (disabled):
// const manual = @import("linear_types_manual.zig");
// pub const Linear = manual.Linear;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
