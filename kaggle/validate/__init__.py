#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Dataset Validation Checks

Validates generated datasets for:
- Question diversity (semantic similarity)
- Difficulty gradient (φ-scaling verification)
- Data leakage (train/test contamination)
- Format compliance (CSV schema)
"""

import os
import sys
import json
import csv
import argparse
from pathlib import Path
from typing import List, Dict, Set, Tuple, Optional
from dataclasses import dataclass
from collections import Counter
import math


@dataclass
class ValidationIssue:
    """A validation issue found."""
    severity: str  # "error", "warning", "info"
    category: str
    message: str
    location: str  # file:row or similar
    suggestion: Optional[str] = None


@dataclass
class ValidationResult:
    """Result of validation."""
    is_valid: bool
    issues: List[ValidationIssue]
    stats: Dict

    def print_report(self):
        """Print validation report."""
        print("\n" + "="*60)
        print("VALIDATION REPORT")
        print("="*60)

        if self.is_valid:
            print("✅ PASSED")
        else:
            print("❌ FAILED")

        print(f"\nIssues found: {len(self.issues)}")

        # Group by severity
        by_severity = {"error": [], "warning": [], "info": []}
        for issue in self.issues:
            by_severity[issue.severity].append(issue)

        for severity in ["error", "warning", "info"]:
            issues = by_severity[severity]
            if issues:
                print(f"\n{severity.upper()} ({len(issues)}):")
                for issue in issues[:10]:  # Limit output
                    print(f"  [{issue.category}] {issue.message}")
                    if issue.location:
                        print(f"    at {issue.location}")
                    if issue.suggestion:
                        print(f"    💡 {issue.suggestion}")
                if len(issues) > 10:
                    print(f"  ... and {len(issues) - 10} more")

        print("\n" + "="*60 + "\n")


class DiversityValidator:
    """Validates question diversity using semantic analysis."""

    def __init__(self, similarity_threshold: float = 0.8):
        """
        Initialize the validator.

        Args:
            similarity_threshold: Threshold for flagging similar questions
        """
        self.similarity_threshold = similarity_threshold

    def validate(self, questions: List[str], ids: List[str] = None) -> ValidationResult:
        """
        Check for question diversity.

        Args:
            questions: List of question text
            ids: Optional list of question IDs

        Returns:
            ValidationResult
        """
        issues = []
        ids = ids or [f"q_{i}" for i in range(len(questions))]

        # Check for exact duplicates
        seen: Dict[str, List[str]] = {}
        for q, qid in zip(questions, ids):
            q_norm = q.strip().lower()
            if q_norm not in seen:
                seen[q_norm] = []
            seen[q_norm].append(qid)

        for q_norm, qids in seen.items():
            if len(qids) > 1:
                issues.append(ValidationIssue(
                    severity="error",
                    category="duplicate",
                    message=f"Duplicate question: {q_norm[:50]}...",
                    location=f"items: {', '.join(qids)}",
                    suggestion="Remove duplicate questions or add variation"
                ))

        # Check for near-duplicates using simple word overlap
        # (In production, would use embeddings)
        for i, (q1, id1) in enumerate(zip(questions, ids)):
            for q2, id2 in zip(questions[i+1:], ids[i+1:]):
                similarity = self._word_overlap_similarity(q1, q2)
                if similarity >= self.similarity_threshold:
                    issues.append(ValidationIssue(
                        severity="warning",
                        category="near_duplicate",
                        message=f"Questions {similarity:.1%} similar: {q1[:30]}... vs {q2[:30]}...",
                        location=f"{id1} vs {id2}",
                        suggestion="Consider adding more variation between questions"
                    ))

        # Check vocabulary diversity
        all_words = set()
        for q in questions:
            words = set(q.lower().split())
            all_words.update(words)

        unique_ratio = len(all_words) / max(sum(len(q.split()) for q in questions), 1)

        if unique_ratio < 0.3:
            issues.append(ValidationIssue(
                severity="warning",
                category="low_vocabulary_diversity",
                message=f"Low vocabulary diversity: {unique_ratio:.1%} unique words",
                location="dataset",
                suggestion="Add more variety to question wording"
            ))

        stats = {
            "total_questions": len(questions),
            "exact_duplicates": sum(1 for v in seen.values() if len(v) > 1),
            "unique_words": len(all_words),
            "vocabulary_diversity": unique_ratio
        }

        return ValidationResult(
            is_valid=not any(i.severity == "error" for i in issues),
            issues=issues,
            stats=stats
        )

    def _word_overlap_similarity(self, q1: str, q2: str) -> float:
        """Calculate word overlap similarity (Jaccard)."""
        words1 = set(q1.lower().split())
        words2 = set(q2.lower().split())

        if not words1 or not words2:
            return 0.0

        intersection = words1 & words2
        union = words1 | words2

        return len(intersection) / len(union) if union else 0.0


class DifficultyValidator:
    """Validates φ-scaling difficulty gradient."""

    PHI = (1 + math.sqrt(5)) / 2
    FIBONACCI = [3, 5, 8, 13, 21]

    def validate(self, difficulties: List[float], ids: List[str] = None) -> ValidationResult:
        """
        Validate difficulty scores follow φ-scaling pattern.

        Args:
            difficulties: List of difficulty scores
            ids: Optional list of item IDs

        Returns:
            ValidationResult
        """
        issues = []
        ids = ids or [f"d_{i}" for i in range(len(difficulties))]

        # Check for negative difficulties
        for i, (d, did) in enumerate(zip(difficulties, ids)):
            if d < 0:
                issues.append(ValidationIssue(
                    severity="error",
                    category="negative_difficulty",
                    message=f"Negative difficulty: {d}",
                    location=did
                ))

        # Check difficulty range
        min_d = min(difficulties)
        max_d = max(difficulties)

        if max_d > 100:
            issues.append(ValidationIssue(
                severity="warning",
                category="extreme_difficulty",
                message=f"Maximum difficulty very high: {max_d}",
                location="dataset",
                suggestion="Verify φ-scaling calculation"
            ))

        # Check for φ-scaling distribution
        # Expected: values should cluster around Fibonacci * PHI^n
        expected_ranges = [
            (0, 5),      # Level 0: ~3
            (5, 10),     # Level 1: ~5-6
            (10, 20),    # Level 2: ~8-13
            (20, 40),    # Level 3: ~13-21
            (40, 100)    # Level 4: ~21-34
        ]

        distribution = [0] * 5
        for d in difficulties:
            for i, (low, high) in enumerate(expected_ranges):
                if low <= d < high:
                    distribution[i] += 1
                    break

        # Check that distribution is not too skewed
        total = sum(distribution)
        if total > 0:
            max_ratio = max(distribution) / total
            if max_ratio > 0.8:
                issues.append(ValidationIssue(
                    severity="warning",
                    category="skewed_distribution",
                    message=f"Difficulty distribution skewed: {max_ratio:.1%} in one range",
                    location="dataset",
                    suggestion="Ensure items across all difficulty levels"
                ))

        # Check for monotonic progression in sorted order
        sorted_difficulties = sorted(difficulties)
        gaps = []
        for i in range(len(sorted_difficulties) - 1):
            gap = sorted_difficulties[i+1] - sorted_difficulties[i]
            gaps.append(gap)

        if gaps:
            avg_gap = sum(gaps) / len(gaps)
            if avg_gap < 0.1:
                issues.append(ValidationIssue(
                    severity="info",
                    category="low_difficulty_variance",
                    message=f"Low difficulty variance: avg gap {avg_gap:.3f}",
                    location="dataset",
                    suggestion="Items may not cover a good difficulty range"
                ))

        stats = {
            "min_difficulty": min_d,
            "max_difficulty": max_d,
            "mean_difficulty": sum(difficulties) / len(difficulties),
            "distribution": distribution
        }

        return ValidationResult(
            is_valid=not any(i.severity == "error" for i in issues),
            issues=issues,
            stats=stats
        )


class LeakageValidator:
    """Validates no data leakage between splits."""

    def validate(
        self,
        train_items: List[Dict],
        test_items: List[Dict],
        key_fields: List[str] = None
    ) -> ValidationResult:
        """
        Check for data leakage between train and test sets.

        Args:
            train_items: Training set items
            test_items: Test set items
            key_fields: Fields to compare for leakage

        Returns:
            ValidationResult
        """
        issues = []
        key_fields = key_fields or ["question", "ground_truth"]

        # Create keys for train items
        train_keys = set()
        for item in train_items:
            key = self._make_key(item, key_fields)
            train_keys.add(key)

        # Check test items against train
        leaked = []
        for item in test_items:
            key = self._make_key(item, key_fields)
            if key in train_keys:
                leaked.append(item.get("id", "unknown"))

        if leaked:
            issues.append(ValidationIssue(
                severity="error",
                category="data_leakage",
                message=f"{len(leaked)} test items found in training set",
                location=f"items: {', '.join(leaked[:5])}",
                suggestion="Remove duplicate items from train/test split"
            ))

        # Check for near-leakage (very similar questions)
        if len(train_items) > 0 and len(test_items) > 0:
            train_questions = [item.get("question", "") for item in train_items]
            test_questions = [item.get("question", "") for item in test_items]

            # Sample check (would use embeddings in production)
            sample_size = min(100, len(test_questions))
            for i, test_q in enumerate(test_questions[:sample_size]):
                for train_q in train_questions[:sample_size]:
                    similarity = self._word_overlap_similarity(test_q, train_q)
                    if similarity > 0.9:
                        issues.append(ValidationIssue(
                            severity="warning",
                            category="near_leakage",
                            message=f"Very similar questions: {test_q[:30]}... vs {train_q[:30]}...",
                            location=f"test item {i}",
                            suggestion="Review similar items for potential leakage"
                        ))

        stats = {
            "train_size": len(train_items),
            "test_size": len(test_items),
            "leaked_items": len(leaked)
        }

        return ValidationResult(
            is_valid=len(leaked) == 0,
            issues=issues,
            stats=stats
        )

    def _make_key(self, item: Dict, fields: List[str]) -> str:
        """Create a key for comparison."""
        parts = []
        for field in fields:
            value = item.get(field, "")
            parts.append(str(value).strip().lower())
        return "|".join(parts)

    def _word_overlap_similarity(self, q1: str, q2: str) -> float:
        """Calculate word overlap similarity."""
        words1 = set(q1.lower().split())
        words2 = set(q2.lower().split())

        if not words1 or not words2:
            return 0.0

        intersection = words1 & words2
        union = words1 | words2

        return len(intersection) / len(union) if union else 0.0


class FormatValidator:
    """Validates CSV format compliance."""

    REQUIRED_COLUMNS = {
        "thlp_learning.csv": ["id", "task", "question", "answer", "ground_truth_confidence", "difficulty", "brain_zone", "neural_analog"],
        "tmp_metacognition.csv": ["id", "task", "question", "answer", "ground_truth_confidence", "difficulty", "brain_zone", "neural_analog"],
        "tagp_attention.csv": ["id", "task", "context", "query", "distractor_count", "expected_focus", "difficulty", "brain_zone", "neural_analog"],
        "tefb_executive.csv": ["id", "task", "context", "actions_needed", "constraints", "expected_result", "difficulty", "brain_zone", "neural_analog"],
        "tscp_social.csv": ["id", "task", "scenario", "perspective", "expected_inference", "difficulty", "brain_zone", "neural_analog"]
    }

    def validate(self, csv_path: str) -> ValidationResult:
        """
        Validate CSV file format.

        Args:
            csv_path: Path to CSV file

        Returns:
            ValidationResult
        """
        issues = []
        filename = Path(csv_path).name

        # Check file exists
        if not Path(csv_path).exists():
            return ValidationResult(
                is_valid=False,
                issues=[ValidationIssue(
                    severity="error",
                    category="file_not_found",
                    message=f"File not found: {csv_path}",
                    location=csv_path
                )],
                stats={}
            )

        # Read and validate
        try:
            with open(csv_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                rows = list(reader)

            # Check required columns
            required = self.REQUIRED_COLUMNS.get(filename, [])
            if required:
                actual_columns = set(reader.fieldnames)
                missing = set(required) - actual_columns

                if missing:
                    issues.append(ValidationIssue(
                        severity="error",
                        category="missing_columns",
                        message=f"Missing required columns: {', '.join(missing)}",
                        location=filename,
                        suggestion=f"Add columns: {', '.join(missing)}"
                    ))

            # Validate each row
            for i, row in enumerate(rows):
                row_id = row.get('id', f'row_{i}')

                # Check required fields are not empty
                for col in required:
                    if col in row and not row[col].strip():
                        issues.append(ValidationIssue(
                            severity="error",
                            category="empty_field",
                            message=f"Empty required field: {col}",
                            location=f"{filename}:{row_id}"
                        ))

                # Validate numeric fields
                if 'difficulty' in row and row['difficulty']:
                    try:
                        d = float(row['difficulty'])
                        if d < 0:
                            issues.append(ValidationIssue(
                                severity="error",
                                category="invalid_value",
                                message=f"Negative difficulty: {d}",
                                location=f"{filename}:{row_id}"
                            ))
                    except ValueError:
                        issues.append(ValidationIssue(
                            severity="error",
                            category="invalid_value",
                            message=f"Invalid difficulty value: {row['difficulty']}",
                            location=f"{filename}:{row_id}"
                        ))

                if 'ground_truth_confidence' in row and row['ground_truth_confidence']:
                    try:
                        c = float(row['ground_truth_confidence'])
                        if not 0 <= c <= 1:
                            issues.append(ValidationIssue(
                                severity="warning",
                                category="invalid_value",
                                message=f"Confidence out of range [0,1]: {c}",
                                location=f"{filename}:{row_id}"
                            ))
                    except ValueError:
                        pass

            stats = {
                "total_rows": len(rows),
                "columns": reader.fieldnames,
                "has_required_columns": not bool(missing)
            }

        except Exception as e:
            issues.append(ValidationIssue(
                severity="error",
                category="read_error",
                message=f"Failed to read CSV: {e}",
                location=csv_path
            ))
            stats = {}

        return ValidationResult(
            is_valid=not any(i.severity == "error" for i in issues),
            issues=issues,
            stats=stats
        )


def validate_all(data_dir: str) -> Dict[str, ValidationResult]:
    """
    Run all validation checks on all datasets.

    Args:
        data_dir: Directory containing CSV files

    Returns:
        Dict mapping filename to ValidationResult
    """
    data_path = Path(data_dir)

    if not data_path.exists():
        print(f"Error: Data directory not found: {data_dir}")
        return {}

    results = {}

    # Validate each CSV file
    csv_files = [
        "thlp_learning.csv",
        "tmp_metacognition.csv",
        "tagp_attention.csv",
        "tefb_executive.csv",
        "tscp_social.csv"
    ]

    validators = {
        "format": FormatValidator(),
        "diversity": DiversityValidator(),
        "difficulty": DifficultyValidator()
    }

    for csv_file in csv_files:
        csv_path = data_path / csv_file

        if not csv_path.exists():
            print(f"⚠️  File not found: {csv_file}")
            continue

        print(f"\nValidating {csv_file}...")

        # Format validation
        format_result = validators["format"].validate(str(csv_path))
        results[f"{csv_file}:format"] = format_result

        # Load data for other validations
        try:
            with open(csv_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                rows = list(reader)

            questions = [row.get('question', row.get('context', row.get('scenario', ''))) for row in rows]
            ids = [row.get('id', f'q_{i}') for i in range(len(rows))]
            difficulties = [float(row.get('difficulty', 3.0)) for row in rows]

            # Diversity validation
            diversity_result = validators["diversity"].validate(questions, ids)
            results[f"{csv_file}:diversity"] = diversity_result

            # Difficulty validation
            difficulty_result = validators["difficulty"].validate(difficulties, ids)
            results[f"{csv_file}:difficulty"] = difficulty_result

        except Exception as e:
            print(f"  Error loading data: {e}")

    return results


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Trinity Cognitive Probes — Dataset Validation"
    )

    parser.add_argument(
        "--data-dir",
        default="../data",
        help="Data directory"
    )
    parser.add_argument(
        "--check",
        choices=["all", "format", "diversity", "difficulty", "leakage"],
        default="all",
        help="Validation check to run"
    )
    parser.add_argument(
        "--file",
        help="Specific file to validate"
    )

    args = parser.parse_args()

    print("="*60)
    print("TRINITY COGNITIVE PROBES — DATASET VALIDATION")
    print("="*60)

    if args.file:
        # Validate single file
        validator = FormatValidator()
        result = validator.validate(args.file)
        result.print_report()
    else:
        # Validate all files
        results = validate_all(args.data_dir)

        # Print summary
        print("\n" + "="*60)
        print("SUMMARY")
        print("="*60)

        passed = sum(1 for r in results.values() if r.is_valid)
        total = len(results)

        print(f"Passed: {passed}/{total}")

        for name, result in results.items():
            status = "✅" if result.is_valid else "❌"
            print(f"  {status} {name}: {len(result.issues)} issues")

        print("="*60 + "\n")


if __name__ == "__main__":
    main()
