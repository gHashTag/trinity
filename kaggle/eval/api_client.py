#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Multi-Provider API Client

Supports multiple LLM providers for benchmark evaluation:
- OpenAI (GPT-4, GPT-3.5)
- Anthropic (Claude Opus, Sonnet, Haiku)
- Google (Gemini Pro, Ultra)
- Local (Ollama, vLLM, LM Studio)
- Custom (any OpenAI-compatible API)
"""

import os
import json
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional, Dict, List, Any, Union
from enum import Enum
import urllib.request
import urllib.error


class Provider(Enum):
    """Supported LLM providers."""
    OPENAI = "openai"
    ANTHROPIC = "anthropic"
    GOOGLE = "google"
    LOCAL = "local"
    CUSTOM = "custom"


class ModelTier(Enum):
    """Model capability tiers for routing."""
    FLAGSHIP = "flagship"  # GPT-4, Claude Opus, Gemini Ultra
    STANDARD = "standard"  # GPT-3.5, Claude Sonnet, Gemini Pro
    FAST = "fast"  # Haiku, small local models


@dataclass
class ModelConfig:
    """Configuration for a model."""
    provider: Provider
    model_name: str
    api_key: Optional[str] = None
    base_url: Optional[str] = None
    tier: ModelTier = ModelTier.STANDARD
    max_tokens: int = 4096
    temperature: float = 0.7
    timeout: int = 30


@dataclass
class APIResponse:
    """Response from an LLM API."""
    content: str
    model: str
    provider: Provider
    tokens_used: int = 0
    latency_ms: int = 0
    raw_response: Dict = None
    confidence: float = 0.5
    logprobs: List[float] = None


class LLMClient(ABC):
    """Abstract base class for LLM clients."""

    def __init__(self, config: ModelConfig):
        self.config = config
        self._request_count = 0
        self._total_tokens = 0

    @abstractmethod
    def generate(self, prompt: str, **kwargs) -> APIResponse:
        """Generate a response from the model."""
        pass

    @abstractmethod
    def generate_with_confidence(self, prompt: str) -> APIResponse:
        """Generate response with confidence scoring."""
        pass

    def get_stats(self) -> Dict[str, Any]:
        """Get client usage statistics."""
        return {
            "request_count": self._request_count,
            "total_tokens": self._total_tokens,
            "provider": self.config.provider.value,
            "model": self.config.model_name
        }


class OpenAIClient(LLMClient):
    """OpenAI API client."""

    DEFAULT_BASE_URL = "https://api.openai.com/v1"

    def __init__(self, config: ModelConfig):
        super().__init__(config)
        self.base_url = config.base_url or os.getenv("OPENAI_BASE_URL", self.DEFAULT_BASE_URL)
        self.api_key = config.api_key or os.getenv("OPENAI_API_KEY")
        if not self.api_key:
            raise ValueError("OpenAI API key not found")

    def generate(self, prompt: str, **kwargs) -> APIResponse:
        """Generate using OpenAI Chat Completions API."""
        start_time = time.time()

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        body = {
            "model": self.config.model_name,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": kwargs.get("max_tokens", self.config.max_tokens),
            "temperature": kwargs.get("temperature", self.config.temperature)
        }

        if kwargs.get("logprobs", False):
            body["logprobs"] = True
            body["top_logprobs"] = 5

        try:
            req = urllib.request.Request(
                f"{self.base_url}/chat/completions",
                data=json.dumps(body).encode("utf-8"),
                headers=headers,
                method="POST"
            )

            with urllib.request.urlopen(req, timeout=self.config.timeout) as response:
                result = json.loads(response.read().decode("utf-8"))

                self._request_count += 1
                self._total_tokens += result.get("usage", {}).get("total_tokens", 0)

                content = result["choices"][0]["message"]["content"]
                logprobs = self._extract_logprobs(result)

                return APIResponse(
                    content=content,
                    model=result.get("model", self.config.model_name),
                    provider=Provider.OPENAI,
                    tokens_used=result.get("usage", {}).get("total_tokens", 0),
                    latency_ms=int((time.time() - start_time) * 1000),
                    raw_response=result,
                    confidence=self._confidence_from_logprobs(logprobs),
                    logprobs=logprobs
                )

        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8")
            raise RuntimeError(f"OpenAI API error: {e.code} - {error_body}")

    def generate_with_confidence(self, prompt: str) -> APIResponse:
        """Generate with logprob-based confidence."""
        # Add confidence request to prompt
        confidence_prompt = f"""{prompt}

Provide your answer followed by your confidence level (0.0 to 1.0).

Format:
Answer: [your answer]
Confidence: [0.0 to 1.0]"""

        return self.generate(confidence_prompt, logprobs=True)

    def _extract_logprobs(self, result: Dict) -> List[float]:
        """Extract logprobs from response."""
        try:
            logprobs = result["choices"][0].get("logprobs", {}).get("content", [])
            if logprobs:
                return [lp.get("logprob", -10) for lp in logprobs]
        except (KeyError, IndexError, TypeError):
            pass
        return []

    def _confidence_from_logprobs(self, logprobs: List[float]) -> float:
        """Estimate confidence from logprobs."""
        if not logprobs:
            return 0.5

        # Average logprob converted to probability-ish scale
        avg_logprob = sum(logprobs) / len(logprobs)
        # Clamp and convert logprob (-10 to 0) to confidence (0 to 1)
        return max(0.0, min(1.0, (avg_logprob + 5) / 5))


class AnthropicClient(LLMClient):
    """Anthropic Claude API client."""

    DEFAULT_BASE_URL = "https://api.anthropic.com/v1"

    def __init__(self, config: ModelConfig):
        super().__init__(config)
        self.base_url = config.base_url or os.getenv("ANTHROPIC_BASE_URL", self.DEFAULT_BASE_URL)
        self.api_key = config.api_key or os.getenv("ANTHROPIC_API_KEY")
        if not self.api_key:
            raise ValueError("Anthropic API key not found")

    def generate(self, prompt: str, **kwargs) -> APIResponse:
        """Generate using Anthropic Messages API."""
        start_time = time.time()

        headers = {
            "x-api-key": self.api_key,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json"
        }

        body = {
            "model": self.config.model_name,
            "max_tokens": kwargs.get("max_tokens", self.config.max_tokens),
            "messages": [{"role": "user", "content": prompt}]
        }

        try:
            req = urllib.request.Request(
                f"{self.base_url}/messages",
                data=json.dumps(body).encode("utf-8"),
                headers=headers,
                method="POST"
            )

            with urllib.request.urlopen(req, timeout=self.config.timeout) as response:
                result = json.loads(response.read().decode("utf-8"))

                self._request_count += 1
                self._total_tokens += result.get("usage", {}).get("input_tokens", 0)
                self._total_tokens += result.get("usage", {}).get("output_tokens", 0)

                content = result["content"][0]["text"]

                return APIResponse(
                    content=content,
                    model=result.get("model", self.config.model_name),
                    provider=Provider.ANTHROPIC,
                    tokens_used=result.get("usage", {}).get("input_tokens", 0) + result.get("usage", {}).get("output_tokens", 0),
                    latency_ms=int((time.time() - start_time) * 1000),
                    raw_response=result
                )

        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8")
            raise RuntimeError(f"Anthropic API error: {e.code} - {error_body}")

    def generate_with_confidence(self, prompt: str) -> APIResponse:
        """Generate with confidence request."""
        confidence_prompt = f"""{prompt}

Provide your answer followed by your confidence level (0.0 to 1.0).

Format:
Answer: [your answer]
Confidence: [0.0 to 1.0]"""

        return self.generate(confidence_prompt)


class GoogleClient(LLMClient):
    """Google Gemini API client."""

    DEFAULT_BASE_URL = "https://generativelanguage.googleapis.com/v1beta"

    def __init__(self, config: ModelConfig):
        super().__init__(config)
        self.api_key = config.api_key or os.getenv("GOOGLE_API_KEY")
        if not self.api_key:
            raise ValueError("Google API key not found")

    def generate(self, prompt: str, **kwargs) -> APIResponse:
        """Generate using Google Gemini API."""
        start_time = time.time()

        # Use generate endpoint
        url = f"{self.DEFAULT_BASE_URL}/models/{self.config.model_name}:generateContent?key={self.api_key}"

        headers = {"Content-Type": "application/json"}

        body = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": kwargs.get("temperature", self.config.temperature),
                "maxOutputTokens": kwargs.get("max_tokens", self.config.max_tokens)
            }
        }

        try:
            req = urllib.request.Request(
                url,
                data=json.dumps(body).encode("utf-8"),
                headers=headers,
                method="POST"
            )

            with urllib.request.urlopen(req, timeout=self.config.timeout) as response:
                result = json.loads(response.read().decode("utf-8"))

                self._request_count += 1

                content = result["candidates"][0]["content"]["parts"][0]["text"]

                return APIResponse(
                    content=content,
                    model=self.config.model_name,
                    provider=Provider.GOOGLE,
                    latency_ms=int((time.time() - start_time) * 1000),
                    raw_response=result
                )

        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8")
            raise RuntimeError(f"Google API error: {e.code} - {error_body}")

    def generate_with_confidence(self, prompt: str) -> APIResponse:
        """Generate with confidence request."""
        confidence_prompt = f"""{prompt}

Provide your answer followed by your confidence level (0.0 to 1.0).

Format:
Answer: [your answer]
Confidence: [0.0 to 1.0]"""

        return self.generate(confidence_prompt)


class LocalClient(LLMClient):
    """Local model client (Ollama, vLLM, LM Studio)."""

    def __init__(self, config: ModelConfig):
        super().__init__(config)
        self.base_url = config.base_url or os.getenv(
            "LOCAL_LLM_URL",
            "http://localhost:11434"  # Default Ollama
        )

    def generate(self, prompt: str, **kwargs) -> APIResponse:
        """Generate using local LLM (Ollama-compatible API)."""
        start_time = time.time()

        headers = {"Content-Type": "application/json"}

        body = {
            "model": self.config.model_name,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": kwargs.get("temperature", self.config.temperature),
                "num_predict": kwargs.get("max_tokens", self.config.max_tokens)
            }
        }

        try:
            req = urllib.request.Request(
                f"{self.base_url}/api/generate",
                data=json.dumps(body).encode("utf-8"),
                headers=headers,
                method="POST"
            )

            with urllib.request.urlopen(req, timeout=self.config.timeout) as response:
                result = json.loads(response.read().decode("utf-8"))

                self._request_count += 1

                return APIResponse(
                    content=result.get("response", ""),
                    model=self.config.model_name,
                    provider=Provider.LOCAL,
                    latency_ms=int((time.time() - start_time) * 1000),
                    raw_response=result
                )

        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8")
            raise RuntimeError(f"Local LLM error: {e.code} - {error_body}")

    def generate_with_confidence(self, prompt: str) -> APIResponse:
        """Generate with confidence request."""
        confidence_prompt = f"""{prompt}

Provide your answer followed by your confidence level (0.0 to 1.0).

Format:
Answer: [your answer]
Confidence: [0.0 to 1.0]"""

        return self.generate(confidence_prompt)


class CustomClient(LLMClient):
    """Custom OpenAI-compatible API client."""

    def __init__(self, config: ModelConfig):
        super().__init__(config)
        self.base_url = config.base_url or os.getenv("CUSTOM_API_BASE_URL")
        self.api_key = config.api_key or os.getenv("CUSTOM_API_KEY", "not-needed")

        if not self.base_url:
            raise ValueError("Custom API base URL not found")

    def generate(self, prompt: str, **kwargs) -> APIResponse:
        """Generate using custom OpenAI-compatible API."""
        start_time = time.time()

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        body = {
            "model": self.config.model_name,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": kwargs.get("max_tokens", self.config.max_tokens),
            "temperature": kwargs.get("temperature", self.config.temperature)
        }

        try:
            req = urllib.request.Request(
                f"{self.base_url}/chat/completions",
                data=json.dumps(body).encode("utf-8"),
                headers=headers,
                method="POST"
            )

            with urllib.request.urlopen(req, timeout=self.config.timeout) as response:
                result = json.loads(response.read().decode("utf-8"))

                self._request_count += 1
                self._total_tokens += result.get("usage", {}).get("total_tokens", 0)

                content = result["choices"][0]["message"]["content"]

                return APIResponse(
                    content=content,
                    model=result.get("model", self.config.model_name),
                    provider=Provider.CUSTOM,
                    tokens_used=result.get("usage", {}).get("total_tokens", 0),
                    latency_ms=int((time.time() - start_time) * 1000),
                    raw_response=result
                )

        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8")
            raise RuntimeError(f"Custom API error: {e.code} - {error_body}")

    def generate_with_confidence(self, prompt: str) -> APIResponse:
        """Generate with confidence request."""
        confidence_prompt = f"""{prompt}

Provide your answer followed by your confidence level (0.0 to 1.0).

Format:
Answer: [your answer]
Confidence: [0.0 to 1.0]"""

        return self.generate(confidence_prompt)


class MultiProviderClient:
    """
    Multi-provider LLM client with automatic fallback and routing.

    Supports:
    - Automatic provider selection based on availability
    - Tier-based model routing
    - Fallback on errors
    - Provider statistics
    """

    # Default model configurations by tier
    # Updated 2024 for current model availability
    DEFAULT_MODELS = {
        Provider.OPENAI: {
            ModelTier.FLAGSHIP: "gpt-4o",  # Updated from gpt-4-turbo-preview
            ModelTier.STANDARD: "gpt-4o-mini",  # Updated from gpt-3.5-turbo
            ModelTier.FAST: "gpt-4o-mini"
        },
        Provider.ANTHROPIC: {
            ModelTier.FLAGSHIP: "claude-sonnet-4-20250514",  # Latest Sonnet 4
            ModelTier.STANDARD: "claude-3-5-sonnet-20241022",  # Claude 3.5 Sonnet
            ModelTier.FAST: "claude-3-5-haiku-20241022"  # Claude 3.5 Haiku
        },
        Provider.GOOGLE: {
            ModelTier.FLAGSHIP: "gemini-2.0-flash-exp",  # Updated for Gemini 2.0
            ModelTier.STANDARD: "gemini-2.0-flash",
            ModelTier.FAST: "gemini-2.0-flash"
        },
        Provider.LOCAL: {
            ModelTier.STANDARD: "llama3",  # Updated from llama2
            ModelTier.FAST: "phi-3"  # Updated from phi
        }
    }

    def __init__(
        self,
        preferred_providers: List[Provider] = None,
        preferred_tier: ModelTier = ModelTier.STANDARD
    ):
        """
        Initialize multi-provider client.

        Args:
            preferred_providers: List of providers to try, in order
            preferred_tier: Preferred model tier
        """
        self.preferred_providers = preferred_providers or [
            Provider.ANTHROPIC,
            Provider.OPENAI,
            Provider.GOOGLE,
            Provider.LOCAL
        ]
        self.preferred_tier = preferred_tier
        self._clients: Dict[Provider, LLMClient] = {}
        self._provider_stats: Dict[Provider, Dict] = {}

    def get_client(self, provider: Provider) -> LLMClient:
        """Get or create a client for the specified provider."""
        if provider not in self._clients:
            model_name = self.DEFAULT_MODELS.get(provider, {}).get(self.preferred_tier)

            if not model_name:
                raise ValueError(f"No model configured for {provider} at tier {self.preferred_tier}")

            config = ModelConfig(
                provider=provider,
                model_name=model_name,
                tier=self.preferred_tier
            )

            self._clients[provider] = self._create_client(config)

        return self._clients[provider]

    def _create_client(self, config: ModelConfig) -> LLMClient:
        """Create a client instance based on provider."""
        client_classes = {
            Provider.OPENAI: OpenAIClient,
            Provider.ANTHROPIC: AnthropicClient,
            Provider.GOOGLE: GoogleClient,
            Provider.LOCAL: LocalClient,
            Provider.CUSTOM: CustomClient
        }

        client_class = client_classes.get(config.provider)
        if not client_class:
            raise ValueError(f"Unknown provider: {config.provider}")

        try:
            return client_class(config)
        except Exception as e:
            raise RuntimeError(f"Failed to create {config.provider.value} client: {e}")

    def generate(
        self,
        prompt: str,
        provider: Provider = None,
        tier: ModelTier = None,
        with_confidence: bool = False
    ) -> APIResponse:
        """
        Generate a response, trying providers in order.

        Args:
            prompt: The prompt to send
            provider: Specific provider to use (tries preferred if None)
            tier: Specific tier to use (uses default if None)
            with_confidence: Request confidence scoring

        Returns:
            APIResponse from the first successful provider
        """
        providers_to_try = [provider] if provider else self.preferred_providers

        last_error = None

        for prov in providers_to_try:
            try:
                client = self.get_client(prov)

                if with_confidence:
                    response = client.generate_with_confidence(prompt)
                else:
                    response = client.generate(prompt)

                # Update stats
                if prov not in self._provider_stats:
                    self._provider_stats[prov] = {"success": 0, "errors": 0}
                self._provider_stats[prov]["success"] += 1

                return response

            except Exception as e:
                last_error = e
                if prov not in self._provider_stats:
                    self._provider_stats[prov] = {"success": 0, "errors": 0}
                self._provider_stats[prov]["errors"] += 1
                continue

        # All providers failed
        raise RuntimeError(f"All providers failed. Last error: {last_error}")

    def get_stats(self) -> Dict[str, Any]:
        """Get statistics for all providers."""
        stats = {}

        for provider, client in self._clients.items():
            stats[provider.value] = client.get_stats()
            stats[provider.value]["provider_stats"] = self._provider_stats.get(provider, {})

        return stats

    def print_stats(self):
        """Print provider statistics."""
        print("\n" + "="*60)
        print("Multi-Provider Statistics")
        print("="*60)

        for provider, stats in self.get_stats().items():
            print(f"\n{provider.upper()}:")
            print(f"  Requests: {stats.get('request_count', 0)}")
            print(f"  Tokens: {stats.get('total_tokens', 0)}")
            print(f"  Successes: {stats.get('provider_stats', {}).get('success', 0)}")
            print(f"  Errors: {stats.get('provider_stats', {}).get('errors', 0)}")

        print("="*60 + "\n")


if __name__ == "__main__":
    # Test the multi-provider client
    client = MultiProviderClient()

    try:
        response = client.generate(
            "What is the capital of Uzbekistan?",
            with_confidence=True
        )

        print(f"Response: {response.content}")
        print(f"Provider: {response.provider.value}")
        print(f"Model: {response.model}")
        print(f"Latency: {response.latency_ms}ms")

        client.print_stats()

    except Exception as e:
        print(f"Error: {e}")
        print("\nNote: Set API keys as environment variables to test:")
        print("  OPENAI_API_KEY, ANTHROPIC_API_KEY, or GOOGLE_API_KEY")
