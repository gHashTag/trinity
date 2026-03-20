import SwiftUI

// MARK: - Persona Library (H1 + H2 merged: Personas + Prompt Templates)

struct PersonaLibrary: View {
    @Binding var selectedPersona: Persona?
    @Binding var isPresented: Bool
    var onSelectTemplate: ((String) -> Void)? = nil

    @State private var personas: [Persona] = []
    @State private var templates: [PromptTemplate] = []
    @State private var showAddPersona = false
    @State private var showAddTemplate = false
    @State private var editingPersona: Persona? = nil
    @State private var tab: Tab = .personas

    enum Tab: String, CaseIterable {
        case personas = "Personas"
        case templates = "Templates"
    }

    private var personasURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("QueenUI/personas.json")
    }

    private var templatesURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("QueenUI/templates.json")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Presets")
                    .font(WernickeTypography.body16Bold)
                    .foregroundStyle(V4Color.textPrimary)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.size12)
                        .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                }
                .buttonStyle(.plain)
            }
            .padding(ParietalSpacing.lg)

            // Tab picker
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.rawValue) { t in
                    Button {
                        tab = t
                    } label: {
                        Text(t.rawValue)
                            .font(tab == t ? WernickeTypography.captionBold : WernickeTypography.captionMedium)
                            .foregroundStyle(tab == t ? .black : Color.white.opacity(V2Depth.stateDisabled))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ParietalSpacing.sm)
                            .background(tab == t ? V4Color.accent : Color.white.opacity(V2Depth.bgCard))
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, ParietalSpacing.lg)
            .padding(.bottom, 12)

            // Content
            ScrollView {
                switch tab {
                case .personas:
                    personasContent
                case .templates:
                    templatesContent
                }
            }
        }
        .frame(width: ParietalSpacing.xxlModalFrame, height: ParietalSpacing.extraLargeModalHeight)
        .background(V4Color.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            loadPersonas()
            loadTemplates()
        }
        .sheet(isPresented: $showAddPersona) {
            PersonaEditor(
                persona: editingPersona,
                onSave: { persona in
                    if let idx = personas.firstIndex(where: { $0.id == persona.id }) {
                        personas[idx] = persona
                    } else {
                        personas.append(persona)
                    }
                    savePersonas()
                    editingPersona = nil
                },
                onDismiss: {
                    editingPersona = nil
                    showAddPersona = false
                }
            )
        }
        .sheet(isPresented: $showAddTemplate) {
            TemplateEditor(
                onSave: { template in
                    templates.append(template)
                    saveTemplates()
                },
                onDismiss: { showAddTemplate = false }
            )
        }
    }

    // MARK: - Personas Tab

    @ViewBuilder
    private var personasContent: some View {
        LazyVStack(spacing: ParietalSpacing.sm) {
            // Active persona indicator
            if let active = selectedPersona {
                HStack(spacing: ParietalSpacing.sm) {
                    Image(systemName: active.icon)
                        .font(WernickeTypography.size14)
                        .foregroundStyle(V4Color.accent)
                    Text("Active: \(active.name)")
                        .font(WernickeTypography.captionBold)
                        .foregroundStyle(V4Color.accent)
                    Spacer()
                    Button("Clear") {
                        selectedPersona = nil
                    }
                    .font(WernickeTypography.miniBold)
                    .foregroundStyle(V4Color.error)
                    .buttonStyle(.plain)
                }
                .padding(ParietalSpacing.xs)
                .background(V4Color.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, ParietalSpacing.lg)
            }

            // Built-in personas
            Text("BUILT-IN")
                .font(WernickeTypography.microBold)
                .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ParietalSpacing.lg)
                .padding(.top, 8)

            ForEach(Persona.builtIn) { persona in
                personaRow(persona, isBuiltIn: true)
            }

            // Custom personas
            if !personas.isEmpty {
                Text("CUSTOM")
                    .font(WernickeTypography.microBold)
                    .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ParietalSpacing.lg)
                    .padding(.top, 8)

                ForEach(personas) { persona in
                    personaRow(persona, isBuiltIn: false)
                }
            }

            // Add button
            Button {
                editingPersona = nil
                showAddPersona = true
            } label: {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "plus.circle")
                        .font(WernickeTypography.size12)
                    Text("Create Persona")
                        .font(WernickeTypography.captionMedium)
                }
                .foregroundStyle(V4Color.accent)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, ParietalSpacing.sm + 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, ParietalSpacing.lg)
        }
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func personaRow(_ persona: Persona, isBuiltIn: Bool) -> some View {
        let isActive = selectedPersona?.id == persona.id
        Button {
            selectedPersona = isActive ? nil : persona
        } label: {
            HStack(spacing: ParietalSpacing.sm + 2) {
                Image(systemName: persona.icon)
                    .font(WernickeTypography.size16)
                    .foregroundStyle(isActive ? V4Color.accent : Color.white.opacity(V2Depth.stateDisabled))
                    .frame(width: ParietalSpacing.iconLarge)
                VStack(alignment: .leading, spacing: 2) {
                    Text(persona.name)
                        .font(WernickeTypography.smallMedium)
                        .foregroundStyle(isActive ? V4Color.accent : Color.white)
                    Text(String(persona.systemPrompt.prefix(60)))
                        .font(WernickeTypography.size10)
                        .foregroundStyle(V4Color.white35)
                        .lineLimit(1)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(WernickeTypography.size14)
                        .foregroundStyle(V4Color.accent)
                }
            }
            .padding(ParietalSpacing.xs)
            .background(isActive ? V4Color.accent.opacity(0.08) : Color.white.opacity(V2Depth.bgCardLight))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, ParietalSpacing.lg)
        .contextMenu {
            if !isBuiltIn {
                Button("Edit") {
                    editingPersona = persona
                    showAddPersona = true
                }
                Button("Delete", role: .destructive) {
                    personas.removeAll { $0.id == persona.id }
                    if selectedPersona?.id == persona.id { selectedPersona = nil }
                    savePersonas()
                }
            }
        }
    }

    // MARK: - Templates Tab

    @ViewBuilder
    private var templatesContent: some View {
        LazyVStack(spacing: ParietalSpacing.sm) {
            // Built-in templates by category
            let categories = Dictionary(grouping: PromptTemplate.builtIn, by: { $0.category })
            ForEach(Array(categories.keys).sorted(), id: \.self) { category in
                Text(category.uppercased())
                    .font(WernickeTypography.microBold)
                    .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ParietalSpacing.lg)
                    .padding(.top, 8)

                ForEach(categories[category] ?? []) { template in
                    templateRow(template)
                }
            }

            // Custom templates
            if !templates.isEmpty {
                Text("CUSTOM")
                    .font(WernickeTypography.microBold)
                    .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ParietalSpacing.lg)
                    .padding(.top, 8)

                ForEach(templates) { template in
                    templateRow(template)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                templates.removeAll { $0.id == template.id }
                                saveTemplates()
                            }
                        }
                }
            }

            // Add button
            Button {
                showAddTemplate = true
            } label: {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "plus.circle")
                        .font(WernickeTypography.size12)
                    Text("Create Template")
                        .font(WernickeTypography.captionMedium)
                }
                .foregroundStyle(V4Color.purple)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, ParietalSpacing.sm + 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, ParietalSpacing.lg)
        }
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func templateRow(_ template: PromptTemplate) -> some View {
        Button {
            let vars = template.variables
            if vars.isEmpty {
                onSelectTemplate?(template.body)
                isPresented = false
            } else {
                // Show variable substitution — for now, insert with placeholders
                onSelectTemplate?(template.body)
                isPresented = false
            }
        } label: {
            HStack(spacing: ParietalSpacing.sm + 2) {
                Image(systemName: template.icon)
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.purple)
                    .frame(width: ParietalSpacing.iconLarge)
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.title)
                        .font(WernickeTypography.smallMedium)
                        .foregroundStyle(Color.white)
                    Text(String(template.body.prefix(60)))
                        .font(WernickeTypography.size10)
                        .foregroundStyle(V4Color.white35)
                        .lineLimit(1)
                    if !template.variables.isEmpty {
                        HStack(spacing: ParietalSpacing.xs) {
                            ForEach(template.variables, id: \.self) { v in
                                varTextView(name: v)
                            }
                        }
                    }
                }
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .font(WernickeTypography.size12)
                    .foregroundStyle(V4Color.white20)
            }
            .padding(ParietalSpacing.xs)
            .background(Color.white.opacity(V2Depth.bgCardLight))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, ParietalSpacing.lg)
    }

    private func varTextView(name: String) -> some View {
        Text("{{\(name)}}")
            .font(WernickeTypography.size9Mono.weight(.medium))
            .foregroundStyle(V4Color.golden)
            .padding(.horizontal, ParietalSpacing.xs)
            .padding(.vertical, 1)
            .background(V4Color.golden.opacity(V2Depth.bgSubtle))
            .clipShape(SwiftUI.Capsule())
    }

    // MARK: - Persistence

    private func loadPersonas() {
        guard let data = try? Data(contentsOf: personasURL) else { return }
        personas = (try? JSONDecoder().decode([Persona].self, from: data)) ?? []
    }

    private func savePersonas() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(personas) {
            try? data.write(to: personasURL, options: .atomic)
        }
    }

    private func loadTemplates() {
        guard let data = try? Data(contentsOf: templatesURL) else { return }
        templates = (try? JSONDecoder().decode([PromptTemplate].self, from: data)) ?? []
    }

    private func saveTemplates() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(templates) {
            try? data.write(to: templatesURL, options: .atomic)
        }
    }
}

// MARK: - Persona Editor

struct PersonaEditor: View {
    let persona: Persona?
    let onSave: (Persona) -> Void
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var icon = "person.circle"
    @State private var systemPrompt = ""

    private let icons = ["person.circle", "crown.fill", "magnifyingglass.circle", "lock.shield",
                         "doc.text", "graduationcap", "brain.head.profile", "wrench.and.screwdriver",
                         "paintbrush", "chart.bar", "terminal", "globe"]

    var body: some View {
        VStack(spacing: ParietalSpacing.lg) {
            Text(persona == nil ? "New Persona" : "Edit Persona")
                .font(.headline)
                .foregroundStyle(V4Color.textPrimary)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            // Icon picker
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: ParietalSpacing.sm) {
                ForEach(icons, id: \.self) { ic in
                    Button {
                        icon = ic
                    } label: {
                        Image(systemName: ic)
                            .font(WernickeTypography.size18)
                            .foregroundStyle(icon == ic ? V4Color.accent : Color.white.opacity(V1Theme.opacityTextTertiary))
                            .frame(width: ParietalSpacing.cellFrame, height: ParietalSpacing.avatarLargeHeight)
                            .background(icon == ic ? V4Color.accent.opacity(V2Depth.bgSidebarHover) : Color.white.opacity(V2Depth.bgCard))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("System Prompt")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextEditor(text: $systemPrompt)
                .font(WernickeTypography.size12Mono)
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(V2Depth.bgCard))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Button("Cancel") { onDismiss() }
                    .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                    .buttonStyle(.plain)
                Spacer()
                Button("Save") {
                    var p = persona ?? Persona(name: name, icon: icon, systemPrompt: systemPrompt)
                    if persona != nil {
                        p = Persona(name: name, icon: icon, systemPrompt: systemPrompt)
                    }
                    onSave(p)
                    onDismiss()
                }
                .font(WernickeTypography.smallBold)
                .foregroundStyle(.black)
                .padding(.horizontal, ParietalSpacing.lg)
                .padding(.vertical, ParietalSpacing.sm)
                .background(V4Color.accent)
                .clipShape(SwiftUI.Capsule())
                .buttonStyle(.plain)
                .disabled(name.isEmpty || systemPrompt.isEmpty)
            }
        }
        .padding(ParietalSpacing.xl)
        .frame(width: ParietalSpacing.xlModalFrame)
        .background(V4Color.surfaceElevated)
        .onAppear {
            if let p = persona {
                name = p.name
                icon = p.icon
                systemPrompt = p.systemPrompt
            }
        }
    }
}

// MARK: - Template Editor

struct TemplateEditor: View {
    let onSave: (PromptTemplate) -> Void
    let onDismiss: () -> Void

    @State private var title = ""
    @State private var templateBody = ""
    @State private var category = "Code"
    @State private var icon = "doc.text"

    private let categories = ["Code", "Debug", "Design", "Docs", "Git", "Other"]

    var body: some View {
        VStack(spacing: ParietalSpacing.lg) {
            Text("New Template")
                .font(.headline)
                .foregroundStyle(V4Color.textPrimary)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("Category", selection: $category) {
                ForEach(categories, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)

            Text("Body (use {{variable}} for placeholders)")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextEditor(text: $templateBody)
                .font(WernickeTypography.size12Mono)
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(V2Depth.bgCard))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Button("Cancel") { onDismiss() }
                    .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                    .buttonStyle(.plain)
                Spacer()
                Button("Save") {
                    let template = PromptTemplate(title: title, body: templateBody, category: category, icon: icon)
                    onSave(template)
                    onDismiss()
                }
                .font(WernickeTypography.smallBold)
                .foregroundStyle(.black)
                .padding(.horizontal, ParietalSpacing.lg)
                .padding(.vertical, ParietalSpacing.sm)
                .background(V4Color.purple)
                .clipShape(SwiftUI.Capsule())
                .buttonStyle(.plain)
                .disabled(title.isEmpty || templateBody.isEmpty)
            }
        }
        .padding(ParietalSpacing.xl)
        .frame(width: ParietalSpacing.xlModalFrame)
        .background(V4Color.surfaceElevated)
    }
}

// MARK: - Persona Picker (compact dropdown for input bar)

struct PersonaPicker: View {
    @Binding var selectedPersona: Persona?
    @Binding var showLibrary: Bool

    var body: some View {
        Menu {
            Button {
                selectedPersona = nil
            } label: {
                HStack {
                    Text("Default (Queen CTO)")
                    if selectedPersona == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            Divider()
            ForEach(Persona.builtIn) { persona in
                Button {
                    selectedPersona = persona
                } label: {
                    HStack {
                        Image(systemName: persona.icon)
                        Text(persona.name)
                        if selectedPersona?.id == persona.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Button {
                showLibrary = true
            } label: {
                HStack {
                    Image(systemName: "tray.full")
                    Text("All Presets...")
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: selectedPersona?.icon ?? "crown.fill")
                    .font(WernickeTypography.size11)
                if let name = selectedPersona?.name {
                    Text(name)
                        .font(WernickeTypography.miniMedium)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(selectedPersona != nil ? V4Color.accent : Color.white.opacity(V2Depth.stateDisabled))
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, 5)
            .background(selectedPersona != nil ? V4Color.accent.opacity(0.12) : Color.white.opacity(V2Depth.bgCard))
            .clipShape(SwiftUI.Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Select persona, currently \(selectedPersona?.name ?? "Default")")
        .accessibilityHint("Opens persona selection menu")
    }
}
