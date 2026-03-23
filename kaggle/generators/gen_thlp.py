#!/usr/bin/env python3
"""
Trinity Hippocampal Learning Probe (THLP) — Few-Shot Learning Generator
Track 1 of DeepMind AGI Hackathon
Brain Zones: HIPPOCAMPUS + AMYGDALA + ACCUMBENS

Generates 2400 test items with φ-scaling complexity gradient.
CSV format: id,task,question,answer,ground_truth,examples_count,context_length,difficulty,brain_zone,neural_analog
"""

import csv
import json
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional
import math
import random


@dataclass
class LearningItem:
    id: str
    task: str
    question: str
    answer: str
    ground_truth: str
    examples_count: int
    context_length: int
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


# Task descriptions for each sub-probe in Learning track
TASK_DESCRIPTONS = {
    "few_shot_induction": {
        "name": "Few-Shot Rule Induction",
        "desc": "Model learns rules from few examples. Hippocampus pattern completion with episodic memory.",
        "brain_zone": "hippocampus",
        "neural_analog": "Hippocampus PopulationCache stores patterns for fast retrieval and completion"
    },
    "belief_update": {
        "name": "Belief Update Under Correction",
        "desc": "Model updates beliefs when corrected. Hippocampus reconsolidation with depth tracking.",
        "brain_zone": "hippocampus",
        "neural_analog": "Hippocampus cache invalidation triggers belief revision"
    },
    "error_driven_learning": {
        "name": "Error-Driven Learning",
        "desc": "Model learns from errors rapidly. Amygdala fear conditioning with transfer distance.",
        "brain_zone": "amygdala",
        "neural_analog": "Amygdala strengthens associations on prediction errors"
    },
    "reward_signal_learning": {
        "name": "Reward-Signal Learning",
        "desc": "Model learns from reward signals. ACCumbens reinforcement with stationarity tracking.",
        "brain_zone": "accumbens",
        "neural_analog": "ACCumbens tracks reward stationarity for reinforcement"
    },
    "long_context_retention": {
        "name": "Long-Context Retention",
        "desc": "Model retains information across long contexts. Hippocampus consolidation with φ-scaling.",
        "brain_zone": "hippocampus",
        "neural_analog": "Hippocampus consolidates episodic memory with Fibonacci capacity"
    }
}


# Rule induction templates
RULE_PATTERNS = [
    {
        "desc": "Odd number detection",
        "examples": [
            {"input": "3", "output": "odd"},
            {"input": "7", "output": "odd"},
            {"input": "2", "output": "even"},
        ],
        "test": "5",
        "expected": "odd"
    },
    {
        "desc": "Capitalize first letter",
        "examples": [
            {"input": "apple", "output": "Apple"},
            {"input": "banana", "output": "Banana"},
        ],
        "test": "cherry",
        "expected": "Cherry"
    },
    {
        "desc": "Sum of first two numbers",
        "examples": [
            {"input": "1, 2", "output": "3"},
            {"input": "3, 5", "output": "8"},
        ],
        "test": "2, 7",
        "expected": "9"
    },
    {
        "desc": "Reverse string",
        "examples": [
            {"input": "cat", "output": "tac"},
            {"input": "dog", "output": "god"},
        ],
        "test": "bird",
        "expected": "drib"
    },
]

# Belief update scenarios
BELIEF_SCENARIOS = [
    {
        "initial": "Paris is the capital of Australia.",
        "correction": "Actually, Canberra is the capital of Australia.",
        "question": "What is the capital of Australia?",
        "expected": "Canberra"
    },
    {
        "initial": "Water boils at 90°C.",
        "correction": "Water boils at 100°C at sea level.",
        "question": "At what temperature does water boil at sea level?",
        "expected": "100°C"
    },
]

# Error-driven learning scenarios
ERROR_SCENARIOS = [
    {
        "error": "I previously said 7 × 8 = 56.",
        "correction": "No, 7 × 8 = 54.",
        "question": "What is 7 × 8?",
        "expected": "54"
    },
    {
        "error": "I incorrectly stated that whales are fish.",
        "correction": "Whales are mammals, not fish.",
        "question": "Are whales fish or mammals?",
        "expected": "Mammals"
    },
]

# Reward signal scenarios
REWARD_SCENARIOS = [
    {
        "action": "Solve puzzle quickly",
        "reward": "Correct! Good speed.",
        "question": "What reward did you receive?",
        "expected": "positive_reward"
    },
    {
        "action": "Incorrect answer",
        "reward": "Incorrect. Try again.",
        "question": "What reward did you receive?",
        "expected": "negative_reward"
    },
]

# Context retention scenarios (φ-scaling for complexity)
CONTEXT_SCENARIOS = [
    {
        "context": "Alice bought 3 apples, 2 oranges, and 5 bananas.",
        "question": "How many fruits did Alice buy total?",
        "expected": "10",
        "complexity": 3
    },
    {
        "context": "Bob has 5 cats. Yesterday he bought 3 more cats. Then he gave 2 cats to Carol. Before that, he had adopted 4 kittens.",
        "question": "How many cats does Bob have now?",
        "expected": "10",
        "complexity": 5
    },
    {
        "context": "A train leaves station A at 8 AM traveling at 60 mph. Station B is 180 miles away. At 9:30 AM, a second train leaves station B traveling at 80 mph.",
        "question": "At what time do the trains meet?",
        "expected": "10:08 AM",
        "complexity": 8
    },
    {
        "context": "A company has 4 departments. Department A has 12 employees. Department B has 8 but is hiring 3 more. Department C lost 2 employees who moved to Department D. Department D originally had 10 employees and received a team of 5 from Department A. Department A also sent 2 employees to Department E, which started with 7.",
        "question": "How many employees are in each department now?",
        "expected": "A: 5, B: 11, C: 8, D: 15, E: 9",
        "complexity": 13
    },
    {
        "context": "In a tournament, Team Alpha beats Team Beta (3-2). Team Beta beats Team Gamma (4-1). Team Gamma beats Team Delta (3-0). Team Delta beats Team Alpha (2-1) on penalties. Team Alpha also beats Team Gamma (4-3) in overtime. Team Epsilon draws with Team Beta (2-2) and loses to Team Delta (1-3). Team Gamma beats Team Epsilon (3-1). Team Delta ties with Team Beta (1-1). Team Alpha loses to Team Epsilon (2-3) in upset.",
        "question": "Based on these results, rank the teams by head-to-head performance and identify any circular rankings.",
        "expected": "Circular: Alpha > Beta > Gamma > Delta > Alpha, with Epsilon as wild card",
        "complexity": 21
    },
]


def generate_few_shot_items(target_count: int = 480) -> List[LearningItem]:
    """Generate few-shot rule induction items."""
    items = []

    for i in range(target_count):
        pattern = RULE_PATTERNS[i % len(RULE_PATTERNS)]
        level_idx = i % 5
        difficulty = calculate_phi_score(level_idx)

        # Vary examples count (1, 2, 4, 6, 8 - Fibonacci-like)
        examples_count = [1, 2, 4, 6, 8][level_idx]

        item = LearningItem(
            id=f"thlp_fewshot_{i:04d}",
            task=TASK_DESCRIPTONS["few_shot_induction"]["name"],
            question=f"Learn the rule from these examples and apply to the test case.\n\n{format_examples(pattern)}\n\nTest: {pattern['test']}",
            answer=pattern["expected"],
            ground_truth=pattern["expected"],
            examples_count=examples_count,
            context_length=len(format_examples(pattern)),
            difficulty=difficulty,
            brain_zone=TASK_DESCRIPTONS["few_shot_induction"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["few_shot_induction"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_belief_update_items(target_count: int = 480) -> List[LearningItem]:
    """Generate belief update items."""
    items = []

    for i in range(target_count):
        scenario = BELIEF_SCENARIOS[i % len(BELIEF_SCENARIOS)]
        level_idx = i % 5
        difficulty = calculate_phi_score(level_idx)

        # Depth of consequences (1-3 hop)
        depth = [1, 1, 2, 2, 3][level_idx]

        item = LearningItem(
            id=f"thlp_belief_{i:04d}",
            task=TASK_DESCRIPTONS["belief_update"]["name"],
            question=f"{scenario['initial']}\n\n{scenario['correction']}\n\n{scenario['question']}",
            answer=scenario["expected"],
            ground_truth=scenario["expected"],
            examples_count=0,
            context_length=len(scenario["question"]),
            difficulty=difficulty,
            brain_zone=TASK_DESCRIPTONS["belief_update"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["belief_update"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_error_driven_items(target_count: int = 480) -> List[LearningItem]:
    """Generate error-driven learning items."""
    items = []

    for i in range(target_count):
        scenario = ERROR_SCENARIOS[i % len(ERROR_SCENARIOS)]
        level_idx = i % 5
        difficulty = calculate_phi_score(level_idx)

        # Transfer distance (conceptual similarity)
        transfer_distance = [1.0, 0.8, 0.6, 0.4, 0.2][level_idx]

        item = LearningItem(
            id=f"thlp_error_{i:04d}",
            task=TASK_DESCRIPTONS["error_driven_learning"]["name"],
            question=f"{scenario['error']}\n\n{scenario['correction']}\n\n{scenario['question']}",
            answer=scenario["expected"],
            ground_truth=scenario["expected"],
            examples_count=0,
            context_length=len(scenario["question"]),
            difficulty=difficulty,
            brain_zone=TASK_DESCRIPTONS["error_driven_learning"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["error_driven_learning"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_reward_signal_items(target_count: int = 480) -> List[LearningItem]:
    """Generate reward signal learning items."""
    items = []

    for i in range(target_count):
        scenario = REWARD_SCENARIOS[i % len(REWARD_SCENARIOS)]
        level_idx = i % 5
        difficulty = calculate_phi_score(level_idx)

        # Stationarity reward (how stable reward is)
        stationarity = random.random()

        item = LearningItem(
            id=f"thlp_reward_{i:04d}",
            task=TASK_DESCRIPTONS["reward_signal_learning"]["name"],
            question=f"Action: {scenario['action']}\n\nReward: {scenario['reward']}\n\n{scenario['question']}",
            answer=scenario["expected"],
            ground_truth=scenario["expected"],
            examples_count=0,
            context_length=len(scenario["question"]),
            difficulty=difficulty,
            brain_zone=TASK_DESCRIPTONS["reward_signal_learning"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["reward_signal_learning"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_long_context_items(target_count: int = 480) -> List[LearningItem]:
    """Generate long-context retention items."""
    items = []

    for i in range(target_count):
        # Select scenario by complexity level
        level_idx = i % 5
        scenario = CONTEXT_SCENARIOS[level_idx]
        difficulty = calculate_phi_score(level_idx)

        # φ-scaling context lengths: 3, 5, 8, 13, 21 items/facts
        context_length = [3, 5, 8, 13, 21][level_idx]

        item = LearningItem(
            id=f"thlp_context_{i:04d}",
            task=TASK_DESCRIPTONS["long_context_retention"]["name"],
            question=f"{scenario['context']}\n\n{scenario['question']}",
            answer=scenario["expected"],
            ground_truth=scenario["expected"],
            examples_count=0,
            context_length=context_length,
            difficulty=difficulty,
            brain_zone=TASK_DESCRIPTONS["long_context_retention"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["long_context_retention"]["neural_analog"]
        )
        items.append(item)

    return items


def format_examples(pattern: Dict) -> str:
    """Format examples for few-shot learning."""
    lines = []
    for ex in pattern["examples"]:
        lines.append(f"Input: {ex['input']} -> Output: {ex['output']}")
    return "\n".join(lines)


def write_csv(items: List[LearningItem], output_path: str):
    """Write items to CSV file."""
    fieldnames = [
        'id',
        'task',
        'question',
        'answer',
        'ground_truth',
        'examples_count',
        'context_length',
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
        description='Generate Trinity Hippocampal Learning Probe dataset'
    )
    parser.add_argument(
        '--output',
        type=str,
        default='data/thlp_learning.csv',
        help='Output CSV path'
    )
    parser.add_argument(
        '--count',
        type=int,
        default=2400,
        help='Number of items to generate (default: 2400)'
    )
    args = parser.parse_args()

    print(f"🧠 Trinity Hippocampal Learning Probe Generator")
    print(f"📊 Target: {args.count} items")
    print(f"📏 φ-scaling: {FIBONACCI_LEVELS} (Fibonacci)")
    print(f"🧵 Brain Zones: HIPPOCAMPUS, AMYGDALA, ACCUMBENS")
    print()

    # Generate items for each task (480 per task = 2400 total)
    items_per_task = args.count // 5
    all_items = []

    all_items.extend(generate_few_shot_items(items_per_task))
    all_items.extend(generate_belief_update_items(items_per_task))
    all_items.extend(generate_error_driven_items(items_per_task))
    all_items.extend(generate_reward_signal_items(items_per_task))
    all_items.extend(generate_long_context_items(items_per_task))

    # Shuffle for better distribution
    random.shuffle(all_items)

    # Create output directory if needed
    import os
    os.makedirs(os.path.dirname(args.output) or '.', exist_ok=True)

    write_csv(all_items[:args.count], args.output)

    # Summary statistics
    task_counts: Dict[str, int] = {}
    zone_counts: Dict[str, int] = {}

    for item in all_items[:args.count]:
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
