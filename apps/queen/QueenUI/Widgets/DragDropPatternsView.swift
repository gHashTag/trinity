// Drag & Drop Patterns for Queen UI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drop Zone

struct DropZone: View {
    let title: String
    let subtitle: String?
    let icon: String
    let isDragging: Bool
    let onDrop: () -> Bool
    
    init(title: String, subtitle: String? = nil, icon: String = "arrow.down.doc", isDragging: Bool = false, onDrop: @escaping () -> Bool) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isDragging = isDragging
        self.onDrop = onDrop
    }
    
    var body: some View {
        VStack(spacing: ParietalSpacing.lg) {
            Image(systemName: icon)
                .font(WernickeTypography.size40)
                .foregroundStyle(isDragging ? V4Color.accent : V4Color.textSecondary)
            
            Text(title)
                .font(WernickeTypography.body16Medium)
                .foregroundStyle(V4Color.textPrimary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ParietalSpacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(isDragging ? V4Color.accent : V4Color.border, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                        .fill((isDragging || isDragging) ? V4Color.accent.opacity(0.05) : Color.clear)
                )
        )
        .onDrop(of: [.fileURL], isTargeted: .constant(false)) { _ in
            onDrop()
        }
    }
}

// MARK: - Draggable Item

struct DraggableItem<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .onDrag {
                NSItemProvider(object: "draggable" as NSString)
            }
    }
}

// MARK: - File Drop Zone

struct FileDropZone: View {
    let extensions: [String]
    let onFileDropped: (URL) -> Void
    
    @State private var isDragging = false
    @State private var showSuccess = false
    
    var body: some View {
        VStack(spacing: ParietalSpacing.lg) {
            ZStack {
                if showSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(WernickeTypography.display)
                        .foregroundStyle(.green)
                } else {
                    VStack(spacing: ParietalSpacing.sm) {
                        Image(systemName: isDragging ? "arrow.down.doc.fill" : "doc")
                            .font(WernickeTypography.size40)
                            .foregroundStyle(isDragging ? V4Color.accent : V4Color.textSecondary)
                        
                        Text(isDragging ? "Drop to upload" : "Drag files here")
                            .font(WernickeTypography.size14)
                            .foregroundStyle(V4Color.textPrimary)
                        
                        Text(extensions.joined(separator: ", ").uppercased())
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(ParietalSpacing.xxl)
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            guard let provider = providers.first else { return false }

            _ = provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    onFileDropped(url)
                    withAnimation {
                        showSuccess = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withAnimation {
                            showSuccess = false
                        }
                    }
                }
            }

            return true
        }
    }
}

// MARK: - Drag Overlay

struct DragOverlay: View {
    let isVisible: Bool
    let message: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .fill(V4Color.accent.opacity(V2Depth.bgSubtle))
            
            VStack(spacing: ParietalSpacing.sm) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(WernickeTypography.size32)
                    .foregroundStyle(V4Color.accent)
                
                Text(message)
                    .font(WernickeTypography.body14Medium)
                    .foregroundStyle(V4Color.textPrimary)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9)
    }
}

// MARK: - Preview

struct DragDropPatternsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DropZone(title: "Drop Files Here", subtitle: "Supported: PNG, JPG, PDF", onDrop: { true })
                .frame(width: ParietalSpacing.sheetWidth, height: ParietalSpacing.modalFrame)

            FileDropZone(extensions: ["png", "jpg"]) { _ in }
                .frame(width: ParietalSpacing.sheetWidth, height: ParietalSpacing.modalFrame)
        }
        .padding()
        .background(V4Color.background)
    }
}
