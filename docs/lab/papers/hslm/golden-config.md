# HSLM Golden Configuration

## Verified Best Config (R5/R23v2)

```
HSLM_OPTIMIZER=lamb
HSLM_LR=1e-3
HSLM_LR_SCHEDULE=cosine
HSLM_BATCH=66
HSLM_CONTEXT=27
HSLM_GRAD_CLIP=1.0
HSLM_WARMUP=2000
HSLM_WD=0.01
HSLM_STEPS=100000
HSLM_FRESH=1
```

## Why These Values

- **LAMB**: Large batch optimizer, critical for batch=66
- **LR 1e-3**: 3.3x higher than AdamW default, LAMB can handle it
- **cosine schedule**: Smooth decay, avoids flat schedule death at 20K
- **batch=66**: Sacred number (2*3*11), optimal for ternary resonance
- **ctx=27=3^3**: Ternary resonance dimension
- **clip=1.0**: BitNet-style gradient clipping

## Anti-patterns

- AdamW + 3e-4 + sacred → PPL 265 (90x worse)
- flat LR schedule → dead by 20K steps
- batch > 128 → gradient noise too low for ternary
