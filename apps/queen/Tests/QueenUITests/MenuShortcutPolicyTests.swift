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

    // MARK: - Off-menu screens

    @Test func hiveIsReachableByChordSinceItHasNoPetal() {
        #expect(
            QueenMenuShortcutPolicy.offMenuScreen(
                character: "h",
                modifiers: [.command, .shift]
            ) == .hive
        )
        // Case is irrelevant: shift is part of the chord, so the character
        // arrives capitalised on most layouts.
        #expect(
            QueenMenuShortcutPolicy.offMenuScreen(
                character: "H",
                modifiers: [.command, .shift]
            ) == .hive
        )
    }

    @Test func offMenuChordRequiresTheExactModifiers() {
        #expect(QueenMenuShortcutPolicy.offMenuScreen(character: "h", modifiers: [.command]) == nil)
        #expect(QueenMenuShortcutPolicy.offMenuScreen(character: "h", modifiers: []) == nil)
        #expect(
            QueenMenuShortcutPolicy.offMenuScreen(
                character: "h",
                modifiers: [.command, .shift, .option]
            ) == nil
        )
        #expect(QueenMenuShortcutPolicy.offMenuScreen(character: nil, modifiers: [.command, .shift]) == nil)
    }

    // MARK: - Empty-chat suggestion grid
    //
    // Regression: the grid indexed 0..<3 and 3..<6 into a list whose
    // contextual entries only appear when live state provides them. With the
    // three static fallbacks alone, suggestions[3] trapped and took the whole
    // app down — reproduced as a SIGTRAP in EmptyThreadView.body.

    @Test func suggestionGridHandlesFewerItemsThanAFullRow() {
        #expect(EmptyThreadView.chunk([1, 2, 3], size: 3) == [[1, 2, 3]])
        #expect(EmptyThreadView.chunk([1], size: 3) == [[1]])
        #expect(EmptyThreadView.chunk([Int](), size: 3) == [])
    }

    @Test func suggestionGridSplitsIntoRowsOfThree() {
        #expect(
            EmptyThreadView.chunk([1, 2, 3, 4, 5, 6], size: 3) == [[1, 2, 3], [4, 5, 6]]
        )
        #expect(
            EmptyThreadView.chunk([1, 2, 3, 4], size: 3) == [[1, 2, 3], [4]]
        )
    }

    @Test func suggestionGridNeverLosesAnItem() {
        for count in 0...12 {
            let items = Array(1...max(count, 1)).prefix(count).map { $0 }
            let flattened = EmptyThreadView.chunk(items, size: 3).flatMap { $0 }
            #expect(flattened == items)
        }
    }

    @Test func everyOffMenuScreenIsGenuinelyOffTheTriangle() {
        let petalScreens = Set((0..<27).map(Screen.screenForBlock))
        for entry in QueenMenuShortcutPolicy.offMenuScreens {
            #expect(!petalScreens.contains(entry.screen))
        }
    }
}
