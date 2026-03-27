//! tri/match — Pattern matching with exhaustiveness checking
//! Selector file for generated code

const generated = @import("gen_match.zig");

pub const Match = generated.Match;
pub const MatchCapture = generated.MatchCapture;
pub const matchLiteral = generated.matchLiteral;
pub const matchType = generated.matchType;
pub const exhaustive = generated.exhaustive;
pub const matchEnum = generated.matchEnum;
pub const matchAny = generated.matchAny;
