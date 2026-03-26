# Bayesian Alternative Metrics Framework 2026

**Author:** Dmitrii Vasilev
**Date:** 2026-03-26
**Version:** 1.0
**Purpose:** Bayesian alternatives to frequentist statistical tests for Trinity S³AI metrics
**Status:** Ready for implementation

---

## Executive Summary

This framework provides Bayesian alternatives to all frequentist statistical tests used in Trinity S³AI research. Bayesian methods offer several advantages:

1. **Intuitive interpretation** - Probabilities directly quantify belief
2. **No p-value misunderstandings** - Posterior distributions speak for themselves
3. **Sequential analysis** - Results can be updated as new data arrives
4. **No multiple testing burden** - Priors naturally penalize unsupported claims

**Scope:** All Trinity metrics with Bayesian equivalents

---

## Part I: Philosophy and Motivation

### Why Bayesian for Trinity?

### Frequentist Limitations in LLM Research

| Issue | Frequentist | Bayesian |
|-------|-------------|----------|
| **Interpretation** | P(Data|H₀) - probability of data given null hypothesis | P(H|Data) - probability of hypothesis given data |
| **Stopping rules** | Must be fixed in advance | Can be data-dependent |
| **Multiple testing** | Requires correction (Bonferroni, FDR) | Priors handle automatically |
| **Effect size** | Point estimate + CI | Full posterior distribution |
| **Small samples** | Low power, unreliable | Priors stabilize estimates |
| **Interim analysis** | Inflates Type I error | Naturally supported |

### Trinity-Specific Advantages

1. **Sequential training** - Update beliefs as training progresses
2. **Few seeds** - n=5 is small; Bayesian methods excel here
3. **Interpretability** - "95% probability d > 0.2" vs "reject H₀"
4. **Decision theory** - Direct utility maximization for model selection

---

## Part II: BEST — Bayesian Estimation Supersedes the t-test

### Motivation

The t-test assumes:
- Normal distribution (often violated)
- Large sample size (n=5 is borderline)
- Fixed stopping rule (violated in iterative development)

BEST (Kruschke 2013) provides robust Bayesian alternative.

### Model Specification

```python
@dataclass
class BESTModel:
    """Bayesian Estimation Supersedes the t-test.

    Uses t-distribution likelihood (robust to outliers) instead of normal.
    """
    group1: np.ndarray  # Data from group 1
    group2: np.ndarray  # Data from group 2
    y: np.ndarray  # Concatenated data
    group_idx: np.ndarray  # Group membership (0 or 1)

    # Priors (weakly informative)
    mu_prior: tuple = (0, 100)  # Normal(0, 100) — very weak
    sigma_prior: tuple = (0, 100)  # Half-Normal(0, 100) — positive
    nu_prior: tuple = (2, 30)  # Exponential(1/30) — df > 2 for finite variance
```

### Posterior Predictive Checks

```python
def posterior_predictive_check(
    posterior_samples: np.ndarray,
    observed_data: np.ndarray,
    n_sim: int = 1000
) -> Dict[str, float]:
    """Posterior predictive p-value.

    PPP-value = Proportion of simulated data more extreme than observed.
    Values near 0.5 indicate good fit.
    """
    ppp = 0
    for _ in range(n_sim):
        # Draw from posterior predictive
        theta = posterior_samples[np.random.randint(len(posterior_samples))]
        y_sim = simulate_data(theta, len(observed_data))
        # Test statistic (e.g., mean, variance, skewness)
        if test_statistic(y_sim) > test_statistic(observed_data):
            ppp += 1
    return {"ppp_value": ppp / n_sim}
```

### Effect Size: Cohen's d (Bayesian)

```python
@dataclass
class BayesCohenDResult:
    """Bayesian Cohen's d with full posterior."""
    posterior_mean: float  # E[d|data]
    posterior_sd: float  # SD[d|data]
    ci_95: tuple[float, float]  # 95% credible interval
    prob_negligible: float  # P(|d| < 0.2)
    prob_small: float  # P(0.2 ≤ |d| < 0.5)
    prob_medium: float  # P(0.5 ≤ |d| < 0.8)
    prob_large: float  # P(|d| ≥ 0.8)
    prob_positive: float  # P(d > 0)
    prob_negative: float  # P(d < 0)
    n_samples: int

def bayesian_cohens_d(
    group1: np.ndarray,
    group2: np.ndarray,
    n_samples: int = 10000
) -> BayesCohenDResult:
    """Bayesian Cohen's d using MCMC sampling.

    Posterior of δ = (μ₁ - μ₂) / σ_pooled
    """
    # Priors: μ ~ Normal(0, 100), σ ~ Half-Normal(0, 100)
    # Run MCMC (see implementation section)
    # Return posterior summary
```

---

## Part III: Bayes Factors for Hypothesis Testing

### Motivation

Instead of "reject/fail to reject" H₀, quantify evidence:
- BF > 10: Strong evidence for H₁
- 3 < BF < 10: Moderate evidence for H₁
- 1/3 < BF < 3: Inconclusive
- BF < 1/10: Strong evidence for H₀

### Bayes Factor for Equal Variances

```python
def bayes_factor_two_sample(
    group1: np.ndarray,
    group2: np.ndarray,
    prior_scale: float = 0.707  # Default: Rouder et al. 2009
) -> float:
    """Bayes factor for two-sample t-test.

    BF₁₀ = P(Data|H₁) / P(Data|H₀)

    H₀: μ₁ = μ₂ (equal means)
    H₁: μ₁ ≠ μ₂ (different means, Cauchy prior on effect size)

    Uses Cauchy prior on effect size (default scale = 0.707).
    """
    n1, n2 = len(group1), len(group2)
    df = n1 + n2 - 2

    # Pooled variance
    var_pooled = ((n1-1)*group1.var() + (n2-1)*group2.var()) / df
    se = np.sqrt(var_pooled * (1/n1 + 1/n2))

    # Observed t-statistic
    t_obs = (group1.mean() - group2.mean()) / se

    # Bayes factor (approximation)
    # BF = (1 + t²/df)^(-df/2) / ∫(1 + t²/(df(1+r²)))^(-df/2) * C(0,1,r) dr
    # Use numerical integration or precomputed tables

    # Simplified: Li et al. 2021 approximation
    g = prior_scale**2 * (n1 + n2) / (n1 * n2)
    bf_10 = np.sqrt(1 + g) * (1 + t_obs**2 / ((1 + g) * df))**(-df/2)
    bf_10 /= (1 + t_obs**2 / df)**(-df/2)

    return bf_10
```

### Bayes Factor for Correlation

```python
def bayes_factor_correlation(
    x: np.ndarray,
    y: np.ndarray,
    prior_kappa: float = 1.0  # Jeffreys-Lindley prior
) -> float:
    """Bayes factor for Pearson correlation.

    H₀: ρ = 0 (no correlation)
    H₁: ρ ≠ 0 (Beta(1,1) prior on ρ²)

    Returns BF₁₀ = P(Data|H₁) / P(Data|H₀)
    """
    n = len(x)
    r = np.corrcoef(x, y)[0, 1]

    # Ly et al. 2016 approximation
    # BF₁₀ ≈ √((n-1)/(n-3)) * (1 - r²)^(-(n-2)/2)

    if abs(r) == 1:
        return np.inf  # Perfect correlation

    bf_10 = np.sqrt((n - 1) / (n - 3)) * (1 - r**2)**(-(n - 2) / 2)

    return bf_10
```

### Bayes Factor for One-Sample Test

```python
def bayes_factor_one_sample(
    data: np.ndarray,
    mu_null: float = 0.0,
    prior_scale: float = 0.707
) -> float:
    """Bayes factor for one-sample t-test.

    H₀: μ = mu_null
    H₁: μ ≠ mu_null
    """
    n = len(data)
    sample_mean = data.mean()
    sample_sd = data.std(ddof=1)

    t_obs = (sample_mean - mu_null) / (sample_sd / np.sqrt(n))

    # Rouder et al. 2009 formula
    g = prior_scale**2 / n
    df = n - 1

    bf_10 = np.sqrt(1 + n * g) * (1 + t_obs**2 / ((1 + n * g) * df))**(-df / 2)
    bf_10 /= (1 + t_obs**2 / df)**(-df / 2)

    return bf_10
```

---

## Part IV: Bayesian AUC Analysis

### Motivation

Frequentist DeLong CI assumes asymptotic normality. Bayesian approach gives exact posterior.

### Model: AUC from MCMC

```python
@dataclass
class BayesAUCResult:
    """Bayesian AUC with full posterior."""
    posterior_mean: float  # E[AUC|data]
    posterior_sd: float
    ci_95: tuple[float, float]
    prob_above_random: float  # P(AUC > 0.5)
    prob_excellent: float  # P(AUC > 0.9)
    prob_acceptable: float  # P(AUC > 0.7)
    median: float
    map_estimate: float
    n_samples: int

def bayesian_auc(
    y_true: np.ndarray,
    y_score: np.ndarray,
    n_bootstrap: int = 10000
) -> BayesAUCResult:
    """Bayesian AUC using bootstrap approximation to posterior.

    True Bayesian AUC requires modeling P(Y|X) for each class.
    Bootstrap approximation: resample with replacement → empirical posterior.
    """
    n = len(y_true)
    auc_samples = []

    for _ in range(n_bootstrap):
        idx = np.random.choice(n, n, replace=True)
        y_true_boot = y_true[idx]
        y_score_boot = y_score[idx]

        # Compute AUC for this sample
        pos_scores = y_score_boot[y_true_boot == 1]
        neg_scores = y_score_boot[y_true_boot == 0]

        # Mann-Whitney U statistic
        auc = 0
        for pos in pos_scores:
            auc += np.sum(pos > neg_scores) + 0.5 * np.sum(pos == neg_scores)
        auc /= len(pos_scores) * len(neg_scores)
        auc_samples.append(auc)

    auc_samples = np.array(auc_samples)

    return BayesAUCResult(
        posterior_mean=auc_samples.mean(),
        posterior_sd=auc_samples.std(),
        ci_95=(np.percentile(auc_samples, 2.5), np.percentile(auc_samples, 97.5)),
        prob_above_random=np.mean(auc_samples > 0.5),
        prob_excellent=np.mean(auc_samples > 0.9),
        prob_acceptable=np.mean(auc_samples > 0.7),
        median=np.median(auc_samples),
        map_estimate=auc_samples[np.argmax(np.histogram(auc_samples, bins=100)[0])],
        n_samples=n_bootstrap
    )
```

---

## Part V: Bayesian Calibration Metrics

### Motivation

ECE assumes fixed bins. Bayesian approach:
1. Uncertainty in bin assignments
2. Full posterior on calibration error
3. Hierarchical model for multiple datasets

### Model: Bayesian ECE

```python
@dataclass
class BayesECEResult:
    """Bayesian Expected Calibration Error."""
    posterior_mean: float
    posterior_sd: float
    ci_95: tuple[float, float]
    prob_well_calibrated: float  # P(ECE < 0.1)
    per_bin_posteriors: List[Dict[str, float]]
    n_samples: int

def bayesian_ece(
    confidences: np.ndarray,
    correct: np.ndarray,
    n_bins: int = 10,
    n_samples: int = 1000
) -> BayesECEResult:
    """Bayesian ECE using Dirichlet-Multinomial model.

    Model:
    - Bin assignments: Multinomial with Dirichlet prior
    - Per-bin accuracy: Beta(1,1) prior (uniform)

    Posterior:
    - Bin probabilities: Dirichlet(α + counts)
    - Per-bin accuracy: Beta(1 + correct, 1 + incorrect)
    """
    # Assign to bins (soft assignment with uncertainty)
    bin_probs = np.zeros((len(confidences), n_bins))
    for i, conf in enumerate(confidences):
        bin_idx = min(int(conf * n_bins), n_bins - 1)
        # Soft assignment: neighboring bins get some probability
        bin_probs[i, bin_idx] = 0.7
        if bin_idx > 0:
            bin_probs[i, bin_idx - 1] = 0.15
        if bin_idx < n_bins - 1:
            bin_probs[i, bin_idx + 1] = 0.15

    # Posterior samples
    ece_samples = []
    per_bin_samples = [[] for _ in range(n_bins)]

    for _ in range(n_samples):
        # Sample bin counts from Dirichlet-Multinomial
        bin_counts = np.zeros(n_bins)
        bin_correct = np.zeros(n_bins)

        for i in range(len(confidences)):
            bin_idx = np.random.choice(n_bins, p=bin_probs[i] / bin_probs[i].sum())
            bin_counts[bin_idx] += 1
            if correct[i]:
                bin_correct[bin_idx] += 1

        # Sample per-bin accuracy from Beta
        ece = 0
        for b in range(n_bins):
            if bin_counts[b] > 0:
                acc = np.random.beta(1 + bin_correct[b], 1 + bin_counts[b] - bin_correct[b])
                conf = (b + 0.5) / n_bins
                ece += bin_counts[b] / len(confidences) * abs(acc - conf)
                per_bin_samples[b].append(acc)

        ece_samples.append(ece)

    ece_samples = np.array(ece_samples)

    # Per-bin summaries
    per_bin_summary = []
    for b in range(n_bins):
        if per_bin_samples[b]:
            samples = np.array(per_bin_samples[b])
            per_bin_summary.append({
                "mean": samples.mean(),
                "sd": samples.std(),
                "ci_95": (np.percentile(samples, 2.5), np.percentile(samples, 97.5))
            })

    return BayesECEResult(
        posterior_mean=ece_samples.mean(),
        posterior_sd=ece_samples.std(),
        ci_95=(np.percentile(ece_samples, 2.5), np.percentile(ece_samples, 97.5)),
        prob_well_calibrated=np.mean(ece_samples < 0.1),
        per_bin_posteriors=per_bin_summary,
        n_samples=n_samples
    )
```

---

## Part VI: Hierarchical Models for Multiple Seeds

### Motivation

Trinity uses 5 random seeds. Hierarchical model:
1. Partial pooling: Seeds share information
2. Shrinkage: Extreme estimates pulled toward group mean
3. Natural handling of between-seed variance

### Model: Partial Pooling for PPL

```python
@dataclass
class HierarchicalPPLResult:
    """Hierarchical model for PPL across multiple seeds."""
    global_mean: float  # μ: Overall mean PPL
    global_sd: float  # σ: Between-seed SD
    seed_means: List[float]  # μᵢ: Per-seed means (shrunken)
    seed_sds: List[float]  # σᵢ: Within-seed SD
    shrinkage_factors: List[float]  # How much each seed is shrunk
    prob_ppl_below_threshold: float  # P(μ < threshold)
    n_samples: int

def hierarchical_ppl(
    ppl_values: Dict[int, List[float]],  # {seed: [step1, step2, ...]}
    threshold: float = 130.0,
    n_samples: int = 2000
) -> HierarchicalPPLResult:
    """Hierarchical model for PPL across seeds.

    Model:
    yᵢⱼ ~ Normal(μᵢ, σ)  # PPL for seed i, step j
    μᵢ ~ Normal(μ, τ)    # Seed-specific mean
    μ ~ Normal(125, 20)  # Prior on global mean
    σ ~ Half-Normal(0, 10)  # Within-seed SD
    τ ~ Half-Normal(0, 5)   # Between-seed SD

    Partial pooling: μᵢ shrunk toward μ based on data for seed i.
    """
    seeds = list(ppl_values.keys())
    n_seeds = len(seeds)

    # Compute summary statistics for each seed
    seed_means_raw = np.array([np.mean(ppl_values[s]) for s in seeds])
    seed_sds_raw = np.array([np.std(ppl_values[s]) if len(ppl_values[s]) > 1 else 1.0
                            for s in seeds])
    seed_ns = np.array([len(ppl_values[s]) for s in seeds])

    # Gibbs sampling for hierarchical model
    # Initialize
    mu = 125.0
    sigma = 5.0
    tau = 2.0
    mu_i = seed_means_raw.copy()

    mu_samples = []
    tau_samples = []
    mu_i_samples = {s: [] for s in seeds}

    for _ in range(n_samples):
        # Update μ (global mean)
        # μ | μᵢ, τ ~ Normal(mean(μᵢ), τ / √n)
        precision_mu = n_seeds / tau**2 + 1 / 20**2
        mean_mu = (np.sum(mu_i) / tau**2) / precision_mu
        mu = np.random.normal(mean_mu, 1 / np.sqrt(precision_mu))

        # Update τ (between-seed SD)
        # τ | μ, μᵢ ~ Half-Normal scale based on sum of squared deviations
        ss_tau = np.sum((mu_i - mu)**2)
        tau = np.abs(np.random.normal(0, np.sqrt(2 * n_seeds / ss_tau)))
        tau = max(0.1, min(tau, 20))  # Constrain

        # Update σ (within-seed SD) — assumed known for simplicity
        # In full model, would also sample σ

        # Update μᵢ (seed-specific means)
        for i, seed in enumerate(seeds):
            # μᵢ | μ, τ, yᵢ ~ Normal(precision-weighted avg)
            precision_i = 1 / tau**2 + seed_ns[i] / sigma**2
            mean_i = (mu / tau**2 + seed_ns[i] * seed_means_raw[i] / sigma**2) / precision_i
            mu_i[i] = np.random.normal(mean_i, 1 / np.sqrt(precision_i))
            mu_i_samples[seed].append(mu_i[i])

        mu_samples.append(mu)
        tau_samples.append(tau)

    # Compute shrinkage factors
    # λ = σ² / (σ² + nᵢ * τ²) — how much shrunk toward global mean
    shrinkage_factors = []
    for i, seed in enumerate(seeds):
        lambda_i = sigma**2 / (sigma**2 + seed_ns[i] * tau**2)
        shrinkage_factors.append(lambda_i)

    # Posterior summaries
    prob_below = np.mean(np.array(mu_samples) < threshold)

    return HierarchicalPPLResult(
        global_mean=np.mean(mu_samples),
        global_sd=np.std(mu_samples),
        seed_means=[np.mean(mu_i_samples[s]) for s in seeds],
        seed_sds=[np.std(mu_i_samples[s]) for s in seeds],
        shrinkage_factors=shrinkage_factors,
        prob_ppl_below_threshold=prob_below,
        n_samples=n_samples
    )
```

---

## Part VII: Bayesian Model Comparison

### Motivation

Compare HSLM variants (ternary vs float, φ-RoPE vs learned). Bayesian model comparison naturally penalizes complexity.

### Model: Bayes Factors for Model Selection

```python
def bayes_factor_model_comparison(
    ll_model1: float,  # Log-likelihood (or marginal likelihood)
    ll_model2: float,
    prior_odds: float = 1.0
) -> Dict[str, float]:
    """Bayes factor for model comparison.

    BF₁₂ = P(Data|M₁) / P(Data|M₂)
    Posterior odds = BF₁₂ × prior odds

    Interpretation (Kass & Raftery 1995):
    - 2 ln BF > 10: Very strong evidence for M1
    - 6 < 2 ln BF < 10: Strong evidence
    - 2 < 2 ln BF < 6: Positive evidence
    - 0 < 2 ln BF < 2: Barely worth mentioning
    """
    log_bf = ll_model1 - ll_model2
    bf = np.exp(log_bf)

    # Interpretation
    if log_bf * 2 > 10:
        evidence = "Very strong for M1"
    elif log_bf * 2 > 6:
        evidence = "Strong for M1"
    elif log_bf * 2 > 2:
        evidence = "Positive for M1"
    elif log_bf * 2 > 0:
        evidence = "Barely worth mentioning"
    else:
        evidence = "Evidence for M2"

    return {
        "log_bf": log_bf,
        "bf_12": bf,
        "bf_21": 1 / bf,
        "two_ln_bf": 2 * log_bf,
        "evidence": evidence,
        "posterior_odds": bf * prior_odds
    }
```

### Bayesian Information Criterion (BIC)

```python
def bic_comparison(
    nll_1: float,  # Negative log-likelihood
    n_params_1: int,
    n_samples: int,
    nll_2: float,
    n_params_2: int
) -> Dict[str, float]:
    """Bayesian Information Criterion for model comparison.

    BIC = k * ln(n) - 2 * ln(L̂)
    ΔBIC = BIC₁ - BIC₂

    Interpretation (Kass & Raftery 1995):
    - ΔBIC > 10: Very strong evidence for M2
    - 6 < ΔBIC < 10: Strong evidence for M2
    - 2 < ΔBIC < 6: Positive evidence for M2
    - 0 < ΔBIC < 2: Weak evidence
    """
    bic_1 = n_params_1 * np.log(n_samples) + 2 * nll_1
    bic_2 = n_params_2 * np.log(n_samples) + 2 * nll_2

    delta_bic = bic_1 - bic_2

    # Interpretation (negative = favor M1)
    abs_delta = abs(delta_bic)
    if abs_delta > 10:
        strength = "Very strong"
    elif abs_delta > 6:
        strength = "Strong"
    elif abs_delta > 2:
        strength = "Positive"
    else:
        strength = "Weak"

    favored = "M1" if delta_bic < 0 else "M2"

    return {
        "bic_1": bic_1,
        "bic_2": bic_2,
        "delta_bic": delta_bic,
        "strength": strength,
        "favored": favored,
        "exp_bf_12": np.exp(-0.5 * abs(delta_bic))  # Approximate Bayes factor
    }
```

---

## Part VIII: Implementation with PyMC

### Full BEST Implementation

```python
import pymc as pm
import arviz as az

def best_pymc(
    group1: np.ndarray,
    group2: np.ndarray,
    draws: int = 2000,
    tune: int = 1000,
    chains: int = 4
) -> az.InferenceData:
    """BEST using PyMC for full MCMC inference.

    Returns ArviZ InferenceData with posterior samples.
    """
    y = np.concatenate([group1, group2])
    group_idx = np.concatenate([np.zeros(len(group1)), np.ones(len(group2))]).astype(int)

    with pm.Model() as best_model:
        # Priors (weakly informative)
        mu = pm.Normal("mu", mu=0, sigma=100, shape=2)
        sigma = pm.HalfNormal("sigma", sigma=100, shape=2)
        nu = pm.Exponential("nu", lam=1/30) + 1  # df > 1

        # Likelihood (robust t-distribution)
        likelihood = pm.StudentT(
            "likelihood",
            nu=nu,
            mu=mu[group_idx],
            sigma=sigma[group_idx],
            observed=y
        )

        # Effect size (Cohen's d)
        # δ = (μ₁ - μ₂) / σ_pooled
        sigma_pooled = pm.math.sqrt(
            ((sigma[0]**2 + sigma[1]**2) / 2)
        )
        delta = pm.Deterministic("delta", (mu[0] - mu[1]) / sigma_pooled)

        # Sampling
        trace = pm.sample(
            draws=draws,
            tune=tune,
            chains=chains,
            cores=4,
            return_inferencedata=True
        )

    return trace

# Example usage:
# trace = best_pymc(ppl_seed42, ppl_seed43)
# az.summary(trace, var_names=["delta"])  # Posterior summary
# az.plot_posterior(trace, var_names=["delta"])  # Visualization
```

### Bayesian AUC with PyMC

```python
def bayesian_auc_pymc(
    y_true: np.ndarray,
    y_score: np.ndarray,
    draws: int = 2000,
    tune: int = 1000
) -> az.InferenceData:
    """Bayesian AUC using PyMC.

    Models P(score|class) for each class, then computes AUC.
    """
    pos_scores = y_score[y_true == 1]
    neg_scores = y_score[y_true == 0]

    with pm.Model() as auc_model:
        # Priors for positive class scores
        mu_pos = pm.Normal("mu_pos", mu=0, sigma=10)
        sigma_pos = pm.HalfNormal("sigma_pos", sigma=5)

        # Priors for negative class scores
        mu_neg = pm.Normal("mu_neg", mu=0, sigma=10)
        sigma_neg = pm.HalfNormal("sigma_neg", sigma=5)

        # Likelihood
        pm.Normal("pos_likelihood", mu=mu_pos, sigma=sigma_pos, observed=pos_scores)
        pm.Normal("neg_likelihood", mu=mu_neg, sigma=sigma_neg, observed=neg_scores)

        # AUC computation (probability that random positive > random negative)
        # AUC = P(X_pos > X_neg) = Φ((μ_pos - μ_neg) / √(σ_pos² + σ_neg²))
        auc = pm.Deterministic(
            "auc",
            0.5 * (1 + pm.math.erf(
                (mu_pos - mu_neg) / pm.math.sqrt(2 * (sigma_pos**2 + sigma_neg**2))
            ))
        )

        trace = pm.sample(draws=draws, tune=tune, return_inferencedata=True)

    return trace
```

---

## Part IX: Reporting Guidelines

### What to Report (NeurIPS 2026 / ICLR 2027)

#### For Bayesian t-test Alternative:

| Element | Report | Example |
|---------|--------|---------|
| **Posterior mean** | E[δ\|data] | δ = -0.15 |
| **Credible interval** | 95% HDI | 95% HDI [-0.45, 0.15] |
| **Probability direction** | P(δ > 0) | P(δ > 0) = 0.12 |
| **Probability negligible** | P(\|δ\| < 0.2) | P(\|δ\| < 0.2) = 0.78 |
| **Effect size** | Interpretation | "TINY effect" |

#### For Bayes Factors:

| BF₁₀ | Interpretation |
|------|---------------|
| > 100 | Extreme evidence for H₁ |
| 30-100 | Very strong evidence |
| 10-30 | Strong evidence |
| 3-10 | Moderate evidence |
| 1-3 | Anecdotal evidence |
| 1 | No evidence |
| < 1/3 | Evidence for H₀ |

#### For Bayesian AUC:

| Element | Report |
|---------|--------|
| **Posterior mean** | E[AUC\|data] = 0.82 |
| **95% CI** | 95% HDI [0.76, 0.87] |
| **Prob > random** | P(AUC > 0.5) = 1.00 |
| **Prob excellent** | P(AUC > 0.9) = 0.03 |

### Sample Report Text

```
We assessed the difference in perplexity between seed 42 and seed 43
using a Bayesian alternative to the t-test (Kruschke, 2013). The
posterior mean difference in Cohen's d was -0.08 (95% HDI [-0.32, 0.16]),
with P(|d| < 0.2) = 0.89, indicating a TINY effect. The Bayes factor
was BF₁₀ = 0.18, providing moderate evidence for the null hypothesis
of no meaningful difference between seeds.
```

---

## Part X: Comparison with Frequentist Results

### Trinity Metrics: Bayesian vs Frequentist

| Metric | Frequentist | Bayesian | Advantage |
|--------|-------------|----------|-----------|
| **PPL difference** | t-test, p = 0.03 | P(d > 0) = 0.94, HDI [0.02, 0.15] | Direct probability statement |
| **AUC** | 0.82, CI [0.75, 0.89] | 0.82, HDI [0.76, 0.87], P(AUC > 0.9) = 0.02 | Custom probabilities |
| **Correlation** | r = 0.45, p = 0.001 | r = 0.45, HDI [0.22, 0.64], BF₁₀ = 12.3 | Evidence for H₁ |
| **ECE** | 0.045, CI [0.032, 0.058] | 0.045, HDI [0.035, 0.056], P(ECE < 0.1) = 1.00 | Probabilistic threshold |

### When to Use Which

| Scenario | Use Frequentist | Use Bayesian |
|----------|----------------|--------------|
| **Large sample (n > 100)** | ✅ Standard, fast | Optional |
| **Small sample (n < 20)** | ⚠️ Low power | ✅ Priors help |
| **Sequential analysis** | ❌ Inflates Type I | ✅ Natural update |
| **Multiple testing** | ❌ Need correction | ✅ Automatic penalty |
| **Interpretability** | ❌ P(Data|H₀) confusing | ✅ P(H\|Data) clear |
| **Computational cost** | ✅ Cheap | ❌ MCMC slow |

---

## Part XI: Practical Recommendations for Trinity

### 1. Use Bayesian for Primary Claims

- **H1 (PPL < 130)**: Bayesian one-sample test
- **H2 (FPGA DSP = 0)**: Deterministic, no test needed
- **H3 (Cache hit > 90%)**: Bayesian binomial test
- **H4 (Compression > 15×)**: Deterministic ratio
- **H5 (Energy < 2W)**: Bayesian one-sample test

### 2. Report Both for Supplementary Materials

- Frequentist: Standard in field,便于对比
- Bayesian: Primary analysis, clearer interpretation

### 3. Use Hierarchical Models for Seeds

- 5 seeds → partial pooling model
- Report global mean + per-seed posteriors
- Shrinkage factors show between-seed consistency

### 4. Bayes Factors for Exploratory Analysis

- E1-E3: Report BF with interpretation
- No multiple testing correction needed
- BF < 3 → not worth pursuing further

### 5. Posterior Predictive Checks for Model Validation

- Check model assumptions
- PPP-value near 0.5 → good fit
- PPP < 0.01 or > 0.99 → model misspecification

---

## Part XII: Code Structure

### File Organization

```
kaggle/eval/
├── bayesian_metrics.py         # Main Bayesian metrics
│   ├── best()                  # Bayesian t-test
│   ├── bayes_factor_two_sample()
│   ├── bayes_factor_correlation()
│   ├── bayesian_auc()
│   ├── bayesian_ece()
│   └── hierarchical_ppl()
├── bayesian_plotting.py         # Visualization utilities
│   ├── plot_posterior()         # Posterior density + HDI
│   ├── plot_bayes_factor()      # BF visualization
│   ├── plot_forest_plot()       # Multiple comparisons
│   └── plot_ppc()               # Posterior predictive check
└── tests/
    └── test_bayesian_metrics.py
```

### Data Structures

```python
@dataclass
class BayesianTestResult:
    """Standard output for all Bayesian tests."""
    test_type: str  # "BEST", "BF", "AUC", etc.
    posterior_mean: float
    posterior_sd: float
    ci_95: tuple[float, float]
    hdi_95: tuple[float, float]  # Highest Density Interval
    prob_direction: float  # P(effect > 0)
    prob_negligible: float  # P(|effect| < threshold)
    prob_small: float
    prob_medium: float
    prob_large: float
    bayes_factor: Optional[float] = None
    n_samples: int = 10000
    method: str = "MCMC"
```

---

## Part XIII: Computational Considerations

### MCMC Sampling

| Parameter | Recommendation | Reason |
|-----------|----------------|--------|
| **Chains** | 4 | Detect convergence issues |
| **Draws** | 2000 | Balance precision vs speed |
| **Tune** | 1000 | Ensure convergence |
| **Thin** | 1 | Usually unnecessary |
| **Cores** | 4 | Parallel chains |

### Convergence Diagnostics

```python
def check_convergence(trace: az.InferenceData) -> Dict[str, bool]:
    """Check MCMC convergence using R-hat and ESS."""
    summary = az.summary(trace)

    results = {}
    for var in summary.index:
        rhat = summary.loc[var, "r_hat"]
        ess_bulk = summary.loc[var, "ess_bulk"]
        ess_tail = summary.loc[var, "ess_tail"]

        results[var] = {
            "rhat_ok": rhat < 1.01,  # Gelman-Rubin criterion
            "ess_bulk_ok": ess_bulk > 400,  # Bulk ESS
            "ess_tail_ok": ess_tail > 400,  # Tail ESS
            "converged": (rhat < 1.01) and (ess_bulk > 400) and (ess_tail > 400)
        }

    return results
```

### Variational Inference for Speed

```python
def best_vi(
    group1: np.ndarray,
    group2: np.ndarray,
    samples: int = 10000
) -> az.InferenceData:
    """Variational inference for BEST (faster than MCMC).

    Use for exploratory analysis, confirm with MCMC.
    """
    y = np.concatenate([group1, group2])
    group_idx = np.concatenate([np.zeros(len(group1)), np.ones(len(group2))]).astype(int)

    with pm.Model() as best_model:
        # Same model as BEST
        mu = pm.Normal("mu", mu=0, sigma=100, shape=2)
        sigma = pm.HalfNormal("sigma", sigma=100, shape=2)
        nu = pm.Exponential("nu", lam=1/30) + 1
        pm.StudentT("likelihood", nu=nu, mu=mu[group_idx], sigma=sigma[group_idx], observed=y)

        # Variational inference
        approx = pm.fit(n=50000, method="advi")
        trace = approx.sample(samples)

    return trace
```

---

## Part XIV: References

1. Kruschke, J. (2013). "Bayesian estimation supersedes the t-test." *Journal of Experimental Psychology: General*, 142(2), 573-603.

2. Rouder, J. N., et al. (2009). "Bayesian t tests for accepting and rejecting the null hypothesis." *Psychonomic Bulletin & Review*, 16(2), 225-237.

3. Kass, R. E., & Raftery, A. E. (1995). "Bayes factors." *Journal of the American Statistical Association*, 90(430), 773-795.

4. Gelman, A., et al. (2013). *Bayesian Data Analysis* (3rd ed.). CRC Press.

5. McElreath, R. (2020). *Statistical Rethinking: A Bayesian Course with Examples in R and Stan* (2nd ed.). CRC Press.

6. Ly, A., et al. (2016). "Harmonizing Bayesian p-values: What can the Bayesian one-sample t-test tell us?" *PLOS ONE*, 11(10).

7. Nau, R. F. (2001). "De Finetti was right: Probability does not exist." *Theory and Decision*, 51(2-4), 89-124.

8. Vasilev, D. (2026). "Effect Size Standardization Framework for Trinity Metrics." *Trinity Research Documentation*.

9. Vasilev, D. (2026). "Multiple Testing Correction Framework for Trinity." *Trinity Research Documentation*.

---

## Appendix A: Quick Reference

### Common Bayesian Tests

| Test | Function | Output |
|------|----------|--------|
| **Two-sample** | `best(group1, group2)` | Posterior of δ |
| **One-sample** | `bayes_factor_one_sample(data, μ₀)` | BF₁₀ |
| **Correlation** | `bayes_factor_correlation(x, y)` | BF₁₀ |
| **AUC** | `bayesian_auc(y_true, y_score)` | Posterior of AUC |
| **ECE** | `bayesian_ece(conf, correct)` | Posterior of ECE |
| **Hierarchical** | `hierarchical_ppl(seeds)` | μ, τ, μᵢ posteriors |

### Interpretation Cheat Sheet

| Statistic | Bayesian Interpretation | Frequentist Equivalent |
|-----------|------------------------|----------------------|
| **P(δ > 0) = 0.97** | 97% probability effect is positive | p = 0.03 (reject H₀) |
| **BF₁₀ = 15** | Strong evidence for H₁ | — |
| **95% HDI [0.2, 0.8]** | 95% probability true value in interval | 95% CI (repeated sampling) |
| **P(|δ| < 0.2) = 0.05** | 5% probability negligible effect | Effect size d = 0.5 (medium) |

---

## Appendix B: Migration from Frequentist

### Migration Guide

```python
# OLD: Frequentist
from scipy import stats
t_stat, p_value = stats.ttest_ind(group1, group2)
cohens_d = (group1.mean() - group2.mean()) / pooled_std

# NEW: Bayesian
from kaggle.eval.bayesian_metrics import best, bayes_factor_two_sample
trace = best(group1, group2)
result = az.summary(trace, var_names=["delta"])
bf = bayes_factor_two_sample(group1, group2)

# Reporting
print(f"Bayesian d = {result['mean']:.2f}, 95% HDI [{result['hdi_2.5']:.2f}, {result['hdi_97.5']:.2f}]")
print(f"P(d > 0) = {prob_direction(trace):.2f}")
print(f"BF₁₀ = {bf:.2f} ({interpret_bf(bf)})")
```

---

**Document Version:** 1.0
**Last Updated:** 2026-03-26
**Status:** Ready for implementation
**Next Steps:** Implement `bayesian_metrics.py`, integrate with `scientific_metrics_v7.py`
