#!/usr/bin/env python3
"""
Test OpenAI API for IGLA hybrid integration.
φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
"""

import os
import json
import urllib.request
import urllib.error
import ssl

# Constants
PHI = 1.618033988749895
PHOENIX = 999

def verify_phi_identity():
    """Verify φ² + 1/φ² = 3"""
    phi_sq = PHI * PHI
    inv_phi_sq = 1.0 / phi_sq
    return phi_sq + inv_phi_sq

def test_openai_api():
    """Test OpenAI API with phi identity prompt"""
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("ERROR: OPENAI_API_KEY not set")
        return None

    url = "https://api.openai.com/v1/chat/completions"

    prompts = [
        "prove φ² + 1/φ² = 3 where φ = (1+√5)/2. Be concise.",
        "solve 2+2 step by step",
        "The future of AI in one sentence",
    ]

    results = []

    for prompt in prompts:
        data = {
            "model": "gpt-4o-mini",
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 150,
            "temperature": 0.7
        }

        req = urllib.request.Request(
            url,
            data=json.dumps(data).encode('utf-8'),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}"
            }
        )

        try:
            # Create SSL context
            ctx = ssl.create_default_context()

            with urllib.request.urlopen(req, context=ctx, timeout=30) as response:
                result = json.loads(response.read().decode('utf-8'))
                content = result['choices'][0]['message']['content']
                tokens = result.get('usage', {}).get('total_tokens', 0)

                results.append({
                    "prompt": prompt,
                    "response": content,
                    "tokens": tokens,
                    "coherent": is_coherent(content)
                })

                print(f"\n=== Prompt: {prompt[:50]}... ===")
                print(f"Response: {content[:200]}...")
                print(f"Tokens: {tokens} | Coherent: {is_coherent(content)}")

        except urllib.error.HTTPError as e:
            print(f"HTTP Error: {e.code} - {e.reason}")
            return None
        except Exception as e:
            print(f"Error: {e}")
            return None

    return results

def is_coherent(text):
    """Check if text is coherent (not garbage)"""
    if len(text) < 10:
        return False

    valid_chars = sum(1 for c in text if 32 <= ord(c) <= 126 or c in '\n\r\t')
    spaces = sum(1 for c in text if c == ' ')

    valid_ratio = valid_chars / len(text)
    space_ratio = spaces / len(text) if len(text) > 0 else 0

    return valid_ratio > 0.9 and 0.05 < space_ratio < 0.35

def main():
    print("=" * 60)
    print("IGLA + OpenAI Hybrid Test")
    print("φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL")
    print("=" * 60)

    # Verify phi identity
    phi_result = verify_phi_identity()
    print(f"\nφ² + 1/φ² = {phi_result:.6f} (expected: 3.0)")

    # Test API
    print("\n--- Testing OpenAI API ---")
    results = test_openai_api()

    if results:
        print("\n" + "=" * 60)
        print("SUMMARY")
        print("=" * 60)
        coherent_count = sum(1 for r in results if r['coherent'])
        total_tokens = sum(r['tokens'] for r in results)
        print(f"Tests: {len(results)}")
        print(f"Coherent: {coherent_count}/{len(results)}")
        print(f"Total tokens: {total_tokens}")
        print(f"φ identity verified: {abs(phi_result - 3.0) < 0.0001}")

        # Output JSON for report
        print("\n--- JSON Results ---")
        print(json.dumps(results, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
