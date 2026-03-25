// C-zone — TRI CLI Root
// Re-exports tri modules for cross-zone imports (queen → tri)
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// Core tri modules (used by queen and other zones)
pub const tri_colors = @import("tri_colors.zig");
pub const agent_roles = @import("agent_roles.zig");

// Faculty and cortex (for queen integration)
pub const faculty_types = @import("faculty_types.zig");
pub const cortex = @import("cortex.zig");

// Thalamus
pub const thalamus = @import("thalamus.zig");

// Brain stem (phoenix subsystem)
pub const voice_engine = @import("voice_engine.zig");
pub const cerebellum = @import("cerebellum.zig");
pub const insula = @import("insula.zig");
pub const phoenix_medulla = @import("phoenix_medulla.zig");
pub const phoenix_pons = @import("phoenix_pons.zig");

// GitHub integration (for queen issues) — now in github zone (Wave 3)
const github = @import("github");
pub const github_client = github.github_client;
pub const github_app_auth = github.github_app_auth;

// Farm management — now in farm zone (Wave 3)
const farm = @import("farm");
pub const farm_accounts = farm.farm_accounts;
pub const evolution = farm.evolution;

// Farm utilities (re-exported from farm zone for tri consumers)
pub const railway_api = farm.railway_api;
pub const tri_farm_ws = farm.tri_farm_ws;
pub const hippocampus = farm.hippocampus;
pub const experience_hooks = farm.experience_hooks;
pub const tri_experience = farm.tri_experience;
pub const sevo = farm.sevo;

// Re-export commonly used types
pub const TriColors = tri_colors.TriColors;
