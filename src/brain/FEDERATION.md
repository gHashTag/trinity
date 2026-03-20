# Brain Federation System — Distributed Multi-Instance Coordination

## Overview

The Brain Federation system enables multiple Trinity instances to coordinate as a distributed brain. Each instance acts as a "hemisphere" in the federated brain, communicating via HTTP/WebSocket to achieve consensus on task execution, leader election, and health monitoring.

**Brain Region**: Corpus Callosum (Inter-Hemispheric Communication)

**Sacred Formula**: φ² + 1/φ² = 3 = TRINITY

**Version**: v1.0

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Distributed Brain Network                    │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │ Hemisphere  │  │ Hemisphere  │  │ Hemisphere  │            │
│  │   Alpha     │  │   Beta      │  │   Gamma     │            │
│  │             │  │             │  │             │            │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │            │
│  │ │ Leader  │ │  │ │Follower │ │  │ │Follower │ │            │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
│         │                │                 │                   │
│         └────────────────┼─────────────────┘                   │
│                          │                                     │
│                  ┌───────▼────────┐                            │
│                  │ Federation    │                            │
│                  │  Protocol     │                            │
│                  └───────────────┘                            │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Instance ID

Each Trinity instance has a unique UUID v4 identifier:

```zig
const id = federation.InstanceId.generate();
const id_str = try id.format(allocator); // "550e8400-e29b-41d4-a716-446655440000"

// Parse from string
const parsed = try federation.InstanceId.parse("550e8400-e29b-41d4-a716-446655440000");

// Compare two IDs
const order = id.compareTo(&parsed);
```

### Instance Status

- `online`: Instance is participating normally
- `degraded`: Instance is temporarily offline (grace period)
- `offline`: Instance is beyond grace period
- `leader`: Instance is the elected leader
- `follower`: Instance is following the leader
- `candidate`: Instance is participating in leader election

### Instance Info

```zig
pub const InstanceInfo = struct {
    id: InstanceId,
    address: []const u8,        // "host:port"
    status: InstanceStatus,
    last_heartbeat: i64,
    term: u64,                  // Current election term
    voted_for: ?InstanceId,
    claim_count: usize,
    event_count: usize,
    health_score: f32,
};
```

### Federation Messages

```zig
pub const FederationMessage = struct {
    msg_type: MessageType,
    from: InstanceId,
    to: InstanceId,
    term: u64,
    timestamp: i64,
    data: MessageData,
};
```

Message types:
- `heartbeat`: Liveness signal
- `claim_request`: Request to claim a task
- `claim_response`: Response to claim request
- `task_complete`: Task completion notification
- `vote_request`: Leader election vote request
- `vote_response`: Leader election vote response
- `append_entries`: Log replication entry
- `health_query`: Health status query
- `health_response`: Health status response
- `conflict_resolve`: Conflict resolution request

## Leader Election

Uses a Raft-inspired consensus algorithm:

```zig
pub const ElectionState = struct {
    current_term: u64,
    voted_for: ?InstanceId,
    leader_id: ?InstanceId,
    state: enum { follower, candidate, leader },
};
```

**Algorithm:**
1. Instances start as `followers`
2. If no heartbeat is received, an instance becomes a `candidate`
3. Candidate requests votes from all instances
4. Instance with majority votes becomes `leader`
5. Leader sends heartbeats to maintain authority

```zig
// Start election
var election = ElectionState.init();
election.startElection();

// Check if I am leader
if (election.state == .leader) {
    // Act as leader
}

// Get current leader
if (election.leader_id) |leader| {
    const leader_str = try leader.format(allocator);
}
```

## Conflict Resolution

### Conflict Types

```zig
pub const ConflictType = enum(u8) {
    duplicate_claim,          // Multiple instances claimed the same task
    heartbeat_timeout,        // Task heartbeat timeout
    completion_inconsistent,  // Task completion inconsistency
};
```

### Duplicate Claim Resolution

When two instances claim the same task:

1. Compare instance IDs deterministically
2. Lower ID wins (tiebreaker)
3. Loser abandons the claim

```zig
// In message data
conflict_resolve: struct {
    task_id: []const u8,
    conflict_type: ConflictType,
    resolving_instance: []const u8,
},
```

## Usage Example

```zig
const brain = @import("brain");
const federation = brain.federation;

// Generate instance ID
const my_id = federation.InstanceId.generate();

// Initialize election state
var election = federation.ElectionState.init();

// Create federation message
const msg = federation.FederationMessage{
    .msg_type = .claim_request,
    .from = my_id,
    .to = peer_id,
    .term = election.current_term,
    .timestamp = std.time.milliTimestamp(),
    .data = .{
        .claim_request = .{
            .task_id = "task-123",
            .agent_id = "agent-001",
            .ttl_ms = 60000,
        },
    },
};
defer msg.deinit(allocator);
```

## Integration with Other Brain Regions

The federation module integrates with:

- **Basal Ganglia** (`basal_ganglia`): For distributed task claiming
- **Reticular Formation** (`reticular_formation`): For event broadcasting
- **Locus Coeruleus** (`locus_coeruleus`): For backoff in retry logic

```zig
// Combine with basal ganglia for distributed task claims
const registry = try brain.basal_ganglia.getGlobal(allocator);
const claimed = try registry.claim(allocator, task_id, agent_id, ttl_ms);

// Publish to event bus
const event_bus = try brain.reticular_formation.getGlobal(allocator);
try event_bus.publish(.task_claimed, .{
    .task_claimed = .{ .task_id = task_id, .agent_id = agent_id }
});
```

## Protocol Limitations (Current Implementation)

The current implementation provides in-memory coordination only. Full federation support requires:

1. **HTTP/WebSocket Transport**: For inter-instance communication
2. **Persistent State**: For crash recovery
3. **Security**: TLS encryption and authentication
4. **Network Partition Handling**: For split-brain scenarios

## Future Enhancements

1. Implement WebSocket transport for real-time communication
2. Add persistent federation state storage
3. Implement network partition detection and recovery
4. Add TLS certificate-based authentication
5. Implement full Raft log replication
6. Add federation metrics and observability

## References

- Raft Consensus Algorithm: https://raft.github.io/
- CRDTs: Conflict-free Replicated Data Types
- Brain Regions: Corpus Callosum (Inter-Hemispheric Communication)

## See Also

- **Federation Protocol**: `src/brain/FEDERATION_PROTOCOL.md`
- **Brain Atlas**: `docs/BRAIN_ATLAS.md`
- **Architecture Overview**: `docs/BRAIN_ARCHITECTURE.md`
