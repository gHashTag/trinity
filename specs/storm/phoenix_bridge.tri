# Phoenix Bridge — Self-Healing Interface

## Module
storm.phoenix_bridge

## Description
Phoenix system integration for STORM. Pre-wave health check, biopsy for regeneration, lineage tracking.

## Dependencies
- std
- std.fs (for file operations)

## Structs
### RegenDecision
enum { REGEN, SKIP, DESTROY }

### CellHealth
- path: []const u8  // .tri or .zig file
- tri_timestamp: i64
- zig_timestamp: i64
- is_stale: bool
- needs_regen: bool

### WaveReport
- wave_id: u4
- cells_checked: u32
- cells_regen: u32
- cells_destroyed: u32
- duration_ms: u64

## Functions
### preWaveRegen(wave_id) !WaveReport
Health check BEFORE each wave.

Algorithm (v1 minimal):
1. Scan .trinity/ directory for .tri files
2. For each .tri:
   - Check if corresponding .zig exists
   - Compare timestamps
   - If .tri newer OR .zig missing → mark for regen
3. Log all findings
4. Return WaveReport with stats

Note: v1 does NOT actually regenerate — only logs.

### biopsy(cell_path) !RegenDecision
Analyze if cell needs regeneration.

Algorithm:
1. Read .tri file, get timestamp
2. Check if .zig exists
3. If .zig exists: compare timestamps
4. Decision:
   - REGEN: .tri newer OR .zig missing
   - SKIP: both exist, .zig newer or same age
   - DESTROY: .zig exists but .tri deleted (rare)

### scanCorruption() ![][]const u8
Scan .trinity/ for corruption.

Algorithm:
1. Walk .trinity/experience/episodes/
2. Try to parse each JSON file
3. Collect files that fail to parse
4. Return list of corrupted files

## Integration Points
- Pre-wave: phoenix_bridge.preWaveRegen()
- Link 28: phoenix_lineage_update → save lineage metadata

## Lineage Tracking (Future)
Lineage metadata tracks evolution of each cell:
- parent_spec: []const u8
- generation: u32
- mutations: []Mutation
- fitness_history: []f32

For v1: lineage is minimal (just logging).
