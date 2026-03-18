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
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(isDragging ? TrinityTheme.accent : TrinityTheme.textMuted)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(TrinityTheme.textPrimary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerLarge)
                .stroke(isDragging ? TrinityTheme.accent : TrinityTheme.bgCardBorder, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: TrinityTheme.cornerLarge)
                        .fill((isDragging || isDragging) ? TrinityTheme.accent.opacity(0.05) : Color.clear)
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
        VStack(spacing: 16) {
            ZStack {
                if showSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: isDragging ? "arrow.down.doc.fill" : "doc")
                            .font(.system(size: 40))
                            .foregroundStyle(isDragging ? TrinityTheme.accent : TrinityTheme.textMuted)
                        
                        Text(isDragging ? "Drop to upload" : "Drag files here")
                            .font(.system(size: 14))
                            .foregroundStyle(TrinityTheme.textPrimary)
                        
                        Text(extensions.joined(separator: ", ").uppercased())
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(32)
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
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .fill(TrinityTheme.accent.opacity(0.1))
            
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(TrinityTheme.accent)
                
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TrinityTheme.textPrimary)
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
                .frame(width: 400, height: 200)

            FileDropZone(extensions: ["png", "jpg"]) { _ in }
                .frame(width: 400, height: 200)
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
