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
                Color.black.opacity(V1Theme.opacityTextTertiary)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isVisibleBinding.wrappedValue = false
                    }

                VStack(spacing: ParietalSpacing.lg) {
                    Text("Share")
                        .font(WernickeTypography.body16Medium)
                        .foregroundStyle(V4Color.textPrimary)

                    shareOptions

                    Button {
                        isVisibleBinding.wrappedValue = false
                    } label: {
                        Text("Cancel")
                            .font(WernickeTypography.size14)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(ParietalSpacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                        .fill(V4Color.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                        .stroke(V4Color.border, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 20)
                .padding(.horizontal, ParietalSpacing.xxl)
            }
        }
    }

    private var shareOptions: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: ParietalSpacing.md + ParietalSpacing.md) {
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
        .padding(.vertical, ParietalSpacing.sm)
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
            VStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: icon)
                    .font(WernickeTypography.size20)
                    .foregroundStyle(V4Color.accent)
                    .frame(width: ParietalSpacing.mediumFrame, height: ParietalSpacing.mediumFrame)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(V4Color.accent.opacity(V2Depth.bgSubtle))
                    )

                Text(title)
                    .font(WernickeTypography.size11)
                    .foregroundStyle(V4Color.textPrimary)
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
                HStack(spacing: ParietalSpacing.sm - 2) {
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
        HStack(spacing: ParietalSpacing.sm) {
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
                    .font(WernickeTypography.size13)
                    .foregroundStyle(V4Color.textSecondary)
                    .frame(width: ParietalSpacing.avatarSmall, height: ParietalSpacing.avatarSmall)
                    .background(
                        Circle()
                            .fill(V4Color.border)
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
                .font(WernickeTypography.size13)
                .foregroundStyle(V4Color.textSecondary)
                .frame(width: ParietalSpacing.avatarSmall, height: ParietalSpacing.avatarSmall)
                .background(
                    Circle()
                        .fill(V4Color.border)
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
        VStack(alignment: .leading, spacing: ParietalSpacing.sm + 2) {
            Text("Share Preview")
                .font(WernickeTypography.captionMedium)
                .foregroundStyle(V4Color.textSecondary)

            HStack(spacing: ParietalSpacing.md) {
                if let imageUrl = imageUrl {
                    AsyncImage(url: imageUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(V4Color.border)
                    }
                    .frame(width: ParietalSpacing.largeFrame, height: ParietalSpacing.largeFrame)
                    .cornerRadius(V1Theme.cornerSmall)
                }

                VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                    Text(title)
                        .font(WernickeTypography.smallMedium)
                        .foregroundStyle(V4Color.textPrimary)
                        .lineLimit(2)

                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                            .lineLimit(2)
                    }

                    Text(url.host ?? "Unknown")
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary.opacity(0.7))
                }

                Spacer()
            }
            .padding(ParietalSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(V4Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(V4Color.border, lineWidth: 1)
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
                .font(WernickeTypography.size13)
                .foregroundStyle(V4Color.textSecondary)
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
            .frame(width: ParietalSpacing.xl * 12)
            .padding()

            ExportOptions(
                content: "Sample content to export",
                filename: "sample"
            )
            .padding()
        }
        .padding()
        .background(V4Color.background)
    }
}
