import SwiftUI

public enum QueenSurfaceStyle: Sendable {
    case canonical
    case hostGlass

    public var usesTransparentBackground: Bool {
        self == .hostGlass
    }
}

/// Public host surface for embedding the complete Queen interface in Trios.
/// It renders the same MainView and injects the same services as QueenApp.
public struct EmbeddedQueenRoot: View {
    @StateObject private var watcher: StateWatcher
    @ObservedObject private var accessibility = AccessibilityManager.shared
    @ObservedObject private var server = ControlServer.shared
    private let hostedRoutes: [QueenHostedRoute]
    private let surfaceStyle: QueenSurfaceStyle

    public init(
        projectRoot: String,
        hostedRoutes: [QueenHostedRoute] = [],
        surfaceStyle: QueenSurfaceStyle = .hostGlass
    ) {
        TrinityRuntimePaths.configure(projectRoot: projectRoot)
        self.hostedRoutes = hostedRoutes
        self.surfaceStyle = surfaceStyle
        // The standalone app owns first-launch onboarding. An embedded host is
        // narrower and keeps the overlay available through the normal shortcut.
        UserDefaults.standard.set(true, forKey: "hasSeenShortcuts")
        // The Chat onboarding sheet has a standalone fixed width that can
        // overflow a compact host. Trios opens directly into the live surface.
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        _watcher = StateObject(
            wrappedValue: StateWatcher(trinityPath: TrinityRuntimePaths.stateRoot)
        )
    }

    public var body: some View {
        MainView(
            hostedRoutes: hostedRoutes,
            surfaceStyle: surfaceStyle
        )
            .environmentObject(watcher)
            .environmentObject(accessibility)
            .environmentObject(server)
            .preferredColorScheme(.dark)
            .onAppear {
                watcher.reload()
                server.startIfPuppetMode()
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 8_000_000_000)
                    guard !Task.isCancelled else { break }
                    watcher.reload()
                }
            }
    }
}
