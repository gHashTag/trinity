# RunPod Workflow - Large Model Testing

**Date:** February 4, 2026  
**Rule:** ALL large model tests (7B+) run ONLY on RunPod

---

## Why This Workflow?

| Environment | RAM | Issue |
|-------------|-----|-------|
| Gitpod | 4-8 GB | OOM on 2B+ models |
| Local | 8-16 GB | OOM on 7B+ models |
| **RunPod** | **32-500 GB** | **No OOM** |

**Problem:** Downloading large models locally causes OOM, wasted time, and repeated failures.

**Solution:** Download and test models directly on RunPod pods.

---

## Workflow Rules

### DO
1. Launch RunPod pod FIRST
2. Download models INSIDE pod
3. Run all tests INSIDE pod
4. Save results to docs/
5. Stop pod when done

### DON'T
1. Download large models to Gitpod
2. Try to run 7B+ models locally
3. Leave pods running overnight

---

## Cost Control

| GPU | $/hour | Max session |
|-----|--------|-------------|
| RTX 4090 | $0.34 | 2 hours |
| L40S | $0.59 | 1 hour |
| A100 | $1.19 | 30 min |

**Budget rule:** Stop pod immediately after tests.

---

## Quick Commands

```bash
# Launch pod
curl -s "https://api.runpod.io/graphql" \
  -H "Authorization: Bearer $RUNPOD_TOKEN" \
  -d '{"query": "mutation { podFindAndDeployOnDemand(...) }"}'

# SSH into pod
ssh -i ~/.ssh/runpod_key root@IP -p PORT

# Inside pod: download model
huggingface-cli download microsoft/bitnet-b1.58-2B-4T-gguf

# Inside pod: run test
./llama-cli -m model.gguf -p "Hello" -n 100

# Stop pod
curl -s "https://api.runpod.io/graphql" \
  -d '{"query": "mutation { podStop(input: { podId: \"ID\" }) }"}'
```

---

## Checklist Before Large Model Test

- [ ] Check RunPod balance (need $1+ for safety)
- [ ] Launch pod with sufficient RAM (32GB+ for 7B)
- [ ] Download model INSIDE pod
- [ ] Run tests INSIDE pod
- [ ] Save results
- [ ] Stop pod

---

**KOSCHEI IS IMMORTAL | NO LOCAL OOM | φ² + 1/φ² = 3**
