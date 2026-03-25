// C-zone — TRI CLI Root
// Re-exports tri modules for cross-zone imports (queen → tri)
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// Core tri modules (used by queen and other zones)
pub const tri_colors = @import("tri_colors");
pub const agent_roles = @import("agent_roles.zig");

// Additional tri modules needed by cortex
pub const analysis_engine = @import("analysis_engine");
pub const three_paths = @import("three_paths");
pub const phi_poetry = @import("phi_poetry");
pub const train_types = @import("train_types");
pub const tri_state = @import("tri_state");

// NOTE: faculty_types, cortex, thalamus, cerebellum, insula, phoenix_medulla, phoenix_pons
// moved to queen zone (Wave 3)
// Queen modules should import them directly from queen/

// Brain stem (phoenix subsystem) - still in tri/
pub const voice_engine = @import("voice_engine");

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
