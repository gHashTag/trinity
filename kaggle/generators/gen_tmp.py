#!/usr/bin/env python3
"""
Trinity Metacognition Probe (TMP) — Confidence Calibration Generator
Track 2 of DeepMind AGI Hackathon
Brain Zones: ACC + OFC + HABENULA + INSULA

Generates 2200 test items with φ-scaling complexity gradient.
CSV format: id,task,question,answer,ground_truth_confidence,difficulty,brain_zone,neural_analog
"""

import csv
import json
from dataclasses import dataclass, asdict
from typing import List, Dict
import math


@dataclass
class ConfidenceItem:
    id: str
    task: str
    question: str
    answer: str
    ground_truth_confidence: float
    difficulty: float
    brain_zone: str
    neural_analog: str


# Golden ratio φ = (1 + sqrt(5)) / 2 ≈ 1.618
# Fibonacci for φ-scaling: 3, 5, 8, 13, 21
PHI = (1 + math.sqrt(5)) / 2
FIBONACCI_LEVELS = [3, 5, 8, 13, 21]


def calculate_phi_score(level_idx: int) -> float:
    """Calculate difficulty score based on φ-scaling."""
    base = FIBONACCI_LEVELS[level_idx % len(FIBONACCI_LEVELS)]
    # Add φ scaling for finer gradient
    phi_factor = PHI ** (level_idx / 5)
    return round(base * phi_factor, 4)


# Task descriptions for each sub-probe in Metacognition track
TASK_DESCRIPTONS = {
    "confidence_calibration": {
        "name": "Confidence Calibration",
        "desc": "Model must assess its confidence accurately. OFC value judgment with calibrated uncertainty.",
        "brain_zone": "ofc",
        "neural_analog": "OFC value judgment requires calibrated confidence for optimal decision-making"
    },
    "error_detection": {
        "name": "Error Self-Detection",
        "desc": "Model detects when its own reasoning is flawed. ACC conflict monitor between cache and live state.",
        "brain_zone": "acc",
        "neural_analog": "ACC detects stale cache vs live state conflicts"
    },
    "strategic_adaptation": {
        "name": "Strategic Adaptation",
        "desc": "Model adapts strategy based on past failures. MNL pattern learning from Experience Engine.",
        "brain_zone": "acc",
        "neural_analog": "ACC + Amygdala Minimum Necessary Learning"
    },
    "knowledge_boundary": {
        "name": "Knowledge Boundary",
        "desc": "Model recognizes limits of its knowledge. HABENULA fairness detection for reward/effort ratio.",
        "brain_zone": "habenula",
        "neural_analog": "HABENULA anti-corruption: effort must match reward"
    },
    "monitoring_under_load": {
        "name": "Monitoring Under Load",
        "desc": "Model maintains self-awareness under resource constraints. Insula interoceptive health metrics.",
        "brain_zone": "insula",
        "neural_analog": "Insula measures internal state and resource health"
    }
}


# Question templates for each task
QUESTIONS = {
    "confidence_calibration": [
        {
            "q": "What is the capital of Uzbekistan?",
            "a": "Tashkent",
            "c": 0.95  # Should be high confidence
        },
        {
            "q": "Explain quantum superposition in one sentence.",
            "a": "A quantum system exists in multiple states simultaneously until measured.",
            "c": 0.3  # Low confidence appropriate for complex topic
        },
        {
            "q": "What is 2^20?",
            "a": "1048576",
            "c": 0.98  # High confidence for math
        },
    ],
    "error_detection": [
        {
            "q": "I previously stated Paris is the capital of Australia. Is this correct?",
            "a": "No, Canberra is the capital of Australia.",
            "c": 0.9  # Should catch previous error
        },
        {
            "q": "I claimed 7 × 8 = 56. Is this correct?",
            "a": "No, 7 × 8 = 54.",
            "c": 0.85  # Moderate confidence needed
        },
    ],
    "strategic_adaptation": [
        {
            "q": "The previous approach failed due to timeout. What should you try next?",
            "a": "Reduce batch size and increase timeout threshold.",
            "c": 0.7  # Uncertainty is appropriate for strategy
        },
    ],
    "knowledge_boundary": [
        {
            "q": "What year was the first neural network architecture published?",
            "a": "I don't have high confidence about publications before 1950.",
            "c": 0.4  # Express knowledge boundary
        },
    ],
    "monitoring_under_load": [
        {
            "q": "You've been processing for 5 minutes. Is your performance stable?",
            "a": "Yes, latency is within acceptable bounds.",
            "c": 0.8  # Self-monitoring under load
        },
    ],
}


def generate_items(target_count: int = 440) -> List[ConfidenceItem]:
    """
    Generate ConfidenceItems distributed across 5 sub-tasks.
    Target: 440 items per sub-task × 5 = 2200 total.

    φ-scaling distribution:
    - Level 0 (3.0): 15% (330 items)
    - Level 1 (3.2φ): 25% (550 items)
    - Level 2 (5.0): 30% (660 items)
    - Level 3 (5.6φ): 20% (440 items)
    - Level 4 (8.0): 10% (220 items)
    """
    items = []

    # Distribution per difficulty level
    level_distribution = [330, 550, 660, 440, 220]

    item_counter = 0
    level_idx = 0

    for task_key in TASK_DESCRIPTONS.keys():
        questions = QUESTIONS.get(task_key, [])

        if not questions:
            continue

        task_info = TASK_DESCRIPTONS[task_key]

        # Generate items for this task across all difficulty levels
        for level_idx, level_count in enumerate(level_distribution):
            for i in range(level_count):
                if item_counter >= target_count:
                    break

                # Pick question cyclically from template
                question_idx = item_counter % len(questions)
                question_template = questions[question_idx]

                difficulty = calculate_phi_score(level_idx)

                item = ConfidenceItem(
                    id=f"tmp_{task_key}_{item_counter:04d}",
                    task=task_info["name"],
                    question=question_template["q"],
                    answer=question_template["a"],
                    ground_truth_confidence=question_template["c"],
                    difficulty=difficulty,
                    brain_zone=task_info["brain_zone"],
                    neural_analog=task_info["neural_analog"]
                )
                items.append(item)
                item_counter += 1

                if item_counter >= target_count:
                    break

        if item_counter >= target_count:
            break

        level_idx += 1

    return items[:target_count]


def write_csv(items: List[ConfidenceItem], output_path: str):
    """Write items to CSV file."""
    fieldnames = [
        'id',
        'task',
        'question',
        'answer',
        'ground_truth_confidence',
        'difficulty',
        'brain_zone',
        'neural_analog'
    ]

    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()

        for item in items:
            row = asdict(item)
            writer.writerow(row)

    print(f"✅ Generated {len(items)} items → {output_path}")


def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Generate Trinity Metacognition Probe dataset'
    )
    parser.add_argument(
        '--output',
        type=str,
        default='data/tmp_metacognition.csv',
        help='Output CSV path'
    )
    parser.add_argument(
        '--count',
        type=int,
        default=2200,
        help='Number of items to generate (default: 2200)'
    )
    args = parser.parse_args()

    print(f"🧠 Trinity Metacognition Probe Generator")
    print(f"📊 Target: {args.count} items")
    print(f"📏 φ-scaling: {FIBONACCI_LEVELS} (Fibonacci)")
    print(f"🧵 Brain Zones: OFC, ACC, HABENULA, INSULA")
    print()

    items = generate_items(args.count)

    # Create output directory if needed
    import os
    os.makedirs(os.path.dirname(args.output) or '.', exist_ok=True)

    write_csv(items, args.output)

    # Summary statistics
    task_counts: Dict[str, int] = {}
    zone_counts: Dict[str, int] = {}

    for item in items:
        task_counts[item.task] = task_counts.get(item.task, 0) + 1
        zone_counts[item.brain_zone] = zone_counts.get(item.brain_zone, 0) + 1

    print()
    print("📊 Summary:")
    for task, count in sorted(task_counts.items()):
        print(f"  {task}: {count} items")
    print()
    for zone, count in sorted(zone_counts.items()):
        print(f"  {zone}: {count} items")


if __name__ == '__main__':
    main()
