#!/usr/bin/env python3
"""
Trinity Attentional Gateway Probe (TAGP) — Selective Attention Generator
Track 3 of DeepMind AGI Hackathon
Brain Zones: THALAMUS + COLLICULUS + COERULEUS + RETICULAR

Generates 2200 test items with φ-scaling complexity gradient.
CSV format: id,task,context,query,distractor_count,expected_focus,difficulty,brain_zone,neural_analog
"""

import csv
import json
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional
import math
import random


@dataclass
class AttentionItem:
    id: str
    task: str
    context: str
    query: str
    distractor_count: int
    expected_focus: str
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


# Task descriptions for each sub-probe in Attention track
TASK_DESCRIPTONS = {
    "selective_filtering": {
        "name": "Selective Filtering",
        "desc": "Model filters relevant information from noise. Thalamus gating with focus/suppress config.",
        "brain_zone": "thalamus",
        "neural_analog": "Thalamus FilterConfig.focus and FilterConfig.suppress for attentional control"
    },
    "sustained_attention": {
        "name": "Sustained Over Length",
        "desc": "Model maintains focus over long contexts. Reticular formation alertness tracking.",
        "brain_zone": "reticular",
        "neural_analog": "Reticular system tracks cycle_latency_us for sustained alertness"
    },
    "attention_shifting": {
        "name": "Attention Shifting",
        "desc": "Model shifts focus efficiently. Colliculus orientation with switching cost measurement.",
        "brain_zone": "colliculus",
        "neural_analog": "Colliculus FilterConfig.focus switching cost"
    },
    "adversarial_needle": {
        "name": "Adversarial Needle",
        "desc": "Model finds critical info in haystack. Thalamus + Coeruleus with DECOY detection.",
        "brain_zone": "thalamus",
        "neural_analog": "Thalamus + Coeruleus handle needle-in-haystack with decoy patterns"
    },
    "divided_attention": {
        "name": "Divided Attention",
        "desc": "Model handles multiple simultaneous streams. Coeruleus arousal with dual-task cost.",
        "brain_zone": "coeruleus",
        "neural_analog": "Coeruleus manages arousal for parallel task processing"
    }
}


# Selective filtering templates (noise + signal)
FILTERING_TEMPLATES = [
    {
        "noise": [
            "The weather is nice today.",
            "I like pizza.",
            "Cats are furry animals.",
            "The sky is blue.",
            "Water is wet.",
            "Trees have leaves.",
            "Cars have wheels.",
            "Books have pages.",
        ],
        "signal": "The API key is sk_live_abc123xyz789.",
        "query": "What is the API key?",
        "expected": "sk_live_abc123xyz789"
    },
    {
        "noise": [
            "JavaScript is a programming language.",
            "Python is popular for AI.",
            "Rust is fast and safe.",
            "Go is good for concurrency.",
            "Java runs on JVM.",
            "C++ is low-level.",
            "Ruby is elegant.",
            "PHP is for web development.",
        ],
        "signal": "The error code is ERR_TIMEOUT_DB_CONNECTION.",
        "query": "What is the error code?",
        "expected": "ERR_TIMEOUT_DB_CONNECTION"
    },
    {
        "noise": [
            "The meeting is at 3 PM.",
            "Please send the report.",
            "Don't forget to call mom.",
            "Buy groceries on the way home.",
            "The car needs oil change.",
            "Doctor appointment on Friday.",
            "Pay electricity bill.",
            "Renew library books.",
        ],
        "signal": "Critical: System failure in production. Immediate action required.",
        "query": "What is the critical message?",
        "expected": "System failure in production"
    },
]

# Sustained attention scenarios (increasing context length)
SUSTAINED_TEMPLATES = [
    {
        "length": 3,
        "context": [
            "Alice went to the store.",
            "She bought apples and oranges.",
            "Alice paid with cash.",
        ],
        "query": "How did Alice pay?",
        "expected": "cash"
    },
    {
        "length": 5,
        "context": [
            "The project started in January.",
            "Team Alpha was assigned to it.",
            "They completed phase 1 in February.",
            "Phase 2 took until March.",
            "The final deliverable was in April.",
        ],
        "query": "When was phase 2 completed?",
        "expected": "March"
    },
    {
        "length": 8,
        "context": [
            "Server A hosts the database.",
            "Server B runs the API.",
            "Server C handles caching.",
            "Server D processes jobs.",
            "Server E stores logs.",
            "Server F monitors metrics.",
            "Server G serves static files.",
            "Server H manages authentication.",
        ],
        "query": "Which server runs the API?",
        "expected": "Server B"
    },
    {
        "length": 13,
        "context": [
            "User 1 logged in at 08:00.",
            "User 2 logged in at 08:15.",
            "User 3 logged in at 08:30.",
            "User 4 logged in at 08:45.",
            "User 5 logged in at 09:00.",
            "User 1 logged out at 09:10.",
            "User 6 logged in at 09:20.",
            "User 2 logged out at 09:30.",
            "User 7 logged in at 09:40.",
            "User 3 logged out at 09:50.",
            "User 8 logged in at 10:00.",
            "User 4 logged out at 10:10.",
            "User 9 logged in at 10:20.",
        ],
        "query": "Which user was logged in at 09:25?",
        "expected": "User 6"
    },
    {
        "length": 21,
        "context": [
            "Chapter 1: The hero begins their journey.",
            "Chapter 2: They meet a wise mentor.",
            "Chapter 3: The first challenge appears.",
            "Chapter 4: A companion joins the party.",
            "Chapter 5: They discover an ancient map.",
            "Chapter 6: The villain is revealed.",
            "Chapter 7: A betrayal occurs.",
            "Chapter 8: The hero loses hope.",
            "Chapter 9: A revelation restores faith.",
            "Chapter 10: The final battle begins.",
            "Chapter 11: Victory seems impossible.",
            "Chapter 12: A sacrifice is made.",
            "Chapter 13: The villain's weakness is found.",
            "Chapter 14: The hero gains new power.",
            "Chapter 15: The tide turns.",
            "Chapter 16: The companion falls.",
            "Chapter 17: The hero presses on alone.",
            "Chapter 18: The villain is defeated.",
            "Chapter 19: The world is saved.",
            "Chapter 20: Peace returns to the land.",
            "Chapter 21: The hero's legend lives on.",
        ],
        "query": "In which chapter does the hero lose hope?",
        "expected": "Chapter 8"
    },
]

# Attention shifting templates
SHIFTING_TEMPLATES = [
    {
        "focus_1": "color",
        "context_1": "The RED car drove fast. The blue bike was slow. RED is the fastest color.",
        "focus_2": "vehicle",
        "context_2": "Cars are faster than bikes. Trucks are slowest.",
        "query": "Which vehicle is fastest?",
        "expected": "car"
    },
    {
        "focus_1": "price",
        "context_1": "Item A costs $10. Item B costs $20. Item A is cheaper.",
        "focus_2": "quality",
        "context_2": "Item A has 3 stars. Item B has 5 stars. Item B has better quality.",
        "query": "Which item has better quality?",
        "expected": "Item B"
    },
]

# Needle-in-haystack with decoys
NEEDLE_TEMPLATES = [
    {
        "haystack": [
            "The password is: qwerty123",
            "The password is: admin456",
            "The password is: letmein789",
            "The password is: hunter2",
            "The password is: 123456",
            "The password is: password1",
            "The password is: football",
            "The password is: monkey123",
        ],
        "needle": "The password is: CORRECT_answ3r!XK9",
        "decoys": [
            "qwerty123",
            "admin456",
            "letmein789",
            "hunter2",
        ],
        "query": "What is the correct password?",
        "expected": "CORRECT_answ3r!XK9"
    },
    {
        "haystack": [
            "Debug line 1: variable x = 5",
            "Debug line 2: variable y = 10",
            "Debug line 3: variable z = 15",
            "Debug line 4: variable sum = 20",
            "Debug line 5: ERROR: division by zero",
            "Debug line 6: variable product = 30",
            "Debug line 7: variable diff = -5",
            "Debug line 8: ERROR: null pointer",
        ],
        "needle": "Debug line 42: ERROR: REAL_bug_buffer_overflow_0xdeadbeef",
        "decoys": [
            "division by zero",
            "null pointer",
            "buffer overflow",
        ],
        "query": "What is the REAL error message?",
        "expected": "REAL_bug_buffer_overflow_0xdeadbeef"
    },
]

# Divided attention templates (dual-task)
DIVIDED_TEMPLATES = [
    {
        "task_1": "Count even numbers",
        "stream_1": "3, 7, 4, 9, 2, 8, 5, 6, 1, 10",
        "task_2": "Count numbers > 5",
        "stream_2": "3, 7, 4, 9, 2, 8, 5, 6, 1, 10",
        "query_1": "How many even numbers?",
        "query_2": "How many numbers > 5?",
        "expected": "5, 4"
    },
    {
        "task_1": "Track words starting with 'A'",
        "stream_1": "Apple, Banana, Avocado, Cherry, Apricot, Date",
        "task_2": "Track fruits with 5 letters",
        "stream_2": "Apple, Banana, Avocado, Cherry, Apricot, Date",
        "query_1": "Words starting with 'A'?",
        "query_2": "Fruits with 5 letters?",
        "expected": "3, 2"
    },
]


def generate_filtering_items(target_count: int = 440) -> List[AttentionItem]:
    """Generate selective filtering items."""
    items = []

    for i in range(target_count):
        template = FILTERING_TEMPLATES[i % len(FILTERING_TEMPLATES)]
        level_idx = i % 5
        difficulty = calculate_phi_score(level_idx)

        # Distractor count increases with difficulty
        distractor_count = [3, 5, 8, 13, 21][level_idx]

        # Build context with noise + signal
        noise_subset = template["noise"][:distractor_count]
        random.shuffle(noise_subset)
        context_lines = noise_subset + [template["signal"]]
        random.shuffle(context_lines)
        context = " ".join(context_lines)

        item = AttentionItem(
            id=f"tagp_filter_{i:04d}",
            task=TASK_DESCRIPTONS["selective_filtering"]["name"],
            context=context,
            query=template["query"],
            distractor_count=distractor_count,
            expected_focus=template["expected"],
            difficulty=difficulty,
            brain_zone=TASK_DESCRIPTONS["selective_filtering"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["selective_filtering"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_sustained_items(target_count: int = 440) -> List[AttentionItem]:
    """Generate sustained attention items."""
    items = []

    for i in range(target_count):
        # Cycle through templates by difficulty
        level_idx = i % 5
        template = SUSTAINED_TEMPLATES[level_idx]
        difficulty = calculate_phi_score(level_idx)

        context = " ".join(template["context"])

        item = AttentionItem(
            id=f"tagp_sustained_{i:04d}",
            task=TASK_DESCRIPTONS["sustained_attention"]["name"],
            context=context,
            query=template["query"],
            distractor_count=template["length"],
            expected_focus=template["expected"],
            difficulty=difficulty,
            brain_zone=TASK_DESCRIPTONS["sustained_attention"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["sustained_attention"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_shifting_items(target_count: int = 440) -> List[AttentionItem]:
    """Generate attention shifting items."""
    items = []

    for i in range(target_count):
        template = SHIFTING_TEMPLATES[i % len(SHIFTING_TEMPLATES)]
        level_idx = i % 5
        difficulty = calculate_phi_score(level_idx)

        # Switching cost (number of shifts)
        shifts = [1, 2, 3, 4, 5][level_idx]

        context = f"{template['context_1']} {template['context_2']}"

        item = AttentionItem(
            id=f"tagp_shift_{i:04d}",
            task=TASK_DESCRIPTONS["attention_shifting"]["name"],
            context=context,
            query=template["query"],
            distractor_count=shifts,
            expected_focus=template["expected"],
            difficulty=difficulty,
            brain_zone=TASK_DESCRIPTONS["attention_shifting"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["attention_shifting"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_needle_items(target_count: int = 440) -> List[AttentionItem]:
    """Generate adversarial needle items."""
    items = []

    for i in range(target_count):
        template = NEEDLE_TEMPLATES[i % len(NEEDLE_TEMPLATES)]
        level_idx = i % 5
        difficulty = calculate_phi_score(level_idx)

        # Decoy count increases with difficulty
        decoy_count = [1, 2, 3, 5, 8][level_idx]

        # Build haystack with decoys + needle
        haystack = template["haystack"].copy()
        haystack.append(template["needle"])
        random.shuffle(haystack)
        context = " | ".join(haystack)

        item = AttentionItem(
            id=f"tagp_needle_{i:04d}",
            task=TASK_DESCRIPTONS["adversarial_needle"]["name"],
            context=context,
            query=template["query"],
            distractor_count=decoy_count,
            expected_focus=template["expected"],
            difficulty=difficulty,
            brain_zone=TASK_DESCRIPTONS["adversarial_needle"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["adversarial_needle"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_divided_items(target_count: int = 440) -> List[AttentionItem]:
    """Generate divided attention items."""
    items = []

    for i in range(target_count):
        template = DIVIDED_TEMPLATES[i % len(DIVIDED_TEMPLATES)]
        level_idx = i % 5
        difficulty = calculate_phi_score(level_idx)

        # Dual-task cost (parallel difficulty)
        dual_cost = [1.0, 1.2, 1.5, 1.8, 2.0][level_idx]

        context = f"Stream 1: {template['stream_1']} | Stream 2: {template['stream_2']}"
        query = f"{template['query_1']} AND {template['query_2']}"

        item = AttentionItem(
            id=f"tagp_divided_{i:04d}",
            task=TASK_DESCRIPTONS["divided_attention"]["name"],
            context=context,
            query=query,
            distractor_count=int(dual_cost * 10),
            expected_focus=template["expected"],
            difficulty=difficulty * dual_cost,
            brain_zone=TASK_DESCRIPTONS["divided_attention"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["divided_attention"]["neural_analog"]
        )
        items.append(item)

    return items


def write_csv(items: List[AttentionItem], output_path: str):
    """Write items to CSV file."""
    fieldnames = [
        'id',
        'task',
        'context',
        'query',
        'distractor_count',
        'expected_focus',
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
        description='Generate Trinity Attentional Gateway Probe dataset'
    )
    parser.add_argument(
        '--output',
        type=str,
        default='data/tagp_attention.csv',
        help='Output CSV path'
    )
    parser.add_argument(
        '--count',
        type=int,
        default=2200,
        help='Number of items to generate (default: 2200)'
    )
    args = parser.parse_args()

    print(f"🧠 Trinity Attentional Gateway Probe Generator")
    print(f"📊 Target: {args.count} items")
    print(f"📏 φ-scaling: {FIBONACCI_LEVELS} (Fibonacci)")
    print(f"🧵 Brain Zones: THALAMUS, COLLICULUS, COERULEUS, RETICULAR")
    print()

    # Generate items for each task (440 per task = 2200 total)
    items_per_task = args.count // 5
    all_items = []

    all_items.extend(generate_filtering_items(items_per_task))
    all_items.extend(generate_sustained_items(items_per_task))
    all_items.extend(generate_shifting_items(items_per_task))
    all_items.extend(generate_needle_items(items_per_task))
    all_items.extend(generate_divided_items(items_per_task))

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
