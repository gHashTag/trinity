import SwiftUI
import UniformTypeIdentifiers

// MARK: - Message Attachment Picker

struct MessageAttachmentPicker: View {
    let onAttachmentsSelected: ([Attachment]) -> Void

    @State private var showFilePicker = false
    @State private var showImagePicker = false
    @State private var draggedURLs: [URL] = []

    var body: some View {
        HStack(spacing: 12) {
            // Image picker
            attachmentButton(
                icon: "photo.fill",
                label: "Image",
                color: TrinityTheme.purple
            ) {
                showImagePicker = true
            }
            .fileImporter(
                isPresented: $showImagePicker,
                allowedContentTypes: [.image, .png, .jpeg],
                allowsMultipleSelection: true
            ) { result in
                handleFileSelection(result)
            }

            // File picker
            attachmentButton(
                icon: "doc.fill",
                label: "File",
                color: TrinityTheme.accent
            ) {
                showFilePicker = true
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                handleFileSelection(result)
            }

            // Drop zone
            dropZone

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func attachmentButton(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                    .fill(TrinityTheme.bgCard)
            )
        }
        .buttonStyle(.plain)
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 16))
                .foregroundStyle(draggedURLs.isEmpty ? TrinityTheme.textMuted : TrinityTheme.accent)

            Text(draggedURLs.isEmpty ? "Drop files" : "\(draggedURLs.count) files")
                .font(.caption2)
                .foregroundStyle(TrinityTheme.textMuted)
        }
        .frame(width: 80, height: 50)
        .background(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                .fill(draggedURLs.isEmpty ? TrinityTheme.bgCard : TrinityTheme.accent.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                .stroke(draggedURLs.isEmpty ? TrinityTheme.bgCardBorder : TrinityTheme.accent, lineWidth: 1)
        )
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let attachments = urls.compactMap { url in
                Attachment(url: url, type: detectType(for: url))
            }
            onAttachmentsSelected(attachments)
        case .failure:
            break
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
 }
                DispatchQueue.main.async {
                    draggedURLs.append(url)
                }
            }
        }
        return true
    }

    private func detectType(for url: URL) -> Attachment.AttachmentType {
        if let uti = UTType(filenameExtension: url.pathExtension) {
            if uti.conforms(to: .image) {
                return .image
            } else if uti.conforms(to: .movie) {
                return .video
            } else if uti.conforms(to: .audio) {
                return .audio
            } else if uti.conforms(to: .pdf) {
                return .pdf
            }
        }
        return .file
    }
}

// MARK: - Attachment Model

struct Attachment: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let type: AttachmentType
    var thumbnail: Image?
    var fileName: String { url.lastPathComponent }
    var fileSize: Int64? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
    }

    enum AttachmentType {
        case image, video, audio, pdf, file
    }
}

// MARK: - Attachment Preview Row

struct AttachmentPreviewRow: View {
    @Binding var attachments: [Attachment]
    let onRemove: (Attachment) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(attachments) { attachment in
                    attachmentThumbnail(attachment)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func attachmentThumbnail(_ attachment: Attachment) -> some View {
        Button {
            onRemove(attachment)
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    thumbnailPlaceholder(attachment)

                    // Remove button
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .background(Circle().fill(TrinityTheme.statusError))
                }

                Text(attachment.fileName)
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .lineLimit(1)
                    .frame(width: 60)
            }
        }
        .buttonStyle(.plain)
    }

    private func thumbnailPlaceholder(_ attachment: Attachment) -> some View {
        Group {
            switch attachment.type {
            case .image:
                if let thumbnail = attachment.thumbnail {
                    thumbnail
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(TrinityTheme.purple)
                }
            case .video:
                Image(systemName: "video")
                    .font(.title2)
                    .foregroundStyle(TrinityTheme.accent)
            case .audio:
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundStyle(.green)
            case .pdf:
                Image(systemName: "doc.richtext")
                    .font(.title2)
                    .foregroundStyle(.red)
            case .file:
                Image(systemName: "doc")
                    .font(.title2)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
        }
        .frame(width: 60, height: 60)
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerSmall)
    }
}

// MARK: - Attachment Gallery View

struct AttachmentGalleryView: View {
    let attachments: [Attachment]
    let onSelect: (Attachment) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
            ForEach(attachments) { attachment in
                attachmentCard(attachment)
            }
        }
        .padding()
    }

    private func attachmentCard(_ attachment: Attachment) -> some View {
        Button {
            onSelect(attachment)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                thumbnailPlaceholder(attachment)

                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.fileName)
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textPrimary)
                        .lineLimit(1)

                    if let size = attachment.fileSize {
                        Text(formattedFileSize(size))
                            .font(.caption2)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(TrinityTheme.bgCard)
            .cornerRadius(TrinityTheme.cornerSmall)
        }
        .buttonStyle(.plain)
    }

    private func thumbnailPlaceholder(_ attachment: Attachment) -> some View {
        Group {
            switch attachment.type {
            case .image:
                Image(systemName: "photo.fill")
                    .font(.largeTitle)
                    .foregroundStyle(TrinityTheme.purple)
            case .video:
                Image(systemName: "video.fill")
                    .font(.largeTitle)
                    .foregroundStyle(TrinityTheme.accent)
            case .audio:
                Image(systemName: "waveform.path")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
            case .pdf:
                Image(systemName: "doc.richtext.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
            case .file:
                Image(systemName: "doc.fill")
                    .font(.largeTitle)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(TrinityTheme.bgCard.opacity(0.5))
        .cornerRadius(TrinityTheme.cornerSmall)
    }

    private func formattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Preview

struct MessageAttachmentPicker_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            MessageAttachmentPicker { _ in }
                .padding()
                .background(TrinityTheme.bgCard)

            AttachmentPreviewRow(
                attachments: .constant([
                    Attachment(url: URL(fileURLWithPath: "/tmp/test.png"), type: .image),
                    Attachment(url: URL(fileURLWithPath: "/tmp/test.pdf"), type: .pdf)
                ]),
                onRemove: { _ in }
            )
        }
        .background(TrinityTheme.bgWindow)
    }
}
