// Q-zone — Queen Coordination (Prefrontal Cortex)
// Meta-control: reads thalamus, assigns tasks, resolves conflicts
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const temple = @import("temple");

// Queen modules (neuroanatomically organized)
pub const queen_acc = @import("queen_acc.zig");
pub const queen_actions = @import("queen_actions.zig");
pub const queen_cortex = @import("queen_cortex.zig");
pub const cortex = @import("cortex.zig"); // Faculty board
pub const queen_cron = @import("queen_cron.zig");
pub const queen_dlpfc = @import("queen_dlpfc.zig"); // Dorsolateral PFC
pub const queen_dmpfc = @import("queen_dmpfc.zig"); // Dorsomedial PFC
pub const queen_issues = @import("queen_issues.zig");
pub const queen_motor = @import("queen_motor.zig");
pub const queen_ofc = @import("queen_ofc.zig"); // Orbitofrontal Cortex
pub const queen_ouroboros = @import("queen_ouroboros.zig");
pub const queen_pcc = @import("queen_pcc.zig");
pub const queen_premotor = @import("queen_premotor.zig");
pub const queen_senses = @import("queen_senses.zig");
pub const queen_tamagotchi = @import("queen_tamagotchi.zig");
pub const queen_telegram = @import("queen_telegram.zig");
pub const queen_trinity = @import("queen_trinity.zig");
pub const queen_types = @import("queen_types.zig");
pub const queen_vlpfc = @import("queen_vlpfc.zig"); // Ventrolateral PFC
pub const queen_vmpfc = @import("queen_vmpfc.zig"); // Ventromedial PFC

// Re-export core types
pub const QueenPolicy = queen_policy.QueenPolicy;
pub const QueenTypes = queen_types.QueenTypes;

// Re-export main entry point
pub const runQueenCommand = queen_trinity.runQueenCommand;

// Import queen_policy and queen_types
pub const queen_policy = @import("queen_policy.zig");
