//! TRI Time Module Selector
//! φ² + 1/φ² = 3 | TRINITY

pub const Timestamp = @import("gen_time.zig").Timestamp;
pub const Duration = @import("gen_time.zig").Duration;
pub const DateTime = @import("gen_time.zig").DateTime;

pub const now = @import("gen_time.zig").now;
pub const fromSeconds = @import("gen_time.zig").fromSeconds;
pub const toSeconds = @import("gen_time.zig").toSeconds;
pub const elapsed = @import("gen_time.zig").elapsed;
pub const duration = @import("gen_time.zig").duration;
pub const formatDuration = @import("gen_time.zig").formatDuration;
pub const formatDurationFull = @import("gen_time.zig").formatDurationFull;
pub const toMillis = @import("gen_time.zig").toMillis;
pub const toSecondsDuration = @import("gen_time.zig").toSecondsDuration;
pub const toMinutes = @import("gen_time.zig").toMinutes;
pub const toHours = @import("gen_time.zig").toHours;
pub const toDays = @import("gen_time.zig").toDays;
