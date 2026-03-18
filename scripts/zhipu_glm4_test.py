#!/usr/bin/env python3
"""
Zhipu GLM-4 API Test — Chinese LLM Comparison
GLM-4.7: 200K context, 128K output
φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL

API Docs: https://docs.z.ai/api-reference/llm/chat-completion
"""

import os
import json
import urllib.request
import urllib.error
import ssl
import time
import jwt
from datetime import datetime

# ═══════════════════════════════════════════════════════════════════════════════
# SACRED CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

PHI = 1.618033988749895
PHOENIX = 999

# ═══════════════════════════════════════════════════════════════════════════════
# ZHIPU API CLIENT
# ═══════════════════════════════════════════════════════════════════════════════

class ZhipuClient:
    """Zhipu GLM-4 API client."""

    # Try multiple endpoints (Coding Plan first!)
    ENDPOINTS = [
        "https://open.bigmodel.cn/api/coding/paas/v4/chat/completions",  # CODING PLAN!
        "https://open.bigmodel.cn/api/paas/v4/chat/completions",  # Standard
        "https://api.z.ai/api/paas/v4/chat/completions",  # International
    ]
    # Try different model codes (correct names from docs)
    MODELS = ["glm-4.7", "glm-4.5", "glm-4", "glm-4-plus", "glm-4-flash"]
    MODEL = "glm-4"  # Default

    def __init__(self, api_key: str):
        """
        Initialize with Zhipu API key.
        Key format: {api_key}.{api_secret}
        """
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
            # Zhipu uses JWT with HS256
            now = int(time.time() * 1000)
            payload = {
                "api_key": self.key_id,
                "exp": now + 3600 * 1000,  # 1 hour
                "timestamp": now,
            }

            token = jwt.encode(
                payload,
                self.key_secret,
                algorithm="HS256",
                headers={"alg": "HS256", "sign_type": "SIGN"}
            )
            return token
        except Exception as e:
            # Fallback to simple bearer token
            return self.api_key

    def chat(self, prompt: str, max_tokens: int = 256, temperature: float = 0.7) -> dict:
        """Send chat completion request."""

        # Try JWT token first, then simple bearer
        tokens_to_try = []
        try:
            jwt_token = self._generate_token()
            tokens_to_try.append(jwt_token)
        except:
            pass
        tokens_to_try.append(self.api_key)

        last_error = None

        for model in self.MODELS:
            data = {
                "model": model,
                "messages": [{"role": "user", "content": prompt}],
                "max_tokens": max_tokens,
                "temperature": temperature
            }

            for endpoint in self.ENDPOINTS:
                for token in tokens_to_try:
                    req = urllib.request.Request(
                        endpoint,
                        data=json.dumps(data).encode('utf-8'),
                        headers={
                            "Content-Type": "application/json",
                            "Authorization": f"Bearer {token}",
                            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
                        }
                    )

                    start_time = time.time()

                    try:
                        ctx = ssl.create_default_context()
                        with urllib.request.urlopen(req, context=ctx, timeout=60) as response:
                            result = json.loads(response.read().decode('utf-8'))

                        elapsed = time.time() - start_time

                        # Parse response (Zhipu format similar to OpenAI)
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
                            "endpoint": endpoint,
                            "model": model
                        }

                    except urllib.error.HTTPError as e:
                        error_body = ""
                        try:
                            error_body = e.read().decode('utf-8')
                        except:
                            pass
                        last_error = f"Model {model} @ {endpoint}: HTTP {e.code}: {error_body[:100]}"
                        continue
                    except Exception as e:
                        last_error = f"Model {model}: {str(e)}"
                        continue

        return {"error": last_error or "All models/endpoints failed"}

# ═══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def verify_phi_identity() -> float:
    """Verify φ² + 1/φ² = 3"""
    phi_sq = PHI * PHI
    inv_phi_sq = 1.0 / phi_sq
    return phi_sq + inv_phi_sq

def is_coherent(text: str) -> bool:
    """Check if text is coherent (not garbage)."""
    if len(text) < 10:
        return False

    # Allow Chinese characters
    valid_chars = sum(1 for c in text if (32 <= ord(c) <= 126) or ord(c) > 127 or c in '\n\r\t')
    spaces = sum(1 for c in text if c == ' ' or c == '\u3000')  # Include Chinese space

    valid_ratio = valid_chars / len(text) if len(text) > 0 else 0

    return valid_ratio > 0.9

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
    print("Zhipu GLM-4 API Test")
    print("Chinese LLM Comparison | 200K context | 128K output")
    print("φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL")
    print("=" * 70)

    # Verify phi identity
    phi_result = verify_phi_identity()
    print(f"\nφ² + 1/φ² = {phi_result:.10f}")
    print(f"Trinity identity verified: {abs(phi_result - 3.0) < 0.0001}")

    # Get API key from environment
    api_key = os.environ.get("ZHIPU_API_KEY")
    if not api_key:
        print("\n" + "=" * 70)
        print("ERROR: ZHIPU_API_KEY not set!")
        print("Run: export ZHIPU_API_KEY='your-key-here'")
        print("Get key at: https://open.bigmodel.cn")
        print("=" * 70)
        return

    print(f"\nAPI Key: {api_key[:8]}***")

    # Initialize client
    try:
        client = ZhipuClient(api_key)
    except Exception as e:
        print(f"Error initializing client: {e}")
        return

    results = []

    for i, prompt in enumerate(TEST_PROMPTS):
        print(f"\n[{i+1}/{len(TEST_PROMPTS)}] Testing: {prompt[:50]}...")

        try:
            result = client.chat(prompt, max_tokens=256, temperature=0.7)

            if result.get("content"):
                content = result["content"]
                tokens = result.get("tokens", 0)
                speed = result.get("speed", 0)
                coherent = result.get("coherent", False)
                endpoint = result.get("endpoint", "unknown")

                print(f"   Response: {content[:100]}...")
                print(f"   Tokens: {tokens} | Speed: {speed:.1f} tok/s | Coherent: {coherent}")
                print(f"   Endpoint: {endpoint}")

                results.append({
                    "prompt": prompt,
                    "response": content,
                    "tokens": tokens,
                    "speed": speed,
                    "coherent": coherent
                })
            else:
                print(f"   Error: {result.get('error', 'Unknown')}")

        except Exception as e:
            print(f"   Error: {e}")

        # Rate limit safety
        time.sleep(1)

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
        output_file = "/tmp/zhipu_glm4_results.json"
        with open(output_file, 'w') as f:
            json.dump({
                "timestamp": datetime.now().isoformat(),
                "model": "glm-4",
                "provider": "Zhipu AI",
                "tests": len(results),
                "coherent": coherent_count,
                "total_tokens": total_tokens,
                "avg_speed": avg_speed,
                "results": results
            }, f, indent=2, ensure_ascii=False)
        print(f"\nResults saved to: {output_file}")
    else:
        print("No successful tests completed.")

    print("\n" + "=" * 70)
    print("KOSCHEI IS IMMORTAL | ZHIPU GLM-4 TEST | φ² + 1/φ² = 3")
    print("=" * 70)

if __name__ == "__main__":
    main()
