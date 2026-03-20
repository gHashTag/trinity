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
            VStack(spacing: ParietalSpacing.standard) {
                HStack {
                    Text("📊")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("STATE")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                        Text(".trinity/ Directory Listing")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                    StatCard(label: "Files", value: "\(stateFiles.count)")
                        .frame(width: ParietalSpacing.xxLargeFrame)
                }
                .padding()

                let totalSize = stateFiles.reduce(0) { $0 + $1.size }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                    StatCard(label: "Total Files", value: "\(stateFiles.count)", accent: V4Color.accent)
                    StatCard(label: "Total Size", value: formatSize(totalSize), accent: V4Color.golden)
                }
                .padding(.horizontal)

                // File list
                ForEach(stateFiles.sorted(by: { $0.modified > $1.modified })) { file in
                    HStack(spacing: ParietalSpacing.md) {
                        Text(fileIcon(file.name))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.name)
                                .font(.body.monospaced())
                                .foregroundStyle(V4Color.textPrimary)
                            Text(formatDate(file.modified))
                                .font(.caption2)
                                .foregroundStyle(V4Color.textSecondary)
                        }
                        Spacer()
                        Text(file.sizeFormatted)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, ParietalSpacing.xxs)
                }
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
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
