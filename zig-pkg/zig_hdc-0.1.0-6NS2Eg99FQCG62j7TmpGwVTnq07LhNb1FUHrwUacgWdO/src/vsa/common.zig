//! Re-export. The implementation lives in gHashTag/zig-golden-float.
//!
//! This file used to be a second copy of that one. Both repositories carried
//! src/vsa/common.zig, they were edited independently, and they diverged -- which is
//! why repairing sixteen defects in golden-float (#97) left every one of them
//! standing here. Two maintained copies of the same code is how that happens,
//! and it happens quietly, because nothing reports it.
//!
//! The names are listed one by one because `usingnamespace` was removed in Zig
//! 0.15, which is the version this package targets. That is a cost: a name added
//! there does not appear here until it is added here too. It is still cheaper
//! than a second implementation, and unlike a second implementation it fails
//! loudly -- the name is simply missing rather than quietly different.
const upstream = @import("zig_golden_float").vsa_common;

pub const HybridBigInt = upstream.HybridBigInt;
pub const Trit = upstream.Trit;
pub const Vec32i8 = upstream.Vec32i8;
pub const SIMD_WIDTH = upstream.SIMD_WIDTH;
pub const MAX_TRITS = upstream.MAX_TRITS;
pub const SearchResult = upstream.SearchResult;

// golden-float's vsa/common.zig has no counterpart for this one, so it cannot
// come from the re-export above. It is taken from where the value actually
// lives -- packed_trit -- rather than written out as a literal, so there is
// still exactly one definition of it. Nothing inside this repository uses it,
// but it was part of this module's public surface before the deduplication and
// dropping it silently would break somebody outside who does.
pub const MAX_PACKED_BYTES = @import("zig_golden_float").packed_trit.MAX_PACKED_BYTES;
