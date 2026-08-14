//! Совместимостный слой: src/vsa.zig был перенесён в gHashTag/zig-hdc
//! коммитом 42490a222, но десятки файлов этого репозитория продолжали
//! импортировать его по относительному пути. Файл не дублирует код —
//! он только реэкспортирует модуль зависимости `zig-hdc-vsa`.
//! Zig 0.15 не поддерживает `usingnamespace`, поэтому реэкспорт явный.

const hdc = @import("zig-hdc-vsa");

pub const common = hdc.common;
pub const core = hdc.core;
pub const encoding = hdc.encoding;
pub const storage = hdc.storage;
pub const concurrency = hdc.concurrency;
pub const HRR = hdc.HRR;
pub const HybridBigInt = hdc.HybridBigInt;
pub const Trit = hdc.Trit;
pub const Vec32i8 = hdc.Vec32i8;
pub const SIMD_WIDTH = hdc.SIMD_WIDTH;
pub const MAX_TRITS = hdc.MAX_TRITS;
pub const SearchResult = hdc.SearchResult;
pub const randomVector = hdc.randomVector;
pub const bind = hdc.bind;
pub const unbind = hdc.unbind;
pub const bundle2 = hdc.bundle2;
pub const bundle3 = hdc.bundle3;
pub const permute = hdc.permute;
pub const inversePermute = hdc.inversePermute;
pub const cosineSimilarity = hdc.cosineSimilarity;
pub const hammingDistance = hdc.hammingDistance;
pub const hammingSimilarity = hdc.hammingSimilarity;
pub const dotSimilarity = hdc.dotSimilarity;
pub const vectorNorm = hdc.vectorNorm;
pub const bundleN = hdc.bundleN;
pub const countNonZero = hdc.countNonZero;
pub const encodeSequence = hdc.encodeSequence;
pub const probeSequence = hdc.probeSequence;
pub const encodeText = hdc.encodeText;
pub const decodeText = hdc.decodeText;
pub const TEXT_VECTOR_DIM = hdc.TEXT_VECTOR_DIM;
pub const charToVector = hdc.charToVector;
pub const encodeTextWords = hdc.encodeTextWords;
pub const textSimilarity = hdc.textSimilarity;
pub const textsAreSimilar = hdc.textsAreSimilar;
pub const TextCorpus = hdc.TextCorpus;
pub const ChaseLevDeque = hdc.ChaseLevDeque;
pub const DependencyGraph = hdc.DependencyGraph;
pub const TaskNode = hdc.TaskNode;
pub const TaskState = hdc.TaskState;
pub const getGlobalPool = hdc.getGlobalPool;
pub const hammingDistanceSlice = hdc.hammingDistanceSlice;
