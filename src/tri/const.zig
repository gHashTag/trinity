//! Trinity Global Constants
//!
//! Single source of truth for project-wide constants.
//! All modules must import from here to avoid duplication drift.

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
};

/// Count of scan directories
pub const CELL_SCAN_DIRS_COUNT = CELL_SCAN_DIRS.len;
