import SwiftUI

// MARK: - Focus Mode View

struct FocusModeView: View {
    @Binding var isFocusMode: Bool
    @Binding var content: String
    @Binding var scrollPosition: CGFloat
    let contentHeight: CGFloat

    @State private var ambientColorHex: String = "0x0A0A0F"
    @State private var focusFontSize: Int = 16
    @State private var autoScrollEnabled = true
    @State private var showProgress = true
    @State private var hoverExitButton = false
    @State private var showControls = false

    private var ambientColor: Color {
        Color(hex: UInt32(ambientColorHex.dropFirst(2), radix: 16) ?? 0x0A0A0F)
    }

    private var fontSize: CGFloat {
        CGFloat(focusFontSize)
    }

    private var readingProgress: Double {
        guard contentHeight > 0 else { return 0 }
        let progress = min(max(scrollPosition / contentHeight, 0), 1)
        return progress
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Ambient background
            ambientColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: ambientColorHex)

            // Exit focus mode button (floating pill)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isFocusMode = false
                        }
                    } label: {
                        HStack(spacing: ParietalSpacing.sm - 2) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                            Text("Exit Focus")
                            Text("(Esc)")
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
                        }
                        .font(WernickeTypography.smallMedium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, ParietalSpacing.md + 2)
                        .padding(.vertical, ParietalSpacing.sm)
                        .background(
                            SwiftUI.Capsule()
                                .fill(Color.black.opacity(V1Theme.opacityTextSecondary))
                                .overlay(
                                    SwiftUI.Capsule()
                                        .stroke(hoverExitButton ? V4Color.accent : V4Color.white20, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Exit focus mode (Esc)")
                    .accessibilityLabel("Exit focus mode")
                    .accessibilityHint("Double tap to exit focus mode and return to normal view")
                    .padding(.trailing, 20)
                    .padding(.top, 12)
                    .scaleEffect(hoverExitButton ? 1.02 : 1.0)
                    .onHover { hoverExitButton = $0 }
                }
                Spacer()
            }
            .padding(.top, 8)

            // Content area (centered, readable width)
            VStack {
                Spacer()
                ScrollView {
                    VStack(alignment: .leading, spacing: ParietalSpacing.lg) {
                        MarkdownTextView(text: content)
                            .font(.system(size: fontSize))
                    }
                    .frame(maxWidth: 680, alignment: .leading)
                    .padding(.horizontal, ParietalSpacing.xxl)
                    .padding(.vertical, ParietalSpacing.xxl)
                }
                Spacer()
            }

            // Reading progress indicator (bottom)
            if showProgress && contentHeight > 0 {
                VStack {
                    Spacer()
                    readingProgressIndicator
                        .padding(.bottom, 20)
                }
            }

            // Focus mode controls (collapsible panel)
            VStack {
                Spacer()
                focusModeControlsPanel
                    .padding(.trailing, 20)
                    .padding(.bottom, 80)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onReceive(NotificationCenter.default.publisher(for: .escapeAction)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isFocusMode = false
            }
        }
        .onAppear {
            // Load saved preferences
            if let savedColor = UserDefaults.standard.string(forKey: "focusModeAmbientColor") {
                ambientColorHex = savedColor
            }
            focusFontSize = UserDefaults.standard.integer(forKey: "focusModeFontSize")
            if focusFontSize == 0 { focusFontSize = 16 }
            autoScrollEnabled = UserDefaults.standard.bool(forKey: "focusModeAutoScroll")
            showProgress = UserDefaults.standard.bool(forKey: "focusModeShowProgress")
            if !UserDefaults.standard.bool(forKey: "focusModeShowProgressSet") {
                showProgress = true
            }
        }
    }

    // MARK: - Reading Progress Indicator

    private var readingProgressIndicator: some View {
        VStack(spacing: ParietalSpacing.sm - 2) {
            HStack(spacing: ParietalSpacing.sm) {
                Text("\(Int(readingProgress * 100))%")
                    .font(WernickeTypography.caption2MediumMono)
                    .foregroundStyle(V4Color.accent)
                    .frame(width: ParietalSpacing.cellFrame)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(V2Depth.bgSubtle))
                            .frame(height: ParietalSpacing.xs)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(V4Color.accent)
                            .frame(width: geometry.size.width * readingProgress, height: ParietalSpacing.microHeight)
                    }
                }
                .frame(height: ParietalSpacing.xs)
            }
            .frame(width: ParietalSpacing.xl * 5)

            Text("Reading progress")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.sm)
        .background(
            SwiftUI.Capsule()
                .fill(Color.black.opacity(V2Depth.stateDisabled))
        )
    }

    // MARK: - Focus Mode Controls Panel

    private var focusModeControlsPanel: some View {
        VStack(spacing: 0) {
            // Toggle button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showControls.toggle()
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(WernickeTypography.size16)
                    .foregroundStyle(showControls ? V4Color.accent : Color.white.opacity(V1Theme.opacityTextTertiary))
                    .frame(width: ParietalSpacing.cellFrame, height: ParietalSpacing.avatarLargeHeight)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(V1Theme.opacityTextSecondary))
                            .overlay(
                                Circle()
                                    .stroke(showControls ? V4Color.accent.opacity(V2Depth.stateDisabled) : Color.white.opacity(V2Depth.bgSubtle), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .help("Focus mode settings")
            .accessibilityLabel("Focus mode settings")
            .accessibilityHint("Double tap to show or hide focus mode controls")

            if showControls {
                VStack(spacing: ParietalSpacing.md) {
                    // Font size control
                    VStack(spacing: ParietalSpacing.sm - 2) {
                        Text("Font Size")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))

                        HStack(spacing: ParietalSpacing.sm) {
                            Button {
                                withAnimation {
                                    focusFontSize = max(12, focusFontSize - 2)
                                    savePreferences()
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .font(WernickeTypography.miniBold)
                                    .foregroundStyle(Color.white.opacity(V1Theme.opacityTextSecondary))
                                    .frame(width: ParietalSpacing.lg, height: ParietalSpacing.lg)
                                    .background(Circle().fill(Color.white.opacity(V2Depth.bgSubtle)))
                            }
                            .buttonStyle(.plain)
                            .disabled(focusFontSize <= 12)

                            Text("\(focusFontSize)pt")
                                .font(WernickeTypography.caption2MediumMono)
                                .foregroundStyle(.white)
                                .frame(width: ParietalSpacing.buttonMediumWidth)

                            Button {
                                withAnimation {
                                    focusFontSize = min(28, focusFontSize + 2)
                                    savePreferences()
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(WernickeTypography.miniBold)
                                    .foregroundStyle(Color.white.opacity(V1Theme.opacityTextSecondary))
                                    .frame(width: ParietalSpacing.lg, height: ParietalSpacing.lg)
                                    .background(Circle().fill(Color.white.opacity(V2Depth.bgSubtle)))
                            }
                            .buttonStyle(.plain)
                            .disabled(focusFontSize >= 28)
                        }
                    }

                    Divider()
                        .background(Color.white.opacity(V2Depth.bgSubtle))

                    // Ambient color picker (presets)
                    VStack(spacing: ParietalSpacing.sm - 2) {
                        Text("Background")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))

                        HStack(spacing: ParietalSpacing.sm - 2) {
                            colorButton("0x0A0A0F", name: "Deep")     // Default dark
                            colorButton("0x000000", name: "OLED")      // Pure black
                            colorButton("0x0D1117", name: "GitHub")    // GitHub dark
                            colorButton("0x1E1E1E", name: "VS Code")  // VS Code
                            colorButton("0x2C2C2C", name: "Slate")    // Warm gray
                        }
                    }

                    Divider()
                        .background(Color.white.opacity(V2Depth.bgSubtle))

                    // Toggles
                    VStack(spacing: ParietalSpacing.sm) {
                        Toggle("Progress Bar", isOn: $showProgress)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .toggleStyle(.switch)
                            .onChange(of: showProgress) { _, _ in savePreferences() }

                        Toggle("Auto Scroll", isOn: $autoScrollEnabled)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .toggleStyle(.switch)
                            .onChange(of: autoScrollEnabled) { _, _ in savePreferences() }
                    }
                }
                .padding(ParietalSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(V2Depth.bgSubtle), lineWidth: 1)
                        )
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showControls)
    }

    private func colorButton(_ hex: String, name: String) -> some View {
        let isSelected = ambientColorHex == hex
        return Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                ambientColorHex = hex
                savePreferences()
            }
        } label: {
            Color(hex: UInt32(hex.dropFirst(2), radix: 16) ?? 0x0A0A0F)
                .frame(width: ParietalSpacing.lg, height: ParietalSpacing.lg)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(isSelected ? V4Color.accent : V4Color.white20, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel("\(name) background")
    }

    private func savePreferences() {
        UserDefaults.standard.set(ambientColorHex, forKey: "focusModeAmbientColor")
        UserDefaults.standard.set(focusFontSize, forKey: "focusModeFontSize")
        UserDefaults.standard.set(autoScrollEnabled, forKey: "focusModeAutoScroll")
        UserDefaults.standard.set(showProgress, forKey: "focusModeShowProgress")
        UserDefaults.standard.set(true, forKey: "focusModeShowProgressSet")
    }
}

// MARK: - Focus Mode Toggle Button

struct FocusModeToggleButton: View {
    @Binding var isFocusMode: Bool
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                isFocusMode.toggle()
            }
            NotificationCenter.default.post(name: .toggleFocusMode, object: nil)
        } label: {
            Image(systemName: isFocusMode ? "viewfinder.circle.fill" : "viewfinder.circle")
                .font(WernickeTypography.size15)
                .foregroundStyle(isFocusMode ? V4Color.accent : Color.white.opacity(V1Theme.opacityTextTertiary))
                .frame(width: ParietalSpacing.smallIconFrame, height: ParietalSpacing.smallButtonHeight)
                .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .help(isFocusMode ? "Exit focus mode" : "Enter focus mode")
        .accessibilityLabel(isFocusMode ? "Exit focus mode" : "Enter focus mode")
        .accessibilityHint("Double tap to toggle focus mode for distraction-free reading")
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preview Provider

struct FocusModeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FocusModeView(
                isFocusMode: .constant(true),
                content: .constant("# Focus Mode\n\nThis is a distraction-free reading environment.\n\n## Features\n\n- Hides sidebar and header\n- Adjustable font size\n- Ambient background colors\n- Reading progress indicator\n\nPress **Esc** to exit."),
                scrollPosition: .constant(100),
                contentHeight: 500
            )
            .previewDisplayName("Focus Mode Active")

            FocusModeToggleButton(isFocusMode: .constant(false))
                .padding()
                .background(Color.black)
                .previewDisplayName("Toggle Button")
        }
    }
}
