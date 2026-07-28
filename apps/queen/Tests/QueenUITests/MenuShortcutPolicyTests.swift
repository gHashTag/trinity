import AppKit
import Testing
@testable import QueenUILib

@Suite("Queen 999 menu shortcut policy")
struct MenuShortcutPolicyTests {
    @Test @MainActor func navigationVisibilityTracksOpenedScreens() {
        let state = QueenNavigationState()

        #expect(state.isMainMenuVisible)

        state.selectedHostedPetal = 0
        #expect(!state.isMainMenuVisible)

        state.selectedHostedPetal = nil
        state.selectedScreen = .files
        #expect(!state.isMainMenuVisible)

        state.selectedScreen = nil
        #expect(state.isMainMenuVisible)
    }

    @Test func threeModifierRowsCoverAllPetals() {
        for digit in 1...9 {
            #expect(
                QueenMenuShortcutPolicy.petalIndex(
                    digit: digit,
                    modifiers: [.command],
                    isMainMenuVisible: true
                ) == digit - 1
            )
            #expect(
                QueenMenuShortcutPolicy.petalIndex(
                    digit: digit,
                    modifiers: [.option],
                    isMainMenuVisible: true
                ) == digit + 8
            )
            #expect(
                QueenMenuShortcutPolicy.petalIndex(
                    digit: digit,
                    modifiers: [.control],
                    isMainMenuVisible: true
                ) == digit + 17
            )
        }
    }

    @Test func openedScreensNeverInterceptDigitRows() {
        for digit in 1...9 {
            for modifiers: NSEvent.ModifierFlags in [
                [.command],
                [.option],
                [.control],
            ] {
                #expect(
                    QueenMenuShortcutPolicy.petalIndex(
                        digit: digit,
                        modifiers: modifiers,
                        isMainMenuVisible: false
                    ) == nil
                )
            }
        }
    }

    @Test func mixedModifiersAndInvalidDigitsPassThrough() {
        #expect(
            QueenMenuShortcutPolicy.petalIndex(
                digit: 1,
                modifiers: [.command, .option],
                isMainMenuVisible: true
            ) == nil
        )
        #expect(
            QueenMenuShortcutPolicy.petalIndex(
                digit: 1,
                modifiers: [.command, .shift],
                isMainMenuVisible: true
            ) == nil
        )
        #expect(
            QueenMenuShortcutPolicy.petalIndex(
                digit: 0,
                modifiers: [.command],
                isMainMenuVisible: true
            ) == nil
        )
        #expect(
            QueenMenuShortcutPolicy.petalIndex(
                digit: 10,
                modifiers: [.control],
                isMainMenuVisible: true
            ) == nil
        )
    }

    @Test func tooltipLabelsMatchRows() {
        #expect(QueenMenuShortcutPolicy.label(forPetalIndex: 0) == "Cmd+1")
        #expect(QueenMenuShortcutPolicy.label(forPetalIndex: 8) == "Cmd+9")
        #expect(QueenMenuShortcutPolicy.label(forPetalIndex: 9) == "Option+1")
        #expect(QueenMenuShortcutPolicy.label(forPetalIndex: 17) == "Option+9")
        #expect(QueenMenuShortcutPolicy.label(forPetalIndex: 18) == "Control+1")
        #expect(QueenMenuShortcutPolicy.label(forPetalIndex: 26) == "Control+9")
        #expect(QueenMenuShortcutPolicy.label(forPetalIndex: 27) == nil)
    }
}
