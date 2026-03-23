#!/usr/bin/env python3
"""
Trinity Executive Function Battery (TEFB) — Executive Planning Generator
Track 4 of DeepMind AGI Hackathon
Brain Zones: CORTEX + DLPFC + PALLIDUS + STRIATUM + NIGRA

Generates 2400 test items with φ-scaling complexity gradient.
CSV format: id,task,context,actions_needed,constraints,expected_result,difficulty,brain_zone,neural_analog
"""

import csv
import json
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional
import math
import random


@dataclass
class ExecutiveItem:
    id: str
    task: str
    context: str
    actions_needed: int
    constraints: str
    expected_result: str
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


# Task descriptions for each sub-probe in Executive Functions track
TASK_DESCRIPTONS = {
    "multi_step_planning": {
        "name": "Multi-Step Planning",
        "desc": "Model plans sequences of actions. Cortex planning with GoldenChain pipeline (28 links).",
        "brain_zone": "cortex",
        "neural_analog": "Cortex GoldenChain executes 28-link agentic pipeline with role-based coordination"
    },
    "stroop_inhibition": {
        "name": "Stroop-like Inhibition",
        "desc": "Model inhibits automatic responses. Pallidus GABA gate for response suppression.",
        "brain_zone": "pallidus",
        "neural_analog": "Pallidus OFC.checkDestructiveness() inhibits impulsive actions"
    },
    "wisconsin_card_sort": {
        "name": "Wisconsin Card Sort",
        "desc": "Model discovers and adapts to rules. Striatum Experience Engine pattern adaptation.",
        "brain_zone": "striatum",
        "neural_analog": "Striatum Experience Engine adapts patterns based on feedback"
    },
    "working_memory": {
        "name": "Working Memory Span",
        "desc": "Model maintains information temporarily. DLPFC with φ-scaling: 3,5,8,13,21 items.",
        "brain_zone": "dlpfc",
        "neural_analog": "DLPFC maintains items with Fibonacci capacity scaling"
    },
    "conflicting_instructions": {
        "name": "Conflicting Instructions",
        "desc": "Model resolves contradictory directives. Nigra + ACC conflict resolution.",
        "brain_zone": "nigra",
        "neural_analog": "NIGRA + ACC.verifySafeToAction() resolves action conflicts"
    }
}


# Multi-step planning scenarios (increasing complexity)
PLANNING_SCENARIOS = [
    {
        "steps": 1,
        "context": "You need to open the file 'data.txt' and read its contents.",
        "actions": "1. Open file, 2. Read contents",
        "constraints": "File exists and is readable",
        "expected": "File contents read successfully"
    },
    {
        "steps": 2,
        "context": "User wants to convert a CSV file to JSON. The CSV has headers.",
        "actions": "1. Parse CSV headers, 2. Read rows, 3. Convert to JSON structure",
        "constraints": "Valid CSV format, all rows converted",
        "expected": "JSON object with all data"
    },
    {
        "steps": 3,
        "context": "Implement a function to sort a list of dictionaries by a specific key.",
        "actions": "1. Define function signature, 2. Implement sorting logic, 3. Handle edge cases",
        "constraints": "Correct sorting, handles None values, preserves stability",
        "expected": "Sorted list of dictionaries"
    },
    {
        "steps": 5,
        "context": "Build a simple HTTP server that serves static files and handles API requests.",
        "actions": "1. Setup routing, 2. Implement static file serving, 3. Implement API endpoints, 4. Add error handling, 5. Add logging",
        "constraints": "Files served correctly, API responses valid, errors logged",
        "expected": "Functional HTTP server"
    },
    {
        "steps": 8,
        "context": "Create a multi-stage CI/CD pipeline that builds, tests, deploys, and monitors.",
        "actions": "1. Configure build stage, 2. Setup test automation, 3. Add deployment triggers, 4. Implement monitoring, 5. Configure rollback, 6. Add notifications, 7. Setup secrets management, 8. Document pipeline",
        "constraints": "All stages work, rollback functional, monitoring active",
        "expected": "Complete CI/CD pipeline with all stages"
    },
    {
        "steps": 13,
        "context": "Design and implement a distributed system with load balancing, caching, and fault tolerance.",
        "actions": "1. Design architecture, 2. Implement load balancer, 3. Add distributed cache, 4. Implement service discovery, 5. Add health checks, 6. Implement retry logic, 7. Add circuit breaker, 8. Setup distributed tracing, 9. Configure rate limiting, 10. Implement graceful degradation, 11. Add monitoring dashboard, 12. Write operational docs, 13. Design disaster recovery",
        "constraints": "System handles failures, load distributed, cache effective",
        "expected": "Production-ready distributed system"
    },
    {
        "steps": 21,
        "context": "Build an AGI system with multi-modal perception, reasoning, planning, and execution across multiple domains.",
        "actions": "1. Design perception layer, 2. Implement knowledge representation, 3. Build reasoning engine, 4. Create planning module, 5. Add execution interface, 6. Implement learning system, 7. Add metacognitive layer, 8. Create memory system, 9. Build attentional mechanism, 10. Implement social cognition, 11. Add language understanding, 12. Create visual processing, 13. Add tool use capability, 14. Implement safety constraints, 15. Add value alignment, 16. Create communication interface, 17. Add uncertainty handling, 18. Implement parallel execution, 19. Add hierarchical planning, 20. Create introspection system, 21. Integrate all modules",
        "constraints": "All modules functional, integrated behavior coherent, safety enforced",
        "expected": "Functional AGI system with aligned behavior"
    },
]

# Stroop-like inhibition scenarios
STROOP_SCENARIOS = [
    {
        "automatic_response": "Color of word: RED",
        "instruction": "Read the word, ignore its meaning",
        "target": "Shape of letters",
        "expected": "Inhibit color response, report shape (e.g., 'straight lines')"
    },
    {
        "automatic_response": "Word: LEFT",
        "instruction": "Press the RIGHT arrow key",
        "target": "Direction (not meaning)",
        "expected": "Press RIGHT (inhibit semantic response)"
    },
    {
        "automatic_response": "Sequence: UP, UP, UP",
        "instruction": "When you see UP, press DOWN",
        "target": "Counter-factual response",
        "expected": "Press DOWN (inhibit pattern matching)"
    },
    {
        "automatic_response": "Sound: loud noise",
        "instruction": "Stay calm and don't react",
        "target": "Stress response",
        "expected": "Maintain composure (inhibit startle response)"
    },
    {
        "automatic_response": "Question: 2 + 2",
        "instruction": "Answer 5 (this is wrong, ignore it)",
        "target": "Correct answer",
        "expected": "Answer 4 (inhibit instruction that contradicts facts)"
    },
]

# Wisconsin card sort scenarios (rule discovery)
WISCONSIN_SCENARIOS = [
    {
        "cards": [
            {"color": "red", "shape": "circle", "number": 1},
            {"color": "red", "shape": "circle", "number": 2},
            {"color": "red", "shape": "circle", "number": 3},
        ],
        "correct_sort": "number",
        "feedback": "Wrong. Try another rule.",
        "new_cards": [
            {"color": "red", "shape": "circle", "number": 4},
        ],
        "expected": "Adapt to new rule (shape)"
    },
    {
        "cards": [
            {"color": "blue", "shape": "square", "has_pattern": True},
            {"color": "blue", "shape": "square", "has_pattern": True},
        ],
        "correct_sort": "has_pattern",
        "feedback": "Wrong. Rule changed.",
        "new_cards": [
            {"color": "blue", "shape": "square", "has_pattern": False},
        ],
        "expected": "Adapt to color sorting"
    },
    {
        "cards": [
            {"color": "green", "shape": "triangle", "size": "small"},
            {"color": "green", "shape": "triangle", "size": "small"},
            {"color": "green", "shape": "triangle", "size": "large"},
        ],
        "correct_sort": "color",
        "feedback": "Wrong. New sorting required.",
        "new_cards": [
            {"color": "green", "shape": "triangle", "size": "small"},
            {"color": "yellow", "shape": "triangle", "size": "small"},
        ],
        "expected": "Discover shape-based sorting"
    },
]

# Working memory span scenarios (φ-scaling: 3,5,8,13,21 items)
MEMORY_SCENARIOS = [
    {
        "items": 3,
        "data": ["apple", "banana", "cherry"],
        "operations": "Remember first item, count vowels in second, check if third is fruit",
        "expected": "apple, 3 (a, e, a), yes"
    },
    {
        "items": 5,
        "data": ["42", "hello", "world", "3.14", "Python"],
        "operations": "Sum first two, reverse third, check if fourth > 3, identify fifth's type",
        "expected": "42 + 3.14 = 45.14, 'dlrow', yes (3.14 > 3), string"
    },
    {
        "items": 8,
        "data": ["cat", "dog", "bird", "fish", "elephant", "giraffe", "lion", "zebra"],
        "operations": "Filter mammals > 4 letters, count vowels in even indices, find word with 'z'",
        "expected": "elephant (8 letters), vowels: a (cat), o (fish), i (lion), zebra has 'z'"
    },
    {
        "items": 13,
        "data": list(range(1, 14)),  # 1-13
        "operations": "Find pairs summing to 13, multiply pairs, sum results, identify prime numbers",
        "expected": "Pairs: (1,12), (2,11), (3,10), (4,9), (5,8), (6,7). Products: 12,22,30,36,40,42. Sum: 182. Primes: 2, 3, 5, 7, 11, 13"
    },
    {
        "items": 21,
        "data": [f"item_{i}" for i in range(21)],
        "operations": "Categorize items by letter count, sort alphabetically within groups, find median of each group, report total of medians",
        "expected": "Groups calculated, medians found, totals computed"
    },
]

# Conflicting instruction scenarios
CONFLICT_SCENARIOS = [
    {
        "instruction_1": "Always return lowercase",
        "instruction_2": "Capitalize proper nouns",
        "input": "What is the capital of France?",
        "expected": "Paris (conflict resolved: proper noun wins)"
    },
    {
        "instruction_1": "Be concise (under 10 words)",
        "instruction_2": "Be thorough and detailed",
        "input": "Explain quantum entanglement",
        "expected": "Balanced response (detailed enough but not verbose)"
    },
    {
        "instruction_1": "Assume user is expert",
        "instruction_2": "Explain like to beginner",
        "input": "What is a neural network?",
        "expected": "Detect expertise level and adjust explanation accordingly"
    },
    {
        "instruction_1": "Prioritize accuracy over speed",
        "instruction_2": "Respond as quickly as possible",
        "input": "Calculate sqrt(144) × 3",
        "expected": "Accuracy first: 36, speed secondary"
    },
    {
        "instruction_1": "Be creative and original",
        "instruction_2": "Stick to facts and be precise",
        "input": "What color is the sky?",
        "expected": "Factual answer: blue (not creative interpretation)"
    },
]


def generate_planning_items(target_count: int = 480) -> List[ExecutiveItem]:
    """Generate multi-step planning items."""
    items = []

    for i in range(target_count):
        # Select scenario by Fibonacci level
        level_idx = i % len(PLANNING_SCENARIOS)
        scenario = PLANNING_SCENARIOS[level_idx]
        difficulty = calculate_phi_score(level_idx)

        actions_needed = scenario["steps"]

        item = ExecutiveItem(
            id=f"tefb_plan_{i:04d}",
            task=TASK_DESCRIPTONS["multi_step_planning"]["name"],
            context=scenario["context"],
            actions_needed=actions_needed,
            constraints=scenario["constraints"],
            expected_result=scenario["expected"],
            difficulty=difficulty * actions_needed,
            brain_zone=TASK_DESCRIPTONS["multi_step_planning"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["multi_step_planning"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_stroop_items(target_count: int = 480) -> List[ExecutiveItem]:
    """Generate Stroop-like inhibition items."""
    items = []

    for i in range(target_count):
        scenario = STROOP_SCENARIOS[i % len(STROOP_SCENARIOS)]
        level_idx = i % 5
        difficulty = calculate_phi_score(level_idx)

        # Difficulty based on inhibition strength needed
        inhibition_cost = [1, 2, 3, 4, 5][level_idx]

        context = f"Automatic response: {scenario['automatic_response']}\nInstruction: {scenario['instruction']}\nTarget: {scenario['target']}"

        item = ExecutiveItem(
            id=f"tefb_stroop_{i:04d}",
            task=TASK_DESCRIPTONS["stroop_inhibition"]["name"],
            context=context,
            actions_needed=inhibition_cost,
            constraints="Inhibit automatic response",
            expected_result=scenario["expected"],
            difficulty=difficulty * inhibition_cost,
            brain_zone=TASK_DESCRIPTONS["stroop_inhibition"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["stroop_inhibition"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_wisconsin_items(target_count: int = 480) -> List[ExecutiveItem]:
    """Generate Wisconsin card sort items."""
    items = []

    for i in range(target_count):
        scenario = WISCONSIN_SCENARIOS[i % len(WISCONSIN_SCENARIOS)]
        level_idx = i % 5
        difficulty = calculate_phi_score(level_idx)

        # Adaptation attempts (how many feedback cycles)
        adaptation_cycles = [1, 2, 3, 5, 8][level_idx]

        context = f"Cards: {scenario['cards']}\nCorrect sort: {scenario['correct_sort']}\nFeedback: {scenario['feedback']}\nNew cards: {scenario['new_cards']}"

        item = ExecutiveItem(
            id=f"tefb_wisco_{i:04d}",
            task=TASK_DESCRIPTONS["wisconsin_card_sort"]["name"],
            context=context,
            actions_needed=adaptation_cycles,
            constraints="Discover new rule from feedback",
            expected_result=scenario["expected"],
            difficulty=difficulty * adaptation_cycles,
            brain_zone=TASK_DESCRIPTONS["wisconsin_card_sort"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["wisconsin_card_sort"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_memory_items(target_count: int = 480) -> List[ExecutiveItem]:
    """Generate working memory span items."""
    items = []

    for i in range(target_count):
        # Select scenario by Fibonacci level (3,5,8,13,21)
        level_idx = i % len(MEMORY_SCENARIOS)
        scenario = MEMORY_SCENARIOS[level_idx]
        difficulty = calculate_phi_score(level_idx)

        context = f"Data: {scenario['data']}\nOperations: {scenario['operations']}"

        item = ExecutiveItem(
            id=f"tefb_memory_{i:04d}",
            task=TASK_DESCRIPTONS["working_memory"]["name"],
            context=context,
            actions_needed=scenario["items"],
            constraints=f"Maintain {scenario['items']} items in working memory",
            expected_result=scenario["expected"],
            difficulty=difficulty * scenario["items"],
            brain_zone=TASK_DESCRIPTONS["working_memory"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["working_memory"]["neural_analog"]
        )
        items.append(item)

    return items


def generate_conflict_items(target_count: int = 480) -> List[ExecutiveItem]:
    """Generate conflicting instruction items."""
    items = []

    for i in range(target_count):
        scenario = CONFLICT_SCENARIOS[i % len(CONFLICT_SCENARIOS)]
        level_idx = i % 5
        difficulty = calculate_phi_score(level_idx)

        # Conflict severity (how contradictory)
        conflict_severity = [1, 2, 3, 4, 5][level_idx]

        context = f"Instruction 1: {scenario['instruction_1']}\nInstruction 2: {scenario['instruction_2']}\nInput: {scenario['input']}"

        item = ExecutiveItem(
            id=f"tefb_conflict_{i:04d}",
            task=TASK_DESCRIPTONS["conflicting_instructions"]["name"],
            context=context,
            actions_needed=conflict_severity,
            constraints="Resolve conflict according to context",
            expected_result=scenario["expected"],
            difficulty=difficulty * conflict_severity,
            brain_zone=TASK_DESCRIPTONS["conflicting_instructions"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["conflicting_instructions"]["neural_analog"]
        )
        items.append(item)

    return items


def write_csv(items: List[ExecutiveItem], output_path: str):
    """Write items to CSV file."""
    fieldnames = [
        'id',
        'task',
        'context',
        'actions_needed',
        'constraints',
        'expected_result',
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
        description='Generate Trinity Executive Function Battery dataset'
    )
    parser.add_argument(
        '--output',
        type=str,
        default='data/tefb_executive.csv',
        help='Output CSV path'
    )
    parser.add_argument(
        '--count',
        type=int,
        default=2400,
        help='Number of items to generate (default: 2400)'
    )
    args = parser.parse_args()

    print(f"🧠 Trinity Executive Function Battery Generator")
    print(f"📊 Target: {args.count} items")
    print(f"📏 φ-scaling: {FIBONACCI_LEVELS} (Fibonacci)")
    print(f"🧵 Brain Zones: CORTEX, DLPFC, PALLIDUS, STRIATUM, NIGRA")
    print()

    # Generate items for each task (480 per task = 2400 total)
    items_per_task = args.count // 5
    all_items = []

    all_items.extend(generate_planning_items(items_per_task))
    all_items.extend(generate_stroop_items(items_per_task))
    all_items.extend(generate_wisconsin_items(items_per_task))
    all_items.extend(generate_memory_items(items_per_task))
    all_items.extend(generate_conflict_items(items_per_task))

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
