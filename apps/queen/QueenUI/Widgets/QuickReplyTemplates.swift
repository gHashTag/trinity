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
                HStack(spacing: 8) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(
                TrinityTheme.bgCard
                    .opacity(0.6)
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
                .font(.system(size: 9))
            Text("\(manager.templateCount)")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(TrinityTheme.textMuted)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            TrinityTheme.textMuted.opacity(0.1)
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
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(template.category == .builtin ? TrinityTheme.textPrimary : TrinityTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    template.category == .builtin
                        ? TrinityTheme.bgCardBorder.opacity(0.5)
                        : TrinityTheme.accent.opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                        .stroke(
                            template.category == .builtin
                                ? TrinityTheme.bgCardBorder.opacity(0.8)
                                : TrinityTheme.accent.opacity(0.3),
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
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TrinityTheme.textMuted)
                .padding(7)
                .background(
                    Circle()
                        .fill(TrinityTheme.textMuted.opacity(0.1))
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
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TrinityTheme.textMuted)
                .padding(7)
                .background(
                    Circle()
                        .fill(TrinityTheme.textMuted.opacity(0.1))
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
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(TrinityTheme.textPrimary)

                Spacer()

                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(20)
            .background(TrinityTheme.bgCard)

            Divider()
                .background(TrinityTheme.bgCardBorder)

            // Template list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(templates) { template in
                        templateRow(for: template)
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    }
                }
            }
            .background(TrinityTheme.bgWindow)

            Divider()
                .background(TrinityTheme.bgCardBorder)

            // Footer actions
            HStack(spacing: 12) {
                Button {
                    manager.resetToDefaults()
                    templates = manager.allTemplates
                } label: {
                    Text("Reset to Defaults")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TrinityTheme.statusWarn)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(TrinityTheme.statusWarn.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset all templates to defaults")

                Button { isPresented = false } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(TrinityTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done")
            }
            .padding(20)
            .background(TrinityTheme.bgCard)
        }
        .frame(width: 480, height: 500)
        .background(TrinityTheme.bgWindow)
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
        HStack(spacing: 12) {
            // Category indicator
            Circle()
                .fill(template.category == .builtin ? TrinityTheme.textMuted : TrinityTheme.accent)
                .frame(width: 6, height: 6)

            // Template text
            Text(template.text)
                .font(.system(size: 14))
                .foregroundStyle(TrinityTheme.textPrimary)
                .lineLimit(2)

            Spacer()

            // Category badge
            Text(template.category.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(template.category == .builtin ? TrinityTheme.textMuted : TrinityTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (template.category == .builtin ? TrinityTheme.textMuted : TrinityTheme.accent)
                        .opacity(0.15)
                )
                .clipShape(SwiftUI.Capsule())

            // Actions
            HStack(spacing: 8) {
                if template.category == .custom {
                    Button {
                        editingTemplate = template
                        editedText = template.text
                        showEditAlert = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(TrinityTheme.textMuted)
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
                            .font(.system(size: 11))
                            .foregroundStyle(TrinityTheme.statusError)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete template")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
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
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(TrinityTheme.textPrimary)

                Spacer()

                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(20)
            .background(TrinityTheme.bgCard)

            Divider()
                .background(TrinityTheme.bgCardBorder)

            // Content
            VStack(spacing: 20) {
                // Input field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Template Text")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TrinityTheme.textMuted)

                    TextField("e.g., 'Show me an example'", text: $templateText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(TrinityTheme.textPrimary)
                        .padding(12)
                        .background(TrinityTheme.bgCardBorder.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium))
                        .overlay(
                            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
                        )
                        .focused($focused)
                        .accessibilityLabel("Template text")
                        .accessibilityHint("Enter the text for your quick reply template")

                    if showError {
                        Text(errorMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(TrinityTheme.statusError)
                    }
                }

                // Preview
                if !templateText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TrinityTheme.textMuted)

                        Text(templateText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TrinityTheme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(TrinityTheme.accent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                                    .stroke(TrinityTheme.accent.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(20)
            .background(TrinityTheme.bgWindow)

            Spacer()

            Divider()
                .background(TrinityTheme.bgCardBorder)

            // Actions
            HStack(spacing: 12) {
                Button { isPresented = false } label: {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TrinityTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(TrinityTheme.bgCardBorder.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel")

                Button {
                    addTemplate()
                } label: {
                    Text("Add Template")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(TrinityTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium))
                }
                .buttonStyle(.plain)
                .disabled(templateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Add template")
                .accessibilityHint(templateText.isEmpty ? "Enter template text first" : "")
            }
            .padding(20)
            .background(TrinityTheme.bgCard)
        }
        .frame(width: 400, height: 300)
        .background(TrinityTheme.bgWindow)
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
        HStack(spacing: 6) {
            ForEach(manager.allTemplates.prefix(5)) { template in
                compactButton(for: template)
            }

            if manager.templateCount > 5 {
                Button {
                    showAll = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(TrinityTheme.textMuted)
                        .padding(5)
                        .background(
                            Circle()
                                .fill(TrinityTheme.textMuted.opacity(0.1))
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
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(template.category == .builtin ? TrinityTheme.textPrimary : TrinityTheme.accent)
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
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(TrinityTheme.textPrimary)

                Spacer()

                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(TrinityTheme.bgCard)

            Divider()
                .background(TrinityTheme.bgCardBorder)

            // Templates grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(manager.allTemplates) { template in
                        templateGridItem(for: template)
                    }
                }
                .padding(16)
            }
            .background(TrinityTheme.bgWindow)
        }
        .frame(width: 500, height: 400)
        .background(TrinityTheme.bgWindow)
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
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(template.category == .builtin ? TrinityTheme.textPrimary : TrinityTheme.accent)
                .multilineTextAlignment(.center)
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(
                    template.category == .builtin
                        ? TrinityTheme.bgCardBorder.opacity(0.5)
                        : TrinityTheme.accent.opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                        .stroke(
                            template.category == .builtin
                                ? TrinityTheme.bgCardBorder.opacity(0.8)
                                : TrinityTheme.accent.opacity(0.3),
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
        VStack(spacing: 20) {
            // Full bar
            QuickReplyTemplatesBar(inputText: .constant(""))

            Divider()
                .background(TrinityTheme.bgCardBorder)

            // Compact bar
            HStack {
                Text("Compact:")
                    .foregroundStyle(TrinityTheme.textMuted)
                CompactQuickReplyBar(inputText: .constant(""))
            }
            .padding()

            // All templates sheet trigger
            Button("Show All Templates") {
                // Would trigger sheet
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(width: 600, height: 300)
        .background(TrinityTheme.bgWindow)
    }
}
#endif
