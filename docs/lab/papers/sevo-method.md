# SEVO — Sacred EVolutionary Objective Search

## Abstract

SEVO (Sacred EVolutionary Objective Search) is a population-based evolutionary training system that mutates not only scalar hyperparameters (learning rate, gradient clipping, warmup) but the **training objective itself** (NTP, JEPA, NCA, hybrid) across a population of workers. SEVO combines three mechanisms — ASHA successive halving, PBT hyperparameter mutation, and diversity-preserving objective injection — under sacred 3^k constraints derived from ternary resonance theory. Implemented in 6,700+ lines of pure Zig with zero dependencies, SEVO orchestrates 108 concurrent workers on commodity CPU infrastructure at $120/month total cost.

The name SEVO is clean — no conflicts exist in the ML/AI namespace.

---

## Formal Definition

**Population**: N workers {w_1, ..., w_N}, each with configuration:
```
config_i = (objective, lr, gc, warmup, context, schedule, batch)
```

Where:
- `objective` ∈ {NTP, NTP-81+, JEPA, hybrid} — the training loss function
- `lr` ∈ phi-grid: {base × φ^p | p ∈ {-3, -2, -1, 0, 1, 2, 3}}
- `gc` ∈ {0.5, 1.0, 2.0} — gradient clipping threshold
- `warmup` ∈ {243, 729, 2187} — sacred warmup steps (3^5, 3^6, 3^7)
- `context` ∈ {27, 81, 243} — sacred context lengths (3^3, 3^4, 3^5)
- `schedule` = cosine (ONLY — flat schedule banned)
- `batch` ∈ {27, 54, 66} — batch sizes

**Evolution loop**: At each SACRED_RUNG (3^k steps: 2187, 6561, 19683, 59049):
1. **Evaluate**: collect PPL from all workers at rung
2. **Halve** (ASHA): kill bottom fraction by PPL
3. **Mutate** (PBT): top workers → copy weights → mutate config (including objective)
4. **Inject**: compute quota deficit → inject new workers for underrepresented objectives
5. **Fresh detect**: objective/context changed → FRESH=1, scalar-only → FRESH=0

---

## Comparison Table

| Dimension | PBT (Jaderberg 2017) | ASHA (Li 2020) | NAS (Zoph 2017) | **SEVO** |
|-----------|---------------------|----------------|-----------------|----------|
| Mutates LR/batch | Yes | No | No | **Yes** |
| Mutates objective | No | No | No | **Yes** |
| Copies best weights | Yes | No | No | **Yes** |
| Successive halving | No | Yes | No | **Yes** |
| Diversity quotas | No | No | No | **Yes** |
| Sacred 3^k constraints | No | No | No | **Yes** |
| Fresh/resume detection | No | No | No | **Yes** |

**Key insight**: PBT searches a hyperparameter hypercube; SEVO searches a hyperparameter × objective product space with diversity enforcement.

---

## Algorithm Pseudocode

```
SEVO(population_size=108, rungs=[2187, 6561, 19683, 59049]):
    # Initialize population with quota-balanced objectives
    population = inject_batch(population_size, DEFAULT_QUOTAS)

    for rung in rungs:
        # Wait for all workers to reach rung
        wait_until(all workers at step >= rung)

        # Collect fitness (PPL) from all workers
        fitness = {w: w.ppl for w in population}

        # ASHA: successive halving — kill bottom fraction
        survivors = top_fraction(population, by=fitness)
        killed = population - survivors

        # PBT: mutate surviving workers
        for w in survivors:
            if w in top_k:
                w.config = mutateConfigSacred(w.config)
                # May change objective: NTP → JEPA, etc.

        # Injection: restore diversity quotas
        deficit = computeQuotaDeficit(survivors, DEFAULT_QUOTAS)
        new_workers = inject_batch(deficit, quotas)
        for w in new_workers:
            w.ppl = 0.0  # Sentinel: prevents immediate re-kill

        # Fresh detection
        for w in mutated_or_new:
            if w.obj_changed or w.ctx_changed:
                w.FRESH = 1  # Restart from scratch
            else:
                w.FRESH = 0  # Resume from checkpoint

        population = survivors + new_workers

    return best(population, by=ppl)
```

---

## Independent Claims

### Claim 1: Objective Mutation in PBT Population

A method for training neural networks comprising:
(a) maintaining a population of N training workers, each with a configuration including a training objective field;
(b) the training objective field accepting values from a set of distinct loss functions {NTP, JEPA, NCA, hybrid};
(c) during evolutionary mutation, modifying the training objective field of a worker configuration, thereby changing the loss function used for subsequent training;
(d) selecting objective values according to predefined diversity quotas to maintain population diversity across objective types.

### Claim 2: Diversity-Preserving Batch Injection with PPL=0.0 Sentinel

A method for maintaining population diversity in evolutionary training comprising:
(a) detecting underrepresented training objective types via quota deficit computation;
(b) injecting new workers with underrepresented objectives;
(c) assigning a sentinel fitness value (PPL=0.0) to newly injected workers;
(d) the sentinel value preventing freshly injected workers from being eliminated as worst-performing in the subsequent evolution cycle.

### Claim 3: Automatic FRESH/RESUME Detection

A method for determining training continuation strategy after evolutionary mutation comprising:
(a) comparing the mutated configuration with the parent configuration;
(b) if the training objective or context length has changed, setting FRESH=1 to trigger training restart from random initialization;
(c) if only scalar hyperparameters (learning rate, gradient clipping, warmup) have changed, setting FRESH=0 to enable training resumption from the parent checkpoint;
(d) thereby minimizing wasted compute by reusing checkpoints when mutation is compatible.

### Claim 4: Sacred 3^k Dimension Constraint on Search Space

A method for constraining the hyperparameter search space in evolutionary training comprising:
(a) restricting evaluation checkpoints (rungs) to steps that are powers of 3;
(b) constraining learning rates to a golden-ratio grid: base × φ^p for integer p;
(c) constraining warmup steps and context lengths to powers of 3;
(d) these constraints reducing the search space to values empirically correlated with resonant performance in ternary neural networks.

---

## Dependent Claims

### Claim 5: ASHA + PBT + Objective Mutation Combined

The method of Claims 1 and 4, further comprising:
(a) successive halving (ASHA) at sacred rungs to eliminate underperforming workers;
(b) population-based training (PBT) mutation of surviving workers' configurations;
(c) objective-type injection based on quota deficit computation;
wherein all three mechanisms operate in a single evolutionary loop at each sacred rung.

### Claim 6: Diversity Health Metric with Auto-Injection Threshold

The method of Claim 2, wherein:
(a) diversity health H is computed as the product of standard deviations across hyperparameter dimensions: H = ∏(σ_lr, σ_gc, σ_wu);
(b) when H falls below a predefined threshold, automatic injection is triggered;
(c) injection targets the objective type with the largest quota deficit.

### Claim 7: Generation Lineage Tracking with Mutation Yield

The method of Claim 1, further comprising:
(a) tracking generation number (G0, G1, G2, ...) for each worker through evolutionary mutations;
(b) computing mutation yield as the fraction of mutated workers that improve PPL over their parent;
(c) using mutation yield to adapt mutation aggressiveness in subsequent generations.

---

## Compute and Cost Profile

All SEVO experiments were conducted on a CPU-only cloud farm built from low-cost Railway accounts. Each account provides a small pool of commodity x86 CPU containers with no GPU or TPU accelerators. A total of six Railway accounts were used, each on a 20 USD/month plan, yielding an effective compute budget of ≈120 USD/month for the entire training farm.

The HSLM-1.95M ternary model (1.58 bits/parameter, ≈390 KB weights) was trained using SEVO across 104 concurrent workers scheduled over these CPU resources. Population-based evolution was orchestrated entirely through lightweight process scheduling and log-based control, without any dedicated cluster manager or GPU queueing system.

**Key point**: The CPU/Railway cost is an implementation advantage demonstrating SEVO's efficiency, NOT a patent claim. The algorithm itself is hardware-agnostic.

---

## What Is Patentable vs Not

### Patentable (Algorithm)

- **YES**: Objective mutation within PBT population — novel search dimension
- **YES**: Diversity-preserving injection with PPL=0.0 sentinel — prevents premature elimination
- **YES**: FRESH/RESUME detection — automatic restart vs resume decision
- **YES**: Sacred 3^k constraint system — empirically-grounded search space restriction
- **YES**: Combined ASHA + PBT + objective injection — three mechanisms in one loop
- **YES**: Selection metrics: diversity health H, mutation yield

### Not Patentable (Engineering Context)

- **NO**: Railway deployment details — infrastructure choice, not algorithm
- **NO**: 6 accounts at $20/month — commercial arrangement
- **NO**: CPU-farm specifics — hardware platform, not method
- **NO**: Zig implementation — language choice

The engineering context is valuable for the **paper narrative** (accessibility, reproducibility, cost-efficiency) and **go-to-market story**, but patent claims should focus on the algorithmic innovations.

---

## P5 Provisional Patent Recommendation

**Filing**: P5 — SEVO Sacred EVolutionary Objective Search
**Priority**: HIGH
**Estimated cost**: $1,500–2,000 (provisional patent application)
**Priority date**: Establishes priority on the entire SEVO method

### Claims to include in provisional:
1. Objective mutation in PBT (Claim 1)
2. Diversity injection with sentinel (Claim 2)
3. FRESH/RESUME detection (Claim 3)
4. Sacred 3^k constraints (Claim 4)
5. Combined ASHA+PBT+objective (Claim 5)

### Strength assessment:

| Factor | Assessment |
|--------|-----------|
| Novelty | No prior PBT system mutates training objective |
| Non-obviousness | Objective mutation requires FRESH detection — not trivial extension |
| Experimental evidence | 108 workers, 6 accounts, G0→G3 evolution, PPL=4.6 best |
| Prior art gap | PBT (US12314856B2) mutates scalars only; NAS searches architecture not objective |
| 101 risk | LOW — concrete algorithm with measurable metrics, not abstract idea |
| Reproducibility | Open source (MIT), fully specified in 6,700 LOC |

### Obvious Extensions (Picket Fence Additions)

- Closed-loop integration with Arena for quality-aware evolution: using ELO-based model evaluation scores as an additional fitness signal beyond perplexity
- Integration with autonomous code improvement (Ouroboros) for end-to-end self-improvement: code quality metrics feeding back into SEVO population decisions

### Timeline:
- File provisional: establishes priority date immediately
- Convert to utility patent within 12 months
- Consider PCT filing for international protection
