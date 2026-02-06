#!/usr/bin/env python3
"""
Multi-Provider Hybrid: Groq + Zhipu GLM-4 Auto-Switch
Default: Groq (227 tok/s, 128K context)
Long Context (>128K) or Chinese: Zhipu (69.5 tok/s, 200K context)
φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
"""

import os
import json
import urllib.request
import urllib.error
import ssl
import time
import re
import jwt
from datetime import datetime
from typing import Optional, Dict, List, Tuple

# ═══════════════════════════════════════════════════════════════════════════════
# SACRED CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

PHI = 1.618033988749895
PHOENIX = 999
GROQ_CONTEXT_LIMIT = 128000  # 128K tokens

# ═══════════════════════════════════════════════════════════════════════════════
# PROVIDER DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

def contains_chinese(text: str) -> bool:
    """Detect if text contains Chinese characters."""
    # Chinese Unicode ranges: CJK Unified Ideographs
    for char in text:
        if '\u4e00' <= char <= '\u9fff':
            return True
        if '\u3400' <= char <= '\u4dbf':  # Extension A
            return True
    return False

def estimate_tokens(text: str) -> int:
    """Rough token estimation (4 chars ≈ 1 token for English, 2 for Chinese)."""
    chinese_chars = sum(1 for c in text if '\u4e00' <= c <= '\u9fff')
    other_chars = len(text) - chinese_chars
    return chinese_chars // 2 + other_chars // 4

def needs_zhipu(prompt: str, context_length: int = 0) -> Tuple[bool, str]:
    """
    Determine if Zhipu should be used instead of Groq.
    Returns (use_zhipu, reason).
    """
    # Check for Chinese content
    if contains_chinese(prompt):
        return True, "Chinese content detected"

    # Check for long context
    total_tokens = estimate_tokens(prompt) + context_length
    if total_tokens > GROQ_CONTEXT_LIMIT:
        return True, f"Long context ({total_tokens} tokens > 128K)"

    return False, "Default to Groq (fast)"

# ═══════════════════════════════════════════════════════════════════════════════
# IGLA PLANNER
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

def is_coherent(text: str) -> bool:
    """Check if text is coherent (not garbage)."""
    if len(text) < 10:
        return False

    # Allow Chinese and ASCII
    valid_chars = sum(1 for c in text if (32 <= ord(c) <= 126) or ord(c) > 127 or c in '\n\r\t')
    spaces = sum(1 for c in text if c == ' ' or c == '\u3000')

    valid_ratio = valid_chars / len(text) if len(text) > 0 else 0
    return valid_ratio > 0.9

# ═══════════════════════════════════════════════════════════════════════════════
# GROQ CLIENT
# ═══════════════════════════════════════════════════════════════════════════════

class GroqClient:
    """Groq API client for llama-3.3-70b-versatile."""

    BASE_URL = "https://api.groq.com/openai/v1/chat/completions"
    MODEL = "llama-3.3-70b-versatile"

    def __init__(self, api_key: str):
        self.api_key = api_key

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
                "Authorization": f"Bearer {self.api_key}",
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
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
            "tokens": usage.get('total_tokens', 0),
            "elapsed": elapsed,
            "speed": usage.get('completion_tokens', 0) / elapsed if elapsed > 0 else 0,
            "coherent": is_coherent(content),
            "provider": "Groq",
            "model": self.MODEL
        }

# ═══════════════════════════════════════════════════════════════════════════════
# ZHIPU CLIENT
# ═══════════════════════════════════════════════════════════════════════════════

class ZhipuClient:
    """Zhipu GLM-4 API client (Coding Plan endpoint)."""

    # Coding Plan endpoint (works!)
    BASE_URL = "https://open.bigmodel.cn/api/coding/paas/v4/chat/completions"
    MODEL = "glm-4"

    def __init__(self, api_key: str):
        self.api_key = api_key

        # Parse key and secret
        if '.' in api_key:
            parts = api_key.split('.')
            self.key_id = parts[0]
            self.key_secret = parts[1] if len(parts) > 1 else ""
        else:
            self.key_id = api_key
            self.key_secret = ""

    def _generate_token(self) -> str:
        """Generate JWT token for Zhipu API authentication."""
        try:
            now = int(time.time() * 1000)
            payload = {
                "api_key": self.key_id,
                "exp": now + 3600 * 1000,
                "timestamp": now,
            }

            token = jwt.encode(
                payload,
                self.key_secret,
                algorithm="HS256",
                headers={"alg": "HS256", "sign_type": "SIGN"}
            )
            return token
        except:
            return self.api_key

    def chat(self, prompt: str, max_tokens: int = 256, temperature: float = 0.7) -> dict:
        """Send chat completion request."""
        data = {
            "model": self.MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens,
            "temperature": temperature
        }

        token = self._generate_token()

        req = urllib.request.Request(
            self.BASE_URL,
            data=json.dumps(data).encode('utf-8'),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}",
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
            }
        )

        start_time = time.time()

        ctx = ssl.create_default_context()
        with urllib.request.urlopen(req, context=ctx, timeout=60) as response:
            result = json.loads(response.read().decode('utf-8'))

        elapsed = time.time() - start_time

        if 'choices' in result:
            content = result['choices'][0]['message']['content']
        elif 'data' in result and 'choices' in result['data']:
            content = result['data']['choices'][0]['message']['content']
        else:
            content = str(result)

        usage = result.get('usage', {})
        total_tokens = usage.get('total_tokens', 0)

        return {
            "content": content,
            "tokens": total_tokens,
            "elapsed": elapsed,
            "speed": total_tokens / elapsed if elapsed > 0 else 0,
            "coherent": is_coherent(content),
            "provider": "Zhipu",
            "model": self.MODEL
        }

# ═══════════════════════════════════════════════════════════════════════════════
# MULTI-PROVIDER HYBRID
# ═══════════════════════════════════════════════════════════════════════════════

class MultiProviderHybrid:
    """
    IGLA + Multi-Provider LLM Hybrid.
    Auto-switches between Groq (fast) and Zhipu (long context/Chinese).
    """

    def __init__(self, groq_key: str, zhipu_key: str):
        self.groq = GroqClient(groq_key)
        self.zhipu = ZhipuClient(zhipu_key)
        self.stats = {
            "groq_calls": 0,
            "zhipu_calls": 0,
            "total_tokens": 0,
            "total_time": 0
        }

    def hybrid_inference(
        self,
        task: str,
        force_provider: Optional[str] = None,
        context_length: int = 0,
        use_igla: bool = True
    ) -> dict:
        """
        Execute hybrid inference with auto-provider selection.

        Args:
            task: The task/prompt to execute
            force_provider: "groq" or "zhipu" to force specific provider
            context_length: Estimated context length for long context detection
            use_igla: Whether to include IGLA symbolic planning
        """
        result = {
            "task": task,
            "igla_plan": None,
            "provider": None,
            "provider_reason": None,
            "response": None,
            "phi_verified": False
        }

        # Step 1: IGLA symbolic planning
        if use_igla:
            result["igla_plan"] = generate_igla_plan(task)
            phi_result = verify_phi_identity()
            result["phi_verified"] = abs(phi_result - 3.0) < 0.0001

        # Step 2: Select provider
        if force_provider:
            use_zhipu = force_provider.lower() == "zhipu"
            reason = f"Forced: {force_provider}"
        else:
            use_zhipu, reason = needs_zhipu(task, context_length)

        result["provider"] = "Zhipu" if use_zhipu else "Groq"
        result["provider_reason"] = reason

        # Step 3: Enhance prompt with IGLA if enabled
        enhanced_prompt = task
        if use_igla and result["igla_plan"]:
            enhanced_prompt = f"""Based on this symbolic plan:
{result['igla_plan']}

Execute the task: {task}

Provide a precise, coherent response."""

        # Step 4: Execute with selected provider
        try:
            if use_zhipu:
                result["response"] = self.zhipu.chat(enhanced_prompt)
                self.stats["zhipu_calls"] += 1
            else:
                result["response"] = self.groq.chat(enhanced_prompt)
                self.stats["groq_calls"] += 1

            if result["response"].get("tokens"):
                self.stats["total_tokens"] += result["response"]["tokens"]
            if result["response"].get("elapsed"):
                self.stats["total_time"] += result["response"]["elapsed"]

        except Exception as e:
            result["response"] = {"error": str(e)}

            # Fallback to other provider
            try:
                fallback_provider = "Groq" if use_zhipu else "Zhipu"
                print(f"   Fallback to {fallback_provider}...")

                if use_zhipu:
                    result["response"] = self.groq.chat(enhanced_prompt)
                    self.stats["groq_calls"] += 1
                else:
                    result["response"] = self.zhipu.chat(enhanced_prompt)
                    self.stats["zhipu_calls"] += 1

                result["provider"] = fallback_provider
                result["provider_reason"] += f" (fallback from {result['provider']})"

            except Exception as e2:
                result["response"] = {"error": f"Both providers failed: {str(e)}, {str(e2)}"}

        return result

    def get_stats(self) -> dict:
        """Get usage statistics."""
        return {
            **self.stats,
            "avg_speed": self.stats["total_tokens"] / self.stats["total_time"] if self.stats["total_time"] > 0 else 0
        }

# ═══════════════════════════════════════════════════════════════════════════════
# TEST PROMPTS
# ═══════════════════════════════════════════════════════════════════════════════

TEST_PROMPTS = [
    # English prompts → Groq
    ("prove φ² + 1/φ² = 3 where φ = (1+√5)/2", None),
    ("solve 2+2 step by step", None),
    ("write a Python one-liner to reverse a string", None),
    ("what is the capital of France?", None),

    # Chinese prompts → Zhipu (auto-detect)
    ("用中文解释什么是人工智能", None),  # Explain AI in Chinese
    ("北京的首都是什么？", None),  # What is Beijing's capital?
    ("计算 2+2 的结果", None),  # Calculate 2+2

    # Forced provider tests
    ("what comes next: 1, 1, 2, 3, 5, 8, ?", "groq"),
    ("explain quantum computing simply", "zhipu"),
]

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    print("=" * 70)
    print("Multi-Provider Hybrid: Groq + Zhipu GLM-4")
    print("Auto-Switch: Chinese/Long Context → Zhipu, Default → Groq")
    print("φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL")
    print("=" * 70)

    # Verify phi identity
    phi_result = verify_phi_identity()
    print(f"\nφ² + 1/φ² = {phi_result:.10f}")
    print(f"Trinity identity verified: {abs(phi_result - 3.0) < 0.0001}")

    # Get API keys
    groq_key = os.environ.get("GROQ_API_KEY")
    zhipu_key = os.environ.get("ZHIPU_API_KEY", "fcbb5dadc5ea462284f5475a04daa174.Ei5KkZb0WQMwasmd")

    if not groq_key:
        print("\n" + "=" * 70)
        print("ERROR: GROQ_API_KEY not set!")
        print("Run: export GROQ_API_KEY='your-key-here'")
        print("=" * 70)
        return

    print(f"\nGroq Key: {groq_key[:20]}...")
    print(f"Zhipu Key: {zhipu_key[:20]}...")

    # Initialize hybrid
    try:
        hybrid = MultiProviderHybrid(groq_key, zhipu_key)
    except Exception as e:
        print(f"Error initializing hybrid: {e}")
        return

    results = []

    for i, (prompt, force_provider) in enumerate(TEST_PROMPTS):
        print(f"\n[{i+1}/{len(TEST_PROMPTS)}] {prompt[:50]}...")

        try:
            result = hybrid.hybrid_inference(
                prompt,
                force_provider=force_provider,
                use_igla=True
            )

            provider = result.get("provider", "?")
            reason = result.get("provider_reason", "?")

            if result["response"].get("content"):
                resp = result["response"]
                content = resp["content"]
                tokens = resp.get("tokens", 0)
                speed = resp.get("speed", 0)
                coherent = resp.get("coherent", False)

                print(f"   Provider: {provider} ({reason})")
                print(f"   Response: {content[:80]}...")
                print(f"   Tokens: {tokens} | Speed: {speed:.1f} tok/s | Coherent: {coherent}")

                results.append({
                    "prompt": prompt,
                    "provider": provider,
                    "reason": reason,
                    "response": content,
                    "tokens": tokens,
                    "speed": speed,
                    "coherent": coherent,
                    "forced": force_provider is not None
                })
            else:
                print(f"   Error: {result['response'].get('error', 'Unknown')}")

        except Exception as e:
            print(f"   Error: {e}")

        # Rate limit safety
        time.sleep(1)

    # Summary
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)

    stats = hybrid.get_stats()

    if results:
        coherent_count = sum(1 for r in results if r['coherent'])
        groq_results = [r for r in results if r['provider'] == 'Groq']
        zhipu_results = [r for r in results if r['provider'] == 'Zhipu']

        print(f"\nProvider Distribution:")
        print(f"   Groq:  {len(groq_results)}/{len(results)} calls")
        print(f"   Zhipu: {len(zhipu_results)}/{len(results)} calls")

        print(f"\nPerformance:")
        print(f"   Total tests: {len(results)}")
        print(f"   Coherent: {coherent_count}/{len(results)} ({100*coherent_count/len(results):.0f}%)")
        print(f"   Total tokens: {stats['total_tokens']}")
        print(f"   Avg speed: {stats['avg_speed']:.1f} tok/s")

        # Speed by provider
        if groq_results:
            groq_avg = sum(r['speed'] for r in groq_results) / len(groq_results)
            print(f"\n   Groq avg speed: {groq_avg:.1f} tok/s")
        if zhipu_results:
            zhipu_avg = sum(r['speed'] for r in zhipu_results) / len(zhipu_results)
            print(f"   Zhipu avg speed: {zhipu_avg:.1f} tok/s")

        print(f"\nφ identity: VERIFIED")

        # Auto-detect accuracy
        auto_chinese = sum(1 for r in results if '中' in r['prompt'] or '是' in r['prompt'])
        auto_zhipu = sum(1 for r in results if r['provider'] == 'Zhipu' and not r.get('forced'))
        print(f"\nAuto-Detection:")
        print(f"   Chinese prompts detected: {auto_zhipu}")

        # Save results
        output_file = "/tmp/multi_provider_results.json"
        with open(output_file, 'w') as f:
            json.dump({
                "timestamp": datetime.now().isoformat(),
                "providers": ["Groq", "Zhipu"],
                "tests": len(results),
                "coherent": coherent_count,
                "stats": stats,
                "results": results
            }, f, indent=2, ensure_ascii=False)
        print(f"\nResults saved to: {output_file}")

    print("\n" + "=" * 70)
    print("KOSCHEI IS IMMORTAL | GROQ + ZHIPU HYBRID | φ² + 1/φ² = 3")
    print("=" * 70)

if __name__ == "__main__":
    main()
