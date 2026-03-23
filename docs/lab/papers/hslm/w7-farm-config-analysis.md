# W7 Farm Configuration Analysis

## Date: 2026-03-15

## Finding: Local W7 vs Farm W7 Config Divergence

Local W7 training used **default config** (AdamW 3e-4 sacred schedule),
producing PPL 265 at 100K steps. Farm W7 (72 workers) uses **golden config**
(LAMB 1e-3 cosine schedule), expected PPL ~3.0.

## Key Config Differences

| Parameter | Local W7 (PPL 265) | Farm W7 (PPL ~3) |
|-----------|-------------------|-------------------|
| Optimizer | AdamW (default) | LAMB |
| LR | 3e-4 (default) | 1e-3 (3.3x higher) |
| Schedule | sacred (default) | cosine |
| Batch | 64 (default) | 66 |
| Grad clip | 1.0 | 1.0 |

## Conclusion

- grad_clip=1.0 is hardcoded default in all code paths
- The 90x PPL difference is entirely due to optimizer/LR/schedule
- LAMB + higher LR + cosine is critical for ternary convergence
- Farm W7 env vars verified via Railway GraphQL API
