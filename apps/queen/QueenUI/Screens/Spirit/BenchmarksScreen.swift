import SwiftUI

struct BenchmarksScreen: View {
    @EnvironmentObject var watcher: StateWatcher
    private let bridge = QueenBridge.shared

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                HStack {
                    Text("📈")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("BENCHMARKS")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.accent)
                        Text("Performance — VSA, Sparse Matmul, FPGA")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                }
                .padding()

                // HSLM Training — live data from senses + evolution
                hslmTrainingSection

                // Sparse ternary matmul — static (measured once)
                sparseMatmulSection

                // FPGA — static (measured once)
                fpgaSection

                // VSA — static (measured once)
                vsaSection
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
    }

    private var hslmTrainingSection: some View {
        let senses = watcher.queenSenses
        let evo = bridge.loadEvolutionState()
        let bestPPL = senses?.farm_best_ppl ?? evo?["best_ppl"] as? Double
        let bestName = evo?["best_name"] as? String ?? "R33"
        let bestStep = evo?["best_step"] as? Int
        let testRate = senses?.test_rate

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HSLM TRAINING (LIVE)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TrinityTheme.golden)
                Spacer()
                if bestPPL != nil {
                    StatusBadge(status: .up)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(label: "Best PPL", value: bestPPL.map { String(format: "%.2f", $0) } ?? "4.6", accent: TrinityTheme.golden)
                StatCard(label: "Run", value: bestName, accent: TrinityTheme.accent)
                StatCard(label: "Optimizer", value: "LAMB 1e-3")
                StatCard(label: "Schedule", value: "cosine", accent: TrinityTheme.purple)
                StatCard(label: "Test Rate", value: testRate.map { "\($0)%" } ?? "—", accent: TrinityTheme.statusOK)
                StatCard(label: "Steps", value: bestStep.map { "\($0 / 1000)K" } ?? "100K", accent: TrinityTheme.golden)
            }
        }
        .padding(.horizontal)
    }

    private var sparseMatmulSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SPARSE TERNARY MATMUL")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TrinityTheme.accent)
                Spacer()
                Text("Last measured: 2026-03-14")
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
            }

            ForEach([
                ("Branchless", "9.2x speedup", TrinityTheme.golden),
                ("Skip-zero", "4.1x speedup", TrinityTheme.accent),
                ("SIMD (NEON)", "6.8x speedup", TrinityTheme.purple),
                ("Packed 2-bit", "3.2x memory", TrinityTheme.statusOK),
            ], id: \.0) { variant, result, color in
                HStack {
                    Text(variant)
                        .font(.body.weight(.medium))
                        .foregroundStyle(TrinityTheme.textPrimary)
                    Spacer()
                    Text(result)
                        .font(.body.weight(.bold).monospacedDigit())
                        .foregroundStyle(color)
                }
                .padding()
                .background(TrinityTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
            }
        }
        .padding(.horizontal)
    }

    private var fpgaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FPGA INFERENCE (K=16)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TrinityTheme.golden)
                Spacer()
                Text("Last measured: 2026-03-15")
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(label: "Throughput", value: "5000 tok/s", accent: TrinityTheme.golden)
                StatCard(label: "DSP", value: "0 used", accent: TrinityTheme.statusOK)
                StatCard(label: "LUT", value: "~45K (71%)", accent: TrinityTheme.accent)
                StatCard(label: "BRAM", value: "100.5 (74%)", accent: TrinityTheme.purple)
            }
        }
        .padding(.horizontal)
    }

    private var vsaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("VSA OPERATIONS (dim=59049)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TrinityTheme.purple)
                Spacer()
                Text("Last measured: 2026-03-14")
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(label: "Bind", value: "< 1us")
                StatCard(label: "Bundle", value: "< 1us", accent: TrinityTheme.accent)
                StatCard(label: "Similarity", value: "< 2us", accent: TrinityTheme.golden)
                StatCard(label: "Memory/vec", value: "7.3 KB", accent: TrinityTheme.purple)
            }
        }
        .padding(.horizontal)
    }
}
