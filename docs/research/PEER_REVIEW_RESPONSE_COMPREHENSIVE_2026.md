# Peer Review Response Template 2026

**Author:** Dmitrii Vasilev
**Date:** 2026-03-26
**Version:** 1.0
**Purpose:** Comprehensive template for responding to peer reviews
**Status:** Ready for use

---

## Overview

This template provides a structured approach to responding to peer reviews for Trinity S³AI publications, ensuring professional, thorough, and effective responses.

---

## Part I: Pre-Response Preparation

### Initial Review Assessment

```markdown
## Review Summary

**Venue:** [NeurIPS/ICLR/MLSys/etc.]
**Paper ID:** [Number]
**Paper Title:** [Title]
**Reviewers:** [N] reviewers
**Overall Rating:** [Average score]
**Decision:** [Accept/Reject/Revise]

### Reviewer Sentiment

| Reviewer | Overall | Main Concerns | Main Praises |
|----------|---------|---------------|--------------|
| R1 | [Positive/Mixed/Negative] | [List] | [List] |
| R2 | [Positive/Mixed/Negative] | [List] | [List] |
| R3 | [Positive/Mixed/Negative] | [List] | [List] |

### Key Themes

1. [Theme 1] - [Which reviewers mentioned it]
2. [Theme 2] - [Which reviewers mentioned it]
3. [Theme 3] - [Which reviewers mentioned it]
```

---

## Part II: Response Structure

### General Guidelines

✅ **DO:**
- Start with gratitude for reviewers' time
- Address every point raised
- Be specific about changes made
- Provide evidence for claims
- Maintain professional tone
- Admit limitations honestly
- Cite new sources if needed

❌ **DON'T:**
- Be defensive or argumentative
- Ignore minor comments
- Dismiss concerns without evidence
- Use vague language ("we improved it")
- Attack reviewers' understanding
- Make promises you can't keep

---

## Part III: Response Templates by Category

### Template 1: Additional Experiments

**Reviewer Comment:**
> "The paper would be stronger with additional experiments on [X]."

**Response:**

```markdown
### Response to Reviewer [N]: Additional Experiments

We thank the reviewer for this suggestion. We agree that experiments on [X]
would strengthen our claims.

**New Experiments:**
We conducted [N] additional experiments:

1. **[Experiment 1]:** [Description]
   - **Method:** [Brief methodology]
   - **Results:** [Summary of findings]
   - **Interpretation:** [What it means]
   - **Location:** Added to Section [X], Figure [Y]

2. **[Experiment 2]:** [Description]
   - **Method:** [Brief methodology]
   - **Results:** [Summary of findings]
   - **Interpretation:** [What it means]
   - **Location:** Added to Appendix [Z]

**Key Findings:**
- [Finding 1 with effect size and CI]
- [Finding 2 with effect size and CI]

These experiments confirm our original conclusions and provide additional
evidence for [claim].

**Page Changes:**
- Page [X]: Added paragraph describing new experiments
- Figure [Y]: Added visualization of new results
- Table [Z]: Added comparison of old vs new results
```

### Template 2: Clarification Request

**Reviewer Comment:**
> "The description of [X] is unclear. How did you compute [Y]?"

**Response:**

```markdown
### Response to Reviewer [N]: Clarification of [X]

We apologize for the lack of clarity. Here is a detailed explanation:

**Computation of [Y]:**
[Y] is computed as:

[Y] = [Formula]

where:
- [Variable 1]: [Definition]
- [Variable 2]: [Definition]

**Step-by-step:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Example:**
For concreteness, with [example values]:
[Y] = [computed value]

**Changes:**
We have revised Section [X] to include this detailed explanation
(see Page [Y], Paragraph [Z]). We also added Algorithm [N] to clarify
the computation.
```

### Template 3: Comparison to Baseline

**Reviewer Comment:**
> "You should compare to [baseline paper]."

**Response:**

```markdown
### Response to Reviewer [N]: Comparison to [Baseline]

We thank the reviewer for suggesting this comparison. We have added a
comparison to [Baseline] ([Citation]).

**Comparison Results:**

| Model | Metric [X] | Metric [Y] | Relative |
|-------|-----------|-----------|----------|
| Trinity | [Value] | [Value] | [X% better] |
| [Baseline] | [Value] | [Value] | Baseline |
| [SOTA] | [Value] | [Value] | [Y% better] |

**Analysis:**
Trinity achieves [improvement] over [Baseline] on [metric], while
maintaining [advantage]. The gap to [SOTA] is [explanation].

**Discussion:**
We added discussion of these results in Section [X] (Page [Y]), including:
- Why Trinity outperforms [Baseline] on [aspect]
- Trade-offs between approaches
- When [Baseline] might be preferred

**New Figure:** Figure [Z] shows this comparison visually.
```

### Template 4: Limitations

**Reviewer Comment:**
> "The paper should acknowledge [limitation]."

**Response:**

```markdown
### Response to Reviewer [N]: Acknowledging [Limitation]

We appreciate this feedback. We agree that [limitation] is important to
acknowledge.

**Revised Limitations Section:**
We have expanded our limitations section (Section [X]) to include:

1. **[Limitation 1]:** [Description]
   - **Impact:** [How it affects our results]
   - **Mitigation:** [What we did / future work]

2. **[Limitation 2]:** [Description]
   - **Impact:** [How it affects our results]
   - **Mitigation:** [What we did / future work]

**Specific to [reviewer's point]:**
We explicitly acknowledge that [specific limitation]. This means that
[consequence]. Future work could address this by [suggestion].

**Changes:**
- Page [X]: Added paragraph on [limitation]
- Page [Y]: Revised future work section
```

### Template 5: Writing Clarity

**Reviewer Comment:**
> "Section [X] is difficult to follow. Please reorganize."

**Response:**

```markdown
### Response to Reviewer [N]: Reorganization of Section [X]

We have reorganized Section [X] to improve clarity based on this feedback.

**Original Structure:**
- [Old flow]
- [Old flow]
- [Old flow]

**New Structure:**
- [New improved flow]
- [New improved flow]
- [New improved flow]

**Key Improvements:**
1. **Added overview paragraph:** [What it provides]
2. **Moved [content]:** From [old location] to [new location]
3. **Added transitions:** [How sections now connect]
4. **Added examples:** [Illustrative examples added]

**Visual Aids:**
- Added Figure [Z] to illustrate [concept]
- Added Table [T] to summarize [information]

We hope this reorganization makes the section more accessible.
```

### Template 6: Statistical Concerns

**Reviewer Comment:**
> "The statistical analysis should include [test/correction]."

**Response:**

```markdown
### Response to Reviewer [N]: Statistical Improvements

We thank the reviewer for pointing out this statistical concern. We have
updated our analysis following best practices ([Citations]).

**Changes:**

1. **Effect Sizes:** All tests now report effect sizes with 95% CI
   - Cohen's d for t-tests
   - Cliff's Delta for non-parametric tests
   - See Table [X] for complete results

2. **Multiple Testing Correction:** Applied [method] correction
   - Original: [N] significant findings
   - Corrected: [M] significant findings
   - See Section [Y] for details

3. **Assumption Checks:** All assumptions verified
   - Normality: Shapiro-Wilk test reported
   - Homogeneity: Levene's test reported
   - See Appendix [Z] for full diagnostic plots

**Updated Results:**
The main conclusions remain unchanged after these improvements. [Specific
finding] remains statistically significant (p = [value], d = [value],
95% CI [[lower], [upper]]).

**Documentation:**
- Page [X]: Updated statistical methods section
- Appendix [Y]: Added diagnostic plots
- Supplementary: Added full statistical output
```

### Template 7: Disagreement (Use Carefully)

**Reviewer Comment:**
> "[Statement we disagree with]"

**Response:**

```markdown
### Response to Reviewer [N]: Regarding [Point]

We respectfully disagree with this assessment for the following reasons:

**Our Evidence:**
1. **[Evidence 1]:** [Cite result from paper or new analysis]
2. **[Evidence 2]:** [Cite result from paper or new analysis]
3. **[Evidence 3]:** [Cite external literature]

**Clarification:**
We believe there may be a misunderstanding about [aspect]. Our approach
is [explanation], not [misinterpretation].

**Additional Analysis:**
To address this concern, we conducted [additional analysis]:
- [Method]
- [Results]
- [Interpretation]

This additional analysis supports our original conclusion.

**Alternative Perspective:**
We acknowledge that [alternative view] is also reasonable. We have added
discussion of this alternative in Section [X] (Page [Y]).

We hope this clarifies our position.
```

---

## Part IV: Full Rebuttal Example

```markdown
# Rebuttal: [Paper Title]

## Summary

We thank all reviewers for their thoughtful and constructive feedback. We
appreciate the time and effort put into these reviews. Below, we address
each concern systematically.

## Overview of Changes

- [X] pages of new content added
- [Y] new figures added
- [Z] new experiments conducted
- [N] new citations added
- Major revision to Section [X] based on feedback

---

## Response to Reviewer 1

### Point 1.1: [Concern about methodology]

**Summary:** [Brief restatement]

**Response:**

[Detailed response using appropriate template]

**Changes:**
- Page [X]: [Specific change]
- Figure [Y]: [Specific change]

### Point 1.2: [Another concern]

**Summary:** [Brief restatement]

**Response:**

[Detailed response using appropriate template]

---

## Response to Reviewer 2

### Point 2.1: [Concern]

**Summary:** [Brief restatement]

**Response:**

[Detailed response using appropriate template]

---

## Response to Reviewer 3

### Point 3.1: [Concern]

**Summary:** [Brief restatement]

**Response:**

[Detailed response using appropriate template]

---

## Additional Improvements

Beyond addressing specific reviewer concerns, we have made the following
improvements:

1. **[Improvement 1]:** [Description and benefit]
2. **[Improvement 2]:** [Description and benefit]
3. **[Improvement 3]:** [Description and benefit]

---

## Conclusion

We believe these changes significantly strengthen the paper. We appreciate
the reviewers' guidance and hope the revised manuscript meets the standards
of [Venue].

**Word Count:** [N] words of new content added
**Committee:** Reviewers [ID numbers]
```

---

## Part V: Post-Rejection Response

### If Paper is Rejected

```markdown
# Response to Rejection

While we are disappointed by the rejection, we appreciate the reviewers'
feedback. Here is our plan for revision:

## Primary Concerns Addressed

1. **[Concern 1]:** We will [action]
2. **[Concern 2]:** We will [action]
3. **[Concern 3]:** We will [action]

## Plan for Resubmission

**Target Venue:** [Alternative venue]
**Timeline:** [When we will resubmit]
**Major Additions:**
- [Addition 1]
- [Addition 2]

We remain committed to this work and believe the revised version will be
significantly stronger.
```

---

## Part VI: Quick Response Templates

### For Minor Revisions

```markdown
## Minor Revisions Response

We thank the reviewers for their feedback. All comments were minor and
have been addressed as follows:

- R1.1: Fixed typo on page [X]
- R1.2: Added citation to [Paper]
- R2.1: Clarified [statement]
- R2.2: Updated Figure [X] caption

No substantive changes were required.
```

### For Major Revisions

```markdown
## Major Revisions Response

We thank the reviewers for their detailed feedback. This letter outlines
our major revisions:

## Summary of Major Changes

1. **New Experiments (Section [X])**
   - [Description]
   - Impact: [How it strengthens paper]

2. **Revised Analysis (Section [Y])**
   - [Description]
   - Impact: [How it addresses concerns]

3. **Additional Comparisons (Section [Z])**
   - [Description]
   - Impact: [How it provides context]

[Then address each point in detail as shown above]
```

---

## Part VII: Common Reviewer Concerns

### Concern: "Limited to TinyStories"

**Response Framework:**
```
1. Acknowledge: Yes, we focus on TinyStories for reproducibility
2. Justify: TinyStories provides controlled environment for ablation
3. Contextualize: HSLM is dataset-agnostic (cite other work)
4. Future: We plan to extend to larger datasets
5. Distinguish: Our focus is architectural contribution, not SOTA benchmarking
```

### Concern: "No comparison to SOTA"

**Response Framework:**
```
1. Acknowledge: We don't aim for SOTA PPL
2. Clarify: Our contribution is efficiency + interpretability
3. Provide: SOTA comparisons in efficiency (Table X)
4. Explain: Ternary trade-offs are documented
5. Add: Additional SOTA comparisons in revised version
```

### Concern: "Pure-Zig limits adoption"

**Response Framework:**
```
1. Reframe: Pure-Zig is a feature, not a bug
2. Justify: Zero external deps ensure reproducibility
3. Evidence: Zig is growing (100K+ GitHub stars)
4. Mitigate: We provide Python bindings
5. Note: Zig compiles to C for interoperability
```

### Concern: "Not enough baselines"

**Response Framework:**
```
1. Add: Requested baselines to comparison table
2. Explain: Why initial baselines were chosen
3. Contextualize: Fair comparison requires same setup
4. Acknowledge: Limitations of cross-framework comparison
5. Provide: Additional results in supplementary
```

---

## Part VIII: Tone and Style Guidelines

### Professional Language

| Instead of | Use |
|------------|-----|
| "The reviewer is wrong" | "We respectfully disagree" |
| "This is standard practice" | "This follows established methodology ([Citation])" |
| "We already explained this" | "We apologize for the lack of clarity" |
| "The reviewer misunderstood" | "There may be a misunderstanding about" |
| "This comment is not helpful" | "We appreciate the feedback, however..." |

### Acknowledging Good Feedback

```markdown
**Excellent suggestion:** We thank the reviewer for this insight, which
significantly improved our work on [aspect].

**Helpful pointer:** The reviewer's suggestion to look at [Paper] was
instrumental in improving our [section].

**Valuable insight:** This observation led us to conduct additional
analysis that strengthened our claims.
```

---

**Document Version:** 1.0
**Last Updated:** 2026-03-26
**Status:** Ready for use
**Next Steps:** Customize for each review response
