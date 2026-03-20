# tri storm — STORM Operation

## Module
tri.storm

## Description
STORM (Self-Organizing Regenerative Task Management) as subcommand of tri CLI.

## Commands (as tri subcommands)
- run: Execute 5-wave, 32-agent operation --waves=N --agents=M --config=PATH
- status: Show checkpoint status --wave=N
- resume: Continue from checkpoint --checkpoint=ID
- init: Scaffold .trinity/storm/ structure

## Implementation
These are SUBCOMMANDS of tri, implemented in src/tri/storm.zig:

```zig
// src/tri/storm.zig
pub const StormCommand = enum {
    run,
    status,
    resume,
    init,
};

pub fn executeStormCommand(allocator: Allocator, args: [][]const u8) !u8 {
    // Parse "tri storm <subcommand>" pattern
    // Delegate to storm_protocol, golden_chain
}
```

No separate binary. Everything inside tri.

## CLI Integration
In src/tri/main.zig, add storm case:
```zig
if (std.mem.eql(u8, command, "storm")) {
    return storm.executeStormCommand(allocator, command_args);
}
```

## Dependencies
- storm.golden_chain (28-link pipeline)
- storm.phoenix_bridge (self-healing)
- storm.brain_zones.ofc (toxic verdict)
- storm.brain_zones.habenula (anti-corruption)
- storm.brain_zones.amygdala (MNL pattern)
- tri.experience (reuse)
- tri.swarm (reuse)

## Error Handling
Return exit code 1 on error, 0 on success.
