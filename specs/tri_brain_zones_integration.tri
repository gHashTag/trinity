# tri brain — Brain Zone Subcommands

## Module
tri.brain_zones

## Description
Brain zone subcommands integrated into tri CLI.
All 22 neuroanatomical zones accessible as `tri <zone> <action>`.

## Dependencies
- tri.brain_zones.ofc
- tri.brain_zones.habenula
- tri.brain_zones.amygdala
- tri.experience (for hippocampus)

## Integration Points
### src/tri/main.zig
Add brain command case:
```zig
// In main() command dispatch
if (std.mem.eql(u8, command, "brain")) {
    if (command_args.len < 2) {
        try printBrainUsage();
        return 1;
    }
    const zone_name = command_args[0];
    const action = command_args[1];
    const action_args = command_args[2..];
    return try brain_zones.execute(allocator, zone_name, action, action_args);
}
```

### src/tri/brain_zones.zig (NEW MODULE)
```zig
const ofc = @import("brain_zones/ofc.zig");
const habenula = @import("brain_zones/habenula.zig");
const amygdala = @import("brain_zones/amygdala.zig");
const hippocampus = @import("brain_zones/hippocampus.zig");

pub const BrainZone = enum {
    ofc, habenula, amygdala, hippocampus,
    // TODO: Add remaining 18 zones
    // cortex, dlpfc, acc, broca, wernicke, insula,
    // accumbens, fornix, striatum, pallidus, nigra,
    // thalamus, hypothalamus, colliculus_s, colliculus_i,
    // ruber, pag, vta, cerebellum, vermis, pons,
    // medulla, coeruleus, raphe,
};

pub const Action = enum {
    verdict, unfair_detect, check_fear, save_episode, consult,
    // ... zone-specific actions
};

pub fn execute(allocator: Allocator, zone_str: []const u8, action_str: []const u8, args: [][]const u8) !u8 {
    const zone = std.meta.stringToEnum(BrainZone, zone_str) catch {
        std.debug.print("Unknown brain zone: {s}\\n", .{zone_str});
        return 1;
    };

    return switch (zone) {
        .ofc => {
            if (std.mem.eql(u8, action_str, "verdict")) {
                return ofc.cmdVerdict(allocator, args);
            }
        },
        .habenula => {
            if (std.mem.eql(u8, action_str, "unfair_detect")) {
                return habenula.cmdUnfairDetect(allocator, args);
            }
        },
        .amygdala => {
            if (std.mem.eql(u8, action_str, "check_fear")) {
                return amygdala.cmdCheckFear(allocator, args);
            }
        },
        .hippocampus => {
            if (std.mem.eql(u8, action_str, "save_episode")) {
                return hippocampus.cmdSaveEpisode(allocator, args);
            }
        },
        else => {
            std.debug.print("Action not implemented for zone\\n", .{});
            return 1;
        },
    };
}
```

## CLI Patterns
All brain zone commands use `tri <zone> <action>` pattern:
```bash
# OFC — Палата ценностей
tri ofc verdict --toxic "action description"    # Check toxicity
tri ofc dimensions                       # List 12 dimensions

# HABENULA — Антикоррупционный датчик
tri habenula unfair_detect               # Scan recent rewards
tri habenula check <reward> <effort>     # Single check

# AMYGDALA — Страж ошибок
tri amygdala check_fear "task"           # Check fear level
tri amygdala list                          # Show blacklist
tri amygdala clear "task"                 # Manual override

# HIPPOCAMPUS — Хранилище опыта
tri hippocampus save_episode                # Save new episode
tri hippocampus consult "task"              # Find similar tasks
```

## Directory Structure
```
src/
├── tri/
│   ├── main.zig              # Updated: add brain case
│   ├── storm.zig             # storm subcommand
│   └── brain_zones.zig        # NEW: unified zone handler
└── storm/brain_zones/          # Existing implementations
    ├── ofc.zig
    ├── habenula.zig
    └── amygdala.zig
```

## Brain Zone Map
| Zone | Russian Name | CLI Subcommand | Actions |
|------|-------------|---------------|----------|
| OFC | Палата ценностей | `tri ofc` | verdict, dimensions |
| HABENULA | Антикоррупция | `tri habenula` | unfair_detect, check, status |
| AMYGDALA | Страж ошибок | `tri amygdala` | check_fear, list, clear |
| HIPPOCAMPUS | Хранилище опыта | `tri hippocampus` | save, consult, recall |
| ACCUMBENS | Reward Engine | `tri accumbens` | distribute, balance |
| FORNIX | Магистраль памяти | `tri fornix` | sync, export, import |
| STRIATUM | Arena отбор | `tri striatum` | arena, fitness, select |
| PALLIDUS | GABA-торможение | `tri pallidus` | inhibit, release, threshold |
| NIGRA | Дофамин-калибратор | `tri nigra` | calibrate, adjust, reset |
| THALAMUS | Центральный хаб | `tri thalamus` | route, switch, monitor |
| HYPOTHALAMUS | Гомеостат | `tri hypothalamus` | regulate, monitor, alert |
| COLliculus_S | Визуальный дашборд | `tri colliculus` | dashboard, listen |
| COLliculus_I | Слушатель | `tri colliculus` | listen, config, mute |
| RUBER | Координатор | `tri ruber` | coordinate, sync, status |
| PAG | Экстренный контур | `tri pag` | emergency, activate, deactivate |
| VTA | Мотиватор агентов | `tri vta` | motivate, reward, track |
| CEREBELLUM | Исполнительная машина | `tri cerebellum` | execute, verify, bench |
| VERMIS | Балансировщик нагрузки | `tri vermis` | balance, report, adjust |
| PONS | Мост между контурами | `tri pons` | relay, bridge, status |
| MEDULLA | Автономная инфраструктура | `tri medulla` | infra, deploy, status |
| COERULEUS | Серотониновый стабилизатор | `tri coeruleus` | stress_signal, stabilize, inject |
| RAPHE | Серотониновый стабилизатор | `tri raphe` | stabilize, modulate, status |

## Build Integration
### build.zig
Add brain_zones module:
```zig
const brain_zones_mod = b.addModule(.{
    .root_source_file = b.path("src/tri/brain_zones.zig"),
    .target = target,
    .optimize = optimize,
});
```

## Tests
- Zone name parsing
- Action dispatch per zone
- Unknown zone error handling
- Unknown action error handling
