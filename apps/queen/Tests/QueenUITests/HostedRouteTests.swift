import SwiftUI
import Testing
@testable import QueenUILib

@Suite("Hosted Queen routes")
struct HostedRouteTests {
    @Test func routeRetains999Metadata() {
        let route = QueenHostedRoute(
            petalIndex: 14,
            title: "Git",
            systemImage: "arrow.triangle.branch",
            worldName: "GIT",
            formula: "e^pi = 23.14",
            keyboardShortcut: 6
        ) {
            Text("Git")
        }

        #expect(route.petalIndex == 14)
        #expect(route.title == "Git")
        #expect(route.worldName == "GIT")
        #expect(route.keyboardShortcut == 6)
    }

    @Test func navigationNotificationsAreStable() {
        #expect(
            QueenHostNavigation.request.rawValue
                == "com.trinity.queen.host-navigation.request"
        )
        #expect(
            QueenHostNavigation.didOpen.rawValue
                == "com.trinity.queen.host-navigation.did-open"
        )
    }
}
