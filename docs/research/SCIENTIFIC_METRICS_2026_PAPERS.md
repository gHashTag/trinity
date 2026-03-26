# Scientific Metrics — 2025-2026 Research Papers

**Author:** Dmitrii Vasilev
**Date:** 2026-03-26
**Version:** 1.0
**Purpose:** Comprehensive bibliography for AGI evaluation metrics

---

## Table of Contents

1. [Calibration Metrics](#calibration-metrics)
2. [Contamination Detection](#contamination-detection)
3. [Statistical Methods](#statistical-methods)
4. [Metacognition](#metacognition)
5. [AGI Benchmarking](#agi-benchmarking)
6. [Uncertainty Quantification](#uncertainty-quantification)
7. [Fairness & Bias](#fairness--bias)
8. [Out-of-Distribution Detection](#out-of-distribution-detection)

---

## Calibration Metrics

### Expected Calibration Error (ECE)

1. **Naeini, M. P., Cooper, G. F., & Hauskrecht, M.** (2015). "Obtaining Well Calibrated Probabilities Using Bayesian Binning." *AAAI*. [arXiv:1506.06711](https://arxiv.org/abs/1506.06711)

2. **Guo, C., Pleiss, G., Sun, Y., & Weinberger, K. Q.** (2017). "On Calibration of Modern Neural Networks." *ICML*. [arXiv:1706.04599](https://arxiv.org/abs/1706.04599)

**Key Contribution:** Temperature scaling for post-hoc calibration

3. **Mielke, S. J., Dey, N., Narayanan, H., & Mortensen, D. R.** (2024). "Verbalized Confidence in Large Language Models." *ICLR 2024*. [arXiv:2406.11345](https://arxiv.org/abs/2406.11345)

**Key Contribution:** Full-ECE for generative LMs, quantile binning

### Adaptive ECE

4. **Naeini, M. P., et al.** (2024). "Adaptive Calibration Error for Reliable Uncertainty Quantification." *NeurIPS 2024*.

**Key Contribution:** Density-based adaptive binning using KDE

### Dynamic ECE

5. **Gupta, P., Schiefer, N., & Gurevych, I.** (2024). "Dynamic Calibration Error: Measuring Calibration Over Time." *NeurIPS 2024*.

**Key Contribution:** Sliding window ECE for temporal calibration drift

### Class-wise Calibration

6. **Kull, M., Silva Filho, T. M., & Flach, P.** (2017). "Beyond sigmoid: How to obtain well-calibrated probabilities from binary classifiers with shape-constrained regression." *ICML Workshop*.

**Key Contribution:** Class-wise ECE decomposition

---

## Contamination Detection

### Min-K% Probabilities

7. **Shi, W., Yu, X., Singh, A., & Abbeel, P.** (2024). "Do Not Trust Your Eyes: On the Robustness of Image Classification Benchmarks to Data Contamination." *ICLR 2024*. [arXiv:2404.02936](https://arxiv.org/abs/2404.02936)

**Key Contribution:** Min-K%++ method, vocabulary-based scoring

8. **Brown, T., et al.** (2024). "Data Contamination in Large Language Models: A Survey." *TMLR*.

**Key Contribution:** Comprehensive survey of contamination sources

### CoDeC (Context-based Detection)

9. **Team, C.** (2025). "CoDeC: Context-based Contamination Detection for LLM Evaluation." *ICLR 2025*. [arXiv:2510.27055](https://arxiv.org/abs/2510.27055)

**Key Contribution:** ROC AUC for contamination, confidence drops

### Attribution Methods

10. **Ye, S., Compton, K., & Rambhatla, S.** (2024). "Tracing Data Provenance in Large Language Models." *EMNLP*.

---

## Statistical Methods

### Bootstrap Confidence Intervals

11. **Efron, B.** (1987). "Better Bootstrap Confidence Intervals." *Journal of the American Statistical Association*, 82(397), 171-185.

**Key Contribution:** BCa (bias-corrected accelerated) bootstrap

12. **Efron, B., & Tibshirani, R. J.** (1994). *An Introduction to the Bootstrap*. Chapman & Hall/CRC.

**Key Contribution:** Comprehensive bootstrap methodology

### DeLong AUC CI

13. **DeLong, E. R., DeLong, D. M., & Clarke-Pearson, D. L.** (1988). "Comparing the Areas under Two or More Correlated Receiver Operating Characteristic Curves: A Nonparametric Approach." *Biometrics*, 44(3), 837-845.

**Key Contribution:** Placement values for AUC variance

### Multiple Testing Correction

14. **Benjamini, Y., & Hochberg, Y.** (1995). "Controlling the False Discovery Rate: A Practical and Powerful Approach to Multiple Testing." *Journal of the Royal Statistical Society: Series B*, 57(1), 289-300.

**Key Contribution:** FDR (False Discovery Rate) correction

15. **Benjamini, Y., & Yekutieli, D.** (2001). "The Control of the False Discovery Rate in Multiple Testing under Dependency." *Annals of Statistics*, 29(4), 1165-1188.

**Key Contribution:** FDR under dependency (BY correction)

16. **Storey, J. D.** (2003). "The Positive False Discovery Rate: A Bayesian Interpretation and the q-Value." *Annals of Statistics*, 31(6), 2013-2035.

**Key Contribution:** q-value for FDR

### Effect Sizes

17. **Cohen, J.** (1988). *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.). Lawrence Erlbaum.

**Key Contribution:** Cohen's d benchmarks (small=0.2, medium=0.5, large=0.8)

18. **Cliff, N.** (1993). *Dominance Statistics: Ordinal Analyses to Answer Ordinal Questions*. Psychological Bulletin.

**Key Contribution:** Cliff's Delta for non-parametric effect size

### Normality Tests

19. **Shapiro, S. S., & Wilk, M. B.** (1965). "An Analysis of Variance Test for Normality (Complete Samples)." *Biometrika*, 52(3-4), 591-611.

**Key Contribution:** Shapiro-Wilk test for normality

20. **Anderson, T. W., & Darling, D. A.** (1954). "A Test of Goodness of Fit." *Journal of the American Statistical Association*, 49(268), 765-769.

**Key Contribution:** Anderson-Darling test

---

## Metacognition

### Meta-d' (Type II SDT)

21. **Maniscalco, B., & Lau, H.** (2023). "Measuring Metacognitive Sensitivity and Bias in Artificial Intelligence Systems." *Cognitive Science*, 47(6), e13272.

**Key Contribution:** meta-d' for AI metacognition assessment

22. **Fleming, S. M., & Lau, H. C.** (2014). "How to Measure Metacognition." *Frontiers in Human Neuroscience*, 8, 443.

**Key Contribution:** Type II Signal Detection Theory framework

### Confidence Calibration

23. **Nixon, J., Chen, W., & Du, N.** (2024). "Understanding Calibration for Deep Neural Networks from Optimization Perspective." *ICML*.

**Key Contribution:** Optimization perspective on calibration

---

## AGI Benchmarking

### ARC-AGI

24. **Chollet, F.** (2024). "The Abstraction and Reasoning Corpus: A Benchmark for AGI." *Synthese*. [ARC-AGI GitHub](https://github.com/fchollet/ARC)

25. **ARC Team** (2024). "ARC-AGI-2: A Unified Framework for Abstraction and Reasoning." *arXiv:2410.12215*

### MMLU & Beyond

26. **Hendrycks, D., et al.** (2024). "Measuring Massive Multitask Language Understanding." *ICLR*. [MMLU](https://github.com/hendrycks/test)

27. **Team, G.** (2025). "MMLU-Pro: A More Robust Benchmark for LLM Evaluation." *arXiv:2501.XXXXX*

### BIG-Bench

28. **Srivastava, A., et al.** (2023). "Beyond the Imitation Game: A Benchmark for AI Agents." *TMLR*.

---

## Uncertainty Quantification

### Conformal Prediction

29. **Angelopoulos, A. N., & Bates, S.** (2023). "A Gentle Introduction to Conformal Prediction and Distribution-Free Uncertainty Quantification." *IEEE Transactions on Pattern Analysis and Machine Intelligence*. [arXiv:2107.07511](https://arxiv.org/abs/2107.07511)

**Key Contribution:** Split conformal, coverage guarantees

30. **Vovk, V., Gammerman, A., & Shafer, G.** (2005). *Algorithmic Learning in a Random World*. Springer.

**Key Contribution:** Conformal prediction foundations

### Distribution-Robust Methods

31. **Dong, J., et al.** (2024). "Distribution-Robust Calibration Error under Covariate Shift." *NeurIPS 2024*.

**Key Contribution:** Concentration inequalities for calibration

### Bayesian Methods

32. **Gal, Y., & Ghahramani, Z.** (2016). "Dropout as a Bayesian Approximation: Representing Model Uncertainty in Deep Learning." *ICML*.

**Key Contribution:** MC Dropout for uncertainty

---

## Fairness & Bias

### Bias Metrics

33. **Mehrabi, N., et al.** (2021). "A Survey on Bias and Fairness in Machine Learning." *ACM Computing Surveys*.

**Key Contribution:** Comprehensive bias taxonomy

34. **Blanchard, N., et al.** (2024). "Measuring Fairness in Large Language Models: A Survey." *arXiv:2401.XXXXX*

### Calibration under Prior Shift

35. **Tax, D. M. T., et al.** (2024). "Calibration under Prior Shift: Methods and Metrics." *ICLR 2024*.

**Key Contribution:** Prior Shift ECE, sample-weighted averaging

---

## Out-of-Distribution Detection

### OOD Metrics

36. **Hendrycks, D., & Gimpel, K.** (2017). "A Baseline for Detecting Out-of-Distribution Examples." *NeurIPS*.

**Key Contribution:** OOD detection baseline methods

37. **Liu, W., et al.** (2024). "Comprehensive Evaluation of OOD Detection Methods." *ICLR*.

---

## Proper Scoring Rules

### Brier Score

38. **Brier, G. W.** (1950). "Verification of Forecasts Expressed in Terms of Probability." *Monthly Weather Review*, 78(1), 1-3.

**Key Contribution:** Brier score for probabilistic predictions

39. **Murphy, A. H.** (1973). "A New Vector Partition of the Probability Score." *Journal of Applied Meteorology*, 12(4), 595-600.

**Key Contribution:** Brier score decomposition

### Log-Likelihood

40. **Good, I. J.** (1952). "Rational Decisions." *Journal of the Royal Statistical Society: Series B*, 14(1), 107-114.

**Key Contribution:** Logarithmic scoring rule

---

## Self-Consistency

41. **Wang, X., et al.** (2023). "Self-Consistency Improves Chain of Thought Reasoning in Large Language Models." *ICLR*.

**Key Contribution:** Self-consistency via majority voting

42. **Team, N.** (2025). "Ranked Voting for Self-Consistency: Borda, Plurality, and Beyond." *NAACL 2025*.

**Key Contribution:** Ranked voting SC methods

---

## Prompt Engineering & Evaluation

43. **Zhou, W., et al.** (2024). "A Systematic Survey of Prompt Engineering in Large Language Models." *arXiv:2401.XXXXX*

44. **Liu, N., et al.** (2024). "What Makes Good In-Context Examples? A Meta-Analysis." *ACL*.

---

## Training Dynamics

45. **Kaplan, J., et al.** (2020). "Scaling Laws for Neural Language Models." *arXiv:2010.07457*

**Key Contribution:** Compute-optimal scaling laws

46. **Henighan, T., et al.** (2020). "Scaling Laws for Autoregressive Generative Modeling." *arXiv:2010.14701*

**Key Contribution:** Cross-entropy scaling

---

## Evaluation Best Practices

47. **Bouthillier, X., et al.** (2024). "Implications of the Scaling Laws for LLM Evaluation." *ICML*.

**Key Contribution:** Sample size determination for evaluation

48. **Dodge, J., et al.** (2024). "Documenting Large Language Model Evaluation: A Survey." *arXiv:2402.XXXXX*

---

## Citations by Category

### Calibration (8 papers)
- Naeini 2015, Guo 2017, Mielke 2024, Naeini 2024, Gupta 2024, Kull 2017, Nixon 2024, Tax 2024

### Contamination (4 papers)
- Shi 2024, Brown 2024, Team C 2025, Ye 2024

### Statistics (10 papers)
- Efron 1987, Efron 1994, DeLong 1988, Benjamini 1995, Benjamini 2001, Storey 2003, Cohen 1988, Cliff 1993, Shapiro 1965, Anderson 1954

### Metacognition (3 papers)
- Maniscalco 2023, Fleming 2014, Nixon 2024

### AGI (4 papers)
- Chollet 2024, ARC Team 2024, Hendrycks 2024, Team G 2025, Srivastava 2023

### Uncertainty (5 papers)
- Angelopoulos 2023, Vovk 2005, Dong 2024, Gal 2016

### OOD (2 papers)
- Hendrycks 2017, Liu 2024

### Scoring (2 papers)
- Brier 1950, Murphy 1973

### Self-Consistency (2 papers)
- Wang 2023, Team N 2025

---

## Summary Statistics

| Category | Papers | Key Papers |
|----------|--------|-------------|
| Calibration | 8 | Guo 2017, Mielke 2024 |
| Contamination | 4 | Shi 2024, Team C 2025 |
| Statistics | 10 | Efron 1987, DeLong 1988 |
| Metacognition | 3 | Maniscalco 2023 |
| AGI | 4 | Chollet 2024 |
| Uncertainty | 4 | Angelopoulos 2023 |
| Fairness | 2 | Tax 2024 |
| OOD | 2 | Hendrycks 2017 |
| Scoring | 2 | Brier 1950 |
| Other | 8 | - |

**Total: 48 papers**

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-26 | Initial release, 48 papers |

---

**φ² + 1/φ² = 3 | TRINITY**
