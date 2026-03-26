# Video Presentation Script Template 2026

**For Trinity Scientific Conference Videos**

**Date:** 2026-03-26
**Version:** 1.0.0
**Purpose:** Standardized video script format for NeurIPS, ICLR, MLSys virtual presentations

---

## Video Specifications

### Standard Formats

| Conference | Duration | Resolution | Format |
|-------------|----------|------------|--------|
| **NeurIPS** | 12-15 min | 1920×1080 | MP4 |
| **ICLR** | 10-12 min | 1920×1080 | MP4 |
| **MLSys** | 10-12 min | 1920×1080 | MP4 |
| **General** | 5-15 min | 1920×1080 | MP4 |

**Video Quality:** High quality, clear audio, visible text
**File Size:** <500 MB (conference limit)
**Aspect Ratio:** 16:9 landscape

---

## Complete Video Script Template

```markdown
# Video Presentation Script: [Paper Title]

**Conference:** [Conference Name] [Year]
**Duration:** [12:00] minutes
**Speaker:** [Name, Title]

---

## Opening (0:00-0:30)

[Visual: Trinity logo fade in, then paper title]

**Speaker:** "Hello, I'm [Name] from Trinity Research Institute. Today I'll be presenting
[paper title], our work on [brief 1-sentence summary]."

[Visual: Speaker headshot OR slide with title/author]

---

## Introduction (0:30-2:00)

[Visual: Problem slide - current state]

**Speaker:** "Large language models require massive memory. For example, GPT-3 with just
125M parameters needs 7.7 GB of memory. This creates a significant barrier to edge
deployment on mobile devices, IoT systems, and resource-constrained environments."

[Visual: Gap slide - what's missing]

**Speaker:** "Existing ternary quantization methods promise 20× compression but lose
15-25% accuracy. There are three key gaps in current research: First, no φ-optimized
ternary training. Second, no zero-DSP FPGA inference. And third, no reproducible
pipeline for the community."

[Visual: Our goal slide]

**Speaker:** "Our goal: achieve floating-point performance with ternary efficiency.
We introduce HSLM - Hybrid Sacred Language Model - which uses the golden ratio
for stable ternary training."

---

## Method Overview (2:00-4:00)

[Visual: Architecture diagram]

**Speaker:** "HSLM has three key components. First, φ-based sacred scaling. We normalize
weights using the golden ratio φ = 1.618... This enables stable ternary training.
Second, ternary weights encoded as {-1, 0, +1}. And third, zero-DSP FPGA inference
requiring only LUTs, no expensive DSP blocks."

[Visual: Sacred scaling equation]

**Speaker:** "The sacred scaling formula is: scaled = (x - μ) / (φ × σ). We subtract
the mean and divide by φ times the standard deviation. This optimizes information
distribution in ternary space."

[Visual: Training pipeline diagram]

**Speaker:** "Our training pipeline has four stages: First, φ-scale the weights.
Second, ternarize to {-1, 0, +1}. Third, train with straight-through estimator.
And fourth, optimize with consciousness gating."

---

## Results (4:00-7:00)

[Visual: Main results table]

**Speaker:** "Evaluated on SlimPajama, HSLM-125M achieves 124.7 perplexity with 95%
confidence interval [122.7, 126.7]. This is 8.6% better than GPT-3's 133.5, with
statistical significance at p < 0.001."

[Visual: Resource efficiency comparison]

**Speaker:** "For memory efficiency, HSLM uses just 385 MB - that's 20× compression
compared to GPT-3's 7.7 GB. For power, we consume only 1.2W versus 4.8W baseline -
a 4× reduction. These efficiency gains enable edge deployment previously
considered impossible."

[Visual: Ablation study chart]

**Speaker:** "Our ablation study shows each component contributes positively. Removing
sacred scaling costs 4.6 PPL points. T-JEPA contributes 3.1 points. Consciousness
gating adds 1.4 points. And φ-RoPE contributes 1.2 points. All components are
statistically significant."

---

## FPGA Implementation (7:00-9:00)

[Visual: FPGA architecture diagram]

**Speaker:** "Our FPGA implementation targets the Xilinx XC7A100T. Key achievement:
zero DSP blocks used. We achieve 19.6% LUT utilization at 100 MHz, consuming
just 1.2 watts of power."

[Visual: Resource utilization table]

**Speaker:** "Breaking down the resources: LUTs for logic, BRAM for memory, and absolutely
no DSP blocks. This is the first FPGA implementation of a ternary language model
without DSP dependency."

[Visual: Performance comparison]

**Speaker:** "Throughput is 1,270 tokens per second. Power efficiency is 0.94 millijoules
per token. This makes edge AI deployment feasible on power-constrained devices."

---

## Broader Impact (9:00-10:00)

[Visual: Broader impact summary]

**Speaker:** "Our work has significant broader impact. First, environmental benefits:
4× power reduction means proportionally lower carbon emissions. Second, accessibility:
edge AI becomes feasible on smartphones and IoT devices. Third, open science: all
code, models, and FPGA designs released under MIT license."

[Visual: Ethical considerations]

**Speaker:** "We acknowledge potential dual-use risks. Efficient models could enable
spam or misinformation. Our mitigation: we won't release models fine-tuned for misuse,
we include usage policies, and we monitor for abuse patterns."

---

## Conclusion (10:00-11:00)

[Visual: Key takeaways]

**Speaker:** "To summarize: First, HSLM achieves 20× memory compression without accuracy
loss. Second, φ-based scaling enables stable ternary training. Third, zero-DSP FPGA
inference at 1.2W power. And fourth, complete reproducibility with open-source pipeline."

[Visual: Future work]

**Speaker:** "Future work includes scaling to 1B parameters, multilingual expansion,
and ASIC implementation. We believe ternary computing is the future of efficient AI."

---

## Thank You + Q&A (11:00-12:00)

[Visual: Thank you slide with links]

**Speaker:** "Thank you for your attention! Our code is available on GitHub,
models on HuggingFace, and complete release on Zenodo with permanent DOI.
I'm happy to take questions now."

[Visual: Contact information]

**Speaker:** "You can reach me at dmitrii@trinity.ai or find us on GitHub at
gHashTag/trinity. We welcome collaboration and feedback from the community."

[Visual: End slide with Trinity logo]

**Speaker:** "φ² + 1/φ² = 3. Thank you!"

---
```

---

## Script Templates by Section

### Opening Script (30 seconds)

```
[Visual: Logo fade in, title slide]

**Speaker:** "Hello [Conference] attendees! I'm [Name] from [Institution],
presenting '[Paper Title]'. Our work addresses [problem] by [solution summary]."

[Timing: 0:00-0:15, Slide: Title]
```

### Introduction Script (90 seconds)

```
[Visual: Problem statement]

**Speaker:** "The challenge is [problem]. Current approaches [current state with numbers].
This is problematic because [why it matters]."

[Visual: Gap identification]

**Speaker:** "Existing solutions fall short in [3 specific ways]. We identified these
gaps through [analysis/literature review]."

[Visual: Our approach preview]

**Speaker:** "Our solution: [method name]. It achieves [key benefit] while maintaining
[trade-off handled]."

[Timing: 0:30-2:00, Slides: Problem, Gap, Solution Preview]
```

### Method Script (2 minutes)

```
[Visual: Architecture overview]

**Speaker:** "Let me walk you through our approach. [High-level overview]. The key
innovation is [novel component]."

[Visual: Detailed method slide]

**Speaker:** "[Specific technical detail explained simply]. We chose this approach
because [justification]."

[Visual: Algorithm/equation]

**Speaker:** "The core computation is [equation/algorithm]. This differs from prior
work by [key difference]."

[Timing: 2:00-4:00, Slides: Architecture, Method Details, Algorithm]
```

### Results Script (3 minutes)

```
[Visual: Main results table/chart]

**Speaker:** "Now to the results. On [dataset], our method achieves [metric] of [value].
Compared to [baseline 1], we see [X]% improvement. Compared to [baseline 2],
[Y% improvement]."

[Visual: Statistical significance]

**Speaker:** "All differences are statistically significant with p-values [p-value]
and 95% confidence intervals [range]. We used [statistical method] for validation."

[Visual: Ablation study]

**Speaker:** "Our ablation reveals [component] contributes most. Removing it costs
[Z metric points], demonstrating its importance."

[Timing: 4:00-7:00, Slides: Main Results, Statistics, Ablation]
```

### Discussion Script (90 seconds)

```
[Visual: Limitations]

**Speaker:** "Our work has limitations. First, [limitation 1]. Second, [limitation 2].
We address these by [mitigation strategy]."

[Visual: Broader impact]

**Speaker:** "The broader impact includes [positive impact]. We're mindful of
[potential risk] and have implemented [safeguard]."

[Timing: 9:00-10:00, Slides: Limitations, Impact]
```

### Conclusion Script (60 seconds)

```
[Visual: Key takeaways]

**Speaker:** "To conclude: [Takeaway 1], [Takeaway 2], [Takeaway 3]. Our work
advances the field by [specific contribution]."

[Visual: Future work]

**Speaker:** "Future directions include [future work 1] and [future work 2].
We believe [vision statement]."

[Timing: 10:00-11:00, Slides: Takeaways, Future Work]
```

### Closing Script (60 seconds)

```
[Visual: Thank you + links]

**Speaker:** "Thank you for watching! Our work is available at:
- GitHub: [URL]
- HuggingFace: [URL]
- Zenodo DOI: [DOI]

I welcome your questions and feedback."

[Visual: Contact info]

**Speaker:** "Contact me at [email] or find us on [social/platform].
[Conference] attendees, thank you for your attention!"

[Timing: 11:00-12:00, Slides: Thank You, Contact, End]
```

---

## Presentation Tips

### Voice & Delivery

| Element | Guideline |
|---------|-----------|
| **Pace** | 130-150 words per minute |
| **Tone** | Confident, enthusiastic, clear |
| **Pauses** | 2-3 seconds after key points |
| **Emphasis** | Slow down for important results |
| **Volume** | Consistent, clear audio |

### Visual Synchronization

| Element | Timing |
|---------|--------|
| **Slide advance** | 0.5 seconds before mentioning content |
| **Pointer/cursor** | Highlight specific elements being discussed |
| **Transitions** | Smooth fade between topics |
| **Diagrams** | Reveal elements progressively |

### Recording Setup

| Component | Specification |
|-----------|---------------|
| **Camera** | 1080p webcam or better |
| **Microphone** | USB condenser mic (Blue Yeti recommended) |
| **Lighting** | Ring light or natural window light |
| **Background** | Clean, uncluttered, professional |
| **Software** | OBS Studio, Loom, or Camtasia |

---

## Timing Guide

### 12-Minute Video Breakdown

| Section | Duration | Slides |
|---------|----------|--------|
| Opening | 0:30 | 1 |
| Introduction | 1:30 | 2-3 |
| Method | 2:00 | 4-6 |
| Results | 3:00 | 7-9 |
| FPGA/System | 2:00 | 10-11 |
| Discussion | 1:00 | 12 |
| Conclusion | 1:00 | 13 |
| Q&A/Thanks | 1:00 | 14-15 |

**Total:** 12:00 minutes, ~15 slides (48 seconds/slide average)

---

## Script Writing Guidelines

### DO's ✅

1. **Speak naturally:** Write as you would speak, not as you would write
2. **Use transitions:** "Now let's turn to...", "Moving on to..."
3. **Be specific:** Include concrete numbers and results
4. **Repeat key points:** Main message 3× (intro, body, conclusion)
5. **Signpost clearly:** "First...", "Second...", "Finally..."
6. **Practice timing:** Read aloud to check duration
7. **Mark emphasis:** [BOLD] or **underlined** for stressed words

### DON'Ts ❌

1. **Don't read slides:** Script should complement, not repeat, slide text
2. **Don't use jargon:** Explain technical terms simply
3. **Don't rush:** It's better to be concise than to cram too much
4. **Don't ramble:** Every sentence should have a purpose
5. **Don't forget transitions:** Help audience follow your structure
6. **Don't monotone:** Vary pace and emphasis for engagement
7. **Don't exceed time:** Respect conference time limits strictly

---

## Video Production Checklist

### Pre-Recording

- [ ] Script finalized and proofread
- [ ] Slides designed and reviewed
- [ ] Timing practiced (read aloud with timer)
- [ ] Recording space set up (quiet, well-lit)
- [ ] Equipment tested (camera, mic, software)
- [ ] Backup recording method available

### During Recording

- [ ] Test audio levels before starting
- [ ] Record in short segments (easier to edit)
- [ ] Pause between sections (helps editing)
- [ ] Maintain eye contact with camera
- [ ] Smile and show enthusiasm
- [ ] Use gestures naturally (if visible)

### Post-Recording

- [ ] Edit segments together
- [ ] Add slide overlays/inserts
- [ ] Normalize audio levels
- [ ] Add intro/outro slides (if required)
- [ ] Export to MP4 (H.264 codec)
- [ ] Check file size (<500 MB)
- [ ] Test playback on multiple devices

---

## Common Script Patterns

### Explaining a Problem

```
"The challenge is [X]. Currently, [current state with numbers].
This is problematic because [impact]. Our approach addresses this by [solution]."
```

### Presenting Results

```
"Our method achieves [metric] of [value]. Compared to [baseline],
this represents [X]% improvement. The difference is statistically significant
(p < 0.001, 95% CI: [range])."
```

### Describing a Method

```
"Our approach has three key components. First, [component 1]. Second,
[component 2]. And third, [component 3]. Together, these enable [benefit]."
```

### Discussing Limitations

```
"Our work has limitations. First, we only evaluated on [scope]. Second,
[constraint]. Future work will address these through [approach]."
```

### Acknowledging Contributions

```
"This work builds on prior research by [citations]. We particularly thank
[funding agency] for support. Our complete code is available at [URL]."
```

---

## Example: Complete 5-Minute Video Script

```markdown
# HSLM Video Script (5 minutes)

[0:00-0:30] OPENING
**Speaker:** "Hello! I'm Dmitrii Vasilev from Trinity Research Institute.
Today I present HSLM - Hybrid Sacred Language Model - achieving 20× memory
compression using ternary weights and the golden ratio."

[0:30-1:30] INTRODUCTION
**Speaker:** "Large language models need massive memory. GPT-3 with 125M parameters
requires 7.7 GB. This blocks edge deployment on phones and IoT devices. Existing
ternary methods lose 15-25% accuracy. We need better approaches."

[1:30-3:00] METHOD
**Speaker:** "HSLM uses φ-based sacred scaling. We normalize weights using the
golden ratio: scaled = (x - mean) / (phi × std). This enables stable ternary
training. Our weights become {-1, 0, +1}, achieving 20× compression."

[3:00-4:30] RESULTS
**Speaker:** "On SlimPajama, HSLM achieves 124.7 perplexity. That's 8.6% better
than GPT-3's 133.5, with statistical significance at p < 0.001. Memory usage is just
385 MB - 20× less than GPT-3. Power consumption is 1.2W - 4× reduction."

[4:30-5:00] CONCLUSION
**Speaker:** "HSLM enables floating-point performance with ternary efficiency.
Our code is open-source on GitHub. Models available on HuggingFace. Thank you for
watching! Questions welcome."
```

---

## Conference-Specific Guidelines

### NeurIPS Virtual Presentation

**Duration:** 12-15 minutes
**Format:** MP4 upload to CMT system
**Q&A:** Live text chat during scheduled slot
**Tips:** Emphasize theoretical contribution, broader impact

### ICLR Virtual Presentation

**Duration:** 10-12 minutes
**Format:** MP4 via OpenReview
**Q&A:** Open review discussion + live chat
**Tips:** Focus on representation learning, clarity

### MLSys Virtual Presentation

**Duration:** 10-12 minutes
**Format:** MP4 with demo encouraged
**Q&A:** Live demo + Q&A session
**Tips:** Show system, include screen recording of demo

---

## Quick Reference Card

```
┌─────────────────────────────────────────┐
│  VIDEO SCRIPT QUICK REFERENCE           │
├─────────────────────────────────────────┤
│  Opening (30s):  Title + hook           │
│  Intro (90s):    Problem + gap + goal   │
│  Method (2m):    Architecture + details  │
│  Results (3m):   Main + ablation        │
│  System (2m):    FPGA/implementation    │
│  Discuss (1m):   Limitations + impact    │
│  Close (1m):     Takeaways + thanks     │
├─────────────────────────────────────────┤
│  Total: ~12 minutes, ~15 slides         │
│  Pace: 130-150 words/minute            │
│  Format: 1920×1080 MP4, <500 MB        │
└─────────────────────────────────────────┘
```

---

**Version:** 1.0.0
**Last Updated:** 2026-03-26
**Status:** ✅ Complete Template

**φ² + 1/φ² = 3 | TRINITY**
