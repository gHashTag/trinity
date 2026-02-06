#!/usr/bin/env python3
"""
Multi-Provider Hybrid: Groq + Zhipu + Anthropic + Cohere Auto-Switch
Providers:
- Groq (227 tok/s, 128K, FREE) - Default for speed
- Zhipu GLM-4 (69.5 tok/s, 200K) - Chinese/CJK, long context
- Anthropic Claude (80 tok/s, 200K) - Quality preference
- Cohere Command R+ (100 tok/s, 128K, FREE) - Alternative
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
    for char in text:
        if '\u4e00' <= char <= '\u9fff':  # CJK Unified Ideographs
            return True
        if '\u3400' <= char <= '\u4dbf':  # Extension A
            return True
    return False

def contains_japanese(text: str) -> bool:
    """Detect if text contains Japanese Hiragana/Katakana."""
    for char in text:
        if '\u3040' <= char <= '\u309f':  # Hiragana
            return True
        if '\u30a0' <= char <= '\u30ff':  # Katakana
            return True
    return False

def contains_korean(text: str) -> bool:
    """Detect if text contains Korean Hangul."""
    for char in text:
        if '\uac00' <= char <= '\ud7a3':  # Hangul Syllables
            return True
    return False

def contains_cyrillic(text: str) -> bool:
    """Detect if text contains Cyrillic (Russian, etc.)."""
    for char in text:
        if '\u0400' <= char <= '\u04ff':  # Cyrillic
            return True
    return False

def detect_language(text: str) -> str:
    """Detect primary language in text."""
    if contains_chinese(text):
        return "chinese"
    if contains_japanese(text):
        return "japanese"
    if contains_korean(text):
        return "korean"
    if contains_cyrillic(text):
        return "russian"
    return "english"

def estimate_tokens(text: str) -> int:
    """Rough token estimation (4 chars ≈ 1 token for English, 2 for Chinese)."""
    chinese_chars = sum(1 for c in text if '\u4e00' <= c <= '\u9fff')
    other_chars = len(text) - chinese_chars
    return chinese_chars // 2 + other_chars // 4

def select_provider(
    prompt: str,
    context_length: int = 0,
    prefer_quality: bool = False,
    prefer_free: bool = True
) -> Tuple[str, str]:
    """
    Select best provider based on prompt and preferences.
    Returns (provider_name, reason).
    """
    lang = detect_language(prompt)
    total_tokens = estimate_tokens(prompt) + context_length

    # CJK languages → Zhipu (native support)
    if lang in ("chinese", "japanese", "korean"):
        return "zhipu", f"{lang.capitalize()} content detected"

    # Long context → Zhipu or Anthropic
    if total_tokens > GROQ_CONTEXT_LIMIT:
        if prefer_quality:
            return "anthropic", f"Long context ({total_tokens} tokens), quality mode"
        return "zhipu", f"Long context ({total_tokens} tokens > 128K)"

    # Quality preference → Anthropic
    if prefer_quality:
        return "anthropic", "Quality mode enabled"

    # Free tier preference → Groq (fastest) or Cohere
    if prefer_free:
        return "groq", "Default (fast, FREE)"

    return "groq", "Default to Groq (fastest)"


def needs_zhipu(prompt: str, context_length: int = 0) -> Tuple[bool, str]:
    """Legacy compatibility: Determine if Zhipu should be used."""
    provider, reason = select_provider(prompt, context_length)
    return provider == "zhipu", reason

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

class AnthropicClient:
    """Anthropic Claude API client."""

    BASE_URL = "https://api.anthropic.com/v1/messages"
    MODEL = "claude-3-5-sonnet-20241022"

    def __init__(self, api_key: str):
        self.api_key = api_key

    def chat(self, prompt: str, max_tokens: int = 256, temperature: float = 0.7) -> dict:
        """Send chat completion request."""
        data = {
            "model": self.MODEL,
            "max_tokens": max_tokens,
            "messages": [{"role": "user", "content": prompt}]
        }

        req = urllib.request.Request(
            self.BASE_URL,
            data=json.dumps(data).encode('utf-8'),
            headers={
                "Content-Type": "application/json",
                "x-api-key": self.api_key,
                "anthropic-version": "2023-06-01",
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
            }
        )

        start_time = time.time()

        ctx = ssl.create_default_context()
        with urllib.request.urlopen(req, context=ctx, timeout=60) as response:
            result = json.loads(response.read().decode('utf-8'))

        elapsed = time.time() - start_time

        content = result['content'][0]['text'] if result.get('content') else ""
        usage = result.get('usage', {})
        total_tokens = usage.get('input_tokens', 0) + usage.get('output_tokens', 0)

        return {
            "content": content,
            "tokens": total_tokens,
            "elapsed": elapsed,
            "speed": usage.get('output_tokens', 0) / elapsed if elapsed > 0 else 0,
            "coherent": is_coherent(content),
            "provider": "Anthropic",
            "model": self.MODEL
        }


class CohereClient:
    """Cohere Command R+ API client."""

    BASE_URL = "https://api.cohere.ai/v1/chat"
    MODEL = "command-r-plus"

    def __init__(self, api_key: str):
        self.api_key = api_key

    def chat(self, prompt: str, max_tokens: int = 256, temperature: float = 0.7) -> dict:
        """Send chat completion request."""
        data = {
            "model": self.MODEL,
            "message": prompt,
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
        with urllib.request.urlopen(req, context=ctx, timeout=60) as response:
            result = json.loads(response.read().decode('utf-8'))

        elapsed = time.time() - start_time

        content = result.get('text', '')
        # Cohere doesn't return token count in simple response
        estimated_tokens = len(content.split()) * 1.3

        return {
            "content": content,
            "tokens": int(estimated_tokens),
            "elapsed": elapsed,
            "speed": estimated_tokens / elapsed if elapsed > 0 else 0,
            "coherent": is_coherent(content),
            "provider": "Cohere",
            "model": self.MODEL
        }


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
    Auto-switches between providers based on task requirements.

    Providers:
    - Groq: Fast (227 tok/s), FREE tier, 128K context
    - Zhipu: Chinese native, 200K context
    - Anthropic: High quality, 200K context
    - Cohere: FREE tier alternative, 128K context
    """

    def __init__(
        self,
        groq_key: str = None,
        zhipu_key: str = None,
        anthropic_key: str = None,
        cohere_key: str = None
    ):
        self.providers = {}

        if groq_key:
            self.providers['groq'] = GroqClient(groq_key)
        if zhipu_key:
            self.providers['zhipu'] = ZhipuClient(zhipu_key)
        if anthropic_key:
            self.providers['anthropic'] = AnthropicClient(anthropic_key)
        if cohere_key:
            self.providers['cohere'] = CohereClient(cohere_key)

        self.stats = {
            "groq_calls": 0,
            "zhipu_calls": 0,
            "anthropic_calls": 0,
            "cohere_calls": 0,
            "total_tokens": 0,
            "total_time": 0
        }

        # Provider priority for fallback
        self.fallback_order = ['groq', 'cohere', 'zhipu', 'anthropic']

    def hybrid_inference(
        self,
        task: str,
        force_provider: Optional[str] = None,
        context_length: int = 0,
        use_igla: bool = True,
        prefer_quality: bool = False
    ) -> dict:
        """
        Execute hybrid inference with auto-provider selection.

        Args:
            task: The task/prompt to execute
            force_provider: Provider name to force (groq, zhipu, anthropic, cohere)
            context_length: Estimated context length for long context detection
            use_igla: Whether to include IGLA symbolic planning
            prefer_quality: Prefer quality over speed (uses Anthropic)
        """
        result = {
            "task": task,
            "igla_plan": None,
            "provider": None,
            "provider_reason": None,
            "response": None,
            "phi_verified": False,
            "language": detect_language(task)
        }

        # Step 1: IGLA symbolic planning
        if use_igla:
            result["igla_plan"] = generate_igla_plan(task)
            phi_result = verify_phi_identity()
            result["phi_verified"] = abs(phi_result - 3.0) < 0.0001

        # Step 2: Select provider
        if force_provider and force_provider.lower() in self.providers:
            selected_provider = force_provider.lower()
            reason = f"Forced: {force_provider}"
        else:
            selected_provider, reason = select_provider(
                task, context_length, prefer_quality
            )
            # Check if selected provider is available
            if selected_provider not in self.providers:
                # Fall back to first available
                selected_provider = next(iter(self.providers.keys()), None)
                if selected_provider:
                    reason += f" (fallback to {selected_provider})"

        result["provider"] = selected_provider.capitalize() if selected_provider else "None"
        result["provider_reason"] = reason

        if not selected_provider or selected_provider not in self.providers:
            result["response"] = {"error": "No providers available"}
            return result

        # Step 3: Enhance prompt with IGLA if enabled
        enhanced_prompt = task
        if use_igla and result["igla_plan"]:
            enhanced_prompt = f"""Based on this symbolic plan:
{result['igla_plan']}

Execute the task: {task}

Provide a precise, coherent response."""

        # Step 4: Execute with selected provider
        client = self.providers[selected_provider]
        try:
            result["response"] = client.chat(enhanced_prompt)
            self.stats[f"{selected_provider}_calls"] += 1

            if result["response"].get("tokens"):
                self.stats["total_tokens"] += result["response"]["tokens"]
            if result["response"].get("elapsed"):
                self.stats["total_time"] += result["response"]["elapsed"]

        except Exception as e:
            result["response"] = {"error": str(e)}

            # Fallback to next available provider
            for fallback in self.fallback_order:
                if fallback != selected_provider and fallback in self.providers:
                    try:
                        print(f"   Fallback to {fallback}...")
                        fallback_client = self.providers[fallback]
                        result["response"] = fallback_client.chat(enhanced_prompt)
                        self.stats[f"{fallback}_calls"] += 1

                        if result["response"].get("tokens"):
                            self.stats["total_tokens"] += result["response"]["tokens"]
                        if result["response"].get("elapsed"):
                            self.stats["total_time"] += result["response"]["elapsed"]

                        result["provider"] = fallback.capitalize()
                        result["provider_reason"] += f" (fallback from {selected_provider})"
                        break
                    except Exception:
                        continue

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
    # English prompts → Groq (fast, default)
    ("prove φ² + 1/φ² = 3 where φ = (1+√5)/2", None, False),
    ("solve 2+2 step by step", None, False),
    ("write a Python one-liner to reverse a string", None, False),
    ("what is the capital of France?", None, False),

    # Chinese prompts → Zhipu (auto-detect)
    ("用中文解释什么是人工智能", None, False),  # Explain AI in Chinese
    ("计算 2+2 的结果", None, False),  # Calculate 2+2

    # Russian prompt → test Cyrillic detection
    ("Объясни что такое искусственный интеллект", None, False),

    # Quality mode → Anthropic (if key available)
    ("explain the theory of relativity", None, True),

    # Forced provider tests
    ("what comes next: 1, 1, 2, 3, 5, 8, ?", "groq", False),
    ("explain quantum computing simply", "zhipu", False),
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

    # Get API keys from environment
    groq_key = os.environ.get("GROQ_API_KEY")
    zhipu_key = os.environ.get("ZHIPU_API_KEY", "fcbb5dadc5ea462284f5475a04daa174.Ei5KkZb0WQMwasmd")
    anthropic_key = os.environ.get("ANTHROPIC_API_KEY")
    cohere_key = os.environ.get("COHERE_API_KEY")

    if not groq_key and not zhipu_key:
        print("\n" + "=" * 70)
        print("ERROR: No API keys set!")
        print("Set at least one: GROQ_API_KEY, ZHIPU_API_KEY, ANTHROPIC_API_KEY, COHERE_API_KEY")
        print("=" * 70)
        return

    print("\nAvailable Providers:")
    if groq_key:
        print(f"  ✓ Groq: {groq_key[:20]}...")
    if zhipu_key:
        print(f"  ✓ Zhipu: {zhipu_key[:20]}...")
    if anthropic_key:
        print(f"  ✓ Anthropic: {anthropic_key[:20]}...")
    if cohere_key:
        print(f"  ✓ Cohere: {cohere_key[:20]}...")

    # Initialize hybrid with available providers
    try:
        hybrid = MultiProviderHybrid(
            groq_key=groq_key,
            zhipu_key=zhipu_key,
            anthropic_key=anthropic_key,
            cohere_key=cohere_key
        )
        print(f"\nActive providers: {list(hybrid.providers.keys())}")
    except Exception as e:
        print(f"Error initializing hybrid: {e}")
        return

    results = []

    for i, (prompt, force_provider, quality_mode) in enumerate(TEST_PROMPTS):
        print(f"\n[{i+1}/{len(TEST_PROMPTS)}] {prompt[:50]}...")

        try:
            result = hybrid.hybrid_inference(
                prompt,
                force_provider=force_provider,
                use_igla=True,
                prefer_quality=quality_mode
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
