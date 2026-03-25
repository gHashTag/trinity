#!/usr/bin/env python3
"""
Unit tests for leaderboard helper.

Tests the KaggleLeaderboard class and related functions.
100% test coverage for leaderboard.py (~100 LOC)
"""

import unittest
import sys
import tempfile
import csv
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from eval.leaderboard import (
    KaggleLeaderboard,
    LeaderboardEntry,
    SubmissionSummary,
)


class TestLeaderboard(unittest.TestCase):
    """Tests for KaggleLeaderboard class."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.leaderboard = KaggleLeaderboard(data_dir=self.temp_dir)

    def tearDown(self):
        """Clean up test fixtures."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_leaderboard_initialization(self):
        """Test leaderboard initialization."""
        self.assertIsNotNone(self.leaderboard)
        self.assertEqual(self.leaderboard.REQUIRED_COLUMNS, ["id", "score"])

    def test_validate_submission_valid(self):
        """Test validation of valid submission file."""
        # Create valid submission
        submission_path = Path(self.temp_dir) / "valid_submission.csv"
        with open(submission_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=["id", "score"])
            writer.writeheader()
            writer.writerow({'id': 'q1', 'score': '0.75'})
            writer.writerow({'id': 'q2', 'score': '0.80'})
            writer.writerow({'id': 'q3', 'score': '0.70'})

        is_valid, errors = self.leaderboard.validate_submission(str(submission_path))

        self.assertTrue(is_valid)
        self.assertEqual(len(errors), 0)

    def test_validate_submission_missing_columns(self):
        """Test validation detects missing columns."""
        submission_path = Path(self.temp_dir) / "invalid_submission.csv"
        with open(submission_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=["id", "value"])  # Wrong column
            writer.writeheader()
            writer.writerow({'id': 'q1', 'value': '0.75'})

        is_valid, errors = self.leaderboard.validate_submission(str(submission_path))

        self.assertFalse(is_valid)
        self.assertGreater(len(errors), 0)
        self.assertTrue(any("columns" in e.lower() for e in errors))

    def test_validate_submission_no_rows(self):
        """Test validation detects empty file."""
        submission_path = Path(self.temp_dir) / "empty_submission.csv"
        with open(submission_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=["id", "score"])
            writer.writeheader()
            # No data rows

        is_valid, errors = self.leaderboard.validate_submission(str(submission_path))

        self.assertFalse(is_valid)
        self.assertTrue(any("No data rows" in e for e in errors))

    def test_validate_submission_duplicate_ids(self):
        """Test validation detects duplicate IDs."""
        submission_path = Path(self.temp_dir) / "dup_submission.csv"
        with open(submission_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=["id", "score"])
            writer.writeheader()
            writer.writerow({'id': 'q1', 'score': '0.75'})
            writer.writerow({'id': 'q1', 'score': '0.80'})  # Duplicate ID

        is_valid, errors = self.leaderboard.validate_submission(str(submission_path))

        self.assertFalse(is_valid)
        self.assertTrue(any("Duplicate" in e for e in errors))

    def test_validate_submission_score_range(self):
        """Test validation checks score range."""
        submission_path = Path(self.temp_dir) / "range_submission.csv"
        with open(submission_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=["id", "score"])
            writer.writeheader()
            writer.writerow({'id': 'q1', 'score': '0.75'})
            writer.writerow({'id': 'q2', 'score': '5.0'})  # Out of range

        is_valid, errors = self.leaderboard.validate_submission(str(submission_path))

        self.assertFalse(is_valid)
        self.assertTrue(any("out of expected range" in e for e in errors))

    def test_validate_submission_file_not_found(self):
        """Test validation with non-existent file."""
        is_valid, errors = self.leaderboard.validate_submission("nonexistent.csv")

        self.assertFalse(is_valid)
        self.assertTrue(any("not found" in e for e in errors))

    def test_generate_submission(self):
        """Test generating submission file."""
        results = [
            {'id': 'q1', 'score': 0.75},
            {'id': 'q2', 'score': 0.80},
            {'id': 'q3', 'score': 0.70}
        ]

        output_path = Path(self.temp_dir) / "generated_submission.csv"
        success = self.leaderboard.generate_submission(results, str(output_path))

        self.assertTrue(success)
        self.assertTrue(output_path.exists())

        # Verify format
        with open(output_path, 'r') as f:
            reader = csv.DictReader(f)
            rows = list(reader)

        self.assertEqual(len(rows), 3)
        self.assertEqual(rows[0]['id'], 'q1')
        self.assertEqual(rows[0]['score'], '0.75')

    def test_analyze_submission(self):
        """Test submission analysis."""
        # Create test submission
        submission_path = Path(self.temp_dir) / "test_submission.csv"
        with open(submission_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=["id", "score"])
            writer.writeheader()
            writer.writerow({'id': 'thlp_001', 'score': '0.7'})
            writer.writerow({'id': 'thlp_002', 'score': '0.8'})
            writer.writerow({'id': 'tmp_001', 'score': '0.6'})
            writer.writerow({'id': 'tagp_001', 'score': '0.9'})

        summary = self.leaderboard.analyze_submission(str(submission_path))

        self.assertEqual(summary.total_items, 4)
        self.assertAlmostEqual(summary.mean_score, 0.75, places=2)
        self.assertEqual(summary.min_score, 0.6)
        self.assertEqual(summary.max_score, 0.9)
        self.assertIn('thlp', summary.per_track_scores)
        self.assertIn('tmp', summary.per_track_scores)
        self.assertIn('tagp', summary.per_track_scores)


class TestLeaderboardPrediction(unittest.TestCase):
    """Tests for leaderboard prediction."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.leaderboard = KaggleLeaderboard(data_dir=self.temp_dir)

    def tearDown(self):
        """Clean up test fixtures."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_predict_rank_high_score(self):
        """Test rank prediction for high score."""
        rank = self.leaderboard.predict_rank(0.85, total_competitors=100)

        self.assertGreaterEqual(rank, 1)
        self.assertLessEqual(rank, 10)  # Top 10%

    def test_predict_rank_mid_score(self):
        """Test rank prediction for mid score."""
        rank = self.leaderboard.predict_rank(0.6, total_competitors=100)

        self.assertGreater(rank, 20)
        self.assertLessEqual(rank, 80)

    def test_predict_rank_low_score(self):
        """Test rank prediction for low score."""
        rank = self.leaderboard.predict_rank(0.2, total_competitors=100)

        self.assertGreater(rank, 80)
        self.assertLessEqual(rank, 100)

    def test_predict_rank_edge_cases(self):
        """Test rank prediction at boundaries."""
        # Perfect score (>=0.8) -> top 5%
        rank = self.leaderboard.predict_rank(1.0, total_competitors=100)
        self.assertLessEqual(rank, 5)  # Top 5%

        # Zero score (<0.3) -> bottom 5%
        rank = self.leaderboard.predict_rank(0.0, total_competitors=100)
        self.assertGreater(rank, 90)  # Bottom 5%


class TestBenchmarkComparison(unittest.TestCase):
    """Tests for benchmark comparison."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.leaderboard = KaggleLeaderboard(data_dir=self.temp_dir)

    def tearDown(self):
        """Clean up test fixtures."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_compare_to_benchmarks(self):
        """Test comparison to known benchmarks."""
        comparisons = self.leaderboard.compare_to_benchmarks(0.75)

        self.assertIn('gpt_4', comparisons)
        self.assertIn('claude_3_opus', comparisons)
        self.assertIn('human_expert', comparisons)

        # Check structure
        for benchmark, comp in comparisons.items():
            self.assertIn('benchmark_score', comp)
            self.assertIn('difference', comp)
            self.assertIn('status', comp)
            self.assertIn(comp['status'], ['above', 'below', 'similar'])

    def test_compare_status_above(self):
        """Test 'above' status determination."""
        # Above GPT-4 (0.75 benchmark)
        comparisons = self.leaderboard.compare_to_benchmarks(0.80)

        self.assertEqual(comparisons['gpt_4']['status'], 'above')
        self.assertGreater(comparisons['gpt_4']['difference'], 0)

    def test_compare_status_below(self):
        """Test 'below' status determination."""
        # Below baseline_heuristic (0.3)
        comparisons = self.leaderboard.compare_to_benchmarks(0.2)

        self.assertEqual(comparisons['baseline_heuristic']['status'], 'below')
        self.assertLess(comparisons['baseline_heuristic']['difference'], 0)

    def test_compare_status_similar(self):
        """Test 'similar' status determination."""
        # Very close to benchmark (within 0.05)
        comparisons = self.leaderboard.compare_to_benchmarks(0.50)

        self.assertEqual(comparisons['small_language_model']['status'], 'similar')
        self.assertLessEqual(abs(comparisons['small_language_model']['difference']), 0.05)


class TestLeaderboardDisplay(unittest.TestCase):
    """Tests for leaderboard display functionality."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.leaderboard = KaggleLeaderboard(data_dir=self.temp_dir)

    def tearDown(self):
        """Clean up test fixtures."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_print_leaderboard_prediction(self):
        """Test printing leaderboard prediction."""
        summary = SubmissionSummary(
            filename="test_submission.csv",
            total_items=100,
            mean_score=0.75,
            min_score=0.50,
            max_score=0.95,
            std_score=0.10,
            per_track_scores={'thlp': 0.80, 'tmp': 0.70},
            timestamp="2026-03-25 12:00:00"
        )

        # Just verify it doesn't raise exception
        # The print_leaderboard_prediction method prints to stdout
        # We can't easily capture it without mock, so just verify no exception
        try:
            self.leaderboard.print_leaderboard_prediction(summary, total_competitors=100)
            printed_successfully = True
        except Exception:
            printed_successfully = False

        self.assertTrue(printed_successfully, "Should print without errors")


class TestLeaderboardEntry(unittest.TestCase):
    """Tests for LeaderboardEntry dataclass."""

    def test_entry_creation(self):
        """Test creating a leaderboard entry."""
        entry = LeaderboardEntry(
            rank=1,
            team_name="Trinity Team",
            score=0.82,
            submission_date="2026-03-25"
        )

        self.assertEqual(entry.rank, 1)
        self.assertEqual(entry.team_name, "Trinity Team")
        self.assertEqual(entry.score, 0.82)

    def test_entry_sorting(self):
        """Test entries can be sorted by score."""
        entries = [
            LeaderboardEntry(1, "Team A", 0.75, "2026-03-20"),
            LeaderboardEntry(2, "Team B", 0.85, "2026-03-21"),
            LeaderboardEntry(3, "Team C", 0.65, "2026-03-22"),
        ]

        sorted_entries = sorted(entries, key=lambda e: e.score, reverse=True)

        self.assertEqual(sorted_entries[0].team_name, "Team B")
        self.assertEqual(sorted_entries[1].team_name, "Team A")
        self.assertEqual(sorted_entries[2].team_name, "Team C")


class TestHistoricalLeaderboard(unittest.TestCase):
    """Tests for historical leaderboard functionality."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.leaderboard = KaggleLeaderboard(data_dir=self.temp_dir)

    def tearDown(self):
        """Clean up test fixtures."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_get_sample_leaderboard(self):
        """Test getting sample leaderboard when no file exists."""
        entries = self.leaderboard.get_historical_leaderboard()

        self.assertIsInstance(entries, list)
        self.assertGreater(len(entries), 0)
        self.assertIsInstance(entries[0], LeaderboardEntry)

    def test_get_leaderboard_from_file(self):
        """Test loading leaderboard from JSON file."""
        leaderboard_path = Path(self.temp_dir) / "leaderboard.json"
        import json

        test_data = {
            "entries": [
                {"rank": 1, "team_name": "Team A", "score": 0.9, "submission_date": "2026-03-20"},
                {"rank": 2, "team_name": "Team B", "score": 0.8, "submission_date": "2026-03-21"},
            ]
        }

        with open(leaderboard_path, 'w') as f:
            json.dump(test_data, f)

        entries = self.leaderboard.get_historical_leaderboard(leaderboard_path=leaderboard_path)

        self.assertEqual(len(entries), 2)
        self.assertEqual(entries[0].team_name, "Team A")
        self.assertEqual(entries[1].score, 0.8)


def run_tests():
    """Run all tests and return exit code."""
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(run_tests())
