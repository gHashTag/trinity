#!/usr/bin/env python3
"""
Unit tests for Trinity Cognitive Probes generators.

Tests each generator module for:
- Correct CSV output format
- φ-scaling difficulty calculation
- Question distribution
- Required fields
"""

import unittest
import csv
import tempfile
import os
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock
import json

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

# Import generators
try:
    from generators import gen_thlp, gen_tmp, gen_tagp, gen_tefb, gen_tscp
except ImportError:
    # Fallback for direct execution
    import gen_thlp, gen_tmp, gen_tagp, gen_tefb, gen_tscp


class TestMetacognitionGenerator(unittest.TestCase):
    """Tests for TMP (Metacognition) generator."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv')
        self.temp_file.close()

    def tearDown(self):
        """Clean up test fixtures."""
        if os.path.exists(self.temp_file.name):
            os.unlink(self.temp_file.name)

    def test_generate_items(self):
        """Test item generation produces correct count."""
        items = gen_tmp.generate_items(target_count=100)
        self.assertEqual(len(items), 100)

    def test_item_structure(self):
        """Test items have all required fields."""
        items = gen_tmp.generate_items(target_count=10)
        item = items[0]

        required_fields = [
            'id', 'task', 'question', 'answer', 'ground_truth_confidence',
            'difficulty', 'brain_zone', 'neural_analog'
        ]

        for field in required_fields:
            self.assertTrue(hasattr(item, field), f"Missing field: {field}")

    def test_confidence_range(self):
        """Test confidence values are in valid range [0, 1]."""
        items = gen_tmp.generate_items(target_count=100)

        for item in items:
            self.assertGreaterEqual(item.ground_truth_confidence, 0.0)
            self.assertLessEqual(item.ground_truth_confidence, 1.0)

    def test_difficulty_positive(self):
        """Test difficulty values are positive."""
        items = gen_tmp.generate_items(target_count=100)

        for item in items:
            self.assertGreater(item.difficulty, 0)

    def test_csv_write(self):
        """Test CSV output is valid."""
        items = gen_tmp.generate_items(target_count=10)
        gen_tmp.write_csv(items, self.temp_file.name)

        # Verify file exists and is readable
        self.assertTrue(os.path.exists(self.temp_file.name))

        with open(self.temp_file.name, 'r') as f:
            reader = csv.DictReader(f)
            rows = list(reader)

        self.assertEqual(len(rows), 10)

    def test_task_distribution(self):
        """Test items are distributed across tasks."""
        items = gen_tmp.generate_items(target_count=250)

        tasks = set(item.task for item in items)
        self.assertGreater(len(tasks), 1, "Items should span multiple tasks")

    def test_phi_scaling(self):
        """Test φ-scaling calculation."""
        phi_score_0 = gen_tmp.calculate_phi_score(0)
        phi_score_1 = gen_tmp.calculate_phi_score(1)

        self.assertGreater(phi_score_0, 0)
        self.assertGreater(phi_score_1, phi_score_0)  # Should increase


class TestLearningGenerator(unittest.TestCase):
    """Tests for THLP (Learning) generator."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv')
        self.temp_file.close()

    def tearDown(self):
        """Clean up test fixtures."""
        if os.path.exists(self.temp_file.name):
            os.unlink(self.temp_file.name)

    def test_generate_items(self):
        """Test item generation produces correct count."""
        items = gen_thlp.generate_items(target_count=100)
        self.assertEqual(len(items), 100)

    def test_examples_count_range(self):
        """Test examples_count is non-negative."""
        items = gen_thlp.generate_items(target_count=100)

        for item in items:
            self.assertGreaterEqual(item.examples_count, 0)


class TestAttentionGenerator(unittest.TestCase):
    """Tests for TAGP (Attention) generator."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv')
        self.temp_file.close()

    def tearDown(self):
        """Clean up test fixtures."""
        if os.path.exists(self.temp_file.name):
            os.unlink(self.temp_file.name)

    def test_generate_items(self):
        """Test item generation produces correct count."""
        items = gen_tagp.generate_items(target_count=100)
        self.assertEqual(len(items), 100)

    def test_distractor_count_positive(self):
        """Test distractor_count is non-negative."""
        items = gen_tagp.generate_items(target_count=100)

        for item in items:
            self.assertGreaterEqual(item.distractor_count, 0)


class TestExecutiveGenerator(unittest.TestCase):
    """Tests for TEFB (Executive) generator."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv')
        self.temp_file.close()

    def tearDown(self):
        """Clean up test fixtures."""
        if os.path.exists(self.temp_file.name):
            os.unlink(self.temp_file.name)

    def test_generate_items(self):
        """Test item generation produces correct count."""
        items = gen_tefb.generate_items(target_count=100)
        self.assertEqual(len(items), 100)

    def test_actions_needed_positive(self):
        """Test actions_needed is positive."""
        items = gen_tefb.generate_items(target_count=100)

        for item in items:
            self.assertGreater(item.actions_needed, 0)


class TestSocialGenerator(unittest.TestCase):
    """Tests for TSCP (Social) generator."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv')
        self.temp_file.close()

    def tearDown(self):
        """Clean up test fixtures."""
        if os.path.exists(self.temp_file.name):
            os.unlink(self.temp_file.name)

    def test_generate_items(self):
        """Test item generation produces correct count."""
        items = gen_tscp.generate_items(target_count=100)
        self.assertEqual(len(items), 100)

    def test_scenario_not_empty(self):
        """Test scenarios are not empty."""
        items = gen_tscp.generate_items(target_count=100)

        for item in items:
            self.assertTrue(len(item.scenario) > 0, "Scenario should not be empty")


class TestGeneratorIntegration(unittest.TestCase):
    """Integration tests for all generators."""

    def test_all_generators_run(self):
        """Test all generators can produce output."""
        generators = [
            ("THLP", gen_thlp),
            ("TMP", gen_tmp),
            ("TAGP", gen_tagp),
            ("TEFB", gen_tefb),
            ("TSCP", gen_tscp)
        ]

        for name, gen_module in generators:
            with self.subTest(generator=name):
                items = gen_module.generate_items(target_count=10)
                self.assertGreater(len(items), 0, f"{name} should produce items")

    def test_all_csv_formats_valid(self):
        """Test all generators produce valid CSV."""
        generators = [
            ("THLP", gen_thlp),
            ("TMP", gen_tmp),
            ("TAGP", gen_tagp),
            ("TEFB", gen_tefb),
            ("TSCP", gen_tscp)
        ]

        for name, gen_module in generators:
            with self.subTest(generator=name):
                temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv')
                temp_file.close()

                try:
                    items = gen_module.generate_items(target_count=10)
                    gen_module.write_csv(items, temp_file.name)

                    # Verify CSV is readable
                    with open(temp_file.name, 'r') as f:
                        reader = csv.DictReader(f)
                        rows = list(reader)

                    self.assertEqual(len(rows), 10)

                finally:
                    if os.path.exists(temp_file.name):
                        os.unlink(temp_file.name)


class TestQuestionTemplates(unittest.TestCase):
    """Test question template loading from JSON."""

    def test_metacognition_templates_exist(self):
        """Test metacognition question templates can be loaded."""
        questions_path = Path(__file__).parent.parent / "questions" / "metacognition.json"

        if not questions_path.exists():
            self.skipTest("Question templates not found")

        with open(questions_path, 'r') as f:
            data = json.load(f)

        # Check structure
        self.assertIn("confidence_calibration", data)
        self.assertIn("templates", data["confidence_calibration"])

        templates = data["confidence_calibration"]["templates"]
        self.assertGreater(len(templates), 0)

        # Check template structure
        template = templates[0]
        required_keys = ["id", "question", "answer", "ground_truth_confidence"]
        for key in required_keys:
            self.assertIn(key, template)

    def test_learning_templates_exist(self):
        """Test learning question templates can be loaded."""
        questions_path = Path(__file__).parent.parent / "questions" / "learning.json"

        if not questions_path.exists():
            self.skipTest("Question templates not found")

        with open(questions_path, 'r') as f:
            data = json.load(f)

        # Check structure
        self.assertIn("few_shot_induction", data)
        self.assertIn("templates", data["few_shot_induction"])


class TestSeedReproducibility(unittest.TestCase):
    """Test random seed control for reproducibility."""

    def test_reproducible_output(self):
        """Test same seed produces same output."""
        import random

        # Set seed and generate
        random.seed(42)
        items1 = gen_tmp.generate_items(target_count=50)

        # Reset seed and generate again
        random.seed(42)
        items2 = gen_tmp.generate_items(target_count=50)

        # Should produce identical results
        self.assertEqual(len(items1), len(items2))

        for i, (item1, item2) in enumerate(zip(items1, items2)):
            self.assertEqual(item1.question, item2.question,
                           f"Item {i} questions differ with same seed")


def run_tests():
    """Run all tests and return exit code."""
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(run_tests())
