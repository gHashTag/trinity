// ═══════════════════════════════════════════════════════════════════════════════
// Result Type for Tri Language (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_result_type.zig");

pub const SourceLocation = gen.SourceLocation;
pub const Result = gen.Result;
pub const NeuroError = gen.NeuroError;
pub const ParseError = gen.ParseError;
pub const EpisodeError = gen.EpisodeError;
pub const map = gen.map;
pub const mapError = gen.mapError;
pub const andThen = gen.andThen;
pub const withDefault = gen.withDefault;
pub const withDefaultLazy = gen.withDefaultLazy;
pub const unwrap = gen.unwrap;
pub const unwrapOr = gen.unwrapOr;
pub const isOk = gen.isOk;
pub const isErr = gen.isErr;
pub const tryMacro = gen.tryMacro;
pub const match = gen.match;
pub const MatchedResult = gen.MatchedResult;
pub const mustMatch = gen.mustMatch;
pub const unwrapChecked = gen.unwrapChecked;
pub const LoweredResult = gen.LoweredResult;
pub const lowerToTRI27 = gen.lowerToTRI27;

// Manual (disabled):
// const manual = @import("result_type_manual.zig");
// pub const Result = manual.Result;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
