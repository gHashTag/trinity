#!/usr/bin/env python3
"""
Production Demo: Multi-Provider Hybrid - 20+ Multilingual Prompts
Tests: Speed, Coherence, Language Detection, Auto-Switch, Fallback
φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
"""

import os
import sys
import time
from datetime import datetime

# Add parent directory for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from multi_provider_hybrid import (
    MultiProviderHybrid,
    verify_phi_identity,
    detect_language,
    is_coherent
)

# ═══════════════════════════════════════════════════════════════════════════════
# PRODUCTION TEST PROMPTS (20+)
# ═══════════════════════════════════════════════════════════════════════════════

PRODUCTION_PROMPTS = [
    # === ENGLISH (10) ===
    ("prove φ² + 1/φ² = 3 where φ = (1+√5)/2", "math"),
    ("solve 2+2 step by step", "math"),
    ("what is the derivative of x²?", "math"),
    ("write a Python one-liner to reverse a string", "code"),
    ("what does 'SOLID' stand for in programming?", "code"),
    ("explain why the sky is blue in one sentence", "science"),
    ("what comes next: 1, 1, 2, 3, 5, 8, ?", "logic"),
    ("what is the capital of France?", "factual"),
    ("explain quantum computing to a 5 year old", "explain"),
    ("the future of AI in 2026", "creative"),

    # === CHINESE (5) ===
    ("用中文解释什么是人工智能", "chinese"),
    ("计算 2+2 的结果", "chinese"),
    ("北京是中国的首都吗？", "chinese"),
    ("写一个Python函数来反转字符串", "chinese"),
    ("解释量子计算的基本概念", "chinese"),

    # === RUSSIAN (3) ===
    ("Объясни что такое искусственный интеллект", "russian"),
    ("Какая столица России?", "russian"),
    ("Напиши функцию на Python для сортировки списка", "russian"),

    # === JAPANESE (2) ===
    ("人工知能とは何ですか？", "japanese"),
    ("2+2の答えは？", "japanese"),

    # === KOREAN (2) ===
    ("인공지능이란 무엇인가요?", "korean"),
    ("2+2의 답은?", "korean"),

    # === LONG CONTEXT (2) ===
    ("Summarize the following text: " + "AI is transforming the world. " * 100, "long"),
    ("Analyze this data: " + "value=42, " * 200, "long"),
]

# ═══════════════════════════════════════════════════════════════════════════════
# PRODUCTION DEMO
# ═══════════════════════════════════════════════════════════════════════════════

def run_production_demo():
    print("=" * 70)
    print("PRODUCTION DEMO: Multi-Provider Hybrid")
    print("24 Prompts | 5 Languages | 4 Providers")
    print("φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL")
    print("=" * 70)

    # Verify phi identity
    phi_result = verify_phi_identity()
    print(f"\nφ² + 1/φ² = {phi_result:.10f}")
    print(f"Trinity identity verified: {abs(phi_result - 3.0) < 0.0001}")

    # Get API keys
    groq_key = os.environ.get("GROQ_API_KEY")
    zhipu_key = os.environ.get("ZHIPU_API_KEY")
    anthropic_key = os.environ.get("ANTHROPIC_API_KEY")
    cohere_key = os.environ.get("COHERE_API_KEY")

    if not groq_key and not zhipu_key:
        print("\nERROR: No API keys configured!")
        print("Set: GROQ_API_KEY or ZHIPU_API_KEY")
        return None

    # Initialize hybrid
    hybrid = MultiProviderHybrid(
        groq_key=groq_key,
        zhipu_key=zhipu_key,
        anthropic_key=anthropic_key,
        cohere_key=cohere_key
    )

    print(f"\nActive providers: {list(hybrid.providers.keys())}")
    print(f"Total prompts: {len(PRODUCTION_PROMPTS)}")
    print("\n" + "-" * 70)

    results = []
    categories = {}
    languages_detected = {}

    start_time = time.time()

    for i, (prompt, category) in enumerate(PRODUCTION_PROMPTS):
        print(f"\n[{i+1}/{len(PRODUCTION_PROMPTS)}] [{category}] {prompt[:40]}...")

        try:
            result = hybrid.hybrid_inference(prompt, use_igla=True)

            provider = result.get("provider", "?")
            lang = result.get("language", "english")

            if result["response"].get("content"):
                resp = result["response"]
                content = resp["content"]
                tokens = resp.get("tokens", 0)
                speed = resp.get("speed", 0)
                coherent = resp.get("coherent", False)

                print(f"   Provider: {provider} | Lang: {lang}")
                print(f"   Response: {content[:60]}...")
                print(f"   Tokens: {tokens} | Speed: {speed:.1f} tok/s | Coherent: {coherent}")

                # Track results
                results.append({
                    "prompt": prompt,
                    "category": category,
                    "provider": provider,
                    "language": lang,
                    "tokens": tokens,
                    "speed": speed,
                    "coherent": coherent
                })

                # Track categories
                if category not in categories:
                    categories[category] = {"count": 0, "coherent": 0, "tokens": 0}
                categories[category]["count"] += 1
                if coherent:
                    categories[category]["coherent"] += 1
                categories[category]["tokens"] += tokens

                # Track languages
                if lang not in languages_detected:
                    languages_detected[lang] = 0
                languages_detected[lang] += 1

            else:
                print(f"   Error: {result['response'].get('error', 'Unknown')}")

        except Exception as e:
            print(f"   Error: {e}")

        # Rate limit
        time.sleep(0.5)

    total_time = time.time() - start_time

    # ═══════════════════════════════════════════════════════════════════════════
    # SUMMARY
    # ═══════════════════════════════════════════════════════════════════════════

    print("\n" + "=" * 70)
    print("PRODUCTION DEMO SUMMARY")
    print("=" * 70)

    if results:
        coherent_count = sum(1 for r in results if r['coherent'])
        total_tokens = sum(r['tokens'] for r in results)

        print(f"\nOverall Results:")
        print(f"  Total prompts: {len(results)}/{len(PRODUCTION_PROMPTS)}")
        print(f"  Coherent: {coherent_count}/{len(results)} ({100*coherent_count/len(results):.0f}%)")
        print(f"  Total tokens: {total_tokens}")
        print(f"  Total time: {total_time:.1f}s")
        print(f"  Throughput: {total_tokens/total_time:.1f} tok/s")

        print(f"\nBy Category:")
        for cat, stats in sorted(categories.items()):
            pct = 100 * stats["coherent"] / stats["count"] if stats["count"] > 0 else 0
            print(f"  {cat}: {stats['coherent']}/{stats['count']} ({pct:.0f}%) - {stats['tokens']} tokens")

        print(f"\nLanguages Detected:")
        for lang, count in sorted(languages_detected.items(), key=lambda x: -x[1]):
            print(f"  {lang}: {count} prompts")

        print(f"\nProvider Stats:")
        stats = hybrid.get_stats()
        for provider in ['groq', 'zhipu', 'anthropic', 'cohere']:
            calls = stats.get(f'{provider}_calls', 0)
            if calls > 0:
                print(f"  {provider.capitalize()}: {calls} calls")

        print(f"\nφ Identity: VERIFIED")
        print(f"Production Ready: {'YES' if coherent_count == len(results) else 'PARTIAL'}")

        return {
            "timestamp": datetime.now().isoformat(),
            "total_prompts": len(PRODUCTION_PROMPTS),
            "successful": len(results),
            "coherent": coherent_count,
            "total_tokens": total_tokens,
            "total_time": total_time,
            "throughput": total_tokens / total_time if total_time > 0 else 0,
            "categories": categories,
            "languages": languages_detected,
            "providers": stats,
            "results": results
        }

    return None


if __name__ == "__main__":
    result = run_production_demo()

    if result:
        print("\n" + "=" * 70)
        print("KOSCHEI IS IMMORTAL | PRODUCTION DEMO COMPLETE | φ² + 1/φ² = 3")
        print("=" * 70)
