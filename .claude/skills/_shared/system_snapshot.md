# System Snapshot — Shared Cache & Event Log

All skills and agents SHOULD use these cached snapshots to avoid duplicate API calls.

## Issue Snapshot

**File**: `.trinity/issues_snapshot.json`
**TTL**: 300 seconds (5 min)
**Writer**: Any skill/agent that needs issue data
**Reader**: All skills and agents

```bash
cd /Users/playra/trinity-w1 && \
if [ -f .trinity/issues_snapshot.json ] && [ $(($(date +%s) - $(stat -f %m .trinity/issues_snapshot.json))) -lt 300 ]; then
  echo "CACHED" && cat .trinity/issues_snapshot.json
else
  gh issue list -R gHashTag/trinity --state open --limit 50 --json number,title,labels,assignees > .trinity/issues_snapshot.json 2>&1 && echo "REFRESHED" && cat .trinity/issues_snapshot.json
fi
```

## Board Snapshot

**File**: `.trinity/board_snapshot.json`
**TTL**: 300 seconds (5 min)
**Writer**: Any skill/agent that needs board data
**Reader**: All skills and agents

```bash
cd /Users/playra/trinity-w1 && \
if [ -f .trinity/board_snapshot.json ] && [ $(($(date +%s) - $(stat -f %m .trinity/board_snapshot.json))) -lt 300 ]; then
  echo "CACHED" && cat .trinity/board_snapshot.json
else
  gh project item-list 6 --owner gHashTag --format json --limit 50 > .trinity/board_snapshot.json 2>&1 && echo "REFRESHED" && cat .trinity/board_snapshot.json
fi
```

## System State

**File**: `.trinity/system_state.json`
**TTL**: 60 seconds (1 min)
**Writer**: Orchestrator Phase 1, or any agent needing build status
**Reader**: All skills and agents

Format:
```json
{
  "ts": 1710000000,
  "build": "PASS|FAIL",
  "tests": "PASS|FAIL",
  "binaries": 6,
  "dirty_files": 12
}
```

## Event Log

**File**: `.trinity/event_log.jsonl`
**Format**: Append-only JSONL
**Writer**: Agents after completing actions
**Reader**: Orchestrator Phase 0, any skill needing action history

Each line:
```json
{"ts":1710000000,"agent":"tri-doctor","action":"build_fix","detail":"fixed std.time.sleep → std.Thread.sleep","result":"OK"}
```

### Skip Rules (for orchestrator)

When reading event log, apply these freshness rules:
- `tri-doctor` action=`build_fix` result=`OK` within 15 min → skip build check
- `tri-farmer` action=`evolve` within 15 min → skip farm delegation
- `tri-orchestrator` action=`report` within 15 min → skip entire run

### Writing Events

After any state-changing action, append:
```bash
echo '{"ts":'$(date +%s)',"agent":"AGENT_NAME","action":"ACTION","detail":"DETAIL","result":"OK|FAIL"}' >> /Users/playra/trinity-w1/.trinity/event_log.jsonl
```
