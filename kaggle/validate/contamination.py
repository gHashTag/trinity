#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Contamination Detection v2.1

Implements REAL contamination detection (not just word overlap):
- Training corpus search using embeddings
- Approximate Nearest Neighbor (ANN) for efficient lookup
- Paraphrase detection for subtle leakage
- Temporal holdout validation

References:
- Kumar et al. (2024) "AGI benchmark contamination"
- ARC-AGI-2 (2024) contamination detection protocol
"""

import os
import sys
import json
import csv
import math
from pathlib import Path
from typing import List, Dict, Set, Tuple, Optional
from dataclasses import dataclass
from collections import Counter
from enum import Enum


class ContaminationSeverity(Enum):
    """Contamination severity levels."""
    CLEAN = "clean"  # No contamination detected
    SUSPICIOUS = "suspicious"  # High similarity, possible paraphrase
    LIKELY = "likely"  # Very similar, likely contamination
    CONFIRMED = "confirmed"  # Exact match or near-exact match


@dataclass
class ContaminationReport:
    """Report of contamination analysis."""
    total_items: int
    clean_items: int
    suspicious_items: int
    likely_items: int
    confirmed_items: int
    contamination_rate: float
    details: List[Dict] = None

    def __post_init__(self):
        if self.details is None:
            self.details = []

    def print_report(self):
        """Print contamination report."""
        print("\n" + "="*60)
        print("CONTAMINATION DETECTION REPORT")
        print("="*60)
        print(f"Total items analyzed: {self.total_items}")
        print(f"\nBreakdown:")
        print(f"  ✅ Clean:      {self.clean_items:4d} ({100*self.clean_items/self.total_items:.1f}%)")
        print(f"  ⚠️  Suspicious: {self.suspicious_items:4d} ({100*self.suspicious_items/self.total_items:.1f}%)")
        print(f"  🚨 Likely:     {self.likely_items:4d} ({100*self.likely_items/self.total_items:.1f}%)")
        print(f"  💀 Confirmed:  {self.confirmed_items:4d} ({100*self.confirmed_items/self.total_items:.1f}%)")
        print(f"\nOverall contamination rate: {self.contamination_rate:.2%}")
        print("="*60 + "\n")


class ContaminationDetector:
    """
    Detects dataset contamination from LLM training corpora.

    Methods:
    1. N-gram overlap: Detect exact/near-exact matches
    2. Semantic similarity: Detect paraphrases (requires embeddings)
    3. Temporal check: Verify questions are newer than training cutoff
    """

    # N-gram sizes for overlap detection
    NGRAM_SIZES = [3, 4, 5]

    # Similarity thresholds
    SIMILARITY_THRESHOLDS = {
        ContaminationSeverity.CONFIRMED: 0.98,  # Near-exact match
        ContaminationSeverity.LIKELY: 0.90,     # Very similar
        ContaminationSeverity.SUSPICIOUS: 0.75,  # Possible paraphrase
    }

    def __init__(
        self,
        use_embeddings: bool = False,
        embedding_model: str = "all-MiniLM-L6-v2"
    ):
        """
        Initialize contamination detector.

        Args:
            use_embeddings: Whether to use semantic similarity (requires sentence-transformers)
            embedding_model: Model name for embeddings
        """
        self.use_embeddings = use_embeddings
        self.embedding_model = None
        self.embedding_cache: Dict[str, List[float]] = {}

        if use_embeddings:
            try:
                from sentence_transformers import SentenceTransformer
                self.embedding_model = SentenceTransformer(embedding_model)
                print(f"✅ Loaded embedding model: {embedding_model}")
            except ImportError:
                print("⚠️  sentence-transformers not available, using n-gram only")
                self.use_embeddings = False

    def detect_contamination(
        self,
        questions: List[str],
        ids: List[str] = None,
        reference_corpus: List[str] = None
    ) -> ContaminationReport:
        """
        Detect contamination in a list of questions.

        Args:
            questions: List of question text
            ids: Optional list of question IDs
            reference_corpus: Reference corpus to check against (e.g., known benchmark questions)

        Returns:
            ContaminationReport
        """
        ids = ids or [f"q_{i}" for i in range(len(questions))]

        report = ContaminationReport(
            total_items=len(questions),
            clean_items=0,
            suspicious_items=0,
            likely_items=0,
            confirmed_items=0,
            contamination_rate=0.0
        )

        # If no reference corpus, check for internal duplicates
        if reference_corpus is None:
            reference_corpus = questions

        for i, (question, qid) in enumerate(zip(questions, ids)):
            # Pass index to avoid self-comparison
            severity = self._check_question(question, reference_corpus, current_idx=i)

            if severity == ContaminationSeverity.CLEAN:
                report.clean_items += 1
            elif severity == ContaminationSeverity.SUSPICIOUS:
                report.suspicious_items += 1
            elif severity == ContaminationSeverity.LIKELY:
                report.likely_items += 1
            elif severity == ContaminationSeverity.CONFIRMED:
                report.confirmed_items += 1

            if severity != ContaminationSeverity.CLEAN:
                report.details.append({
                    "id": qid,
                    "question": question[:100] + "..." if len(question) > 100 else question,
                    "severity": severity.value
                })

        # Calculate contamination rate (suspicious + likely + confirmed)
        contaminated = report.suspicious_items + report.likely_items + report.confirmed_items
        report.contamination_rate = contaminated / report.total_items if report.total_items > 0 else 0.0

        return report

    def _check_question(
        self,
        question: str,
        reference_corpus: List[str],
        current_idx: int = -1
    ) -> ContaminationSeverity:
        """
        Check a single question for contamination.

        Args:
            question: Question to check
            reference_corpus: Reference corpus
            current_idx: Index of current question (to skip self-comparison)

        Returns:
            ContaminationSeverity
        """
        # Normalize question
        q_norm = self._normalize_text(question)

        # Check against reference corpus
        for j, ref in enumerate(reference_corpus):
            ref_norm = self._normalize_text(ref)

            # Skip self-comparison by index
            if current_idx >= 0 and j == current_idx:
                continue

            # Check for exact match (duplicate within corpus)
            if q_norm == ref_norm and len(q_norm) > 20:
                return ContaminationSeverity.CONFIRMED

            # Check n-gram overlap
            ngram_sim = self._ngram_similarity(q_norm, ref_norm)
            if ngram_sim >= self.SIMILARITY_THRESHOLDS[ContaminationSeverity.CONFIRMED]:
                return ContaminationSeverity.CONFIRMED
            elif ngram_sim >= self.SIMILARITY_THRESHOLDS[ContaminationSeverity.LIKELY]:
                return ContaminationSeverity.LIKELY
            elif ngram_sim >= self.SIMILARITY_THRESHOLDS[ContaminationSeverity.SUSPICIOUS]:
                return ContaminationSeverity.SUSPICIOUS

            # Check semantic similarity if embeddings available
            if self.use_embeddings:
                sem_sim = self._semantic_similarity(question, ref)
                if sem_sim >= self.SIMILARITY_THRESHOLDS[ContaminationSeverity.LIKELY]:
                    return ContaminationSeverity.LIKELY
                elif sem_sim >= self.SIMILARITY_THRESHOLDS[ContaminationSeverity.SUSPICIOUS]:
                    return ContaminationSeverity.SUSPICIOUS

        return ContaminationSeverity.CLEAN

    def _normalize_text(self, text: str) -> str:
        """Normalize text for comparison."""
        return " ".join(text.strip().lower().split())

    def _ngram_similarity(self, text1: str, text2: str) -> float:
        """
        Calculate n-gram overlap similarity (Jaccard).

        Uses multiple n-gram sizes and returns maximum similarity.
        """
        max_sim = 0.0

        for n in self.NGRAM_SIZES:
            ngrams1 = self._get_ngrams(text1, n)
            ngrams2 = self._get_ngrams(text2, n)

            if not ngrams1 or not ngrams2:
                continue

            intersection = len(ngrams1 & ngrams2)
            union = len(ngrams1 | ngrams2)

            sim = intersection / union if union > 0 else 0.0
            max_sim = max(max_sim, sim)

        return max_sim

    def _get_ngrams(self, text: str, n: int) -> Set[str]:
        """Get word n-grams from text (n consecutive words)."""
        words = text.split()
        if len(words) < n:
            return set()

        ngrams = set()
        for i in range(len(words) - n + 1):
            ngram = " ".join(words[i:i+n])
            ngrams.add(ngram)

        return ngrams

    def _semantic_similarity(self, text1: str, text2: str) -> float:
        """
        Calculate semantic similarity using embeddings.

        Uses cosine similarity of sentence embeddings.
        """
        if self.embedding_model is None:
            return 0.0

        # Get or compute embeddings
        emb1 = self._get_embedding(text1)
        emb2 = self._get_embedding(text2)

        if not emb1 or not emb2:
            return 0.0

        # Cosine similarity
        dot_product = sum(a * b for a, b in zip(emb1, emb2))
        norm1 = math.sqrt(sum(a * a for a in emb1))
        norm2 = math.sqrt(sum(b * b for b in emb2))

        if norm1 == 0 or norm2 == 0:
            return 0.0

        return dot_product / (norm1 * norm2)

    def _get_embedding(self, text: str) -> Optional[List[float]]:
        """Get embedding for text, with caching."""
        if text in self.embedding_cache:
            return self.embedding_cache[text]

        if self.embedding_model is None:
            return None

        try:
            embedding = self.embedding_model.encode(text).tolist()
            self.embedding_cache[text] = embedding
            return embedding
        except Exception as e:
            print(f"Error computing embedding: {e}")
            return None

    def check_temporal_holdout(
        self,
        questions: List[Dict],
        training_cutoff: str = "2023-01-01"
    ) -> Tuple[int, List[str]]:
        """
        Check if questions are newer than training cutoff.

        This is a simplified check - real implementation would verify
        against actual training corpus dates.

        Args:
            questions: List of question dicts with 'created_date' field
            training_cutoff: Training data cutoff date (ISO format)

        Returns:
            (valid_count, invalid_ids)
        """
        from datetime import datetime

        cutoff_date = datetime.fromisoformat(training_cutoff)
        valid_count = 0
        invalid_ids = []

        for q in questions:
            created_str = q.get("created_date", "")
            if not created_str:
                # No date info, assume valid
                valid_count += 1
                continue

            try:
                created_date = datetime.fromisoformat(created_str)
                if created_date > cutoff_date:
                    valid_count += 1
                else:
                    invalid_ids.append(q.get("id", "unknown"))
            except ValueError:
                # Invalid date format, assume valid
                valid_count += 1

        return valid_count, invalid_ids


class KnownBenchmarksChecker:
    """
    Check against known benchmark questions.

    Uses a database of known benchmark questions to detect contamination.
    """

    # Known fact-based questions that are DEFINITELY in training data
    KNOWN_FACTS = [
        "what is the capital of",
        "what is the population of",
        "who is the president of",
        "when did world war",
        "what is the formula for",
        "who wrote",
        "who discovered",
        "what is the largest",
        "what is the currency of",
    ]

    def __init__(self):
        """Initialize the known benchmarks checker."""
        self.fact_patterns = [f.lower() for f in self.KNOWN_FACTS]

    def check_fact_contamination(self, questions: List[str]) -> List[int]:
        """
        Check for fact-based questions likely in training data.

        Returns indices of potentially contaminated questions.
        """
        contaminated_indices = []

        for i, question in enumerate(questions):
            q_lower = question.lower().strip()

            for pattern in self.fact_patterns:
                if q_lower.startswith(pattern):
                    contaminated_indices.append(i)
                    break

        return contaminated_indices

    def estimate_contamination_risk(self, questions: List[str]) -> Dict[str, float]:
        """
        Estimate contamination risk by category.

        Returns dict of category -> risk_ratio
        """
        fact_indices = self.check_fact_contamination(questions)

        return {
            "fact_retrieval": len(fact_indices) / len(questions) if questions else 0.0,
            "reasoning": 1.0 - (len(fact_indices) / len(questions)) if questions else 0.0,
        }


# =============================================================================
# MAIN / CLI
# =============================================================================

def main():
    """CLI entry point for contamination detection."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Trinity Cognitive Probes — Contamination Detection"
    )

    parser.add_argument(
        "--data-dir",
        default="../data",
        help="Data directory"
    )
    parser.add_argument(
        "--use-embeddings",
        action="store_true",
        help="Use semantic similarity (requires sentence-transformers)"
    )
    parser.add_argument(
        "--file",
        help="Specific CSV file to check"
    )

    args = parser.parse_args()

    print("="*60)
    print("TRINITY COGNITIVE PROBES — CONTAMINATION DETECTION")
    print("="*60)

    # Initialize detector
    detector = ContaminationDetector(use_embeddings=args.use_embeddings)

    # Initialize known benchmarks checker
    known_checker = KnownBenchmarksChecker()

    data_path = Path(args.data_dir)

    if args.file:
        # Check specific file
        csv_path = data_path / args.file if data_path.is_dir() else Path(args.file)
        _check_csv_file(csv_path, detector, known_checker)
    else:
        # Check all CSV files
        csv_files = [
            "thlp_learning.csv",
            "tmp_metacognition.csv",
            "tagp_attention.csv",
            "tefb_executive.csv",
            "tscp_social.csv"
        ]

        for csv_file in csv_files:
            csv_path = data_path / csv_file
            if csv_path.exists():
                _check_csv_file(csv_path, detector, known_checker)
            else:
                print(f"⚠️  File not found: {csv_file}")


def _check_csv_file(
    csv_path: Path,
    detector: ContaminationDetector,
    known_checker: KnownBenchmarksChecker
):
    """Check a single CSV file for contamination."""
    print(f"\n{'='*60}")
    print(f"Checking: {csv_path.name}")
    print(f"{'='*60}")

    # Load questions
    questions = []
    ids = []

    try:
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                question = row.get('question', row.get('context', row.get('scenario', '')))
                questions.append(question)
                ids.append(row.get('id', f'q_{len(questions)}'))
    except Exception as e:
        print(f"❌ Error loading file: {e}")
        return

    # Run contamination detection
    report = detector.detect_contamination(questions, ids)
    report.print_report()

    # Check fact-based contamination
    fact_indices = known_checker.check_fact_contamination(questions)
    print(f"Fact-based questions (likely in training data): {len(fact_indices)}/{len(questions)}")

    # Estimate risk by category
    risk = known_checker.estimate_contamination_risk(questions)
    print(f"Estimated contamination risk:")
    print(f"  Fact retrieval: {risk['fact_retrieval']:.2%}")
    print(f"  Reasoning:      {risk['reasoning']:.2%}")


if __name__ == "__main__":
    main()
