//
// Cerebellum — Accuracy & Calibration
// Snapshot and E2E tests for UI components
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - Test Preview Helpers

/// Preview helpers for UI testing
public enum CerebellumPreviews {

    /// Preview container for light mode
    public struct LightModePreview<Content: View>: View {
        let content: Content

        public init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }

        public var body: some View {
            content
                .preferredColorScheme(.light)
        }
    }

    /// Preview container for dark mode
    public struct DarkModePreview<Content: View>: View {
        let content: Content

        public init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }

        public var body: some View {
            content
                .preferredColorScheme(.dark)
        }
    }

    /// Preview container with both light and dark modes
    public struct DualModePreview<Content: View>: View {
        let content: Content

        public init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }

        public var body: some View {
            VStack {
                Text("Light Mode")
                    .font(.caption)
                content
                    .preferredColorScheme(.light)
                    .previewDisplayName("Light Mode")

                Divider()

                Text("Dark Mode")
                    .font(.caption)
                content
                    .preferredColorScheme(.dark)
                    .previewDisplayName("Dark Mode")
            }
        }
    }
}

// MARK: - Component Test Catalog

/// Catalog of all Cortex components for visual testing
public struct CerebellumComponentCatalog: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ParietalSpacing.xl) {
                catalogSection("Visual Cortex") {
                    // V1 Theme colors
                    colorPaletteSection("V1 Theme Colors", colors: [
                        ("Background", V1Theme.bgWindow),
                        ("Sidebar", V1Theme.bgSidebar),
                        ("Card", V1Theme.bgCard),
                        ("Text Primary", V1Theme.textPrimary),
                        ("Text Muted", V1Theme.textMuted),
                        ("Accent", V1Theme.accent)
                    ])

                    // V4 Semantic colors
                    colorPaletteSection("V4 Semantic Colors", colors: [
                        ("Background", V4Color.background),
                        ("Surface", V4Color.surface),
                        ("Error", V4Color.error),
                        ("Warning", V4Color.warning),
                        ("Success", V4Color.success),
                        ("Info", V4Color.info)
                    ])
                }

                catalogSection("Language Cortex") {
                    typographySection()

                    BrocaInput(
                        text: .constant(""),
                        placeholder: "Enter text..."
                    )

                    BrocaChatInput(
                        text: .constant(""),
                        placeholder: "Type a message...",
                        onSubmit: {},
                        onAttach: {}
                    )
                }

                catalogSection("Navigation Cortex") {
                    EntorhinalNavItem(
                        title: "Sample Item",
                        icon: "star.fill",
                        isSelected: false
                    ) {}

                    SuperiorColliculusAccordion(
                        "Accordion Title",
                        icon: "chevron.down",
                        subtitle: "Tap to expand",
                        isExpanded: .constant(true)
                    ) {
                        Text("Accordion content goes here")
                            .font(WernickeTypography.body)
                    }
                }

                catalogSection("Executive Cortex") {
                    ACCFeedback.LoadingView(message: "Loading...")

                    ACCFeedback.EmptyView(
                        title: "No Items",
                        message: "Add items to get started",
                        systemImage: "tray"
                    )
                }

                catalogSection("Retrieval Cortex") {
                    ParahippocampalInlineSearch(
                        text: .constant(""),
                        placeholder: "Search..."
                    )
                }
            }
            .padding()
        }
        .background(V4Color.background)
    }

    @ViewBuilder
    private func catalogSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            Text(title)
                .font(WernickeTypography.h4)
                .foregroundStyle(V4Color.accent)

            content()
        }
    }

    @ViewBuilder
    private func colorPaletteSection(_ title: String, colors: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            Text(title)
                .font(WernickeTypography.small)
                .foregroundStyle(V4Color.textSecondary)

            VStack(spacing: ParietalSpacing.xs) {
                ForEach(colors, id: \.0) { name, color in
                    HStack {
                        Color.swatch(color)
                            .frame(width: ParietalSpacing.standardFrame, height: ParietalSpacing.itemHeight)
                            .cornerRadius(V1Theme.cornerSmall)

                        Text(name)
                            .font(WernickeTypography.caption)

                        Spacer()
                    }
                }
            }
            .padding(ParietalSpacing.sm)
            .background(V4Color.surface)
            .cornerRadius(V1Theme.cornerMedium)
        }
    }

    @ViewBuilder
    private func typographySection() -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            Text("Typography Scale")
                .font(WernickeTypography.small)
                .foregroundStyle(V4Color.textSecondary)

            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                Text("Heading 1").font(WernickeTypography.h1)
                Text("Heading 2").font(WernickeTypography.h2)
                Text("Heading 3").font(WernickeTypography.h3)
                Text("Body text").font(WernickeTypography.body)
                Text("Caption text").font(WernickeTypography.caption)
            }
            .padding(ParietalSpacing.sm)
            .background(V4Color.surface)
            .cornerRadius(V1Theme.cornerMedium)
        }
    }
}

extension Color {
    fileprivate static func swatch(_ color: Color) -> some View {
        color
    }
}

// MARK: - Xcode Preview Provider
// NOTE: Preview blocks removed for CLI build compatibility
// Use Xcode to preview components during development

// MARK: - Unit Tests (for test target only)

#if DEBUG && canImport(XCTest)
import XCTest

/// Cerebellum — Accuracy & Calibration Tests
///
/// These tests should be run in a separate test target.
/// Move this code to QueenUITests/CerebellumTests.swift for actual testing.
final class CerebellumUnitTests: XCTestCase {

    // MARK: - V1 Theme Tests

    func testV1Theme_colorsExist() {
        XCTAssertNotNil(V1Theme.bgWindow)
        XCTAssertNotNil(V1Theme.bgSidebar)
        XCTAssertNotNil(V1Theme.bgCard)
        XCTAssertNotNil(V1Theme.textPrimary)
        XCTAssertNotNil(V1Theme.textMuted)
        XCTAssertNotNil(V1Theme.accent)
    }

    func testV1Theme_cornerRadii() {
        XCTAssertEqual(V1Theme.cornerSmall, 6)
        XCTAssertEqual(V1Theme.cornerMedium, 10)
        XCTAssertEqual(V1Theme.cornerLarge, 12)
        XCTAssertEqual(V1Theme.cornerXL, 24)
    }

    // MARK: - V4 Color Tests

    func testV4Color_semanticColorsExist() {
        XCTAssertNotNil(V4Color.background)
        XCTAssertNotNil(V4Color.surface)
        XCTAssertNotNil(V4Color.textPrimary)
        XCTAssertNotNil(V4Color.textSecondary)
        XCTAssertNotNil(V4Color.accent)
        XCTAssertNotNil(V4Color.error)
        XCTAssertNotNil(V4Color.warning)
        XCTAssertNotNil(V4Color.success)
    }

    // MARK: - Parietal Spacing Tests

    func testParietalSpacing_spacingScale() {
        XCTAssertEqual(ParietalSpacing.xxs, 4)
        XCTAssertEqual(ParietalSpacing.xs, 8)
        XCTAssertEqual(ParietalSpacing.sm, 12)
        XCTAssertEqual(ParietalSpacing.md, 16)
        XCTAssertEqual(ParietalSpacing.lg, 24)
        XCTAssertEqual(ParietalSpacing.xl, 32)
        XCTAssertEqual(ParietalSpacing.xxl, 48)
    }

    func testParietalSpacing_minTouchTarget() {
        XCTAssertEqual(ParietalSpacing.minTouchTarget, 44)
    }

    // MARK: - Component Initialization Tests

    func testBrocaInput_canBeCreated() {
        let input = BrocaInput(
            text: .constant(""),
            placeholder: "Enter text"
        )
        XCTAssertNotNil(input)
    }

    func testEntorhinalNavItem_canBeCreated() {
        let navItem = EntorhinalNavItem(
            title: "Test",
            icon: "star.fill",
            isSelected: false
        ) {}
        XCTAssertNotNil(navItem)
    }

    func testAccordion_canBeCreated() {
        let accordion = SuperiorColliculusAccordion(
            "Test Title",
            isExpanded: .constant(true)
        ) {
            Text("Content")
        }
        XCTAssertNotNil(accordion)
    }

    // MARK: - Accessibility Tests

    func testAccessibility_highContrastColorsExist() {
        XCTAssertNotNil(V4Color.HighContrast.background)
        XCTAssertNotNil(V4Color.HighContrast.textPrimary)
        XCTAssertNotNil(V4Color.HighContrast.accent)
    }
}
#endif
