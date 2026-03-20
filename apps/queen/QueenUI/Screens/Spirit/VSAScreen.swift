import SwiftUI

struct VSAScreen: View {
    @State private var dimA = 729
    @State private var similarity: Double = 0
    @State private var vecA: [Int8] = []
    @State private var vecB: [Int8] = []
    @State private var bound: [Int8] = []

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                HStack {
                    Text("🔷")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("VSA")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.purple)
                        Text("Vector Symbolic Architecture — Hyperdimensional Computing")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                }
                .padding()

                // Core operations
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("CORE OPERATIONS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.accent)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                        opCard("bind(a,b)", "Associate", "a⊗b")
                        opCard("unbind(a,b)", "Retrieve", "a⊘b")
                        opCard("bundle(a,b)", "Merge", "a⊕b")
                        opCard("permute(v,k)", "Sequence", "ρᵏ(v)")
                        opCard("similarity", "Compare", "cos(a,b)")
                        opCard("hamming", "Distance", "d(a,b)")
                    }
                }
                .padding(.horizontal)

                // Live demo
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("LIVE DEMO (dim=\(dimA))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.golden)

                    HStack(spacing: ParietalSpacing.lg) {
                        Button("Generate") { generateVectors() }
                            .buttonStyle(.bordered)
                            .tint(V4Color.accent)

                        Button("Bind") { computeBind() }
                            .buttonStyle(.bordered)
                            .tint(V4Color.purple)

                        Spacer()

                        Text(String(format: "cos = %.4f", similarity))
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(V4Color.golden)
                    }

                    if !vecA.isEmpty {
                        HStack(spacing: ParietalSpacing.lg) {
                            VStack {
                                Text("Vector A")
                                    .font(.caption2)
                                    .foregroundStyle(V4Color.textSecondary)
                                TritVisualizer(values: vecA, cellSize: 2)
                            }
                            VStack {
                                Text("Vector B")
                                    .font(.caption2)
                                    .foregroundStyle(V4Color.textSecondary)
                                TritVisualizer(values: vecB, cellSize: 2)
                            }
                            if !bound.isEmpty {
                                VStack {
                                    Text("A ⊗ B")
                                        .font(.caption2)
                                        .foregroundStyle(V4Color.textSecondary)
                                    TritVisualizer(values: bound, cellSize: 2)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                .padding(.horizontal)

                // Math foundation
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("MATHEMATICAL FOUNDATION")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.accent)

                    ForEach([
                        ("Encoding", "Ternary {-1, 0, +1} = 1.58 bits/trit"),
                        ("Memory", "20x savings vs float32"),
                        ("Compute", "Add-only, no multiply needed"),
                        ("Self-inverse", "bind(a, a) = all +1"),
                        ("Max dim", "59,049 (3^10)"),
                        ("Identity", "φ² + 1/φ² = 3"),
                    ], id: \.0) { label, value in
                        HStack {
                            Text(label)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(V4Color.textSecondary)
                                .frame(width: ParietalSpacing.xxLargeFrame, alignment: .leading)
                            Text(value)
                                .font(.caption)
                                .foregroundStyle(V4Color.textPrimary)
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                .padding(.horizontal)

                // Libraries
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("LIBRARIES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.purple)

                    ForEach([
                        ("src/vsa.zig", "Core SIMD-accelerated VSA"),
                        ("src/c_api.zig", "C FFI bridge (libtrinity-vsa)"),
                        ("libs/swift/TrinityVSA/", "Swift package"),
                    ], id: \.0) { path, desc in
                        HStack {
                            Text(path)
                                .font(.caption.monospaced())
                                .foregroundStyle(V4Color.accent)
                            Spacer()
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(V4Color.textSecondary)
                        }
                    }
                }
                .padding()
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
    }

    private func opCard(_ name: String, _ desc: String, _ symbol: String) -> some View {
        VStack(spacing: ParietalSpacing.sm - 2) {
            Text(symbol)
                .font(.title3.weight(.bold).monospaced())
                .foregroundStyle(V4Color.accent)
            Text(name)
                .font(.caption2.weight(.bold).monospaced())
                .foregroundStyle(V4Color.textPrimary)
            Text(desc)
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func generateVectors() {
        vecA = (0..<dimA).map { _ in Int8.random(in: -1...1) }
        vecB = (0..<dimA).map { _ in Int8.random(in: -1...1) }
        bound = []
        computeSimilarity()
    }

    private func computeBind() {
        guard vecA.count == vecB.count else { return }
        bound = zip(vecA, vecB).map { $0 * $1 }
    }

    private func computeSimilarity() {
        guard vecA.count == vecB.count, !vecA.isEmpty else { similarity = 0; return }
        let dot = zip(vecA, vecB).reduce(0.0) { $0 + Double($1.0) * Double($1.1) }
        let normA = sqrt(vecA.reduce(0.0) { $0 + Double($1) * Double($1) })
        let normB = sqrt(vecB.reduce(0.0) { $0 + Double($1) * Double($1) })
        similarity = (normA > 0 && normB > 0) ? dot / (normA * normB) : 0
    }
}
