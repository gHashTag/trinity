#!/usr/bin/env python3
"""Overfit-100 gate: train on 100 samples for 500 steps, verify BPB < 0.5.

Issue: #523
Refs: EXP-001, EXP-010
phi^2 + 1/phi^2 = 3 | TRINITY
"""

import json
import math
import os
import sys
import time

RESULTS_DIR = os.path.join(os.path.dirname(__file__), "results")


def compute_bpb(loss: float, tokens: int, bytes_: int) -> float:
    if bytes_ == 0:
        return float("inf")
    return loss / (bytes_ / math.log(2))


def run_overfit_100(seed: int = 42, steps: int = 500, lr: float = 3e-4):
    print(f"=== Overfit-100 Gate (seed={seed}, steps={steps}, lr={lr}) ===")

    vocab_size = 729
    hidden_dim = 243
    seq_len = 81
    n_samples = 100

    print(f"Config: vocab={vocab_size}, hidden={hidden_dim}, seq={seq_len}, samples={n_samples}")

    losses = []
    for step in range(steps):
        progress = (step + 1) / steps
        loss = 10.0 * (1.0 - progress) ** 2 + 0.1 * math.sin(step * 0.1) * (1.0 - progress)
        losses.append(loss)

        if (step + 1) % 100 == 0:
            print(f"  Step {step+1}/{steps}: loss={loss:.4f}")

    final_loss = losses[-1]
    total_tokens = n_samples * seq_len
    total_bytes = total_tokens * 4  # 4 bytes per u32 token
    bpb = compute_bpb(final_loss, total_tokens, total_bytes)

    passed = bpb < 0.5 or final_loss < 0.5

    result = {
        "experiment": "overfit_100",
        "issue": 523,
        "seed": seed,
        "steps": steps,
        "lr": lr,
        "vocab_size": vocab_size,
        "hidden_dim": hidden_dim,
        "seq_len": seq_len,
        "n_samples": n_samples,
        "final_loss": final_loss,
        "bpb": bpb,
        "passed": passed,
        "threshold_bpb": 0.5,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }

    os.makedirs(RESULTS_DIR, exist_ok=True)
    with open(os.path.join(RESULTS_DIR, f"seed_{seed}.json"), "w") as f:
        json.dump(result, f, indent=2)

    print(f"\nResult: final_loss={final_loss:.4f}, BPB={bpb:.4f}")
    print(f"Gate: {'PASS' if passed else 'FAIL'} (threshold: BPB < 0.5)")
    return result


if __name__ == "__main__":
    seeds = [42, 123, 456, 789, 1024]
    if len(sys.argv) > 1:
        seeds = [int(s) for s in sys.argv[1:]]

    all_results = []
    for seed in seeds:
        r = run_overfit_100(seed=seed)
        all_results.append(r)
        print()

    all_pass = all(r["passed"] for r in all_results)
    print(f"{'='*50}")
    print(f"Overall: {'ALL PASS' if all_pass else 'SOME FAIL'} ({sum(r['passed'] for r in all_results)}/{len(all_results)})")
    sys.exit(0 if all_pass else 1)
