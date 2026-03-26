# LaTeX Templates for Trinity Publications

Publication-ready LaTeX templates for Trinity S³AI research papers.

## Files

| File | Purpose | Target Venue |
|------|---------|--------------|
| `arxiv2026_b001_hslm.tex` | HSLM architecture paper v6.0 | arXiv cs.LG/cs.AI |
| `neurips2026_b001_hslm.tex` | HSLM NeurIPS submission | NeurIPS 2026 |
| `references.bib` | Bibliography | All papers |

## Compilation

### Requirements
```bash
# macOS
brew install texlive-basic

# Ubuntu/Debian  
sudo apt-get install texlive-latex-base texlive-latex-extra
```

### Build
```bash
cd docs/research/latex
pdflatex arxiv2026_b001_hslm.tex
bibtex arxiv2026_b001_hslm
pdflatex arxiv2026_b001_hslm.tex
pdflatex arxiv2026_b001_hslm.tex
```

## Figures
Linked from `../figures/`:
- `B001-Fig1_training_curve.png` — Training curve (300 DPI)
- `B001-Fig2_format_comparison.png` — Format comparison (300 DPI)

## Version
**v6.0** — Enhanced with publication-ready figures

---
**φ² + 1/φ² = 3 | TRINITY**
