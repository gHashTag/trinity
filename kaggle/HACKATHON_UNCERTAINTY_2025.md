# Kaggle Hackathon — Cutting-Edge Uncertainty Quantification (2025 Research)

**Date**: 2026-03-26
**Version**: 1.0
**Status**: Latest Research Integration

---

## Overview

This document implements **state-of-the-art uncertainty quantification methods** from NeurIPS 2024, ICLR 2025, and EMNLP 2025 papers. These methods go beyond traditional calibration by distinguishing between **aleatoric** (data) and **epistemic** (knowledge) uncertainty.

---

## 1. Aleatoric vs Epistemic Uncertainty ⭐⭐⭐

**Paper**: "To Believe or Not to Believe Your LLM" (NeurIPS 2024, arXiv:2406.02543)
**Authors**: Google DeepMind + University of Alberta (Csaba Szepesvári)

### Key Insight

| Uncertainty Type | Source | When High | Action |
|-----------------|--------|-----------|--------|
| **Aleatoric** | Inherent randomness (multiple valid answers) | Task ambiguity | Accept diversity |
| **Epistemic** | Lack of knowledge (model doesn't know) | Hallucination risk | Abstain/verify |

### Iterative Prompting Method

The paper proposes **iterative prompting** to separate the two uncertainties:

```python
def iterative_prompting_uncertainty(
    query: str,
    llm,
    n_iterations: int = 5,
    temperature: float = 0.7
) -> Dict[str, float]:
    """
    Estimate aleatoric vs epistemic uncertainty via iterative prompting.

    Key idea: Epistemic uncertainty causes responses to be stable
    regardless of previous responses. Aleatoric uncertainty causes
    natural variation regardless of history.

    Returns:
        {
            'aleatoric_uncertainty': float,  # H(Y) - inherent variation
            'epistemic_uncertainty': float,    # I(Y; X) - lack of knowledge
            'total_uncertainty': float,
            'hallucination_risk': bool
        }
    """
    responses = []
    log_probs = []

    # Iterative prompting: each prompt includes all previous responses
    prompt = query
    for i in range(n_iterations):
        result = llm.generate(prompt, temperature=temperature)
        response = result.text
        log_prob = result.log_prob  # Average log probability

        responses.append(response)
        log_probs.append(log_prob)

        # Build next prompt with all previous responses
        prompt = f"{query}\n\nPrevious responses:\n" + "\n".join(
            f"- {r}" for r in responses
        ) + "\n\nProvide another distinct response:"

    # Estimate aleatoric uncertainty: entropy of response distribution
    # Count unique responses (semantic clustering recommended)
    unique_responses = set(semantic_cluster(responses))  # Requires embeddings
    aleatoric = len(unique_responses) / n_iterations  # Normalized diversity

    # Estimate epistemic uncertainty: stability of responses
    # Low epistemic = responses change based on history (model is uncertain)
    # High epistemic = responses are stable regardless of history (model knows)
    response_entropy = compute_entropy(responses)
    epistemic = 1.0 - (response_entropy / math.log(n_iterations))

    total = aleatoric + epistemic

    # Hallucination risk: high epistemic = model doesn't know
    hallucination_risk = epistemic > 0.7

    return {
        'aleatoric_uncertainty': aleatoric,
        'epistemic_uncertainty': epistemic,
        'total_uncertainty': total,
        'hallucination_risk': hallucination_risk
    }
```

### Quick Implementation

```python
def simple_epistemic_detector(
    confidence: float,
    n_samples: int = 5,
    agreement_threshold: float = 0.8
) -> bool:
    """
    Fast epistemic uncertainty detection.

    If samples disagree beyond threshold -> high epistemic uncertainty.
    """
    # Collect samples
    samples = [llm.sample(query) for _ in range(n_samples)]

    # Check semantic agreement
    unique_responses = len(set(samples))
    agreement = unique_responses / n_samples

    # Low agreement = high epistemic uncertainty
    return agreement < (1 - agreement_threshold)
```

---

## 2. Conformal Prediction for LLM-as-a-Judge ⭐⭐⭐

**Paper**: "Analyzing Uncertainty of LLM-as-a-Judge" (EMNLP 2025)
**Authors**: Various

### Key Insight

Instead of point estimates, output **prediction intervals** with coverage guarantees:
- P(true_score ∈ [lower, upper]) ≥ 1 - α

### Implementation

```python
def conformal_llm_judge(
    responses: List[str],
    calibration_scores: List[float],
    calibration_labels: List[float],
    alpha: float = 0.1
) -> Tuple[float, float, float]:
    """
    Conformal prediction interval for LLM judge.

    Args:
        responses: LLM responses for current query
        calibration_scores: Scores from calibration set
        calibration_labels: Ground truth for calibration set
        alpha: Error rate (0.1 = 90% coverage)

    Returns:
        (lower_bound, upper_bound, midpoint)
    """
    # Compute nonconformity scores
    nc_scores = [abs(s - l) for s, l in zip(calibration_scores, calibration_labels)]

    # Quantile threshold
    n = len(nc_scores)
    q = np.quantile(nc_scores, min(1, (n + 1) * (1 - alpha) / n), method='higher')

    # For current response, construct interval
    # This is simplified - full implementation uses ranking
    score = np.mean([parse_score(r) for r in responses])

    lower_bound = max(0.0, score - q)
    upper_bound = min(1.0, score + q)
    midpoint = (lower_bound + upper_bound) / 2

    return lower_bound, upper_bound, midpoint
```

### Ordinal Boundary Adjustment

The paper proposes adjusting for discrete ratings:

```python
def ordinal_boundary_adjustment(
    interval: Tuple[float, float],
    scale_min: int = 1,
    scale_max: int = 5
) -> Tuple[int, int]:
    """
    Adjust conformal interval for ordinal rating scale.

    Maps continuous interval to discrete rating bounds.
    """
    lower, upper = interval

    # Clip to valid range
    lower_adj = max(scale_min, math.floor(lower) + 1)
    upper_adj = min(scale_max, math.ceil(upper) - 1)

    return lower_adj, upper_adj
```

---

## 3. Muse: Multi-LLM Uncertainty Quantification ⭐⭐⭐

**Paper**: "An Information-Theoretic Approach to Multi-LLM Uncertainty" (ICLR 2025)

### Key Insight

**Disagreement among LLMs signals epistemic uncertainty.** Consensus indicates reliability.

### Muse Algorithm

```python
def muse_uncertainty(
    predictions: List[np.ndarray],  # Each is [n_classes] or binary
    beta: float = 1.0,
    epsilon_tol: float = 0.1,
    m_min: int = 2
) -> Tuple[np.ndarray, Dict[str, float]]:
    """
    Muse: Multi-LLM uncertainty-aware subset selection.

    Args:
        predictions: List of N model predictions
        beta: Weighting between epistemic and aleatoric
        epsilon_tol: Disagreement tolerance
        m_min: Minimum models to select

    Returns:
        (aggregated_prediction, uncertainty_metrics)
    """
    n_models = len(predictions)

    # Compute mean prediction
    mean_pred = np.mean(predictions, axis=0)

    # Compute epistemic uncertainty: JSD from mean
    from scipy.spatial.distance import jensenshannon

    epistemic_uncertainties = []
    for pred in predictions:
        jsd = jensenshannon(pred, mean_pred)
        epistemic_uncertainties.append(jsd)

    # Compute aleatoric uncertainty: entropy of each prediction
    aleatoric_uncertainties = []
    for pred in predictions:
        entropy = -np.sum(pred * np.log(pred + 1e-10))
        aleatoric_uncertainties.append(entropy)

    # Greedy subset selection
    selected = [0]  # Start with first model
    remaining = list(range(1, n_models))

    while remaining and len(selected) < n_models:
        best_candidate = None
        best_total_uncertainty = float('inf')

        for candidate in remaining:
            # Candidate subset
            subset = selected + [candidate]

            # Compute mean of subset
            subset_preds = [predictions[i] for i in subset]
            subset_mean = np.mean(subset_preds, axis=0)

            # Epistemic: mean JSD to subset mean
            subset_epistemic = np.mean([
                jensenshannon(predictions[i], subset_mean)
                for i in subset
            ])

            # Aleatoric: mean entropy
            subset_aleatoric = np.mean([aleatoric_uncertainties[i] for i in subset])

            # Total uncertainty
            total = subset_epistemic + beta * subset_aleatoric

            if total < best_total_uncertainty:
                best_total_uncertainty = total
                best_candidate = candidate

        # Check tolerance
        if best_total_uncertainty < epsilon_tol:
            selected.append(best_candidate)
            remaining.remove(best_candidate)
        else:
            break

        if len(selected) >= m_min and best_total_uncertainty > epsilon_tol:
            break

    # Final aggregation
    final_preds = [predictions[i] for i in selected]
    aggregated = np.mean(final_preds, axis=0)

    # Compute final uncertainty metrics
    u_epis = np.mean([epistemic_uncertainties[i] for i in selected])
    u_alea = np.mean([aleatoric_uncertainties[i] for i in selected])

    return aggregated, {
        'epistemic_uncertainty': u_epis,
        'aleatoric_uncertainty': u_alea,
        'total_uncertainty': u_epis + beta * u_alea,
        'n_models_selected': len(selected),
        'selected_indices': selected
    }
```

---

## 4. CROQ: Conformal Revision of Questions ⭐⭐

**Paper**: "Prune 'n Predict" (ICLR 2025)

### Key Insight

**Revise questions by narrowing choices to conformal prediction set.** LLMs are more accurate on fewer choices.

### CROQ Implementation

```python
def croq_revision(
    question: str,
    choices: List[str],
    llm,
    calibration_data,
    alpha: float = 0.1
) -> Tuple[str, List[str], Dict]:
    """
    Conformal Revision Of Questions (CROQ).

    1. Get conformal prediction set
    2. Revise question to only include choices in set
    3. LLM answers revised question (more accurate)

    Args:
        question: Original question
        choices: List of answer choices
        llm: Language model
        calibration_data: For conformal prediction
        alpha: Coverage level

    Returns:
        (answer, revised_choices, metadata)
    """
    # Step 1: Compute conformal prediction set
    prediction_set = conformal_prediction_set(
        question, choices, calibration_data, alpha
    )

    if len(prediction_set) == len(choices):
        # No pruning possible
        answer = llm.select_answer(question, choices)
        return answer, choices, {'pruned': False}

    # Step 2: Revise question
    revised_question = f"{question}\n\nAnswer choices: {', '.join(prediction_set)}"

    # Step 3: LLM answers revised question
    answer = llm.select_answer(revised_question, prediction_set)

    return answer, prediction_set, {
        'pruned': True,
        'original_n_choices': len(choices),
        'revised_n_choices': len(prediction_set),
        'prediction_set': prediction_set
    }

def conformal_prediction_set(
    question: str,
    choices: List[str],
    calibration_data,
    alpha: float
) -> List[str]:
    """
    Compute conformal prediction set (minimal covering set).

    Returns smallest set of choices containing true answer with 1-α probability.
    """
    # Score each choice
    scores = {}
    for choice in choices:
        score = llm.score_choice(question, choice)
        scores[choice] = score

    # Get nonconformity threshold from calibration
    q = calibration_data['quantile_threshold']

    # Prediction set: choices with score above threshold
    prediction_set = [c for c, s in scores.items() if s > q]

    # Ensure at least one choice
    if not prediction_set:
        prediction_set = [max(scores, key=scores.get)]

    return prediction_set
```

---

## 5. Local Uncertainty Conformal Calibration (LUCCa) ⭐⭐

**Paper**: "Local Uncertainty Conformal Calibration" (WAFR 2024, arXiv:2409.08249)

### Key Insight

**Calibrate locally in state-action space** for more useful uncertainty estimates.

### LUCCa Implementation

```python
def lucca_calibration(
    confidences: List[float],
    correct: List[bool],
    features: List[np.ndarray],  # Feature vectors for localization
    k_neighbors: int = 50,
    alpha: float = 0.1
) -> Callable[[float, np.ndarray], Tuple[float, float]]:
    """
    Local Uncertainty Conformal Calibration (LUCCa).

    Unlike global conformal prediction, LUCCa calibrates locally
    in feature space for more accurate uncertainty estimates.

    Args:
        confidences: Validation confidences
        correct: Ground truth correctness
        features: Feature vectors for each prediction
        k_neighbors: Number of neighbors for local calibration
        alpha: Coverage level

    Returns:
        Function that maps (confidence, feature) -> (lower, upper)
    """
    from sklearn.neighbors import NearestNeighbors

    # Build k-NN model
    nbrs = NearestNeighbors(n_neighbors=k_neighbors)
    nbrs.fit(features)

    # Pre-compute nonconformity scores
    nc_scores = [1 - c if corr else c for c, corr in zip(confidences, correct)]

    def calibrate(new_confidence: float, new_feature: np.ndarray) -> Tuple[float, float]:
        # Find k nearest neighbors
        distances, indices = nbrs.kneighbors([new_feature])
        neighbor_nc_scores = [nc_scores[i] for i in indices[0]]

        # Local quantile
        q_local = np.quantile(neighbor_nc_scores, 1 - alpha, method='higher')

        # Construct interval
        lower = max(0.0, new_confidence - q_local)
        upper = min(1.0, new_confidence + q_local)

        return lower, upper

    return calibrate
```

---

## 6. Information-Theoretic Uncertainty Decomposition ⭐⭐

**Paper**: "Uncertainty Quantification for In-Context Learning" (NAACL 2024)

### Mutual Information-Based Decomposition

```python
def mutual_information_uncertainty(
    predictive_distribution: np.ndarray,
    posterior_samples: List[np.ndarray] = None
) -> Dict[str, float]:
    """
    Decompose uncertainty into aleatoric and epistemic using mutual information.

    Based on NAACL 2024 paper:
    - Total Uncertainty = H[y | x, D]  (predictive entropy)
    - Aleatoric Uncertainty = E_{θ~p(θ|D)}[H[y | x, θ]]  (expected entropy)
    - Epistemic Uncertainty = H[y | x, D] - E[H[y | x, θ]]  (mutual information)

    Args:
        predictive_distribution: p(y | x, D) averaged over posterior
        posterior_samples: Samples from posterior p(θ | D)

    Returns:
        {'total': float, 'aleatoric': float, 'epistemic': float}
    """
    # Total uncertainty: predictive entropy
    total_uncertainty = -np.sum(
        predictive_distribution * np.log(predictive_distribution + 1e-10)
    )

    if posterior_samples is None:
        # Single model: cannot decompose
        return {
            'total': total_uncertainty,
            'aleatoric': total_uncertainty,
            'epistemic': 0.0
        }

    # Aleatoric: expected entropy under posterior
    entropies = []
    for sample_dist in posterior_samples:
        h = -np.sum(sample_dist * np.log(sample_dist + 1e-10))
        entropies.append(h)

    aleatoric_uncertainty = np.mean(entropies)

    # Epistemic: mutual information
    epistemic_uncertainty = total_uncertainty - aleatoric_uncertainty

    return {
        'total': total_uncertainty,
        'aleatoric': aleatoric_uncertainty,
        'epistemic': max(0.0, epistemic_uncertainty)
    }
```

---

## Priority Matrix (Uncertainty Methods)

| # | Method | Impact | Effort | Dependencies | Priority |
|---|--------|--------|--------|--------------|----------|
| 1 | Aleatoric/Epistemic (Iterative) | +20% reliability | 3-4 days | LLM API | **P0** |
| 2 | Muse (Multi-LLM) | +15% accuracy | 2-3 days | Multiple LLMs | **P1** |
| 3 | Conformal LLM Judge | Coverage guarantee | 2 days | Calibration data | **P1** |
| 4 | CROQ (Question Revision) | +10% accuracy | 2-3 days | CP implementation | **P1** |
| 5 | LUCCa (Local CP) | +5-10% calibration | 3 days | Feature vectors | **P2** |
| 6 | MI Decomposition | Theoretical insight | 1-2 days | Posterior samples | **P2** |

---

## Quick Wins (Same-Day)

### Win 1: Simple Epistemic Detector

```python
def epistemic_abstention(
    confidence: float,
    entropy: float,
    epistemic_threshold: float = 0.7
) -> Tuple[bool, str]:
    """
    Simple abstention based on epistemic uncertainty.

    High entropy + high confidence = likely epistemic uncertainty.
    """
    # Epistemic signal: confident but high entropy
    epistemic_score = confidence * entropy

    if epistemic_score > epistemic_threshold:
        return False, "abstained_high_epistemic"

    return True, "answered"
```

### Win 2: Multi-LLM Consensus

```python
def multi_llm_consensus(
    query: str,
    llms: List,
    agreement_threshold: float = 0.8
) -> Tuple[str, float, bool]:
    """
    Simple multi-LLM consensus.

    Returns: (answer, confidence, is_consensus)
    """
    responses = [llm.generate(query) for llm in llms]

    # Check agreement
    from collections import Counter
    counts = Counter(responses)
    most_common = counts.most_common(1)[0]
    answer, count = most_common

    confidence = count / len(llms)
    is_consensus = confidence >= agreement_threshold

    return answer, confidence, is_consensus
```

### Win 3: Prediction Interval Output

```python
def prediction_interval_output(
    point_estimate: float,
    interval: Tuple[float, float]
) -> str:
    """
    Format prediction with uncertainty interval.

    Example: "0.75 [0.65, 0.85]"
    """
    lower, upper = interval
    return f"{point_estimate:.2f} [{lower:.2f}, {upper:.2f}]"
```

---

## Implementation Roadmap

### Week 1: Foundation
1. **Aleatoric/Epistemic Separation** (Day 1-3)
   - Implement iterative prompting
   - Add semantic clustering
   - Create hallucination detector

2. **Multi-LLM Consensus** (Day 4-5)
   - Implement Muse algorithm
   - Add JSD computation
   - Create subset selection

### Week 2: Advanced Methods
3. **Conformal LLM Judge** (Day 6-8)
   - Implement split conformal
   - Add ordinal boundary adjustment
   - Create interval visualization

4. **CROQ** (Day 9-10)
   - Implement prediction set
   - Add question revision
   - Benchmark accuracy improvement

### Week 3: Integration
5. **LUCCa + MI Decomposition** (Day 11-13)
   - Local calibration
   - MI-based decomposition
   - Unified uncertainty API

6. **Integration & Testing** (Day 14-15)
   - Integrate into runner.py
   - Create uncertainty dashboard
   - Document and validate

---

## References

1. **Aleatoric/Epistemic**: arXiv:2406.02543 (NeurIPS 2024) — "To Believe or Not to Believe Your LLM"
2. **Conformal LLM Judge**: EMNLP 2025 — "Analyzing Uncertainty of LLM-as-a-Judge"
3. **Muse**: ICLR 2025 — "An Information-Theoretic Approach to Multi-LLM Uncertainty"
4. **CROQ**: ICLR 2025 — "Prune 'n Predict: Optimizing LLM Decision-making with Conformal Prediction"
5. **LUCCa**: arXiv:2409.08249 (WAFR 2024) — "Local Uncertainty Conformal Calibration"
6. **MI Decomposition**: NAACL 2024 — "Uncertainty Quantification for In-Context Learning"

---

**Document Version**: 1.0
**Last Updated**: 2026-03-26
**Total New Methods**: 6
**Total Quick Wins**: 3
