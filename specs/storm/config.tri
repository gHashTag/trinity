# Storm Config

## Module
storm.config

## Description
Configuration parser and defaults for STORM operations.

## Structs
### StormConfig
- waves: u4 = 5
- agents: u8 = 32
- config_path: []const u8 = ".trinity/storm/config.json"
- checkpoint_dir: []const u8 = ".trinity/storm/checkpoints/"
- log_level: LogLevel = .info

### LogLevel
enum { debug, info, warn, err }

### WaveConfig (for each wave)
- wave_id: u4
- agent_count: u8
- parallel: bool = true
- timeout_ms: u64 = 300_000

### AgentConfig
- max_concurrent: u8 = 10  // Max agents running at once
- heartbeat_interval_ms: u64 = 30_000
- retry_count: u3 = 3

## Default Config JSON
```json
{
  "waves": 5,
  "agents": 32,
  "checkpoint_dir": ".trinity/storm/checkpoints/",
  "log_level": "info",
  "max_concurrent_agents": 10,
  "heartbeat_interval_ms": 30000,
  "retry_count": 3,
  "wave_configs": [
    {"wave_id": 1, "agent_count": 3, "parallel": true, "timeout_ms": 300000},
    {"wave_id": 2, "agent_count": 4, "parallel": true, "timeout_ms": 300000},
    {"wave_id": 3, "agent_count": 16, "parallel": true, "timeout_ms": 600000},
    {"wave_id": 4, "agent_count": 5, "parallel": true, "timeout_ms": 300000},
    {"wave_id": 5, "agent_count": 4, "parallel": false, "timeout_ms": 300000}
  ]
}
```

## Functions
### load(allocator, path) !StormConfig
Load config from JSON file. Use defaults if file missing.

### save(config) !void
Save config to config_path.

### defaults() StormConfig
Return default StormConfig.

### validate(config) !void
Validate config values (waves <= 10, agents <= 100, etc.).
