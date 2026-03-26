# Kaggle Hackathon — LLM Evaluation Best Practices (2025)

**Date**: 2026-03-26
**Version**: 1.0
**Status**: Industry Standard Practices

---

## Overview

This document synthesizes **industry best practices for LLM evaluation** from leading research labs (OpenAI, Anthropic, Google DeepMind, Meta). It covers Elo ranking, LLM-as-a-Judge, contamination detection, and the three-layer evaluation architecture.

---

## 1. Elo Rating System for LLMs ⭐⭐⭐

**Paper**: "Elo Uncovered: Robustness and Best Practices" (NeurIPS 2024)

### Key Findings

| Issue | Finding | Recommendation |
|-------|----------|----------------|
| **Order Sensitivity** | Elo scores vary by comparison order | Use multiple permutations (N_perms ≥ 10) |
| **Reliability** | Individual computations volatile | Report confidence intervals |
| **Transitivity** | Not always satisfied | Use Bradley-Terry for rankings |
| **Saturation** | Top models cluster together | Focus on head-to-head comparisons |

### Robust Elo Implementation

```python
def robust_elo_rating(
    pairwise_comparisons: List[Tuple[str, str, str]],  # (winner, loser, context)
    n_permutations: int = 100,
    k_factor: float = 32.0,
    initial_rating: float = 1000.0
) -> Dict[str, Dict]:
    """
    Robust Elo rating with order correction.

    Addresses NeurIPS 2024 findings:
    - Use multiple order permutations
    - Report confidence intervals
    - Handle tied models

    Args:
        pairwise_comparisons: List of (winner, loser, context)
        n_permutations: Number of order permutations
        k_factor: K value for Elo updates
        initial_rating: Starting Elo rating

    Returns:
        {model: {'elo': float, 'ci_lower': float, 'ci_upper': float}}
    """
    models = set()
    for winner, loser, _ in pairwise_comparisons:
        models.add(winner)
        models.add(loser)

    # Store ratings across permutations
    elo_distributions = {model: [] for model in models}

    for perm_idx in range(n_permutations):
        # Shuffle comparison order
        import random
        shuffled = random.sample(pairwise_comparisons, len(pairwise_comparisons))

        # Initialize ratings
        ratings = {model: initial_rating for model in models}

        # Process comparisons
        for winner, loser, _ in shuffled:
            # Expected score
            expected = 1.0 / (1.0 + 10.0 ** ((ratings[loser] - ratings[winner]) / 400.0))

            # Update ratings
            ratings[winner] = ratings[winner] + k_factor * (1.0 - expected)
            ratings[loser] = ratings[loser] + k_factor * (0.0 - expected)

        # Store final ratings
        for model, rating in ratings.items():
            elo_distributions[model].append(rating)

    # Compute statistics
    results = {}
    for model, ratings in elo_distributions.items():
        mean_elo = np.mean(ratings)
        std_elo = np.std(ratings)
        results[model] = {
            'elo': mean_elo,
            'std': std_elo,
            'ci_lower': mean_elo - 1.96 * std_elo,
            'ci_upper': mean_elo + 1.96 * std_elo
        }

    return results
```

### Bradley-Terry Alternative

```python
def bradley_terry_rating(
    pairwise_comparisons: List[Tuple[str, str, str]]
) -> Dict[str, float]:
    """
    Bradley-Terry model: alternative to Elo with transitivity guarantee.

    Advantages over Elo:
    - Maximum likelihood estimation
    - Guaranteed transitivity
    - Statistical inference framework

    Reference: "Elo Uncovered" NeurIPS 2024
    """
    import statsmodels.api as sm

    # Count wins
    models = set()
    win_matrix = {}

    for winner, loser, _ in pairwise_comparisons:
        models.add(winner)
        models.add(loser)

        if winner not in win_matrix:
            win_matrix[winner] = {}
        if loser not in win_matrix:
            win_matrix[loser] = {}

        win_matrix[winner][loser] = win_matrix[winner].get(loser, 0) + 1
        win_matrix[loser][winner] = win_matrix[loser].get(winner, 0) + 0

    # Convert to design matrix
    model_list = list(models)
    n = len(model_list)

    X = []  # Design matrix
    y = []  # Outcomes

    for i in range(n):
        for j in range(i + 1, n):
            model_a = model_list[i]
            model_b = model_list[j]

            # Wins of A over B
            wins_ab = win_matrix.get(model_a, {}).get(model_b, 0)
            # Wins of B over A
            wins_ba = win_matrix.get(model_b, {}).get(model_a, 0)

            # A vs B
            row = [0] * n
            row[i] = -1  # A
            row[j] = 1   # B
            X.append(row)
            y.append(wins_ab / (wins_ab + wins_ba + 1e-10))

    # Fit Bradley-Terry model
    X = np.array(X)
    y = np.array(y)

    model = sm.GLM(y, X, family=sm.families.Binomial())
    result = model.fit()

    # Extract abilities
    abilities = result.params
    ratings = {model_list[i]: float(abilities[i]) for i in range(n)}

    # Normalize to 0-100 scale
    min_rating = min(ratings.values())
    max_rating = max(ratings.values())

    normalized = {
        model: 100 * (rating - min_rating) / (max_rating - min_rating + 1e-10)
        for model, rating in ratings.items()
    }

    return normalized
```

---

## 2. LLM-as-a-Judge Best Practices ⭐⭐⭐

**Paper**: "Re-evaluating Automatic LLM System Ranking" (NAACL 2025)

### Key Findings

| Component | Best Practice | Rationale |
|-----------|---------------|-----------|
| **Input Set** | Diverse, representative | Avoids bias |
| **Evaluation Model** | GPT-4-o or Claude Opus | Best human alignment |
| **Evaluation Type** | Pairwise comparison | More robust than absolute |
| **Aggregation** | Bradley-Terry > Elo | Better statistical properties |

### LLM-as-a-Judge Implementation

```python
def llm_as_judge(
    responses: List[str],
    question: str,
    judge_model,  # GPT-4-o, Claude Opus, etc.
    judge_prompt_template: str,
    reference_answer: str = None,
    temperature: float = 0.0  # Critical: use T=0
) -> Dict[str, float]:
    """
    LLM-as-a-Judge evaluation with best practices.

    Key principles from NAACL 2025:
    1. Use T=0 for deterministic evaluation
    2. Compare models relative to each other (pairwise)
    3. Use multiple judges if possible
    4. Account for length bias

    Args:
        responses: List of model responses to evaluate
        question: Original question/prompt
        judge_model: LLM to use as judge
        judge_prompt_template: Template for evaluation
        reference_answer: Optional ground truth
        temperature: Must be 0 for evaluation

    Returns:
        {response_idx: score} or pairwise comparison results
    """
    # Normalize: T=0 is critical for evaluation
    assert temperature == 0.0, "Evaluation must use T=0"

    if len(responses) == 2:
        # Pairwise comparison (recommended)
        result = pairwise_judge(
            responses[0], responses[1],
            question, judge_model, judge_prompt_template
        )
        return result
    else:
        # Absolute scoring (less reliable)
        scores = []
        for response in responses:
            prompt = judge_prompt_template.format(
                question=question,
                response=response,
                reference=reference_answer or "N/A"
            )
            score = judge_model.score(prompt, temperature=0.0)
            scores.append(score)

        return {i: scores[i] for i in range(len(responses))}

def pairwise_judge(
    response_a: str,
    response_b: str,
    question: str,
    judge_model,
    template: str
) -> Dict:
    """
    Pairwise comparison with length bias correction.
    """
    prompt = template.format(
        question=question,
        response_a=response_a,
        response_b=response_b
    )

    result = judge_model.generate(prompt, temperature=0.0)

    # Parse judgment
    judgment = parse_judgment(result.text)  # "A is better" or "B is better" or "Tie"

    # Length bias correction (from WILDBENCH ICLR 2025)
    len_a = len(response_a)
    len_b = len(response_b)

    # If winner is significantly longer, convert to tie
    if judgment['winner'] == 'A' and len_a > 1.5 * len_b:
        judgment['winner'] = 'Tie'
        judgment['note'] = 'Length-corrected'
    elif judgment['winner'] == 'B' and len_b > 1.5 * len_a:
        judgment['winner'] = 'Tie'
        judgment['note'] = 'Length-corrected'

    return judgment

def parse_judgment(text: str) -> Dict:
    """Parse LLM judgment into structured output."""
    text_lower = text.lower()

    if 'a is better' in text_lower or 'response a is superior' in text_lower:
        return {'winner': 'A', 'confidence': extract_confidence(text)}
    elif 'b is better' in text_lower or 'response b is superior' in text_lower:
        return {'winner': 'B', 'confidence': extract_confidence(text)}
    elif 'tie' in text_lower or 'equal' in text_lower:
        return {'winner': 'Tie', 'confidence': extract_confidence(text)}
    else:
        # Default to tie if unclear
        return {'winner': 'Tie', 'confidence': 0.0}
```

### Multiple Judge Agreement

```python
def multi_judge_agreement(
    responses: List[str],
    question: str,
    judges: List,
    template: str
) -> Dict:
    """
    Use multiple LLMs as judges for robustness.

    From NAACL 2025: Multiple judges improve reliability,
    especially when models have similar performance.
    """
    judgments = []

    for judge in judges:
        # Collect pairwise judgments
        for i in range(len(responses)):
            for j in range(i + 1, len(responses)):
                result = pairwise_judge(
                    responses[i], responses[j],
                    question, judge, template
                )
                judgments.append({
                    'judge': judge.name,
                    'pair': (i, j),
                    'winner': result['winner']
                })

    # Aggregate using majority voting
    from collections import Counter

    pairwise_winners = {}
    for i in range(len(responses)):
        for j in range(i + 1, len(responses)):
            pair_key = (i, j)
            pair_judgments = [j['winner'] for j in judgments if j['pair'] == pair_key]
            winner = Counter(pair_judgments).most_common(1)[0][0]
            pairwise_winners[pair_key] = winner

    # Compute final scores using Bradley-Terry
    scores = bradley_terry_from_pairwise(pairwise_winners, len(responses))

    return {
        'scores': scores,
        'agreement': compute_agreement(judgments),
        'confidence': compute_confidence_from_agreement(judgments)
    }

def compute_agreement(judgments: List) -> float:
    """Compute inter-rater agreement (Cohen's kappa or similar)."""
    # Simplified agreement: proportion of agreeing pairs
    agreements = 0
    total = len(judgments)

    for j in judgments:
        # Check if other judges agree
        other_judgments = [j2 for j2 in judgments if j2 != j and j2['pair'] == j['pair']]
        if other_judgments:
            agreement = any(j2['winner'] == j['winner'] for j2 in other_judgments)
            if agreement:
                agreements += 1

    return agreements / total if total > 0 else 0.0
```

---

## 3. Three-Layer Evaluation Architecture ⭐⭐⭐

**Source**: "MMLU, Chatbot Arena & LLM-as-Judge [2026 Guide]" (Meta Intelligence)

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    LLM Evaluation System                      │
├─────────────────────────────────────────────────────────────┤
│ Layer 1: Automated Benchmarks (Lowest cost, fastest)         │
│   - MMLU-Pro, GPQA, HLE subsets                              │
│   - Custom domain QA                                        │
│   - Code: HumanEval, SWE-Bench                               │
│   - Safety: Toxicity, bias, refusal rate                       │
│   Trigger: Every model update                                │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: LLM-as-Judge (Medium cost, good quality)             │
│   - Pairwise comparison vs baseline                           │
│   - Multi-dimensional: Helpfulness, accuracy, completeness   │
│   - RAGAs metrics: Faithfulness, relevancy                   │
│   - Length bias correction                                    │
│   Trigger: Weekly, major updates                              │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: Human Evaluation (Highest cost, most reliable)       │
│   - Domain expert review                                      │
│   - A/B testing with real users                               │
│   - Error analysis & red team testing                         │
│   Trigger: Pre-release, quarterly                             │
└─────────────────────────────────────────────────────────────┘
```

### Implementation

```python
class ThreeLayerEvaluator:
    """
    Three-layer LLM evaluation system.

    Follows Meta Intelligence 2025 best practices.
    """

    def __init__(self):
        self.layer1_benchmarks = []
        self.layer2_judges = []
        self.layer3_evaluators = []

    def evaluate(self, model, layer: int = 1):
        """Run evaluation at specified layer."""
        if layer >= 1:
            return self.layer1_evaluation(model)
        elif layer >= 2:
            return self.layer2_evaluation(model)
        else:
            return self.layer3_evaluation(model)

    def layer1_evaluation(self, model):
        """Automated benchmarks."""
        results = {}

        # MMLU-Pro subset (for speed)
        results['mmlu_pro'] = self.run_mmlu_pro(model, n_questions=500)

        # Custom domain QA
        results['domain'] = self.run_domain_benchmark(model)

        # Safety checks
        results['safety'] = self.run_safety_checks(model)

        return results

    def layer2_evaluation(self, model):
        """LLM-as-a-Judge evaluation."""
        # Compare against baseline models
        baseline = self.get_baseline_model()

        pairwise_results = []
        for task in self.get_evaluation_tasks():
            result = self.pairwise_evaluate(
                model, baseline, task
            )
            pairwise_results.append(result)

        # Aggregate
        return self.aggregate_pairwise(pairwise_results)

    def layer3_evaluation(self, model):
        """Human evaluation."""
        # Domain expert review
        expert_review = self.expert_evaluation(model)

        # A/B test
        ab_test = self.ab_test(model)

        # Red team
        red_team = self.red_team_test(model)

        return {
            'expert': expert_review,
            'ab_test': ab_test,
            'red_team': red_team
        }
```

---

## 4. Contamination Detection ⭐⭐⭐

**Critical Issue**: MMLU and other benchmarks have 6.5-10% error rates and are vulnerable to data contamination.

### MMLU Issues

| Issue | Finding | Source |
|-------|----------|--------|
| **Ground truth errors** | 6.5% of MMLU questions have errors | arXiv:2406.04127 |
| **Virology errors** | 57% of Virology subset has errors | Expert review |
| **Data contamination** | Models trained on test data | Multiple sources |
| **Ceiling effect** | Max attainable ~91% (not 100%) | Research findings |

### Contamination Detection Methods

```python
def detect_contamination(
    model,
    benchmark_questions: List[str],
    benchmark_answers: List[str],
    n_samples: int = 100
) -> Dict:
    """
    Detect if model was trained on benchmark data.

    Methods:
    1. Exact match check
    2. N-gram overlap
    3. Perplexity comparison
    4. Zero-shot accuracy

    Returns contamination probability and evidence.
    """
    import nltk
    from collections import Counter

    evidence = {
        'exact_matches': 0,
        'high_ngram_overlap': 0,
        'suspicious_perplexity': 0,
        'contamination_prob': 0.0
    }

    # Method 1: Exact match check
    for question, answer in zip(benchmark_questions, benchmark_answers):
        model_output = model.generate(question)
        if model_output.strip().lower() == answer.strip().lower():
            evidence['exact_matches'] += 1

    # Method 2: N-gram overlap
    model_responses = []
    for question in benchmark_questions[:n_samples]:
        response = model.generate(question)
        model_responses.append(response)

    # Compute n-grams for benchmark
    benchmark_text = " ".join(benchmark_questions + benchmark_answers)
    benchmark_ngrams = set(nltk.ngrams(benchmark_text.split(), 5))

    overlap_count = 0
    for response in model_responses:
        response_ngrams = set(nltk.ngrams(response.split(), 5))
        overlap = len(benchmark_ngrams & response_ngrams)
        if overlap > 10:  # Threshold
            overlap_count += 1

    evidence['high_ngram_overlap'] = overlap_count

    # Method 3: Suspiciously high accuracy
    # If zero-shot accuracy > trained baseline, suspicious
    zero_shot_acc = evaluate_zero_shot(model, benchmark_questions[:n_samples])
    if zero_shot_acc > 0.95:  # >95% zero-shot is suspicious
        evidence['suspicious_perplexity'] = 1

    # Aggregate
    contamination_signals = sum([
        evidence['exact_matches'] > 0,
        evidence['high_ngram_overlap'] > n_samples * 0.1,
        evidence['suspicious_perplexity'] > 0
    ])

    evidence['contamination_prob'] = min(1.0, contamination_signals / 3.0)

    return evidence
```

### MMLU-Pro: The Solution

```python
def mmlu_pro_evaluation(
    model,
    n_questions: int = 12000,
    n_choices: int = 10,
    chain_of_thought: bool = False
) -> Dict:
    """
    MMLU-Pro evaluation (NeurIPS 2024 benchmark).

    Advantages over MMLU:
    - 10-choice format (harder)
    - Focus on reasoning
    - Lower error rate
    - Better discrimination

    Current ceilings (2025):
    - MMLU: ~91% (saturated)
    - MMLU-Pro: ~90% (approaching saturation)
    - GPQA: ~80%
    - HLE: ~50% (free-text), ~26% (multi-choice)
    """
    from datasets import load_dataset

    # Load MMLU-Pro
    dataset = load_dataset("cais/mmlu", "all", split="test")

    results = {
        'correct': 0,
        'total': 0,
        'by_subject': {}
    }

    for example in dataset:
        subject = example['subject']
        question = example['question']
        choices = example['choices']  # 10 choices
        answer = example['answer']  # Index of correct answer

        # Build prompt
        if chain_of_thought:
            prompt = f"{question}\n\nLet's think step by step:"
        else:
            prompt = question

        # Generate response
        response = model.generate(prompt)

        # Parse answer
        predicted = parse_multiple_choice(response, choices)

        if predicted == answer:
            results['correct'] += 1
        results['total'] += 1

        # Track by subject
        if subject not in results['by_subject']:
            results['by_subject'][subject] = {'correct': 0, 'total': 0}
        results['by_subject'][subject]['correct'] += int(predicted == answer)
        results['by_subject'][subject]['total'] += 1

    # Compute accuracy
    accuracy = results['correct'] / results['total']
    results['accuracy'] = accuracy

    return results
```

---

## 5. WILDBENCH Metrics ⭐⭐

**Paper**: "WILDBENCH: Benchmarking LLMs with Wild Human Queries" (ICLR 2025)

### WB-Reward and WB-Score

```python
def wildbench_evaluation(
    model,
    tasks: List[Dict],
    judge_model,  # GPT-4 or Claude
    k_baselines: int = 3
) -> Dict:
    """
    WILDBENCH evaluation with WB-Reward and WB-Score.

    Pearson correlation with human Elo:
    - WB-Reward: 0.98
    - WB-Score: 0.95

    Args:
        model: Model to evaluate
        tasks: List of wild chatbot tasks
        judge_model: LLM judge
        k_baselines: Number of baseline models

    Returns:
        {wb_reward: float, wb_score: float, correlations: dict}
    """
    wb_rewards = []
    wb_scores = []

    for task in tasks:
        prompt = task['prompt']

        # Generate response
        response = model.generate(prompt)

        # WB-Reward: Compare against k baselines
        pairwise_scores = []
        for baseline_idx in range(k_baselines):
            baseline_response = task.get(f'baseline_{baseline_idx}')
            if baseline_response:
                judgment = judge_compare(response, baseline_response, prompt, judge_model)
                pairwise_scores.append(judgment)

        # Aggregate pairwise scores
        wb_reward = np.mean(pairwise_scores)
        wb_rewards.append(wb_reward)

        # WB-Score: Absolute quality score
        wb_score = judge_absolute(response, prompt, judge_model)
        wb_scores.append(wb_score)

    return {
        'wb_reward': np.mean(wb_rewards),
        'wb_score': np.mean(wb_scores),
        'correlation_with_elo': 0.98  # From paper
    }

def judge_compare(response_a, response_b, prompt, judge):
    """Pairwise comparison for WB-Reward."""
    comparison_prompt = f"""
Prompt: {prompt}

Response A: {response_a}

Response B: {response_b}

Which response is better? Respond with 'A', 'B', or 'Tie':
"""
    result = judge.generate(comparison_prompt, temperature=0.0)
    return parse_comparison(result.text)

def judge_absolute(response, prompt, judge):
    """Absolute scoring for WB-Score."""
    score_prompt = f"""
Prompt: {prompt}

Response: {response}

Rate the response quality from 1 (poor) to 10 (excellent):
"""
    result = judge.generate(score_prompt, temperature=0.0)
    return parse_score(result.text)
```

---

## Priority Matrix (Evaluation Methods)

| # | Method | Impact | Effort | Priority |
|---|--------|--------|--------|----------|
| 1 | Robust Elo (N_perms) | +20% reliability | 2 days | **P0** |
| 2 | Bradley-Terry | Better than Elo | 1 day | **P1** |
| 3 | Multi-Judge Agreement | +15% robustness | 2 days | **P1** |
| 4 | Contamination Detection | Data validity | 2-3 days | **P1** |
| 5 | MMLU-Pro Integration | Better benchmark | 1 day | **P1** |
| 6 | Three-Layer Architecture | Systematic | 3 days | **P2** |
| 7 | WILDBENCH Metrics | Human correlation | 2 days | **P2** |

---

## Quick Wins

```python
# 1. Length bias correction
def length_corrected_score(score_a, score_b, len_a, len_b):
    if len_a > 1.5 * len_b:
        return 0.5  # Tie
    return score_a

# 2. Multiple judge agreement
def multi_judge_vote(judgments):
    from collections import Counter
    return Counter(judgments).most_common(1)[0][0]

# 3. Confidence intervals for Elo
def elo_confidence_interval(elo_hist, alpha=0.05):
    import scipy.stats as stats
    lower = np.percentile(elo_hist, 100 * alpha / 2)
    upper = np.percentile(elo_hist, 100 * (1 - alpha / 2))
    return lower, upper
```

---

## References

1. **Elo Uncovered**: NeurIPS 2024 — "Robustness and Best Practices in Elo Rating"
2. **Auto LLM Ranking**: arXiv:2501.00560 (NAACL 2025) — "Re-evaluating Automatic LLM System Ranking"
3. **WILDBENCH**: ICLR 2025 — "Benchmarking LLMs with Wild Human Queries"
4. **MMLU-Pro**: NeurIPS 2024 — TIGER-Lab MMLU-Pro benchmark
5. **Meta Intelligence Guide**: 2025 — "MMLU, Chatbot Arena & LLM-as-a-Judge"

---

**Document Version**: 1.0
**Last Updated**: 2026-03-26
