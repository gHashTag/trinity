# Experience Engine — MNL Core

## Module
storm.experience_engine

## Description
MNL (Mistake Never Again) pattern engine. Consults experience before action, records after action.

## Dependencies
- std
- std.crypto.hash.sha256 (for task hashing)

## Structs
### TaskContext
- task: []const u8
- similar_tasks: []SimilarTask
- is_blacklisted: bool
- failure_count: u3

### SimilarTask
- task_name: []const u8
- success_rate: f32  // 0-1
- last_attempt: i64
- outcome: []const u8

### Episode
- task: []const u8
- agent: []const u8
- start_time: i64
- end_time: i64
- success: bool
- error: ?[]const u8
- learnings: [][]const u8

## Storage Paths
- experience_dir: ".trinity/experience/episodes/"
- similar_tasks: ".trinity/experience/similar_tasks.json"
- blacklist: ".trinity/mistakes/blacklist.json"

## Functions
### consult(ctx, task) !?TaskContext
Check similar tasks BEFORE action.

Algorithm (v1 minimal):
1. Hash task with SHA-256
2. If similar_tasks.json exists:
   - Parse JSON
   - Find tasks with similar hash (fuzzy match)
   - Return top 3 with success rates
3. If blacklist.json exists:
   - Check if task is blacklisted
   - Set is_blacklisted flag
4. Return TaskContext

### isBlacklisted(ctx, task) bool
Quick blacklist check.

Algorithm:
1. Load .trinity/mistakes/blacklist.json
2. Hash task
3. Lookup exact match
4. Return true if failure_count >= 3

### recordFailure(ctx, task, error) !void
Record failure after action.

Algorithm:
1. Load blacklist.json
2. Hash task, lookup/create entry
3. Increment failure_count
4. Atomic write back

### saveEpisode(ctx, episode) !void
Save completed episode to experience.

Algorithm:
1. Generate filename: {timestamp}_{agent}_{hash}.json
2. Write to .trinity/experience/episodes/
3. Update similar_tasks.json (rebuild index)

## File Formats

### similar_tasks.json
```json
{
  "tasks": [
    {
      "hash": "abc123...",
      "task_name": "vibee codegen",
      "success_count": 5,
      "failure_count": 1,
      "success_rate": 0.833,
      "last_attempt": 1710890123456
    }
  ],
  "version": 1
}
```

### blacklist.json
```json
{
  "entries": [
    {
      "task_hash": "def456...",
      "task_name": "broken task",
      "failure_count": 3,
      "first_failed_at": 1710890000000,
      "last_failed_at": 1710890200000,
      "error_pattern": "connection refused"
    }
  ],
  "version": 1
}
```

### Episode file: {timestamp}_{agent}_{hash}.json
```json
{
  "task": "implement feature X",
  "agent": "agent-1",
  "start_time": 1710890123456,
  "end_time": 1710890129999,
  "success": true,
  "error": null,
  "learnings": ["use async pattern", "avoid blocking I/O"]
}
```

## Integration Points
- Link 2: check_experience_blacklist → consult()
- Link 3: find_similar_tasks → consult()
- Link 27: experience_save → saveEpisode()
