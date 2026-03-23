import SwiftUI

struct FPGAScreen: View {
    private let bridge = QueenBridge.shared

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                HStack {
                    Text("⚡")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("FPGA")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.golden)
                        Text("Artix-7 Ternary Inference — Zero DSP")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()

                    // Hardware status badge
                    let hwState = loadHardwareState()
                    if let blocker = hwState?["blocker"] as? String, !blocker.isEmpty {
                        StatusBadge(status: .down)
                    } else {
                        StatusBadge(status: .up)
                    }
                }
                .padding()

                // Synthesis results
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                    StatCard(label: "Target", value: "XC7A100T", accent: V4Color.golden)
                    StatCard(label: "DSP Used", value: "0", accent: V4Color.statusOK)
                    StatCard(label: "TMU K", value: "16", accent: V4Color.accent)
                    StatCard(label: "Throughput", value: "5000 tok/s", accent: V4Color.purple)
                }
                .padding(.horizontal)

                // K=16 results
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("K=16 WIDE BRAM (FITS)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.statusOK)

                    resourceRow("LUT", used: 19000, available: 63400, extra: "+ 6.5K RAM64M")
                    resourceRow("BRAM36-eq", used: 100, available: 135, extra: nil)
                    resourceRow("Effective LUT", used: 45000, available: 63400, extra: "~71%")
                }
                .padding()
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                .padding(.horizontal)

                // K=32 results
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("K=32 WIDE BRAM (DOESN'T FIT)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.statusError)

                    resourceRow("LUT", used: 72600, available: 63400, extra: "114% — over")
                    resourceRow("BRAM36-eq", used: 100, available: 135, extra: "74%")
                }
                .padding()
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                .padding(.horizontal)

                // Hardware state
                hardwareStateSection

                // Experience log
                experienceSection

                // Synth reports
                synthReportsSection

                // Pipeline
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("PIPELINE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.accent)

                    ForEach([
                        ("export_weights.zig", "Extract model weights"),
                        ("weight_col2wide", "Column to wide BRAM format"),
                        ("TMU wide .mem", "Memory initialization files"),
                        ("Yosys → nextpnr", "Synthesis → Place & Route"),
                        ("openFPGALoader", "Flash bitstream to FPGA"),
                    ], id: \.0) { step, desc in
                        HStack(spacing: ParietalSpacing.sm) {
                            Text("→")
                                .foregroundStyle(V4Color.accent)
                            Text(step)
                                .font(.caption.weight(.medium).monospaced())
                                .foregroundStyle(V4Color.textPrimary)
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(V4Color.textSecondary)
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                .padding(.horizontal)

                // Key files
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("KEY FILES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.purple)

                    ForEach([
                        "fpga/openxc7-synth/hslm_ternary_mac.v",
                        "fpga/openxc7-synth/hslm_full_top.bit",
                        "docs/lab/papers/trinity-fpga/fpl2026-paper.tex",
                    ], id: \.self) { path in
                        Text(path)
                            .font(.caption.monospaced())
                            .foregroundStyle(V4Color.textSecondary)
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

    // MARK: - Hardware State

    private var hardwareStateSection: some View {
        let hwState = loadHardwareState()
        return Group {
            if let hwState {
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("HARDWARE STATE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.golden)

                    if let blocker = hwState["blocker"] as? String, !blocker.isEmpty {
                        HStack(spacing: ParietalSpacing.sm) {
                            Text("BLOCKER")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(V4Color.statusError)
                            Text(blocker)
                                .font(.caption)
                                .foregroundStyle(V4Color.textPrimary)
                        }
                    }

                    if let device = hwState["device"] as? String {
                        HStack {
                            Text("Device:")
                                .font(.caption)
                                .foregroundStyle(V4Color.textSecondary)
                            Text(device)
                                .font(.caption.monospaced())
                                .foregroundStyle(V4Color.textPrimary)
                        }
                    }
                }
                .padding()
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Experience Log

    private var experienceSection: some View {
        let entries = loadExperience()
        return Group {
            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("EXPERIENCE LOG (last 5)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.purple)

                    ForEach(entries.suffix(5), id: \.description) { entry in
                        HStack(spacing: ParietalSpacing.sm) {
                            Text(entry.result == "OK" ? "OK" : "FAIL")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(entry.result == "OK"
                                    ? V4Color.statusOK : V4Color.statusError)
                            Text(entry.operation)
                                .font(.caption.monospaced())
                                .foregroundStyle(V4Color.textPrimary)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Synth Reports

    private var synthReportsSection: some View {
        let reports = synthReportFiles()
        return Group {
            if !reports.isEmpty {
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("SYNTH REPORTS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.accent)

                    ForEach(reports, id: \.self) { file in
                        Text(file)
                            .font(.caption.monospaced())
                            .foregroundStyle(V4Color.textSecondary)
                    }
                }
                .padding()
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Data Loaders

    private func loadHardwareState() -> [String: Any]? {
        let cwd = FileManager.default.currentDirectoryPath
        let path = "\(cwd)/.trinity/fpga/hardware_state.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }

    private struct ExperienceEntry {
        let operation: String
        let result: String
        var description: String { "\(operation)-\(result)" }
    }

    private func loadExperience() -> [ExperienceEntry] {
        let cwd = FileManager.default.currentDirectoryPath
        let path = "\(cwd)/.trinity/fpga/experience.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return json.compactMap { entry in
            guard let op = entry["operation"] as? String else { return nil }
            let result = entry["result"] as? String ?? "UNKNOWN"
            return ExperienceEntry(operation: op, result: result)
        }
    }

    private func synthReportFiles() -> [String] {
        let cwd = FileManager.default.currentDirectoryPath
        let dir = "\(cwd)/fpga/openxc7-synth/synth_reports"
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
        return entries.sorted()
    }

    private func resourceRow(_ name: String, used: Int, available: Int, extra: String?) -> some View {
        let pct = Double(used) / Double(available)
        let color = pct > 1.0 ? V4Color.statusError : (pct > 0.8 ? V4Color.statusWarn : V4Color.statusOK)

        return VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            HStack {
                Text(name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V4Color.textPrimary)
                Spacer()
                Text("\(used)/\(available)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(color)
                if let extra {
                    Text(extra)
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(V4Color.sidebar)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * min(pct, 1.0))
                }
            }
            .frame(height: ParietalSpacing.statusIndicatorHeight)
        }
    }
}
