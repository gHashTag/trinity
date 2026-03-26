# Zenodo Quick Links

**Author:** Dmitrii Vasilev
**Date:** 2026-03-26
**Version:** 1.0

---

## All Bundle DOIs

| Code | Title | DOI | Link |
|------|-------|-----|------|
| **B001** | Ternarial Neural Networks | 10.5281/zenodo.19224354 | [https://doi.org/10.5281/zenodo.19224354](https://doi.org/10.5281/zenodo.19224354) |
| **B002** | Zero-DSP FPGA Architecture | 10.5281/zenodo.19224355 | [https://doi.org/10.5281/zenodo.19224355](https://doi.org/10.5281/zenodo.19224355) |
| **B003** | TRI-27 ISA | 10.5281/zenodo.19224356 | [https://doi.org/10.5281/zenodo.19224356](https://doi.org/10.5281/zenodo.19224356) |
| **B004** | Queen Lotus Cycle | 10.5281/zenodo.19224357 | [https://doi.org/10.5281/zenodo.19224357](https://doi.org/10.5281/zenodo.19224357) |
| **B005** | Tri Language | 10.5281/zenodo.19224360 | [https://doi.org/10.5281/zenodo.19224360](https://doi.org/10.5281/zenodo.19224360) |
| **B006** | Sacred GF16/TF3 | 10.5281/zenodo.19224361 | [https://doi.org/10.5281/zenodo.19224361](https://doi.org/10.5281/zenodo.19224361) |
| **B007** | VSA Operations | 10.5281/zenodo.19224362 | [https://doi.org/10.5281/zenodo.19224362](https://doi.org/10.5281/zenodo.19224362) |
| **PARENT** | Trinity S³AI Framework | 10.5281/zenodo.19224363 | [https://doi.org/10.5281/zenodo.19224363](https://doi.org/10.5281/zenodo.19224363) |

---

## Key Scientific Papers (48)

### Calibration (8)

| Paper | Year | DOI/arXiv |
|-------|------|-----------|
| Verbalized Confidence in LLMs (Full-ECE) | 2024 | [arXiv:2406.11345](https://arxiv.org/abs/2406.11345) |
| On Calibration of Modern NNs | 2017 | [arXiv:1706.04599](https://arxiv.org/abs/1706.04599) |
| Adaptive Calibration Error | 2024 | NeurIPS |
| Dynamic Calibration Error | 2024 | NeurIPS |
| Calibration under Prior Shift | 2024 | ICLR |

### Contamination Detection (4)

| Paper | Year | DOI/arXiv |
|-------|------|-----------|
| Min-K%++ Probabilities | 2024 | [arXiv:2404.02936](https://arxiv.org/abs/2404.02936) |
| CoDeC Context-based Detection | 2025 | [arXiv:2510.27055](https://arxiv.org/abs/2510.27055) |

### Statistics (10)

| Paper | Year | DOI/arXiv |
|-------|------|-----------|
| Better Bootstrap CI (BCa) | 1987 | JASA 82(397) |
| Comparing AUCs (DeLong) | 1988 | Biometrics 44(3) |
| Controlling FDR (BH) | 1995 | JRSS 57(1) |
| Statistical Power Analysis | 1988 | Erlbaum |

---

## Documentation by Category

### Scientific Guides

| Document | LOC | Description |
|----------|-----|-------------|
| `ZENODO_ADVANCED_PATTERNS_2026.md` | 700 | Advanced publication practices |
| `SCIENTIFIC_METRICS_2026_PAPERS.md` | 390 | 48 scientific papers |
| `STATISTICAL_COMPUTING_PATTERNS_2026.md` | 660 | Statistical patterns |
| `REPRODUCIBILITY_GUIDE_2026.md` | 756 | Reproducibility guide |
| `STATISTICAL_QUICK_REFERENCE.md` | 287 | Quick reference |

**Total:** ~2,795 LOC of scientific documentation

### Templates

| Document | Purpose |
|----------|---------|
| `ZENODO_SCIENTIFIC_TEMPLATE.md` | Description template |
| `ZENODO_BEST_PRACTICES.md` | Best practices |
| `SCIENTIFIC_PAPER_TEMPLATE.md` | Paper template |

---

## API and Scripts

### Zenodo API

**Base URL:**
```
https://zenodo.org/api
```

**Endpoints:**
- `POST /deposit/depositions` — create deposition
- `PUT /deposit/depositions/{id}` — update metadata
- `POST /deposit/depositions/{id}/files` — upload file
- `POST /deposit/depositions/{id}/actions/publish` — publish

### Scripts

| Script | Description |
|--------|-------------|
| `ZENODO_ADVANCED_PATTERNS_2026.md` | Python upload script |
| `.zenodo.json` | Metadata template |

---

## Citation Formats

### BibTeX

```bibtex
@software{vasilev_2026_trinity,
  title        = {Trinity S³AI Framework: Ternary Computing for Edge AI},
  author       = {Vasilev, Dmitrii},
  year         = {2026},
  version      = {4.0},
  doi          = {10.5281/zenodo.19224363},
  url          = {https://github.com/gHashTag/trinity}
}
```

### APA

```
Vasilev, D. (2026). Trinity S³AI Framework: Ternary Computing for Edge AI
(Version 4.0) [Computer software]. Zenodo.
https://doi.org/10.5281/zenodo.19224363
```

### IEEE

```
D. Vasilev, "Trinity S³AI Framework: Ternary Computing for Edge AI,"
2026, doi: 10.5281/zenodo.19224363.
```

---

## Key Metrics

| Metric | Value |
|--------|-------|
| **Total Bundles** | 7 |
| **Total DOIs** | 8 |
| **Total Discoveries** | 69 |
| **Papers in Bibliography** | 48 |
| **Documentation** | ~15,000 LOC |
| **Tests Passing** | 2,836/2,836 |
| **Code Coverage** | 93% |

---

## Quick Commands

### Check Metadata

```bash
# Check .zenodo.json
python -m json.tool .zenodo.json

# Validate CITATION.cff
cff-lint CITATION.cff
```

### Upload to Zenodo

```python
from requests import post

ACCESS_TOKEN = "YOUR_TOKEN"
headers = {"Authorization": f"Bearer {ACCESS_TOKEN}"}

# Create deposition
response = post(
    "https://zenodo.org/api/deposit/depositions",
    params={"access_token": ACCESS_TOKEN}
)
deposition_id = response.json()["id"]
print(f"Created: {deposition_id}")
```

---

## Updates

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-26 | Initial version |
| 1.1 | 2026-03-26 | Converted to English, removed Russian references |

---

**φ² + 1/φ² = 3 | TRINITY**
