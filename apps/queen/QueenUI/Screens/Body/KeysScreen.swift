import SwiftUI

struct KeysScreen: View {
    @State private var keys: [KeyInfo] = []
    @State private var actions: [QueenActionDef] = []

    struct KeyInfo: Identifiable {
        let name: String
        let status: KeyStatus
        let redacted: String

        var id: String { name }

        enum KeyStatus {
            case present, missing, expired
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                HStack {
                    Text("\u{1F511}")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("KEYS")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.golden)
                        Text("API Keys & Tokens (redacted)")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                    ActionButton(icon: "🔑", label: "Test Keys", color: V4Color.golden,
                                 action: "keys_test")
                    let present = keys.filter { $0.status == .present }.count
                    MetricGauge(
                        label: "Valid",
                        value: Double(present),
                        maxValue: Double(max(keys.count, 1)),
                        accent: V4Color.accent
                    )
                }
                .padding()

                ForEach(keys) { key in
                    HStack(spacing: ParietalSpacing.md) {
                        Text(statusIcon(key.status))
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(key.name)
                                .font(.headline.monospaced())
                                .foregroundStyle(V4Color.textPrimary)
                            Text(key.redacted)
                                .font(.caption.monospaced())
                                .foregroundStyle(V4Color.textSecondary)
                        }

                        Spacer()

                        StatusBadge(status: key.status == .present ? .up : (key.status == .expired ? .down : .stub))
                    }
                    .padding()
                    .background(V4Color.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                    .padding(.horizontal)
                }

                // MARK: - Policy Map
                if !actions.isEmpty {
                    policyMapSection
                }
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
        .onAppear {
            scanKeys()
            actions = QueenBridge.shared.loadActions()
        }
    }

    // MARK: - Policy Map Section

    private var policyMapSection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            Text("QUEEN POLICY MAP (\(actions.count) actions)")
                .font(.caption.weight(.bold))
                .foregroundStyle(V4Color.golden)
                .padding(.horizontal)

            policyLevel(title: "L0 READ-ONLY", level: 0, color: V4Color.statusOK)
            policyLevel(title: "L1 SOFT-WRITE", level: 1, color: V4Color.golden)
            policyLevel(title: "L2 DANGEROUS", level: 2, color: V4Color.statusError)
        }
        .padding(.top, 8)
    }

    private func policyLevel(title: String, level: Int, color: Color) -> some View {
        let filtered = actions.filter { $0.level == level }
        return VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .padding(.horizontal)

            ForEach(filtered) { action in
                HStack(spacing: ParietalSpacing.sm) {
                    Text(action.emoji ?? "\u{2699}\u{FE0F}")
                        .font(.caption)
                    Text(action.label ?? "unknown")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(V4Color.textPrimary)
                    Spacer()
                    Text(action.levelLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(V2Depth.bgSidebarHover))
                        .clipShape(SwiftUI.Capsule())
                    Text("\(action.max_per_hour ?? 0)/h")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(V4Color.textSecondary)
                    if let cd = action.cooldown_sec, cd > 0 {
                        Text("\(cd)s cd")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(V4Color.textSecondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 4)
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .padding(.horizontal)
    }

    private func scanKeys() {
        let envKeys = [
            "ANTHROPIC_API_KEY", "ZAI_KEY_1", "ZAI_KEY_2", "ZAI_KEY_3",
            "RAILWAY_TOKEN", "RAILWAY_TOKEN_2", "RAILWAY_TOKEN_3",
            "ZENODO_TOKEN", "TELEGRAM_BOT_TOKEN", "AGENT_GH_TOKEN",
            "GITHUB_TOKEN", "PERPLEXITY_API_KEY", "XAI_API_KEY",
        ]

        keys = envKeys.map { name in
            let value = ProcessInfo.processInfo.environment[name]
            if let v = value, !v.isEmpty {
                let redacted = String(v.prefix(4)) + "..." + String(v.suffix(4))
                return KeyInfo(name: name, status: .present, redacted: redacted)
            } else {
                return KeyInfo(name: name, status: .missing, redacted: "not set")
            }
        }
    }

    private func statusIcon(_ status: KeyInfo.KeyStatus) -> String {
        switch status {
        case .present: return "\u{1F7E2}"
        case .missing: return "\u{1F534}"
        case .expired: return "\u{1F7E1}"
        }
    }
}
