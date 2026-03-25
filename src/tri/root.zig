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

// GitHub integration (for queen issues)
pub const github_client = @import("github_client.zig");
pub const github_app_auth = @import("github_app_auth.zig");

// Farm management
pub const farm_accounts = @import("farm_accounts.zig");

// Re-export commonly used types
pub const TriColors = tri_colors.TriColors;
