# Brain Federation Protocol

## Overview

The Brain Federation protocol enables multiple Trinity instances to coordinate as a distributed brain. Each instance acts as a "hemisphere" in the federated brain, communicating via HTTP/WebSocket to achieve consensus on task execution, leader election, and health monitoring.

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
const id = InstanceId.generate();
const id_str = try id.format(allocator); // "550e8400-e29b-41d4-a716-446655440000"
```

### Instance Status

- `online`: Instance is participating normally
- `degraded`: Instance is temporarily offline (grace period)
- `offline`: Instance is beyond grace period
- `leader`: Instance is the elected leader
- `follower`: Instance is following the leader
- `candidate`: Instance is participating in leader election

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

1. Instances start as `followers`
2. If no heartbeat is received, an instance becomes a `candidate`
3. Candidate requests votes from all instances
4. Instance with majority votes becomes `leader`
5. Leader sends heartbeats to maintain authority

```zig
// Start election
federation.election.startElection();

// Check if I am leader
if (federation.amILeader()) {
    // Act as leader
}

// Get current leader
if (federation.getLeader()) |leader| {
    const leader_str = try leader.format(allocator);
}
```

## Conflict Resolution

### Duplicate Claim Resolution

When two instances claim the same task:

1. Compare instance IDs deterministically
2. Lower ID wins (tiebreaker)
3. Loser abandons the claim

```zig
const winner = try resolver.resolveDuplicateClaim(task_id, claimant1, claimant2);
```

### Heartbeat Timeout

When a task owner stops sending heartbeats:

1. Other instances can claim the task after timeout
2. Original owner can reclaim by refreshing heartbeat

```zig
const can_claim = try resolver.resolveHeartbeatTimeout(task_id, owner);
```

### Completion Inconsistency

When instances disagree on task completion:

1. Use majority vote from all instances
2. If majority says completed, mark as completed

```zig
const completed = try resolver.resolveCompletionInconsistency(task_id, completions, total_instances);
```

## CRDT State Synchronization

### G-Counter (Grow-only Counter)

For metrics that only increase:

```zig
var counter = GCounter.init(allocator);
try counter.increment(my_instance_id, 5);
const total = counter.value();
```

### LWW-Register (Last-Write-Wins)

For single values where latest write wins:

```zig
var reg = try LWWRegister.init(allocator, "value1");
try reg.set(allocator, "value2", my_instance_id);
_ = try reg.merge(allocator, &other_reg);
```

## CLI Commands

```bash
# Show federation status
tri brain federation status

# Join a federation
tri brain federation join 192.168.1.100:8080

# Leave the federation
tri brain federation leave

# Initiate leader election
tri brain federation elect

# Show aggregated health
tri brain federation health
```

## Usage Example

```zig
const federation = try brain.federation.getGlobal(allocator);

// Create distributed task claim system
var task_claim = DistributedTaskClaim{
    .allocator = allocator,
    .federation = federation,
    .registry = registry,
    .event_bus = event_bus,
};

// Claim a task (with federation coordination)
const claimed = try task_claim.claim("task-123", "agent-001", 60000);

// Complete a task
try task_claim.complete("task-123", "agent-001", 5000);

// Check if I am the leader
if (federation.amILeader()) {
    // Perform leader-only actions
}
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
