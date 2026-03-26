# Kaggle Hackathon — AGI Benchmarking with ARC-AGI (2025)

**Date**: 2026-03-26
**Version**: 1.0
**Status**: Latest Frontier AGI Research

---

## Overview

**ARC-AGI** (Abstraction and Reasoning Corpus) is the most important unsolved AI benchmark. Created by François Chollet, it measures **fluid intelligence** — the ability to generalize from minimal examples to novel tasks.

**Key Insight**: Intelligence is **skill-acquisition efficiency**, not just capability.

---

## 1. ARC-AGI vs Traditional Benchmarks ⭐⭐⭐

| Dimension | Traditional (MMLU, etc.) | ARC-AGI |
|-----------|---------------------------|---------|
| **Measures** | Knowledge memorization | Fluid intelligence |
| **Training** | Billions of examples | Few-shot (2-5 demos) |
| **Evaluation** | Same distribution | Novel tasks |
| **Solution** | Pattern matching | True reasoning |
| **Ceiling** | Saturated (90%+) | Unsolved (<55%) |
| **Human perf** | ~90% | ~75% |
| **AI perf (2025)** | ~88% | ~5-55% (method-dependent) |

---

## 2. ARC-AGI-2 (Current Version) ⭐⭐⭐

**Released**: March 2025
**Status**: Pure LLMs score 0%, AI systems <30% (public), 55.5% (private, refined)

### Key Differences from ARC-AGI-1

| Feature | ARC-AGI-1 | ARC-AGI-2 |
|---------|-----------|-----------|
| Grid size | Up to 20×20 | Up to 30×30 |
| Tasks | Single-rule | Multi-rule, compositional |
| Context | None | Context-conditioned |
| Human baseline | 75% | 62% |
| AI baseline (2024) | 33% | <5% |

### Task Categories

1. **Color-based**: Color transformations, hue rotation
2. **Geometric**: Shapes, sizes, positions, rotations
3. **Compositional**: Multiple rules combined
4. **Contextual**: Rules that depend on grid position
5. **Symbolic**: Symbol definition and application

### Evaluation Format

```python
def arc_agi2_format(
    task_input: Dict,  # {input_grid, output_grid, demo_pairs}
    max_predictions: int = 2  # Pass@2 format
) -> List[str]:
    """
    ARC-AGI-2 evaluation format.

    Returns list of JSON-encoded output grids (max 2 predictions).
    """
    demo_input = task_input['demo_input']  # List of example inputs
    demo_output = task_input['demo_output']  # Corresponding outputs
    test_input = task_input['test_input']  # Grid to solve

    # Format for submission
    return [
        json.dumps({
            "input": test_input.tolist(),
            "output": prediction.tolist()
        })
        for prediction in predictions
    ]
```

---

## 3. Winning Approaches (ARC Prize 2025)

### 3.1 Deep Learning-Guided Program Synthesis

**Principle**: Use LLM to guide discrete program search.

```python
def dl_guided_synthesis(
    task: Dict,
    llm,
    dsl: str,  # ARC-DSL or similar
    n_programs: int = 10000
) -> Dict:
    """
    Deep learning-guided program synthesis.

    Top approach from ARC Prize 2024.
    """
    # 1. Use LLM to propose candidate programs
    prompt = f"""
Given input grid {task['demo_input']}, output grid {task['demo_output']},
write a {dsl} program that transforms input to output:
"""

    # 2. Generate and execute programs
    candidates = []
    for _ in range(n_programs):
        program = llm.generate(prompt)

        # Execute on test input
        try:
            result = execute_dsl(program, task['test_input'])
            candidates.append((program, result))
        except Exception as e:
            continue

    # 3. Score and select best
    best = min(candidates, key=lambda x: score_result(x[1], task['test_output']))

    return best
```

### 3.2 Test-Time Training (TTT) / Test-Time Fine-Tuning (TTFT)

**Principle**: Adapt model to each task at inference time.

```python
def test_time_training(
    model,
    task: Dict,
    n_steps: int = 100,
    lr: float = 1e-4
) -> Dict:
    """
    Test-time training (dominant approach in 2024-2025).

    Key: Fine-tune on demonstration examples, not on test input.
    """
    # Prepare training data from demos
    train_x = np.array(task['demo_input'])
    train_y = np.array(task['demo_output'])

    # Create optimizer
    optimizer = torch.optim.AdamW(model.parameters(), lr=lr)

    # Fine-tune
    model.train()
    for step in range(n_steps):
        pred = model(train_x)
        loss = F.mse_loss(pred, train_y)

        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

    # Evaluate on test input
    with torch.no_grad():
        prediction = model(task['test_input'])

    return {
        'prediction': prediction,
        'loss': loss.item()
    }
```

### 3.3 Product-of-Experts Ensemble

**Principle**: Multiple specialized models voted.

```python
def product_of_experts(
    task: Dict,
    experts: List,
    voting: str = "soft"
) -> Dict:
    """
    Product-of-Experts ensemble approach.

    From "Product of Experts with LLMs" (2025):
    - Multiple specialized models
    - Weighted voting
    - Perspective-based scoring
    """
    # Get predictions from all experts
    predictions = [expert.solve(task) for expert in experts]

    if voting == "hard":
        # Majority voting (with tie-breaking)
        from collections import Counter
        votes = [pred['output_grid'] for pred in predictions]
        winner = Counter(votes).most_common(1)[0][0]
        return {'output_grid': winner}

    elif voting == "soft":
        # Weighted average (by confidence)
        weights = [pred['confidence'] for pred in predictions]
        weighted_sum = sum(w * p['output_grid'] for w, p in zip(weights, predictions))
        avg_weight = sum(weights)
        return {
            'output_grid': weighted_sum / avg_weight,
            'confidence': np.mean(weights)
        }
```

### 3.4 Neural Cellular Automata

**Principle**: Cellular automata for grid transformation.

```python
def neural_cellular_automata(
    task: Dict,
    nca_steps: int = 100,
    hidden_dim: int = 128
) -> Dict:
    """
    Neural Cellular Automata (NCA) approach.

    Key: Learned update rules applied iteratively.
    """
    # Initialize NCA model
    model = NCA(input_shape=task['demo_input'][0].shape, hidden_dim=hidden_dim)

    # Train on demo pairs
    for demo_in, demo_out in zip(task['demo_input'], task['demo_output']):
        model.fit(demo_in, demo_out, n_steps=nca_steps)

    # Apply to test input
    test_input = task['test_input']
    prediction = model.generate(test_input, n_steps=nca_steps)

    return {'output_grid': prediction}
```

---

## 4. Efficiency Measurement ⭐⭐⭐

**Critical Insight**: Intelligence = Capability / Cost

From ARC-AGI-2 design:
> "Intelligence is not solely defined by the ability to solve problems or achieve high scores. The efficiency with which those capabilities are acquired and deployed is a crucial, defining component."

### Efficiency Metrics

```python
def efficiency_evaluation(
    method: Callable,
    tasks: List[Dict],
    cost_tracker: CostTracker
) -> Dict:
    """
    Evaluate method on ARC-AGI-2 with efficiency metrics.

    Metrics:
    - solve_rate: Fraction of tasks solved
    - avg_cost: Average cost per task
    - cost_per_solved: Cost divided by solved count
    - efficiency: solve_rate / log(avg_cost + 1)
    """
    results = []
    total_cost = 0.0
    solved = 0

    for task in tasks:
        # Track compute
        with cost_tracker.track() as cost:
            prediction = method(task)
            is_correct = verify_arc_agi(prediction, task['test_output'])

        total_cost += cost.total_cost

        results.append({
            'task_id': task['id'],
            'correct': is_correct,
            'cost': cost.total_cost,
            'time': cost.time_elapsed
        })

        if is_correct:
            solved += 1

    solve_rate = solved / len(tasks)
    avg_cost = total_cost / len(tasks)

    return {
        'solve_rate': solve_rate,
        'avg_cost': avg_cost,
        'cost_per_solved': total_cost / max(solved, 1),
        'efficiency': solve_rate / math.log(avg_cost + 1),
        'results': results
    }

def verify_arc_agi(prediction, ground_truth) -> bool:
    """
    Verify ARC-AGI prediction (pixel-perfect match required).
    """
    pred_grid = np.array(prediction['output_grid'])
    truth_grid = np.array(ground_truth['test_output'])

    return np.array_equal(pred_grid, truth_grid)
```

---

## 5. ARC-AGI-3 Preview (Coming 2026) ⭐⭐⭐

**Release**: Early 2026
**New Capabilities Required**:
- Exploration (multi-step reasoning)
- Planning (search with goals)
- Memory (store/retrieve information)
- Goal Acquisition (infer what to do)
- Alignment (understand intent)

### Interactive Reasoning

```python
def interactive_arc_agi3(
    initial_state: Dict,
    goal: Dict,
    model,
    max_interactions: int = 10
) -> Dict:
    """
    ARC-AGI-3: Interactive reasoning tasks.

    Unlike ARC-AGI-1/2 (static), ARC-AGI-3 requires:
    - Exploration: Try actions, observe results
    - Planning: Plan multi-step solutions
    - Memory: Remember previous observations
    - Goal Acquisition: Infer the goal from context
    """
    memory = {}
    state = initial_state

    for step in range(max_interactions):
        # Goal acquisition: infer what to do
        if goal is None:
            goal = infer_goal(state, memory)

        # Planning: Plan next action
        action = plan_action(state, goal, memory)

        # Execute action
        new_state, observation = execute_action(state, action)

        # Memory: Store observation
        memory[step] = {
            'state': state,
            'action': action,
            'observation': observation,
            'new_state': new_state
        }

        state = new_state

        # Check if goal achieved
        if is_goal_achieved(state, goal):
            return {
                'success': True,
                'steps': step + 1,
                'memory': memory
            }

    return {
        'success': False,
        'steps': max_interactions,
        'memory': memory
    }
```

---

## 6. Knowledge Coverage Analysis ⭐⭐

**Finding**: AI performance on ARC-AGI is **fundamentally constrained by knowledge coverage**.

```python
def knowledge_coverage_analysis(
    model,
    arc_dataset: List[Dict],
    knowledge_base: Dict
) -> Dict:
    """
    Analyze whether model failures are due to reasoning or knowledge gaps.

    From "3 Program Refinement Loops" (2025):
    AI reasoning performance is fundamentally constrained by knowledge coverage.
    """
    results = {
        'knowledge_bound_failures': 0,
        'reasoning_failures': 0,
        'ambiguous': 0
    }

    for task in arc_dataset:
        # Check if task requires knowledge not in training
        required_knowledge = extract_required_knowledge(task)

        if not has_knowledge(model, required_knowledge, knowledge_base):
            results['knowledge_bound_failures'] += 1
        else:
            # Try to solve
            solution = model.solve(task)

            if is_correct(solution):
                results['reasoning_failures'] += 1
            else:
                results['ambiguous'] += 1

    return results

def extract_required_knowledge(task: Dict) -> Set[str]:
    """
    Extract domain knowledge required for task.

    Examples:
    - "diagonal" → geometry concept
    - "modulo 3" → arithmetic concept
    - "xor" → logic operation
    """
    knowledge = set()

    # Extract from task description
    if 'description' in task:
        desc = task['description'].lower()

        # Domain-specific keywords
        geometry_keywords = ['diagonal', 'rotate', 'reflect', 'translate', 'scale']
        for kw in geometry_keywords:
            if kw in desc:
                knowledge.add(f"geometry:{kw}")

        math_keywords = ['modulo', 'add', 'subtract', 'multiply', 'divide']
        for kw in math_keywords:
            if kw in desc:
                knowledge.add(f"math:{kw}")

    return knowledge
```

---

## 7. Synthetic Data Arms Race ⚠️

**Critical Finding**: Much of ARC-AGI improvement comes from **synthetic training data**, not fundamental reasoning advances.

### Synthetic Data Generation

```python
def generate_synthetic_arc_data(
    n_tasks: int = 1000000,
    complexity: str = "high"
) -> List[Dict]:
    """
    Generate synthetic ARC-like tasks for training.

    This approach (used by NVIDIA ARC Prize 2025 winners):
    1. Generate millions of synthetic puzzles
    2. Train on every pattern variation
    3. Perform test-time training on new puzzles

    Issues:
    - Not true generalization (knowledge-bound)
    - May not transfer to real-world reasoning
    - Benchmark contamination risk
    """
    tasks = []

    for _ in range(n_tasks):
        # Random task parameters
        grid_size = random.randint(10, 30)
        n_colors = random.randint(2, 10)
        rule_type = random.choice(['color', 'shape', 'position', 'size'])

        # Generate input/output pair
        input_grid = generate_random_grid(grid_size, n_colors)
        output_grid = apply_rule(input_grid, rule_type)

        task = {
            'input': input_grid,
            'output': output_grid,
            'rule': rule_type,
            'synthetic': True
        }

        tasks.append(task)

    return tasks

def detect_synthetic_contamination(
    model,
    original_tasks: List[Dict],
    synthetic_threshold: float = 0.9
) -> Dict:
    """
    Detect if model was trained on synthetic ARC-like data.

    Signs of synthetic training:
    - Unusually high performance on pattern variants
    - Poor performance on truly novel reasoning
    - Overfitting to synthetic rule distributions
    """
    # Compare performance on:
    # 1. Original tasks (held out)
    # 2. Synthetic variants (may have seen similar)

    original_score = evaluate_subset(model, original_tasks)

    # Generate synthetic variants
    synthetic_tasks = generate_synthetic_arc_data(len(original_tasks))
    synthetic_score = evaluate_subset(model, synthetic_tasks)

    # If much better on synthetic, likely trained on synthetic
    contamination_score = synthetic_score - original_score

    return {
        'contaminated': contamination_score > synthetic_threshold,
        'contamination_score': contamination_score,
        'original_score': original_score,
        'synthetic_score': synthetic_score
    }
```

---

## 8. Cost Optimization (2024-2025) ⭐⭐

**Massive Cost Reduction**:
- o3-preview (Dec 2024): $4,500/task
- GPT-5.2 (Dec 2025): $12/task
- Poetiq (Dec 2025): $30.57/task (54% score)

### Cost Optimization Strategies

```python
def cost_optimized_arc_solution(
    task: Dict,
    models: List,  # Available models with costs
    budget: float
) -> Dict:
    """
    Cost-optimized ARC-AGI solving.

    Strategy:
    1. Use cheaper models for initial attempts
    2. Escalate to expensive models only if needed
    3. Early stopping on confidence
    """
    # Sort models by cost (cheapest first)
    models_sorted = sorted(models, key=lambda m: m.cost_per_call)

    total_cost = 0.0
    best_prediction = None
    best_confidence = 0.0

    for model in models_sorted:
        if total_cost + model.cost_per_call > budget:
            break

        # Get prediction with confidence
        result = model.solve_with_confidence(task)
        prediction, confidence = result['prediction'], result['confidence']

        total_cost += model.cost_per_call

        # Early stopping if high confidence
        if confidence > 0.95:
            return {
                'prediction': prediction,
                'confidence': confidence,
                'cost': total_cost,
                'model': model.name
            }

        # Track best
        if confidence > best_confidence:
            best_confidence = confidence
            best_prediction = prediction

    return {
        'prediction': best_prediction,
        'confidence': best_confidence,
        'cost': total_cost
    }
```

---

## Priority Matrix (AGI Benchmarking)

| # | Method | Impact | Effort | Priority |
|---|--------|--------|--------|----------|
| 1 | Test-Time Training | High | 2-3 days | **P0** |
| 2 | Synthetic Training | Very High | 3-5 days | **P1** |
| 3 | DL-Guided Synthesis | High | 5-7 days | **P1** |
| 4 | PoE Ensemble | Medium | 2-3 days | **P1** |
| 5 | NCA Approach | Medium | 4-5 days | **P2** |
| 6 | Cost Optimization | High | 1-2 days | **P2** |
| 7 | ARC-AGI-3 Prep | Future | TBD | **P2** |

---

## Key Takeaways for Kaggle

1. **Don't rely on pure LLMs** — They score 0% on ARC-AGI-2
2. **Use test-time adaptation** — The dominant paradigm in 2024-2025
3. **Efficiency matters** — Cost per solution is key metric
4. **Synthetic data helps** — But true generalization remains unsolved
5. **Human-AI gap persists** — 62% human vs <55% best AI (refined)
6. **ARC-AGI-3 coming** — Will require interactive reasoning

---

## References

1. **ARC-AGI-2**: arcprize.org/arc-agi/2/
2. **ARC Prize 2025**: arXiv:2412.04604 (NAACL 2025 submission)
3. **Program Refinement Loops**: arXiv:2601.10904 (2025)
4. **Synthetic Training**: "Don't throw the baby out" (2025)
5. **GPT-5.2 Analysis**: aihola.com/article/arcagi-benchmark-gpt-5-analysis
6. **Poetiq Approach**: Model refinement without training

---

**Document Version**: 1.0
**Last Updated**: 2026-03-26
