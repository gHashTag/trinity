import SwiftUI

struct BenchmarksScreen: View {
    @EnvironmentObject var watcher: StateWatcher
    private let bridge = QueenBridge.shared

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                HStack {
                    Text("📈")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("BENCHMARKS")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                        Text("Performance — VSA, Sparse Matmul, FPGA")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
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
        .background(V4Color.bgWindow)
    }

    private var hslmTrainingSection: some View {
        let senses = watcher.queenSenses
        let evo = bridge.loadEvolutionState()
        let bestPPL = senses?.farm_best_ppl ?? evo?["best_ppl"] as? Double
        let bestName = evo?["best_name"] as? String ?? "R33"
        let bestStep = evo?["best_step"] as? Int
        let testRate = senses?.test_rate

        return VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            HStack {
                Text("HSLM TRAINING (LIVE)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V4Color.golden)
                Spacer()
                if bestPPL != nil {
                    StatusBadge(status: .up)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                StatCard(label: "Best PPL", value: bestPPL.map { String(format: "%.2f", $0) } ?? "4.6", accent: V4Color.golden)
                StatCard(label: "Run", value: bestName, accent: V4Color.accent)
                StatCard(label: "Optimizer", value: "LAMB 1e-3")
                StatCard(label: "Schedule", value: "cosine", accent: V4Color.purple)
                StatCard(label: "Test Rate", value: testRate.map { "\($0)%" } ?? "—", accent: V4Color.statusOK)
                StatCard(label: "Steps", value: bestStep.map { "\($0 / 1000)K" } ?? "100K", accent: V4Color.golden)
            }
        }
        .padding(.horizontal)
    }

    private var sparseMatmulSection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            HStack {
                Text("SPARSE TERNARY MATMUL")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V4Color.accent)
                Spacer()
                Text("Last measured: 2026-03-14")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }

            ForEach([
                ("Branchless", "9.2x speedup", V4Color.golden),
                ("Skip-zero", "4.1x speedup", V4Color.accent),
                ("SIMD (NEON)", "6.8x speedup", V4Color.purple),
                ("Packed 2-bit", "3.2x memory", V4Color.statusOK),
            ], id: \.0) { variant, result, color in
                HStack {
                    Text(variant)
                        .font(.body.weight(.medium))
                        .foregroundStyle(V4Color.textPrimary)
                    Spacer()
                    Text(result)
                        .font(.body.weight(.bold).monospacedDigit())
                        .foregroundStyle(color)
                }
                .padding()
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
            }
        }
        .padding(.horizontal)
    }

    private var fpgaSection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            HStack {
                Text("FPGA INFERENCE (K=16)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V4Color.golden)
                Spacer()
                Text("Last measured: 2026-03-15")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                StatCard(label: "Throughput", value: "5000 tok/s", accent: V4Color.golden)
                StatCard(label: "DSP", value: "0 used", accent: V4Color.statusOK)
                StatCard(label: "LUT", value: "~45K (71%)", accent: V4Color.accent)
                StatCard(label: "BRAM", value: "100.5 (74%)", accent: V4Color.purple)
            }
        }
        .padding(.horizontal)
    }

    private var vsaSection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            HStack {
                Text("VSA OPERATIONS (dim=59049)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V4Color.purple)
                Spacer()
                Text("Last measured: 2026-03-14")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                StatCard(label: "Bind", value: "< 1us")
                StatCard(label: "Bundle", value: "< 1us", accent: V4Color.accent)
                StatCard(label: "Similarity", value: "< 2us", accent: V4Color.golden)
                StatCard(label: "Memory/vec", value: "7.3 KB", accent: V4Color.purple)
            }
        }
        .padding(.horizontal)
    }
}
