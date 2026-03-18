import SwiftUI

struct SacredMathScreen: View {
    private let sacred = QueenBridge.shared.sacred

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                // Header
                HStack {
                    Text("🔢")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("SACRED MATH")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.golden)
                        Text("Mathematical Foundation — Ternary {-1, 0, +1}")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                }
                .padding()

                // Trinity Identity
                VStack(spacing: 12) {
                    Text("TRINITY IDENTITY")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.golden)

                    Text("φ² + 1/φ² = 3")
                        .font(.title.weight(.bold).monospaced())
                        .foregroundStyle(TrinityTheme.accent)

                    Text(String(format: "%.10f + %.10f = %.10f",
                                sacred.phiSquared, sacred.invPhiSquared, sacred.trinityIdentity))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(TrinityTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                .padding(.horizontal)

                // Golden ratio constants
                VStack(alignment: .leading, spacing: 12) {
                    Text("GOLDEN RATIO")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        constantCard("φ", value: sacred.phi, format: "%.10f")
                        constantCard("φ²", value: sacred.phiSquared, format: "%.10f")
                        constantCard("1/φ²", value: sacred.invPhiSquared, format: "%.10f")
                        constantCard("bits/trit", value: sacred.bitsPerTrit, format: "%.5f")
                    }
                }
                .padding(.horizontal)

                // Ternary dimensions (3^k)
                VStack(alignment: .leading, spacing: 12) {
                    Text("TERNARY DIMENSIONS (3^k)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.purple)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                        ForEach(Array(sacred.dim3k.enumerated()), id: \.offset) { k, dim in
                            VStack(spacing: 4) {
                                Text("3^\(k + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(TrinityTheme.textMuted)
                                Text(formatDim(dim))
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(TrinityTheme.accent)
                            }
                            .padding(8)
                            .background(TrinityTheme.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal)

                // Sacred Predictions
                VStack(alignment: .leading, spacing: 12) {
                    Text("SACRED PREDICTIONS (SBL)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.statusWarn)

                    predictionCard(
                        id: "P-SBL-001",
                        formula: "δ_CP = (3−φ)π",
                        value: sacred.deltaCP,
                        unit: "°",
                        experiment: "DUNE",
                        timeline: "~2031"
                    )

                    predictionCard(
                        id: "P-SBL-002",
                        formula: "w₀ = −1/φ",
                        value: sacred.w0,
                        unit: "",
                        experiment: "DESI DR3",
                        timeline: "~2027"
                    )
                }
                .padding(.horizontal)

                // Memory savings
                VStack(alignment: .leading, spacing: 12) {
                    Text("TERNARY ADVANTAGES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(label: "Memory Savings", value: "20x", accent: TrinityTheme.golden)
                        StatCard(label: "Compute", value: "Add-only", accent: TrinityTheme.accent)
                        StatCard(label: "Max Dimension", value: "59,049", accent: TrinityTheme.purple)
                        StatCard(label: "Encoding", value: "1.58 bit/trit", accent: TrinityTheme.textMuted)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
    }

    private func constantCard(_ label: String, value: Double, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
            Text(String(format: format, value))
                .font(.body.weight(.bold).monospacedDigit())
                .foregroundStyle(TrinityTheme.textPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
    }

    private func predictionCard(id: String, formula: String, value: Double, unit: String, experiment: String, timeline: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(id)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TrinityTheme.golden)
                Text(formula)
                    .font(.body.weight(.medium).monospaced())
                    .foregroundStyle(TrinityTheme.accent)
                Text("\(experiment) \(timeline)")
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(String(format: "%.3f%@", value, unit))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(TrinityTheme.textPrimary)
                Text("PENDING")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(TrinityTheme.statusWarn)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(TrinityTheme.statusWarn.opacity(0.15))
                    .clipShape(SwiftUI.Capsule())
            }
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
    }

    private func formatDim(_ dim: Int) -> String {
        if dim >= 1000 {
            return "\(dim / 1000)K"
        }
        return "\(dim)"
    }
}
