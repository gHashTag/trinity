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
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xs)
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
                        HStack(spacing: ParietalSpacing.sm + 2) {
                            Image(systemName: item.icon)
                                .font(WernickeTypography.size13)
                                .foregroundStyle(V4Color.textSecondary)
                                .frame(width: ParietalSpacing.buttonSmallWidth)
                            
                            Text(item.title)
                                .font(WernickeTypography.size13)
                                .foregroundStyle(V4Color.textPrimary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, ParietalSpacing.sm + 2)
                        .padding(.vertical, ParietalSpacing.xs + 2)
                    }
                    .buttonStyle(.plain)
                    
                    if index < items.count - 1 {
                        Divider()
                            .background(V4Color.border)
                    }
                }
            }
            .padding(ParietalSpacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                    .fill(V4Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                    .stroke(V4Color.border, lineWidth: 1)
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
            Color.black.opacity(V2Depth.stateHover)
                .ignoresSafeArea()
            
            VStack(spacing: ParietalSpacing.lg) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(V4Color.accent)
                
                Text(message)
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.textPrimary)
            }
            .padding(ParietalSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                    .fill(V4Color.surface)
            )
        }
        .opacity(isVisible ? 1 : 0)
    }
}

// MARK: - Error Banner

struct OverlayErrorBanner: View {
    let error: String
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(WernickeTypography.size16)
                .foregroundStyle(V4Color.error)
            
            Text(error)
                .font(WernickeTypography.size13)
                .foregroundStyle(V4Color.textPrimary)
            
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
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(ParietalSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .fill(V4Color.error.opacity(V2Depth.bgSubtle))
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
                .frame(width: ParietalSpacing.modalFrame, height: ParietalSpacing.xxLargeFrame)
            
            OverlayErrorBanner(error: "Something went wrong") {}
                .frame(width: ParietalSpacing.xl * 16)
        }
        .padding()
        .background(V4Color.background)
    }
}
