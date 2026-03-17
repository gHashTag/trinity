import SwiftUI

struct AgentStreamView: View {
    @EnvironmentObject var watcher: StateWatcher
    @State private var userInput = ""
    @State private var showAggregateDiff = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\u{1F4E1} AGENT STREAM")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TrinityTheme.accent)
                Spacer()
                // Toggle aggregate diff view
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showAggregateDiff.toggle() }
                } label: {
                    Image(systemName: showAggregateDiff ? "list.bullet" : "doc.text.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)

                Text("\(watcher.eventStream.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(TrinityTheme.bgCard)

            Divider().background(TrinityTheme.bgCardBorder)

            // Time navigation: selected event info bar
            if let selectedId = watcher.selectedEventId,
               let selected = watcher.eventStream.first(where: { $0.id == selectedId }) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.golden)
                    Text(watcher.sensesAtEvent(selected))
                        .font(.caption2.monospaced())
                        .foregroundStyle(TrinityTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        withAnimation { watcher.selectedEventId = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(TrinityTheme.golden.opacity(0.08))
            }

            if showAggregateDiff {
                // Aggregate diff mode
                ScrollView {
                    AggregateDiffView(events: watcher.eventStream)
                        .padding(8)
                }
            } else {
                // Event stream
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(watcher.eventStream) { event in
                                AgentEventRow(
                                    event: event,
                                    isLatest: event.id == watcher.eventStream.last?.id,
                                    isSelected: event.id == watcher.selectedEventId
                                )
                                .id(event.id)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        watcher.selectedEventId = watcher.selectedEventId == event.id ? nil : event.id
                                    }
                                }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: watcher.eventStream.count) { _, _ in
                        // Auto-scroll only if no event selected (time navigation not active)
                        if watcher.selectedEventId == nil, let last = watcher.eventStream.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            Divider().background(TrinityTheme.bgCardBorder)

            // Todos section (editable)
            MemoryTodoView()

            Divider().background(TrinityTheme.bgCardBorder)

            // Mid-flight input (Windsurf/Copilot steering)
            HStack(spacing: 8) {
                TextField("Message to Queen...", text: $userInput)
                    .font(.caption.monospaced())
                    .textFieldStyle(.plain)
                    .foregroundStyle(TrinityTheme.textPrimary)
                    .onSubmit { sendMessage() }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.caption)
                        .foregroundStyle(userInput.isEmpty ? TrinityTheme.textMuted : TrinityTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(userInput.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(TrinityTheme.bgCard)
        }
    }

    private func sendMessage() {
        let msg = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }
        watcher.sendUserInput(msg)
        userInput = ""
    }
}

// MARK: - AgentEventRow

struct AgentEventRow: View {
    let event: AgentEvent
    let isLatest: Bool
    let isSelected: Bool

    var body: some View {
        Group {
            switch event.resolvedKind {
            case "thought":
                ThoughtBubble(event: event, isLatest: isLatest)
            case "cli", "mcp":
                ToolCallRow(event: event)
            case "diff":
                DiffView(event: event)
            case "todo":
                TodoItem(event: event)
            case "queen_cycle":
                CycleStatusLine(event: event)
            case "report":
                ReportLine(event: event)
            default:
                GenericEventLine(event: event)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? TrinityTheme.golden : .clear, lineWidth: 1.5)
        )
    }
}

// MARK: - ThoughtBubble

struct ThoughtBubble: View {
    let event: AgentEvent
    let isLatest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("\u{1F9E0} THINKING")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(TrinityTheme.accent)
                Spacer()
                if let ts = event.ts {
                    Text(timeAgo(ts))
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            }

            if isLatest {
                StreamingText(text: event.text ?? "")
            } else {
                Text(event.text ?? "")
                    .font(.body.monospaced())
                    .foregroundStyle(TrinityTheme.textPrimary)
            }
        }
        .padding(10)
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(TrinityTheme.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private func timeAgo(_ ts: Int) -> String {
        let delta = Int(Date().timeIntervalSince1970) - ts
        if delta < 60 { return "\(delta)s ago" }
        if delta < 3600 { return "\(delta / 60)m ago" }
        return "\(delta / 3600)h ago"
    }
}

// MARK: - TodoItem

struct TodoItem: View {
    let event: AgentEvent

    var body: some View {
        HStack(spacing: 8) {
            Text(event.status == "done" ? "\u{2611}" : "\u{2610}")
                .font(.caption)
            Text(event.text ?? "")
                .font(.caption)
                .foregroundStyle(event.status == "done" ? TrinityTheme.textMuted : TrinityTheme.textPrimary)
            Spacer()
            if let source = event.source {
                Text("(\(source))")
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - CycleStatusLine

struct CycleStatusLine: View {
    let event: AgentEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("\u{1F451}")
                    .font(.caption)
                if let progress = event.stepProgress {
                    Text(progress)
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(TrinityTheme.accent)
                } else {
                    Text("cycle")
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                if let text = event.text {
                    Text(text)
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textPrimary)
                        .lineLimit(1)
                }
                if let detail = event.detail {
                    Text(detail)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(detail == "GREEN" ? TrinityTheme.statusOK : TrinityTheme.statusError)
                }
                Spacer()
                if let ts = event.ts {
                    Text(formatTime(ts))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            }

            if let step = event.step, let total = event.total, total > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(TrinityTheme.bgCardBorder)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(TrinityTheme.accent)
                            .frame(width: geo.size.width * CGFloat(step) / CGFloat(total))
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private func formatTime(_ ts: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: date)
    }
}

// MARK: - ReportLine

struct ReportLine: View {
    let event: AgentEvent

    var body: some View {
        HStack(spacing: 6) {
            Text("\u{1F4CA}")
                .font(.caption)
            Text(event.action ?? "report")
                .font(.caption2.monospaced())
                .foregroundStyle(TrinityTheme.golden)
            if let detail = event.detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }
}

// MARK: - GenericEventLine

struct GenericEventLine: View {
    let event: AgentEvent

    var body: some View {
        HStack(spacing: 6) {
            Text("\u{2022}")
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
            Text(event.event ?? event.kind ?? "event")
                .font(.caption2.monospaced())
                .foregroundStyle(TrinityTheme.textMuted)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}
