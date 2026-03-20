import SwiftUI

/// Split-screen view for comparing two message versions (original vs edited/regenerated)
struct MessageComparisonView: View {
    @Binding var isPresented: Bool
    @Binding var onAccept: Bool

    let originalText: String
    let newText: String
    let originalTitle: String
    let newTitle: String

    @State private var scrollOffset: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    init(
        isPresented: Binding<Bool>,
        onAccept: Binding<Bool>,
        originalText: String,
        newText: String,
        originalTitle: String = "Original",
        newTitle: String = "New Version"
    ) {
        self._isPresented = isPresented
        self._onAccept = onAccept
        self.originalText = originalText
        self.newText = newText
        self.originalTitle = originalTitle
        self.newTitle = newTitle
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            titleBar

            // Divider
            Divider()
                .background(V4Color.bgCardBorder)

            // Comparison panes
            HStack(spacing: 0) {
                // Left: Original
                messagePane(
                    text: originalText,
                    title: originalTitle,
                    diffType: .original
                )

                // Center divider
                Divider()
                    .background(V4Color.bgCardBorder)

                // Right: New version
                messagePane(
                    text: newText,
                    title: newTitle,
                    diffType: .new
                )
            }

            // Divider
            Divider()
                .background(V4Color.bgCardBorder)

            // Action buttons
            actionButtons
        }
        .background(V4Color.bgWindow)
        .frame(minWidth: 800, minHeight: 500)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack {
            HStack(spacing: ParietalSpacing.sm) {
                Image(systemName: "doc.on.doc")
                    .font(WernickeTypography.body14Medium)
                    .foregroundStyle(V4Color.accent)

                Text("Compare Versions")
                    .font(WernickeTypography.smallSemibold)
                    .foregroundStyle(V4Color.textPrimary)
            }

            Spacer()

            Button {
                withAnimation(MTMotion.adaptiveStandardSpring()) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(WernickeTypography.size16)
                    .foregroundStyle(V4Color.textSecondary)
            }
            .buttonStyle(.plain)
            .onHover { isHovering in
                // Hover effect handled by system
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(V4Color.bgCard)
    }

    // MARK: - Message Pane

    private enum DiffType {
        case original
        case new
    }

    private func messagePane(text: String, title: String, diffType: DiffType) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pane header
            HStack {
                Text(title)
                    .font(WernickeTypography.caption2Semibold)
                    .foregroundStyle(V4Color.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                HStack(spacing: ParietalSpacing.xs) {
                    Image(systemName: "text.alignleft")
                        .font(WernickeTypography.size9)
                    Text("\(text.components(separatedBy: .newlines).count) lines")
                        .font(WernickeTypography.size10)
                }
                .foregroundStyle(V4Color.textSecondary.opacity(V1Theme.opacityTextSecondary))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(V4Color.bgCard.opacity(V2Depth.stateDisabled))

            Divider()
                .background(V4Color.bgCardBorder)

            // Scrollable content with diff highlighting
            ScrollViewWithOffset(offset: $scrollOffset) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(diffLines(text: text, diffType: diffType).enumerated()), id: \.offset) { _, line in
                        diffLineView(line)
                    }
                }
                .padding(12)
            }
            .background(V4Color.bgWindow)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Diff Line View

    private struct DiffLine: Identifiable {
        let id = UUID()
        let text: String
        let type: LineType

        enum LineType {
            case unchanged
            case added
            case removed
        }
    }

    private func diffLines(text: String, diffType: DiffType) -> [DiffLine] {
        let lines = text.components(separatedBy: .newlines)

        // For new version: highlight additions from original
        // For original: highlight deletions (what's not in new)
        let originalLines = originalText.components(separatedBy: .newlines)
        let newLines = newText.components(separatedBy: .newlines)

        switch diffType {
        case .original:
            // Mark lines that were removed (exist in original but not in new)
            return lines.map { line in
                let wasRemoved = !newLines.contains(where: { $0 == line })
                return DiffLine(
                    text: line.isEmpty ? " " : line,
                    type: wasRemoved ? .removed : .unchanged
                )
            }
        case .new:
            // Mark lines that were added (exist in new but not in original)
            return lines.map { line in
                let wasAdded = !originalLines.contains(where: { $0 == line })
                return DiffLine(
                    text: line.isEmpty ? " " : line,
                    type: wasAdded ? .added : .unchanged
                )
            }
        }
    }

    private func diffLineView(_ line: DiffLine) -> some View {
        HStack(alignment: .top, spacing: ParietalSpacing.sm) {
            // Line indicator
            Group {
                switch line.type {
                case .unchanged:
                    Text(" ")
                case .added:
                    Text("+")
                        .foregroundStyle(V4Color.statusOK)
                case .removed:
                    Text("-")
                        .foregroundStyle(V4Color.statusError)
                }
            }
            .font(WernickeTypography.size11Mono)
            .frame(width: 12, alignment: .trailing)

            // Line content with background
            Text(line.text)
                .font(.system(size: V1Theme.chatFontSize, design: .monospaced))
                .foregroundStyle(foregroundFor(lineType: line.type))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(backgroundFor(lineType: line.type))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func foregroundFor(lineType: DiffLine.LineType) -> Color {
        switch lineType {
        case .unchanged:
            return V4Color.textPrimary
        case .added:
            return Color(hex: 0x00C853) // Slightly darker green for text
        case .removed:
            return Color(hex: 0xFF5252) // Slightly darker red for text
        }
    }

    private func backgroundFor(lineType: DiffLine.LineType) -> Color {
        switch lineType {
        case .unchanged:
            return Color.clear
        case .added:
            return Color(hex: 0x00FF88).opacity(V2Depth.bgSidebarHover)
        case .removed:
            return Color(hex: 0xEF4444).opacity(V2Depth.bgSidebarHover)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: ParietalSpacing.md) {
            Spacer()

            // Reject button
            Button {
                withAnimation(MTMotion.adaptiveStandardSpring()) {
                    onAccept = false
                    isPresented = false
                }
            } label: {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.caption2Semibold)
                    Text("Reject")
                        .font(WernickeTypography.captionMedium)
                }
                .foregroundStyle(V4Color.statusError)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(V4Color.statusError.opacity(V2Depth.bgSubtle))
                .cornerRadius(V1Theme.cornerMedium)
            }
            .buttonStyle(.plain)

            // Accept button
            Button {
                withAnimation(MTMotion.adaptiveStandardSpring()) {
                    onAccept = true
                    isPresented = false
                }
            } label: {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "checkmark")
                        .font(WernickeTypography.caption2Semibold)
                    Text("Accept")
                        .font(WernickeTypography.captionMedium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(V4Color.statusOK)
                .cornerRadius(V1Theme.cornerMedium)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(V4Color.bgCard)
    }
}

// MARK: - Synchronized Scrolling ScrollView

private struct ScrollViewWithOffset<Content: View>: View {
    @Binding var offset: CGFloat
    let content: Content

    init(offset: Binding<CGFloat>, @ViewBuilder content: () -> Content) {
        self._offset = offset
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geo.frame(in: .named("scroll")).minY
                        )
                    }
                )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            offset = value
        }
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview

struct MessageComparisonView_Previews: PreviewProvider {
    static var previews: some View {
        MessageComparisonView(
            isPresented: .constant(true),
            onAccept: .constant(false),
            originalText: """
            # Original Message

            This is the original content that was generated.
            It contains several lines of text.
            Some of this content will be modified.
            The green highlights show new additions.
            The red highlights show removed content.

            ```swift
            func originalFunction() {
                print("Hello, World!")
            }
            ```
            """,
            newText: """
            # Updated Message

            This is the original content that was generated.
            It contains several lines of text with modifications.
            Some of this content will be edited significantly.
            The green highlights show new additions.
            Blue highlights indicate unchanged sections.

            ```swift
            func updatedFunction() {
                print("Hello, Trinity!")
                // New comment added
            }
            ```

            Additional paragraph at the end.
            """,
            originalTitle: "Original",
            newTitle: "Regenerated"
        )
        .frame(width: 1000, height: 600)
    }
}
