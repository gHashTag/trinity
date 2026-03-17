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
                .background(TrinityTheme.bgCardBorder)

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
                    .background(TrinityTheme.bgCardBorder)

                // Right: New version
                messagePane(
                    text: newText,
                    title: newTitle,
                    diffType: .new
                )
            }

            // Divider
            Divider()
                .background(TrinityTheme.bgCardBorder)

            // Action buttons
            actionButtons
        }
        .background(TrinityTheme.bgWindow)
        .frame(minWidth: 800, minHeight: 500)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TrinityTheme.accent)

                Text("Compare Versions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)
            }

            Spacer()

            Button {
                withAnimation(TrinityTheme.springAnimation()) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .buttonStyle(.plain)
            .onHover { isHovering in
                // Hover effect handled by system
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(TrinityTheme.bgCard)
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .textCase(.uppercase)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 9))
                    Text("\(text.components(separatedBy: .newlines).count) lines")
                        .font(.system(size: 10))
                }
                .foregroundStyle(TrinityTheme.textMuted.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(TrinityTheme.bgCard.opacity(0.5))

            Divider()
                .background(TrinityTheme.bgCardBorder)

            // Scrollable content with diff highlighting
            ScrollViewWithOffset(offset: $scrollOffset) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(diffLines(text: text, diffType: diffType).enumerated()), id: \.offset) { _, line in
                        diffLineView(line)
                    }
                }
                .padding(12)
            }
            .background(TrinityTheme.bgWindow)
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
        HStack(alignment: .top, spacing: 8) {
            // Line indicator
            Group {
                switch line.type {
                case .unchanged:
                    Text(" ")
                case .added:
                    Text("+")
                        .foregroundStyle(TrinityTheme.statusOK)
                case .removed:
                    Text("-")
                        .foregroundStyle(TrinityTheme.statusError)
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .frame(width: 12, alignment: .trailing)

            // Line content with background
            Text(line.text)
                .font(.system(size: TrinityTheme.chatFontSize, design: .monospaced))
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
            return TrinityTheme.textPrimary
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
            return Color(hex: 0x00FF88).opacity(0.15)
        case .removed:
            return Color(hex: 0xEF4444).opacity(0.15)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Spacer()

            // Reject button
            Button {
                withAnimation(TrinityTheme.springAnimation()) {
                    onAccept = false
                    isPresented = false
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Reject")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(TrinityTheme.statusError)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(TrinityTheme.statusError.opacity(0.1))
                .cornerRadius(TrinityTheme.cornerMedium)
            }
            .buttonStyle(.plain)

            // Accept button
            Button {
                withAnimation(TrinityTheme.springAnimation()) {
                    onAccept = true
                    isPresented = false
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Accept")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(TrinityTheme.statusOK)
                .cornerRadius(TrinityTheme.cornerMedium)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(TrinityTheme.bgCard)
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
