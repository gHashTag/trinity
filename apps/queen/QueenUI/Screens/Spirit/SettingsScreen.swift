import SwiftUI

struct SettingsScreen: View {
    @AppStorage("arenaHost") private var arenaHost = "localhost"
    @AppStorage("arenaPort") private var arenaPort = 8080
    @AppStorage("refreshInterval") private var refreshInterval = 5.0
    @AppStorage("trinityPath") private var trinityPath = ""
    @AppStorage("soundMode") private var soundMode = "full"

    @State private var godMode = false
    @State private var maxAutoLevel = 1
    @State private var requireApproval = true
    @State private var intervalSec = 600

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                HStack {
                    Text("\u{2699}\u{FE0F}")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("SETTINGS")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.textPrimary)
                        Text("Queen UI Configuration")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                }
                .padding()

                // Queen Daemon config
                queenDaemonSection

                // Arena connection
                VStack(alignment: .leading, spacing: 12) {
                    Text("ARENA HTTP")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)

                    HStack {
                        Text("Host")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                            .frame(width: 100, alignment: .leading)
                        TextField("localhost", text: $arenaHost)
                            .textFieldStyle(.roundedBorder)
                            .font(.body.monospaced())
                    }

                    HStack {
                        Text("Port")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                            .frame(width: 100, alignment: .leading)
                        TextField("8080", value: $arenaPort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .font(.body.monospaced())
                    }
                }
                .padding()
                .background(TrinityTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                .padding(.horizontal)

                // Sound
                VStack(alignment: .leading, spacing: 12) {
                    Text("SOUND & NOTIFICATIONS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.purple)

                    HStack {
                        Text("Sound Mode")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                            .frame(width: 100, alignment: .leading)
                        Picker("", selection: $soundMode) {
                            Text("Full").tag("full")
                            Text("Notifications Only").tag("notifications")
                            Text("Silent").tag("silent")
                        }
                        .pickerStyle(.segmented)
                    }

                    Text("Full = sounds + notifications | Notifications = banners only | Silent = nothing")
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .padding()
                .background(TrinityTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                .padding(.horizontal)

                // Refresh
                VStack(alignment: .leading, spacing: 12) {
                    Text("REFRESH")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.golden)

                    HStack {
                        Text("Interval")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                            .frame(width: 100, alignment: .leading)
                        Slider(value: $refreshInterval, in: 1...30, step: 1)
                        Text("\(Int(refreshInterval))s")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(TrinityTheme.textPrimary)
                            .frame(width: 40)
                    }
                }
                .padding()
                .background(TrinityTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                .padding(.horizontal)

                // Project path
                VStack(alignment: .leading, spacing: 12) {
                    Text("PROJECT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.purple)

                    HStack {
                        Text("Path")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                            .frame(width: 100, alignment: .leading)
                        Text(trinityPath.isEmpty ? FileManager.default.currentDirectoryPath : trinityPath)
                            .font(.caption.monospaced())
                            .foregroundStyle(TrinityTheme.textPrimary)
                    }
                }
                .padding()
                .background(TrinityTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                .padding(.horizontal)

                // About
                VStack(alignment: .leading, spacing: 8) {
                    Text("ABOUT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.textMuted)

                    HStack {
                        Text("Queen UI")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                        Spacer()
                        Text("v1.0.0")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(TrinityTheme.textPrimary)
                    }
                    HStack {
                        Text("libtrinity-queen")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                        Spacer()
                        Text("v1.0.0")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(TrinityTheme.textPrimary)
                    }
                    HStack {
                        Text("Architecture")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                        Spacer()
                        Text("3\u{00B3} = 27 screens")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.golden)
                    }
                    HStack {
                        Text("Principle")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                        Spacer()
                        Text("Swift renders, Zig computes")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.accent)
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
        .onAppear { loadQueenConfig() }
    }

    // MARK: - Queen Daemon Config

    private var queenDaemonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUEEN DAEMON")
                .font(.caption.weight(.bold))
                .foregroundStyle(TrinityTheme.golden)

            Toggle(isOn: $godMode) {
                HStack {
                    Text("\u{26A1} God Mode")
                        .font(.body.weight(.medium))
                        .foregroundStyle(godMode ? TrinityTheme.statusError : TrinityTheme.textPrimary)
                    Text("L2 + no approval")
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            }
            .onChange(of: godMode) {
                if godMode {
                    maxAutoLevel = 2
                    requireApproval = false
                }
                saveQueenConfig()
            }

            HStack {
                Text("Max Auto Level")
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .frame(width: 120, alignment: .leading)
                Picker("", selection: $maxAutoLevel) {
                    Text("L0 (read-only)").tag(0)
                    Text("L1 (soft-write)").tag(1)
                    Text("L2 (dangerous)").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: maxAutoLevel) { saveQueenConfig() }
            }

            Toggle(isOn: $requireApproval) {
                Text("Require Human Approval (L2)")
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .onChange(of: requireApproval) { saveQueenConfig() }

            HStack {
                Text("Interval")
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .frame(width: 120, alignment: .leading)
                Stepper(value: $intervalSec, in: 60...3600, step: 60) {
                    Text("\(intervalSec)s (\(intervalSec / 60)m)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(TrinityTheme.textPrimary)
                }
                .onChange(of: intervalSec) { saveQueenConfig() }
            }

            Text("Queen daemon reads config.json on next cycle")
                .font(.caption2)
                .foregroundStyle(TrinityTheme.textMuted)
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
        .padding(.horizontal)
    }

    // MARK: - Config Persistence

    private func loadQueenConfig() {
        let path = "\(FileManager.default.currentDirectoryPath)/.trinity/queen/config.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        godMode = json["god_mode"] as? Bool ?? false
        maxAutoLevel = json["max_auto_level"] as? Int ?? 1
        requireApproval = json["require_human_approval"] as? Bool ?? true
        intervalSec = json["interval_sec"] as? Int ?? 600
    }

    private func saveQueenConfig() {
        let config: [String: Any] = [
            "god_mode": godMode,
            "max_auto_level": maxAutoLevel,
            "require_human_approval": requireApproval,
            "interval_sec": intervalSec,
        ]

        let cwd = FileManager.default.currentDirectoryPath
        let dir = "\(cwd)/.trinity/queen"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let path = "\(dir)/config.json"
        if let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
