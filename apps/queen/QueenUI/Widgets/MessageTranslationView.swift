import SwiftUI

// MARK: - Translation Button (Inline)

/// Small button that shows in message actions menu
/// Triggers the translation sheet when clicked
struct TranslateButton: View {
    let message: ChatMessage
    let onTranslate: () -> Void

    var body: some View {
        Button(action: onTranslate) {
            Image(systemName: "globe")
                .font(.system(size: 12))
                .foregroundStyle(TrinityTheme.textMuted)
                .frame(width: 28, height: 28)
        }
        .accessibilityLabel("Translate message")
    }
}

// MARK: - Translation Sheet Overlay

/// Sheet that displays the translation UI
struct TranslationOverlay: View {
    let message: ChatMessage
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTargetLanguage: SupportedLanguage = .spanish
    @State private var sourceLanguage: SupportedLanguage?
    @State private var translatedText: String = ""
    @State private var isTranslating = false
    @State private var showLanguagePicker = false
    @State private var showSourcePicker = false
    @State private var didCopy = false
    @State private var sourceExpanded = false

    private let cache = TranslationCache.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            ScrollView {
                VStack(alignment: .leading, spacing: TrinityTheme.spacing) {
                    // Language selectors
                    languageSelectorRow

                    // Source text (collapsible)
                    sourceTextSection

                    // Translation result
                    translationSection
                }
                .padding(TrinityTheme.spacing)
            }

            // Footer
            footer
        }
        .frame(width: 600, height: 500)
        .background(TrinityTheme.bgWindow)
        .onAppear {
            detectLanguage()
            loadFromCache()
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePicker(
                selectedLanguage: $selectedTargetLanguage,
                recentLanguages: cache.recentLanguages
            )
        }
        .sheet(isPresented: $showSourcePicker) {
            LanguagePicker(
                selectedLanguage: Binding(
                    get: { sourceLanguage ?? .autoDetect },
                    set: { sourceLanguage = $0 }
                ),
                recentLanguages: cache.recentLanguages,
                includeAutoDetect: true
            )
        }
    }

    private var header: some View {
        HStack {
            Text("Translate Message")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TrinityTheme.textPrimary)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, TrinityTheme.spacing)
        .padding(.vertical, 12)
        .background(TrinityTheme.bgSidebar)
    }

    private var languageSelectorRow: some View {
        HStack(spacing: 12) {
            // Source language
            Button(action: { showSourcePicker = true }) {
                HStack(spacing: 6) {
                    Text(sourceLanguage?.flag ?? "??")
                    Text(sourceLanguage?.localizedName ?? "Auto-detect")
                        .foregroundStyle(TrinityTheme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(TrinityTheme.bgCard)
                .cornerRadius(TrinityTheme.cornerSmall)
            }
            .buttonStyle(.plain)

            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 12))
                .foregroundStyle(TrinityTheme.textMuted)

            // Target language
            Button(action: { showLanguagePicker = true }) {
                HStack(spacing: 6) {
                    Text(selectedTargetLanguage.flag)
                    Text(selectedTargetLanguage.localizedName)
                        .foregroundStyle(TrinityTheme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(TrinityTheme.bgCard)
                .cornerRadius(TrinityTheme.cornerSmall)
            }
            .buttonStyle(.plain)

            Spacer()

            // Translate button
            Button(action: performTranslation) {
                HStack(spacing: 6) {
                    if isTranslating {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "globe")
                    }
                    Text("Translate")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isTranslating ? TrinityTheme.textMuted : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isTranslating ? TrinityTheme.bgCardBorder : TrinityTheme.accent)
                .cornerRadius(TrinityTheme.cornerSmall)
            }
            .buttonStyle(.plain)
            .disabled(isTranslating)
            .accessibilityLabel("Translate to \(selectedTargetLanguage.localizedName)")
        }
    }

    private var sourceTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { sourceExpanded.toggle() }) {
                HStack {
                    Text("Original")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TrinityTheme.textMuted)
                    Image(systemName: sourceExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(TrinityTheme.textMuted)
                    Text(String(message.text.prefix(50)) + (message.text.count > 50 ? "..." : ""))
                        .font(.system(size: 11))
                        .foregroundStyle(TrinityTheme.textMuted)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            if sourceExpanded {
                Text(message.text)
                    .font(.system(size: TrinityTheme.chatFontSize))
                    .foregroundStyle(TrinityTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(TrinityTheme.bgCard)
                    .cornerRadius(TrinityTheme.cornerSmall)
            }
        }
    }

    private var translationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Translation")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TrinityTheme.textMuted)

            if isTranslating {
                loadingSkeleton
            } else if translatedText.isEmpty {
                Text("Click \"Translate\" to translate this message")
                    .font(.system(size: TrinityTheme.chatFontSize))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(TrinityTheme.bgCard)
                    .cornerRadius(TrinityTheme.cornerSmall)
            } else {
                Text(translatedText)
                    .font(.system(size: TrinityTheme.chatFontSize))
                    .foregroundStyle(TrinityTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(TrinityTheme.bgCard)
                    .cornerRadius(TrinityTheme.cornerSmall)
            }
        }
    }

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<3) { _ in
                HStack(spacing: 8) {
                    Circle()
                        .fill(TrinityTheme.textMuted.opacity(0.3))
                        .frame(width: 8, height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(TrinityTheme.textMuted.opacity(0.3))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(TrinityTheme.textMuted.opacity(0.2))
                        .frame(height: 12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerSmall)
    }

    private var footer: some View {
        HStack {
            if !translatedText.isEmpty {
                Button(action: copyTranslation) {
                    HStack(spacing: 6) {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        Text(didCopy ? "Copied" : "Copy Translation")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("Translation API not connected")
                .font(.system(size: 10))
                .foregroundStyle(TrinityTheme.statusWarn)
        }
        .padding(.horizontal, TrinityTheme.spacing)
        .padding(.vertical, 10)
        .background(TrinityTheme.bgSidebar)
    }

    // MARK: - Actions

    private func detectLanguage() {
        // Simple heuristic-based detection
        let text = message.text.lowercased()

        // Check for Cyrillic (Russian)
        if text.unicodeScalars.contains(where: { $0.value >= 0x0400 && $0.value <= 0x04FF }) {
            sourceLanguage = .russian
            return
        }

        // Check for Chinese characters
        if text.unicodeScalars.contains(where: { $0.value >= 0x4E00 && $0.value <= 0x9FFF }) {
            sourceLanguage = .chinese
            return
        }

        // Check for Japanese (Hiragana/Katakana)
        if text.unicodeScalars.contains(where: { ($0.value >= 0x3040 && $0.value <= 0x309F) ||
                                               ($0.value >= 0x30A0 && $0.value <= 0x30FF) }) {
            sourceLanguage = .japanese
            return
        }

        // Check for common words
        let patterns: [(String, SupportedLanguage)] = [
            ("el|la|los|las|un|una|es|estar|tener|haber", .spanish),
            ("le|la|les|un|une|etre|avoir|faire", .french),
            ("der|die|das|ein|eine|sein|haben|werden", .german),
            ("o|a|os|as|um|uma|ser|estar|ter", .portuguese),
        ]

        for (pattern, language) in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                sourceLanguage = language
                return
            }
        }

        sourceLanguage = .english
    }

    private func loadFromCache() {
        if let cached = cache.translation(for: message.id, targetLanguage: selectedTargetLanguage) {
            translatedText = cached
        }
    }

    private func performTranslation() {
        isTranslating = true

        // Simulate translation delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Placeholder translation (would use actual API in production)
            translatedText = placeholderTranslation()

            // Cache the result
            cache.saveTranslation(
                for: message.id,
                targetLanguage: selectedTargetLanguage,
                text: translatedText
            )

            isTranslating = false
        }
    }

    private func placeholderTranslation() -> String {
        // Return placeholder text since no API is connected
        return "[Translation to \(selectedTargetLanguage.localizedName) would appear here]\n\nConnect a translation service in ChatClient to enable actual translations."
    }

    private func copyTranslation() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)

        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            didCopy = false
        }
    }
}

// MARK: - Language Picker

/// Sheet for selecting source and target languages
struct LanguagePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLanguage: SupportedLanguage
    let recentLanguages: [SupportedLanguage]
    var includeAutoDetect: Bool = false

    @State private var searchText = ""

    private var filteredLanguages: [SupportedLanguage] {
        if searchText.isEmpty {
            return includeAutoDetect ? Array(SupportedLanguage.allCases) : Array(SupportedLanguage.allCases.dropFirst())
        }

        return SupportedLanguage.allCases.filter { language in
            language.localizedName.localizedCaseInsensitiveContains(searchText) ||
            language.englishName.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(TrinityTheme.textMuted)
                TextField("Search languages...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(TrinityTheme.bgCard)
            .cornerRadius(TrinityTheme.cornerSmall)
            .padding(TrinityTheme.spacing)

            // Language list
            ScrollView {
                VStack(spacing: 0) {
                    if !searchText.isEmpty || recentLanguages.isEmpty {
                        languageSection(title: nil, languages: filteredLanguages)
                    } else {
                        languageSection(title: "Recent", languages: recentLanguages)

                        let otherLanguages = SupportedLanguage.allCases.filter { !recentLanguages.contains($0) }
                        languageSection(title: "All Languages", languages: otherLanguages)
                    }
                }
            }

            // Selected indicator
            HStack {
                Text("Selected: \(selectedLanguage.localizedName)")
                    .font(.system(size: 12))
                    .foregroundStyle(TrinityTheme.textMuted)
                Spacer()
            }
            .padding(TrinityTheme.spacing)
            .background(TrinityTheme.bgSidebar)
        }
        .frame(width: 350, height: 400)
        .background(TrinityTheme.bgWindow)
    }

    private func languageSection(title: String?, languages: [SupportedLanguage]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .padding(.horizontal, TrinityTheme.spacing)
                    .padding(.vertical, 8)
            }

            ForEach(languages, id: \.self) { language in
                Button(action: {
                    selectedLanguage = language
                    dismiss()
                }) {
                    HStack {
                        Text(language.flag)
                            .font(.system(size: 18))
                        Text(language.localizedName)
                            .font(.system(size: 13))
                            .foregroundStyle(TrinityTheme.textPrimary)
                        Spacer()
                        if language == selectedLanguage {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12))
                                .foregroundStyle(TrinityTheme.accent)
                        }
                    }
                    .padding(.horizontal, TrinityTheme.spacing)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(language == selectedLanguage ? TrinityTheme.bgCard : Color.clear)
            }
        }
    }
}

// MARK: - Supported Languages

enum SupportedLanguage: String, CaseIterable, Identifiable {
    case autoDetect
    case english
    case spanish
    case french
    case german
    case chinese
    case japanese
    case russian
    case portuguese
    case italian
    case korean
    case arabic
    case hindi
    case dutch
    case polish
    case turkish
    case vietnamese
    case thai
    case swedish
    case norwegian

    var id: String { rawValue }

    var flag: String {
        switch self {
        case .autoDetect: return "??"
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .russian: return "🇷🇺"
        case .portuguese: return "🇧🇷"
        case .italian: return "🇮🇹"
        case .korean: return "🇰🇷"
        case .arabic: return "🇸🇦"
        case .hindi: return "🇮🇳"
        case .dutch: return "🇳🇱"
        case .polish: return "🇵🇱"
        case .turkish: return "🇹🇷"
        case .vietnamese: return "🇻🇳"
        case .thai: return "🇹🇭"
        case .swedish: return "🇸🇪"
        case .norwegian: return "🇳🇴"
        }
    }

    var englishName: String {
        switch self {
        case .autoDetect: return "Auto-detect"
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .russian: return "Russian"
        case .portuguese: return "Portuguese"
        case .italian: return "Italian"
        case .korean: return "Korean"
        case .arabic: return "Arabic"
        case .hindi: return "Hindi"
        case .dutch: return "Dutch"
        case .polish: return "Polish"
        case .turkish: return "Turkish"
        case .vietnamese: return "Vietnamese"
        case .thai: return "Thai"
        case .swedish: return "Swedish"
        case .norwegian: return "Norwegian"
        }
    }

    var localizedName: String {
        // In production, use localized strings
        return englishName
    }
}

// MARK: - Translation Cache

/// UserDefaults-backed cache for translation results
/// Implements LRU eviction with max 100 entries
class TranslationCache {
    static let shared = TranslationCache()

    private struct CacheEntry: Codable {
        let language: String
        let text: String
        let timestamp: Date
    }

    private let cacheKey = "translationCache"
    private let recentKey = "recentLanguages"
    private let maxEntries = 100
    private let maxRecent = 5

    private var cache: [UUID: CacheEntry] = [:]
    private var accessOrder: [UUID] = []
    var recentLanguages: [SupportedLanguage] = []

    private init() {
        loadCache()
        loadRecentLanguages()
    }

    // MARK: - Cache Operations

    func translation(for messageID: UUID, targetLanguage: SupportedLanguage) -> String? {
        guard let entry = cache[messageID],
              entry.language == targetLanguage.rawValue else {
            return nil
        }

        // Update access order for LRU
        accessOrder.removeAll { $0 == messageID }
        accessOrder.append(messageID)

        return entry.text
    }

    func saveTranslation(for messageID: UUID, targetLanguage: SupportedLanguage, text: String) {
        let entry = CacheEntry(language: targetLanguage.rawValue, text: text, timestamp: Date())

        // Remove existing entry if present
        if cache[messageID] != nil {
            accessOrder.removeAll { $0 == messageID }
        }

        // Evict oldest if at capacity
        if accessOrder.count >= maxEntries {
            let oldest = accessOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }

        cache[messageID] = entry
        accessOrder.append(messageID)

        // Update recent languages
        addToRecent(targetLanguage)

        saveCache()
    }

    func clearCache() {
        cache.removeAll()
        accessOrder.removeAll()
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    // MARK: - Recent Languages

    private func addToRecent(_ language: SupportedLanguage) {
        // Skip auto-detect
        guard language != .autoDetect else { return }

        recentLanguages.removeAll { $0 == language }
        recentLanguages.insert(language, at: 0)

        if recentLanguages.count > maxRecent {
            recentLanguages = Array(recentLanguages.prefix(maxRecent))
        }

        saveRecentLanguages()
    }

    // MARK: - Persistence

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let dict = try? JSONDecoder().decode([String: CacheEntry].self, from: data) else {
            return
        }

        // Convert String keys back to UUID
        var result: [UUID: CacheEntry] = [:]
        for (key, value) in dict {
            if let uuid = UUID(uuidString: key) {
                result[uuid] = value
            }
        }
        cache = result
        accessOrder = Array(cache.keys)
    }

    private func saveCache() {
        // Convert UUID keys to String for JSON encoding
        let stringKeyDict = Dictionary(uniqueKeysWithValues:
            cache.map { key, value in (key.uuidString, value) }
        )

        if let data = try? JSONEncoder().encode(stringKeyDict) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadRecentLanguages() {
        guard let rawValues = UserDefaults.standard.array(forKey: recentKey) as? [String] else {
            recentLanguages = [.english, .spanish, .french, .german, .chinese]
            return
        }

        recentLanguages = rawValues.compactMap { SupportedLanguage(rawValue: $0) }
    }

    private func saveRecentLanguages() {
        let rawValues = recentLanguages.map { $0.rawValue }
        UserDefaults.standard.set(rawValues, forKey: recentKey)
    }
}

// MARK: - Preview Helper

#if DEBUG
struct MessageTranslationView_Previews: PreviewProvider {
    static var previews: some View {
        TranslationOverlay(
            message: ChatMessage(
                role: .assistant,
                text: "Bonjour! Comment puis-je vous aider aujourd'hui?",
                modelID: "claude-sonnet"
            )
        )
    }
}
#endif
