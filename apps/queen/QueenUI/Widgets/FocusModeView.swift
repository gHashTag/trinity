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
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                            Text("Exit Focus")
                            Text("(Esc)")
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    Capsule()
                                        .stroke(hoverExitButton ? TrinityTheme.accent : Color.white.opacity(0.2), lineWidth: 1)
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
                    VStack(alignment: .leading, spacing: 16) {
                        MarkdownTextView(text: content)
                            .font(.system(size: fontSize))
                    }
                    .frame(maxWidth: 680, alignment: .leading)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 40)
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
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("\(Int(readingProgress * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(TrinityTheme.accent)
                    .frame(width: 36)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(TrinityTheme.accent)
                            .frame(width: geometry.size.width * readingProgress, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(width: 120)

            Text("Reading progress")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.5))
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
                    .font(.system(size: 16))
                    .foregroundStyle(showControls ? TrinityTheme.accent : Color.white.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                Circle()
                                    .stroke(showControls ? TrinityTheme.accent.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .help("Focus mode settings")
            .accessibilityLabel("Focus mode settings")
            .accessibilityHint("Double tap to show or hide focus mode controls")

            if showControls {
                VStack(spacing: 12) {
                    // Font size control
                    VStack(spacing: 6) {
                        Text("Font Size")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.5))

                        HStack(spacing: 8) {
                            Button {
                                withAnimation {
                                    focusFontSize = max(12, focusFontSize - 2)
                                    savePreferences()
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.6))
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Color.white.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                            .disabled(focusFontSize <= 12)

                            Text("\(focusFontSize)pt")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(width: 40)

                            Button {
                                withAnimation {
                                    focusFontSize = min(28, focusFontSize + 2)
                                    savePreferences()
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.6))
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Color.white.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                            .disabled(focusFontSize >= 28)
                        }
                    }

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // Ambient color picker (presets)
                    VStack(spacing: 6) {
                        Text("Background")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.5))

                        HStack(spacing: 6) {
                            colorButton("0x0A0A0F", name: "Deep")     // Default dark
                            colorButton("0x000000", name: "OLED")      // Pure black
                            colorButton("0x0D1117", name: "GitHub")    // GitHub dark
                            colorButton("0x1E1E1E", name: "VS Code")  // VS Code
                            colorButton("0x2C2C2C", name: "Slate")    // Warm gray
                        }
                    }

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // Toggles
                    VStack(spacing: 8) {
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
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(isSelected ? TrinityTheme.accent : Color.white.opacity(0.2), lineWidth: 2)
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
                .font(.system(size: 15))
                .foregroundStyle(isFocusMode ? TrinityTheme.accent : Color.white.opacity(0.4))
                .frame(width: 28, height: 28)
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
