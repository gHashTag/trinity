// ═══════════════════════════════════════════════════════════════════════════════
// Array Combinators (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_array_combinators.zig");

pub const SourceLocation = gen.SourceLocation;
pub const map = gen.map;
pub const mapInPlace = gen.mapInPlace;
pub const reduce = gen.reduce;
pub const reduceIndexed = gen.reduceIndexed;
pub const scan = gen.scan;
pub const scanInclusive = gen.scanInclusive;
pub const scanExclusive = gen.scanExclusive;
pub const filter = gen.filter;
pub const flatMap = gen.flatMap;
pub const foldLeft = gen.foldLeft;
pub const foldRight = gen.foldRight;
pub const Zip = gen.Zip;
pub const zip = gen.zip;
pub const partition = gen.partition;
pub const chunk = gen.chunk;
pub const chunkBy = gen.chunkBy;
pub const reverse = gen.reverse;
pub const take = gen.take;
pub const drop = gen.drop;
pub const takeWhile = gen.takeWhile;
pub const dropWhile = gen.dropWhile;
pub const find = gen.find;
pub const findLast = gen.findLast;
pub const findIndex = gen.findIndex;
pub const findLastIndex = gen.findLastIndex;
pub const any = gen.any;
pub const all = gen.all;
pub const distinct = gen.distinct;
pub const flatten = gen.flatten;
pub const interleave = gen.interleave;

// Manual (disabled):
// const manual = @import("array_combinators_manual.zig");
// pub const map = manual.map;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
