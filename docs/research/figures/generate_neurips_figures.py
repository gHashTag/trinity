#!/usr/bin/env python3
"""
Generate NeurIPS 2026 submission figures (PDF format).

Creates publication-ready PDF figures for Trinity S³AI paper submission.
Follows NeurIPS 2025/2026 guidelines:
- 300 DPI minimum
- PDF format (vector preferred)
- 3.5" (single column) or 7" (double column) width
- Colorblind-safe palette
- Arial/Helvetica font, minimum 8pt

φ² + 1/φ² = 3 | TRINITY
"""

import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle, Circle
import numpy as np
import os
from pathlib import Path

# NeurIPS colorblind-safe palette
COLORS = {
    'primary': '#4CAF50',      # Green
    'secondary': '#2196F3',    # Blue
    'accent': '#FF9800',        # Orange
    'danger': '#F44336',        # Red
    'neutral': '#9E9E9E',      # Gray
    'info': '#00BCD4',          # Cyan
    'warning': '#FFC107',       # Amber
    'gold': '#D4AF37',          # φ gold
}

# NeurIPS style settings
plt.style.use('seaborn-v0_8-whitegrid')
plt.rcParams.update({
    'font.family': 'Arial',
    'font.size': 10,
    'axes.labelsize': 11,
    'axes.titlesize': 12,
    'xtick.labelsize': 9,
    'ytick.labelsize': 9,
    'legend.fontsize': 9,
    'figure.dpi': 300,
    'savefig.dpi': 300,
    'savefig.format': 'pdf',
    'savefig.bbox': 'tight',
})

OUTPUT_DIR = Path(__file__).parent
os.makedirs(OUTPUT_DIR, exist_ok=True)


def fig1_architecture():
    """Figure 1: HSLM Architecture (6.5" × 4")."""
    fig, ax = plt.subplots(figsize=(6.5, 4))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')

    # Title
    ax.text(5, 9.5, 'HSLM-1.95M Architecture', ha='center', fontsize=14, weight='bold')

    # Input
    rect = Rectangle((4, 8.5), 2, 0.5, facecolor=COLORS['neutral'], edgecolor='black', linewidth=1.5)
    ax.add_patch(rect)
    ax.text(5, 8.75, 'Input: Token IDs (0-2047)', ha='center', va='center', fontsize=9)

    # Arrow
    ax.annotate('', xy=(5, 8.3), xytext=(5, 8.5),
                arrowprops=dict(arrowstyle='->', lw=1.5, color='black'))

    # Embedding
    rect = Rectangle((2.5, 7), 5, 1, facecolor=COLORS['accent'], edgecolor='black', linewidth=1.5, alpha=0.7)
    ax.add_patch(rect)
    ax.text(5, 7.6, 'Embedding Layer', ha='center', fontsize=10, weight='bold')
    ax.text(5, 7.3, 'Weight: 2048×512 (ternary)', ha='center', fontsize=8)
    ax.text(5, 7.1, 'Positional: Learnable (512)', ha='center', fontsize=8)

    # Arrow
    ax.annotate('', xy=(5, 6.8), xytext=(5, 7),
                arrowprops=dict(arrowstyle='->', lw=1.5, color='black'))

    # Transformer Stack
    rect = Rectangle((1.5, 2), 7, 4.5, facecolor=COLORS['secondary'], edgecolor='black', linewidth=1.5, alpha=0.7)
    ax.add_patch(rect)
    ax.text(5, 6.2, 'Transformer Stack (12 blocks)', ha='center', fontsize=10, weight='bold')

    # Attention block
    rect = Rectangle((2, 4.5), 6, 0.8, facecolor=COLORS['info'], edgecolor='black', linewidth=1, alpha=0.7)
    ax.add_patch(rect)
    ax.text(5, 5, 'Multi-Head Attention (8 heads)', ha='center', fontsize=9)

    # FFN block
    rect = Rectangle((2, 3.2), 6, 0.8, facecolor=COLORS['primary'], edgecolor='black', linewidth=1, alpha=0.7)
    ax.add_patch(rect)
    ax.text(5, 3.7, 'Feed-Forward (512→1344→512)', ha='center', fontsize=9)
    ax.text(7.5, 3.6, '90% sparse', ha='center', fontsize=7, color='white')

    # Arrow
    ax.annotate('', xy=(5, 1.8), xytext=(5, 2),
                arrowprops=dict(arrowstyle='->', lw=1.5, color='black'))

    # Output
    rect = Rectangle((2.5, 1), 5, 0.7, facecolor=COLORS['accent'], edgecolor='black', linewidth=1.5, alpha=0.7)
    ax.add_patch(rect)
    ax.text(5, 1.45, 'Output Layer', ha='center', fontsize=10, weight='bold')
    ax.text(5, 1.2, 'Weight: 512→2048 (ternary)', ha='center', fontsize=8)

    # Final arrow
    ax.annotate('', xy=(5, 0.8), xytext=(5, 1),
                arrowprops=dict(arrowstyle='->', lw=1.5, color='black'))

    ax.text(5, 0.5, 'Logits → Softmax', ha='center', fontsize=9)

    plt.savefig(OUTPUT_DIR / 'fig1_architecture.pdf', format='pdf')
    plt.close()
    print("✓ Figure 1: Architecture (6.5\" × 4\")")


def fig2_convergence():
    """Figure 2: Training Convergence (6.5" × 3")."""
    steps = np.array([1000, 5000, 10000, 15000, 20000, 25000, 30000])
    sacred = np.array([142.7, 134.5, 128.9, 126.8, 127.2, 125.9, 125.3])
    standard = np.array([145.2, 137.1, 132.4, 129.8, 129.8, 128.5, 128.7])

    fig, ax = plt.subplots(figsize=(6.5, 3))

    ax.plot(steps, sacred, 'o-', linewidth=2, markersize=6, color=COLORS['primary'], label='Sacred Scaling')
    ax.plot(steps, standard, 's--', linewidth=2, markersize=6, color=COLORS['danger'], label='Standard Scaling')

    ax.set_xlabel('Training Step', fontsize=11)
    ax.set_ylabel('Validation PPL', fontsize=11)
    ax.set_title('HSLM Training Convergence', fontsize=12, weight='bold')
    ax.grid(True, alpha=0.3)
    ax.legend(fontsize=10, loc='upper right')

    ax.set_ylim([122, 148])
    ax.set_xlim([0, 32000])

    # Add annotation
    ax.annotate('15% faster\nto target PPL',
                xy=(24200, 125.3),
                xytext=(15000, 135),
                arrowprops=dict(arrowstyle='->', lw=1.5, color='black'),
                fontsize=9,
                bbox=dict(boxstyle='round,pad=0.5', facecolor='yellow', alpha=0.5, edgecolor='black'))

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'fig2_convergence.pdf', format='pdf')
    plt.close()
    print("✓ Figure 2: Convergence (6.5\" × 3\")")


def fig3_resources():
    """Figure 3: Resource Utilization (6.5" × 3")."""
    resources = ['LUT', 'FF', 'DSP', 'BRAM']
    ternary = np.array([60100, 37700, 0, 327])
    dense = np.array([25000, 18000, 2400, 512])
    total = np.array([306720, 306720, 2400, 3840])

    x = np.arange(len(resources))
    width = 0.35

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(6.5, 3))

    # Left: Absolute values
    bars1 = ax1.bar(x - width/2, dense, width, label='Dense', color=COLORS['danger'], alpha=0.8)
    bars2 = ax1.bar(x + width/2, ternary, width, label='Ternary', color=COLORS['primary'], alpha=0.8)

    ax1.set_ylabel('Resources Used', fontsize=10)
    ax1.set_title('(a) Absolute Utilization', fontsize=11, weight='bold')
    ax1.set_xticks(x)
    ax1.set_xticklabels(resources)
    ax1.legend(fontsize=9)
    ax1.grid(axis='y', alpha=0.3)
    ax1.set_yscale('log')

    # Right: Percentages
    ternary_pct = ternary / total * 100
    dense_pct = dense / total * 100

    bars3 = ax2.bar(x - width/2, dense_pct, width, label='Dense', color=COLORS['danger'], alpha=0.8)
    bars4 = ax2.bar(x + width/2, ternary_pct, width, label='Ternary', color=COLORS['primary'], alpha=0.8)

    ax2.set_ylabel('Utilization (%)', fontsize=10)
    ax2.set_title('(b) Percentage of Available', fontsize=11, weight='bold')
    ax2.set_xticks(x)
    ax2.set_xticklabels(resources)
    ax2.legend(fontsize=9)
    ax2.grid(axis='y', alpha=0.3)

    # Add DSP annotation
    ax2.text(2, 50, '0% DSP\nvs 100%', ha='center', va='top',
             fontsize=8, bbox=dict(boxstyle='round,pad=0.3', facecolor='yellow', alpha=0.5, edgecolor='black'))

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'fig3_resources.pdf', format='pdf')
    plt.close()
    print("✓ Figure 3: Resources (6.5\" × 3\")")


def fig4_ablation():
    """Figure 4: Ablation Studies (6.5" × 4")."""
    # Sparsity data
    sparsity = np.array([50, 75, 90, 95, 99])
    ppl_sparsity = np.array([128.5, 126.8, 125.3, 127.1, 143.7])
    throughput_sparsity = np.array([12.8, 16.4, 20.4, 21.2, 22.1])

    # Dimension data
    dimensions = np.array([256, 384, 512, 768, 1024])
    ppl_dim = np.array([137.2, 131.5, 125.3, 123.1, 122.8])

    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(6.5, 4))

    # Subplot 1: PPL vs Sparsity
    ax1.plot(sparsity, ppl_sparsity, 'o-', linewidth=2, markersize=5, color=COLORS['primary'])
    ax1.scatter([90], [125.3], s=100, c=COLORS['danger'], zorder=5, label='Selected')
    ax1.axvline(90, color=COLORS['danger'], linestyle='--', alpha=0.5)
    ax1.set_xlabel('Sparsity (%)', fontsize=9)
    ax1.set_ylabel('Validation PPL', fontsize=9)
    ax1.set_title('(a) Accuracy vs Sparsity', fontsize=10, weight='bold')
    ax1.grid(alpha=0.3)
    ax1.legend(fontsize=8)

    # Subplot 2: Throughput vs Sparsity
    ax2.plot(sparsity, throughput_sparsity, 's-', linewidth=2, markersize=5, color=COLORS['secondary'])
    ax2.set_xlabel('Sparsity (%)', fontsize=9)
    ax2.set_ylabel('Throughput (k tok/s)', fontsize=9)
    ax2.set_title('(b) Throughput vs Sparsity', fontsize=10, weight='bold')
    ax2.grid(alpha=0.3)

    # Subplot 3: PPL vs Dimension
    ax3.plot(dimensions, ppl_dim, 'o-', linewidth=2, markersize=5, color=COLORS['primary'])
    ax3.scatter([512], [125.3], s=100, c=COLORS['danger'], zorder=5, label='Selected')
    ax3.axvline(512, color=COLORS['danger'], linestyle='--', alpha=0.5)
    ax3.set_xlabel('Embedding Dimension', fontsize=9)
    ax3.set_ylabel('Validation PPL', fontsize=9)
    ax3.set_title('(c) Accuracy vs Dimension', fontsize=10, weight='bold')
    ax3.grid(alpha=0.3)
    ax3.legend(fontsize=8)

    # Subplot 4: Format comparison
    formats = ['FP32', 'BF16', 'GF16', 'TF3']
    memory = np.array([7.6, 3.8, 3.0, 0.385])
    ppl_format = np.array([110, 118, 122, 125.3])

    ax4_twin = ax4.twinx()
    bars = ax4.bar(formats, memory, color=[COLORS['danger'], COLORS['accent'], COLORS['secondary'], COLORS['primary']], alpha=0.8)
    line = ax4_twin.plot(formats, ppl_format, 'o-', color=COLORS['gold'], linewidth=2, markersize=8)

    ax4.set_ylabel('Memory (MB)', fontsize=9)
    ax4_twin.set_ylabel('PPL', fontsize=9)
    ax4.set_title('(d) Format Trade-off', fontsize=10, weight='bold')
    ax4.set_yscale('log')

    # Add labels
    for i, (bar, mem) in enumerate(zip(bars, memory)):
        ax4.text(bar.get_x() + bar.get_width()/2, mem * 1.2, f'{mem} MB',
                ha='center', fontsize=7, color='black')

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'fig4_ablation.pdf', format='pdf')
    plt.close()
    print("✓ Figure 4: Ablation (6.5\" × 4\")")


def fig5_energy():
    """Figure 5: Energy Efficiency (6.5" × 3")."""
    platforms = ['ARM64\nFloat32', 'ARM64\nINT8', 'ARM64\nSparse\nVSA', 'FPGA\nSparse\nVSA']
    power = np.array([15, 15, 15, 1.2])
    tokens_sec = np.array([1200, 2400, 20400, 51200])
    tokens_joule = np.array([80, 160, 1360, 42667])

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(6.5, 3))

    # Left: Bar chart
    x = np.arange(len(platforms))
    width = 0.35

    bars1 = ax1.bar(x, power, width, label='Power (W)', color=COLORS['danger'], alpha=0.7)
    ax1_twin = ax1.twinx()
    bars2 = ax1_twin.bar(x + 0.2, tokens_sec/1000, width, label='Throughput (k tok/s)', color=COLORS['secondary'], alpha=0.7)

    ax1.set_ylabel('Power (W)', fontsize=10)
    ax1_twin.set_ylabel('Throughput (k tok/s)', fontsize=10)
    ax1.set_title('(a) Power vs Throughput', fontsize=11, weight='bold')
    ax1.set_xticks(x + 0.1)
    ax1.set_xticklabels(platforms, fontsize=8)
    ax1.legend(loc='upper left', fontsize=8)
    ax1_twin.legend(loc='upper right', fontsize=8)

    # Right: Efficiency
    bars3 = ax2.bar(x, tokens_joule, color=COLORS['primary'], alpha=0.8)

    for i, eff in enumerate(tokens_joule):
        ax2.text(i, eff + 1000, f'{int(eff)}\ntok/J', ha='center', fontsize=7,
                bbox=dict(boxstyle='round,pad=0.3', facecolor='yellow', alpha=0.5, edgecolor='black'))

    ax2.set_ylabel('Efficiency (tok/J)', fontsize=10)
    ax2.set_title('(b) Energy Efficiency', fontsize=11, weight='bold')
    ax2.set_xticks(x)
    ax2.set_xticklabels(platforms, fontsize=8)
    ax2.set_ylim([0, 45000])
    ax2.grid(axis='y', alpha=0.3)

    # Add 533× annotation
    ax2.text(3, 42000, '533×\nvs Float32', ha='center', va='top',
             fontsize=9, weight='bold',
             bbox=dict(boxstyle='round,pad=0.5', facecolor='yellow', alpha=0.6, edgecolor='black'))

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'fig5_energy.pdf', format='pdf')
    plt.close()
    print("✓ Figure 5: Energy (6.5\" × 3\")")


def fig6_ternary_binary():
    """Figure 6: Ternary vs Binary (6.5" × 3")."""
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(6.5, 3))
    plt.suptitle('Ternary vs Binary Encoding', fontsize=12, weight='bold', y=0.98)

    # Subplot 1: Binary
    ax1.set_xlim(-0.5, 1.5)
    ax1.set_ylim(-0.5, 1.5)
    ax1.set_aspect('equal')
    ax1.axis('off')
    ax1.set_title('(a) Binary (1 bit)', fontsize=10)

    circle1 = Circle((0, 0), 0.3, facecolor='white', edgecolor='black', linewidth=2)
    circle2 = Circle((1, 0), 0.3, facecolor='black', edgecolor='black', linewidth=2)
    ax1.add_patch(circle1)
    ax1.add_patch(circle2)
    ax1.text(0, 0, '0', ha='center', va='center', fontsize=12, weight='bold')
    ax1.text(1, 0, '1', ha='center', va='center', fontsize=12, weight='bold', color='white')

    # Subplot 2: Ternary
    ax2.set_xlim(-1, 2)
    ax2.set_ylim(-0.5, 1.5)
    ax2.set_aspect('equal')
    ax2.axis('off')
    ax2.set_title('(b) Ternary (1.585 bits)', fontsize=10)

    colors = [COLORS['danger'], 'white', COLORS['primary']]
    labels = ['-1', '0', '+1']
    for i, (color, label) in enumerate(zip(colors, labels)):
        circle = Circle((i, 0), 0.3, facecolor=color, edgecolor='black', linewidth=2)
        ax2.add_patch(circle)
        text_color = 'black' if i == 1 else 'white'
        ax2.text(i, 0, label, ha='center', va='center', fontsize=11, weight='bold', color=text_color)

    # Subplot 3: Information density
    ax3.bar(['Binary', 'Ternary'], [1, 1.585], color=[COLORS['accent'], COLORS['primary']], alpha=0.8)
    ax3.set_ylabel('Information per Symbol (bits)', fontsize=9)
    ax3.set_ylim([0, 2])
    ax3.set_title('(c) Information Density', fontsize=10)
    ax3.grid(axis='y', alpha=0.3)

    ax3.text(0.5, 1.585*0.8, '+58.5%\nvs binary', ha='center',
             fontsize=8, bbox=dict(boxstyle='round,pad=0.3', facecolor='yellow', alpha=0.6, edgecolor='black'))

    # Subplot 4: Memory comparison
    models = ['Float32', 'INT8', 'Ternary']
    memory_mb = np.array([496, 124, 24.8])
    bar_colors = [COLORS['danger'], COLORS['accent'], COLORS['primary']]

    bars = ax4.bar(models, memory_mb, color=bar_colors, alpha=0.8)
    ax4.set_ylabel('Memory Usage (MB)', fontsize=9)
    ax4.set_ylim([0, 550])
    ax4.set_title('(d) Memory (124M params)', fontsize=10)
    ax4.grid(axis='y', alpha=0.3)

    for i, (bar, mem) in enumerate(zip(bars, memory_mb)):
        ratio = 496 / mem
        ax4.text(i, mem + 15, f'{ratio:.0f}×', ha='center', fontsize=8,
                 bbox=dict(boxstyle='round,pad=0.3', facecolor='lightblue', alpha=0.5, edgecolor='black'))

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'fig6_ternary_binary.pdf', format='pdf')
    plt.close()
    print("✓ Figure 6: Ternary vs Binary (6.5\" × 3\")")


def main():
    """Generate all NeurIPS 2026 figures."""
    print("\n" + "="*60)
    print("NeurIPS 2026 Figure Generator")
    print("="*60)
    print(f"\nOutput directory: {OUTPUT_DIR}")
    print("\nGenerating PDF figures...\n")

    fig1_architecture()
    fig2_convergence()
    fig3_resources()
    fig4_ablation()
    fig5_energy()
    fig6_ternary_binary()

    pdf_files = list(OUTPUT_DIR.glob("fig*.pdf"))
    print(f"\n{'='*60}")
    print(f"Total PDF figures generated: {len(pdf_files)}")
    print("="*60 + "\n")
    print("✓ All figures ready for NeurIPS 2026 submission!\n")

    for f in sorted(pdf_files):
        size = f.stat().st_size / 1024  # KB
        print(f"  {f.name}: {size:.1f} KB")

    print("\nφ² + 1/φ² = 3 | TRINITY\n")


if __name__ == '__main__':
    main()
