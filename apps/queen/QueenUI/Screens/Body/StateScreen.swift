import SwiftUI

struct StateScreen: View {
    @State private var stateFiles: [StateFile] = []

    struct StateFile: Identifiable {
        let name: String
        let size: Int
        let modified: Date

        var id: String { name }
        var sizeFormatted: String {
            if size > 1024 * 1024 { return "\(size / 1024 / 1024) MB" }
            if size > 1024 { return "\(size / 1024) KB" }
            return "\(size) B"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                HStack {
                    Text("📊")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("STATE")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.accent)
                        Text(".trinity/ Directory Listing")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                    StatCard(label: "Files", value: "\(stateFiles.count)")
                        .frame(width: 100)
                }
                .padding()

                let totalSize = stateFiles.reduce(0) { $0 + $1.size }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(label: "Total Files", value: "\(stateFiles.count)", accent: TrinityTheme.accent)
                    StatCard(label: "Total Size", value: formatSize(totalSize), accent: TrinityTheme.golden)
                }
                .padding(.horizontal)

                // File list
                ForEach(stateFiles.sorted(by: { $0.modified > $1.modified })) { file in
                    HStack(spacing: 12) {
                        Text(fileIcon(file.name))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.name)
                                .font(.body.monospaced())
                                .foregroundStyle(TrinityTheme.textPrimary)
                            Text(formatDate(file.modified))
                                .font(.caption2)
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                        Spacer()
                        Text(file.sizeFormatted)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
        .onAppear { scanState() }
    }

    private func scanState() {
        let path = "\(FileManager.default.currentDirectoryPath)/.trinity"
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: path) else { return }

        stateFiles = items.compactMap { name -> StateFile? in
            let fullPath = "\(path)/\(name)"
            guard let attrs = try? fm.attributesOfItem(atPath: fullPath) else { return nil }
            let size = attrs[.size] as? Int ?? 0
            let modified = attrs[.modificationDate] as? Date ?? Date()
            return StateFile(name: name, size: size, modified: modified)
        }
    }

    private func fileIcon(_ name: String) -> String {
        if name.hasSuffix(".json") { return "📄" }
        if name.hasSuffix(".jsonl") { return "📋" }
        if name.hasSuffix(".dat") { return "💾" }
        return "📁"
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }

    private func formatSize(_ bytes: Int) -> String {
        if bytes > 1024 * 1024 { return "\(bytes / 1024 / 1024) MB" }
        if bytes > 1024 { return "\(bytes / 1024) KB" }
        return "\(bytes) B"
    }
}
