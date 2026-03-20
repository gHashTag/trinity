# Brain Learning System — Hippocampal Pattern Recognition

## Overview

The Brain Learning System (`src/brain/learning.zig`) implements adaptive intelligence for the Trinity S³AI neuroanatomy. It tracks historical performance, recognizes patterns, and provides recommendations for optimizing system behavior.

## Architecture

### Biological Mapping

- **Cerebellum**: Motor Learning & Adaptive Performance
- **Hippocampus**: Memory Consolidation (pattern recognition from historical data)

### Core Components

1. **LearningSystem**: Main orchestrator for learning operations
2. **PerformanceRecord**: Records operation outcomes with metadata
3. **Pattern**: Detected patterns with confidence scores
4. **AdaptiveBackoffConfig**: Dynamic backoff strategy tuning
5. **FailurePrediction**: Probabilistic failure forecasting

## Data Structures

### PerformanceRecord

```zig
pub const PerformanceRecord = struct {
    timestamp: i64,
    operation: OperationType,
    duration_ms: u64,
    success: bool,
    metadata: Metadata,
};
```

### OperationType

- `task_claim`: Agent claiming a task
- `task_complete`: Task completion
- `task_fail`: Task failure
- `backoff_wait`: Backoff delay applied
- `health_check`: Health monitoring
- `farm_recycle`: Farm recycling operation
- `service_deploy`: Service deployment
- `agent_run`: Agent execution

### Pattern Types

- `backoff_optimal`: Optimal backoff value discovered
- `failure_imminent`: High failure rate detected
- `performance_degrading': Performance declining over time
- `optimal_window`: Best timing window identified
- `resource_constraint`: Resource limit detected

## CLI Usage

```bash
# Show learning system status
tri brain --learn status

# Predict failure probability for an operation
tri brain --learn predict task_claim

# Get recommendations
tri brain --learn recommend

# Calculate adaptive backoff delay
tri brain --learn backoff --strategy adaptive --attempt 3

# Force pattern retraining
tri brain --learn retrain
```

## Backoff Strategies

### Exponential
`delay = initial_ms * multiplier^attempt`

### Linear
`delay = initial_ms + (attempt * 1000)`

### Phi-Weighted
`delay = initial_ms * φ^attempt` where φ = 1.618

### Adaptive (Recommended)
Uses learned multiplier with phi-based jitter:
- Even attempts: multiply by 1.618
- Odd attempts: multiply by 0.618

## Pattern Recognition

The system automatically learns patterns every 100 records:

1. **Optimal Backoff Detection**: Analyzes which backoff values have highest success rates
2. **Failure Pattern Detection**: Monitors recent failure rates
3. **Performance Degradation**: Compares first half vs second half of history
4. **Optimal Windows**: Time-of-day success patterns (TODO)

## Persistence

- Learning history stored in `.trinity/brain/learning_history.jsonl`
- JSONL format for easy parsing and analysis
- Max 10,000 records (FIFO)

## Integration

```zig
const brain = @import("brain");
const learning = brain.learning;

var sys = try learning.LearningSystem.init(allocator);
defer sys.deinit();

// Record an operation
try sys.recordEvent(.{
    .timestamp = std.time.milliTimestamp(),
    .operation = .task_claim,
    .duration_ms = 100,
    .success = true,
    .metadata = .{ .task_id = "task-123", .agent_id = "agent-1", ... },
});

// Get adaptive backoff
const delay = sys.getBackoffDelay(3);

// Predict failure
const prediction = sys.predictFailure(.task_claim);

// Get recommendations
const rec = sys.getRecommendation();
```

## Testing

```bash
zig test src/brain/learning.zig
```

Tests cover:
- Initialization and recording
- Backoff calculations (all strategies)
- Failure prediction
- Pattern detection
- Statistics tracking

## Future Enhancements

- Full JSON parsing for history loading
- Time-of-day pattern analysis
- Multi-factor correlation analysis
- Reinforcement learning integration
- Cross-instance learning federation
