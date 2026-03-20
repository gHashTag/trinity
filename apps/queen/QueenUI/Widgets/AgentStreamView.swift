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
                    .foregroundStyle(V4Color.accent)
                Spacer()
                // Toggle aggregate diff view
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showAggregateDiff.toggle() }
                } label: {
                    Image(systemName: showAggregateDiff ? "list.bullet" : "doc.text.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)

                Text("\(watcher.eventStream.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(V4Color.textSecondary)
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.sm)
            .background(V4Color.surface)

            Divider().background(V4Color.border)

            // Time navigation: selected event info bar
            if let selectedId = watcher.selectedEventId,
               let selected = watcher.eventStream.first(where: { $0.id == selectedId }) {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundStyle(V4Color.golden)
                    Text(watcher.sensesAtEvent(selected))
                        .font(.caption2.monospaced())
                        .foregroundStyle(V4Color.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        withAnimation { watcher.selectedEventId = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.xs)
                .background(V4Color.golden.opacity(0.08))
            }

            if showAggregateDiff {
                // Aggregate diff mode
                ScrollView {
                    AggregateDiffView(events: watcher.eventStream)
                        .padding(ParietalSpacing.sm)
                }
            } else {
                // Event stream
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
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
                        .padding(ParietalSpacing.sm)
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

            Divider().background(V4Color.border)

            // Todos section (editable)
            MemoryTodoView()

            Divider().background(V4Color.border)

            // Mid-flight input (Windsurf/Copilot steering)
            HStack(spacing: ParietalSpacing.sm) {
                TextField("Message to Queen...", text: $userInput)
                    .font(.caption.monospaced())
                    .textFieldStyle(.plain)
                    .foregroundStyle(V4Color.textPrimary)
                    .onSubmit { sendMessage() }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.caption)
                        .foregroundStyle(userInput.isEmpty ? V4Color.textSecondary : V4Color.accent)
                }
                .buttonStyle(.plain)
                .disabled(userInput.isEmpty)
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.sm)
            .background(V4Color.surface)
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
                .stroke(isSelected ? V4Color.golden : .clear, lineWidth: 1.5)
        )
    }
}

// MARK: - ThoughtBubble

struct ThoughtBubble: View {
    let event: AgentEvent
    let isLatest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            HStack(spacing: ParietalSpacing.xs) {
                Text("\u{1F9E0} THINKING")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(V4Color.accent)
                Spacer()
                if let ts = event.ts {
                    Text(timeAgo(ts))
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }

            if isLatest {
                StreamingText(text: event.text ?? "")
            } else {
                Text(event.text ?? "")
                    .font(.body.monospaced())
                    .foregroundStyle(V4Color.textPrimary)
            }
        }
        .padding(ParietalSpacing.xs)
        .background(V4Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(V4Color.accent.opacity(V2Depth.stateHover), lineWidth: 1)
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
        HStack(spacing: ParietalSpacing.sm) {
            Text(event.status == "done" ? "\u{2611}" : "\u{2610}")
                .font(.caption)
            Text(event.text ?? "")
                .font(.caption)
                .foregroundStyle(event.status == "done" ? V4Color.textSecondary : V4Color.textPrimary)
            Spacer()
            if let source = event.source {
                Text("(\(source))")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.xs)
    }
}

// MARK: - CycleStatusLine

struct CycleStatusLine: View {
    let event: AgentEvent

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            HStack(spacing: ParietalSpacing.sm - 2) {
                Text("\u{1F451}")
                    .font(.caption)
                if let progress = event.stepProgress {
                    Text(progress)
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(V4Color.accent)
                } else {
                    Text("cycle")
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
                if let text = event.text {
                    Text(text)
                        .font(.caption2)
                        .foregroundStyle(V4Color.textPrimary)
                        .lineLimit(1)
                }
                if let detail = event.detail {
                    Text(detail)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(detail == "GREEN" ? V4Color.success : V4Color.error)
                }
                Spacer()
                if let ts = event.ts {
                    Text(formatTime(ts))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(V4Color.textSecondary)
                }
            }

            if let step = event.step, let total = event.total, total > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(V4Color.border)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(V4Color.accent)
                            .frame(width: geo.size.width * CGFloat(step) / CGFloat(total))
                    }
                }
                .frame(height: ParietalSpacing.xxxs)
            }
        }
        .padding(.horizontal, ParietalSpacing.md)
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
        HStack(spacing: ParietalSpacing.sm - 2) {
            Text("\u{1F4CA}")
                .font(.caption)
            Text(event.action ?? "report")
                .font(.caption2.monospaced())
                .foregroundStyle(V4Color.golden)
            if let detail = event.detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, 3)
    }
}

// MARK: - GenericEventLine

struct GenericEventLine: View {
    let event: AgentEvent

    var body: some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            Text("\u{2022}")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)
            Text(event.event ?? event.kind ?? "event")
                .font(.caption2.monospaced())
                .foregroundStyle(V4Color.textSecondary)
            Spacer()
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, 2)
    }
}
