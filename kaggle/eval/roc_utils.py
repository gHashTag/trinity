#!/usr/bin/env python3
"""
Trinity Cognitive Probes — ROC/AUC Utilities

Utility functions for computing ROC curves and AUC metrics.
Used by CoDeC and other contamination detection methods.

Key functions:
- calculate_roc_auc: Proper ROC AUC using TPR/FPR curve
- calculate_tpr_fpr: Compute TPR/FPR at various thresholds
- auc_trapezoidal: Trapezoidal rule for AUC integration

Reference: Fawcett (2006) — "An introduction to ROC analysis"
"""

import math
from typing import List, Tuple, Optional
from dataclasses import dataclass


@dataclass
class ROCCurve:
    """ROC curve data."""
    tpr: List[float]  # True Positive Rate (Sensitivity)
    fpr: List[float]  # False Positive Rate (1 - Specificity)
    thresholds: List[float]
    auc: float  # Area Under Curve


def calculate_tpr_fpr(
    true_labels: List[bool],
    confidence_scores: List[float],
    threshold: float
) -> Tuple[float, float]:
    """
    Calculate True Positive Rate and False Positive Rate at a threshold.

    TPR = TP / (TP + FN) = Sensitivity = Recall
    FPR = FP / (FP + TN) = 1 - Specificity

    Args:
        true_labels: Ground truth labels (True = positive/seen, False = negative/unseen)
        confidence_scores: Confidence scores (higher = more likely positive)
        threshold: Classification threshold

    Returns:
        (TPR, FPR) tuple
    """
    if not true_labels or not confidence_scores:
        return 0.0, 0.0

    if len(true_labels) != len(confidence_scores):
        raise ValueError("true_labels and confidence_scores must have same length")

    # Classify based on threshold
    predicted_positive = [score >= threshold for score in confidence_scores]

    # Calculate confusion matrix
    tp = sum(1 for pred, true in zip(predicted_positive, true_labels) if pred and true)
    fp = sum(1 for pred, true in zip(predicted_positive, true_labels) if pred and not true)
    fn = sum(1 for pred, true in zip(predicted_positive, true_labels) if not pred and true)
    tn = sum(1 for pred, true in zip(predicted_positive, true_labels) if not pred and not true)

    # TPR = TP / (TP + FN)
    tpr = tp / (tp + fn) if (tp + fn) > 0 else 0.0

    # FPR = FP / (FP + TN)
    fpr = fp / (fp + tn) if (fp + tn) > 0 else 0.0

    return tpr, fpr


def calculate_roc_auc(
    true_labels: List[bool],
    confidence_scores: List[float],
    n_thresholds: int = 100
) -> ROCCurve:
    """
    Calculate proper ROC AUC using TPR/FPR curve.

    CRITICAL v6: This is the CORRECT way to compute AUC for CoDeC.
    Previous versions used weighted average accuracy, which is NOT AUC.

    ROC curve plots TPR vs FPR at various threshold values:
    - TPR (True Positive Rate) = TP / (TP + FN)
    - FPR (False Positive Rate) = FP / (FP + TN)
    - AUC = Area under the ROC curve using trapezoidal integration

    Perfect classifier: TPR = 1, FPR = 0 → AUC = 1.0
    Random classifier: TPR = FPR → AUC = 0.5
    Worst classifier: TPR = 0, FPR = 1 → AUC = 0.0

    Reference: Fawcett (2006) — "An introduction to ROC analysis"

    Args:
        true_labels: Ground truth (True = positive/seen, False = negative/unseen)
        confidence_scores: Confidence scores (higher = more likely positive)
        n_thresholds: Number of threshold points for ROC curve

    Returns:
        ROCCurve with TPR, FPR, thresholds, and AUC
    """
    if not true_labels or not confidence_scores:
        return ROCCurve(tpr=[], fpr=[], thresholds=[], auc=0.5)

    if len(true_labels) != len(confidence_scores):
        raise ValueError("true_labels and confidence_scores must have same length")

    # Sort unique confidence scores for thresholds
    unique_scores = sorted(set(confidence_scores))

    # Add boundaries beyond min/max scores
    min_score = min(confidence_scores)
    max_score = max(confidence_scores)

    # Create thresholds: from max_score to min_score
    # Using n_thresholds evenly spaced points
    if n_thresholds > len(unique_scores):
        # Use all unique scores plus boundaries
        thresholds = [max_score + 1.0] + unique_scores + [min_score - 1.0]
    else:
        # Use evenly spaced thresholds
        step = (max_score - min_score) / (n_thresholds - 1)
        thresholds = [max_score + 1.0] + [
            max_score - i * step for i in range(n_thresholds)
        ]

    # Calculate TPR and FPR at each threshold
    tpr_values = []
    fpr_values = []

    for thresh in thresholds:
        tpr, fpr = calculate_tpr_fpr(true_labels, confidence_scores, thresh)
        tpr_values.append(tpr)
        fpr_values.append(fpr)

    # Sort by FPR for proper ROC curve
    paired = sorted(zip(fpr_values, tpr_values), key=lambda x: x[0])
    sorted_fpr = [p[0] for p in paired]
    sorted_tpr = [p[1] for p in paired]

    # Remove duplicates (same FPR value)
    unique_fpr = []
    unique_tpr = []
    for fpr, tpr in zip(sorted_fpr, sorted_tpr):
        if not unique_fpr or fpr != unique_fpr[-1]:
            unique_fpr.append(fpr)
            unique_tpr.append(tpr)
        else:
            # Keep the point with higher TPR
            unique_tpr[-1] = max(unique_tpr[-1], tpr)

    # Ensure (0, 0) and (1, 1) are included
    if unique_fpr[0] != 0.0:
        unique_fpr.insert(0, 0.0)
        unique_tpr.insert(0, 0.0)
    if unique_fpr[-1] != 1.0:
        unique_fpr.append(1.0)
        unique_tpr.append(1.0)

    # Calculate AUC using trapezoidal rule
    auc = auc_trapezoidal(unique_fpr, unique_tpr)

    return ROCCurve(
        tpr=unique_tpr,
        fpr=unique_fpr,
        thresholds=thresholds,
        auc=auc
    )


def auc_trapezoidal(x: List[float], y: List[float]) -> float:
    """
    Calculate Area Under Curve using trapezoidal rule.

    AUC = Σ[(x_i+1 - x_i) * (y_i + y_i+1) / 2]

    Args:
        x: X-coordinates (must be sorted)
        y: Y-coordinates

    Returns:
        Area under the curve
    """
    if len(x) != len(y) or len(x) < 2:
        return 0.0

    auc = 0.0
    for i in range(len(x) - 1):
        dx = x[i + 1] - x[i]
        avg_y = (y[i] + y[i + 1]) / 2.0
        auc += dx * avg_y

    return auc


def calculate_auc_ranking(
    true_labels: List[bool],
    confidence_scores: List[float]
) -> float:
    """
    Calculate AUC using ranking method (Wilcoxon-Mann-Whitney statistic).

    AUC = P(score_positive > score_negative)

    This is equivalent to:
    AUC = (sum of ranks of positives - M*(M+1)/2) / (M * N)
    where M = number of positives, N = number of negatives

    Reference: Hanley & McNeil (1982) — "The meaning and use of the area under a ROC curve"

    Args:
        true_labels: Ground truth (True = positive, False = negative)
        confidence_scores: Confidence scores

    Returns:
        AUC value [0, 1]
    """
    if not true_labels or not confidence_scores:
        return 0.5

    if len(true_labels) != len(confidence_scores):
        raise ValueError("true_labels and confidence_scores must have same length")

    # Separate scores by class
    pos_scores = [score for score, label in zip(confidence_scores, true_labels) if label]
    neg_scores = [score for score, label in zip(confidence_scores, true_labels) if not label]

    if not pos_scores or not neg_scores:
        return 0.5

    # Count pairs where positive score > negative score
    n_greater = 0
    n_pairs = 0

    for pos_score in pos_scores:
        for neg_score in neg_scores:
            if pos_score > neg_score:
                n_greater += 1
            elif pos_score == neg_score:
                n_greater += 0.5  # Tie counts as half
            n_pairs += 1

    return n_greater / n_pairs if n_pairs > 0 else 0.5


def optimize_threshold(
    true_labels: List[bool],
    confidence_scores: List[float],
    target_tpr: Optional[float] = None,
    target_fpr: Optional[float] = None
) -> Tuple[float, float, float]:
    """
    Find optimal threshold for ROC curve.

    Can optimize for:
    - Target TPR (sensitivity)
    - Target FPR (1 - specificity)
    - Youden's J statistic (maximize TPR - FPR)

    Args:
        true_labels: Ground truth labels
        confidence_scores: Confidence scores
        target_tpr: Target TPR (if set, find threshold achieving this)
        target_fpr: Target FPR (if set, find threshold achieving this)

    Returns:
        (optimal_threshold, tpr, fpr) tuple
    """
    if not true_labels or not confidence_scores:
        return 0.5, 0.0, 0.0

    # Get ROC curve
    roc = calculate_roc_auc(true_labels, confidence_scores)

    if target_tpr is not None:
        # Find threshold closest to target TPR
        best_idx = min(range(len(roc.tpr)), key=lambda i: abs(roc.tpr[i] - target_tpr))
        return roc.thresholds[best_idx], roc.tpr[best_idx], roc.fpr[best_idx]

    if target_fpr is not None:
        # Find threshold closest to target FPR
        best_idx = min(range(len(roc.fpr)), key=lambda i: abs(roc.fpr[i] - target_fpr))
        return roc.thresholds[best_idx], roc.tpr[best_idx], roc.fpr[best_idx]

    # Use Youden's J statistic: J = TPR - FPR
    best_j = -1.0
    best_idx = 0

    for i, (tpr, fpr) in enumerate(zip(roc.tpr, roc.fpr)):
        j = tpr - fpr
        if j > best_j:
            best_j = j
            best_idx = i

    return roc.thresholds[best_idx], roc.tpr[best_idx], roc.fpr[best_idx]


if __name__ == "__main__":
    print("=" * 60)
    print("ROC/AUC Utilities Test")
    print("=" * 60)

    # Test data
    true_labels = [True, True, True, False, False, False]
    confidence_scores = [0.9, 0.8, 0.7, 0.4, 0.3, 0.2]

    print("\n1. ROC AUC Calculation:")
    roc = calculate_roc_auc(true_labels, confidence_scores)
    print(f"   AUC: {roc.auc:.4f}")
    print(f"   TPR range: [{min(roc.tpr):.2f}, {max(roc.tpr):.2f}]")
    print(f"   FPR range: [{min(roc.fpr):.2f}, {max(roc.fpr):.2f}]")

    print("\n2. AUC Ranking Method:")
    auc_ranking = calculate_auc_ranking(true_labels, confidence_scores)
    print(f"   AUC (ranking): {auc_ranking:.4f}")

    print("\n3. Optimal Threshold (Youden's J):")
    thresh, tpr, fpr = optimize_threshold(true_labels, confidence_scores)
    print(f"   Threshold: {thresh:.3f}")
    print(f"   TPR: {tpr:.3f}, FPR: {fpr:.3f}")

    print("\n4. Perfect Classifier Test:")
    perfect_labels = [True] * 5 + [False] * 5
    perfect_scores = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.0]
    perfect_roc = calculate_roc_auc(perfect_labels, perfect_scores)
    print(f"   AUC: {perfect_roc.auc:.4f} (expected ~1.0)")

    print("\n5. Random Classifier Test:")
    random_labels = [True] * 5 + [False] * 5
    random_scores = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]
    random_roc = calculate_roc_auc(random_labels, random_scores)
    print(f"   AUC: {random_roc.auc:.4f} (expected ~0.5)")

    print("\n" + "=" * 60)
