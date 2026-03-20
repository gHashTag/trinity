# tri storm — STORM Subcommand Integration

## Module
tri.storm (storm subcommand handler)

## Description
Integrate STORM operation as `tri storm <command>` subcommand.
All storm functionality accessed through single `tri` binary.

## Dependencies
- tri.storm.config
- tri.storm.golden_chain
- tri.storm.phoenix_bridge
- tri.storm.brain_zones.ofc
- tri.storm.brain_zones.habenula
- tri.storm.brain_zones.amygdala

## Integration Points
### src/tri/main.zig
Add storm command case:
```zig
// In main() command dispatch
if (std.mem.eql(u8, command, "storm")) {
    if (command_args.len == 0) {
        try storm.printUsage();
        return 1;
    }
    const storm_subcommand = command_args[0];
    const storm_args = command_args[1..];
    return try storm.execute(allocator, storm_subcommand, storm_args);
}
```

### src/tri/storm.zig (NEW MODULE)
```zig
const storm_config = @import("storm/config.zig");
const golden_chain = @import("storm/golden_chain.zig");
const phoenix_bridge = @import("storm/phoenix_bridge.zig");
const ofc = @import("storm/brain_zones/ofc.zig");
const habenula = @import("storm/brain_zones/habenula.zig");
const amygdala = @import("storm/brain_zones/amygdala.zig");

pub const StormCommand = enum {
    run,
    status,
    resume,
    init,
};

pub fn execute(allocator: Allocator, subcommand: []const u8, args: [][]const u8) !u8 {
    const config = try storm_config.load(allocator, ".trinity/storm/config.json");

    if (std.mem.eql(u8, subcommand, "run")) {
        return try cmdRun(allocator, config, args);
    } else if (std.mem.eql(u8, subcommand, "status")) {
        return try cmdStatus(allocator, config, args);
    } else if (std.mem.eql(u8, subcommand, "resume")) {
        return try cmdResume(allocator, config, args);
    } else if (std.mem.eql(u8, subcommand, "init")) {
        return try cmdInit(allocator);
    }

    std.debug.print("Unknown storm subcommand: {s}\\n", .{subcommand});
    try printUsage();
    return 1;
}

fn cmdRun(allocator: Allocator, config: StormConfig, args: [][]const u8) !u8 {
    // Parse --waves=N, --agents=M, --config=PATH
    // Initialize GoldenChain
    // Execute 5-wave operation
    _ = allocator;
    _ = config;
    _ = args;
    std.debug.print("STORM RUN: 5 waves, 32 agents\\n", .{});
    return 0;
}

fn cmdStatus(allocator: Allocator, config: StormConfig, args: [][]const u8) !u8 {
    _ = allocator;
    _ = config;
    _ = args;
    // Read checkpoint, display progress
    std.debug.print("STORM STATUS\\n", .{});
    return 0;
}

fn cmdResume(allocator: Allocator, config: StormConfig, args: [][]const u8) !u8 {
    _ = allocator;
    _ = config;
    _ = args;
    // Load checkpoint, continue
    std.debug.print("STORM RESUME\\n", .{});
    return 0;
}

fn cmdInit(allocator: Allocator) !u8 {
    _ = allocator;
    // Create .trinity/storm/ directories
    std.debug.print("STORM INIT\\n", .{});
    return 0;
}

fn printUsage() !void {
    std.debug.print(
        \\STORM — Self-Organizing Regenerative Task Management\\n
        \\Usage: tri storm <command> [options]\\n\\n
        \\Commands:\\
        \\  run        Execute STORM operation\\n
        \\  status     Show checkpoint status\\n
        \\  resume     Continue from checkpoint\\n
        \\  init       Scaffold STORM structure\\n
        \\Options:\\n
        \\  --waves N     Number of waves (default: 5)\\n
        \\  --agents M    Number of agents (default: 32)\\n
        \\  --config PATH Config file path\\n
    , .{}
    );
}
```

## CLI Patterns
All storm commands use `tri storm <subcommand>` pattern:
```bash
tri storm run                    # Run with defaults (5 waves, 32 agents)
tri storm run --waves=3          # 3 waves
tri storm run --agents=16          # 16 agents
tri storm run --config=custom.json  # Custom config
tri storm status                 # Show checkpoint status
tri storm resume                  # Resume from latest checkpoint
tri storm resume --checkpoint=123   # Resume from specific checkpoint
tri storm init                   # Initialize STORM structure
```

## Build Integration
### build.zig
Add storm source module:
```zig
const storm_mod = b.addModule(.{
    .root_source_file = b.path("src/storm"),
    .target = target,
    .optimize = optimize,
});
```

No separate `storm` binary. Everything compiles into `tri`.

## Directory Structure
```
src/
├── tri/
│   ├── main.zig              # Updated: add storm case
│   ├── storm.zig             # NEW: storm subcommand handler
│   └── config.zig             # Updated: reuse existing
└── storm/                       # All storm modules (existing)
    ├── config.zig
    ├── golden_chain.zig
    ├── phoenix_bridge.zig
    ├── main.zig               # DELETE: separate binary entry
    └── brain_zones/
        ├── ofc.zig
        ├── habenula.zig
        └── amygdala.zig
```

## Tests
- Command dispatch: run/status/resume/init
- Arg parsing: --waves, --agents, --config
- Config loading and validation
- Checkpoint I/O
