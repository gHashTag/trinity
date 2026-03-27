// ELO Rating Selector — Self-hosted from .tri spec
// φ² + 1/φ² = 3 | TRINITY

const gen = @import("gen_elo.zig");

// Re-export all constants and functions
pub const Verdict = gen.Verdict;
pub const K_FACTOR = gen.K_FACTOR;
pub const expectedScore = gen.expectedScore;
pub const updateRatings = gen.updateRatings;
pub const formatElo = gen.formatElo;
