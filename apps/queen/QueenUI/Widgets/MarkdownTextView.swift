import SwiftUI
import AppKit

struct MarkdownTextView: View {
    let text: String
    var citations: [Citation]? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    private enum Block {
        case paragraph(String)
        case heading(Int, String)      // level, text
        case code(String, String?)     // code, language
        case diff(String)              // diff block with +/- lines
        case callout(CalloutType, String) // info/warning/error callout
        case listItem(String)
        case table([[String]])         // rows of cells (first row = header)
        case image(String, String)     // alt, url
        case math(String)              // block math ($$...$$)
        case horizontalRule
        case empty
    }

    enum CalloutType {
        case info, warning, error, tip, note

        var color: Color {
            switch self {
            case .info: return TrinityTheme.accent
            case .warning: return TrinityTheme.statusWarn
            case .error: return TrinityTheme.statusError
            case .tip: return TrinityTheme.purple
            case .note: return Color.white.opacity(0.4)
            }
        }

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            case .tip: return "lightbulb.fill"
            case .note: return "note.text"
            }
        }
    }

    private var blocks: [Block] {
        var result: [Block] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        var inCodeBlock = false
        var codeLines: [String] = []
        var codeLang: String?

        while i < lines.count {
            let line = lines[i]

            // Block math: $$...$$ (single line or multi-line)
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("$$") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Single-line block math: $$formula$$
                if trimmed.hasSuffix("$$") && trimmed.count > 4 {
                    let math = String(trimmed.dropFirst(2).dropLast(2))
                    result.append(.math(math))
                    i += 1
                    continue
                }
                // Multi-line block math
                var mathLines: [String] = []
                let firstLine = String(trimmed.dropFirst(2))
                if !firstLine.isEmpty { mathLines.append(firstLine) }
                i += 1
                while i < lines.count {
                    let ml = lines[i]
                    if ml.trimmingCharacters(in: .whitespaces).hasSuffix("$$") {
                        let last = ml.trimmingCharacters(in: .whitespaces)
                        let content = String(last.dropLast(2))
                        if !content.isEmpty { mathLines.append(content) }
                        i += 1
                        break
                    }
                    mathLines.append(ml)
                    i += 1
                }
                result.append(.math(mathLines.joined(separator: "\n")))
                continue
            }

            // Code block fence
            if line.hasPrefix("```") {
                if inCodeBlock {
                    let content = codeLines.joined(separator: "\n")
                    // Diff blocks get special rendering
                    if codeLang?.lowercased() == "diff" {
                        result.append(.diff(content))
                    } else {
                        result.append(.code(content, codeLang))
                    }
                    codeLines = []
                    codeLang = nil
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                    let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeLang = lang.isEmpty ? nil : lang
                }
                i += 1
                continue
            }

            if inCodeBlock {
                codeLines.append(line)
                i += 1
                continue
            }

            // Empty line
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                result.append(.empty)
                i += 1
                continue
            }

            // Horizontal rule (---, ***, ___)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.count >= 3 && (trimmed.allSatisfy({ $0 == "-" }) || trimmed.allSatisfy({ $0 == "*" }) || trimmed.allSatisfy({ $0 == "_" })) {
                result.append(.horizontalRule)
                i += 1
                continue
            }

            // Image: ![alt](url)
            if let imgMatch = extractImage(line) {
                result.append(.image(imgMatch.alt, imgMatch.url))
                i += 1
                continue
            }

            // Table detection: line with | separators
            if line.contains("|") && i + 1 < lines.count && isTableSeparator(lines[i + 1]) {
                var tableRows: [[String]] = []
                // Header
                tableRows.append(parseTableRow(line))
                i += 1 // skip separator line
                i += 1
                // Body rows
                while i < lines.count && lines[i].contains("|") {
                    tableRows.append(parseTableRow(lines[i]))
                    i += 1
                }
                result.append(.table(tableRows))
                continue
            }

            // Heading
            if line.hasPrefix("### ") {
                result.append(.heading(3, String(line.dropFirst(4))))
                i += 1
                continue
            }
            if line.hasPrefix("## ") {
                result.append(.heading(2, String(line.dropFirst(3))))
                i += 1
                continue
            }
            if line.hasPrefix("# ") {
                result.append(.heading(1, String(line.dropFirst(2))))
                i += 1
                continue
            }

            // List item
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("\u{2022} ") {
                result.append(.listItem(String(line.dropFirst(2))))
                i += 1
                continue
            }
            // Numbered list
            if let range = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                result.append(.listItem(String(line[range.upperBound...])))
                i += 1
                continue
            }

            // Callout: > **ERROR**: ..., > **WARNING**: ..., > **INFO**: ..., > **TIP**: ..., > **NOTE**: ...
            if trimmed.hasPrefix("> ") {
                let content = String(trimmed.dropFirst(2))
                if let callout = parseCallout(content) {
                    // Collect multi-line blockquote
                    var fullText = callout.text
                    i += 1
                    while i < lines.count {
                        let nextLine = lines[i].trimmingCharacters(in: .whitespaces)
                        if nextLine.hasPrefix("> ") {
                            fullText += "\n" + String(nextLine.dropFirst(2))
                            i += 1
                        } else {
                            break
                        }
                    }
                    result.append(.callout(callout.type, fullText))
                    continue
                }
            }

            // Regular paragraph line
            result.append(.paragraph(line))
            i += 1
        }

        // Close unclosed code block
        if inCodeBlock && !codeLines.isEmpty {
            result.append(.code(codeLines.joined(separator: "\n"), codeLang))
        }

        return result
    }

    // MARK: - Block Views

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .paragraph(let text):
            inlineMarkdown(text)
                .padding(.vertical, 2)

        case .heading(let level, let text):
            Text(text)
                .font(.system(size: headingSize(level), weight: .bold))
                .foregroundStyle(Color.white)
                .padding(.top, 12)
                .padding(.bottom, 4)

        case .code(let code, let lang):
            VStack(alignment: .leading, spacing: 0) {
                // Language badge + copy button
                if let lang, !lang.isEmpty {
                    HStack {
                        Text(lang)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(TrinityTheme.accent)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(code, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    SyntaxHighlightedCode(code: code, language: lang)
                        .padding(.horizontal, 12)
                        .padding(.vertical, lang != nil ? 4 : 12)
                        .padding(.bottom, 8)
                }
            }
            .background(Color(hex: 0x1A1A1A))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.vertical, 4)

        case .listItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("\u{2022}")
                    .foregroundStyle(Color(hex: 0xD1D1D1))
                inlineMarkdown(text)
            }
            .padding(.vertical, 1)
            .padding(.leading, 8)

        case .table(let rows):
            TableBlockView(rows: rows)
                .padding(.vertical, 8)

        case .image(let alt, let url):
            ImageBlockView(alt: alt, url: url)
                .padding(.vertical, 8)

        case .diff(let content):
            DiffBlockView(content: content)
                .padding(.vertical, 4)

        case .math(let expr):
            MathBlockView(expression: expr)
                .padding(.vertical, 4)

        case .callout(let type, let text):
            CalloutView(type: type, text: text)
                .padding(.vertical, 4)

        case .horizontalRule:
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.vertical, 12)

        case .empty:
            Spacer().frame(height: 8)
        }
    }

    // MARK: - Callout Parser

    private func parseCallout(_ content: String) -> (type: CalloutType, text: String)? {
        let upper = content.uppercased()
        if upper.hasPrefix("**ERROR**:") || upper.hasPrefix("**ERROR**") {
            return (.error, String(content.dropFirst(content.hasPrefix("**ERROR**:") ? 10 : 9)).trimmingCharacters(in: .whitespaces))
        }
        if upper.hasPrefix("**WARNING**:") || upper.hasPrefix("**WARNING**") {
            return (.warning, String(content.dropFirst(content.hasPrefix("**WARNING**:") ? 12 : 11)).trimmingCharacters(in: .whitespaces))
        }
        if upper.hasPrefix("**INFO**:") || upper.hasPrefix("**INFO**") {
            return (.info, String(content.dropFirst(content.hasPrefix("**INFO**:") ? 9 : 8)).trimmingCharacters(in: .whitespaces))
        }
        if upper.hasPrefix("**TIP**:") || upper.hasPrefix("**TIP**") {
            return (.tip, String(content.dropFirst(content.hasPrefix("**TIP**:") ? 8 : 7)).trimmingCharacters(in: .whitespaces))
        }
        if upper.hasPrefix("**NOTE**:") || upper.hasPrefix("**NOTE**") {
            return (.note, String(content.dropFirst(content.hasPrefix("**NOTE**:") ? 9 : 8)).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    // MARK: - Inline Markdown

    @ViewBuilder
    private func inlineMarkdown(_ text: String) -> some View {
        let processed = MathRenderer.processInlineMath(text)
        if let attributed = try? AttributedString(
            markdown: processed,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            let withCitations = applyCitationSuperscripts(to: attributed)
            Text(withCitations)
                .foregroundStyle(Color(hex: 0xD1D1D1))
                .environment(\.openURL, OpenURLAction { url in
                    NSWorkspace.shared.open(url)
                    return .handled
                })
        } else {
            Text(processed)
                .foregroundStyle(Color(hex: 0xD1D1D1))
        }
    }

    /// Replace [N] patterns with tappable accent-colored superscripts linked to citation URLs
    private func applyCitationSuperscripts(to str: AttributedString) -> AttributedString {
        guard let citations = citations, !citations.isEmpty else { return str }
        var result = str
        let superMap: [Character: Character] = [
            "0": "\u{2070}", "1": "\u{00B9}", "2": "\u{00B2}", "3": "\u{00B3}",
            "4": "\u{2074}", "5": "\u{2075}", "6": "\u{2076}", "7": "\u{2077}",
            "8": "\u{2078}", "9": "\u{2079}",
        ]

        // Process [1], [2], etc.
        let plain = String(result.characters)
        guard let regex = try? NSRegularExpression(pattern: #"\[(\d+)\]"#) else { return result }
        let nsRange = NSRange(plain.startIndex..., in: plain)
        // Process matches in reverse order to maintain string indices
        let matches = regex.matches(in: plain, range: nsRange).reversed()
        for match in matches {
            guard let fullRange = Range(match.range, in: plain),
                  let numRange = Range(match.range(at: 1), in: plain) else { continue }
            let numStr = String(plain[numRange])
            guard let num = Int(numStr), num >= 1, num <= citations.count else { continue }

            let startOffset = plain.distance(from: plain.startIndex, to: fullRange.lowerBound)
            let endOffset = plain.distance(from: plain.startIndex, to: fullRange.upperBound)
            let attrStart = result.index(result.startIndex, offsetByCharacters: startOffset)
            let attrEnd = result.index(result.startIndex, offsetByCharacters: endOffset)

            // Build superscript string
            let superscript = String(numStr.map { superMap[$0] ?? $0 })
            var replacement = AttributedString(superscript)
            replacement.foregroundColor = Color(hex: 0x50FA7B) // accent green
            replacement.font = .system(size: 11, weight: .bold)
            // Add link to citation URL
            if let url = URL(string: citations[num - 1].url) {
                replacement.link = url
            }

            result.replaceSubrange(attrStart..<attrEnd, with: replacement)
        }
        return result
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 20
        case 2: return 17
        default: return 15
        }
    }

    // MARK: - Table Helpers

    private func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Table separator: | --- | --- | or |:---|:---|
        return trimmed.contains("|") && trimmed.contains("-")
            && trimmed.replacingOccurrences(of: "|", with: "")
                      .replacingOccurrences(of: "-", with: "")
                      .replacingOccurrences(of: ":", with: "")
                      .replacingOccurrences(of: " ", with: "")
                      .isEmpty
    }

    private func parseTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed = String(trimmed.dropFirst()) }
        if trimmed.hasSuffix("|") { trimmed = String(trimmed.dropLast()) }
        return trimmed.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    // MARK: - Image Helpers

    private struct ImageMatch {
        let alt: String
        let url: String
    }

    private func extractImage(_ line: String) -> ImageMatch? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // ![alt](url)
        guard trimmed.hasPrefix("![") else { return nil }
        guard let altEnd = trimmed.range(of: "](") else { return nil }
        guard trimmed.hasSuffix(")") else { return nil }

        let alt = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<altEnd.lowerBound])
        let urlStart = altEnd.upperBound
        let urlEnd = trimmed.index(before: trimmed.endIndex)
        let url = String(trimmed[urlStart..<urlEnd])
        return ImageMatch(alt: alt, url: url)
    }
}

// MARK: - Table Block View

struct TableBlockView: View {
    let rows: [[String]]

    private var colCount: Int { rows.map(\.count).max() ?? 0 }

    /// Convert table to plain text for clipboard
    private var tableAsText: String {
        rows.map { row in
            row.joined(separator: " | ")
        }.joined(separator: "\n")
    }

    var body: some View {
        if rows.isEmpty || colCount == 0 {
            EmptyView()
        } else {
            VStack(spacing: 0) {
            // Copy button header
            HStack {
                Text("table")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.3))
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(tableAsText, forType: NSPasteboard.PasteboardType.string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .help("Copy table")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.04))

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                        HStack(spacing: 0) {
                            ForEach(0..<colCount, id: \.self) { colIdx in
                                let cell = colIdx < row.count ? row[colIdx] : ""
                                Text(cell)
                                    .font(.system(size: 13, weight: rowIdx == 0 ? .bold : .regular, design: .default))
                                    .foregroundStyle(rowIdx == 0 ? TrinityTheme.accent : Color(hex: 0xD1D1D1))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .frame(minWidth: 80, alignment: .leading)
                            }
                        }
                        .background(rowIdx == 0 ? Color.white.opacity(0.06) : (rowIdx % 2 == 0 ? Color.clear : Color.white.opacity(0.02)))

                        if rowIdx == 0 {
                            Rectangle()
                                .fill(TrinityTheme.accent.opacity(0.3))
                                .frame(height: 1)
                        }
                    }
                }
            } // ScrollView
            } // VStack
            .background(Color(hex: 0x0A0A0A))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

// MARK: - Diff Block View

struct DiffBlockView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("diff")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(TrinityTheme.accent)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(content.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 0) {
                            Text(line)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(diffLineColor(line))
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 1)
                        .background(diffLineBG(line))
                    }
                }
                .padding(.vertical, 4)
                .padding(.bottom, 8)
            }
        }
        .background(Color(hex: 0x1A1A1A))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func diffLineColor(_ line: String) -> Color {
        if line.hasPrefix("+") { return Color(hex: 0x50FA7B) }  // green
        if line.hasPrefix("-") { return Color(hex: 0xFF5555) }  // red
        if line.hasPrefix("@@") { return Color(hex: 0x8BE9FD) } // cyan
        return Color(hex: 0xE0E0E0)
    }

    private func diffLineBG(_ line: String) -> Color {
        if line.hasPrefix("+") { return Color(hex: 0x50FA7B).opacity(0.08) }
        if line.hasPrefix("-") { return Color(hex: 0xFF5555).opacity(0.08) }
        if line.hasPrefix("@@") { return Color(hex: 0x8BE9FD).opacity(0.05) }
        return .clear
    }
}

// MARK: - Callout View

struct CalloutView: View {
    let type: MarkdownTextView.CalloutType
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: type.icon)
                .font(.system(size: 14))
                .foregroundStyle(type.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineSpacing(3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(type.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Syntax Highlighted Code

struct SyntaxHighlightedCode: View {
    let code: String
    let language: String?

    var body: some View {
        Text(highlightedCode)
            .font(.system(size: 13, design: .monospaced))
            .textSelection(.enabled)
    }

    private var highlightedCode: AttributedString {
        var result = AttributedString(code)
        result.foregroundColor = Color(hex: 0xE0E0E0) // default text

        let lang = (language ?? "").lowercased()
        let isZig = lang == "zig"
        let isSwift = lang == "swift"
        let isJS = ["js", "javascript", "typescript", "ts", "json"].contains(lang)
        let isPy = ["python", "py"].contains(lang)
        let isRust = lang == "rust" || lang == "rs"
        let isBash = ["bash", "sh", "shell", "zsh"].contains(lang)

        // Keyword colors
        let keywordColor = Color(hex: 0xFF79C6) // pink
        let stringColor = Color(hex: 0xF1FA8C)  // yellow
        let commentColor = Color(hex: 0x6272A4)  // gray-blue
        let numberColor = Color(hex: 0xBD93F9)   // purple
        let typeColor = Color(hex: 0x8BE9FD)     // cyan
        let funcColor = Color(hex: 0x50FA7B)     // green

        let keywords: [String]
        let types: [String]

        if isZig {
            keywords = ["const", "var", "fn", "return", "if", "else", "while", "for", "switch",
                        "break", "continue", "pub", "try", "catch", "defer", "errdefer",
                        "comptime", "inline", "export", "extern", "test", "struct", "enum",
                        "union", "error", "unreachable", "undefined", "null", "true", "false",
                        "and", "or", "orelse", "async", "await", "suspend", "resume"]
            types = ["u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64", "f16", "f32", "f64",
                     "bool", "void", "anyerror", "anytype", "usize", "isize", "noreturn"]
        } else if isSwift {
            keywords = ["let", "var", "func", "return", "if", "else", "guard", "while", "for",
                        "switch", "case", "break", "continue", "import", "struct", "class",
                        "enum", "protocol", "extension", "self", "Self", "true", "false", "nil",
                        "async", "await", "throws", "throw", "try", "catch", "some", "any",
                        "private", "public", "internal", "fileprivate", "open", "static",
                        "override", "mutating", "weak", "lazy", "in", "where", "typealias"]
            types = ["Int", "String", "Bool", "Double", "Float", "Array", "Dictionary",
                     "Optional", "Result", "Void", "Never", "Any", "AnyObject", "UUID",
                     "Date", "URL", "Data", "View", "Color"]
        } else if isJS {
            keywords = ["const", "let", "var", "function", "return", "if", "else", "while",
                        "for", "switch", "case", "break", "continue", "import", "export",
                        "default", "class", "extends", "new", "this", "super", "async",
                        "await", "try", "catch", "throw", "true", "false", "null", "undefined",
                        "typeof", "instanceof", "of", "in", "from", "as", "type", "interface"]
            types = ["string", "number", "boolean", "object", "Array", "Promise", "Map", "Set"]
        } else if isPy {
            keywords = ["def", "return", "if", "elif", "else", "while", "for", "in", "import",
                        "from", "class", "self", "True", "False", "None", "and", "or", "not",
                        "is", "with", "as", "try", "except", "finally", "raise", "pass",
                        "break", "continue", "lambda", "yield", "async", "await", "global"]
            types = ["int", "str", "float", "bool", "list", "dict", "tuple", "set", "bytes"]
        } else if isRust {
            keywords = ["fn", "let", "mut", "const", "return", "if", "else", "while", "for",
                        "loop", "match", "break", "continue", "use", "mod", "pub", "struct",
                        "enum", "impl", "trait", "self", "Self", "true", "false", "as", "in",
                        "ref", "move", "async", "await", "unsafe", "where", "type", "dyn"]
            types = ["i32", "u32", "i64", "u64", "f32", "f64", "bool", "str", "String",
                     "Vec", "Option", "Result", "Box", "Rc", "Arc", "usize", "isize"]
        } else if isBash {
            keywords = ["if", "then", "else", "elif", "fi", "for", "while", "do", "done",
                        "case", "esac", "function", "return", "exit", "echo", "export",
                        "source", "local", "readonly", "set", "unset", "shift", "true", "false"]
            types = []
        } else {
            // Unknown language — return unhighlighted
            return result
        }

        // Apply highlighting via regex on the raw string
        applyPattern(&result, in: code, pattern: isZig || isRust ? "//[^\n]*" : (isPy || isBash ? "#[^\n]*" : "//[^\n]*"), color: commentColor)
        if !isBash {
            applyPattern(&result, in: code, pattern: "/\\*[\\s\\S]*?\\*/", color: commentColor)
        }
        applyPattern(&result, in: code, pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", color: stringColor)
        applyPattern(&result, in: code, pattern: "'(?:[^'\\\\]|\\\\.)*'", color: stringColor)
        applyPattern(&result, in: code, pattern: "\\b\\d+(?:\\.\\d+)?\\b", color: numberColor)

        for kw in keywords {
            applyPattern(&result, in: code, pattern: "\\b\(NSRegularExpression.escapedPattern(for: kw))\\b", color: keywordColor)
        }
        for tp in types {
            applyPattern(&result, in: code, pattern: "\\b\(NSRegularExpression.escapedPattern(for: tp))\\b", color: typeColor)
        }

        // Function calls: word followed by (
        applyPattern(&result, in: code, pattern: "\\b([a-zA-Z_]\\w*)(?=\\()", color: funcColor)

        return result
    }

    private func applyPattern(_ attrStr: inout AttributedString, in source: String, pattern: String, color: Color) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let nsRange = NSRange(source.startIndex..., in: source)
        for match in regex.matches(in: source, range: nsRange) {
            guard let range = Range(match.range, in: source) else { continue }
            // Convert String range to AttributedString range
            let startOffset = source.distance(from: source.startIndex, to: range.lowerBound)
            let endOffset = source.distance(from: source.startIndex, to: range.upperBound)
            let attrStart = attrStr.index(attrStr.startIndex, offsetByCharacters: startOffset)
            let attrEnd = attrStr.index(attrStr.startIndex, offsetByCharacters: endOffset)
            attrStr[attrStart..<attrEnd].foregroundColor = color
        }
    }
}

// MARK: - Image Block View

struct ImageBlockView: View {
    let alt: String
    let url: String
    @State private var image: NSImage?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 600, maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .contextMenu {
                        Button("Copy Image") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.writeObjects([image])
                        }
                        Button("Save Image...") {
                            saveImage(image)
                        }
                        Button("Open in Browser") {
                            if let url = URL(string: url) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading image...")
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .frame(width: 300, height: 200)
                .background(Color(hex: 0x1A1A1A))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Failed to load — show URL + retry
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .foregroundStyle(TrinityTheme.statusError)
                        Text(alt.isEmpty ? "Image failed to load" : alt)
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    HStack(spacing: 8) {
                        Button {
                            isLoading = true
                            Task {
                                image = await downloadImage(from: url)
                                isLoading = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10))
                                Text("Retry")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(TrinityTheme.accent)
                        }
                        .buttonStyle(.plain)

                        Button {
                            if let imgURL = URL(string: url) {
                                NSWorkspace.shared.open(imgURL)
                            }
                        } label: {
                            Text("Open URL")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(Color(hex: 0x1A1A1A))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !alt.isEmpty && image != nil {
                Text(alt)
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .italic()
            }
        }
        .task {
            image = await downloadImage(from: url)
            isLoading = false
        }
    }

    private func saveImage(_ nsImage: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "queen-image.png"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let tiff = nsImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: url)
            }
        }
    }
}

// MARK: - Math Block View (block $$...$$ display)

struct MathBlockView: View {
    let expression: String

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            VStack(alignment: .center, spacing: 4) {
                Text(MathRenderer.render(expression))
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(Color(hex: 0xE0E0E0))
                    .textSelection(.enabled)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            Spacer()
        }
        .background(Color(hex: 0x0A0A0A))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(TrinityTheme.purple.opacity(0.2), lineWidth: 1)
        )
        .accessibilityLabel("Math expression: \(expression)")
    }
}

// MARK: - Math Renderer (Unicode-based, no external deps)

enum MathRenderer {
    /// Render LaTeX-like expression to Unicode math
    static func render(_ expr: String) -> String {
        var s = expr

        // Greek letters
        let greek: [(String, String)] = [
            ("\\alpha", "\u{03B1}"), ("\\beta", "\u{03B2}"), ("\\gamma", "\u{03B3}"),
            ("\\delta", "\u{03B4}"), ("\\epsilon", "\u{03B5}"), ("\\zeta", "\u{03B6}"),
            ("\\eta", "\u{03B7}"), ("\\theta", "\u{03B8}"), ("\\iota", "\u{03B9}"),
            ("\\kappa", "\u{03BA}"), ("\\lambda", "\u{03BB}"), ("\\mu", "\u{03BC}"),
            ("\\nu", "\u{03BD}"), ("\\xi", "\u{03BE}"), ("\\pi", "\u{03C0}"),
            ("\\rho", "\u{03C1}"), ("\\sigma", "\u{03C3}"), ("\\tau", "\u{03C4}"),
            ("\\upsilon", "\u{03C5}"), ("\\phi", "\u{03C6}"), ("\\chi", "\u{03C7}"),
            ("\\psi", "\u{03C8}"), ("\\omega", "\u{03C9}"),
            ("\\Gamma", "\u{0393}"), ("\\Delta", "\u{0394}"), ("\\Theta", "\u{0398}"),
            ("\\Lambda", "\u{039B}"), ("\\Xi", "\u{039E}"), ("\\Pi", "\u{03A0}"),
            ("\\Sigma", "\u{03A3}"), ("\\Phi", "\u{03A6}"), ("\\Psi", "\u{03A8}"),
            ("\\Omega", "\u{03A9}"),
        ]
        for (tex, uni) in greek {
            s = s.replacingOccurrences(of: tex, with: uni)
        }

        // Common symbols
        let symbols: [(String, String)] = [
            ("\\infty", "\u{221E}"), ("\\pm", "\u{00B1}"), ("\\mp", "\u{2213}"),
            ("\\times", "\u{00D7}"), ("\\div", "\u{00F7}"), ("\\cdot", "\u{22C5}"),
            ("\\leq", "\u{2264}"), ("\\geq", "\u{2265}"), ("\\neq", "\u{2260}"),
            ("\\approx", "\u{2248}"), ("\\equiv", "\u{2261}"), ("\\sim", "\u{223C}"),
            ("\\rightarrow", "\u{2192}"), ("\\leftarrow", "\u{2190}"),
            ("\\Rightarrow", "\u{21D2}"), ("\\Leftarrow", "\u{21D0}"),
            ("\\forall", "\u{2200}"), ("\\exists", "\u{2203}"), ("\\partial", "\u{2202}"),
            ("\\nabla", "\u{2207}"), ("\\in", "\u{2208}"), ("\\notin", "\u{2209}"),
            ("\\subset", "\u{2282}"), ("\\supset", "\u{2283}"),
            ("\\cup", "\u{222A}"), ("\\cap", "\u{2229}"),
            ("\\ldots", "\u{2026}"), ("\\cdots", "\u{22EF}"),
            ("\\sum", "\u{2211}"), ("\\prod", "\u{220F}"), ("\\int", "\u{222B}"),
        ]
        for (tex, uni) in symbols {
            s = s.replacingOccurrences(of: tex, with: uni)
        }

        // Superscripts: ^{...} or ^n
        s = applySuperscripts(s)

        // Subscripts: _{...} or _n
        s = applySubscripts(s)

        // \frac{a}{b} → a/b
        while let range = s.range(of: #"\\frac\{([^}]*)\}\{([^}]*)\}"#, options: .regularExpression) {
            let match = String(s[range])
            if let regex = try? NSRegularExpression(pattern: #"\\frac\{([^}]*)\}\{([^}]*)\}"#),
               let m = regex.firstMatch(in: match, range: NSRange(match.startIndex..., in: match)),
               let r1 = Range(m.range(at: 1), in: match),
               let r2 = Range(m.range(at: 2), in: match) {
                let num = render(String(match[r1]))
                let den = render(String(match[r2]))
                s = s.replacingCharacters(in: range, with: "\(num)\u{2044}\(den)")
            } else {
                break
            }
        }

        // \sqrt{x} → √x
        s = s.replacingOccurrences(of: #"\\sqrt\{([^}]*)\}"#, with: "\u{221A}($1)", options: .regularExpression)

        // Clean up remaining backslashes for simple commands
        s = s.replacingOccurrences(of: "\\text{", with: "")
        s = s.replacingOccurrences(of: "\\mathrm{", with: "")
        s = s.replacingOccurrences(of: "\\mathbf{", with: "")
        // Remove unmatched closing braces from above
        if s.filter({ $0 == "}" }).count > s.filter({ $0 == "{" }).count {
            s = s.replacingOccurrences(of: "}", with: "")
        }

        return s
    }

    /// Process inline $...$ math in text
    static func processInlineMath(_ text: String) -> String {
        guard text.contains("$") else { return text }
        var result = ""
        var i = text.startIndex
        while i < text.endIndex {
            if text[i] == "$" && (i == text.startIndex || text[text.index(before: i)] != "\\") {
                // Find closing $
                let start = text.index(after: i)
                if start < text.endIndex, let end = text[start...].firstIndex(of: "$") {
                    let mathExpr = String(text[start..<end])
                    if !mathExpr.isEmpty && !mathExpr.contains("\n") {
                        result += render(mathExpr)
                        i = text.index(after: end)
                        continue
                    }
                }
            }
            result.append(text[i])
            i = text.index(after: i)
        }
        return result
    }

    private static func applySuperscripts(_ s: String) -> String {
        let superMap: [Character: Character] = [
            "0": "\u{2070}", "1": "\u{00B9}", "2": "\u{00B2}", "3": "\u{00B3}",
            "4": "\u{2074}", "5": "\u{2075}", "6": "\u{2076}", "7": "\u{2077}",
            "8": "\u{2078}", "9": "\u{2079}", "+": "\u{207A}", "-": "\u{207B}",
            "n": "\u{207F}", "i": "\u{2071}",
        ]
        var result = s
        // ^{content}
        while let range = result.range(of: #"\^\{([^}]*)\}"#, options: .regularExpression) {
            let inner = String(result[range]).dropFirst(2).dropLast(1)
            let sup = String(inner).map { superMap[$0] ?? $0 }
            result = result.replacingCharacters(in: range, with: String(sup))
        }
        // ^single_char
        while let range = result.range(of: #"\^([0-9ni])"#, options: .regularExpression) {
            let ch = result[result.index(range.lowerBound, offsetBy: 1)]
            let sup = superMap[ch] ?? ch
            result = result.replacingCharacters(in: range, with: String(sup))
        }
        return result
    }

    private static func applySubscripts(_ s: String) -> String {
        let subMap: [Character: Character] = [
            "0": "\u{2080}", "1": "\u{2081}", "2": "\u{2082}", "3": "\u{2083}",
            "4": "\u{2084}", "5": "\u{2085}", "6": "\u{2086}", "7": "\u{2087}",
            "8": "\u{2088}", "9": "\u{2089}", "+": "\u{208A}", "-": "\u{208B}",
        ]
        var result = s
        // _{content}
        while let range = result.range(of: #"_\{([^}]*)\}"#, options: .regularExpression) {
            let inner = String(result[range]).dropFirst(2).dropLast(1)
            let sub = String(inner).map { subMap[$0] ?? $0 }
            result = result.replacingCharacters(in: range, with: String(sub))
        }
        // _single_digit
        while let range = result.range(of: #"_([0-9])"#, options: .regularExpression) {
            let ch = result[result.index(range.lowerBound, offsetBy: 1)]
            let sub = subMap[ch] ?? ch
            result = result.replacingCharacters(in: range, with: String(sub))
        }
        return result
    }
}
