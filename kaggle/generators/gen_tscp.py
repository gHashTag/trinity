#!/usr/bin/env python3
"""
Trinity Social Cognition Probe (TSCP) — Social Reasoning Generator
Track 5 of DeepMind AGI Hackathon
Brain Zones: INSULA + OFC + HABENULA + THEORYOFMIND

Generates 2200 test items with φ-scaling complexity gradient.
CSV format: id,task,scenario,perspective,expected_inference,difficulty,brain_zone,neural_analog
"""

import csv
import json
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional
import math
import random


@dataclass
class SocialItem:
    id: str
    task: str
    scenario: str
    perspective: str
    expected_inference: str
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


# Task descriptions for each sub-probe in Social Cognition track
TASK_DESCRIPTONS = {
    "theory_of_mind": {
        "name": "Theory of Mind — False Belief",
        "desc": "Model reasons about others' beliefs. TheoryOfMind perspective_taking with empathy_level.",
        "brain_zone": "tom",
        "neural_analog": "TheoryOfMind.modelOther() simulates other agent's mental state"
    },
    "pragmatic_inference": {
        "name": "Pragmatic Inference",
        "desc": "Model understands implied meaning. Wernicke comprehension for sarcasm/irony.",
        "brain_zone": "wernicke",
        "neural_analog": "Wernicke area comprehends non-literal language (sarcasm, irony)"
    },
    "audience_adaptation": {
        "name": "Audience Adaptation",
        "desc": "Model adjusts communication for audience. Broca generation with complexity control.",
        "brain_zone": "broca",
        "neural_analog": "Broca area adjusts complexity based on audience model"
    },
    "negotiation": {
        "name": "Negotiation",
        "desc": "Model reasons about fairness in trade. OFC + HABENULA fairness detection.",
        "brain_zone": "ofc",
        "neural_analog": "OFC + HABENULA.detectUnfair() evaluates social fairness"
    },
    "social_norms": {
        "name": "Implicit Social Norms",
        "desc": "Model understands cultural expectations. OFC social values system.",
        "brain_zone": "ofc",
        "neural_analog": "OFC social value system for cultural norm inference"
    }
}


# Theory of Mind — False Belief scenarios (Sally-Anne test variants)
TOM_SCENARIOS = [
    {
        "level": 1,
        "scenario": "Sally puts a toy in a basket and leaves. Anne moves the toy to a box. Sally returns.",
        "sally_belief": "Sally believes the toy is in the basket (false belief)",
        "actual_location": "box",
        "question": "Where will Sally look for the toy?",
        "expected": "basket (false belief)"
    },
    {
        "level": 2,
        "scenario": "John puts his keys on the table and goes outside. Mary moves the keys to a drawer. John's friend tells him 'Mary moved your keys.' John doesn't know where Mary moved them.",
        "john_belief": "John knows keys were moved but doesn't know location (second-order false belief)",
        "actual_location": "drawer",
        "question": "What does John believe about the keys?",
        "expected": "Keys were moved, but John doesn't know where"
    },
    {
        "level": 3,
        "scenario": "Alice tells Bob that a surprise party is at 5 PM. Bob tells Charlie it's at 5 PM. Alice changes time to 6 PM but doesn't tell Bob. Bob doesn't tell Charlie about the change.",
        "alice_belief": "Alice believes party is at 6 PM",
        "bob_belief": "Bob believes party is at 5 PM (false)",
        "charlie_belief": "Charlie believes party is at 5 PM (false, from Bob)",
        "question": "What time does Charlie think the party is?",
        "expected": "5 PM (inherited Bob's false belief)"
    },
    {
        "level": 4,
        "scenario": "Manager assigns Task A to Developer X and Task B to Developer Y. Manager emails X about changes to Task A but forgets to email Y. X and Y discuss tasks; X mentions the changes to Y. Manager assumes Y knows about changes.",
        "manager_belief": "Manager believes Y knows about changes (false)",
        "y_belief": "Y knows about changes (from X)",
        "question": "Does Manager have a correct model of Y's knowledge?",
        "expected": "No, Manager is correct by coincidence (Y knows, but not from Manager)"
    },
    {
        "level": 5,
        "scenario": "In a complex organization: CEO tells VP1 about strategy change. VP1 tells Director A, who tells Manager 1. CEO also tells VP2, who tells Director B, who tells Manager 2. Manager 1 and Manager 2 discuss. CEO assumes all managers know. But Director A was on vacation and didn't tell Manager 1 correctly.",
        "nested_beliefs": "CEO -> VP1 -> Director A (vacation) -> Manager 1 (misinformed) | CEO -> VP2 -> Director B -> Manager 2 (informed)",
        "question": "Which managers have correct information?",
        "expected": "Only Manager 2. Manager 1 is misinformed due to vacation gap."
    },
]

# Pragmatic inference scenarios (sarcasm, irony, implicature)
PRAGMATIC_SCENARIOS = [
    {
        "level": 1,
        "utterance": "Great weather for a picnic!",
        "context": "It's raining heavily outside.",
        "literal": "Weather is good for picnic",
        "implied": "sarcasm: Weather is bad for picnic",
        "expected": "sarcastic"
    },
    {
        "level": 2,
        "utterance": "I just love waiting in line for 3 hours.",
        "context": "Speaker looks frustrated and checks watch repeatedly.",
        "literal": "Speaker enjoys waiting",
        "implied": "irony: Speaker hates waiting",
        "expected": "ironic"
    },
    {
        "level": 3,
        "utterance": "Do you have the time?",
        "context": "Person approaches stranger on street.",
        "literal": "Question about possession of time",
        "implied": "Request to tell current time",
        "expected": "request for information"
    },
    {
        "level": 4,
        "utterance": "This soup is a bit spicy.",
        "context": "Diner at restaurant, soup is extremely hot, diner is coughing.",
        "literal": "Soup has some spice",
        "implied": "Understatement: Soup is too spicy",
        "expected": "understatement/litotes"
    },
    {
        "level": 5,
        "utterance": "Well, that went exactly as planned.",
        "context": "After a presentation where projector failed, laptop crashed, and speaker tripped on stage.",
        "literal": "Everything went according to plan",
        "implied": "sarcasm: Everything went wrong",
        "expected": "sarcastic with multiple failure cues"
    },
]

# Audience adaptation scenarios
AUDIENCE_SCENARIOS = [
    {
        "level": 1,
        "topic": "How a computer works",
        "audience": "5-year-old child",
        "complexity": "simple analogies, basic concepts",
        "expected": "Computer is like a brain that follows instructions"
    },
    {
        "level": 2,
        "topic": "How the internet works",
        "audience": "Grandparent who never used computers",
        "complexity": "avoid jargon, use familiar comparisons",
        "expected": "Internet is like a postal system for messages"
    },
    {
        "level": 3,
        "topic": "Blockchain technology",
        "audience": "Business executives",
        "complexity": "focus on business value, minimal technical detail",
        "expected": "Emphasize security, transparency, efficiency"
    },
    {
        "level": 4,
        "topic": "Quantum computing",
        "audience": "Physics undergraduate students",
        "complexity": "technical but accessible, use relevant analogies",
        "expected": "Discuss qubits, superposition, entanglement with some math"
    },
    {
        "level": 5,
        "topic": "Advanced machine learning",
        "audience": "ML research conference",
        "complexity": "highly technical, current research, equations expected",
        "expected": "Assume deep knowledge, discuss cutting-edge techniques"
    },
]

# Negotiation scenarios (fairness reasoning)
NEGOTIATION_SCENARIOS = [
    {
        "level": 1,
        "scenario": "Alice offers Bob $10 for an item worth $15. Bob counters at $12.",
        "alice_offer": 10,
        "item_value": 15,
        "bob_counter": 12,
        "fairness": "Both parties gain value",
        "expected": "Fair compromise: both benefit"
    },
    {
        "level": 2,
        "scenario": "Company offers employee $50K for role worth $70K market rate. Employee asks for $65K. Company says $55K final.",
        "market_value": 70000,
        "company_final": 55000,
        "employee_ask": 65000,
        "fairness": "Company lowballs, employee compromise",
        "expected": "Unfair: Company underpays relative to market"
    },
    {
        "level": 3,
        "scenario": "Three siblings inherit $300K. Sibling A cared for parents for 5 years. Sibling B visited monthly. Sibling C lived abroad with no contact.",
        "equal_split": 100K each,
        "effort_disparity": "A did most work, B some, C none",
        "fair_proposal": "A deserves largest share, B some, C minimal",
        "expected": "Equitable split: A > B > C"
    },
    {
        "level": 4,
        "scenario": "Startup: Founder A invested $100K and works full-time. Founder B invested $500K but doesn't work. Co-founder C joined with no investment but key technical skills.",
        "investments": "A: $100K, B: $500K, C: $0",
        "work": "A: full-time, B: none, C: key skills",
        "fair_split": "Consider both money AND contribution",
        "expected": "Complex equity: B for money, A for work, C for skills"
    },
    {
        "level": 5,
        "scenario": "International treaty: Country A reduces emissions 50% at high cost. Country B reduces 10% at low cost. Country C is developing and increases emissions. Climate impact: global but costs local.",
        "fairness_principle": "Common but differentiated responsibility",
        "historical_emissions": "A and B emitted most historically",
        "development_need": "C needs to develop",
        "expected": "A and B should reduce more, C gets allowance for development"
    },
]

# Social norm scenarios
NORM_SCENARIOS = [
    {
        "level": 1,
        "scenario": "Person enters elevator and sees another person inside.",
        "norm": "Acknowledge with nod or brief greeting",
        "violation": "Ignoring completely is rude",
        "expected": "Minimal acknowledgment expected"
    },
    {
        "level": 2,
        "scenario": "Guest arrives 15 minutes late to dinner party.",
        "norm": "Apologize for lateness",
        "cultural_variation": "Some cultures more time-flexible",
        "expected": "Apology appropriate in most Western contexts"
    },
    {
        "level": 3,
        "scenario": "Coworker's family member passed away. You see them at office.",
        "norm": "Express condolences, respect privacy",
        "violation": "Asking for details or treating as normal workday",
        "expected": "Brief sympathy, then give space"
    },
    {
        "level": 4,
        "scenario": "Business meeting in Japan. Foreign executive hands business card with one hand.",
        "norm": "Use both hands, receive with respect",
        "cultural_significance": "Business cards represent identity",
        "expected": "Two-handed exchange shows proper respect"
    },
    {
        "level": 5,
        "scenario": "Multi-cultural team meeting. Team member from high-context culture gives indirect feedback. Manager from low-context culture doesn't understand.",
        "norms_clash": "High-context: indirect communication valued. Low-context: directness expected.",
        "resolution": "Manager should recognize indirect feedback as meaningful",
        "expected": "Cultural competence: decode high-context communication"
    },
]


def generate_tom_items(target_count: int = 440) -> List[SocialItem]:
    """Generate Theory of Mind items."""
    items = []

    for i in range(target_count):
        # Cycle through scenarios by difficulty
        level_idx = i % len(TOM_SCENARIOS)
        scenario = TOM_SCENARIOS[level_idx]
        difficulty = calculate_phi_score(level_idx)

        # Perspective taking complexity (nesting level)
        perspective_complexity = scenario["level"]

        item = SocialItem(
            id=f"tscp_tom_{i:04d}",
            task=TASK_DESCRIPTONS["theory_of_mind"]["name"],
            scenario=scenario["scenario"],
            perspective=f"Level {scenario['level']} perspective taking",
            expected_inference=scenario["expected"],
            difficulty=difficulty * perspective_complexity,
            brain_zone=TASK_DESCRIPTONS["theory_of_mind"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["theory_of_mind"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_pragmatic_items(target_count: int = 440) -> List[SocialItem]:
    """Generate pragmatic inference items."""
    items = []

    for i in range(target_count):
        # Cycle through scenarios
        level_idx = i % len(PRAGMATIC_SCENARIOS)
        scenario = PRAGMATIC_SCENARIOS[level_idx]
        difficulty = calculate_phi_score(level_idx)

        # Context complexity (cues needed)
        context_cues = scenario["level"]

        context_str = f"Utterance: '{scenario['utterance']}'\nContext: {scenario['context']}"

        item = SocialItem(
            id=f"tscp_prag_{i:04d}",
            task=TASK_DESCRIPTONS["pragmatic_inference"]["name"],
            scenario=context_str,
            perspective=f"Level {scenario['level']} context cues",
            expected_inference=scenario["expected"],
            difficulty=difficulty * context_cues,
            brain_zone=TASK_DESCRIPTONS["pragmatic_inference"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["pragmatic_inference"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_audience_items(target_count: int = 440) -> List[SocialItem]:
    """Generate audience adaptation items."""
    items = []

    for i in range(target_count):
        # Cycle through scenarios
        level_idx = i % len(AUDIENCE_SCENARIOS)
        scenario = AUDIENCE_SCENARIOS[level_idx]
        difficulty = calculate_phi_score(level_idx)

        # Adaptation difficulty (knowledge gap)
        adaptation_gap = scenario["level"]

        scenario_str = f"Topic: {scenario['topic']}\nAudience: {scenario['audience']}\nRequired complexity: {scenario['complexity']}"

        item = SocialItem(
            id=f"tscp_aud_{i:04d}",
            task=TASK_DESCRIPTONS["audience_adaptation"]["name"],
            scenario=scenario_str,
            perspective=f"Level {scenario['level']} adaptation",
            expected_inference=scenario["expected"],
            difficulty=difficulty * adaptation_gap,
            brain_zone=TASK_DESCRIPTONS["audience_adaptation"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["audience_adaptation"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_negotiation_items(target_count: int = 440) -> List[SocialItem]:
    """Generate negotiation items."""
    items = []

    for i in range(target_count):
        # Cycle through scenarios
        level_idx = i % len(NEGOTIATION_SCENARIOS)
        scenario = NEGOTIATION_SCENARIOS[level_idx]
        difficulty = calculate_phi_score(level_idx)

        # Fairness reasoning complexity
        fairness_complexity = scenario["level"]

        item = SocialItem(
            id=f"tscp_neg_{i:04d}",
            task=TASK_DESCRIPTONS["negotiation"]["name"],
            scenario=scenario["scenario"],
            perspective=f"Level {scenario['level']} fairness reasoning",
            expected_inference=scenario["expected"],
            difficulty=difficulty * fairness_complexity,
            brain_zone=TASK_DESCRIPTONS["negotiation"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["negotiation"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_norm_items(target_count: int = 440) -> List[SocialItem]:
    """Generate social norm items."""
    items = []

    for i in range(target_count):
        # Cycle through scenarios
        level_idx = i % len(NORM_SCENARIOS)
        scenario = NORM_SCENARIOS[level_idx]
        difficulty = calculate_phi_score(level_idx)

        # Cultural complexity
        cultural_complexity = scenario["level"]

        item = SocialItem(
            id=f"tscp_norm_{i:04d}",
            task=TASK_DESCRIPTONS["social_norms"]["name"],
            scenario=scenario["scenario"],
            perspective=f"Level {scenario['level']} cultural awareness",
            expected_inference=scenario["expected"],
            difficulty=difficulty * cultural_complexity,
            brain_zone=TASK_DESCRIPTONS["social_norms"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["social_norms"]["neural_analog"]
        )
        items.append(item)

    return items


def write_csv(items: List[SocialItem], output_path: str):
    """Write items to CSV file."""
    fieldnames = [
        'id',
        'task',
        'scenario',
        'perspective',
        'expected_inference',
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
        description='Generate Trinity Social Cognition Probe dataset'
    )
    parser.add_argument(
        '--output',
        type=str,
        default='data/tscp_social.csv',
        help='Output CSV path'
    )
    parser.add_argument(
        '--count',
        type=int,
        default=2200,
        help='Number of items to generate (default: 2200)'
    )
    args = parser.parse_args()

    print(f"🧠 Trinity Social Cognition Probe Generator")
    print(f"📊 Target: {args.count} items")
    print(f"📏 φ-scaling: {FIBONACCI_LEVELS} (Fibonacci)")
    print(f"🧵 Brain Zones: INSULA, OFC, HABENULA, THEORYOFMIND")
    print()

    # Generate items for each task (440 per task = 2200 total)
    items_per_task = args.count // 5
    all_items = []

    all_items.extend(generate_tom_items(items_per_task))
    all_items.extend(generate_pragmatic_items(items_per_task))
    all_items.extend(generate_audience_items(items_per_task))
    all_items.extend(generate_negotiation_items(items_per_task))
    all_items.extend(generate_norm_items(items_per_task))

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
