# tri brain amygdala — Mistake Memory

## Module
tri.brain.amygdala

## Description
Corpus amygdaloideum — fear conditioning, mistake tracker. Enforces MNL (3x failed = blacklist).

## Subcommands
- `tri brain amygdala check-fear <task>`
- `tri brain amygdala blacklist`

## Neuroanatomy
Amygdala — aversive stimulus encoding, fear response.

## Structs
### BlacklistEntry
- task_hash: [32]u8
- task_name: []const u8
- failure_count: u3 (0-7)
- first_failed_at: i64
- last_failed_at: i64

## Storage
- Path: .trinity/mistakes/blacklist.json
- Format: JSON array

## Functions
### isBlacklisted(task) bool
Check if task failed 3+ times.

### recordFailure(task, error) !void
Record failure, add to blacklist on 3rd.

### shouldSkip(task) bool
Convenience: failure_count >= 3

## MNL Pattern
Before any action: if amygdala.isBlacklisted(task) → skip
After failure: amygdala.recordFailure(task, error)
