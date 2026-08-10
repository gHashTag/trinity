import SwiftUI

public struct QueenHostedRoute {
    public let petalIndex: Int
    public let title: String
    public let systemImage: String
    public let worldName: String
    public let formula: String
    public let keyboardShortcut: Int
    let content: AnyView

    public init<Content: View>(
        petalIndex: Int,
        title: String,
        systemImage: String,
        worldName: String,
        formula: String,
        keyboardShortcut: Int,
        @ViewBuilder content: () -> Content
    ) {
        self.petalIndex = petalIndex
        self.title = title
        self.systemImage = systemImage
        self.worldName = worldName
        self.formula = formula
        self.keyboardShortcut = keyboardShortcut
        self.content = AnyView(content())
    }
}

public enum QueenHostNavigation {
    public static let request = Notification.Name(
        "com.trinity.queen.host-navigation.request"
    )
    public static let didOpen = Notification.Name(
        "com.trinity.queen.host-navigation.did-open"
    )

    public static func open(petalIndex: Int) {
        NotificationCenter.default.post(name: request, object: petalIndex)
    }

    public static func showMenu() {
        NotificationCenter.default.post(name: request, object: -1)
    }
}
