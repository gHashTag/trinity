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
    # New fields for complexity
    distractor: str = ""
    note: str = ""
    ambiguity: str = ""
    hidden_rule: str = ""
    partial_credit_possible: bool = False


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


# Multi-step planning scenarios (increasing complexity) - COMPLICATED
PLANNING_SCENARIOS = [
    {
        "steps": 1,
        "context": "You need to open the file 'data.txt' and read its contents.",
        "actions": "1. Open file, 2. Read contents",
        "constraints": "File exists and is readable",
        "expected": "File contents read successfully",
        "hidden_constraint": "File might be locked by another process"
    },
    {
        "steps": 2,
        "context": "User wants to convert a CSV file to JSON. The CSV has headers.",
        "actions": "1. Parse CSV headers, 2. Read rows, 3. Convert to JSON structure",
        "constraints": "Valid CSV format, all rows converted",
        "expected": "JSON object with all data",
        "distractor": "Some rows may have missing fields - how to handle?"
    },
    {
        "steps": 3,
        "context": "Implement a function to sort a list of dictionaries by a specific key.",
        "actions": "1. Define function signature, 2. Implement sorting logic, 3. Handle edge cases",
        "constraints": "Correct sorting, handles None values, preserves stability",
        "expected": "Sorted list of dictionaries",
        "note": "Stable sort means equal elements keep original order"
    },
    {
        "steps": 5,
        "context": "Build a simple HTTP server that serves static files and handles API requests.",
        "actions": "1. Setup routing, 2. Implement static file serving, 3. Implement API endpoints, 4. Add error handling, 5. Add logging",
        "constraints": "Files served correctly, API responses valid, errors logged",
        "expected": "Functional HTTP server",
        "hidden_constraint": "Must handle concurrent requests (threading/async)"
    },
    {
        "steps": 8,
        "context": "Create a multi-stage CI/CD pipeline that builds, tests, deploys, and monitors.",
        "actions": "1. Configure build stage, 2. Setup test automation, 3. Add deployment triggers, 4. Implement monitoring, 5. Configure rollback, 6. Add notifications, 7. Setup secrets management, 8. Document pipeline",
        "constraints": "All stages work, rollback functional, monitoring active",
        "expected": "Complete CI/CD pipeline with all stages",
        "distractor": "Build fails 50% of time - how to handle partial success?"
    },
    {
        "steps": 13,
        "context": "Design and implement a distributed system with load balancing, caching, and fault tolerance.",
        "actions": "1. Design architecture, 2. Implement load balancer, 3. Add distributed cache, 4. Implement service discovery, 5. Add health checks, 6. Implement retry logic, 7. Add circuit breaker, 8. Setup distributed tracing, 9. Configure rate limiting, 10. Implement graceful degradation, 11. Add monitoring dashboard, 12. Write operational docs, 13. Design disaster recovery",
        "constraints": "System handles failures, load distributed, cache effective",
        "expected": "Production-ready distributed system",
        "ambiguity": "Cache coherence vs availability tradeoff - which to prioritize?"
    },
    {
        "steps": 21,
        "context": "Build an AGI system with multi-modal perception, reasoning, planning, and execution across multiple domains.",
        "actions": "1. Design perception layer, 2. Implement knowledge representation, 3. Build reasoning engine, 4. Create planning module, 5. Add execution interface, 6. Implement learning system, 7. Add metacognitive layer, 8. Create memory system, 9. Build attentional mechanism, 10. Implement social cognition, 11. Add language understanding, 12. Create visual processing, 13. Add tool use capability, 14. Implement safety constraints, 15. Add value alignment, 16. Create communication interface, 17. Add uncertainty handling, 18. Implement parallel execution, 19. Add hierarchical planning, 20. Create introspection system, 21. Integrate all modules",
        "constraints": "All modules functional, integrated behavior coherent, safety enforced",
        "expected": "Functional AGI system with aligned behavior",
        "note": "Impossible in practice - this tests response to impossible requirements"
    },
    # NEW: Ambiguous planning scenarios
    {
        "steps": 4,
        "context": "Optimize database queries. Some are slow, some return wrong data, some timeout.",
        "actions": "1. Identify problematic queries, 2. Add indexes, 3. Fix data issues, 4. Adjust timeouts",
        "constraints": "Cannot change schema, must maintain backward compatibility",
        "expected": "All queries < 100ms with correct results",
        "distractor": "Fixing one query might break another - cascading effects"
    },
    {
        "steps": 6,
        "context": "Migrate legacy system to new architecture while keeping old system running.",
        "actions": "1. Extract domain logic, 2. Implement new services, 3. Setup data sync, 4. Implement feature flags, 5. Gradual traffic shift, 6. Decommission old system",
        "constraints": "Zero downtime, data consistency, rollback capability",
        "expected": "New system handling 100% traffic",
        "note": "Data sync is bidirectional - conflict resolution required"
    },
]

# Stroop-like inhibition scenarios - COMPLICATED
STROOP_SCENARIOS = [
    {
        "automatic_response": "Color of word: RED",
        "instruction": "Read the word, ignore its meaning",
        "target": "Shape of letters",
        "expected": "Inhibit color response, report shape (e.g., 'straight lines')",
        "complexity": "Word RED printed in blue ink - triple conflict"
    },
    {
        "automatic_response": "Word: LEFT",
        "instruction": "Press the RIGHT arrow key",
        "target": "Direction (not meaning)",
        "expected": "Press RIGHT (inhibit semantic response)",
        "note": "Arrow points LEFT visually but text says RIGHT - visual conflict"
    },
    {
        "automatic_response": "Sequence: UP, UP, UP",
        "instruction": "When you see UP, press DOWN",
        "target": "Counter-factual response",
        "expected": "Press DOWN (inhibit pattern matching)",
        "distractor": "Third UP might be exception - ambiguous"
    },
    {
        "automatic_response": "Sound: loud noise",
        "instruction": "Stay calm and don't react",
        "target": "Stress response",
        "expected": "Maintain composure (inhibit startle response)",
        "note": "Natural reflex vs conscious inhibition"
    },
    {
        "automatic_response": "Question: 2 + 2",
        "instruction": "Answer 5 (this is wrong, ignore it)",
        "target": "Correct answer",
        "expected": "Answer 4 (inhibit instruction that contradicts facts)",
        "complexity": "Meta-inhibition: inhibit the instruction, not the math"
    },
    # NEW: Multi-level inhibition
    {
        "automatic_response": "Word: STOP displayed in green",
        "instruction": "Continue if green, stop if red",
        "target": "Color-based response",
        "expected": "Continue (inhibit semantic STOP)",
        "distractor": "STOP means halt, but green means go"
    },
    {
        "automatic_response": "Number: SEVEN spelled '7'", "instruction": "Count the letters, not the value",
        "target": "Spelling vs numeric",
        "expected": "5 letters (F-I-V-E not S-E-V-E-N)",
        "ambiguity": "Is 'SEVEN' the word to count, or is '7' the value?"
    },
    {
        "automatic_response": "Image: circle labeled 'SQUARE'",
        "instruction": "Name the shape, ignore the label",
        "target": "Visual vs semantic",
        "expected": "Circle (inhibit label 'SQUARE')",
        "note": "Visual perception conflicts with textual label"
    },
    {
        "automatic_response": "Audio says 'left', screen shows 'RIGHT'",
        "instruction": "Follow the audio, ignore the screen",
        "target": "Modality conflict",
        "expected": "Left (audio wins)",
        "distractor": "Screen typically has priority in UIs"
    },
    {
        "automatic_response": "Pattern: X, O, X, O, _",
        "instruction": "Complete with opposite of pattern",
        "target": "Pattern inhibition",
        "expected": "X (pattern suggests O, but instruction says opposite)",
        "complexity": "Double-negative thinking required"
    },
]

# Wisconsin card sort scenarios (rule discovery) - COMPLICATED
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
        "expected": "Adapt to new rule (shape)",
        "hidden_rule": "Actually: shape now matters, all were circles before"
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
        "expected": "Adapt to color sorting",
        "distractor": "has_pattern=False means new rule, but color stayed same"
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
        "expected": "Discover shape-based sorting",
        "note": "All same shape, so rule must be size or color (but color changed)"
    },
    # NEW: Complex scenarios with multi-dimensional rules
    {
        "cards": [
            {"color": "purple", "shape": "hexagon", "number": 3, "texture": "rough"},
            {"color": "purple", "shape": "hexagon", "number": 6, "texture": "rough"},
            {"color": "orange", "shape": "hexagon", "number": 9, "texture": "smooth"},
        ],
        "correct_sort": "number",
        "feedback": "Wrong, rule changed.",
        "new_cards": [
            {"color": "purple", "shape": "octagon", "number": 12, "texture": "rough"},
        ],
        "expected": "Rule: number of sides (hexagon=6, octagon=8)",
        "hidden_rule": "Shape complexity (number of sides), not named shapes"
    },
    {
        "cards": [
            {"value": "A", "priority": 1, "category": "urgent"},
            {"value": "B", "priority": 2, "category": "normal"},
            {"value": "C", "priority": 1, "category": "urgent"},
        ],
        "correct_sort": "priority",
        "feedback": "Wrong, rule evolved.",
        "new_cards": [
            {"value": "D", "priority": 3, "category": "low"},
        ],
        "expected": "Rule: category alphabetically (low < normal < urgent)",
        "distractor": "Priority 1,2,3 suggests numeric but actually categorical"
    },
    {
        "cards": [
            {"temp": "hot", "state": "gas", "color": "red"},
            {"temp": "warm", "state": "liquid", "color": "yellow"},
            {"temp": "cold", "state": "solid", "color": "blue"},
        ],
        "correct_sort": "temperature",
        "feedback": "Wrong, abstract rule.",
        "new_cards": [
            {"temp": "tepid", "state": "plasma", "color": "purple"},
        ],
        "expected": "Rule: color spectrum (ROYGBIV)",
        "hidden_rule": "Wavelength of color, not temperature or state"
    },
]

# Working memory span scenarios (φ-scaling: 3,5,8,13,21 items) - COMPLICATED
MEMORY_SCENARIOS = [
    {
        "items": 3,
        "data": ["apple", "banana", "cherry"],
        "operations": "Remember first item, count vowels in second, check if third is fruit",
        "expected": "apple, 3 (a, e, a), yes",
        "distractor": "cherry is also red, not just fruit"
    },
    {
        "items": 5,
        "data": ["42", "hello", "world", "3.14", "Python"],
        "operations": "Sum first two, reverse third, check if fourth > 3, identify fifth's type",
        "expected": "42 + 3.14 = 45.14, 'dlrow', yes (3.14 > 3), string",
        "note": "Order of operations matters: first+second means 42 + hello (invalid) OR index-based sum",
        "ambiguity": "Ambiguous: sum values or concatenate? Assume index 0+1: 42 (string) + hello = error"
    },
    {
        "items": 8,
        "data": ["cat", "dog", "bird", "fish", "elephant", "giraffe", "lion", "zebra"],
        "operations": "Filter mammals > 4 letters, count vowels in even indices, find word with 'z'",
        "expected": "elephant (8 letters), vowels: a (cat, idx 0), o (fish, idx 3), i (lion, idx 5), zebra has 'z'",
        "distractor": "Even indices (0,2,4,6): cat, bird, elephant, lion. Vowels: a, bird(2), elephant(4), lion(2) = 8 total"
    },
    {
        "items": 13,
        "data": list(range(1, 14)),  # 1-13
        "operations": "Find pairs summing to 13, multiply pairs, sum results, identify prime numbers",
        "expected": "Pairs: (1,12), (2,11), (3,10), (4,9), (5,8), (6,7). Products: 12,22,30,36,40,42. Sum: 182. Primes: 2, 3, 5, 7, 11, 13",
        "note": "Multiple valid pairings possible - must find ALL unique pairs"
    },
    {
        "items": 21,
        "data": [f"item_{i}" for i in range(21)],
        "operations": "Categorize items by letter count, sort alphabetically within groups, find median of each group, report total of medians",
        "expected": "Groups calculated, medians found, totals computed",
        "complexity": "21 items with same letter count means no sorting needed, median is middle item"
    },
    # NEW: Additional complicated scenarios
    {
        "items": 5,
        "data": ["0x1A", "42", "101", "3.14", "π"],
        "operations": "Convert all to decimal, identify which are prime, sort ascending",
        "expected": "3.14, 26, 42, 101 (π is irrational, not in sort)",
        "distractor": "0x1A = 26 (hex), 101 in binary = 5 in decimal (ambiguity)"
    },
    {
        "items": 7,
        "data": ["red+blue", "yellow", "green-blue", "orange-red", "purple", "cyan", "magenta"],
        "operations": "Identify primary colors, secondary colors, and ambiguous mixes",
        "expected": "Primary: yellow, cyan, magenta. Secondary: purple, green-blue, orange-red, red+blue",
        "note": "Color theory knowledge required"
    },
]

# Conflicting instruction scenarios (complicated - ambiguous or distractor-based)
CONFLICT_SCENARIOS = [
    {
        "instruction_1": "Always return lowercase",
        "instruction_2": "Capitalize proper nouns",
        "input": "What is the capital of France?",
        "expected": "Paris (conflict resolved: proper noun wins)",
        "distractor": "Note: 'France' could also mean the country, the currency, or historical references"
    },
    {
        "instruction_1": "Be concise (under 10 words)",
        "instruction_2": "Be thorough and detailed",
        "input": "Explain quantum entanglement",
        "expected": "Balanced response (detailed enough but not verbose)",
        "note": "Length constraint contradicts detail requirement - choose appropriately"
    },
    {
        "instruction_1": "Assume user is expert",
        "instruction_2": "Explain like to beginner",
        "input": "What is a neural network?",
        "expected": "Detect expertise level and adjust explanation accordingly",
        "note": "Context clues (age, domain) may indicate actual expertise level"
    },
    {
        "instruction_1": "Prioritize accuracy over speed",
        "instruction_2": "Respond as quickly as possible",
        "input": "Calculate sqrt(144) × 3",
        "expected": "Accuracy first: 36, speed secondary",
        "distractor": "Common error: 12 × 3 = 36, missing sqrt"
    },
    {
        "instruction_1": "Be creative and original",
        "instruction_2": "Stick to facts and be precise",
        "input": "What color is the sky?",
        "expected": "Factual answer: blue (not creative interpretation)",
        "distractor": "Sunset could be orange/pink/purple, daytime blue, night black/starry"
    },
    {
        "instruction_1": "Use metric system",
        "instruction_2": "Use imperial system",
        "input": "What is the distance to the moon?",
        "expected": "Metric: ~384,400 km (most precise)",
        "distractor": "Imperial: ~238,855 miles"
    },
    {
        "instruction_1": "Sort ascending",
        "instruction_2": "Sort by custom criteria",
        "input": "Sort these colors by wavelength: red, green, blue",
        "expected": "Red (longest wavelength, ~700nm)",
        "note": "Blue is shortest, Green is middle - depends on criterion"
    },
    {
        "instruction_1": "Add first",
        "instruction_2": "Multiply all results",
        "input": "List of 10 numbers",
        "expected": "Sum of all",
        "distractor": "Sum of first 10, ignoring others"
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

        # Build complexity fields
        distractor = scenario.get("distractor", "")
        note = scenario.get("note", "")
        ambiguity = scenario.get("ambiguity", "")
        hidden_rule = scenario.get("hidden_constraint", "")
        partial = "distractor" in scenario or "note" in scenario or "ambiguity" in scenario

        # Include complexity info in context
        context_enhanced = scenario["context"]
        if distractor:
            context_enhanced += f"\n[DI-STRACTOR] {distractor}"
        if note:
            context_enhanced += f"\n[NOTE] {note}"
        if ambiguity:
            context_enhanced += f"\n[AMBIGUOUS] {ambiguity}"
        if hidden_rule:
            context_enhanced += f"\n[HIDDEN] {hidden_rule}"

        item = ExecutiveItem(
            id=f"tefb_plan_{i:04d}",
            task=TASK_DESCRIPTONS["multi_step_planning"]["name"],
            context=context_enhanced,
            actions_needed=actions_needed,
            constraints=scenario["constraints"],
            expected_result=scenario["expected"],
            difficulty=difficulty * actions_needed,
            brain_zone=TASK_DESCRIPTONS["multi_step_planning"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["multi_step_planning"]["neural_analog"],
            distractor=distractor,
            note=note,
            ambiguity=ambiguity,
            hidden_rule=hidden_rule,
            partial_credit_possible=partial
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

        # Build complexity fields
        distractor = scenario.get("distractor", "")
        note = scenario.get("note", "")
        ambiguity = scenario.get("complexity", "")
        hidden_rule = scenario.get("hidden_rule", "")
        partial = "note" in scenario or "ambiguity" in scenario

        context = f"Automatic response: {scenario['automatic_response']}\nInstruction: {scenario['instruction']}\nTarget: {scenario['target']}"
        if distractor:
            context += f"\n[DI-STRACTOR] {distractor}"
        if note:
            context += f"\n[NOTE] {note}"
        if ambiguity:
            context += f"\n[COMPLEX] {ambiguity}"
        if hidden_rule:
            context += f"\n[HIDDEN] {hidden_rule}"

        item = ExecutiveItem(
            id=f"tefb_stroop_{i:04d}",
            task=TASK_DESCRIPTONS["stroop_inhibition"]["name"],
            context=context,
            actions_needed=inhibition_cost,
            constraints="Inhibit automatic response",
            expected_result=scenario["expected"],
            difficulty=difficulty * inhibition_cost,
            brain_zone=TASK_DESCRIPTONS["stroop_inhibition"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["stroop_inhibition"]["neural_analog"],
            distractor=distractor,
            note=note,
            ambiguity=ambiguity,
            hidden_rule=hidden_rule,
            partial_credit_possible=partial
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

        # Build complexity fields
        distractor = scenario.get("distractor", "")
        note = scenario.get("note", "")
        ambiguity = scenario.get("hidden_rule", "")
        hidden_rule = scenario.get("note", "")  # Use 'note' as hidden rule indicator
        partial = "distractor" in scenario or "note" in scenario

        context = f"Cards: {scenario['cards']}\nCorrect sort: {scenario['correct_sort']}\nFeedback: {scenario['feedback']}\nNew cards: {scenario['new_cards']}"
        if distractor:
            context += f"\n[DI-STRACTOR] {distractor}"
        if note:
            context += f"\n[NOTE] {note}"
        if ambiguity:
            context += f"\n[COMPLEX] {ambiguity}"
        if hidden_rule:
            context += f"\n[HIDDEN] {hidden_rule}"

        item = ExecutiveItem(
            id=f"tefb_wisco_{i:04d}",
            task=TASK_DESCRIPTONS["wisconsin_card_sort"]["name"],
            context=context,
            actions_needed=adaptation_cycles,
            constraints="Discover new rule from feedback",
            expected_result=scenario["expected"],
            difficulty=difficulty * adaptation_cycles,
            brain_zone=TASK_DESCRIPTONS["wisconsin_card_sort"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["wisconsin_card_sort"]["neural_analog"],
            distractor=distractor,
            note=note,
            ambiguity=ambiguity,
            hidden_rule=hidden_rule,
            partial_credit_possible=partial
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

        # Build complexity fields
        distractor = scenario.get("distractor", "")
        note = scenario.get("note", "")
        complexity = scenario.get("complexity", "")
        partial = "distractor" in scenario or "note" in scenario or "complexity" in scenario

        context = f"Data: {scenario['data']}\nOperations: {scenario['operations']}"
        if distractor:
            context += f"\n[DI-STRACTOR] {distractor}"
        if note:
            context += f"\n[NOTE] {note}"
        if complexity:
            context += f"\n[COMPLEX] {complexity}"

        item = ExecutiveItem(
            id=f"tefb_memory_{i:04d}",
            task=TASK_DESCRIPTONS["working_memory"]["name"],
            context=context,
            actions_needed=scenario["items"],
            constraints=f"Maintain {scenario['items']} items in working memory",
            expected_result=scenario["expected"],
            difficulty=difficulty * scenario["items"],
            brain_zone=TASK_DESCRIPTONS["working_memory"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["working_memory"]["neural_analog"],
            distractor=distractor,
            note=note,
            ambiguity=complexity,
            hidden_rule="",
            partial_credit_possible=partial
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

        # Build complexity fields
        distractor = scenario.get("distractor", "")
        note = scenario.get("note", "")
        ambiguity = scenario.get("ambiguity", "")
        partial = "distractor" in scenario or "note" in scenario or "ambiguity" in scenario

        context = f"Instruction 1: {scenario['instruction_1']}\nInstruction 2: {scenario['instruction_2']}\nInput: {scenario['input']}"
        if distractor:
            context += f"\n[DI-STRACTOR] {distractor}"
        if note:
            context += f"\n[NOTE] {note}"
        if ambiguity:
            context += f"\n[AMBIGUOUS] {ambiguity}"

        item = ExecutiveItem(
            id=f"tefb_conflict_{i:04d}",
            task=TASK_DESCRIPTONS["conflicting_instructions"]["name"],
            context=context,
            actions_needed=conflict_severity,
            constraints="Resolve conflict according to context",
            expected_result=scenario["expected"],
            difficulty=difficulty * conflict_severity,
            brain_zone=TASK_DESCRIPTONS["conflicting_instructions"]["brain_zone"],
            neural_analog=TASK_DESCRIPTONS["conflicting_instructions"]["neural_analog"],
            distractor=distractor,
            note=note,
            ambiguity=ambiguity,
            hidden_rule="",
            partial_credit_possible=partial
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
        'neural_analog',
        'distractor',
        'note',
        'ambiguity',
        'hidden_rule',
        'partial_credit_possible'
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
