# AMYGDALA — Страж ошибок (Mistake Guardian)

## Module
storm.brain_zones.amygdala

## Description
Amygdala — MNL (Mistake Never Again) pattern enforcement.
3x failed = auto-SKIP. Fear conditioning from past errors.

## Dependencies
- std

## Structs
### FearLevel
enum {
    none,   // No failures recorded
    low,    // 1-2 failures
    medium, // 3 failures (blacklist threshold)
    high,   // 4+ failures (chronic failure)
}

### BlacklistEntry
- task: []const u8
    failure_count: u8
    last_issue: u32
    last_error: []const u8
    timestamp: i64

### Amygdala
- allocator: std.mem.Allocator
    blacklist_file: []const u8 = ".trinity/mistakes/blacklist.json"
    fear_threshold: u8 = 3

### BiopsyResult
- is_blacklisted: bool
    fear_level: FearLevel
    entry: ?BlacklistEntry = null
    recommendation: []const u8

## Constants
### PHI_FEAR_THRESHOLD
u8 = 3 — based on φ² ≈ 2.618, rounded to 3.

### MAX_FAILURES
u8 = 255 — saturation point for failure count.

## Functions
### init(allocator) !Amygdala
Initialize with default paths.

### isBlacklisted(amg, task) bool
Check if task is blacklisted (3x failed).
- Load blacklist.json
- Return true if failure_count >= fear_threshold

### fearLevel(amg, task) !FearLevel
Get fear level for a task.
- 0 failures → .none
- 1-2 failures → .low
- 3 failures → .medium (blacklist)
- 4+ failures → .high

### recordFailure(amg, task, issue, error_msg) !void
Record failure → blacklist after 3rd.
- Increment failure count
- If newly blacklisted, create detailed entry
- Save to blacklist.json

### biopsy(amg, task) !BiopsyResult
Analyze if task needs avoidance.
- Returns recommendation with fear level
- Suggests SKIP if blacklisted

### cmdCheckFear(allocator, args) !u8
CLI: tri amygdala check-fear "task description"
Display fear level with emoji:
- 😌 for .none
- 😟 for .low
- 😨 for .medium
- 😱 for .high

### cmdListBlacklist(allocator) !u8
CLI: tri amygdala list
Show all blacklisted tasks.

### cmdClear(allocator, task) !u8
CLI: tri amygdala clear "task"
Remove task from blacklist (manual override).

## CLI Integration
```bash
tri amygdala check-fear "task description"  # Check fear level
tri amygdala list                          # Show blacklist
tri amygdala clear "task"                  # Manual override
tri amygdala stats                         # Failure statistics
```

## Files
- .trinity/mistakes/blacklist.json — failure counts
- .trinity/mistakes/entries/ — detailed mistake entries

## MNL Protocol
1. Before ANY action → consult amygdala
2. If blacklisted → SKIP with reason
3. If failed → recordFailure
4. After 3rd failure → auto-blacklist
5. Manual override requires explicit --force flag

## Tests
- New task → not blacklisted, .none fear
- 1 failure → .low fear, not blacklisted
- 3 failures → .medium fear, blacklisted
- 5 failures → .high fear, blacklisted
- Manual override removes from blacklist
