import SwiftUI

// MARK: - Quick Reply Template Model

struct QuickReplyTemplate: Codable, Identifiable, Hashable {
    let id: UUID
    var text: String
    var category: TemplateCategory
    var order: Int
    var createdAt: Date

    init(id: UUID = UUID(), text: String, category: TemplateCategory = .custom, order: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.category = category
        self.order = order
        self.createdAt = createdAt
    }

    enum TemplateCategory: String, Codable, CaseIterable {
        case builtin = "builtin"
        case custom = "custom"

        var displayName: String {
            switch self {
            case .builtin: return "Built-in"
            case .custom: return "Custom"
            }
        }
    }
}

// MARK: - Template Storage Manager

@MainActor
class QuickReplyTemplateManager: ObservableObject {
    static let shared = QuickReplyTemplateManager()

    @AppStorage("quickReplyTemplates") private var templatesRaw: String = ""
    @AppStorage("quickReplyTemplatesVersion") private var version: Int = 1

    @Published private(set) var templates: [QuickReplyTemplate] = []

    private let defaultsKey = "quickReplyTemplates"

    // Built-in templates that cannot be deleted
    private let builtInTemplates: [QuickReplyTemplate] = [
        QuickReplyTemplate(text: "Continue", category: .builtin, order: 0),
        QuickReplyTemplate(text: "Explain more", category: .builtin, order: 1),
        QuickReplyTemplate(text: "Summarize", category: .builtin, order: 2),
        QuickReplyTemplate(text: "Code only", category: .builtin, order: 3),
        QuickReplyTemplate(text: "Critique this", category: .builtin, order: 4),
        QuickReplyTemplate(text: "Alternative approach", category: .builtin, order: 5),
    ]

    private var templatesURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let queenDir = appSupport.appendingPathComponent("QueenUI", isDirectory: true)
        try? FileManager.default.createDirectory(at: queenDir, withIntermediateDirectories: true)
        return queenDir.appendingPathComponent("quickreply_templates.json")
    }

    var customTemplates: [QuickReplyTemplate] {
        templates.filter { $0.category == .custom }.sorted { $0.order < $1.order }
    }

    var allTemplates: [QuickReplyTemplate] {
        templates.sorted { $0.order < $1.order }
    }

    var templateCount: Int {
        templates.count
    }

    var customCount: Int {
        customTemplates.count
    }

    private init() {
        loadTemplates()
    }

    func loadTemplates() {
        // Try loading from file first
        if let data = try? Data(contentsOf: templatesURL),
           let decoded = try? JSONDecoder().decode([QuickReplyTemplate].self, from: data) {
            templates = decoded
            return
        }

        // Fallback to AppStorage
        if !templatesRaw.isEmpty,
           let data = templatesRaw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([QuickReplyTemplate].self, from: data) {
            templates = decoded
        } else {
            // Initialize with built-in templates
            templates = builtInTemplates
            saveTemplates()
        }
    }

    func saveTemplates() {
        // Save to file
        if let encoded = try? JSONEncoder().encode(templates) {
            try? encoded.write(to: templatesURL)
        }

        // Also save to AppStorage as backup
        if let encoded = try? JSONEncoder().encode(templates),
           let json = String(data: encoded, encoding: .utf8) {
            templatesRaw = json
        }
    }

    func addTemplate(_ text: String) {
        let newTemplate = QuickReplyTemplate(
            text: text,
            category: .custom,
            order: templates.count
        )
        templates.append(newTemplate)
        saveTemplates()
    }

    func updateTemplate(_ template: QuickReplyTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            saveTemplates()
        }
    }

    func deleteTemplate(_ template: QuickReplyTemplate) {
        // Prevent deleting built-in templates
        guard template.category == .custom else { return }
        templates.removeAll { $0.id == template.id }
        reorderTemplates()
        saveTemplates()
    }

    func reorderTemplates() {
        for (index, _) in templates.enumerated() {
            templates[index].order = index
        }
    }

    func moveTemplate(from source: IndexSet, to destination: Int) {
        templates.move(fromOffsets: source, toOffset: destination)
        reorderTemplates()
        saveTemplates()
    }

    func resetToDefaults() {
        templates = builtInTemplates
        saveTemplates()
    }
}

// MARK: - Quick Reply Templates Bar

struct QuickReplyTemplatesBar: View {
    @StateObject private var manager = QuickReplyTemplateManager.shared
    @Binding var inputText: String
    @State private var showEditSheet = false
    @State private var editingTemplate: QuickReplyTemplate? = nil
    @State private var showAddSheet = false
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onTemplateSelected: ((String) -> Void)? = nil

    private var templates: [QuickReplyTemplate] {
        manager.allTemplates
    }

    var body: some View {
        VStack(spacing: 0) {
            // Template bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ParietalSpacing.sm) {
                    // Template count badge
                    templateCountBadge

                    // Template buttons
                    ForEach(templates) { template in
                        templateButton(for: template)
                    }

                    // Add custom template button
                    addTemplateButton

                    // Edit templates button
                    editTemplatesButton
                }
                .padding(.horizontal, ParietalSpacing.lg)
                .padding(.vertical, ParietalSpacing.sm + 2)
            }
            .background(
                V4Color.surface
                    .opacity(V1Theme.opacityTextSecondary)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 1),
                        alignment: .top
                    )
            )
        }
        .frame(height: isVisible ? 44 : 0)
        .opacity(isVisible ? 1 : 0)
        .animation(
            reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.8),
            value: isVisible
        )
        .sheet(isPresented: $showEditSheet) {
            TemplateEditSheet(
                manager: manager,
                isPresented: $showEditSheet
            )
        }
        .sheet(isPresented: $showAddSheet) {
            AddTemplateSheet(
                manager: manager,
                isPresented: $showAddSheet,
                onAdd: { text in
                    insertTemplate(text)
                }
            )
        }
        .onAppear {
            // Animate in from bottom
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.75)) {
                    isVisible = true
                }
            }
        }
    }

    // MARK: - Template Count Badge

    private var templateCountBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "text.bubble")
                .font(WernickeTypography.size9)
            Text("\(manager.templateCount)")
                .font(WernickeTypography.miniMedium)
        }
        .foregroundStyle(V4Color.textSecondary)
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .background(
            V4Color.textSecondary.opacity(V2Depth.bgSubtle)
        )
        .clipShape(SwiftUI.Capsule())
        .accessibilityLabel("Template count")
        .accessibilityValue("\(manager.templateCount) templates available")
        .accessibilityHint("Swipe left to see templates")
    }

    // MARK: - Template Button

    private func templateButton(for template: QuickReplyTemplate) -> some View {
        Button {
            insertTemplate(template.text)
        } label: {
            Text(template.text)
                .font(WernickeTypography.captionMedium)
                .foregroundStyle(template.category == .builtin ? V4Color.textPrimary : V4Color.accent)
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.xs + 2)
                .background(
                    template.category == .builtin
                        ? V4Color.border.opacity(V2Depth.stateDisabled)
                        : V4Color.accent.opacity(V2Depth.bgSubtle)
                )
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                        .stroke(
                            template.category == .builtin
                                ? V4Color.border.opacity(0.8)
                                : V4Color.accent.opacity(V2Depth.stateHover),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.text)
        .accessibilityHint("Insert '\(template.text)' into input field")
        .accessibilityAddTraits(.isButton)
        .onLongPressGesture(minimumDuration: 0.5) {
            if template.category == .custom {
                editingTemplate = template
                showEditSheet = true
            }
        }
    }

    // MARK: - Add Template Button

    private var addTemplateButton: some View {
        Button {
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(WernickeTypography.miniMedium)
                .foregroundStyle(V4Color.textSecondary)
                .padding(7)
                .background(
                    Circle()
                        .fill(V4Color.textSecondary.opacity(V2Depth.bgSubtle))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add custom template")
        .accessibilityHint("Create a new quick reply template")
    }

    // MARK: - Edit Templates Button

    private var editTemplatesButton: some View {
        Button {
            showEditSheet = true
        } label: {
            Image(systemName: "pencil")
                .font(WernickeTypography.miniMedium)
                .foregroundStyle(V4Color.textSecondary)
                .padding(7)
                .background(
                    Circle()
                        .fill(V4Color.textSecondary.opacity(V2Depth.bgSubtle))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit templates")
        .accessibilityHint("Manage custom templates")
    }

    // MARK: - Insert Template

    private func insertTemplate(_ text: String) {
        // Append to existing input with a space if needed
        if inputText.isEmpty {
            inputText = text
        } else {
            inputText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            inputText += " " + text
        }
        onTemplateSelected?(text)
    }
}

// MARK: - Template Edit Sheet

struct TemplateEditSheet: View {
    @ObservedObject var manager: QuickReplyTemplateManager
    @Binding var isPresented: Bool
    @State private var templates: [QuickReplyTemplate] = []
    @State private var editingTemplate: QuickReplyTemplate? = nil
    @State private var showEditAlert = false
    @State private var editedText = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Quick Reply Templates")
                    .font(WernickeTypography.size18Medium)
                    .foregroundStyle(V4Color.textPrimary)

                Spacer()

                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(WernickeTypography.size16)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(20)
            .background(V4Color.surface)

            Divider()
                .background(V4Color.border)

            // Template list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(templates) { template in
                        templateRow(for: template)
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    }
                }
            }
            .background(V4Color.background)

            Divider()
                .background(V4Color.border)

            // Footer actions
            HStack(spacing: ParietalSpacing.md) {
                Button {
                    manager.resetToDefaults()
                    templates = manager.allTemplates
                } label: {
                    Text("Reset to Defaults")
                        .font(WernickeTypography.smallMedium)
                        .foregroundStyle(V4Color.warning)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ParietalSpacing.md)
                        .background(V4Color.warning.opacity(V2Depth.bgSidebarHover))
                        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset all templates to defaults")

                Button { isPresented = false } label: {
                    Text("Done")
                        .font(WernickeTypography.smallSemibold)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ParietalSpacing.md)
                        .background(V4Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done")
            }
            .padding(20)
            .background(V4Color.surface)
        }
        .frame(width: ParietalSpacing.xxxlModalFrame, height: ParietalSpacing.extraLargeModalHeight)
        .background(V4Color.background)
        .onAppear {
            templates = manager.allTemplates
        }
        .alert("Edit Template", isPresented: $showEditAlert) {
            TextField("Template text", text: $editedText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                saveEditedTemplate()
            }
        } message: {
            Text("Enter the new text for this template")
        }
    }

    // MARK: - Template Row

    private func templateRow(for template: QuickReplyTemplate) -> some View {
        HStack(spacing: ParietalSpacing.md) {
            // Category indicator
            Circle()
                .fill(template.category == .builtin ? V4Color.textSecondary : V4Color.accent)
                .frame(width: ParietalSpacing.dotSize, height: 6)

            // Template text
            Text(template.text)
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.textPrimary)
                .lineLimit(2)

            Spacer()

            // Category badge
            Text(template.category.displayName)
                .font(WernickeTypography.miniMedium)
                .foregroundStyle(template.category == .builtin ? V4Color.textSecondary : V4Color.accent)
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.xs)
                .background(
                    (template.category == .builtin ? V4Color.textSecondary : V4Color.accent)
                        .opacity(V2Depth.bgSidebarHover)
                )
                .clipShape(SwiftUI.Capsule())

            // Actions
            HStack(spacing: ParietalSpacing.sm) {
                if template.category == .custom {
                    Button {
                        editingTemplate = template
                        editedText = template.text
                        showEditAlert = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(WernickeTypography.size11)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit template")

                    Button {
                        withAnimation {
                            templates.removeAll { $0.id == template.id }
                            manager.deleteTemplate(template)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(WernickeTypography.size11)
                            .foregroundStyle(V4Color.error)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete template")
                }
            }
        }
        .padding(.horizontal, ParietalSpacing.lg)
        .padding(.vertical, ParietalSpacing.md)
        .background(V4Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
        .padding(.horizontal, ParietalSpacing.lg)
        .padding(.vertical, ParietalSpacing.xs + 2)
    }

    // MARK: - Save Edited Template

    private func saveEditedTemplate() {
        guard var template = editingTemplate else { return }
        template.text = editedText
        manager.updateTemplate(template)
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        }
    }
}

// MARK: - Add Template Sheet

struct AddTemplateSheet: View {
    @ObservedObject var manager: QuickReplyTemplateManager
    @Binding var isPresented: Bool
    var onAdd: (String) -> Void = { _ in }

    @State private var templateText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Custom Template")
                    .font(WernickeTypography.size18Medium)
                    .foregroundStyle(V4Color.textPrimary)

                Spacer()

                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(WernickeTypography.size16)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(20)
            .background(V4Color.surface)

            Divider()
                .background(V4Color.border)

            // Content
            VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                // Input field
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("Template Text")
                        .font(WernickeTypography.smallMedium)
                        .foregroundStyle(V4Color.textSecondary)

                    TextField("e.g., 'Show me an example'", text: $templateText)
                        .textFieldStyle(.plain)
                        .font(WernickeTypography.size14)
                        .foregroundStyle(V4Color.textPrimary)
                        .padding(ParietalSpacing.md)
                        .background(V4Color.border.opacity(V2Depth.stateHover))
                        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
                        .overlay(
                            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                                .stroke(V4Color.border, lineWidth: 1)
                        )
                        .focused($focused)
                        .accessibilityLabel("Template text")
                        .accessibilityHint("Enter the text for your quick reply template")

                    if showError {
                        Text(errorMessage)
                            .font(WernickeTypography.size11)
                            .foregroundStyle(V4Color.error)
                    }
                }

                // Preview
                if !templateText.isEmpty {
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        Text("Preview")
                            .font(WernickeTypography.smallMedium)
                            .foregroundStyle(V4Color.textSecondary)

                        Text(templateText)
                            .font(WernickeTypography.captionMedium)
                            .foregroundStyle(V4Color.accent)
                            .padding(.horizontal, ParietalSpacing.md)
                            .padding(.vertical, ParietalSpacing.xs + 2)
                            .background(V4Color.accent.opacity(V2Depth.bgSubtle))
                            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                                    .stroke(V4Color.accent.opacity(V2Depth.stateHover), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(20)
            .background(V4Color.background)

            Spacer()

            Divider()
                .background(V4Color.border)

            // Actions
            HStack(spacing: ParietalSpacing.md) {
                Button { isPresented = false } label: {
                    Text("Cancel")
                        .font(WernickeTypography.smallMedium)
                        .foregroundStyle(V4Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ParietalSpacing.md)
                        .background(V4Color.border.opacity(V2Depth.stateHover))
                        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel")

                Button {
                    addTemplate()
                } label: {
                    Text("Add Template")
                        .font(WernickeTypography.smallSemibold)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ParietalSpacing.md)
                        .background(V4Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
                }
                .buttonStyle(.plain)
                .disabled(templateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Add template")
                .accessibilityHint(templateText.isEmpty ? "Enter template text first" : "")
            }
            .padding(20)
            .background(V4Color.surface)
        }
        .frame(width: ParietalSpacing.sheetWidth, height: ParietalSpacing.mediumModalFrame)
        .background(V4Color.background)
        .onAppear {
            focused = true
        }
    }

    // MARK: - Add Template

    private func addTemplate() {
        let trimmed = templateText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            showError = true
            errorMessage = "Template text cannot be empty"
            return
        }

        // Check for duplicates
        if manager.allTemplates.contains(where: { $0.text.lowercased() == trimmed.lowercased() }) {
            showError = true
            errorMessage = "This template already exists"
            return
        }

        // Check length limit
        if trimmed.count > 50 {
            showError = true
            errorMessage = "Template must be 50 characters or less"
            return
        }

        manager.addTemplate(trimmed)
        onAdd(trimmed)
        isPresented = false
    }
}

// MARK: - Slide In Animation Modifier

struct SlideInFromBottomModifier: ViewModifier {
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: isVisible ? 0 : 50)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.75)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func slideInFromBottom() -> some View {
        modifier(SlideInFromBottomModifier())
    }
}

// MARK: - Compact Template Bar (Alternative)

/// Compact version that can be placed inline with input field
struct CompactQuickReplyBar: View {
    @StateObject private var manager = QuickReplyTemplateManager.shared
    @Binding var inputText: String
    @State private var showAll = false

    var body: some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            ForEach(manager.allTemplates.prefix(5)) { template in
                compactButton(for: template)
            }

            if manager.templateCount > 5 {
                Button {
                    showAll = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(WernickeTypography.miniMedium)
                        .foregroundStyle(V4Color.textSecondary)
                        .padding(5)
                        .background(
                            Circle()
                                .fill(V4Color.textSecondary.opacity(V2Depth.bgSubtle))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More templates")
                .accessibilityHint("Show all \(manager.templateCount) templates")
            }
        }
        .sheet(isPresented: $showAll) {
            AllTemplatesSheet(inputText: $inputText, isPresented: $showAll)
        }
    }

    private func compactButton(for template: QuickReplyTemplate) -> some View {
        Button {
            if inputText.isEmpty {
                inputText = template.text
            } else {
                inputText = inputText.trimmingCharacters(in: .whitespaces) + " " + template.text
            }
        } label: {
            Text(template.text)
                .font(WernickeTypography.miniMedium)
                .foregroundStyle(template.category == .builtin ? V4Color.textPrimary : V4Color.accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.text)
        .accessibilityHint("Insert '\(template.text)' into input")
    }
}

// MARK: - All Templates Sheet

struct AllTemplatesSheet: View {
    @StateObject private var manager = QuickReplyTemplateManager.shared
    @Binding var inputText: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("All Quick Replies")
                    .font(WernickeTypography.size18Medium)
                    .foregroundStyle(V4Color.textPrimary)

                Spacer()

                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(WernickeTypography.size16)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(V4Color.surface)

            Divider()
                .background(V4Color.border)

            // Templates grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: ParietalSpacing.sm + 2) {
                    ForEach(manager.allTemplates) { template in
                        templateGridItem(for: template)
                    }
                }
                .padding(ParietalSpacing.lg)
            }
            .background(V4Color.background)
        }
        .frame(width: ParietalSpacing.wideSheetWidth, height: ParietalSpacing.wideSheetWidth)
        .background(V4Color.background)
    }

    private func templateGridItem(for template: QuickReplyTemplate) -> some View {
        Button {
            if inputText.isEmpty {
                inputText = template.text
            } else {
                inputText = inputText.trimmingCharacters(in: .whitespaces) + " " + template.text
            }
            isPresented = false
        } label: {
            Text(template.text)
                .font(WernickeTypography.captionMedium)
                .foregroundStyle(template.category == .builtin ? V4Color.textPrimary : V4Color.accent)
                .multilineTextAlignment(.center)
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(
                    template.category == .builtin
                        ? V4Color.border.opacity(V2Depth.stateDisabled)
                        : V4Color.accent.opacity(V2Depth.bgSubtle)
                )
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                        .stroke(
                            template.category == .builtin
                                ? V4Color.border.opacity(0.8)
                                : V4Color.accent.opacity(V2Depth.stateHover),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.text)
        .accessibilityHint("Insert into input field")
    }
}

// MARK: - Preview

#if DEBUG
struct QuickReplyTemplates_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            // Full bar
            QuickReplyTemplatesBar(inputText: .constant(""))

            Divider()
                .background(V4Color.border)

            // Compact bar
            HStack {
                Text("Compact:")
                    .foregroundStyle(V4Color.textSecondary)
                CompactQuickReplyBar(inputText: .constant(""))
            }
            .padding()

            // All templates sheet trigger
            Button("Show All Templates") {
                // Would trigger sheet
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(width: ParietalSpacing.extraWideSheet, height: ParietalSpacing.mediumModalFrame)
        .background(V4Color.background)
    }
}
#endif
