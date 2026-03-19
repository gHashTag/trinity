// =============================================================================
// TRINITY NEXUS -- Symb Module (trinity-symb)
// Symbolic AI: triple extraction, knowledge graph, DHT sync, TRI rewards, TVC
// =============================================================================
// Migrated from src/vibeec/, src/, src/tvc/ in NEXUS-004
// 29 files, 15650 lines -- KG pipeline + TVC subsystem
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");

pub const VERSION = "0.1.0";
pub const MODULE = "trinity-symb";

// --- Knowledge Graph & Triples -------------------------------------------
pub const triples_parser = @import("triples_parser.zig");
pub const kg_sync = @import("kg_sync.zig");
pub const kg_pipeline = @import("kg_pipeline.zig");
pub const igla_knowledge_graph = @import("igla_knowledge_graph.zig");
pub const kg_server = @import("kg_server.zig");
pub const trinity_kg_server = @import("trinity_kg_server.zig");

// --- TVC (Ternary Vector Computing) --------------------------------------
pub const tvc_ir = @import("tvc/tvc_ir.zig");
pub const tvc_bigint = @import("tvc/tvc_bigint.zig");
pub const tvc_packed = @import("tvc/tvc_packed.zig");
pub const tvc_hybrid = @import("tvc/tvc_hybrid.zig");
pub const tvc_vsa = @import("tvc/tvc_vsa.zig");
pub const tvc_vm = @import("tvc/tvc_vm.zig");
pub const tvc_parser = @import("tvc/tvc_parser.zig");
pub const tvc_jit = @import("tvc/tvc_jit.zig");
pub const tvc_runtime = @import("tvc/tvc_runtime.zig");

// --- Deferred (@trinity/core dep, wired in NEXUS-008) --------------------
// pub const knowledge_graph = @import("knowledge_graph.zig");
// pub const kg_cli = @import("kg_cli.zig");
// pub const sym_005_demo = @import("sym_005_demo.zig");
// pub const tvc_corpus = @import("tvc/tvc_corpus.zig");

test {
    // KG / Triples (self-contained, std-only imports)
    _ = triples_parser;
    _ = kg_sync;
    _ = igla_knowledge_graph;
    _ = kg_server;
    _ = trinity_kg_server;

    // TVC core (self-contained, sibling-only imports)
    _ = tvc_ir;
    _ = tvc_bigint;
    _ = tvc_packed;
    _ = tvc_hybrid;
    _ = tvc_vsa;
    _ = tvc_vm;
    _ = tvc_parser;
    _ = tvc_runtime;
}

test "trinity-symb module identity" {
    try std.testing.expectEqualStrings("trinity-symb", MODULE);
    try std.testing.expectEqualStrings("0.1.0", VERSION);
}

test "trinity-symb triples extraction available" {
    const T = triples_parser.ExtractionResult;
    _ = T;
}

test "trinity-symb TVC operations available" {
    _ = tvc_vsa;
    _ = tvc_vm;
}
