import SwiftUI

// MARK: - LogsScreen

/// Petal 2 (LOGS) — unified log viewer with noise-profile sheet.
/// Aggregates entries from NetworkLog, event stream, audit entries,
/// and farm events. Supports per-source filtering and one-tap noise suppression.
struct LogsScreen: View {
    @EnvironmentObject private var watcher: StateWatcher
    @StateObject private var ruleStore = NoiseRuleStore.shared
    @State private var selectedSource: LogSourceFilter = .all
    @State private var searchText = ""
    @State private var showNoiseProfile = false

    private var allEntries: [LogEntry] {
        LogEntryCollector.collect(
            networkLog: NetworkLog.shared,
            watcher: watcher
        )
    }

    private var filteredEntries: [LogEntry] {
        allEntries.filter { entry in
            // Source filter
            if selectedSource != .all && entry.source != selectedSource.rawValue {
                return false
            }
            // Noise rules
            if ruleStore.isSuppressed(entry.message, source: entry.source) {
                return false
            }
            // Text search
            if !searchText.isEmpty {
                return entry.message.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
    }

    private var suppressedCount: Int {
        allEntries.reduce(0) { count, entry in
            ruleStore.isSuppressed(entry.message, source: entry.source)
                ? count + 1 : count
        }
    }

    private var activeRuleCount: Int {
        ruleStore.rules.filter(\.isEnabled).count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                // Header
                logsHeader

                // Source filter + search
                controlsBar

                // Entries
                if filteredEntries.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredEntries.suffix(200).reversed()) { entry in
                            LogEntryRow(entry: entry)
                        }
                    }
                    .background(V4Color.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
        .sheet(isPresented: $showNoiseProfile) {
            NoiseProfileSheet(
                entries: allEntries,
                ruleStore: ruleStore
            )
        }
    }

    // MARK: - Header

    private var logsHeader: some View {
        HStack {
            Text("📜")
                .font(WernickeTypography.size48)
            VStack(alignment: .leading) {
                Text("LOGS")
                    .font(.title.weight(.bold))
                    .foregroundStyle(V4Color.accent)
                Text("Unified runtime log viewer")
                    .font(.subheadline)
                    .foregroundStyle(V4Color.textSecondary)
            }
            Spacer()

            // Noise profile button
            Button {
                showNoiseProfile = true
            } label: {
                HStack(spacing: ParietalSpacing.xs) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption)
                    Text("Noise Profile")
                        .font(.caption.weight(.semibold))
                    if activeRuleCount > 0 {
                        Text("\(activeRuleCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(V4Color.accent)
                            .clipShape(SwiftUI.Capsule())
                    }
                }
                .foregroundStyle(V4Color.textPrimary)
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.xs)
                .background(V4Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                        .stroke(V4Color.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Controls

    private var controlsBar: some View {
        VStack(spacing: ParietalSpacing.xs) {
            // Source filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ParietalSpacing.xs) {
                    ForEach(LogSourceFilter.allCases, id: \.self) { filter in
                        let count = filter == .all
                            ? allEntries.count
                            : allEntries.filter { $0.source == filter.rawValue }.count
                        SourcePill(
                            label: filter.rawValue,
                            count: count,
                            isSelected: selectedSource == filter
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSource = filter
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Search
            HStack(spacing: ParietalSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(V4Color.textSecondary)
                TextField("Search logs…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xs)
            .background(V4Color.input)
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
            .overlay(
                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                    .stroke(V4Color.border, lineWidth: 1)
            )
            .padding(.horizontal)

            // Suppressed indicator
            if suppressedCount > 0 {
                HStack(spacing: ParietalSpacing.xs) {
                    Image(systemName: "speaker.slash.fill")
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                    Text("\(suppressedCount) entries suppressed by \(activeRuleCount) rule\(activeRuleCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: ParietalSpacing.md) {
            Text("📜")
                .font(WernickeTypography.size48)
            if allEntries.isEmpty {
                Text("No logs loaded")
                    .font(.headline)
                    .foregroundStyle(V4Color.textPrimary)
                Text("Logs appear when agents run or API requests fire.")
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
            } else {
                Text("All entries filtered")
                    .font(.headline)
                    .foregroundStyle(V4Color.textPrimary)
                Text("Adjust filters or clear search to see entries.")
                        .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ParietalSpacing.xxl)
    }
}

// MARK: - Log Source Filter

enum LogSourceFilter: String, CaseIterable {
    case all = "All"
    case networkLog = "NetworkLog"
    case eventStream = "EventStream"
    case auditLog = "AuditLog"
    case farmEvents = "FarmEvents"
}

// MARK: - Source Pill

private struct SourcePill: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ParietalSpacing.xxs) {
                Text(label)
                    .font(.caption.weight(.medium))
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isSelected ? .white : V4Color.textSecondary)
            }
            .foregroundStyle(isSelected ? V4Color.bgWindow : V4Color.textSecondary)
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xxs)
            .background(isSelected ? V4Color.accent : V4Color.bgCardBorder)
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Log Entry Row

private struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: ParietalSpacing.xs) {
            Text(entry.severity.icon)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.caption.monospaced())
                    .foregroundStyle(V4Color.textPrimary)
                    .lineLimit(3)

                HStack(spacing: ParietalSpacing.xxs) {
                    Text(entry.source)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(V4Color.accent)
                    Text("•")
                        .foregroundStyle(V4Color.textSecondary)
                    Text(entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .overlay(
            Rectangle()
                .fill(V4Color.border)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// MARK: - LogEntryCollector

/// Bridges domain-specific models (NetworkLog.Entry, AgentEvent, AuditEntry,
/// FarmEvent) into unified `LogEntry` values for the LOGS tab and suggester.
enum LogEntryCollector {

    @MainActor
    static func collect(
        networkLog: NetworkLog,
        watcher: StateWatcher
    ) -> [LogEntry] {
        var entries: [LogEntry] = []

        // NetworkLog entries
        for e in networkLog.entries.suffix(100) {
            let msg = "[\(e.status)] \(e.provider)/\(e.model)  " +
                      "in:\(e.inputTokens) out:\(e.outputTokens)  " +
                      "\(e.totalMs)ms  ttfb:\(e.ttfbMs)ms"
            let sev: LogEntry.Severity = e.status == "ok" ? .info
                : (e.status == "cancelled" ? .info : .error)
            entries.append(LogEntry(
                id: e.id,
                source: LogSourceFilter.networkLog.rawValue,
                timestamp: Date(timeIntervalSince1970: TimeInterval(e.ts)),
                message: msg,
                severity: sev
            ))
        }

        // Event stream
        for e in watcher.eventStream.suffix(100) {
            let msg = e.text ?? e.cmd ?? e.event ?? e.kind ?? "event"
            let sev: LogEntry.Severity = e.kind == "error" ? .error
                : (e.kind == "warning" ? .warning : .info)
            entries.append(LogEntry(
                id: e.id,
                source: LogSourceFilter.eventStream.rawValue,
                timestamp: Date(timeIntervalSince1970: TimeInterval(e.ts ?? 0)),
                message: msg,
                severity: sev
            ))
        }

        // Audit entries
        for e in watcher.auditEntries.suffix(50) {
            let msg = "[\(e.verdict ?? "?")] \(e.action ?? "?") — \(e.detail ?? "")"
            let sev: LogEntry.Severity = (e.success == false) ? .error : .info
            entries.append(LogEntry(
                id: e.id,
                source: LogSourceFilter.auditLog.rawValue,
                timestamp: Date(timeIntervalSince1970: TimeInterval(e.ts ?? 0)),
                message: msg,
                severity: sev
            ))
        }

        // Farm events
        for e in watcher.farmEvents.suffix(50) {
            let ppl = e.ppl.map { String(format: " ppl=%.4f", $0) } ?? ""
            let msg = "[\(e.type ?? "?")] \(e.service ?? "?")\(ppl) — \(e.message ?? "")"
            entries.append(LogEntry(
                id: e.id,
                source: LogSourceFilter.farmEvents.rawValue,
                timestamp: Date(timeIntervalSince1970: TimeInterval(e.timestamp ?? 0)),
                message: msg,
                severity: .info
            ))
        }

        return entries
    }
}
