import SwiftUI
import AppKit

// MARK: - File Attachment Model

struct FileAttachment: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String
    let fileURL: String
    let fileSize: Int64
    let mimeType: String
    let thumbnailURL: String?
    var isDownloaded: Bool
    var downloadProgress: Double

    var displayName: String {
        fileName.isEmpty ? "Untitled" : fileName
    }

    var fileType: FileType {
        FileType(mimeType: mimeType, fileName: fileName)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    init(fileName: String, fileURL: String, fileSize: Int64, mimeType: String, thumbnailURL: String? = nil) {
        self.id = UUID()
        self.fileName = fileName
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.thumbnailURL = thumbnailURL
        self.isDownloaded = false
        self.downloadProgress = 0.0
    }
}

// MARK: - File Type Enum

enum FileType {
    case image
    case pdf
    case code
    case text
    case video
    case audio
    case archive
    case document
    case unknown

    private static let codeExtensions: Set<String> = [
        "swift", "zig", "py", "js", "ts", "tsx", "jsx", "rs", "go", "java", "kt", "c", "cpp", "h", "hpp",
        "cs", "php", "rb", "scala", "clj", "hs", "ml", "fs", "fsx", "sh", "bash", "zsh", "fish",
        "json", "xml", "yaml", "yml", "toml", "ini", "cfg", "conf", "sql", "graphql", "css", "scss",
        "html", "htm", "svg", "vue", "svelte"
    ]

    init(mimeType: String, fileName: String) {
        let lowerMime = mimeType.lowercased()
        let lowerName = fileName.lowercased()

        if lowerMime.hasPrefix("image/") {
            self = .image
        } else if lowerMime.hasPrefix("application/pdf") || lowerName.hasSuffix(".pdf") {
            self = .pdf
        } else if lowerMime.hasPrefix("video/") {
            self = .video
        } else if lowerMime.hasPrefix("audio/") {
            self = .audio
        } else if lowerMime.contains("zip") || lowerMime.contains("tar") || lowerMime.contains("gzip") ||
                  lowerName.hasSuffix(".zip") || lowerName.hasSuffix(".tar") || lowerName.hasSuffix(".gz") ||
                  lowerName.hasSuffix(".7z") || lowerName.hasSuffix(".rar") {
            self = .archive
        } else if lowerMime.hasPrefix("text/") || lowerName.hasSuffix(".txt") || lowerName.hasSuffix(".md") {
            self = .text
        } else if Self.codeExtensions.contains(lowerName.components(separatedBy: ".").last ?? "") {
            self = .code
        } else if lowerMime.contains("document") || lowerMime.contains("word") || lowerMime.contains("office") ||
                  lowerName.hasSuffix(".doc") || lowerName.hasSuffix(".docx") || lowerName.hasSuffix(".pages") {
            self = .document
        } else {
            self = .unknown
        }
    }

    var icon: String {
        switch self {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .text: return "doc.plaintext"
        case .video: return "video"
        case .audio: return "waveform"
        case .archive: return "archivebox"
        case .document: return "doc.text"
        case .unknown: return "doc"
        }
    }

    var color: Color {
        switch self {
        case .image: return V4Color.purple
        case .pdf: return V4Color.error
        case .code: return V4Color.info
        case .text: return V4Color.textSecondary
        case .video: return V4Color.warning
        case .audio: return V4Color.success
        case .archive: return V4Color.textSecondary
        case .document: return V4Color.purple
        case .unknown: return V4Color.textSecondary
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .image: return "Image file"
        case .pdf: return "PDF document"
        case .code: return "Code file"
        case .text: return "Text file"
        case .video: return "Video file"
        case .audio: return "Audio file"
        case .archive: return "Archive file"
        case .document: return "Document"
        case .unknown: return "File"
        }
    }
}

// MARK: - Attachment Preview View

struct MessageAttachmentPreview: View {
    let attachment: FileAttachment
    @State private var isHovered = false
    @State private var thumbnail: NSImage?
    @State private var isLoadingThumbnail = false

    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            thumbnailView

            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                Text(attachment.displayName)
                    .font(WernickeTypography.smallMedium)
                    .foregroundColor(V4Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: ParietalSpacing.sm) {
                    Image(systemName: attachment.fileType.icon)
                        .font(WernickeTypography.size9)
                        .foregroundColor(attachment.fileType.color)

                    Text(attachment.formattedSize)
                        .font(WernickeTypography.size11)
                        .foregroundColor(V4Color.textSecondary)

                    if !attachment.isDownloaded && attachment.downloadProgress > 0 {
                        Text("\(Int(attachment.downloadProgress * 100))%")
                            .font(WernickeTypography.size10)
                            .foregroundColor(V4Color.accent)
                    }
                }
            }

            Spacer()

            actionButtons
        }
        .padding(ParietalSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .fill(V4Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                        .stroke(isHovered ? V4Color.accent.opacity(V2Depth.stateHover) : V4Color.border, lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(MTMotion.quickSpring) {
                isHovered = hovering
            }
        }
        .accessibilityLabel(attachment.fileType.accessibilityLabel + ", " + attachment.displayName)
        .accessibilityHint("Double click to preview")
        .onTapGesture(count: 2) {
            openPreview()
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            if attachment.fileType == .image, let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: ParietalSpacing.largeFrame, height: ParietalSpacing.largeButtonHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if attachment.fileType == .image && isLoadingThumbnail {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: ParietalSpacing.largeFrame, height: ParietalSpacing.largeButtonHeight)
                    .background(V4Color.border.opacity(V2Depth.stateHover))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(attachment.fileType.color.opacity(V2Depth.bgSidebarHover))
                        .frame(width: ParietalSpacing.largeFrame, height: ParietalSpacing.largeButtonHeight)

                    Image(systemName: attachment.fileType.icon)
                        .font(WernickeTypography.h2)
                        .foregroundColor(attachment.fileType.color)
                }
            }

            if !attachment.isDownloaded {
                ZStack {
                    Circle()
                        .fill(V4Color.surface.opacity(0.9))
                        .frame(width: ParietalSpacing.icon + 4, height: ParietalSpacing.icon + 4)

                    if attachment.downloadProgress > 0 {
                        Circle()
                            .trim(from: 0, to: attachment.downloadProgress)
                            .stroke(V4Color.accent, lineWidth: 2)
                            .frame(width: ParietalSpacing.icon + 4, height: ParietalSpacing.icon + 4)
                            .rotationEffect(.degrees(-90))
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(WernickeTypography.size14)
                            .foregroundColor(V4Color.accent)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isHovered {
            HStack(spacing: ParietalSpacing.sm - 2) {
                Button {
                    openPreview()
                } label: {
                    Image(systemName: "eye")
                        .font(WernickeTypography.size12)
                        .foregroundColor(V4Color.textSecondary)
                        .frame(width: ParietalSpacing.smallIconFrame, height: ParietalSpacing.smallButtonHeight)
                        .background(
                            Circle()
                                .fill(V4Color.border.opacity(V2Depth.stateDisabled))
                        )
                }
                .buttonStyle(.plain)
                .help("Quick Look preview")
                .accessibilityLabel("Preview file")

                Button {
                    downloadAttachment()
                } label: {
                    Image(systemName: attachment.isDownloaded ? "checkmark" : "arrow.down")
                        .font(WernickeTypography.size11)
                        .foregroundColor(attachment.isDownloaded ? V4Color.success : V4Color.textSecondary)
                        .frame(width: ParietalSpacing.smallIconFrame, height: ParietalSpacing.smallButtonHeight)
                        .background(
                            Circle()
                                .fill(V4Color.border.opacity(V2Depth.stateDisabled))
                        )
                }
                .buttonStyle(.plain)
                .disabled(attachment.downloadProgress > 0 && !attachment.isDownloaded)
                .help(attachment.isDownloaded ? "Downloaded" : "Download file")
                .accessibilityLabel(attachment.isDownloaded ? "Downloaded" : "Download file")
            }
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func openPreview() {
        guard let url = URL(string: attachment.fileURL) else { return }
        NSWorkspace.shared.open(url)
    }

    private func downloadAttachment() {
        guard let url = URL(string: attachment.fileURL) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Attachments Gallery View

struct AttachmentsGallery: View {
    let attachments: [FileAttachment]
    let onAttachmentTap: ((FileAttachment) -> Void)?

    @State private var selectedIndex: Int?

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: ParietalSpacing.md)
    ]

    var body: some View {
        if attachments.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: ParietalSpacing.md) {
                    ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                        MessageAttachmentPreview(attachment: attachment)
                            .onTapGesture {
                                selectedIndex = index
                                onAttachmentTap?(attachment)
                            }
                    }
                }
                .padding(ParietalSpacing.md)
            }
            .frame(maxHeight: 400)
        }
    }

    private var emptyState: some View {
        VStack(spacing: ParietalSpacing.md) {
            Image(systemName: "paperclip")
                .font(WernickeTypography.size32)
                .foregroundColor(V4Color.textSecondary.opacity(V2Depth.stateDisabled))

            Text("No attachments")
                .font(WernickeTypography.size14)
                .foregroundColor(V4Color.textSecondary)
        }
        .frame(height: 100)
    }
}

// MARK: - Inline Attachment Row (for message bubbles)

struct InlineAttachmentRow: View {
    let attachments: [FileAttachment]
    @State private var expandedAttachment: FileAttachment?

    var body: some View {
        if attachments.count == 1 {
            singleAttachmentView(attachments[0])
        } else {
            multipleAttachmentsView
        }
    }

    @ViewBuilder
    private func singleAttachmentView(_ attachment: FileAttachment) -> some View {
        MessageAttachmentPreview(attachment: attachment)
    }

    private var multipleAttachmentsView: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            HStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: "paperclip")
                    .font(WernickeTypography.size11)
                    .foregroundColor(V4Color.textSecondary)

                Text("\(attachments.count) attachments")
                    .font(WernickeTypography.size12)
                    .foregroundColor(V4Color.textSecondary)
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ParietalSpacing.sm) {
                    ForEach(attachments) { attachment in
                        MiniAttachmentThumbnail(attachment: attachment) {
                            expandedAttachment = attachment
                        }
                    }
                }
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .fill(V4Color.surface.opacity(V2Depth.stateDisabled))
        )
        .sheet(item: $expandedAttachment) { attachment in
            AttachmentDetailView(attachment: attachment)
        }
    }
}

// MARK: - Mini Attachment Thumbnail

struct MiniAttachmentThumbnail: View {
    let attachment: FileAttachment
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: ParietalSpacing.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(attachment.fileType.color.opacity(V2Depth.bgSidebarHover))
                        .frame(width: ParietalSpacing.avatarMedium, height: ParietalSpacing.avatarMedium)

                    Image(systemName: attachment.fileType.icon)
                        .font(WernickeTypography.size18)
                        .foregroundColor(attachment.fileType.color)
                }

                Text(attachment.displayName)
                    .font(WernickeTypography.size9)
                    .foregroundColor(V4Color.textSecondary)
                    .lineLimit(1)
                    .frame(width: ParietalSpacing.avatarMedium + 8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(attachment.displayName)
        .accessibilityHint("Tap to view attachment")
    }
}

// MARK: - Attachment Detail View (Full Screen)

struct AttachmentDetailView: View {
    let attachment: FileAttachment
    @Environment(\.dismiss) private var dismiss
    @State private var fullSizeImage: NSImage?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(V4Color.background)
        .task {
            if attachment.fileType == .image {
                loadImage()
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: ParietalSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(attachment.fileType.color.opacity(V2Depth.bgSidebarHover))
                        .frame(width: ParietalSpacing.avatarSmall, height: ParietalSpacing.avatarSmall)

                    Image(systemName: attachment.fileType.icon)
                        .font(WernickeTypography.size14)
                        .foregroundColor(attachment.fileType.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.displayName)
                        .font(WernickeTypography.smallMedium)
                        .foregroundColor(V4Color.textPrimary)

                    HStack(spacing: ParietalSpacing.sm) {
                        Text(attachment.fileType.accessibilityLabel)
                        Text("•")
                        Text(attachment.formattedSize)
                    }
                    .font(WernickeTypography.size11)
                    .foregroundColor(V4Color.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: ParietalSpacing.sm) {
                Button {
                    saveAttachment()
                } label: {
                    Image(systemName: "arrow.down.doc")
                        .frame(width: ParietalSpacing.smallIconFrame, height: ParietalSpacing.smallButtonHeight)
                }
                .buttonStyle(.plain)
                .help("Save")

                Button {
                    NSWorkspace.shared.open(URL(string: attachment.fileURL)!)
                } label: {
                    Image(systemName: "safari")
                        .frame(width: ParietalSpacing.smallIconFrame, height: ParietalSpacing.smallButtonHeight)
                }
                .buttonStyle(.plain)
                .help("Open in browser")

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(V4Color.textSecondary)
                        .frame(width: ParietalSpacing.smallIconFrame, height: ParietalSpacing.smallButtonHeight)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape)
            }
        }
        .padding(ParietalSpacing.md)
        .background(V4Color.sidebar)
    }

    @ViewBuilder
    private var contentView: some View {
        if let image = fullSizeImage {
            GeometryReader { geometry in
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        } else if isLoading {
            VStack(spacing: ParietalSpacing.lg) {
                ProgressView()
                    .controlSize(.large)

                Text("Loading attachment...")
                    .font(WernickeTypography.size13)
                    .foregroundColor(V4Color.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: ParietalSpacing.lg) {
                Image(systemName: attachment.fileType.icon)
                    .font(WernickeTypography.display)
                    .foregroundColor(attachment.fileType.color.opacity(V1Theme.opacityTextSecondary))

                Text("Preview not available")
                    .font(WernickeTypography.size14)
                    .foregroundColor(V4Color.textSecondary)

                Button("Open in Browser") {
                    if let url = URL(string: attachment.fileURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loadImage() {
        isLoading = true
        Task {
            if let url = URL(string: attachment.fileURL) {
                if let data = try? Data(contentsOf: url),
                   let image = NSImage(data: data) {
                    await MainActor.run {
                        fullSizeImage = image
                        isLoading = false
                    }
                    return
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func saveAttachment() {
        guard let url = URL(string: attachment.fileURL) else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = attachment.fileName
        panel.begin { response in
            guard response == .OK else { return }
            guard let destURL = panel.url else { return }

            Task {
                if let data = try? Data(contentsOf: url) {
                    try? data.write(to: destURL)
                }
            }
        }
    }
}

// MARK: - Quick Look Preview Wrapper

struct QuickLookPreviewView: View {
    let attachment: FileAttachment
    @Binding var isPresented: Bool

    var body: some View {
        EmptyView()
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    openInQuickLook()
                }
            }
    }

    private func openInQuickLook() {
        guard let url = URL(string: attachment.fileURL) else { return }
        NSWorkspace.shared.open(url)
        isPresented = false
    }
}

// MARK: - Download Progress Indicator

struct AttachmentDownloadProgress: View {
    let progress: Double
    let fileSize: Int64

    private var downloadedBytes: Int64 {
        Int64(Double(fileSize) * progress)
    }

    private var remainingBytes: Int64 {
        fileSize - downloadedBytes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
            HStack {
                Text("Downloading...")
                    .font(WernickeTypography.size11)
                    .foregroundColor(V4Color.textSecondary)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(WernickeTypography.miniMedium)
                    .foregroundColor(V4Color.accent)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(V4Color.border.opacity(V2Depth.stateDisabled))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(V4Color.accent)
                        .frame(width: geometry.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text(ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file))
                    .font(WernickeTypography.size10)
                    .foregroundColor(V4Color.textSecondary.opacity(0.8))

                Text("of")
                    .font(WernickeTypography.size10)
                    .foregroundColor(V4Color.textSecondary.opacity(V1Theme.opacityTextSecondary))

                Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                    .font(WernickeTypography.size10)
                    .foregroundColor(V4Color.textSecondary.opacity(0.8))

                Spacer()

                if progress > 0 {
                    let speed = 2_500_000
                    let remaining = Double(remainingBytes) / Double(speed)
                    Text(remaining < 60 ? "\(Int(remaining))s left" : "\(Int(remaining/60))m left")
                        .font(WernickeTypography.size10)
                        .foregroundColor(V4Color.textSecondary.opacity(V1Theme.opacityTextSecondary))
                }
            }
        }
        .padding(ParietalSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .fill(V4Color.surface.opacity(V2Depth.stateDisabled))
        )
    }
}

// MARK: - File Metadata Badge

struct FileMetadataBadge: View {
    let attachment: FileAttachment

    var body: some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            Image(systemName: attachment.fileType.icon)
                .font(WernickeTypography.size9)

            Text(attachment.fileType.accessibilityLabel.uppercased())
                .font(WernickeTypography.tiny8Bold)

            Text("•")
                .font(WernickeTypography.size8)

            Text(attachment.formattedSize)
                .font(WernickeTypography.size8)
        }
        .foregroundColor(attachment.fileType.color.opacity(0.9))
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .background(
            SwiftUI.Capsule()
                .fill(attachment.fileType.color.opacity(V2Depth.bgSidebarHover))
        )
        .accessibilityLabel("File type: \(attachment.fileType.accessibilityLabel), Size: \(attachment.formattedSize)")
    }
}
