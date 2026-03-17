// Share Sheet View — Content Sharing
import SwiftUI

// MARK: - Share Sheet

struct ShareSheet: View {
    let items: [Any]
    private let isVisibleBinding: Binding<Bool>

    init(
        items: [Any],
        isVisible: Binding<Bool>
    ) {
        self.items = items
        self.isVisibleBinding = isVisible
    }

    private var isVisible: Bool {
        get { isVisibleBinding.wrappedValue }
        nonmutating set { isVisibleBinding.wrappedValue = newValue }
    }

    var body: some View {
        if isVisibleBinding.wrappedValue {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isVisibleBinding.wrappedValue = false
                    }

                VStack(spacing: 16) {
                    Text("Share")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TrinityTheme.textPrimary)

                    shareOptions

                    Button {
                        isVisibleBinding.wrappedValue = false
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14))
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: TrinityTheme.cornerLarge)
                        .fill(TrinityTheme.bgCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TrinityTheme.cornerLarge)
                        .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 20)
                .padding(.horizontal, 40)
            }
        }
    }

    private var shareOptions: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 20) {
            ShareSheetOption(icon: "square.and.arrow.up", title: "Copy") {
                copyToClipboard()
            }
            ShareSheetOption(icon: "link", title: "Copy Link") {
                copyLink()
            }
            ShareSheetOption(icon: "envelope", title: "Email") {
                shareViaEmail()
            }
            ShareSheetOption(icon: "message", title: "Message") {
                shareViaMessage()
            }
        }
        .padding(.vertical, 8)
    }

    private func copyToClipboard() {
        guard let item = items.first else { return }
        if let string = item as? String {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        }
        isVisibleBinding.wrappedValue = false
    }

    private func copyLink() {
        guard let item = items.first as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item, forType: .string)
        isVisibleBinding.wrappedValue = false
    }

    private func shareViaEmail() {
        guard let item = items.first as? String else { return }
        let service = NSSharingService(named: .composeEmail)
        service?.perform(withItems: [item])
        isVisibleBinding.wrappedValue = false
    }

    private func shareViaMessage() {
        guard let item = items.first as? String else { return }
        let service = NSSharingService(named: .composeMessage)
        service?.perform(withItems: [item])
        isVisibleBinding.wrappedValue = false
    }
}

// MARK: - Share Option

struct ShareSheetOption: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(TrinityTheme.accent)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(TrinityTheme.accent.opacity(0.1))
                    )

                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(TrinityTheme.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Native Share Button

struct NativeShareButton: View {
    let items: [Any]
    let icon: String?
    let title: String?

    init(
        items: [Any],
        icon: String? = nil,
        title: String? = nil
    ) {
        self.items = items
        self.icon = icon
        self.title = title
    }

    var body: some View {
        Menu {
            ForEach(availableServices, id: \.title) { service in
                Button {
                    service.perform(withItems: items)
                } label: {
                    HStack {
                        Image(nsImage: service.image)
                        Text(service.title)
                    }
                }
            }
        } label: {
            if let title = title {
                HStack(spacing: 6) {
                    if let icon = icon {
                        Image(systemName: icon)
                    }
                    Text(title)
                }
            } else if let icon = icon {
                Image(systemName: icon)
            } else {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }

    private var availableServices: [NSSharingService] {
        NSSharingService.sharingServices(forItems: items)
    }
}

// MARK: - Quick Share

struct QuickShare: View {
    let items: [Any]
    @State private var showFullSheet = false

    var body: some View {
        HStack(spacing: 8) {
            QuickShareButton(icon: "doc.on.doc", title: "Copy") {
                copyToPasteboard()
            }

            QuickShareButton(icon: "link", title: "Link") {
                copyLink()
            }

            Button {
                showFullSheet = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(TrinityTheme.bgCardBorder)
                    )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showFullSheet) {
            ShareSheet(items: items, isVisible: $showFullSheet)
        }
    }

    private func copyToPasteboard() {
        guard let item = items.first as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item, forType: .string)
    }

    private func copyLink() {
        copyToPasteboard()
    }
}

// MARK: - Quick Share Button

struct QuickShareButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textMuted)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(TrinityTheme.bgCardBorder)
                )
        }
        .buttonStyle(.plain)
        .tooltip(title)
    }
}

// MARK: - Share Preview

struct SharePreview: View {
    let url: URL
    let title: String
    let description: String?
    let imageUrl: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share Preview")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TrinityTheme.textMuted)

            HStack(spacing: 12) {
                if let imageUrl = imageUrl {
                    AsyncImage(url: imageUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(TrinityTheme.bgCardBorder)
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TrinityTheme.textPrimary)
                        .lineLimit(2)

                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                            .lineLimit(2)
                    }

                    Text(url.host ?? "Unknown")
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted.opacity(0.7))
                }

                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(TrinityTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Export Options

struct ExportOptions: View {
    let content: String
    let filename: String
    @State private var showShareSheet = false

    enum ExportFormat {
        case txt, md, json, csv

        var fileExtension: String {
            switch self {
            case .txt: return "txt"
            case .md: return "md"
            case .json: return "json"
            case .csv: return "csv"
            }
        }

        var displayName: String {
            switch self {
            case .txt: return "Plain Text"
            case .md: return "Markdown"
            case .json: return "JSON"
            case .csv: return "CSV"
            }
        }
    }

    var body: some View {
        Menu {
            ForEach([ExportFormat.txt, .md, .json, .csv], id: \.fileExtension) { format in
                Button {
                    exportAs(format)
                } label: {
                    Text(format.displayName)
                }
            }

            Divider()

            Button {
                showShareSheet = true
            } label: {
                Text("Share...")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textMuted)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [content], isVisible: $showShareSheet)
        }
    }

    private func exportAs(_ format: ExportFormat) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "\(filename).\(format.fileExtension)"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Preview

struct ShareSheetView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            QuickShare(items: ["https://example.com"])
                .padding()

            SharePreview(
                url: URL(string: "https://example.com")!,
                title: "Example Article",
                description: "This is a preview of the shared content",
                imageUrl: nil
            )
            .frame(width: 300)
            .padding()

            ExportOptions(
                content: "Sample content to export",
                filename: "sample"
            )
            .padding()
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
