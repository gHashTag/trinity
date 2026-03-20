# Storm Main CLI

## Binary
storm

## Description
Main entry point for Trinity STORM operation — 32-agent, 5-wave autonomous system.

## Commands
- init: Scaffold .trinity/storm/ structure
- run: Execute STORM with --waves=N --agents=M --config=PATH
- status: Show checkpoint status --wave=N
- resume: Continue from --checkpoint=ID

## Dependencies
- std (zig standard library)
- storm.config (Config parser)
- storm.golden_chain (Core orchestration)
- storm.phoenix_bridge (Self-healing)

## Functions
### main() !u8
Entry point. Parse args, dispatch to commands.

### cmdInit(allocator) !void
Create .trinity/storm/ directories and default config.json.

### cmdRun(allocator, args) !u8
Parse --waves, --agents, --config. Initialize GoldenChain, execute.

### cmdStatus(allocator, args) !u8
Read latest checkpoint, display wave progress.

### cmdResume(allocator, args) !u8
Load checkpoint, call GoldenChain.resume().

## Structs
### Command
enum { init, run, status, resume }

### Config
- waves: u4 = 5
- agents: u8 = 32
- config_path: []const u8 = ".trinity/storm/config.json"
- checkpoint_dir: []const u8 = ".trinity/storm/checkpoints/"

## Error Handling
Return exit code 1 on error, 0 on success.
