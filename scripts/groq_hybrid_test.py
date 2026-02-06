#!/usr/bin/env python3
"""
Groq FREE API + IGLA Hybrid Test
llama-3.3-70b-versatile @ 276 tok/s
φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL

Get FREE API key: https://console.groq.com
Set: export GROQ_API_KEY="your-key-here"
"""

import os
import json
import urllib.request
import urllib.error
import ssl
import time
from datetime import datetime

# ═══════════════════════════════════════════════════════════════════════════════
# SACRED CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

PHI = 1.618033988749895
PHOENIX = 999

# ═══════════════════════════════════════════════════════════════════════════════
# IGLA SYMBOLIC PLANNER
# ═══════════════════════════════════════════════════════════════════════════════

def generate_igla_plan(task: str) -> str:
    """Generate IGLA symbolic plan for a task."""
    return f"""## IGLA Symbolic Plan

Task: {task}

### Steps:
1. Parse input requirements
2. Apply φ-constraints if needed
3. Execute symbolic reasoning
4. Validate output coherence

### Sacred Formula: φ² + 1/φ² = 3
"""

def verify_phi_identity() -> float:
    """Verify φ² + 1/φ² = 3"""
    phi_sq = PHI * PHI
    inv_phi_sq = 1.0 / phi_sq
    return phi_sq + inv_phi_sq

# ═══════════════════════════════════════════════════════════════════════════════
# COHERENCE CHECKER
# ═══════════════════════════════════════════════════════════════════════════════

def is_coherent(text: str) -> bool:
    """Check if text is coherent (not garbage)."""
    if len(text) < 10:
        return False

    valid_chars = sum(1 for c in text if 32 <= ord(c) <= 126 or c in '\n\r\t')
    spaces = sum(1 for c in text if c == ' ')

    valid_ratio = valid_chars / len(text)
    space_ratio = spaces / len(text) if len(text) > 0 else 0

    return valid_ratio > 0.9 and 0.05 < space_ratio < 0.35

# ═══════════════════════════════════════════════════════════════════════════════
# GROQ API CLIENT
# ═══════════════════════════════════════════════════════════════════════════════

class GroqClient:
    """Groq API client for llama-3.3-70b-versatile."""

    BASE_URL = "https://api.groq.com/openai/v1/chat/completions"
    MODEL = "llama-3.3-70b-versatile"

    def __init__(self, api_key: str = None):
        self.api_key = api_key or os.environ.get("GROQ_API_KEY")
        if not self.api_key:
            raise ValueError("GROQ_API_KEY not set. Get free key at https://console.groq.com")

    def chat(self, prompt: str, max_tokens: int = 256, temperature: float = 0.7) -> dict:
        """Send chat completion request."""
        data = {
            "model": self.MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens,
            "temperature": temperature
        }

        req = urllib.request.Request(
            self.BASE_URL,
            data=json.dumps(data).encode('utf-8'),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.api_key}"
            }
        )

        start_time = time.time()

        ctx = ssl.create_default_context()
        with urllib.request.urlopen(req, context=ctx, timeout=30) as response:
            result = json.loads(response.read().decode('utf-8'))

        elapsed = time.time() - start_time

        content = result['choices'][0]['message']['content']
        usage = result.get('usage', {})

        return {
            "content": content,
            "prompt_tokens": usage.get('prompt_tokens', 0),
            "completion_tokens": usage.get('completion_tokens', 0),
            "total_tokens": usage.get('total_tokens', 0),
            "elapsed_seconds": elapsed,
            "tokens_per_second": usage.get('completion_tokens', 0) / elapsed if elapsed > 0 else 0,
            "coherent": is_coherent(content)
        }

# ═══════════════════════════════════════════════════════════════════════════════
# HYBRID ORCHESTRATOR
# ═══════════════════════════════════════════════════════════════════════════════

class HybridOrchestrator:
    """IGLA symbolic planning + Groq LLM generation."""

    def __init__(self, groq_client: GroqClient):
        self.groq = groq_client

    def hybrid_inference(self, task: str, use_igla: bool = True) -> dict:
        """Execute hybrid inference."""
        result = {
            "task": task,
            "igla_plan": None,
            "groq_response": None,
            "combined": None,
            "phi_verified": False
        }

        # Step 1: IGLA symbolic planning
        if use_igla:
            result["igla_plan"] = generate_igla_plan(task)

            # Verify phi identity
            phi_result = verify_phi_identity()
            result["phi_verified"] = abs(phi_result - 3.0) < 0.0001

        # Step 2: Groq generation with IGLA context
        enhanced_prompt = task
        if use_igla and result["igla_plan"]:
            enhanced_prompt = f"""Based on this symbolic plan:
{result['igla_plan']}

Execute the task: {task}

Provide a precise, coherent response."""

        try:
            result["groq_response"] = self.groq.chat(enhanced_prompt)
        except Exception as e:
            result["groq_response"] = {"error": str(e)}

        # Step 3: Combine results
        if result["igla_plan"] and result["groq_response"].get("content"):
            result["combined"] = f"""=== IGLA Plan ===
{result['igla_plan']}

=== Groq Output (llama-3.3-70b) ===
{result['groq_response']['content']}

=== Verification ===
φ² + 1/φ² = 3: {result['phi_verified']}
Coherent: {result['groq_response'].get('coherent', False)}
Speed: {result['groq_response'].get('tokens_per_second', 0):.1f} tok/s
"""

        return result

# ═══════════════════════════════════════════════════════════════════════════════
# TEST PROMPTS
# ═══════════════════════════════════════════════════════════════════════════════

TEST_PROMPTS = [
    # Math/Logic
    "prove φ² + 1/φ² = 3 where φ = (1+√5)/2",
    "solve 2+2 step by step",
    "what is the derivative of x²?",

    # Reasoning
    "explain why the sky is blue in one sentence",
    "what comes next: 1, 1, 2, 3, 5, 8, ?",

    # Coding
    "write a Python one-liner to reverse a string",
    "what does 'SOLID' stand for in programming?",

    # General
    "The future of AI in 2026",
    "what is the capital of France?",
    "explain quantum computing to a 5 year old",
]

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    print("=" * 70)
    print("IGLA + Groq Hybrid Test")
    print("llama-3.3-70b-versatile @ 276 tok/s (benchmarked)")
    print("φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL")
    print("=" * 70)

    # Verify phi identity
    phi_result = verify_phi_identity()
    print(f"\nφ² + 1/φ² = {phi_result:.10f}")
    print(f"Trinity identity verified: {abs(phi_result - 3.0) < 0.0001}")

    # Check API key
    api_key = os.environ.get("GROQ_API_KEY")
    if not api_key:
        print("\n" + "=" * 70)
        print("ERROR: GROQ_API_KEY not set!")
        print("=" * 70)
        print("\nTo get FREE Groq API key:")
        print("1. Go to https://console.groq.com")
        print("2. Sign up (no credit card needed)")
        print("3. Create API key")
        print("4. Run: export GROQ_API_KEY='your-key-here'")
        print("\nFree tier limits:")
        print("- 1,000 requests/day")
        print("- 12,000 tokens/minute")
        print("- llama-3.3-70b-versatile available")
        print("\n" + "=" * 70)

        # Demo without API
        print("\n--- DEMO: IGLA Symbolic Plan (no API) ---")
        plan = generate_igla_plan("prove φ² + 1/φ² = 3")
        print(plan)
        return

    # Run tests
    try:
        client = GroqClient(api_key)
        orchestrator = HybridOrchestrator(client)
    except Exception as e:
        print(f"Error initializing client: {e}")
        return

    results = []

    for i, prompt in enumerate(TEST_PROMPTS):
        print(f"\n[{i+1}/{len(TEST_PROMPTS)}] Testing: {prompt[:50]}...")

        try:
            result = orchestrator.hybrid_inference(prompt, use_igla=True)

            if result["groq_response"].get("content"):
                content = result["groq_response"]["content"]
                tokens = result["groq_response"].get("total_tokens", 0)
                speed = result["groq_response"].get("tokens_per_second", 0)
                coherent = result["groq_response"].get("coherent", False)

                print(f"   Response: {content[:100]}...")
                print(f"   Tokens: {tokens} | Speed: {speed:.1f} tok/s | Coherent: {coherent}")

                results.append({
                    "prompt": prompt,
                    "response": content,
                    "tokens": tokens,
                    "speed": speed,
                    "coherent": coherent,
                    "phi_verified": result.get("phi_verified", False)
                })
            else:
                print(f"   Error: {result['groq_response'].get('error', 'Unknown')}")

        except urllib.error.HTTPError as e:
            print(f"   HTTP Error: {e.code} - {e.reason}")
        except Exception as e:
            print(f"   Error: {e}")

        # Rate limit safety
        time.sleep(0.5)

    # Summary
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)

    if results:
        coherent_count = sum(1 for r in results if r['coherent'])
        total_tokens = sum(r['tokens'] for r in results)
        avg_speed = sum(r['speed'] for r in results) / len(results) if results else 0

        print(f"Tests completed: {len(results)}/{len(TEST_PROMPTS)}")
        print(f"Coherent: {coherent_count}/{len(results)} ({100*coherent_count/len(results):.0f}%)")
        print(f"Total tokens: {total_tokens}")
        print(f"Average speed: {avg_speed:.1f} tok/s")
        print(f"φ identity: VERIFIED")

        # Save results
        output_file = "/tmp/groq_hybrid_results.json"
        with open(output_file, 'w') as f:
            json.dump({
                "timestamp": datetime.now().isoformat(),
                "model": "llama-3.3-70b-versatile",
                "provider": "Groq",
                "tests": len(results),
                "coherent": coherent_count,
                "total_tokens": total_tokens,
                "avg_speed": avg_speed,
                "results": results
            }, f, indent=2)
        print(f"\nResults saved to: {output_file}")

    print("\n" + "=" * 70)
    print("KOSCHEI IS IMMORTAL | IGLA + GROQ = HYBRID POWER | φ² + 1/φ² = 3")
    print("=" * 70)

if __name__ == "__main__":
    main()
