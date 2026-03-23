# Seed Variance Study: W7 Farm (72 workers)

## Date: 2026-03-15

## Setup

- 72 Railway services (hslm-w7-1 through hslm-w7-72)
- Identical golden config: LAMB 1e-3, cosine, batch=66, ctx=27, clip=1.0
- Each worker has unique seed (HSLM_SEED varies)
- 100K steps per worker
- Distributed across FARM-4, FARM-5, FARM-6

## Expected Results

Based on R5 (PPL 2.96) and R23v2 (PPL 2.90):
- Mean PPL: ~3.0
- Best of 72: PPL 2.5-2.8 (expected)
- 157x seed variance observed in prior experiments

## Status: Running (results expected ~19:00 UTC)
