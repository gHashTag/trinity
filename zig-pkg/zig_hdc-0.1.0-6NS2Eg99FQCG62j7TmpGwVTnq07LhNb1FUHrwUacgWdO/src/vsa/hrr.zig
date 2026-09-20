//! Re-export. The implementation lives in gHashTag/zig-golden-float.
//!
//! This file used to be a second copy of that one. Both repositories carried
//! src/vsa/hrr.zig, they were edited independently, and they diverged -- which is
//! why repairing sixteen defects in golden-float (#97) left every one of them
//! standing here. Two maintained copies of the same code is how that happens,
//! and it happens quietly, because nothing reports it.
//!
//! The names are listed one by one because `usingnamespace` was removed in Zig
//! 0.15, which is the version this package targets. That is a cost: a name added
//! there does not appear here until it is added here too. It is still cheaper
//! than a second implementation, and unlike a second implementation it fails
//! loudly -- the name is simply missing rather than quietly different.
const upstream = @import("zig_golden_float").hrr;

pub const HRR = upstream.HRR;
