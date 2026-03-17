// Overlay & Hover State Patterns
import SwiftUI

// MARK: - Hover Overlay

struct HoverOverlay<Content: View>: View {
    let isHovering: Bool
    let alignment: Alignment
    let content: Content

    init(isHovering: Bool, alignment: Alignment = .topLeading, @ViewBuilder content: () -> Content) {
        self.isHovering = isHovering
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        content
            .opacity(isHovering ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
    }
}

// MARK: - Simple Tooltip

struct SimpleTooltip: View {
    let text: String
    let isVisible: Bool
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.black.opacity(0.8))
            )
            .foregroundStyle(.white)
            .opacity(isVisible ? 1 : 0)
            .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Context Menu Overlay

struct ContextMenuOverlay: View {
    let isVisible: Bool
    let items: [MenuItem]
    let onDismiss: () -> Void
    
    struct MenuItem: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let action: () -> Void
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        item.action()
                        onDismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(TrinityTheme.textMuted)
                                .frame(width: 20)
                            
                            Text(item.title)
                                .font(.system(size: 13))
                                .foregroundStyle(TrinityTheme.textPrimary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    
                    if index < items.count - 1 {
                        Divider()
                            .background(TrinityTheme.bgCardBorder)
                    }
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                    .fill(TrinityTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                    .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
            )
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isVisible)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let isVisible: Bool
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(TrinityTheme.accent)
                
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textPrimary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerLarge)
                    .fill(TrinityTheme.bgCard)
            )
        }
        .opacity(isVisible ? 1 : 0)
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let error: String
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(TrinityTheme.statusError)
            
            Text(error)
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textPrimary)
            
            Spacer()
            
            Button {
                withAnimation {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .fill(TrinityTheme.statusError.opacity(0.1))
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -20)
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
}

// MARK: - Overlay Manager

@MainActor
class OverlayManager: ObservableObject {
    @Published var currentOverlay: (any View)?
    
    func show<T: View>(_ overlay: T) {
        currentOverlay = overlay
    }
    
    func dismiss() {
        currentOverlay = nil
    }
}

// MARK: - Preview

struct OverlayPatternsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SimpleTooltip(text: "Helpful info", isVisible: true)
                .frame(width: 200, height: 100)
            
            ErrorBanner(error: "Something went wrong") {}
                .frame(width: 400)
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
