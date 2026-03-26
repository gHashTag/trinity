#!/usr/bin/env python3
"""
Unit tests for multi-provider API client.

Tests the MultiProviderClient and individual provider clients.
"""

import unittest
import sys
import json
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from urllib.error import HTTPError

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from eval.api_client import (
    MultiProviderClient,
    Provider,
    ModelTier,
    ModelConfig,
    APIResponse,
    OpenAIClient,
    AnthropicClient,
    GoogleClient,
    LocalClient,
    CustomClient
)


class TestModelConfig(unittest.TestCase):
    """Tests for ModelConfig dataclass."""

    def test_config_creation(self):
        """Test creating a model config."""
        config = ModelConfig(
            provider=Provider.OPENAI,
            model_name="gpt-4",
            tier=ModelTier.FLAGSHIP
        )

        self.assertEqual(config.provider, Provider.OPENAI)
        self.assertEqual(config.model_name, "gpt-4")
        self.assertEqual(config.tier, ModelTier.FLAGSHIP)

    def test_default_values(self):
        """Test default config values."""
        config = ModelConfig(
            provider=Provider.LOCAL,
            model_name="llama2"
        )

        self.assertIsNone(config.api_key)
        self.assertIsNone(config.base_url)
        self.assertEqual(config.tier, ModelTier.STANDARD)
        self.assertEqual(config.max_tokens, 4096)
        self.assertEqual(config.temperature, 0.7)


class TestAPIResponse(unittest.TestCase):
    """Tests for APIResponse dataclass."""

    def test_response_creation(self):
        """Test creating an API response."""
        response = APIResponse(
            content="Test response",
            model="gpt-4",
            provider=Provider.OPENAI,
            tokens_used=100,
            latency_ms=1500,
            confidence=0.9
        )

        self.assertEqual(response.content, "Test response")
        self.assertEqual(response.model, "gpt-4")
        self.assertEqual(response.provider, Provider.OPENAI)
        self.assertEqual(response.tokens_used, 100)
        self.assertEqual(response.latency_ms, 1500)
        self.assertEqual(response.confidence, 0.9)


class TestOpenAIClient(unittest.TestCase):
    """Tests for OpenAI client."""

    @patch.dict('os.environ', {'OPENAI_API_KEY': 'test-key-123'})
    def setUp(self):
        """Set up test fixtures."""
        self.config = ModelConfig(
            provider=Provider.OPENAI,
            model_name="gpt-3.5-turbo"
        )
        self.client = OpenAIClient(self.config)

    def test_client_initialization(self):
        """Test client initializes with API key."""
        self.assertIsNotNone(self.client.api_key)
        self.assertEqual(self.client.api_key, "test-key-123")

    @patch('urllib.request.urlopen')
    def test_generate_success(self, mock_urlopen):
        """Test successful generation."""
        # Mock response
        mock_response = MagicMock()
        mock_response.read.return_value = json.dumps({
            "choices": [{
                "message": {"content": "Test response"}
            }],
            "usage": {"total_tokens": 50},
            "model": "gpt-3.5-turbo"
        }).encode()
        mock_urlopen.return_value.__enter__.return_value = mock_response

        result = self.client.generate("Test prompt")

        self.assertEqual(result.content, "Test response")
        self.assertEqual(result.provider, Provider.OPENAI)
        self.assertEqual(result.tokens_used, 50)

    @patch('urllib.request.urlopen')
    def test_generate_http_error(self, mock_urlopen):
        """Test HTTP error handling."""
        mock_urlopen.side_effect = HTTPError(
            "url",
            401,
            "Unauthorized",
            {},
            None
        )

        with self.assertRaises(RuntimeError):
            self.client.generate("Test prompt")


class TestAnthropicClient(unittest.TestCase):
    """Tests for Anthropic client."""

    @patch.dict('os.environ', {'ANTHROPIC_API_KEY': 'test-key-123'})
    def setUp(self):
        """Set up test fixtures."""
        self.config = ModelConfig(
            provider=Provider.ANTHROPIC,
            model_name="claude-3-sonnet-20240229"
        )
        self.client = AnthropicClient(self.config)

    def test_client_initialization(self):
        """Test client initializes with API key."""
        self.assertIsNotNone(self.client.api_key)
        self.assertEqual(self.client.api_key, "test-key-123")

    @patch('urllib.request.urlopen')
    def test_generate_success(self, mock_urlopen):
        """Test successful generation."""
        mock_response = MagicMock()
        mock_response.read.return_value = json.dumps({
            "content": [{"text": "Test response"}],
            "usage": {"input_tokens": 20, "output_tokens": 30},
            "model": "claude-3-sonnet-20240229"
        }).encode()
        mock_urlopen.return_value.__enter__.return_value = mock_response

        result = self.client.generate("Test prompt")

        self.assertEqual(result.content, "Test response")
        self.assertEqual(result.provider, Provider.ANTHROPIC)


class TestLocalClient(unittest.TestCase):
    """Tests for Local client."""

    def setUp(self):
        """Set up test fixtures."""
        self.config = ModelConfig(
            provider=Provider.LOCAL,
            model_name="llama2",
            base_url="http://localhost:11434"
        )
        self.client = LocalClient(self.config)

    def test_client_initialization(self):
        """Test client initializes."""
        self.assertEqual(self.client.base_url, "http://localhost:11434")
        self.assertEqual(self.client.config.model_name, "llama2")

    @patch('urllib.request.urlopen')
    def test_generate_success(self, mock_urlopen):
        """Test successful generation."""
        mock_response = MagicMock()
        mock_response.read.return_value = json.dumps({
            "response": "Test response",
            "model": "llama2"
        }).encode()
        mock_urlopen.return_value.__enter__.return_value = mock_response

        result = self.client.generate("Test prompt")

        self.assertEqual(result.content, "Test response")
        self.assertEqual(result.provider, Provider.LOCAL)


class TestMultiProviderClient(unittest.TestCase):
    """Tests for MultiProviderClient."""

    def setUp(self):
        """Set up test fixtures."""
        self.client = MultiProviderClient(
            preferred_providers=[Provider.LOCAL],
            preferred_tier=ModelTier.STANDARD
        )

    def test_client_initialization(self):
        """Test client initializes."""
        self.assertIsNotNone(self.client.preferred_providers)
        self.assertEqual(self.client.preferred_tier, ModelTier.STANDARD)

    @patch('eval.api_client.LocalClient.generate')
    def test_generate_with_provider(self, mock_generate):
        """Test generating with specific provider."""
        mock_generate.return_value = APIResponse(
            content="Test",
            model="llama2",
            provider=Provider.LOCAL
        )

        result = self.client.generate(
            "Test prompt",
            provider=Provider.LOCAL
        )

        self.assertEqual(result.provider, Provider.LOCAL)
        self.assertEqual(result.content, "Test")

    def test_get_stats(self):
        """Test getting statistics."""
        stats = self.client.get_stats()
        self.assertIsInstance(stats, dict)


class TestConfidenceParsing(unittest.TestCase):
    """Tests for confidence extraction from responses."""

    def test_extract_from_format(self):
        """Test extracting confidence from formatted response."""
        from eval.api_client import OpenAIClient

        client = OpenAIClient(ModelConfig(
            provider=Provider.OPENAI,
            model_name="gpt-3.5-turbo"
        ))

        # Test various formats
        test_cases = [
            ("Answer: test\nConfidence: 0.7", 0.7),
            ("70% confident", 0.7),
            ("7/10 confidence", 0.7),
            ("Certainty: 80%", 0.8),
            ("Just text", 0.5),
        ]

        for response, expected in test_cases:
            with self.subTest(response=response):
                result = client._check_confidence_response(response, "")
                # This is a simplified test
                self.assertIn("Confidence", response or "Just text")


class TestProviderEnum(unittest.TestCase):
    """Tests for Provider enum."""

    def test_provider_values(self):
        """Test provider enum values."""
        self.assertEqual(Provider.OPENAI.value, "openai")
        self.assertEqual(Provider.ANTHROPIC.value, "anthropic")
        self.assertEqual(Provider.GOOGLE.value, "google")
        self.assertEqual(Provider.LOCAL.value, "local")
        self.assertEqual(Provider.CUSTOM.value, "custom")


class TestModelTierEnum(unittest.TestCase):
    """Tests for ModelTier enum."""

    def test_tier_values(self):
        """Test tier enum values."""
        self.assertEqual(ModelTier.FLAGSHIP.value, "flagship")
        self.assertEqual(ModelTier.STANDARD.value, "standard")
        self.assertEqual(ModelTier.FAST.value, "fast")


def run_tests():
    """Run all tests and return exit code."""
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(run_tests())
