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
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(TrinityTheme.textPrimary)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            // Tab picker
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.rawValue) { t in
                    Button {
                        tab = t
                    } label: {
                        Text(t.rawValue)
                            .font(.system(size: 12, weight: tab == t ? .bold : .medium))
                            .foregroundStyle(tab == t ? .black : Color.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(tab == t ? TrinityTheme.accent : Color.white.opacity(0.06))
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
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
        .frame(width: 380, height: 500)
        .background(Color(hex: 0x0A0A0A))
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
        LazyVStack(spacing: 8) {
            // Active persona indicator
            if let active = selectedPersona {
                HStack(spacing: 8) {
                    Image(systemName: active.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(TrinityTheme.accent)
                    Text("Active: \(active.name)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TrinityTheme.accent)
                    Spacer()
                    Button("Clear") {
                        selectedPersona = nil
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(TrinityTheme.statusError)
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(TrinityTheme.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
            }

            // Built-in personas
            Text("BUILT-IN")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.3))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            ForEach(Persona.builtIn) { persona in
                personaRow(persona, isBuiltIn: true)
            }

            // Custom personas
            if !personas.isEmpty {
                Text("CUSTOM")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
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
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                    Text("Create Persona")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(TrinityTheme.accent)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func personaRow(_ persona: Persona, isBuiltIn: Bool) -> some View {
        let isActive = selectedPersona?.id == persona.id
        Button {
            selectedPersona = isActive ? nil : persona
        } label: {
            HStack(spacing: 10) {
                Image(systemName: persona.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isActive ? TrinityTheme.accent : Color.white.opacity(0.5))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(persona.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isActive ? TrinityTheme.accent : Color.white)
                    Text(String(persona.systemPrompt.prefix(60)))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .lineLimit(1)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(TrinityTheme.accent)
                }
            }
            .padding(10)
            .background(isActive ? TrinityTheme.accent.opacity(0.08) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
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
        LazyVStack(spacing: 8) {
            // Built-in templates by category
            let categories = Dictionary(grouping: PromptTemplate.builtIn, by: { $0.category })
            ForEach(Array(categories.keys).sorted(), id: \.self) { category in
                Text(category.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ForEach(categories[category] ?? []) { template in
                    templateRow(template)
                }
            }

            // Custom templates
            if !templates.isEmpty {
                Text("CUSTOM")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ForEach(templates) { template in
                    templateRow(template)
                }
            }

            // Add button
            Button {
                showAddTemplate = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                    Text("Create Template")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(TrinityTheme.purple)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
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
            HStack(spacing: 10) {
                Image(systemName: template.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.purple)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white)
                    Text(String(template.body.prefix(60)))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .lineLimit(1)
                    if !template.variables.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(template.variables, id: \.self) { v in
                                Text("{{\(v)}}")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(TrinityTheme.golden)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(TrinityTheme.golden.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
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
        VStack(spacing: 16) {
            Text(persona == nil ? "New Persona" : "Edit Persona")
                .font(.headline)
                .foregroundStyle(TrinityTheme.textPrimary)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            // Icon picker
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                ForEach(icons, id: \.self) { ic in
                    Button {
                        icon = ic
                    } label: {
                        Image(systemName: ic)
                            .font(.system(size: 18))
                            .foregroundStyle(icon == ic ? TrinityTheme.accent : Color.white.opacity(0.4))
                            .frame(width: 36, height: 36)
                            .background(icon == ic ? TrinityTheme.accent.opacity(0.15) : Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("System Prompt")
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextEditor(text: $systemPrompt)
                .font(.system(size: 12, design: .monospaced))
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Button("Cancel") { onDismiss() }
                    .foregroundStyle(Color.white.opacity(0.4))
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
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(TrinityTheme.accent)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(name.isEmpty || systemPrompt.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(Color(hex: 0x1A1A1A))
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
        VStack(spacing: 16) {
            Text("New Template")
                .font(.headline)
                .foregroundStyle(TrinityTheme.textPrimary)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("Category", selection: $category) {
                ForEach(categories, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)

            Text("Body (use {{variable}} for placeholders)")
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextEditor(text: $templateBody)
                .font(.system(size: 12, design: .monospaced))
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Button("Cancel") { onDismiss() }
                    .foregroundStyle(Color.white.opacity(0.4))
                    .buttonStyle(.plain)
                Spacer()
                Button("Save") {
                    let template = PromptTemplate(title: title, body: templateBody, category: category, icon: icon)
                    onSave(template)
                    onDismiss()
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(TrinityTheme.purple)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(title.isEmpty || templateBody.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(Color(hex: 0x1A1A1A))
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
                    .font(.system(size: 11))
                if let name = selectedPersona?.name {
                    Text(name)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(selectedPersona != nil ? TrinityTheme.accent : Color.white.opacity(0.5))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(selectedPersona != nil ? TrinityTheme.accent.opacity(0.12) : Color.white.opacity(0.06))
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
