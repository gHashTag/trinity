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

    /// Screens that have no petal on the 27-block triangle and are reached by
    /// a direct chord instead. Works from any screen, not only the main menu.
    static let offMenuScreens: [(character: Character, screen: Screen, label: String)] = [
        ("h", .hive, "Cmd+Shift+H"),
    ]

    static func offMenuScreen(
        character: Character?,
        modifiers: NSEvent.ModifierFlags
    ) -> Screen? {
        guard let character else { return nil }
        let exact = modifiers.intersection(relevantModifiers)
        guard exact == [.command, .shift] else { return nil }
        let lowered = Character(character.lowercased())
        return offMenuScreens.first { $0.character == lowered }?.screen
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
