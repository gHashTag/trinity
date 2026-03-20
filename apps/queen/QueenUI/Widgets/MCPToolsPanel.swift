// MCP Tools Panel — Trinity MCP Server Tools
import SwiftUI

struct MCPToolsPanel: View {
    @State private var isExpanded = false
    @State private var selectedCategory: String? = nil
    @State private var toolOutput = ""
    @State private var isRunning = false

    private let quickTools: [(name: String, icon: String, tool: String)] = [
        ("sacred", "sparkles", "sacred_constants"),
        ("math", "function", "math_eval"),
        ("git", "arrow.triangle.branch", "git_status"),
        ("search", "magnifyingglass", "search_code"),
        ("format", "text.alignleft", "format_zig"),
    ]

    private let categories: [(name: String, icon: String, color: Color)] = [
        ("Sacred", "sparkles", V4Color.accent),
        ("Math", "function", V4Color.purple),
        ("Git", "arrow.triangle.branch", V4Color.error),
        ("Code", "chevron.left.square", V4Color.info),
        ("Docs", "doc.text", V4Color.success),
        ("File", "doc", V4Color.warning),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            if isExpanded {
                Divider()

                // Quick tools row
                quickToolsRow

                Divider()

                // Category filter
                categoryFilter

                Divider()

                // Tools list
                toolsList

                // Output panel (shown when there's output)
                if !toolOutput.isEmpty {
                    outputPanel
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        Button(action: {
            withAnimation(MTMotion.quickSpring) {
                isExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: "cube.fill")
                    .font(WernickeTypography.size11)
                    .foregroundColor(V4Color.info)

                Text("MCP Tools")
                    .font(WernickeTypography.caption2Semibold)
                    .foregroundColor(V4Color.textPrimary)

                Spacer()

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(V4Color.accent)
                }

                Image(systemName: "chevron.right")
                    .font(WernickeTypography.miniSemibold)
                    .foregroundColor(V4Color.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, ParietalSpacing.sm + 2)
            .padding(.vertical, ParietalSpacing.xs + 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Tools Row

    private var quickToolsRow: some View {
        HStack(spacing: ParietalSpacing.xs) {
            ForEach(quickTools, id: \.name) { tool in
                QuickToolButton(icon: tool.icon, isRunning: isRunning) {
                    executeTool(tool.tool)
                }
            }
        }
        .padding(.horizontal, ParietalSpacing.xs + 2)
        .padding(.vertical, ParietalSpacing.xs)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ParietalSpacing.xs) {
                ForEach(categories, id: \.name) { category in
                    CategoryButton(
                        name: category.name,
                        icon: category.icon,
                        color: category.color,
                        isSelected: selectedCategory == category.name
                    ) {
                        withAnimation {
                            selectedCategory = selectedCategory == category.name ? nil : category.name
                        }
                    }
                }
            }
            .padding(.horizontal, ParietalSpacing.xs + 2)
        }
        .padding(.vertical, ParietalSpacing.xs)
    }

    // MARK: - Tools List

    private var toolsList: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(getToolsForCategory(selectedCategory), id: \.name) { tool in
                    ToolButton(
                        name: tool.name,
                        desc: tool.desc,
                        isRunning: isRunning
                    ) {
                        executeTool(tool.name)
                    }
                }
            }
        }
    }

    // MARK: - Output Panel

    private var outputPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Output")
                    .font(WernickeTypography.miniMedium)
                    .foregroundColor(V4Color.textSecondary)

                Spacer()

                Button(action: {
                    withAnimation {
                        toolOutput = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(WernickeTypography.size9)
                        .foregroundColor(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xs)
            .background(V4Color.border.opacity(V2Depth.stateHover))

            ScrollView {
                Text(toolOutput)
                    .font(WernickeTypography.size10Mono)
                    .foregroundColor(V4Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(ParietalSpacing.sm)
            }
            .frame(maxHeight: 120)
            .background(V4Color.surface.opacity(V2Depth.stateDisabled))
        }
    }

    // MARK: - Tool Execution

    private func executeTool(_ tool: String) {
        isRunning = true
        toolOutput = "Calling \(tool)..."

        Task {
            // Simulate MCP tool call
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            await MainActor.run {
                isRunning = false
                toolOutput = simulateToolOutput(tool)
            }
        }
    }

    private func simulateToolOutput(_ tool: String) -> String {
        switch tool {
        case "sacred_constants":
            return """
            φ = 1.618033988749895
            π = 3.141592653589793
            e = 2.718281828459045
            φ² + 1/φ² = 3 ✓
            """
        case "math_eval":
            return "42 + 42 = 84"
        case "git_status":
            return "On branch main\nYour branch is up to date with 'origin/main'.\n\nnothing to commit, working tree clean"
        default:
            return "\(tool): result placeholder"
        }
    }

    private func getToolsForCategory(_ category: String?) -> [(name: String, desc: String)] {
        if let cat = category {
            switch cat {
            case "Sacred":
                return [
                    ("sacred_constants", "φ, π, e constants"),
                    ("phi_power", "φ^n for any n"),
                    ("fibonacci", "Fibonacci numbers"),
                    ("sacred_proof", "Verify sacred identities"),
                ]
            case "Math":
                return [
                    ("math_eval", "Evaluate expression"),
                    ("matrix_ops", "Matrix operations"),
                    ("vector_calc", "Vector math"),
                    ("stats", "Statistical functions"),
                ]
            case "Git":
                return [
                    ("git_status", "Repo status"),
                    ("git_diff", "Show changes"),
                    ("git_log", "Commit history"),
                    ("git_blame", "Line annotations"),
                ]
            case "Code":
                return [
                    ("search_code", "Search in codebase"),
                    ("find_refs", "Find references"),
                    ("code_ast", "AST traversal"),
                    ("format_zig", "Format Zig code"),
                ]
            case "Docs":
                return [
                    ("search_docs", "Search docs"),
                    ("gen_doc", "Generate docs"),
                    ("doc_ast", "Doc AST view"),
                    ("cross_ref", "Cross references"),
                ]
            case "File":
                return [
                    ("read_file", "Read file"),
                    ("write_file", "Write file"),
                    ("list_dir", "List directory"),
                    ("file_info", "File metadata"),
                ]
            default:
                return []
            }
        }
        return [
            ("sacred_constants", "φ, π, e constants"),
            ("math_eval", "Evaluate expression"),
            ("git_status", "Repo status"),
            ("search_code", "Search codebase"),
            ("format_zig", "Format Zig code"),
        ]
    }
}

// MARK: - Quick Tool Button

struct QuickToolButton: View {
    let icon: String
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white)
                } else {
                    Image(systemName: icon)
                        .font(WernickeTypography.size11)
                }
            }
            .frame(width: ParietalSpacing.smallIconFrame, height: ParietalSpacing.smallButtonHeight)
            .background(isRunning ? V4Color.info : V4Color.border.opacity(V1Theme.opacityTextTertiary))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    let name: String
    let desc: String
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: "chevron.right")
                    .font(WernickeTypography.size7)
                    .foregroundColor(V4Color.textSecondary.opacity(V2Depth.stateDisabled))

                VStack(alignment: .leading, spacing: ParietalSpacing.xxxxs) {
                    Text(name)
                        .font(WernickeTypography.miniMedium)
                        .foregroundColor(V4Color.textPrimary)

                    Text(desc)
                        .font(WernickeTypography.size8)
                        .foregroundColor(V4Color.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.5)
                        .tint(V4Color.info)
                }
            }
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xs)
            .background(V4Color.border.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
