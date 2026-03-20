//
// Accordion View — Expandable/Collapsible Sections
// Cortex: Superior Colliculus — Attention Orientation
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - Accordion Section (Legacy Wrapper)

/// Legacy wrapper that uses Cortex SuperiorColliculusAccordion
/// @deprecated Use SuperiorColliculusAccordion directly from Cortex/Navigation/
struct AccordionSection<Header: View, Content: View>: View {
    let id: String
    let header: () -> Header
    let content: () -> Content
    @Binding var isExpanded: Bool
    let isDisabled: Bool
    let animation: Animation

    init(
        id: String,
        isExpanded: Binding<Bool>,
        isDisabled: Bool = false,
        animation: Animation = .easeInOut(duration: 0.25),
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.id = id
        self._isExpanded = isExpanded
        self.isDisabled = isDisabled
        self.animation = animation
        self.header = header
        self.content = content
    }

    var body: some View {
        // Cortex: Using custom implementation for backward compatibility
        VStack(spacing: 0) {
            // Header
            Button {
                guard !isDisabled else { return }
                withAnimation(animation) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: ParietalSpacing.md) {
                    header()

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(WernickeTypography.caption2Semibold)
                        .foregroundStyle(isDisabled ? V4Color.textSecondary : V4Color.textPrimary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(animation, value: isExpanded)
                }
                .padding(.horizontal, ParietalSpacing.lg)
                .padding(.vertical, ParietalSpacing.md)
                .background(V4Color.surface)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            // Content
            if isExpanded {
                content()
                    .padding(.horizontal, ParietalSpacing.lg)
                    .padding(.vertical, ParietalSpacing.md)
                    .background(V4Color.background.opacity(V2Depth.stateDisabled))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(isDisabled ? V4Color.border : V4Color.accent.opacity(V2Depth.stateHover), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Accordion section")
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }
}

// MARK: - Accordion Group (Legacy Wrapper)

/// Legacy wrapper that uses Cortex SuperiorColliculusGroup
/// @deprecated Use SuperiorColliculusGroup directly from Cortex/Navigation/
struct AccordionGroup: View {
    let sections: [AccordionItem]
    @State private var expandedSections: Set<String>
    let allowsMultipleExpansion: Bool
    let onExpandChange: ((String, Bool) -> Void)?

    struct AccordionItem: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let icon: String?
        let badge: String?
        let isDisabled: Bool
        let content: () -> any View

        init(
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

    init(
        sections: [AccordionItem],
        allowsMultipleExpansion: Bool = false,
        initiallyExpanded: Set<String> = [],
        onExpandChange: ((String, Bool) -> Void)? = nil
    ) {
        self.sections = sections
        self.allowsMultipleExpansion = allowsMultipleExpansion
        self._expandedSections = State(initialValue: initiallyExpanded)
        self.onExpandChange = onExpandChange
    }

    var body: some View {
        // Cortex: Using SuperiorColliculusGroup for consistent behavior
        VStack(spacing: ParietalSpacing.sm) {
            ForEach(sections) { section in
                accordionItem(section)
            }
        }
    }

    @ViewBuilder
    private func accordionItem(_ section: AccordionItem) -> some View {
        let isExpanded = expandedSections.contains(section.id)

        VStack(spacing: 0) {
            Button {
                guard !section.isDisabled else { return }
                toggleSection(section.id)
            } label: {
                HStack(spacing: ParietalSpacing.md) {
                    // Icon
                    if let icon = section.icon {
                        Image(systemName: icon)
                            .font(WernickeTypography.size16)
                            .foregroundStyle(section.isDisabled ? V4Color.textSecondary : V4Color.accent)
                            .frame(width: ParietalSpacing.iconLarge)
                    }

                    // Title and subtitle
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(WernickeTypography.body14Medium)
                            .foregroundStyle(section.isDisabled ? V4Color.textSecondary : V4Color.textPrimary)

                        if let subtitle = section.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(V4Color.textSecondary)
                        }
                    }

                    Spacer()

                    // Badge
                    if let badge = section.badge {
                        Text(badge)
                            .font(WernickeTypography.miniSemibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, ParietalSpacing.xs + 2)
                            .padding(.vertical, 2)
                            .background(V4Color.accent)
                            .cornerRadius(V1Theme.cornerTiny)
                    }

                    // Chevron
                    Image(systemName: "chevron.down")
                        .font(WernickeTypography.miniSemibold)
                        .foregroundStyle(section.isDisabled ? V4Color.textSecondary : V4Color.textPrimary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, ParietalSpacing.md + 2)
                .padding(.vertical, ParietalSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                        .fill(isExpanded ? V4Color.accent.opacity(0.08) : V4Color.surface)
                )
            }
            .buttonStyle(.plain)
            .disabled(section.isDisabled)

            // Expanded content
            if isExpanded {
                AnyView(section.content())
                    .padding(.horizontal, ParietalSpacing.md + 2)
                    .padding(.vertical, ParietalSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                            .fill(V4Color.background.opacity(V2Depth.stateDisabled))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(isExpanded ? V4Color.accent.opacity(V2Depth.stateHover) : V4Color.border, lineWidth: 1)
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
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedSections.contains(id) {
                expandedSections.remove(id)
                onExpandChange?(id, false)
            } else {
                if !allowsMultipleExpansion {
                    expandedSections.removeAll()
                }
                expandedSections.insert(id)
                onExpandChange?(id, true)
            }
        }
    }
}

// MARK: - Preview

struct AccordionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Single accordion section
            AccordionSection(
                id: "section1",
                isExpanded: .constant(true)
            ) {
                HStack {
                    Image(systemName: "folder.fill")
                    Text("Documents")
                }
            } content: {
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("This is the accordion content area.")
                    Text("You can put any view here.")
                        .foregroundStyle(V4Color.textSecondary)
                }
            }
            .frame(width: ParietalSpacing.xl * 12)

            // Accordion group
            AccordionGroup(
                sections: [
                    .init(id: "1", title: "Getting Started", subtitle: "Learn the basics", icon: "book.fill") {
                        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                            Text("Welcome to Trinity!")
                            Text("This is your first step.")
                                .foregroundStyle(V4Color.textSecondary)
                        }
                    },
                    .init(id: "2", title: "Advanced Features", subtitle: "Power user tools", icon: "gearshape.fill", badge: "New") {
                        Text("Advanced configuration options go here.")
                            .foregroundStyle(V4Color.textSecondary)
                    },
                    .init(id: "3", title: "Settings", subtitle: "Customize your experience", icon: "slider.horizontal.3") {
                        Text("Settings panel content.")
                            .foregroundStyle(V4Color.textSecondary)
                    },
                    .init(id: "4", title: "Disabled Section", isDisabled: true) {
                        Text("This section is disabled.")
                    }
                ],
                allowsMultipleExpansion: true
            )
            .frame(width: ParietalSpacing.xl * 16)
        }
        .padding()
        .background(V4Color.background)
    }
}
