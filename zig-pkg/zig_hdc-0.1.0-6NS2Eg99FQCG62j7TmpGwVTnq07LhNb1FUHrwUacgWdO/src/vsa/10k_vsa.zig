//! Re-export. The implementation lives in gHashTag/zig-golden-float.
//!
//! This file used to be a second copy of that one. Both repositories carried
//! src/vsa/10k_vsa.zig, they were edited independently, and they diverged -- which is
//! why repairing sixteen defects in golden-float (#97) left every one of them
//! standing here. Two maintained copies of the same code is how that happens,
//! and it happens quietly, because nothing reports it.
//!
//! The names are listed one by one because `usingnamespace` was removed in Zig
//! 0.15, which is the version this package targets. That is a cost: a name added
//! there does not appear here until it is added here too. It is still cheaper
//! than a second implementation, and unlike a second implementation it fails
//! loudly -- the name is simply missing rather than quietly different.
const upstream = @import("zig_golden_float").vsa_10k;

pub const Trit = upstream.Trit;
pub const HybridBigInt = upstream.HybridBigInt;
pub const DIM_10K = upstream.DIM_10K;
pub const BYTES_PER_10K = upstream.BYTES_PER_10K;
pub const WORDS_32BIT = upstream.WORDS_32BIT;
pub const BRAM_SIZE = upstream.BRAM_SIZE;
pub const VECTORS_PER_BRAM = upstream.VECTORS_PER_BRAM;
pub const TRIT_NEG = upstream.TRIT_NEG;
pub const TRIT_ZERO = upstream.TRIT_ZERO;
pub const TRIT_POS = upstream.TRIT_POS;
pub const HyperVector10K = upstream.HyperVector10K;
pub const BenchmarkResult = upstream.BenchmarkResult;
pub const benchmark = upstream.benchmark;
pub const printBenchmark = upstream.printBenchmark;
