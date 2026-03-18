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
        ("Sacred", "sparkles", TrinityTheme.accent),
        ("Math", "function", Color(hex: 0xA78BFA)),
        ("Git", "arrow.triangle.branch", Color(hex: 0xF05033)),
        ("Code", "chevron.left.square", Color(hex: 0x38BDF8)),
        ("Docs", "doc.text", Color(hex: 0x4ADE80)),
        ("File", "doc", Color(hex: 0xFBBF24)),
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
            withAnimation(TrinityTheme.quickSpring()) {
                isExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: "cube.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0x38BDF8))

                Text("MCP Tools")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(TrinityTheme.textPrimary)

                Spacer()

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(TrinityTheme.accent)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(TrinityTheme.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Tools Row

    private var quickToolsRow: some View {
        HStack(spacing: 4) {
            ForEach(quickTools, id: \.name) { tool in
                QuickToolButton(icon: tool.icon, isRunning: isRunning) {
                    executeTool(tool.tool)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
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
            .padding(.horizontal, 6)
        }
        .padding(.vertical, 4)
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
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(TrinityTheme.textMuted)

                Spacer()

                Button(action: {
                    withAnimation {
                        toolOutput = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TrinityTheme.bgCardBorder.opacity(0.3))

            ScrollView {
                Text(toolOutput)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(TrinityTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 120)
            .background(TrinityTheme.bgCard.opacity(0.5))
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
                        .font(.system(size: 11))
                }
            }
            .frame(width: 28, height: 28)
            .background(isRunning ? Color(hex: 0x38BDF8) : TrinityTheme.bgCardBorder.opacity(0.4))
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
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 7))
                    .foregroundColor(TrinityTheme.textMuted.opacity(0.5))

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(TrinityTheme.textPrimary)

                    Text(desc)
                        .font(.system(size: 8))
                        .foregroundColor(TrinityTheme.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.5)
                        .tint(Color(hex: 0x38BDF8))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TrinityTheme.bgCardBorder.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
