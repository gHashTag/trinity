#!/usr/bin/env python3
"""
Demo: Trinity VSA native binding (SIMD-accelerated via Zig backend)

Run from project root:
    python libs/python/trinity_vsa/examples/demo_native.py
"""

import sys
import time
from pathlib import Path

# Add package to path
pkg_root = Path(__file__).parents[1] / "src"
sys.path.insert(0, str(pkg_root))

from trinity_vsa.native import NativeVSA, Vector


def main():
    # ── Initialize ───────────────────────────────────────────────────
    print("=" * 60)
    print("  Trinity VSA — Native Python Binding Demo")
    print("=" * 60)

    vsa = NativeVSA()
    print(f"\nLibrary version: {vsa.version()}")
    print(f"Max dimension:   {vsa.max_dim()} trits")

    # ── 1. Basic vector operations ───────────────────────────────────
    print("\n--- 1. Basic Vector Operations ---")

    apple = Vector(vsa, random=(10000, 42))
    red = Vector(vsa, random=(10000, 123))
    fruit = Vector(vsa, random=(10000, 456))

    print(f"  apple: {apple}")
    print(f"  red:   {red}")
    print(f"  fruit: {fruit}")

    # Bind: create association
    red_apple = apple.bind(red)
    print(f"\n  bind(apple, red) → {red_apple}")
    print(f"    sim(red_apple, apple) = {red_apple.similarity(apple):.4f}")
    print(f"    sim(red_apple, red)   = {red_apple.similarity(red):.4f}")
    print(f"    sim(red_apple, fruit) = {red_apple.similarity(fruit):.4f} (unrelated)")

    # Unbind: recover original
    recovered = red_apple.unbind(red)
    print(f"\n  unbind(red_apple, red):")
    print(f"    sim(recovered, apple) = {recovered.similarity(apple):.4f} (should be high)")

    # Bundle: superposition
    bundle = apple.bundle(fruit)
    print(f"\n  bundle(apple, fruit):")
    print(f"    sim(bundle, apple) = {bundle.similarity(apple):.4f}")
    print(f"    sim(bundle, fruit) = {bundle.similarity(fruit):.4f}")
    print(f"    sim(bundle, red)   = {bundle.similarity(red):.4f} (unrelated)")

    # ── 2. Text similarity ───────────────────────────────────────────
    print("\n--- 2. Text Similarity (word-level) ---")

    texts = [
        "machine learning",
        "deep learning",
        "database optimization",
        "quantum computing",
    ]

    vectors = [Vector(vsa, text_words=t) for t in texts]

    print(f"  {'':30s} ", end="")
    for t in texts:
        print(f" {t[:12]:>12s}", end="")
    print()

    for i, (ti, vi) in enumerate(zip(texts, vectors)):
        print(f"  {ti:30s} ", end="")
        for j, vj in enumerate(vectors):
            sim = vi.similarity(vj)
            print(f" {sim:12.4f}", end="")
        print()

    # ── 3. Semantic search ───────────────────────────────────────────
    print("\n--- 3. Semantic Search ---")

    corpus = [
        "machine learning algorithms for classification",
        "deep neural networks and backpropagation",
        "natural language processing with transformers",
        "computer vision and image recognition",
        "reinforcement learning for game playing",
        "database query optimization techniques",
        "SQL joins and indexing strategies",
        "distributed systems and consensus protocols",
        "web server configuration and load balancing",
        "Zig systems programming language",
        "Rust memory safety and ownership model",
        "Python scripting for data analysis",
        "ternary computing and balanced ternary",
        "vector symbolic architecture hyperdimensional computing",
        "SIMD parallel processing acceleration",
        "GPU computing with CUDA kernels",
    ]

    queries = [
        "machine learning",
        "database query",
        "programming language",
        "ternary computing",
    ]

    for query in queries:
        t0 = time.perf_counter()
        results = vsa.search(query, corpus, top_n=5)
        elapsed = (time.perf_counter() - t0) * 1000

        print(f'\n  Query: "{query}" ({elapsed:.1f} ms)')
        for sim, idx, text in results:
            print(f"    [{sim:.4f}] {text}")

    # ── 4. Associative memory ────────────────────────────────────────
    print("\n--- 4. Associative Memory ---")

    france = Vector(vsa, text_words="france")
    paris = Vector(vsa, text_words="paris")
    germany = Vector(vsa, text_words="germany")
    berlin = Vector(vsa, text_words="berlin")

    # country * capital pairs
    fr_pair = france.bind(paris)
    de_pair = germany.bind(berlin)

    # Query: what is the capital of France?
    query_result = fr_pair.unbind(france)
    print(f"  unbind(france*paris, france) ~ paris?  sim = {query_result.similarity(paris):.4f}")
    print(f"  unbind(france*paris, france) ~ berlin? sim = {query_result.similarity(berlin):.4f}")

    # ── 5. Performance benchmark ─────────────────────────────────────
    print("\n--- 5. Performance ---")

    n_ops = 1000
    a_handle = vsa.random(10000, 1)
    b_handle = vsa.random(10000, 2)

    t0 = time.perf_counter()
    for _ in range(n_ops):
        vsa.similarity(a_handle, b_handle)
    elapsed = (time.perf_counter() - t0) * 1000

    print(f"  {n_ops} cosine_similarity calls: {elapsed:.1f} ms ({elapsed/n_ops:.3f} ms/op)")

    t0 = time.perf_counter()
    for _ in range(n_ops):
        h = vsa.bind(a_handle, b_handle)
        vsa.free(h)
    elapsed = (time.perf_counter() - t0) * 1000

    print(f"  {n_ops} bind + free calls:       {elapsed:.1f} ms ({elapsed/n_ops:.3f} ms/op)")

    t0 = time.perf_counter()
    for _ in range(100):
        h = vsa.encode_text_words("machine learning algorithms for classification")
        vsa.free(h)
    elapsed = (time.perf_counter() - t0) * 1000

    print(f"  100 encode_text_words calls:   {elapsed:.1f} ms ({elapsed/100:.3f} ms/op)")

    vsa.free(a_handle)
    vsa.free(b_handle)

    # ── Done ─────────────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("  Demo complete.")
    print("=" * 60)


if __name__ == "__main__":
    main()
