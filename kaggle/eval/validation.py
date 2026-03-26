# kaggle/eval/validation.py
"""
Submission Validation Module for DeepMind AGI Hackathon

Validates submission CSV format before Kaggle upload to prevent
disqualification due to format errors.

Author: Trinity Project
Date: 2026-03-26
"""

from dataclasses import dataclass, field
from typing import List, Dict, Any, Optional
from pathlib import Path
import pandas as pd
import numpy as np


@dataclass
class ValidationIssue:
    """A single validation issue."""
    severity: str  # 'error', 'warning', 'info'
    category: str  # 'columns', 'rows', 'values', 'ids', 'format'
    message: str
    location: Optional[str] = None  # e.g., row index, column name


@dataclass
class ValidationReport:
    """Complete validation report."""
    passed: bool
    total_rows: int
    issues: List[ValidationIssue] = field(default_factory=list)
    warnings: List[ValidationIssue] = field(default_factory=list)
    info: List[ValidationIssue] = field(default_factory=list)

    def add_error(self, category: str, message: str, location: str = None):
        self.issues.append(ValidationIssue(
            severity='error', category=category, message=message, location=location
        ))
        self.passed = False

    def add_warning(self, category: str, message: str, location: str = None):
        self.warnings.append(ValidationIssue(
            severity='warning', category=category, message=message, location=location
        ))

    def add_info(self, category: str, message: str, location: str = None):
        self.info.append(ValidationIssue(
            severity='info', category=category, message=message, location=location
        ))

    def print_summary(self):
        """Print validation summary to console."""
        print("\n" + "="*60)
        print("SUBMISSION VALIDATION REPORT")
        print("="*60)

        status = "✅ PASSED" if self.passed else "❌ FAILED"
        print(f"\nStatus: {status}")
        print(f"Total Rows: {self.total_rows}")

        if self.issues:
            print(f"\n❌ ERRORS ({len(self.issues)}):")
            for issue in self.issues:
                loc = f" [{issue.location}]" if issue.location else ""
                print(f"  - [{issue.category}] {issue.message}{loc}")

        if self.warnings:
            print(f"\n⚠️  WARNINGS ({len(self.warnings)}):")
            for issue in self.warnings:
                loc = f" [{issue.location}]" if issue.location else ""
                print(f"  - [{issue.category}] {issue.message}{loc}")

        if self.info:
            print(f"\nℹ️  INFO ({len(self.info)}):")
            for issue in self.info:
                loc = f" [{issue.location}]" if issue.location else ""
                print(f"  - [{issue.category}] {issue.message}{loc}")

        print("="*60 + "\n")


class SubmissionValidator:
    """
    Validates Kaggle submission CSV format.

    Required format:
        id,confidence,answer,track
        item_001,0.85,A,thlp
        item_002,0.72,B,tmp
        ...

    Rules:
        - Columns: id, confidence, answer, track (required)
        - Rows: 11,400 expected (5 tracks × ~2200-2400 items each)
        - Confidence: float in [0.0, 1.0]
        - Answer: single choice (A, B, C, D, or similar)
        - Track: one of [thlp, tmp, tagp, tefb, tscp]
        - IDs: unique, non-empty strings
    """

    REQUIRED_COLS = ['id', 'confidence', 'answer', 'track']
    VALID_TRACKS = {'thlp', 'tmp', 'tagp', 'tefb', 'tscp'}
    CONFIDENCE_RANGE = (0.0, 1.0)
    EXPECTED_ROWS = 11400
    MIN_ROWS = 11000  # Allow some tolerance

    def __init__(self, expected_rows: int = None):
        """
        Initialize validator.

        Args:
            expected_rows: Expected number of rows (default: 11400)
        """
        self.expected_rows = expected_rows or self.EXPECTED_ROWS

    def validate(self, csv_path: str) -> ValidationReport:
        """
        Validate submission CSV file.

        Args:
            csv_path: Path to submission CSV file

        Returns:
            ValidationReport with validation results
        """
        report = ValidationReport(passed=True, total_rows=0)

        # Check file exists
        path = Path(csv_path)
        if not path.exists():
            report.add_error('file', f"File not found: {csv_path}")
            return report

        # Load CSV
        try:
            df = pd.read_csv(csv_path)
        except Exception as e:
            report.add_error('format', f"Failed to parse CSV: {e}")
            return report

        report.total_rows = len(df)
        report.add_info('rows', f"Loaded {len(df)} rows from {csv_path}")

        # Validate columns
        self._validate_columns(df, report)

        # Validate row count
        self._validate_row_count(df, report)

        # Validate IDs
        self._validate_ids(df, report)

        # Validate confidence values
        self._validate_confidence(df, report)

        # Validate answer values
        self._validate_answers(df, report)

        # Validate track values
        self._validate_tracks(df, report)

        # Track distribution check
        self._validate_track_distribution(df, report)

        return report

    def _validate_columns(self, df: pd.DataFrame, report: ValidationReport):
        """Validate required columns exist."""
        missing_cols = set(self.REQUIRED_COLS) - set(df.columns)
        extra_cols = set(df.columns) - set(self.REQUIRED_COLS)

        if missing_cols:
            report.add_error('columns', f"Missing columns: {missing_cols}")
        if extra_cols:
            report.add_warning('columns', f"Extra columns (will be ignored): {extra_cols}")

        # Check column order (info only)
        if list(df.columns[:4]) != self.REQUIRED_COLS:
            report.add_info('columns', f"Column order differs from expected: {self.REQUIRED_COLS}")

    def _validate_row_count(self, df: pd.DataFrame, report: ValidationReport):
        """Validate row count."""
        n = len(df)

        if n < self.MIN_ROWS:
            report.add_error('rows', f"Row count {n} < minimum {self.MIN_ROWS}")
        elif n < self.expected_rows:
            report.add_warning('rows', f"Row count {n} < expected {self.expected_rows}")
        elif n > self.expected_rows + 100:
            report.add_warning('rows', f"Row count {n} > expected {self.expected_rows} (excess)")
        else:
            report.add_info('rows', f"Row count {n} within expected range")

    def _validate_ids(self, df: pd.DataFrame, report: ValidationReport):
        """Validate ID column."""
        if 'id' not in df.columns:
            return

        # Check for empty IDs
        empty_ids = df['id'].isna().sum()
        if empty_ids > 0:
            report.add_error('ids', f"{empty_ids} empty/null IDs found")

        # Check for duplicates
        duplicates = df['id'].duplicated().sum()
        if duplicates > 0:
            report.add_error('ids', f"{duplicates} duplicate IDs found")
            dup_examples = df[df['id'].duplicated()]['id'].head(3).tolist()
            report.add_warning('ids', f"Duplicate ID examples: {dup_examples}")

        # Check ID format (info only)
        if df['id'].dtype == 'object':
            unique_prefixes = df['id'].str[:5].unique()[:3]
            report.add_info('ids', f"ID format samples: {unique_prefixes.tolist()}")

    def _validate_confidence(self, df: pd.DataFrame, report: ValidationReport):
        """Validate confidence column."""
        if 'confidence' not in df.columns:
            return

        # Check for null values
        null_conf = df['confidence'].isna().sum()
        if null_conf > 0:
            report.add_error('values', f"{null_conf} null confidence values")

        # Check range
        try:
            conf = pd.to_numeric(df['confidence'], errors='coerce')
            out_of_range = (~conf.between(*self.CONFIDENCE_RANGE)).sum()

            if out_of_range > 0:
                report.add_error('values', f"{out_of_range} confidence values outside [0, 1]")
                # Find examples
                bad = df[~conf.between(*self.CONFIDENCE_RANGE)].head(3)
                for idx, row in bad.iterrows():
                    report.add_warning('values', f"  Row {idx}: confidence={row['confidence']}", location=str(idx))
        except Exception as e:
            report.add_error('values', f"Failed to validate confidence values: {e}")

        # Confidence distribution (info)
        try:
            conf_numeric = pd.to_numeric(df['confidence'], errors='coerce')
            if not conf_numeric.isna().all():
                report.add_info('values', f"Confidence: mean={conf_numeric.mean():.3f}, std={conf_numeric.std():.3f}")
        except:
            pass

    def _validate_answers(self, df: pd.DataFrame, report: ValidationReport):
        """Validate answer column."""
        if 'answer' not in df.columns:
            return

        # Check for null values
        null_ans = df['answer'].isna().sum()
        if null_ans > 0:
            report.add_error('values', f"{null_ans} null answer values")

        # Check answer distribution
        if df['answer'].dtype == 'object':
            value_counts = df['answer'].value_counts()
            report.add_info('values', f"Answer distribution: {dict(value_counts.head(5))}")

            # Check for suspicious patterns
            if len(value_counts) == 1:
                report.add_warning('values', "All answers are the same value!")

    def _validate_tracks(self, df: pd.DataFrame, report: ValidationReport):
        """Validate track column."""
        if 'track' not in df.columns:
            return

        # Check for null values
        null_tracks = df['track'].isna().sum()
        if null_tracks > 0:
            report.add_error('values', f"{null_tracks} null track values")

        # Check for invalid track names
        invalid = df[~df['track'].isin(self.VALID_TRACKS) & df['track'].notna()]
        if len(invalid) > 0:
            invalid_values = invalid['track'].unique().tolist()
            report.add_error('values', f"Invalid track values: {invalid_values}")
            report.add_error('values', f"Valid tracks: {self.VALID_TRACKS}")

    def _validate_track_distribution(self, df: pd.DataFrame, report: ValidationReport):
        """Validate track distribution is reasonable."""
        if 'track' not in df.columns:
            return

        track_counts = df['track'].value_counts()
        report.add_info('distribution', f"Track distribution: {dict(track_counts)}")

        # Check each track has reasonable count
        expected_per_track = self.expected_rows // len(self.VALID_TRACKS)
        for track in self.VALID_TRACKS:
            count = track_counts.get(track, 0)
            if count == 0:
                report.add_error('distribution', f"Track '{track}' has no items!")
            elif count < expected_per_track // 2:
                report.add_warning('distribution', f"Track '{track}' has only {count} items (expected ~{expected_per_track})")


def validate_submission(csv_path: str, expected_rows: int = None) -> bool:
    """
    Quick validation function.

    Args:
        csv_path: Path to submission CSV
        expected_rows: Expected row count (default: 11400)

    Returns:
        True if validation passed, False otherwise
    """
    validator = SubmissionValidator(expected_rows=expected_rows)
    report = validator.validate(csv_path)
    report.print_summary()
    return report.passed


def validate_and_fix(csv_path: str, output_path: str = None) -> pd.DataFrame:
    """
    Validate submission and attempt to fix common issues.

    Args:
        csv_path: Path to submission CSV
        output_path: Path to save fixed CSV (optional)

    Returns:
        Fixed DataFrame (or original if unfixable)
    """
    validator = SubmissionValidator()
    report = validator.validate(csv_path)
    report.print_summary()

    if report.passed:
        print("✅ Submission is valid! No fixes needed.")
        return pd.read_csv(csv_path)

    print("⚠️  Attempting to fix issues...")

    df = pd.read_csv(csv_path)

    # Fix: Drop duplicate IDs (keep first)
    if 'id' in df.columns and df['id'].duplicated().any():
        before = len(df)
        df = df.drop_duplicates(subset=['id'], keep='first')
        print(f"  Fixed: Dropped {before - len(df)} duplicate IDs")

    # Fix: Clip confidence to [0, 1]
    if 'confidence' in df.columns:
        try:
            conf = pd.to_numeric(df['confidence'], errors='coerce')
            out_of_range = (~conf.between(0, 1)).sum()
            if out_of_range > 0:
                df['confidence'] = conf.clip(0, 1)
                print(f"  Fixed: Clipped {out_of_range} confidence values to [0, 1]")
        except:
            pass

    # Save fixed version
    if output_path:
        df.to_csv(output_path, index=False)
        print(f"  Saved fixed submission to: {output_path}")

    return df


# CLI entrypoint
if __name__ == '__main__':
    import sys

    if len(sys.argv) < 2:
        print("Usage: python -m kaggle.eval.validation <submission.csv>")
        print("       python -m kaggle.eval.validation <submission.csv> --fix")
        sys.exit(1)

    csv_path = sys.argv[1]

    if '--fix' in sys.argv:
        output_path = csv_path.replace('.csv', '_fixed.csv')
        validate_and_fix(csv_path, output_path)
    else:
        passed = validate_submission(csv_path)
        sys.exit(0 if passed else 1)
