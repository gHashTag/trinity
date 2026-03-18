// Overlay Components — Popover, Tooltip, ContextualMenu, ModalView, Drawer, BannerView
import SwiftUI

// MARK: - Popover

struct Popover: View {
    let content: any View
    let attachmentAnchor: Anchor<CGRect>?
    let arrowEdge: Edge
    @Binding var isPresented: Bool

    init(
        @ViewBuilder content: () -> some View,
        attachmentAnchor: Anchor<CGRect>? = nil,
        arrowEdge: Edge = .bottom,
        isPresented: Binding<Bool>
    ) {
        self.content = AnyView(content())
        self.attachmentAnchor = attachmentAnchor
        self.arrowEdge = arrowEdge
        self._isPresented = isPresented
    }

    var body: some View {
        if isPresented {
            ZStack {
                // Backdrop for dismissal
                Color.black.opacity(0.001)
                    .onTapGesture {
                        dismiss()
                    }

                AnyView(content)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                            .fill(TrinityTheme.bgCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                            .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(TrinityTheme.shadowLargeOpacity), radius: TrinityTheme.shadowLargeRadius)
            }
            .transition(.scale.combined(with: .opacity))
            .zIndex(1000)
        }
    }

    private func dismiss() {
        withAnimation(TrinityTheme.quickSpring()) {
            isPresented = false
        }
    }
}

// MARK: - Popover Modifier

struct PopoverModifier<BaseView: View, PopoverContent: View>: ViewModifier {
    let popoverContent: PopoverContent
    let arrowEdge: Edge
    @Binding var isPresented: Bool

    func body(content: BaseView) -> some View {
        ZStack {
            content

            if isPresented {
                ZStack {
                    Color.black.opacity(0.001)
                        .onTapGesture {
                            withAnimation(TrinityTheme.quickSpring()) {
                                isPresented = false
                            }
                        }

                    popoverContent
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                                .fill(TrinityTheme.bgCard)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(TrinityTheme.shadowLargeOpacity), radius: TrinityTheme.shadowLargeRadius)
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .zIndex(1000)
            }
        }
    }
}

extension View {
    func popover<Content: View>(
        isPresented: Binding<Bool>,
        arrowEdge: Edge = .bottom,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(PopoverModifier(popoverContent: content(), arrowEdge: arrowEdge, isPresented: isPresented))
    }
}

// MARK: - Tooltip

struct Tooltip: View {
    let text: String
    let position: TooltipPosition
    @State private var isVisible = false

    enum TooltipPosition {
        case top
        case bottom
        case leading
        case trailing
        case automatic

        var edge: Edge {
            switch self {
            case .top: return .top
            case .bottom: return .bottom
            case .leading: return .leading
            case .trailing: return .trailing
            case .automatic: return .top
            }
        }

        var alignment: Alignment {
            switch self {
            case .top: return .bottom
            case .bottom: return .top
            case .leading: return .trailing
            case .trailing: return .leading
            case .automatic: return .bottom
            }
        }
    }

    init(text: String, position: TooltipPosition = .automatic) {
        self.text = text
        self.position = position
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.black.opacity(0.85))
            )
            .shadow(color: .black.opacity(0.3), radius: 4)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.9)
            .animation(.easeOut(duration: 0.2), value: isVisible)
            .onAppear {
                // Show tooltip briefly on hover
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        isVisible = true
                    }
                }
            }
    }
}

// MARK: - Contextual Menu

struct ContextualMenu: View {
    let menuItems: [MenuItem]
    let onDismiss: () -> Void

    struct MenuItem: Identifiable {
        let id = UUID()
        let title: String
        let icon: String?
        let action: () -> Void
        let isDestructive: Bool
        let isSeparator: Bool

        init(
            title: String,
            icon: String? = nil,
            isDestructive: Bool = false,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.icon = icon
            self.isDestructive = isDestructive
            self.isSeparator = false
            self.action = action
        }

        static func separator() -> MenuItem {
            MenuItem(title: "", isDestructive: false, action: {})
        }
    }

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.001)
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 0) {
                ForEach(Array(menuItems.enumerated()), id: \.element.id) { index, item in
                    if item.isSeparator {
                        Divider()
                            .background(TrinityTheme.bgCardBorder)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                    } else {
                        Button {
                            item.action()
                            onDismiss()
                        } label: {
                            HStack(spacing: 10) {
                                if let icon = item.icon {
                                    Image(systemName: icon)
                                        .font(.system(size: 13))
                                        .foregroundStyle(item.isDestructive ? TrinityTheme.statusError : TrinityTheme.textMuted)
                                        .frame(width: 20)
                                }

                                Text(item.title)
                                    .font(.system(size: 13))
                                    .foregroundStyle(item.isDestructive ? TrinityTheme.statusError : TrinityTheme.textPrimary)

                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)

                        if index < menuItems.count - 1 && !menuItems[index + 1].isSeparator {
                            Divider()
                                .background(TrinityTheme.bgCardBorder)
                                .padding(.leading, 36)
                        }
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
            .shadow(color: .black.opacity(TrinityTheme.shadowLargeOpacity), radius: TrinityTheme.shadowLargeRadius)
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Contextual Menu Modifier

struct ContextualMenuModifier: ViewModifier {
    let menuItems: [ContextualMenu.MenuItem]
    @State private var isShowingMenu = false

    func body(content: Content) -> some View {
        ZStack {
            content
                .contextMenu {
                    ForEach(menuItems) { item in
                        if item.isSeparator {
                            Divider()
                        } else {
                            Button {
                                item.action()
                            } label: {
                                HStack {
                                    if let icon = item.icon {
                                        Image(systemName: icon)
                                    }
                                    Text(item.title)
                                }
                            }
                        }
                    }
                }
        }
    }
}

extension View {
    func contextualMenu(items: [ContextualMenu.MenuItem]) -> some View {
        self.modifier(ContextualMenuModifier(menuItems: items))
    }
}

// MARK: - Modal View

struct ModalView: View {
    let title: String
    let message: String?
    let primaryButtonTitle: String
    let secondaryButtonTitle: String?
    let isPrimaryDestructive: Bool
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    @Binding var isVisible: Bool

    @State private var isAnimating = false

    init(
        title: String,
        message: String? = nil,
        primaryButtonTitle: String,
        secondaryButtonTitle: String? = nil,
        isPrimaryDestructive: Bool = false,
        isVisible: Binding<Bool>,
        onPrimary: @escaping () -> Void,
        onSecondary: @escaping () -> Void = {}
    ) {
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryButtonTitle = secondaryButtonTitle
        self.isPrimaryDestructive = isPrimaryDestructive
        self._isVisible = isVisible
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            modalBackdrop

            // Modal content
            modalContent
        }
        .onAppear {
            withAnimation(TrinityTheme.springAnimation()) {
                isAnimating = true
            }
        }
    }

    private var modalBackdrop: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .opacity(isAnimating ? 1 : 0)
            .onTapGesture {
                dismiss()
            }
    }

    private var modalContent: some View {
        VStack(spacing: 20) {
            // Title
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TrinityTheme.textPrimary)
                .multilineTextAlignment(.center)

            // Message
            if let message = message {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Buttons
            HStack(spacing: 12) {
                if let secondaryButtonTitle = secondaryButtonTitle {
                    Button(secondaryButtonTitle) {
                        dismiss()
                        onSecondary()
                    }
                    .buttonStyle(.bordered)
                }

                Button(primaryButtonTitle) {
                    dismiss()
                    onPrimary()
                }
                .buttonStyle(.borderedProminent)
                .tint(isPrimaryDestructive ? TrinityTheme.statusError : TrinityTheme.accent)
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerLarge)
        .shadow(color: .black.opacity(0.3), radius: 20)
        .scaleEffect(isAnimating ? 1 : 0.9)
        .opacity(isAnimating ? 1 : 0)
    }

    private func dismiss() {
        withAnimation(TrinityTheme.springAnimation()) {
            isAnimating = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isVisible = false
        }
    }
}

// MARK: - Modal View Modifier

struct ModalViewModifier: ViewModifier {
    let title: String
    let message: String?
    let primaryButtonTitle: String
    let secondaryButtonTitle: String?
    let isPrimaryDestructive: Bool
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    @Binding var isVisible: Bool

    func body(content: Content) -> some View {
        ZStack {
            content

            if isVisible {
                ModalView(
                    title: title,
                    message: message,
                    primaryButtonTitle: primaryButtonTitle,
                    secondaryButtonTitle: secondaryButtonTitle,
                    isPrimaryDestructive: isPrimaryDestructive,
                    isVisible: $isVisible,
                    onPrimary: onPrimary,
                    onSecondary: onSecondary
                )
                .zIndex(1000)
            }
        }
    }
}

extension View {
    func modal(
        title: String,
        message: String? = nil,
        primaryButtonTitle: String,
        secondaryButtonTitle: String? = nil,
        isPrimaryDestructive: Bool = false,
        isVisible: Binding<Bool>,
        onPrimary: @escaping () -> Void,
        onSecondary: @escaping () -> Void = {}
    ) -> some View {
        self.modifier(
            ModalViewModifier(
                title: title,
                message: message,
                primaryButtonTitle: primaryButtonTitle,
                secondaryButtonTitle: secondaryButtonTitle,
                isPrimaryDestructive: isPrimaryDestructive,
                onPrimary: onPrimary,
                onSecondary: onSecondary,
                isVisible: isVisible
            )
        )
    }
}

// MARK: - Drawer

struct Drawer: View {
    let position: DrawerPosition
    let width: CGFloat
    let content: any View
    @Binding var isOpen: Bool

    enum DrawerPosition {
        case leading
        case trailing

        var alignment: HorizontalAlignment {
            switch self {
            case .leading: return .leading
            case .trailing: return .trailing
            }
        }

        var edge: Edge {
            switch self {
            case .leading: return .leading
            case .trailing: return .trailing
            }
        }
    }

    init(
        position: DrawerPosition = .trailing,
        width: CGFloat = 320,
        @ViewBuilder content: () -> some View,
        isOpen: Binding<Bool>
    ) {
        self.position = position
        self.width = width
        self.content = AnyView(content())
        self._isOpen = isOpen
    }

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Backdrop
            if isOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .opacity(openProgress)
                    .onTapGesture {
                        closeDrawer()
                    }
            }

            // Drawer content
            drawerContent
        }
    }

    private var openProgress: Double {
        min(max(Double(1 - abs(dragOffset) / width), 0), 1)
    }

    private var drawerContent: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if position == .trailing {
                    Spacer()
                }

                AnyView(content)
                    .frame(width: width)
                    .background(TrinityTheme.bgSidebar)
                    .overlay(
                        Rectangle()
                            .fill(TrinityTheme.bgCardBorder)
                            .frame(width: 1),
                        alignment: position == .leading ? .trailing : .leading
                    )
                    .offset(x: position == .leading ? -width + CGFloat(openProgress) * width + dragOffset : width - CGFloat(openProgress) * width + dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = position == .leading ? value.translation.width : -value.translation.width
                            }
                            .onEnded { value in
                                let threshold: CGFloat = 50
                                if position == .leading {
                                    if value.translation.width > threshold {
                                        closeDrawer()
                                    } else {
                                        withAnimation { dragOffset = 0 }
                                    }
                                } else {
                                    if -value.translation.width > threshold {
                                        closeDrawer()
                                    } else {
                                        withAnimation { dragOffset = 0 }
                                    }
                                }
                            }
                    )

                if position == .leading {
                    Spacer()
                }
            }
        }
        .transition(.move(edge: position.edge))
    }

    private func closeDrawer() {
        withAnimation(TrinityTheme.springAnimation()) {
            isOpen = false
            dragOffset = 0
        }
    }
}

// MARK: - Drawer Modifier

struct DrawerModifier<DrawerContent: View>: ViewModifier {
    let position: Drawer.DrawerPosition
    let width: CGFloat
    let drawerContent: DrawerContent
    @Binding var isOpen: Bool

    func body(content: Content) -> some View {
        ZStack {
            content

            if isOpen {
                Drawer(position: position, width: width) {
                    drawerContent
                } isOpen: $isOpen
                .zIndex(999)
            }
        }
    }
}

extension View {
    func drawer<Content: View>(
        isPresented: Binding<Bool>,
        position: Drawer.DrawerPosition = .trailing,
        width: CGFloat = 320,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(DrawerModifier(position: position, width: width, drawerContent: content(), isOpen: isPresented))
    }
}

// MARK: - Banner View

struct BannerView: View {
    let message: String
    let style: BannerStyle
    let dismissible: Bool
    let autoDismissDuration: TimeInterval?
    let onDismiss: () -> Void

    enum BannerStyle {
        case info
        case warning
        case error
        case success

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .info: return Color(hex: 0x00D9FF)
            case .warning: return TrinityTheme.statusWarn
            case .error: return TrinityTheme.statusError
            case .success: return TrinityTheme.statusOK
            }
        }

        var backgroundColor: Color {
            color.opacity(0.15)
        }
    }

    @State private var isVisible = false
    @State private var timer: Timer?

    init(
        message: String,
        style: BannerStyle = .info,
        dismissible: Bool = true,
        autoDismissDuration: TimeInterval? = nil,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.message = message
        self.style = style
        self.dismissible = dismissible
        self.autoDismissDuration = autoDismissDuration
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: style.icon)
                .font(.system(size: 16))
                .foregroundStyle(style.color)

            // Message
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textPrimary)

            Spacer()

            // Dismiss button
            if dismissible {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(style.backgroundColor)
        .overlay(
            Rectangle()
                .fill(style.color)
                .frame(width: 3),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium))
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(style.color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 8)
        .offset(y: isVisible ? 0 : -80)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            withAnimation {
                isVisible = true
            }

            // Auto-dismiss timer
            if let duration = autoDismissDuration {
                timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                    dismiss()
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func dismiss() {
        timer?.invalidate()
        withAnimation {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Banner Stack

struct BannerStack: View {
    @StateObject private var manager = BannerManager()

    var body: some View {
        VStack(spacing: 8) {
            ForEach(manager.banners) { banner in
                BannerView(
                    message: banner.message,
                    style: banner.style,
                    dismissible: banner.dismissible,
                    autoDismissDuration: banner.autoDismissDuration
                ) {
                    manager.dismiss(banner.id)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(16)
    }
}

// MARK: - Banner Manager

@MainActor
class BannerManager: ObservableObject {
    @Published var banners: [BannerItem] = []

    struct BannerItem: Identifiable {
        let id = UUID()
        let message: String
        let style: BannerView.BannerStyle
        let dismissible: Bool
        let autoDismissDuration: TimeInterval?
    }

    func show(
        message: String,
        style: BannerView.BannerStyle = .info,
        dismissible: Bool = true,
        autoDismissDuration: TimeInterval? = nil
    ) {
        let banner = BannerItem(message: message, style: style, dismissible: dismissible, autoDismissDuration: autoDismissDuration)
        withAnimation {
            banners.append(banner)
        }
    }

    func dismiss(_ id: UUID) {
        withAnimation {
            banners.removeAll { $0.id == id }
        }
    }

    func info(_ message: String, autoDismiss: TimeInterval? = 4) {
        show(message: message, style: .info, autoDismissDuration: autoDismiss)
    }

    func warning(_ message: String, autoDismiss: TimeInterval? = 5) {
        show(message: message, style: .warning, autoDismissDuration: autoDismiss)
    }

    func error(_ message: String, autoDismiss: TimeInterval? = 6) {
        show(message: message, style: .error, autoDismissDuration: autoDismiss)
    }

    func success(_ message: String, autoDismiss: TimeInterval? = 3) {
        show(message: message, style: .success, autoDismissDuration: autoDismiss)
    }

    func dismissAll() {
        withAnimation {
            banners.removeAll()
        }
    }
}

// MARK: - Preview

struct OverlayComponentsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Banner styles
            VStack(spacing: 12) {
                BannerView(message: "Info message", style: .info) {}
                BannerView(message: "Warning message", style: .warning) {}
                BannerView(message: "Error occurred", style: .error) {}
                BannerView(message: "Success!", style: .success) {}
            }
            .frame(width: 400)
            .padding()
            .background(TrinityTheme.bgWindow)
            .previewDisplayName("Banners")

            // Modal
            ModalView(
                title: "Confirm Action",
                message: "Are you sure you want to proceed with this action?",
                primaryButtonTitle: "Confirm",
                secondaryButtonTitle: "Cancel",
                isVisible: .constant(true),
                onPrimary: {},
                onSecondary: {}
            )
            .frame(width: 500, height: 400)
            .background(TrinityTheme.bgWindow)
            .previewDisplayName("Modal")

            // Contextual Menu
            ContextualMenu(menuItems: [
                ContextualMenu.MenuItem(title: "Edit", icon: "pencil") {},
                ContextualMenu.MenuItem(title: "Duplicate", icon: "doc.on.doc") {},
                ContextualMenu.MenuItem.separator(),
                ContextualMenu.MenuItem(title: "Delete", icon: "trash", isDestructive: true) {}
            ], onDismiss: {})
            .frame(width: 200)
            .padding()
            .background(TrinityTheme.bgWindow)
            .previewDisplayName("Contextual Menu")

            // Tooltip
            VStack(spacing: 20) {
                Text("Hover for tooltip")
                    .padding()
                    .background(TrinityTheme.bgCard)
                    .tooltip("This is a helpful tooltip")
            }
            .frame(width: 300)
            .padding()
            .background(TrinityTheme.bgWindow)
            .previewDisplayName("Tooltip")
        }
    }
}
