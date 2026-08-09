import AppKit
import SwiftUI

@MainActor
final class QueenNavigationState: ObservableObject {
    @Published var selectedScreen: Screen?
    @Published var selectedHostedPetal: Int?

    var isMainMenuVisible: Bool {
        selectedScreen == nil && selectedHostedPetal == nil
    }
}

enum QueenMenuShortcutPolicy {
    private static let relevantModifiers: NSEvent.ModifierFlags = [
        .command,
        .option,
        .control,
        .shift,
    ]

    static func petalIndex(
        digit: Int,
        modifiers: NSEvent.ModifierFlags,
        isMainMenuVisible: Bool
    ) -> Int? {
        guard isMainMenuVisible, (1...9).contains(digit) else {
            return nil
        }

        let exactModifiers = modifiers.intersection(relevantModifiers)
        let rowOffset: Int

        if exactModifiers == [.command] {
            rowOffset = 0
        } else if exactModifiers == [.option] {
            rowOffset = 9
        } else if exactModifiers == [.control] {
            rowOffset = 18
        } else {
            return nil
        }

        return rowOffset + digit - 1
    }

    static func label(forPetalIndex petalIndex: Int) -> String? {
        guard (0..<27).contains(petalIndex) else {
            return nil
        }

        let row = petalIndex / 9
        let digit = petalIndex % 9 + 1

        switch row {
        case 0:
            return "Cmd+\(digit)"
        case 1:
            return "Option+\(digit)"
        case 2:
            return "Control+\(digit)"
        default:
            return nil
        }
    }
}
