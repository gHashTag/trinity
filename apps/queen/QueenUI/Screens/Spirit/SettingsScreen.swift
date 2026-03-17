import SwiftUI

struct SettingsScreen: View {
    @AppStorage("arenaHost") private var arenaHost = "localhost"
    @AppStorage("arenaPort") private var arenaPort = 8080
    @AppStorage("refreshInterval") private var refreshInterval = 5.0
    @AppStorage("trinityPath") private var trinityPath = ""
    @AppStorage("soundMode") private var soundMode = "full"
    @AppStorage("useCtrlEnterToSend") private var useCtrlEnterToSend = false
    @AppStorage("sessionCleanupDays") private var sessionCleanupDays = 30
    @AppStorage("chatFontSize") private var chatFontSize = 15
    @AppStorage("ollamaURL") private var ollamaURL = "http://localhost:11434"
    @AppStorage("ollamaEnabled") private var ollamaEnabled = false

    @State private var godMode = false
    @State private var ollamaModels: [String] = []
    @State private var ollamaStatus = ""
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

                // Font Size / Chat Density
                VStack(alignment: .leading, spacing: 12) {
                    Text("CHAT DISPLAY")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)

                    HStack {
                        Text("Font Size")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                            .frame(width: 100, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(chatFontSize) },
                            set: { chatFontSize = Int($0) }
                        ), in: 12...22, step: 1)
                        Text("\(chatFontSize)pt")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(TrinityTheme.textPrimary)
                            .frame(width: 40)
                    }

                    Text("The quick brown fox jumps over the lazy dog")
                        .font(.system(size: CGFloat(chatFontSize)))
                        .foregroundStyle(TrinityTheme.textPrimary)
                        .padding(8)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding()
                .background(TrinityTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                .padding(.horizontal)

                // Ollama (Local Models)
                VStack(alignment: .leading, spacing: 12) {
                    Text("OLLAMA (LOCAL MODELS)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.purple)

                    Toggle(isOn: $ollamaEnabled) {
                        VStack(alignment: .leading) {
                            Text("Enable Ollama")
                                .font(.body.weight(.medium))
                                .foregroundStyle(TrinityTheme.textPrimary)
                            Text("Connect to local Ollama instance for offline inference")
                                .font(.caption2)
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                    }

                    HStack {
                        Text("URL")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                            .frame(width: 100, alignment: .leading)
                        TextField("http://localhost:11434", text: $ollamaURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.body.monospaced())
                    }

                    HStack {
                        Button {
                            detectOllamaModels()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11))
                                Text("Detect Models")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(TrinityTheme.purple)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        if !ollamaStatus.isEmpty {
                            Text(ollamaStatus)
                                .font(.caption)
                                .foregroundStyle(ollamaStatus.contains("Found") ? TrinityTheme.statusOK : TrinityTheme.statusError)
                        }
                    }

                    if !ollamaModels.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Available Models:")
                                .font(.caption)
                                .foregroundStyle(TrinityTheme.textMuted)
                            ForEach(ollamaModels, id: \.self) { model in
                                HStack(spacing: 6) {
                                    Image(systemName: "cpu")
                                        .font(.system(size: 10))
                                        .foregroundStyle(TrinityTheme.purple)
                                    Text(model)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(TrinityTheme.textPrimary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(TrinityTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                .padding(.horizontal)

                // Input behavior
                VStack(alignment: .leading, spacing: 12) {
                    Text("INPUT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)

                    Toggle(isOn: $useCtrlEnterToSend) {
                        VStack(alignment: .leading) {
                            Text("Ctrl+Enter to send")
                                .font(.body.weight(.medium))
                                .foregroundStyle(TrinityTheme.textPrimary)
                            Text(useCtrlEnterToSend
                                ? "Enter = new line, Ctrl+Enter = send"
                                : "Enter = send, Shift+Enter = new line")
                                .font(.caption2)
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                    }

                    HStack {
                        Text("Session Cleanup")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                            .frame(width: 120, alignment: .leading)
                        Stepper(value: $sessionCleanupDays, in: 7...365, step: 7) {
                            Text("\(sessionCleanupDays) days")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(TrinityTheme.textPrimary)
                        }
                    }
                    Text("Threads older than \(sessionCleanupDays) days are auto-deleted")
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

    private func detectOllamaModels() {
        ollamaStatus = "Connecting..."
        ollamaModels = []
        let urlString = ollamaURL.trimmingCharacters(in: .whitespaces) + "/api/tags"
        guard let url = URL(string: urlString) else {
            ollamaStatus = "Invalid URL"
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    ollamaStatus = "Error: \(error.localizedDescription)"
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let models = json["models"] as? [[String: Any]] else {
                    ollamaStatus = "No models found"
                    return
                }
                let names = models.compactMap { $0["name"] as? String }
                ollamaModels = names
                ollamaStatus = "Found \(names.count) model\(names.count == 1 ? "" : "s")"
                // Save discovered models for ModelProvider
                UserDefaults.standard.set(names, forKey: "ollamaModels")
            }
        }.resume()
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
