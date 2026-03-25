// F-zone — Firebird LLM Engine
// Core LLM engine integration: tokens, context, throughput
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const temple = @import("temple");

// Core Firebird modules
pub const firebird = @import("firebird.zig");
pub const app_state = @import("app_state.zig");
pub const b2t_integration = @import("b2t_integration.zig");
pub const cli = @import("cli.zig");
pub const depin = @import("depin.zig");
pub const evolution = @import("evolution.zig");
pub const extension_wasm = @import("extension_wasm.zig");
pub const firebird_continual_agent = @import("firebird_continual_agent.zig");
pub const governance = @import("governance.zig");
pub const mainnet = @import("mainnet.zig");
pub const neodetect_wasm = @import("neodetect_wasm.zig");
pub const parallel = @import("parallel.zig");
pub const reputation = @import("reputation.zig");
pub const scale_test = @import("scale_test.zig");
pub const slashing = @import("slashing.zig");
pub const staking = @import("staking.zig");
pub const vsa_simd = @import("vsa_simd.zig");

// Re-export core types from firebird.zig
pub const TritVec = firebird.TritVec;
pub const SimilarityMetrics = firebird.SimilarityMetrics;
pub const Trit = firebird.Trit;

// Re-export constants
pub const DIM = firebird.DIM;
pub const PHI = firebird.PHI;
pub const PHI_INV = firebird.PHI_INV;
pub const TRINITY = firebird.TRINITY;
pub const MU = firebird.MU;
pub const CHI = firebird.CHI;
pub const SIGMA = firebird.SIGMA;
pub const EPSILON = firebird.EPSILON;
