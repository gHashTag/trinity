// Accordion View — Expandable/Collapsible Sections
import SwiftUI

// MARK: - Accordion Section

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
        VStack(spacing: 0) {
            // Header
            Button {
                guard !isDisabled else { return }
                withAnimation(animation) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    header()

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isDisabled ? TrinityTheme.textMuted : TrinityTheme.textPrimary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(animation, value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(TrinityTheme.bgCard)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            // Content
            if isExpanded {
                content()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(TrinityTheme.bgWindow.opacity(0.5))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(isDisabled ? TrinityTheme.bgCardBorder : TrinityTheme.accent.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Accordion section")
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }
}

// MARK: - Accordion Group

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
        VStack(spacing: 8) {
            ForEach(sections) { section in
                AccordionContent(section: section)
            }
        }
    }

    @ViewBuilder
    private func AccordionContent(section: AccordionItem) -> some View {
        let isExpanded = expandedSections.contains(section.id)

        VStack(spacing: 0) {
            Button {
                guard !section.isDisabled else { return }
                toggleSection(section.id)
            } label: {
                HStack(spacing: 12) {
                    // Icon
                    if let icon = section.icon {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundStyle(section.isDisabled ? TrinityTheme.textMuted : TrinityTheme.accent)
                            .frame(width: 24)
                    }

                    // Title and subtitle
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(section.isDisabled ? TrinityTheme.textMuted : TrinityTheme.textPrimary)

                        if let subtitle = section.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                    }

                    Spacer()

                    // Badge
                    if let badge = section.badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(TrinityTheme.accent)
                            .cornerRadius(4)
                    }

                    // Chevron
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(section.isDisabled ? TrinityTheme.textMuted : TrinityTheme.textPrimary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                        .fill(isExpanded ? TrinityTheme.accent.opacity(0.08) : TrinityTheme.bgCard)
                )
            }
            .buttonStyle(.plain)
            .disabled(section.isDisabled)

            // Expanded content
            if isExpanded {
                AnyView(section.content())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                            .fill(TrinityTheme.bgWindow.opacity(0.5))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(isExpanded ? TrinityTheme.accent.opacity(0.3) : TrinityTheme.bgCardBorder, lineWidth: 1)
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("This is the accordion content area.")
                    Text("You can put any view here.")
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            }
            .frame(width: 300)

            // Accordion group
            AccordionGroup(
                sections: [
                    .init(id: "1", title: "Getting Started", subtitle: "Learn the basics", icon: "book.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome to Trinity!")
                            Text("This is your first step.")
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                    },
                    .init(id: "2", title: "Advanced Features", subtitle: "Power user tools", icon: "gearshape.fill", badge: "New") {
                        Text("Advanced configuration options go here.")
                            .foregroundStyle(TrinityTheme.textMuted)
                    },
                    .init(id: "3", title: "Settings", subtitle: "Customize your experience", icon: "slider.horizontal.3") {
                        Text("Settings panel content.")
                            .foregroundStyle(TrinityTheme.textMuted)
                    },
                    .init(id: "4", title: "Disabled Section", isDisabled: true) {
                        Text("This section is disabled.")
                    }
                ],
                allowsMultipleExpansion: true
            )
            .frame(width: 400)
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
