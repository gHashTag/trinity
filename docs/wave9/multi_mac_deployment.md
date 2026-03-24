# Wave 9 Multi-Mac Deployment Guide

## Overview

Deploy Wave 9 training with S3 MultiObj configuration across multiple Mac machines. Each Mac runs a subset of 48 total workers.

## Prerequisites

### On Each Mac
```bash
# 1. Verify Docker Desktop running
docker info

# 2. Verify ports 8000-8048 available
netstat -an | grep 80

# 3. Verify disk space (~50GB free for 48 workers)
df -h

# 4. Clone trinity repository
git clone https://github.com/gHashTag/trinity.git
cd trinity
```

## Device Configuration

Edit `.trinity/wave9_multi_mac.yaml`:

```yaml
devices:
  - id: 1
    hostname: mac-1.local
    workers_start: 1
    workers_count: 16
  - id: 2
    hostname: mac-2.local
    workers_start: 17
    workers_count: 16
```

Or specify 3 Macs for full 48 workers:
```yaml
devices:
  - id: 1
    hostname: mac-1.local
    workers_start: 1
    workers_count: 16
  - id: 2
    hostname: mac-2.local
    workers_start: 17
    workers_count: 16
  - id: 3
    hostname: mac-3.local
    workers_start: 33
    workers_count: 16
```

## Deployment Commands

### Mac 1 (Workers 1-16)
```bash
# Pull latest trinity
cd trinity-w1 && git pull && zig build tri

# Init device 1 (workers 1-16)
tri farm wave9 device-init \
  --device-id 1 \
  --workers-start 1 \
  --workers-count 16

# Start workers
docker-compose -f deploy/docker/docker-compose.wave9-mac-1.yml up -d

# Verify 16 containers running
docker ps | grep wave9 | wc -l  # Should be 16
```

### Mac 2 (Workers 17-32)
```bash
# Pull latest trinity
cd trinity-w1 && git pull && zig build tri

# Init device 2 (workers 17-32)
tri farm wave9 device-init \
  --device-id 2 \
  --workers-start 17 \
  --workers-count 16

# Start workers
docker-compose -f deploy/docker/docker-compose.wave9-mac-2.yml up -d

# Verify 16 containers running
docker ps | grep wave9 | wc -l  # Should be 16
```

### Mac 3 (Workers 33-48)
```bash
# Pull latest trinity
cd trinity-w1 && git pull && zig build tri

# Init device 3 (workers 33-48)
tri farm wave9 device-init \
  --device-id 3 \
  --workers-start 33 \
  --workers-count 16

# Start workers
docker-compose -f deploy/docker/docker-compose.wave9-mac-3.yml up -d

# Verify 16 containers running
docker ps | grep wave9 | wc -l  # Should be 16
```

## Critical Validation: HSLM_SEED Uniqueness

**CRITICAL**: All 48 workers MUST have unique seeds. Duplicate seeds will train identical models.

```bash
# On EACH Mac, verify seeds are unique
docker ps --format "{{.Names}}" | grep wave9 | while read container; do
  echo "=== $container ==="
  docker exec $container printenv HSLM_SEED
done

# Save to file for issue verification
docker ps --format "{{.Names}}" | grep wave9 | while read container; do
  docker exec $container printenv HSLM_SEED
done > /tmp/mac-1-seeds.txt

# Verify no duplicates (should print nothing)
sort /tmp/mac-1-seeds.txt | uniq -d

# Combine all Mac seed files for verification
cat /tmp/mac-1-seeds.txt /tmp/mac-2-seeds.txt /tmp/mac-3-seeds.txt | sort | uniq -d
# If output is empty = all unique, if not = BAD
```

## S3 MultiObj Configuration Verification

```bash
# Check each worker has correct profile
docker exec wave9-worker-1 printenv HSLM_PROFILE
# Expected: s3multiobj

# Check NTP weight (same across all workers)
docker ps --format "{{.Names}}" | grep wave9 | while read container; do
  docker exec $container printenv HSLM_NTP_WEIGHT
done | sort -u
# Expected: single value (e.g., 0.5)

# Check JEPA enabled
docker exec wave9-worker-1 printenv HSLM_JEPA_ENABLED
# Expected: true

# Check NCA enabled
docker exec wave9-worker-1 printenv HSLM_NCA_ENABLED
# Expected: true

# Check loss weights sum to 1.0
docker exec wave9-worker-1 sh -c 'echo "NTP: $HSLM_NTP_WEIGHT, JEPA: $HSLM_JEPA_WEIGHT, NCA: $HSLM_NCA_WEIGHT"'
# Sum should be ~1.0
```

## Logs to Capture for Issue

### Container Status
```bash
# On each Mac
docker ps > docker-ps-mac1.txt
docker ps > docker-ps-mac2.txt
docker ps > docker-ps-mac3.txt

# Compose status
docker-compose -f deploy/docker/docker-compose.wave9-mac-1.yml ps > compose-ps-mac1.txt
docker-compose -f deploy/docker/docker-compose.wave9-mac-2.yml ps > compose-ps-mac2.txt
docker-compose -f deploy/docker/docker-compose.wave9-mac-3.yml ps > compose-ps-mac3.txt
```

### Worker Logs
```bash
# First 100 lines of each worker log
for i in {1..16}; do
  docker logs --tail 100 wave9-worker-$i > worker-$i-log.txt 2>&1
done

# Or capture all logs
for i in {1..16}; do
  docker logs wave9-worker-$i > worker-$i-full.txt 2>&1
done
```

### Resource Usage
```bash
# Snapshot resource usage
docker stats --no-stream > docker-stats-mac1.txt
docker stats --no-stream > docker-stats-mac2.txt
docker stats --no-stream > docker-stats-mac3.txt
```

### Seed Verification File
```bash
# Capture all seeds in one file
docker ps --format "{{.Names}}" | grep wave9 | while read container; do
  docker exec $container printenv HSLM_SEED
done | sort -n > all-seeds.txt
```

## Quick Health Check (One-Liner)

Run on both Macs to verify all workers healthy:

```bash
# Mac 1
docker ps --format "{{.Names}}: {{.Status}}" | grep wave9 | sort

# Mac 2
docker ps --format "{{.Names}}: {{.Status}}" | grep wave9 | sort

# Mac 3
docker ps --format "{{.Names}}: {{.Status}}" | grep wave9 | sort
```

Expected output pattern:
```
wave9-worker-1: Up 5 minutes
wave9-worker-2: Up 5 minutes
...
```

## Issue Template Comment

```markdown
## Wave 9 Multi-Mac Deployment Report

### Configuration
- Mac 1: 16 workers (1-16) @ mac-1.local
- Mac 2: 16 workers (17-32) @ mac-2.local
- Mac 3: 16 workers (33-48) @ mac-3.local
- Total: 48 workers

### Verification Results
- [x] All containers running (48/48)
- [x] HSLM_SEED unique (verified: `sort all-seeds.txt | uniq -d` = empty)
- [x] S3 MultiObj profile set (HSLM_PROFILE = s3multiobj)
- [x] NTP weight = 0.5 across all workers
- [x] JEPA enabled (HSLM_JEPA_ENABLED = true)
- [x] NCA enabled (HSLM_NCA_ENABLED = true)
- [x] Loss weights sum to ~1.0

### Attached Logs
- docker-ps-mac1.txt
- docker-ps-mac2.txt
- docker-ps-mac3.txt
- compose-ps-mac1.txt
- compose-ps-mac2.txt
- compose-ps-mac3.txt
- docker-stats-mac1.txt
- docker-stats-mac2.txt
- docker-stats-mac3.txt
- all-seeds.txt

### Issues Found
- None / List here...
```

## Rollback

If deployment fails or needs reset:

```bash
# Stop all workers on Mac 1
docker-compose -f deploy/docker/docker-compose.wave9-mac-1.yml down

# Stop all workers on Mac 2
docker-compose -f deploy/docker/docker-compose.wave9-mac-2.yml down

# Stop all workers on Mac 3
docker-compose -f deploy/docker/docker-compose.wave9-mac-3.yml down

# Clean volumes (preserves data/wave9)
docker volume prune

# Remove worker directories if needed
rm -rf data/wave9/worker-*
```

## Troubleshooting

### Containers not starting
```bash
# Check Docker logs
docker-compose -f deploy/docker/docker-compose.wave9-mac-1.yml logs

# Check disk space
df -h

# Check Docker resource limits
docker info | grep "Server Version"
```

### Duplicate seeds detected
```bash
# Reinitialize device
docker-compose -f deploy/docker/docker-compose.wave9-mac-1.yml down
rm data/wave9/worker-*
tri farm wave9 device-init --device-id 1 --workers-start 1 --workers-count 16
docker-compose -f deploy/docker/docker-compose.wave9-mac-1.yml up -d
```

### Network issues
```bash
# Verify Docker bridge network
docker network ls
docker network inspect bridge

# Test worker connectivity
docker exec wave9-worker-1 ping -c 3 8.8.8.8
```
