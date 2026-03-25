#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Scientific Metrics Visualization

Visualization tools for scientific metrics:
- ROC curves
- Calibration curves (reliability diagrams)
- Per-class ECE plots
- Distribution shift plots
- Confidence bands

Usage:
    from kaggle.eval.visualization import plot_roc_curve, plot_calibration_curve

    # Plot ROC curve
    plot_roc_curve(roc_result, save_path="roc.png")

    # Plot calibration curve
    plot_calibration_curve(confidences, correct, save_path="calibration.png")
"""

import math
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass
from pathlib import Path


# Try to import matplotlib
try:
    import matplotlib
    matplotlib.use('Agg')  # Non-interactive backend
    import matplotlib.pyplot as plt
    import numpy as np
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False


def _check_matplotlib():
    """Check if matplotlib is available."""
    if not HAS_MATPLOTLIB:
        raise ImportError(
            "matplotlib is required for visualization. "
            "Install with: pip install matplotlib numpy"
        )


def plot_roc_curve(
    tpr: List[float],
    fpr: List[float],
    auc: float,
    save_path: Optional[str] = None,
    title: str = "ROC Curve",
    figsize: Tuple[int, int] = (8, 6)
) -> str:
    """
    Plot ROC curve with AUC.

    Args:
        tpr: True Positive Rate values
        fpr: False Positive Rate values
        auc: Area Under Curve
        save_path: Path to save plot (optional)
        title: Plot title
        figsize: Figure size (width, height)

    Returns:
        Path to saved plot (or empty string if not saved)
    """
    _check_matplotlib()

    fig, ax = plt.subplots(figsize=figsize)

    # Plot ROC curve
    ax.plot(fpr, tpr, 'b-', linewidth=2, label=f'ROC (AUC = {auc:.4f})')

    # Plot diagonal (random classifier)
    ax.plot([0, 1], [0, 1], 'r--', linewidth=1, label='Random (AUC = 0.5)')

    # Plot perfect classifier point
    ax.plot(0, 1, 'go', markersize=8, label='Perfect')

    # Formatting
    ax.set_xlim([0, 1])
    ax.set_ylim([0, 1.05])
    ax.set_xlabel('False Positive Rate (1 - Specificity)')
    ax.set_ylabel('True Positive Rate (Sensitivity)')
    ax.set_title(title)
    ax.legend(loc='lower right')
    ax.grid(True, alpha=0.3)

    plt.tight_layout()

    if save_path:
        Path(save_path).parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        plt.close()
        return save_path
    else:
        plt.show()
        plt.close()
        return ""


def plot_calibration_curve(
    confidences: List[float],
    correct: List[bool],
    n_bins: int = 10,
    save_path: Optional[str] = None,
    title: str = "Calibration Curve (Reliability Diagram)",
    figsize: Tuple[int, int] = (8, 6)
) -> str:
    """
    Plot calibration curve (reliability diagram).

    Args:
        confidences: Confidence values
        correct: Correctness labels
        n_bins: Number of bins
        save_path: Path to save plot
        title: Plot title
        figsize: Figure size

    Returns:
        Path to saved plot
    """
    _check_matplotlib()

    if len(confidences) != len(correct):
        raise ValueError("confidences and correct must have same length")

    # Calculate bin statistics
    bin_boundaries = [i / n_bins for i in range(n_bins + 1)]

    bin_conf_sum = {}
    bin_acc_sum = {}
    bin_counts = {}

    for conf, corr in zip(confidences, correct):
        bin_idx = min(int(conf * n_bins), n_bins - 1)
        bin_conf_sum[bin_idx] = bin_conf_sum.get(bin_idx, 0) + conf
        bin_acc_sum[bin_idx] = bin_acc_sum.get(bin_idx, 0) + (1.0 if corr else 0.0)
        bin_counts[bin_idx] = bin_counts.get(bin_idx, 0) + 1

    # Calculate averages
    bin_centers = []
    avg_confs = []
    avg_accs = []
    bin_weights = []

    for i in range(n_bins):
        if i in bin_counts and bin_counts[i] > 0:
            bin_centers.append((i + 0.5) / n_bins)
            avg_confs.append(bin_conf_sum[i] / bin_counts[i])
            avg_accs.append(bin_acc_sum[i] / bin_counts[i])
            bin_weights.append(bin_counts[i])

    # Calculate ECE
    ece = 0.0
    total = sum(bin_counts.values())
    if total > 0:
        for i in range(n_bins):
            if i in bin_counts:
                weight = bin_counts[i] / total
                conf = avg_confs[i] if i < len(avg_confs) else bin_conf_sum[i] / bin_counts[i]
                acc = avg_accs[i] if i < len(avg_accs) else bin_acc_sum[i] / bin_counts[i]
                ece += weight * abs(conf - acc)

    # Create plot
    fig, ax = plt.subplots(figsize=figsize)

    # Plot calibration curve
    if avg_confs and avg_accs:
        # Scale point sizes by bin count
        sizes = [w * 20 for w in bin_weights]
        ax.scatter(avg_confs, avg_accs, s=sizes, alpha=0.6, edgecolors='b', linewidths=2)
        ax.plot(avg_confs, avg_accs, 'b-', linewidth=1, alpha=0.5)

    # Plot perfect calibration line
    ax.plot([0, 1], [0, 1], 'r--', linewidth=2, label='Perfect Calibration')

    # Formatting
    ax.set_xlim([0, 1])
    ax.set_ylim([0, 1])
    ax.set_xlabel('Confidence (Mean Predicted Probability)')
    ax.set_ylabel('Accuracy (Empirical Frequency)')
    ax.set_title(f'{title}\nECE = {ece:.4f}')
    ax.legend(loc='lower right')
    ax.grid(True, alpha=0.3)

    # Add weight annotation
    if bin_weights:
        total_weight = sum(bin_weights)
        ax.text(0.05, 0.95, f'Total samples: {total_weight}',
                transform=ax.transAxes, verticalalignment='top',
                bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

    plt.tight_layout()

    if save_path:
        Path(save_path).parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        plt.close()
        return save_path
    else:
        plt.show()
        plt.close()
        return ""


def plot_classwise_ece(
    ece_per_class: Dict[int, float],
    class_names: Optional[List[str]] = None,
    save_path: Optional[str] = None,
    title: str = "Per-Class ECE",
    figsize: Tuple[int, int] = (10, 6)
) -> str:
    """
    Plot per-class Expected Calibration Error.

    Args:
        ece_per_class: Dictionary mapping class index to ECE value
        class_names: Optional list of class names
        save_path: Path to save plot
        title: Plot title
        figsize: Figure size

    Returns:
        Path to saved plot
    """
    _check_matplotlib()

    classes = sorted(ece_per_class.keys())
    ece_values = [ece_per_class[c] for c in classes]

    # Use class names if provided
    if class_names:
        labels = [class_names[i] if i < len(class_names) else f"Class {i}"
                  for i in classes]
    else:
        labels = [f"Class {i}" for i in classes]

    # Color by ECE value
    colors = ['#2ecc71' if ece < 0.05 else '#f39c12' if ece < 0.1 else '#e74c3c'
              for ece in ece_values]

    fig, ax = plt.subplots(figsize=figsize)

    bars = ax.bar(labels, ece_values, color=colors, edgecolor='black', linewidth=1)

    # Add value labels on bars
    for bar, value in zip(bars, ece_values):
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
                f'{value:.3f}',
                ha='center', va='bottom', fontsize=9)

    # Formatting
    ax.set_ylabel('Expected Calibration Error')
    ax.set_title(title)
    ax.set_ylim([0, max(max(ece_values) * 1.2, 0.1)])
    ax.axhline(y=0.05, color='g', linestyle='--', alpha=0.5, label='Good (< 0.05)')
    ax.axhline(y=0.1, color='orange', linestyle='--', alpha=0.5, label='Fair (< 0.1)')
    ax.legend(loc='upper right')
    ax.grid(True, axis='y', alpha=0.3)

    # Rotate labels if many classes
    if len(classes) > 10:
        plt.xticks(rotation=45, ha='right')

    plt.tight_layout()

    if save_path:
        Path(save_path).parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        plt.close()
        return save_path
    else:
        plt.show()
        plt.close()
        return ""


def plot_confidence_bands(
    bin_confidences: List[float],
    bin_accuracies: List[float],
    bin_counts: List[int],
    lower_bounds: List[float],
    upper_bounds: List[float],
    n_bins: int,
    alpha: float = 0.05,
    save_path: Optional[str] = None,
    title: str = "Calibration with Confidence Bands",
    figsize: Tuple[int, int] = (8, 6)
) -> str:
    """
    Plot calibration curve with confidence bands.

    Args:
        bin_confidences: Mean confidence per bin
        bin_accuracies: Mean accuracy per bin
        bin_counts: Number of samples per bin
        lower_bounds: Lower confidence bound per bin
        upper_bounds: Upper confidence bound per bin
        n_bins: Number of bins
        alpha: Significance level
        save_path: Path to save plot
        title: Plot title
        figsize: Figure size

    Returns:
        Path to saved plot
    """
    _check_matplotlib()

    fig, ax = plt.subplots(figsize=figsize)

    # Get valid bins (with data)
    valid_indices = [i for i, count in enumerate(bin_counts) if count > 0]

    if valid_indices:
        valid_confs = [bin_confidences[i] for i in valid_indices]
        valid_accs = [bin_accuracies[i] for i in valid_indices]
        valid_lowers = [lower_bounds[i] for i in valid_indices]
        valid_uppers = [upper_bounds[i] for i in valid_indices]

        # Plot confidence bands
        ax.fill_between(valid_confs, valid_lowers, valid_uppers,
                       alpha=0.3, color='blue', label=f'{int((1-alpha)*100)}% Confidence Band')

        # Plot calibration curve
        ax.plot(valid_confs, valid_accs, 'bo-', linewidth=2,
                label='Calibration Curve', markersize=6)

    # Plot perfect calibration
    ax.plot([0, 1], [0, 1], 'r--', linewidth=2, label='Perfect Calibration')

    # Formatting
    ax.set_xlim([0, 1])
    ax.set_ylim([0, 1])
    ax.set_xlabel('Confidence')
    ax.set_ylabel('Accuracy')
    ax.set_title(title)
    ax.legend(loc='lower right')
    ax.grid(True, alpha=0.3)

    plt.tight_layout()

    if save_path:
        Path(save_path).parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        plt.close()
        return save_path
    else:
        plt.show()
        plt.close()
        return ""


def plot_distribution_shift(
    source_confidences: List[float],
    target_confidences: List[float],
    ks_statistic: float,
    ks_pvalue: float,
    save_path: Optional[str] = None,
    title: str = "Distribution Shift Detection",
    figsize: Tuple[int, int] = (10, 6)
) -> str:
    """
    Plot confidence distributions for shift detection.

    Args:
        source_confidences: Source distribution confidences
        target_confidences: Target distribution confidences
        ks_statistic: KS test statistic
        ks_pvalue: KS test p-value
        save_path: Path to save plot
        title: Plot title
        figsize: Figure size

    Returns:
        Path to saved plot
    """
    _check_matplotlib()

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=figsize)

    # Histogram
    bins = 20
    ax1.hist(source_confidences, bins=bins, alpha=0.5, label='Source', color='blue', density=True)
    ax1.hist(target_confidences, bins=bins, alpha=0.5, label='Target', color='orange', density=True)
    ax1.set_xlabel('Confidence')
    ax1.set_ylabel('Density')
    ax1.set_title('Confidence Distributions')
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    # CDF
    source_sorted = sorted(source_confidences)
    target_sorted = sorted(target_confidences)

    source_cdf = [i / len(source_sorted) for i in range(len(source_sorted))]
    target_cdf = [i / len(target_sorted) for i in range(len(target_sorted))]

    ax2.plot(source_sorted, source_cdf, 'b-', label='Source CDF', linewidth=2)
    ax2.plot(target_sorted, target_cdf, 'orange', label='Target CDF', linewidth=2)
    ax2.set_xlabel('Confidence')
    ax2.set_ylabel('Cumulative Probability')
    ax2.set_title(f'CDFs (KS: {ks_statistic:.4f}, p={ks_pvalue:.4f})')
    ax2.legend()
    ax2.grid(True, alpha=0.3)

    # Overall title
    shift_detected = ks_pvalue < 0.05
    shift_status = "SHIFT DETECTED" if shift_detected else "No significant shift"
    fig.suptitle(f'{title}\n{shift_status}', fontsize=12, fontweight='bold')

    plt.tight_layout()

    if save_path:
        Path(save_path).parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        plt.close()
        return save_path
    else:
        plt.show()
        plt.close()
        return ""


def plot_multi_metric_comparison(
    metrics_dict: Dict[str, Dict[str, float]],
    save_path: Optional[str] = None,
    title: str = "Metrics Comparison",
    figsize: Tuple[int, int] = (12, 6)
) -> str:
    """
    Plot comparison of metrics across multiple versions or models.

    Args:
        metrics_dict: Dictionary mapping names to metric values
                     e.g., {"v5": {"ece": 0.1, "auc": 0.9}, "v6": {"ece": 0.08, "auc": 0.95}}
        save_path: Path to save plot
        title: Plot title
        figsize: Figure size

    Returns:
        Path to saved plot
    """
    _check_matplotlib()

    # Get all metric names
    metric_names = set()
    for metrics in metrics_dict.values():
        metric_names.update(metrics.keys())
    metric_names = sorted(metric_names)

    # Create subplots for each metric
    n_metrics = len(metric_names)
    n_cols = min(3, n_metrics)
    n_rows = (n_metrics + n_cols - 1) // n_cols

    fig, axes = plt.subplots(n_rows, n_cols, figsize=figsize)
    if n_metrics == 1:
        axes = [axes]
    elif n_rows == 1:
        axes = axes.reshape(1, -1)

    for i, metric_name in enumerate(metric_names):
        row = i // n_cols
        col = i % n_cols
        ax = axes[row, col] if n_rows > 1 else axes[col]

        values = []
        labels = []
        for name, metrics in metrics_dict.items():
            if metric_name in metrics:
                values.append(metrics[metric_name])
                labels.append(name)

        if values:
            colors = plt.cm.viridis(np.linspace(0, 1, len(values)))
            bars = ax.bar(labels, values, color=colors, edgecolor='black', linewidth=1)

            # Add value labels
            for bar, value in zip(bars, values):
                height = bar.get_height()
                ax.text(bar.get_x() + bar.get_width()/2., height,
                       f'{value:.4f}', ha='center', va='bottom', fontsize=9)

        ax.set_ylabel(metric_name.upper())
        ax.set_title(metric_name.replace('_', ' ').title())
        ax.grid(True, axis='y', alpha=0.3)

    # Hide unused subplots
    for i in range(n_metrics, n_rows * n_cols):
        row = i // n_cols
        col = i % n_cols
        ax = axes[row, col] if n_rows > 1 else axes[col]
        ax.axis('off')

    plt.suptitle(title, fontsize=14, fontweight='bold')
    plt.tight_layout()

    if save_path:
        Path(save_path).parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        plt.close()
        return save_path
    else:
        plt.show()
        plt.close()
        return ""


def plot_ascii_roc(tpr: List[float], fpr: List[float], auc: float) -> str:
    """
    Generate ASCII art ROC curve (no matplotlib required).

    Args:
        tpr: True Positive Rate values
        fpr: False Positive Rate values
        auc: Area Under Curve

    Returns:
        ASCII art string
    """
    # Create a 20x10 grid
    width, height = 40, 20

    # Normalize points to grid
    grid = [[' ' for _ in range(width)] for _ in range(height)]

    # Plot diagonal (random)
    for i in range(min(width, height)):
        x = i
        y = height - 1 - i * (height - 1) // width
        grid[y][x] = '.'

    # Plot ROC curve
    for t, f in zip(tpr, fpr):
        x = int(f * (width - 1))
        y = height - 1 - int(t * (height - 1))
        if 0 <= x < width and 0 <= y < height:
            grid[y][x] = '*'

    # Convert to string
    lines = []
    lines.append(f"ROC Curve (AUC={auc:.4f})")
    lines.append("+" + "-" * width + "+")
    for row in grid:
        lines.append("|" + "".join(row) + "|")
    lines.append("+" + "-" * width + "+")
    lines.append(" " * (width // 2 - 5) + "0.0     1.0")
    lines.append(" " * (width // 2 - 5)) + "FPR -->"

    return "\n".join(lines)


if __name__ == "__main__":
    print("=" * 60)
    print("Scientific Metrics Visualization")
    print("=" * 60)

    if HAS_MATPLOTLIB:
        print("\n✓ matplotlib is available")
    else:
        print("\n✗ matplotlib not available")
        print("  Install with: pip install matplotlib numpy")

    # Test ASCII ROC
    print("\n" + "-" * 60)
    print("ASCII ROC Curve Test:")
    print("-" * 60)

    tpr = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
    fpr = [0.0, 0.1, 0.2, 0.4, 0.7, 1.0]
    auc = 0.85

    print(plot_ascii_roc(tpr, fpr, auc))

    print("\n" + "=" * 60)
