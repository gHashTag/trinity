// Device Frame View — Mockup Device Frames
import SwiftUI

// MARK: - Device Frame

struct DeviceFrame: View {
    let device: Device
    let content: () -> AnyView
    let scale: CGFloat

    enum Device {
        case iPhone14, iPhone14Pro, iPadPro, macBook

        var size: CGSize {
            switch self {
            case .iPhone14: return CGSize(width: 390, height: 844)
            case .iPhone14Pro: return CGSize(width: 393, height: 852)
            case .iPadPro: return CGSize(width: 1024, height: 1366)
            case .macBook: return CGSize(width: 1440, height: 900)
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .iPhone14, .iPhone14Pro: return 40
            case .iPadPro: return 18
            case .macBook: return 12
            }
        }

        var notchSize: CGSize? {
            switch self {
            case .iPhone14: return CGSize(width: 126, height: 37)
            case .iPhone14Pro: return CGSize(width: 126, height: 37)
            default: return nil
            }
        }
    }

    init(
        device: Device = .iPhone14Pro,
        scale: CGFloat = 1.0,
        @ViewBuilder content: @escaping () -> some View
    ) {
        self.device = device
        self.scale = scale
        self.content = { AnyView(content()) }
    }

    var body: some View {
        deviceFrame
            .scaleEffect(scale)
            .shadow(color: .black.opacity(0.2), radius: 20)
    }

    @ViewBuilder
    private var deviceFrame: some View {
        ZStack {
            // Device body
            RoundedRectangle(cornerRadius: device.cornerRadius)
                .fill(.black)
                .frame(width: device.size.width, height: device.size.height)

            // Screen content
            content()
                .clipShape(RoundedRectangle(cornerRadius: device.cornerRadius - 8))
                .frame(width: device.size.width, height: device.size.height)
                .offset(y: device.notchSize == nil ? 0 : device.notchSize!.height / 2)

            // Notch (if applicable)
            if let notchSize = device.notchSize {
                RoundedRectangle(cornerRadius: notchSize.height / 2)
                    .fill(.black)
                    .frame(width: notchSize.width, height: notchSize.height)
                    .position(x: device.size.width / 2, y: notchSize.height / 2)
            }
        }
    }
}

// MARK: - Browser Frame

struct BrowserFrame: View {
    let url: String
    let content: () -> AnyView
    let scale: CGFloat

    init(
        url: String = "https://example.com",
        scale: CGFloat = 1.0,
        @ViewBuilder content: @escaping () -> some View
    ) {
        self.url = url
        self.scale = scale
        self.content = { AnyView(content()) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Browser toolbar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(TrinityTheme.statusError)
                        .frame(width: 8, height: 8)

                    Circle()
                        .fill(TrinityTheme.statusWarn)
                        .frame(width: 8, height: 8)

                    Circle()
                        .fill(TrinityTheme.statusOK)
                        .frame(width: 8, height: 8)
                    }

                Rectangle()
                    .fill(TrinityTheme.bgCardBorder)
                    .frame(height: 28)
                    .cornerRadius(6)
                    .overlay(
                        HStack {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(TrinityTheme.textMuted)
                            Text(url)
                                .font(.system(size: 11))
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                        .padding(.leading, 8)
                    )
            }
            .padding(12)
            .background(TrinityTheme.bgCard)

            // Content area
            content()
                .frame(maxWidth: .infinity)
        }
        .background(TrinityTheme.bgWindow)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 15)
        .scaleEffect(scale)
    }
}

// MARK: - Window Frame

struct WindowFrame: View {
    let title: String
    let content: () -> AnyView
    let scale: CGFloat

    init(
        title: String = "Untitled",
        scale: CGFloat = 1.0,
        @ViewBuilder content: @escaping () -> some View
    ) {
        self.title = title
        self.scale = scale
        self.content = { AnyView(content()) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack(spacing: 8) {
                Image(systemName: "app.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(TrinityTheme.accent)

                Text(title)
                    .font(.system(size: 12))

                Spacer()

                HStack(spacing: 8) {
                    Circle()
                        .fill(TrinityTheme.statusError)
                        .frame(width: 10, height: 10)

                    Circle()
                        .fill(TrinityTheme.statusWarn)
                        .frame(width: 10, height: 10)

                    Circle()
                        .fill(TrinityTheme.statusOK)
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Rectangle()
                    .fill(TrinityTheme.bgCard)
                    .overlay(
                        Rectangle()
                            .fill(TrinityTheme.bgWindow)
                            .frame(height: 1),
                        alignment: .bottom
                    )
            )

            // Content
            content()
        }
        .background(TrinityTheme.bgWindow)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.15), radius: 10)
        .scaleEffect(scale)
    }
}

// MARK: - Code Editor Frame

struct CodeEditorFrame: View {
    let language: String
    let code: String
    let scale: CGFloat

    init(
        language: String = "Swift",
        code: String,
        scale: CGFloat = 1.0
    ) {
        self.language = language
        self.code = code
        self.scale = scale
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack {
                Text(language)
                    .font(.system(size: 11))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(TrinityTheme.bgCardBorder)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TrinityTheme.bgCard)

            // Code area
            ScrollView([.horizontal, .vertical]) {
                Text(code)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(TrinityTheme.textPrimary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(red: 28/255, green: 28/255, blue: 30/255))
        }
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 8)
        .scaleEffect(scale)
    }
}

// MARK: - Split View Frame

struct SplitViewFrame: View {
    let leadingContent: () -> AnyView
    let trailingContent: () -> AnyView
    let scale: CGFloat

    init(
        scale: CGFloat = 1.0,
        @ViewBuilder leadingContent: @escaping () -> some View,
        @ViewBuilder trailingContent: @escaping () -> some View
    ) {
        self.scale = scale
        self.leadingContent = { AnyView(leadingContent()) }
        self.trailingContent = { AnyView(trailingContent()) }
    }

    var body: some View {
        HStack(spacing: 1) {
            leadingContent()
                .frame(maxWidth: .infinity)
                .background(TrinityTheme.bgCard)

            Rectangle()
                .fill(TrinityTheme.bgCardBorder)
                .frame(width: 1)

            trailingContent()
                .frame(maxWidth: .infinity)
                .background(TrinityTheme.bgCard)
        }
        .frame(height: 300)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 5)
        .scaleEffect(scale)
    }
}

// MARK: - Mockup Container

struct MockupContainer: View {
    let backgroundColor: Color
    let content: () -> AnyView

    init(
        backgroundColor: Color = TrinityTheme.bgWindow,
        @ViewBuilder content: @escaping () -> some View
    ) {
        self.backgroundColor = backgroundColor
        self.content = { AnyView(content()) }
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            content()
        }
    }
}

// MARK: - Preview

struct DeviceFrameView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DeviceFrame(device: .iPhone14Pro, scale: 0.4) {
                Text("Hello\nWorld")
                    .font(.title)
                    .multilineTextAlignment(.center)
            }

            BrowserFrame(scale: 0.5) {
                Text("Browser Content")
            }

            CodeEditorFrame(
                language: "Swift",
                code: "func hello() {\n    print(\"Hello\")\n}",
                scale: 0.8
            )
        }
        .padding()
        .background(.gray.opacity(0.1))
    }
}
