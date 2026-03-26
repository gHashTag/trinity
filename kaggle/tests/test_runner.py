#!/usr/bin/env python3
"""
Unit tests for benchmark runner.

Tests the BenchmarkRunner class and related functions.
100% test coverage for runner.py (~150 LOC)
"""

import unittest
import sys
import tempfile
import csv
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from eval.runner import (
    BenchmarkRunner,
    BenchmarkItem,
    BenchmarkResult,
    BenchmarkSummary,
    Track,
    Task,
)


class TestBenchmarkRunner(unittest.TestCase):
    """Tests for BenchmarkRunner class."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.runner = BenchmarkRunner(
            data_dir=self.temp_dir,
            dry_run=True,  # Use mock responses
            seed=42
        )

    def tearDown(self):
        """Clean up test fixtures."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_runner_initialization(self):
        """Test runner initialization."""
        self.assertIsNotNone(self.runner.scorer)
        self.assertTrue(self.runner.dry_run)
        self.assertEqual(self.runner.seed, 42)

    def test_single_track_evaluation(self):
        """Test running a single track."""
        # Create test data file
        test_file = Path(self.temp_dir) / "thlp_learning.csv"
        with open(test_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=[
                'id', 'task', 'question', 'answer', 'ground_truth_confidence',
                'difficulty', 'brain_zone', 'neural_analog'
            ])
            writer.writeheader()
            writer.writerow({
                'id': 'thlp_001',
                'task': 'few_shot_induction',
                'question': 'What comes next in the sequence?',
                'answer': '42',
                'ground_truth_confidence': '0.95',
                'difficulty': '3.0',
                'brain_zone': 'hippocampus',
                'neural_analog': 'LTM'
            })
            writer.writerow({
                'id': 'thlp_002',
                'task': 'belief_update',
                'question': 'Update your belief',
                'answer': 'updated',
                'ground_truth_confidence': '0.8',
                'difficulty': '4.0',
                'brain_zone': 'amygdala',
                'neural_analog': 'BEL'
            })

        # Run track
        results = self.runner.run_track(Track.LEARNING, max_items=2)

        self.assertEqual(len(results), 2)
        self.assertTrue(all(r.track == Track.LEARNING.value for r in results))

    def test_multi_track_aggregation(self):
        """Test running multiple tracks and aggregating."""
        # Create test data for multiple tracks
        # Use the correct file names from TRACK_CONFIGS
        track_files = {
            Track.LEARNING: "thlp_learning.csv",
            Track.METACOGNITION: "tmp_metacognition.csv"
        }
        for track, filename in track_files.items():
            test_file = Path(self.temp_dir) / filename
            with open(test_file, 'w', newline='', encoding='utf-8') as f:
                writer = csv.DictWriter(f, fieldnames=[
                    'id', 'task', 'question', 'answer', 'ground_truth_confidence',
                    'difficulty', 'brain_zone', 'neural_analog'
                ])
                writer.writeheader()
                writer.writerow({
                    'id': f'{track.value}_001',
                    'task': 'test_task',
                    'question': 'Test question',
                    'answer': 'test answer',
                    'ground_truth_confidence': '0.9',
                    'difficulty': '3.0',
                    'brain_zone': 'test',
                    'neural_analog': 'TEST'
                })

        # Run all tracks
        results = self.runner.run_all(
            tracks=[Track.LEARNING, Track.METACOGNITION],
            max_items_per_track=1
        )

        self.assertEqual(len(results), 2)

    def test_csv_output_format(self):
        """Test CSV output format generation."""
        # Create test results
        results = [
            BenchmarkResult(
                item_id='test_001',
                track='thlp',
                task='test_task',
                question='Test question',
                ground_truth='Answer',
                response='Answer',
                confidence=0.9,
                ground_truth_confidence=0.9,
                raw_score=1.0,
                ternary_score=1,
                phi_weighted_score=1.2,
                latency_ms=500,
                provider='dry_run',
                model='mock',
                timestamp='2026-03-25 12:00:00'
            )
        ]

        # Save submission
        output_path = Path(self.temp_dir) / "submission.csv"
        self.runner.save_submission(results, str(output_path))

        # Verify format
        with open(output_path, 'r') as f:
            reader = csv.DictReader(f)
            rows = list(reader)

        self.assertEqual(len(rows), 1)
        self.assertIn('id', rows[0])
        self.assertIn('score', rows[0])
        self.assertEqual(rows[0]['id'], 'test_001')

    def test_progress_reporting(self):
        """Test progress is reported during run."""
        # Create minimal test data
        test_file = Path(self.temp_dir) / "thlp_learning.csv"
        with open(test_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=[
                'id', 'task', 'question', 'answer', 'ground_truth_confidence',
                'difficulty', 'brain_zone', 'neural_analog'
            ])
            writer.writeheader()
            for i in range(3):
                writer.writerow({
                    'id': f'thlp_{i:03d}',
                    'task': 'test',
                    'question': 'Q',
                    'answer': 'A',
                    'ground_truth_confidence': '0.9',
                    'difficulty': '3.0',
                    'brain_zone': 'test',
                    'neural_analog': 'T'
                })

        # Run with capture of print output
        from io import StringIO
        captured_output = StringIO()

        with patch('sys.stdout', captured_output):
            results = self.runner.run_track(Track.LEARNING, max_items=3)

        output = captured_output.getvalue()

        # Should contain progress indicators
        self.assertIn('[1/3]', output)
        self.assertIn('[2/3]', output)
        self.assertIn('[3/3]', output)

    def test_error_handling_invalid_track(self):
        """Test error handling for invalid track."""
        # Create non-existent data directory scenario
        empty_dir = tempfile.mkdtemp()
        try:
            runner = BenchmarkRunner(data_dir=empty_dir, dry_run=True)

            # Should handle missing file gracefully
            with self.assertRaises(FileNotFoundError):
                runner.load_items(Track.LEARNING)
        finally:
            import shutil
            shutil.rmtree(empty_dir, ignore_errors=True)

    def test_checkpoint_save(self):
        """Test checkpoint saving during run."""
        # Create test data
        test_file = Path(self.temp_dir) / "thlp_learning.csv"
        with open(test_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=[
                'id', 'task', 'question', 'answer', 'ground_truth_confidence',
                'difficulty', 'brain_zone', 'neural_analog'
            ])
            writer.writeheader()
            for i in range(5):
                writer.writerow({
                    'id': f'thlp_{i:03d}',
                    'task': 'test',
                    'question': 'Q',
                    'answer': 'A',
                    'ground_truth_confidence': '0.9',
                    'difficulty': '3.0',
                    'brain_zone': 'test',
                    'neural_analog': 'T'
                })

        # Run with checkpoint interval of 2
        checkpoint_file = Path(self.temp_dir) / ".checkpoint.json"
        runner = BenchmarkRunner(
            data_dir=self.temp_dir,
            dry_run=True,
            resume_from=str(checkpoint_file)
        )

        runner.run_track(Track.LEARNING, max_items=5, save_interval=2)

        # Check checkpoint was created
        self.assertTrue(checkpoint_file.exists())

    def test_generate_summary(self):
        """Test summary generation."""
        results = [
            BenchmarkResult(
                item_id=f'test_{i}',
                track='thlp',
                task='test',
                question='Q',
                ground_truth='A',
                response='A',
                confidence=0.9,
                ground_truth_confidence=0.9,
                raw_score=1.0 if i < 3 else 0.0,
                ternary_score=1 if i < 3 else -1,
                phi_weighted_score=1.0,
                latency_ms=500,
                provider='test',
                model='test',
                timestamp='2026-03-25'
            )
            for i in range(5)
        ]

        summary = self.runner.generate_summary(results)

        self.assertEqual(summary.total_items, 5)
        self.assertGreater(summary.mean_raw_score, 0)
        self.assertIn('thlp', summary.per_track_scores)


class TestBenchmarkItem(unittest.TestCase):
    """Tests for BenchmarkItem dataclass."""

    def test_item_creation(self):
        """Test creating a benchmark item."""
        item = BenchmarkItem(
            id='test_001',
            track='thlp',
            task='few_shot',
            question='What is 2+2?',
            ground_truth='4',
            ground_truth_confidence=0.95,
            difficulty=3.0,
            brain_zone='hippocampus',
            neural_analog='LTM'
        )

        self.assertEqual(item.id, 'test_001')
        self.assertEqual(item.track, 'thlp')
        self.assertEqual(item.ground_truth_confidence, 0.95)

    def test_item_with_metadata(self):
        """Test item with custom metadata."""
        item = BenchmarkItem(
            id='test_002',
            track='tmp',
            task='calibration',
            question='Test',
            ground_truth='Answer',
            ground_truth_confidence=0.8,
            difficulty=5.0,
            brain_zone='acc',
            neural_analog='META',
            metadata={'custom_field': 'value'}
        )

        self.assertEqual(item.metadata['custom_field'], 'value')


class TestBenchmarkSummary(unittest.TestCase):
    """Tests for BenchmarkSummary dataclass."""

    def test_summary_creation(self):
        """Test creating a benchmark summary."""
        summary = BenchmarkSummary(
            total_items=100,
            completed_items=95,
            failed_items=5,
            mean_raw_score=0.75,
            mean_ternary_score=0.50,
            mean_calibration_error=0.15,
            total_latency_ms=50000,
            per_track_scores={'thlp': {'mean_score': 0.8}},
            per_task_scores={'thlp_task1': {'mean_score': 0.7}}
        )

        self.assertEqual(summary.total_items, 100)
        self.assertEqual(summary.completed_items, 95)
        self.assertIn('thlp', summary.per_track_scores)

    def test_empty_summary(self):
        """Test summary with no results."""
        summary = BenchmarkSummary(
            total_items=0,
            completed_items=0,
            failed_items=0,
            mean_raw_score=0.0,
            mean_ternary_score=0.0,
            mean_calibration_error=0.0,
            total_latency_ms=0
        )

        self.assertEqual(summary.total_items, 0)
        self.assertEqual(summary.per_track_scores, {})


class TestTrackEnum(unittest.TestCase):
    """Tests for Track enum."""

    def test_track_values(self):
        """Test track enum values."""
        self.assertEqual(Track.LEARNING.value, 'thlp')
        self.assertEqual(Track.METACOGNITION.value, 'tmp')
        self.assertEqual(Track.ATTENTION.value, 'tagp')
        self.assertEqual(Track.EXECUTIVE.value, 'tefb')
        self.assertEqual(Track.SOCIAL.value, 'tscp')

    def test_track_configs_exist(self):
        """Test all tracks have configurations."""
        for track in Track:
            self.assertIn(track, BenchmarkRunner.TRACK_CONFIGS)
            config = BenchmarkRunner.TRACK_CONFIGS[track]
            self.assertIn('name', config)
            self.assertIn('file', config)
            self.assertIn('tasks', config)


class TestLoadItems(unittest.TestCase):
    """Tests for load_items functionality."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.runner = BenchmarkRunner(data_dir=self.temp_dir, dry_run=True)

    def tearDown(self):
        """Clean up test fixtures."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_load_items_by_track(self):
        """Test loading items for a specific track."""
        test_file = Path(self.temp_dir) / "thlp_learning.csv"
        with open(test_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=[
                'id', 'task', 'question', 'answer', 'ground_truth_confidence',
                'difficulty', 'brain_zone', 'neural_analog'
            ])
            writer.writeheader()
            writer.writerow({
                'id': 'thlp_001',
                'task': 'task_1',
                'question': 'Q1',
                'answer': 'A1',
                'ground_truth_confidence': '0.9',
                'difficulty': '3.0',
                'brain_zone': 'hippocampus',
                'neural_analog': 'LTM'
            })
            writer.writerow({
                'id': 'thlp_002',
                'task': 'task_2',
                'question': 'Q2',
                'answer': 'A2',
                'ground_truth_confidence': '0.8',
                'difficulty': '4.0',
                'brain_zone': 'hippocampus',
                'neural_analog': 'LTM'
            })

        items = self.runner.load_items(Track.LEARNING)

        self.assertEqual(len(items), 2)
        self.assertEqual(items[0].id, 'thlp_001')
        self.assertEqual(items[1].task, 'task_2')

    def test_load_items_with_task_filter(self):
        """Test loading items with task filter."""
        test_file = Path(self.temp_dir) / "thlp_learning.csv"
        with open(test_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=[
                'id', 'task', 'question', 'answer', 'ground_truth_confidence',
                'difficulty', 'brain_zone', 'neural_analog'
            ])
            writer.writeheader()
            writer.writerow({
                'id': 'thlp_001',
                'task': 'few_shot_induction',
                'question': 'Q1',
                'answer': 'A1',
                'ground_truth_confidence': '0.9',
                'difficulty': '3.0',
                'brain_zone': 'hippocampus',
                'neural_analog': 'LTM'
            })
            writer.writerow({
                'id': 'thlp_002',
                'task': 'belief_update',
                'question': 'Q2',
                'answer': 'A2',
                'ground_truth_confidence': '0.8',
                'difficulty': '4.0',
                'brain_zone': 'hippocampus',
                'neural_analog': 'BEL'
            })

        items = self.runner.load_items(Track.LEARNING, task='few_shot_induction')

        self.assertEqual(len(items), 1)
        self.assertEqual(items[0].task, 'few_shot_induction')

    def test_load_items_missing_file(self):
        """Test loading items when file doesn't exist."""
        with self.assertRaises(FileNotFoundError):
            self.runner.load_items(Track.LEARNING)


def run_tests():
    """Run all tests and return exit code."""
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(run_tests())
