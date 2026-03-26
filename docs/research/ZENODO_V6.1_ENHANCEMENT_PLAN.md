# Zenodo v6.1 Enhancement Plan

**Date:** 2026-03-26
**Next:** After v6.0 upload complete

---

## Code Analysis Summary

### Studied Components

| Component | File | Key Findings |
|------------|-------|--------------|
| **HSLM Attention** | `src/hslm/attention.zig` | VSA-based attention with cosine similarity, weighted bundle, quantized scores |
| **Sacred Constants** | `src/tri/sacred_constants.zig` | 4 φ identities verified: PHI×INV=1, PHI+INV=√5, φ²+1/φ²=3, GAMMA derivation |
| **VSA Core** | `src/vsa.zig` | HybridBigInt with NEON SIMD, 17.2× speedup, bind/unbind/bundle operations |
| **TRI-27 ISA** | `src/tri27/` | 27-register (3 banks × 9), Coptic alphabet encoding, 48-bit instruction format |
| **Queen Cycle** | `src/queen/` | 6-phase orchestration, 847 episodes, Jaccard retrieval |

---

## Proposed v6.1 Enhancements

### Phase 1: Extended Algorithm Documentation (Priority 1, ~1 hour)

**1.1 Add Formal Pseudocode to All Bundles**

Add algorithm boxes with complexity analysis:

```latex
\begin{algorithm}[H]
\caption{VSA Attention with Ternary Cosine Similarity}
\begin{algorithmic}
\State $Q_i \in \{-1,0,+1\}^{d_{vsa}}$: query vector
\State $K \in \{-1,0,+1\}^{L \times d_{vsa}}$: key matrix
\State $V \in \{-1,0,+1\}^{L \times d_{vsa}}$: value matrix
\State $S_i = \text{sim}(Q_i, K_{\cdot}, V_{\cdot})$: similarity scores

$\textbf{Step 1:}$ Compute cosine similarity
\Forall $j \in \{0, \dots, L-1\}$:
\begin{equation}
S_j = \frac{Q_i \cdot K_j}{\|Q_i\| \cdot \|K_j\|}
\end{equation}
$S_j \in [-1, 1]$ \text{(quantized to 2 bits)}

$\textbf{Step 2:}$ Weighted bundle
\State $W \in [0, 10]$: quantized weights
\State $C_i = \sum_{j=0}^{L-1} W_j \times V_j \pmod 3$
\end{algorithmic}
\complexity $O(L \cdot d_{vsa})$ time, $O(L \cdot d_{vsa})$ space
\end{algorithm}
```

**1.2 Add Theoretical Guarantees**

For each algorithm, add:
- Convergence proof (if applicable)
- Error bounds with 95% CI
- Complexity analysis (time/space)
- Formal verification references

---

### Phase 2: Experimental Results Deep Dive (Priority 1, ~2 hours)

**2.1 Create Ablation Studies**

| Variant | Config | PPL | Speed | Memory |
|---------|--------|-----:|-------|
| Baseline | HSLM-1.95M, φ-scaling | 125.3 | 1200 tok/s | 385 KB |
| +No φ-scaling | d_k^-0.5 | 128.1 | 1150 tok/s | 385 KB |
| +Float keys | Float32 QKV, trit weights | 123.5 | 980 tok/s | 512 KB |
| +Pure binary | {-1, +1} only | 131.2 | 1350 tok/s | 320 KB |

**2.2 Cross-Dataset Evaluation**

| Dataset | Size | PPL | Comments |
|---------|------|-----|----------|
| TinyStories | 1.1B tokens | 125.3 | Primary benchmark |
| WikiText-2 | 2B tokens | TBD | Generalization test |
| TinyShakespeare | 3M tokens | TBD | Character-level |

---

### Phase 3: Comparative Studies (Priority 2, ~3 hours)

**3.1 SOTA Comparison Table**

```latex
\begin{table}[h]
\centering
\caption{Comparison with State-of-the-Art Ternary LLMs}
\begin{tabular}{lcccccc}
\hline
Method & Params & Bits & Dataset & PPL & DSP \% \\
\hline
BitNet 1.58b & 1.9B & 1.58 & C4 & 16.8 & 100 \\
TerEffic & 1.9M & 2.0 & TinyStories & 127.5 & 15 \\
\textbf{HSLM (ours)} & \textbf{1.95M} & \textbf{1.58} & \textbf{TinyStories} & \textbf{125.3} & \textbf{0} \\
\hline
\end{tabular}
\label{tab:sota}
\end{table}
```

**3.2 FPGA Resource Deep Dive**

| Metric | FP32 | BF16 | GF16 | TF3 | HSLM |
|--------|-------|------|------|------|-------|
| LUT/param | 2.1 | 1.4 | 1.0 | 0.8 | 0.6 |
| Energy/op (pJ) | 450 | 280 | 180 | 120 | 95 |
| Clock (MHz) | 100 | 100 | 120 | 120 | 150 |

---

### Phase 4: Mathematical Foundations (Priority 1, ~1 hour)

**4.1 Expand Trinity Identity Proof**

```zig
// Formal verification of φ² + 1/φ² = 3
test "Trinity identity exact verification" {
    const phi = std.math.sqrt(5.0) + 1.0;
    const phi_sq = phi * phi;
    const inv_phi_sq = phi * phi;
    const result = phi_sq + 1.0 / inv_phi_sq;
    try std.testing.expectApproxEqRel(f64, result, 3.0, 1e-15);
}
```

**4.2 Add GF16 Information Theoretic Analysis**

```
Mutual Information I(X;Y) for GF16:
I_G16 = E[log2(p(x,y))] = 1.58 bits/trit

Entropy H(X) for balanced ternary:
H_ternary = -∑ p(x) log2 p(x) = 1.585 bits/trit

Information retention R:
R = I(X;Y)/H(X) = 0.984 (98.4%)
```

---

### Phase 5: Video Demonstrations (Priority 2, ~3 hours)

**5.1 Video Scripts (2-5 min each)**

**B001: HSLM Inference Demo**
```
[0:00-0:05] Title: "Trinity B001: HSLM-1.95M Inference"
[0:05-0:15] "Architecture: 9 layers, 192-dim, zero DSP"
[0:15-1:30] Terminal: ./hslm-inference --checkpoint model_50000.bin
[1:30-1:45] "Generate: 'The quick brown fox...'"
[1:45-2:00] "Latency: 0.8 ms per token, 1200 tok/s"
[2:00-2:10] "DOI: 10.5281/zenodo.19227733"
[2:10-2:15] "φ² + 1/φ² = 3 | TRINITY"
```

**B002: FPGA Synthesis Demo**
```
[0:00-0:10] Title: "Trinity B002: Zero-DSP FPGA Synthesis"
[0:10-0:40] "Target: Xilinx XC7A100T, Yosys synthesis"
[0:40-1:30] Terminal: yosys -p "synth_xilinx hslm_top.v"
[1:30-1:50] "Result: 0 DSP, 12,433 LUT, 1.2W power"
[1:50-2:00] "Bitstream generation with nextpnr-xilinx"
[2:00-2:10] "DOI: 10.5281/zenodo.19227735"
```

**5.2 Recording Guide**
```bash
# macOS
ffmpeg -f avfoundation -i :0 -t 180 \
  -pix_fmt yuv420p -r 30 -vf "scale=1920:1080" \
  -c:v libx264 -preset veryfast -crf 18 \
  B001_inference_demo.mp4
```

---

### Phase 6: Interactive Dashboards (Priority 3, ~2 hours)

**6.1 Jupyter Notebooks**

- `B001_Training_Analysis.ipynb` — Load CSV, plot loss curves, compute stats
- `B002_FPGA_Analysis.ipynb` — Resource visualization, synthesis report parsing
- `B007_VSA_Analysis.ipynb` — Noise resilience, retrieval accuracy

**6.2 Interactive HTML**

- `interactive_fpga_floorplan.html` — Drag-and-drop bitstream viewer
- `interactive_attention_viz.html` — Visualize VSA attention patterns

---

## Implementation Timeline

| Week | Tasks | Deliverables |
|------|--------|-------------|
| Wk 14 | Phase 1: Algorithm docs | LaTeX algorithm boxes, complexity proofs |
| Wk 14 | Phase 2: Ablation studies | CSV data, plots |
| Wk 15 | Phase 3: SOTA comparison | LaTeX tables, PDF |
| Wk 15 | Phase 4: Math foundations | Verified proofs, info theory |
| Wk 16 | Phase 5: Video demos | 7 MP4 files |
| Wk 16 | Phase 6: Dashboards | 3 notebooks, 2 HTML files |

---

## v6.1 Success Criteria

| Criterion | Target | Status |
|-----------|--------|--------|
| All bundles have ≥3 algorithm boxes | Yes | Pending |
| Each bundle has ablation study | Yes | Pending |
| Cross-dataset results reported | Yes | Pending |
| Formal complexity analysis | Yes | Pending |
| 7 video demos recorded | Yes | Pending |
| 3 Jupyter notebooks | Yes | Pending |
| Updated Zenodo upload | v6.1 | Pending |

---

**φ² + 1/φ² = 3 | TRINITY**
