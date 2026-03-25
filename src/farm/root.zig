// F-zone — Farm Management Zone
// Railway training farm orchestration, evolution, accounts
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// Core farm modules
pub const farm_accounts = @import("farm_accounts.zig");
// TODO: evolution module has local import issues when used through module system
// pub const evolution = @import("evolution.zig");

// Farm utility modules (re-exported for tri module)
pub const railway_api = @import("railway_api.zig");
pub const tri_farm_ws = @import("tri_farm_ws.zig");
pub const hippocampus = @import("hippocampus.zig");
pub const experience_hooks = @import("experience_hooks.zig");
pub const tri_experience = @import("tri_experience.zig");
pub const sevo = @import("sevo.zig");
