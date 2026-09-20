//! Re-export. The implementation lives in gHashTag/zig-golden-float.
//!
//! This file used to be a second copy of that one. Both repositories carried
//! src/vsa/core.zig, they were edited independently, and they diverged -- which is
//! why repairing sixteen defects in golden-float (#97) left every one of them
//! standing here. Two maintained copies of the same code is how that happens,
//! and it happens quietly, because nothing reports it.
//!
//! The names are listed one by one because `usingnamespace` was removed in Zig
//! 0.15, which is the version this package targets. That is a cost: a name added
//! there does not appear here until it is added here too. It is still cheaper
//! than a second implementation, and unlike a second implementation it fails
//! loudly -- the name is simply missing rather than quietly different.
const upstream = @import("zig_golden_float").vsa;

pub const bind = upstream.bind;
pub const unbind = upstream.unbind;
pub const bundle2 = upstream.bundle2;
pub const bundle3 = upstream.bundle3;
pub const cosineSimilarity = upstream.cosineSimilarity;
pub const cosineSimilarityF16 = upstream.cosineSimilarityF16;
pub const hammingDistance = upstream.hammingDistance;
pub const hammingSimilarity = upstream.hammingSimilarity;
pub const dotSimilarity = upstream.dotSimilarity;
pub const vectorNorm = upstream.vectorNorm;
pub const countNonZero = upstream.countNonZero;
pub const bundleN = upstream.bundleN;
pub const randomVector = upstream.randomVector;
pub const permute = upstream.permute;
pub const inversePermute = upstream.inversePermute;
pub const encodeSequence = upstream.encodeSequence;
pub const probeSequence = upstream.probeSequence;
pub const qbind = upstream.qbind;
pub const qbundle = upstream.qbundle;
pub const measure = upstream.measure;
pub const similarity_quantum = upstream.similarity_quantum;
pub const applyPhase = upstream.applyPhase;
pub const computeCoherence = upstream.computeCoherence;
pub const entangle = upstream.entangle;
