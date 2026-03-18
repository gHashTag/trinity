//! Trinity Global Constants
//!
//! Single source of truth for project-wide constants.
//! All modules must import from here to avoid duplication drift.
// @origin(manual) @regen(pending)

/// Directory scan scope for cell discovery
/// Used by: ribosome.discoverAll(), cytoplasm.runBio(), plugin.loadCellsIntoRegistry()
pub const CELL_SCAN_DIRS = [_][]const u8{
    "src", // Core library (VSA, VM, hybrid, SDK)
    "apps", // Applications (Queen UI, desktop agents)
    "tools", // CLI tools and utilities (tri-bot, tri-api, MCP)
    "fpga", // FPGA synthesis and bitstreams
    "libs", // External libraries and vendored deps
    "specs", // VIBEE specifications (.tri files)
    "benchmarks", // Performance benchmarks
    "papers", // Research paper artifacts
    "data", // Training data, datasets
    "contracts", // Smart contracts and chain artifacts
    // Queen Unification v1 — brain cells (Batch 1: Prefrontal + Raphe)
    "src/tri/queen_dlpfc",
    "src/tri/queen_vmpfc",
    "src/tri/queen_ofc",
    "src/tri/queen_vlpfc",
    "src/tri/queen_dmpfc",
    "src/tri/phoenix_medulla",
    "src/tri/phoenix_pons",
    "src/tri/phoenix_locus_coeruleus",
    "src/tri/reticular_aras",
    "src/tri/reticular_raphe",
    "src/tri/reticular_gigantocellular",
};

/// Count of scan directories
pub const CELL_SCAN_DIRS_COUNT = CELL_SCAN_DIRS.len;
