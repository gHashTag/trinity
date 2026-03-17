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
        } else if codeExtensions.contains(lowerName.components(separatedBy: ".").last ?? "") {
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
        case .image: return TrinityTheme.purple
        case .pdf: return Color(hex: 0xFF6B6B)
        case .code: return Color(hex: 0x4ECDC4)
        case .text: return TrinityTheme.textMuted
        case .video: return Color(hex: 0xFFD93D)
        case .audio: return Color(hex: 0x6BCF7F)
        case .archive: return Color(hex: 0xA8A8A8)
        case .document: return Color(hex: 0x6C5CE7)
        case .unknown: return TrinityTheme.textMuted
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
        HStack(spacing: 12) {
            thumbnailView

            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(TrinityTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Image(systemName: attachment.fileType.icon)
                        .font(.system(size: 9))
                        .foregroundColor(attachment.fileType.color)

                    Text(attachment.formattedSize)
                        .font(.system(size: 11))
                        .foregroundColor(TrinityTheme.textMuted)

                    if !attachment.isDownloaded && attachment.downloadProgress > 0 {
                        Text("\(Int(attachment.downloadProgress * 100))%")
                            .font(.system(size: 10))
                            .foregroundColor(TrinityTheme.accent)
                    }
                }
            }

            Spacer()

            actionButtons
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .fill(TrinityTheme.bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                        .stroke(isHovered ? TrinityTheme.accent.opacity(0.3) : TrinityTheme.bgCardBorder, lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(TrinityTheme.quickSpring()) {
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
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if attachment.fileType == .image && isLoadingThumbnail {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 56, height: 56)
                    .background(TrinityTheme.bgCardBorder.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(attachment.fileType.color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: attachment.fileType.icon)
                        .font(.system(size: 22))
                        .foregroundColor(attachment.fileType.color)
                }
            }

            if !attachment.isDownloaded {
                ZStack {
                    Circle()
                        .fill(TrinityTheme.bgCard.opacity(0.9))
                        .frame(width: 20, height: 20)

                    if attachment.downloadProgress > 0 {
                        Circle()
                            .trim(from: 0, to: attachment.downloadProgress)
                            .stroke(TrinityTheme.accent, lineWidth: 2)
                            .frame(width: 20, height: 20)
                            .rotationEffect(.degrees(-90))
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(TrinityTheme.accent)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isHovered {
            HStack(spacing: 6) {
                Button {
                    openPreview()
                } label: {
                    Image(systemName: "eye")
                        .font(.system(size: 12))
                        .foregroundColor(TrinityTheme.textMuted)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(TrinityTheme.bgCardBorder.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
                .help("Quick Look preview")
                .accessibilityLabel("Preview file")

                Button {
                    downloadAttachment()
                } label: {
                    Image(systemName: attachment.isDownloaded ? "checkmark" : "arrow.down")
                        .font(.system(size: 11))
                        .foregroundColor(attachment.isDownloaded ? TrinityTheme.statusOK : TrinityTheme.textMuted)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(TrinityTheme.bgCardBorder.opacity(0.5))
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
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 12)
    ]

    var body: some View {
        if attachments.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                        MessageAttachmentPreview(attachment: attachment)
                            .onTapGesture {
                                selectedIndex = index
                                onAttachmentTap?(attachment)
                            }
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 400)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "paperclip")
                .font(.system(size: 32))
                .foregroundColor(TrinityTheme.textMuted.opacity(0.5))

            Text("No attachments")
                .font(.system(size: 14))
                .foregroundColor(TrinityTheme.textMuted)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "paperclip")
                    .font(.system(size: 11))
                    .foregroundColor(TrinityTheme.textMuted)

                Text("\(attachments.count) attachments")
                    .font(.system(size: 12))
                    .foregroundColor(TrinityTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(attachments) { attachment in
                        MiniAttachmentThumbnail(attachment: attachment) {
                            expandedAttachment = attachment
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .fill(TrinityTheme.bgCard.opacity(0.5))
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
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(attachment.fileType.color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: attachment.fileType.icon)
                        .font(.system(size: 18))
                        .foregroundColor(attachment.fileType.color)
                }

                Text(attachment.displayName)
                    .font(.system(size: 9))
                    .foregroundColor(TrinityTheme.textMuted)
                    .lineLimit(1)
                    .frame(width: 56)
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
        .background(TrinityTheme.bgWindow)
        .task {
            if attachment.fileType == .image {
                loadImage()
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(attachment.fileType.color.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: attachment.fileType.icon)
                        .font(.system(size: 14))
                        .foregroundColor(attachment.fileType.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TrinityTheme.textPrimary)

                    HStack(spacing: 8) {
                        Text(attachment.fileType.accessibilityLabel)
                        Text("•")
                        Text(attachment.formattedSize)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(TrinityTheme.textMuted)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    saveAttachment()
                } label: {
                    Image(systemName: "arrow.down.doc")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Save")

                Button {
                    NSWorkspace.shared.open(URL(string: attachment.fileURL)!)
                } label: {
                    Image(systemName: "safari")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Open in browser")

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(TrinityTheme.textMuted)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape)
            }
        }
        .padding(12)
        .background(TrinityTheme.bgSidebar)
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
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)

                Text("Loading attachment...")
                    .font(.system(size: 13))
                    .foregroundColor(TrinityTheme.textMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 16) {
                Image(systemName: attachment.fileType.icon)
                    .font(.system(size: 48))
                    .foregroundColor(attachment.fileType.color.opacity(0.6))

                Text("Preview not available")
                    .font(.system(size: 14))
                    .foregroundColor(TrinityTheme.textMuted)

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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Downloading...")
                    .font(.system(size: 11))
                    .foregroundColor(TrinityTheme.textMuted)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(TrinityTheme.accent)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(TrinityTheme.bgCardBorder.opacity(0.5))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(TrinityTheme.accent)
                        .frame(width: geometry.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text(ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file))
                    .font(.system(size: 10))
                    .foregroundColor(TrinityTheme.textMuted.opacity(0.8))

                Text("of")
                    .font(.system(size: 10))
                    .foregroundColor(TrinityTheme.textMuted.opacity(0.6))

                Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                    .font(.system(size: 10))
                    .foregroundColor(TrinityTheme.textMuted.opacity(0.8))

                Spacer()

                if progress > 0 {
                    let speed = 2_500_000
                    let remaining = Double(remainingBytes) / Double(speed)
                    Text(remaining < 60 ? "\(Int(remaining))s left" : "\(Int(remaining/60))m left")
                        .font(.system(size: 10))
                        .foregroundColor(TrinityTheme.textMuted.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .fill(TrinityTheme.bgCard.opacity(0.5))
        )
    }
}

// MARK: - File Metadata Badge

struct FileMetadataBadge: View {
    let attachment: FileAttachment

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: attachment.fileType.icon)
                .font(.system(size: 9))

            Text(attachment.fileType.accessibilityLabel.uppercased())
                .font(.system(size: 8, weight: .bold))

            Text("•")
                .font(.system(size: 8))

            Text(attachment.formattedSize)
                .font(.system(size: 8))
        }
        .foregroundColor(attachment.fileType.color.opacity(0.9))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(attachment.fileType.color.opacity(0.15))
        )
        .accessibilityLabel("File type: \(attachment.fileType.accessibilityLabel), Size: \(attachment.formattedSize)")
    }
}
