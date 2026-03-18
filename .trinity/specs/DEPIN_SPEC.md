# DePIN Specification

## Overview
DePIN (Decentralized Physical Infrastructure Network) integration for Trinity.

## Commands
```bash
tri depin status     # Show DePIN node status
tri depin nodes      # List all nodes
tri depin fitness    # Show node fitness scores
```

## Integration Points
- Railway containers as DePIN nodes
- Fitness scoring based on training contribution
- Reward distribution via token

## TODO
- [ ] Implement `src/tri/tri_depin.zig` status command
- [ ] Add fitness calculation
- [ ] Connect to reward token
