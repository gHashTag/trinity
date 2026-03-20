# tri experience — MNL Engine

## Module
tri.experience

## Description
MNL (Mistake Never Again) pattern engine. Consults before action, records after.

## Subcommands
- `tri experience consult <task>`
- `tri experience save --episode`
- `tri experience stats`

## Structs
### TaskContext
- task: []const u8
- similar_tasks: []SimilarTask
- is_blacklisted: bool

### Episode
- task: []const u8
- agent: []const u8
- start_time: i64
- end_time: i64
- success: bool
- error: ?[]const u8
- learnings: [][]const u8

## Storage
- episodes: .trinity/experience/episodes/
- similar_tasks: .trinity/experience/similar_tasks.json
- blacklist: .trinity/mistakes/blacklist.json

## Functions
### consult(task) !TaskContext
Check similar_tasks.json and blacklist BEFORE action.

### recordFailure(task, error) !void
Update blacklist on failure.

### saveEpisode(episode) !void
Persist episode with learnings.
