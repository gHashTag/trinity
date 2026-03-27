//! Arena Elo — Generated from specs/arena/elo.tri
//! φ² + 1/φ² = 3 | TRINITY

const gen = @import("gen_elo.zig");

pub const Verdict = gen.Verdict;
pub const Match = gen.Match;

// Re-export constants
pub const K_FACTOR = gen.K_FACTOR;
pub const INITIAL_RATING = gen.INITIAL_RATING;
pub const MIN_RATING = gen.MIN_RATING;
pub const MAX_RATING = gen.MAX_RATING;
pub const EPSILON = gen.EPSILON;

// Re-export functions
pub const expectedScore = gen.expectedScore;
pub const updateRatings = gen.updateRatings;
pub const formatElo = gen.formatElo;
