//
// Superior Colliculus — Attention Orientation
// Unified accordion with consistent animations
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - Superior Colliculus Accordion

/// Superior Colliculus — Attention Orientation
///
/// The superior colliculus is involved in orienting attention and gaze.
/// It controls saccadic eye movements - rapid shifts of attention.
///
/// This component provides a unified accordion with:
/// - Consistent spring animations
/// - Keyboard accessibility
/// - Optional icons and badges
/// - Smooth expand/collapse transitions
public struct SuperiorColliculusAccordion<Content: View>: View {
    let title: String
    let icon: String?
    let subtitle: String?
    let badge: String?
    @Binding var isExpanded: Bool
    let content: Content
    let isDisabled: Bool

    public init(
        _ title: String,
        icon: String? = nil,
        subtitle: String? = nil,
        badge: String? = nil,
        isExpanded: Binding<Bool>,
        isDisabled: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.badge = badge
        self._isExpanded = isExpanded
        self.isDisabled = isDisabled
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                guard !isDisabled else { return }
                withAnimation(MTMotion.standardSpring) {
                    isExpanded.toggle()
                }
            } label: {
                headerContent
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            // Expanded content
            if isExpanded {
                content
                    .padding(.horizontal, ParietalSpacing.md)
                    .padding(.vertical, ParietalSpacing.sm)
                    .background(V4Color.surface.opacity(V2Depth.stateDisabled))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(isExpanded ? V4Color.borderFocus : V4Color.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .onKeyPress(.space) {
            guard !isDisabled else { return .ignored }
            withAnimation(MTMotion.standardSpring) {
                isExpanded.toggle()
            }
            return .handled
        }
    }

    @ViewBuilder
    private var headerContent: some View {
        HStack(spacing: ParietalSpacing.xs) {
            // Icon
            if let icon = icon {
                Image(systemName: icon)
                    .font(WernickeTypography.body16)
                    .foregroundStyle(isDisabled ? V4Color.textTertiary : V4Color.accent)
                    .frame(width: ParietalSpacing.iconLarge)
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: ParietalSpacing.xs / 2) {
                Text(title)
                    .font(WernickeTypography.small)
                    .foregroundStyle(isDisabled ? V4Color.textTertiary : V4Color.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(WernickeTypography.caption)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }

            Spacer()

            // Badge
            if let badge = badge {
                Text(badge)
                    .font(WernickeTypography.caption2Semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, ParietalSpacing.xxxs)
                    .padding(.vertical, 2)
                    .background(V4Color.accent)
                    .cornerRadius(V1Theme.cornerTiny)
            }

            // Chevron
            Image(systemName: "chevron.down")
                .font(WernickeTypography.caption2Semibold)
                .foregroundStyle(isDisabled ? V4Color.textTertiary : V4Color.textPrimary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .fill(isExpanded ? V4Color.selected : Color.clear)
        )
    }
}

// MARK: - Accordion Group

/// Group of accordions with coordinated expansion
public struct SuperiorColliculusGroup: View {
    let sections: [AccordionItem]
    @State private var expandedIDs: Set<String>
    let allowsMultipleExpansion: Bool
    let onExpandChange: ((String, Bool) -> Void)?

    public struct AccordionItem: Identifiable {
        public let id: String
        let title: String
        let subtitle: String?
        let icon: String?
        let badge: String?
        let isDisabled: Bool
        let content: () -> any View

        public init(
            id: String,
            title: String,
            subtitle: String? = nil,
            icon: String? = nil,
            badge: String? = nil,
            isDisabled: Bool = false,
            @ViewBuilder content: @escaping () -> any View
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.badge = badge
            self.isDisabled = isDisabled
            self.content = content
        }
    }

    public init(
        sections: [AccordionItem],
        allowsMultipleExpansion: Bool = false,
        initiallyExpanded: Set<String> = [],
        onExpandChange: ((String, Bool) -> Void)? = nil
    ) {
        self.sections = sections
        self.allowsMultipleExpansion = allowsMultipleExpansion
        self._expandedIDs = State(initialValue: initiallyExpanded)
        self.onExpandChange = onExpandChange
    }

    public var body: some View {
        VStack(spacing: ParietalSpacing.xs) {
            ForEach(sections) { section in
                accordionItem(section)
            }
        }
    }

    @ViewBuilder
    private func accordionItem(_ section: AccordionItem) -> some View {
        let isExpanded = expandedIDs.contains(section.id)

        VStack(spacing: 0) {
            Button {
                guard !section.isDisabled else { return }
                toggleSection(section.id)
            } label: {
                HStack(spacing: ParietalSpacing.xs) {
                    // Icon
                    if let icon = section.icon {
                        Image(systemName: icon)
                            .font(WernickeTypography.body16)
                            .foregroundStyle(section.isDisabled ? V4Color.textTertiary : V4Color.accent)
                            .frame(width: ParietalSpacing.iconLarge)
                    }

                    // Title and subtitle
                    VStack(alignment: .leading, spacing: ParietalSpacing.xs / 2) {
                        Text(section.title)
                            .font(WernickeTypography.small)
                            .foregroundStyle(section.isDisabled ? V4Color.textTertiary : V4Color.textPrimary)

                        if let subtitle = section.subtitle {
                            Text(subtitle)
                                .font(WernickeTypography.caption)
                                .foregroundStyle(V4Color.textSecondary)
                        }
                    }

                    Spacer()

                    // Badge
                    if let badge = section.badge {
                        Text(badge)
                            .font(WernickeTypography.caption2Semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, ParietalSpacing.xxxs)
                            .padding(.vertical, 2)
                            .background(V4Color.accent)
                            .cornerRadius(V1Theme.cornerTiny)
                    }

                    // Chevron
                    Image(systemName: "chevron.down")
                        .font(WernickeTypography.caption2Semibold)
                        .foregroundStyle(section.isDisabled ? V4Color.textTertiary : V4Color.textPrimary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                        .fill(isExpanded ? V4Color.selected : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .disabled(section.isDisabled)

            // Expanded content
            if isExpanded {
                AnyView(section.content())
                    .padding(.horizontal, ParietalSpacing.sm)
                    .padding(.vertical, ParietalSpacing.sm)
                    .background(V4Color.surface.opacity(V2Depth.stateDisabled))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(isExpanded ? V4Color.borderFocus : V4Color.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(section.title)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .onKeyPress(.space) {
            guard !section.isDisabled else { return .ignored }
            toggleSection(section.id)
            return .handled
        }
    }

    private func toggleSection(_ id: String) {
        withAnimation(MTMotion.standardSpring) {
            if expandedIDs.contains(id) {
                expandedIDs.remove(id)
                onExpandChange?(id, false)
            } else {
                if !allowsMultipleExpansion {
                    expandedIDs.removeAll()
                }
                expandedIDs.insert(id)
                onExpandChange?(id, true)
            }
        }
    }
}

// MARK: - Preview
// NOTE: Preview blocks removed for CLI build compatibility
