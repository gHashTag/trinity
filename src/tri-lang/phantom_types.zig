// ═══════════════════════════════════════════════════════════════════════════════
// Phantom Types for Bank Safety (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_phantom_types.zig");

pub const Bank0 = gen.Bank0;
pub const Bank1 = gen.Bank1;
pub const Bank2 = gen.Bank2;
pub const Bank3 = gen.Bank3;
pub const Bank4 = gen.Bank4;
pub const Bank5 = gen.Bank5;
pub const Bank6 = gen.Bank6;
pub const Bank7 = gen.Bank7;
pub const Bank8 = gen.Bank8;
pub const Banked = gen.Banked;
pub const bankFromType = gen.bankFromType;
pub const bankFromNumber = gen.bankFromNumber;
pub const isSameBank = gen.isSameBank;
pub const addBanked = gen.addBanked;
pub const subBanked = gen.subBanked;
pub const crossBankAdd = gen.crossBankAdd;
pub const LoweredBanked = gen.LoweredBanked;
pub const lowerBankedToTRI27 = gen.lowerBankedToTRI27;
pub const bankedAddress = gen.bankedAddress;

// Manual (disabled):
// const manual = @import("phantom_types_manual.zig");
// pub const Bank0 = manual.Bank0;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
