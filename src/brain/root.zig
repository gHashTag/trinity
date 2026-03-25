// B-zone — Brain Modules Root
// Re-exports all brain region modules
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// Core brain regions
pub const basal_ganglia = @import("basal_ganglia.zig");
pub const reticular_formation = @import("reticular_formation.zig");
pub const locus_coeruleus = @import("locus_coeruleus.zig");
pub const amygdala = @import("amygdala.zig");
pub const prefrontal_cortex = @import("prefrontal_cortex.zig");

// Brain subsystems
pub const persistence = @import("persistence.zig");
pub const telemetry = @import("telemetry.zig");
pub const thalamus_logs = @import("thalamus_logs.zig");
pub const health_history = @import("health_history.zig");
pub const microglia = @import("microglia.zig");
pub const metrics_dashboard = @import("metrics_dashboard.zig");
pub const state_recovery = @import("state_recovery.zig");

// Brain integration
pub const brain = @import("brain.zig");
pub const simulation = @import("simulation.zig");
pub const learning = @import("learning.zig");
pub const federation = @import("federation.zig");
pub const admin = @import("admin.zig");
pub const alerts = @import("alerts.zig");
pub const async_processor = @import("async_processor.zig");

// Phoenix subsystem (brain stem)
pub const phoenix_locus_coeruleus = @import("locus_coeruleus.zig");
pub const phoenix_medulla = @import("reticular_formation.zig");
pub const phoenix_pons = @import("reticular_formation.zig");

// Re-export core types for convenience
pub const Brain = brain.Brain;
pub const WorkerLiveState = brain.WorkerLiveState;
pub const SafetyVerdict = brain.SafetyVerdict;
pub const Action = brain.Action;
