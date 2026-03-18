import SwiftUI

struct VSAScreen: View {
    @State private var dimA = 729
    @State private var similarity: Double = 0
    @State private var vecA: [Int8] = []
    @State private var vecB: [Int8] = []
    @State private var bound: [Int8] = []

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                HStack {
                    Text("🔷")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("VSA")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.purple)
                        Text("Vector Symbolic Architecture — Hyperdimensional Computing")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                }
                .padding()

                // Core operations
                VStack(alignment: .leading, spacing: 12) {
                    Text("CORE OPERATIONS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
                VStack(alignment: .leading, spacing: 12) {
                    Text("LIVE DEMO (dim=\(dimA))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.golden)

                    HStack(spacing: 16) {
                        Button("Generate") { generateVectors() }
                            .buttonStyle(.bordered)
                            .tint(TrinityTheme.accent)

                        Button("Bind") { computeBind() }
                            .buttonStyle(.bordered)
                            .tint(TrinityTheme.purple)

                        Spacer()

                        Text(String(format: "cos = %.4f", similarity))
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(TrinityTheme.golden)
                    }

                    if !vecA.isEmpty {
                        HStack(spacing: 16) {
                            VStack {
                                Text("Vector A")
                                    .font(.caption2)
                                    .foregroundStyle(TrinityTheme.textMuted)
                                TritVisualizer(values: vecA, cellSize: 2)
                            }
                            VStack {
                                Text("Vector B")
                                    .font(.caption2)
                                    .foregroundStyle(TrinityTheme.textMuted)
                                TritVisualizer(values: vecB, cellSize: 2)
                            }
                            if !bound.isEmpty {
                                VStack {
                                    Text("A ⊗ B")
                                        .font(.caption2)
                                        .foregroundStyle(TrinityTheme.textMuted)
                                    TritVisualizer(values: bound, cellSize: 2)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(TrinityTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                .padding(.horizontal)

                // Math foundation
                VStack(alignment: .leading, spacing: 12) {
                    Text("MATHEMATICAL FOUNDATION")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)

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
                                .foregroundStyle(TrinityTheme.textMuted)
                                .frame(width: 100, alignment: .leading)
                            Text(value)
                                .font(.caption)
                                .foregroundStyle(TrinityTheme.textPrimary)
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(TrinityTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                .padding(.horizontal)

                // Libraries
                VStack(alignment: .leading, spacing: 8) {
                    Text("LIBRARIES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.purple)

                    ForEach([
                        ("src/vsa.zig", "Core SIMD-accelerated VSA"),
                        ("src/c_api.zig", "C FFI bridge (libtrinity-vsa)"),
                        ("libs/swift/TrinityVSA/", "Swift package"),
                    ], id: \.0) { path, desc in
                        HStack {
                            Text(path)
                                .font(.caption.monospaced())
                                .foregroundStyle(TrinityTheme.accent)
                            Spacer()
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                    }
                }
                .padding()
                .background(TrinityTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
    }

    private func opCard(_ name: String, _ desc: String, _ symbol: String) -> some View {
        VStack(spacing: 6) {
            Text(symbol)
                .font(.title3.weight(.bold).monospaced())
                .foregroundStyle(TrinityTheme.accent)
            Text(name)
                .font(.caption2.weight(.bold).monospaced())
                .foregroundStyle(TrinityTheme.textPrimary)
            Text(desc)
                .font(.caption2)
                .foregroundStyle(TrinityTheme.textMuted)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(TrinityTheme.bgCard)
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
