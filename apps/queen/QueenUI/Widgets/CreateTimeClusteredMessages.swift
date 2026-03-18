import SwiftUI

/// A view that displays messages grouped into time-based clusters with collapsible sections.
/// Groups messages into: Today, Yesterday, This Week, This Month, Older.
struct TimeClusteredMessages<Content: View>: View {
    let messages: [ChatMessage]
    @ViewBuilder let content: (ChatMessage) -> Content

    @State private var expandedSections: Set<String> = []
    @State private var scrollToID: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Clusters computed from messages
    private var clusters: [TimeCluster] {
        TimeCluster.cluster(messages: messages)
    }

    /// All section keys that exist
    private var allSectionKeys: Set<String> {
        Set(clusters.map { $0.sectionKey })
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(clusters) { cluster in
                    Section(header: sectionHeader(for: cluster)) {
                        if expandedSections.contains(cluster.sectionKey) {
                            ForEach(cluster.messages) { message in
                                content(message)
                                    .id(message.id)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .onChange(of: scrollToID) { _, newID in
                guard let id = newID else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
        .onAppear {
            // Expand all sections by default on first load
            expandedSections = allSectionKeys
        }
    }

    /// Creates a collapsible section header with count and theme colors
    @ViewBuilder
    private func sectionHeader(for cluster: TimeCluster) -> some View {
        let isExpanded = expandedSections.contains(cluster.sectionKey)
        let count = cluster.messages.count
        let countLabel = count == 1 ? "message" : "messages"

        Button {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : TrinityTheme.springAnimation()) {
                if isExpanded {
                    expandedSections.remove(cluster.sectionKey)
                } else {
                    expandedSections.insert(cluster.sectionKey)
                }
            }
        } label: {
            HStack(spacing: 8) {
                // Expand/collapse chevron
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TrinityTheme.accent)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .animation(reduceMotion ? .easeInOut(duration: 0.2) : TrinityTheme.springAnimation(), value: isExpanded)

                // Section title with theme colors
                Text(cluster.title)
                    .font(.system(size: TrinityTheme.chatCaptionSize, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)

                // Message count badge
                Text("\(count) \(countLabel)")
                    .font(.system(size: TrinityTheme.chatCaptionSize - 1))
                    .foregroundStyle(TrinityTheme.textMuted)

                Spacer(minLength: 0)

                // Visual divider line
                Rectangle()
                    .fill(TrinityTheme.bgCardBorder)
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, TrinityTheme.spacing)
            .padding(.vertical, 8)
            .background(TrinityTheme.bgWindow)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(cluster.title), \(count) \(countLabel)")
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")
            .accessibilityAddTraits(.isButton)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Time Cluster Model

struct TimeCluster: Identifiable {
    let id = UUID()
    let sectionKey: String
    let title: String
    let messages: [ChatMessage]

    /// Groups messages into time-based clusters
    static func cluster(messages: [ChatMessage]) -> [TimeCluster] {
        let calendar = Calendar.current
        let now = Date()

        // Helper to check if a date is within the current week
        func isThisWeek(_ date: Date) -> Bool {
            calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        }

        // Helper to check if a date is within the current month
        func isThisMonth(_ date: Date) -> Bool {
            calendar.isDate(date, equalTo: now, toGranularity: .month)
        }

        // Helper to check if a date is yesterday
        func isYesterday(_ date: Date) -> Bool {
            calendar.isDateInYesterday(date)
        }

        // Group messages by section
        var today: [ChatMessage] = []
        var yesterday: [ChatMessage] = []
        var thisWeek: [ChatMessage] = []
        var thisMonth: [ChatMessage] = []
        var older: [ChatMessage] = []

        for message in messages {
            let timestamp = message.timestamp

            if calendar.isDateInToday(timestamp) {
                today.append(message)
            } else if isYesterday(timestamp) {
                yesterday.append(message)
            } else if isThisWeek(timestamp) {
                thisWeek.append(message)
            } else if isThisMonth(timestamp) {
                thisMonth.append(message)
            } else {
                older.append(message)
            }
        }

        // Sort messages within each section by timestamp (newest first)
        let sort: (ChatMessage, ChatMessage) -> Bool = { $0.timestamp > $1.timestamp }

        var clusters: [TimeCluster] = []

        if !today.isEmpty {
            clusters.append(TimeCluster(sectionKey: "today", title: "Today", messages: today.sorted(by: sort)))
        }
        if !yesterday.isEmpty {
            clusters.append(TimeCluster(sectionKey: "yesterday", title: "Yesterday", messages: yesterday.sorted(by: sort)))
        }
        if !thisWeek.isEmpty {
            clusters.append(TimeCluster(sectionKey: "thisWeek", title: "This Week", messages: thisWeek.sorted(by: sort)))
        }
        if !thisMonth.isEmpty {
            clusters.append(TimeCluster(sectionKey: "thisMonth", title: "This Month", messages: thisMonth.sorted(by: sort)))
        }
        if !older.isEmpty {
            clusters.append(TimeCluster(sectionKey: "older", title: "Older", messages: older.sorted(by: sort)))
        }

        return clusters
    }
}

// MARK: - Preview

struct TimeClusteredMessages_Previews: PreviewProvider {
    static var previews: some View {
        TimeClusteredMessages(messages: []) { _ in
            Text("Sample message")
        }
    }
}
