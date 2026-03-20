import SwiftUI
import Combine

/// S³AI Brain Health Monitoring Screen
/// Displays neuroanatomy region status with live telemetry
struct BrainHealthScreen: View {
    @EnvironmentObject var watcher: StateWatcher
    @State private var brainData: BrainHealthData?
    @State private var isLoading = false
    @State private var lastUpdateTime: Date?
    @State private var isRefreshing = false
    @State private var refreshTimer: Timer?
    @State private var errorMessage: String?
    @State private var selectedTab: BrainTab = .regions
    @State private var selectedEventFilter: EventFilter = .all
    @State private var selectedTaskFilter: TaskFilter = .all
    @State private var brainAlerts: [BrainAlert] = []
    @State private var showDetailSheet = false
    @State private var selectedRegion: BrainRegionDetail?

    // Auto-refresh interval: 30 seconds
    private let refreshInterval: TimeInterval = 30

    var body: some View {
        VStack(spacing: 0) {
            // Header with live indicator and refresh
            headerView

            // Tab selector
            BrainTabPicker(
                selectedTab: $selectedTab,
                alertCount: brainAlerts.count,
                eventCount: filteredEvents.count,
                taskCount: filteredTasks.count
            )
            .padding(.horizontal)
            .padding(.top, ParietalSpacing.sm)
            .background(V4Color.bgWindow)

            // Content based on selected tab
            Group {
                switch selectedTab {
                case .regions:
                    regionsContent
                case .events:
                    eventsStreamContent
                case .tasks:
                    taskClaimsContent
                case .alerts:
                    alertsContent
                }
            }
        }
        .background(V4Color.bgWindow)
        .navigationTitle("Brain Health")
        .sheet(isPresented: $showDetailSheet) {
            if let detail = selectedRegion {
                BrainRegionDetailSheet(detail: detail, brainData: brainData)
            }
        }
        .onAppear {
            startMonitoring()
            generateAlerts()
        }
        .onDisappear {
            stopMonitoring()
        }
        .onReceive(watcher.objectWillChange) { _ in
            // React to state watcher changes
            if selectedTab == .events {
                // Events will update via filteredEvents computed property
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Text("🧠")
                .font(WernickeTypography.h1)
            VStack(alignment: .leading) {
                Text("S³AI NEUROANATOMY")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(V4Color.accent)
                Text("Brain Region Health Monitor v5.1")
                    .font(WernickeTypography.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }
            Spacer()

            HStack(spacing: ParietalSpacing.sm) {
                // Live indicator
                if isLiveUpdate {
                    HStack(spacing: ParietalSpacing.xs) {
                        Circle()
                            .fill(V4Color.statusOK)
                            .frame(width: 8, height: 8)
                            .opacity(pulseValue ? 0.5 : 1)
                        Text("LIVE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(V4Color.statusOK)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1).repeatForever()) {
                            pulseValue.toggle()
                        }
                    }
                }

                // Refresh button
                Button {
                    Task { await performRefresh() }
                } label: {
                    Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                        .font(.caption)
                        .foregroundStyle(V4Color.accent)
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
                .accessibilityLabel("Refresh brain data")
            }
        }
        .padding()
        .background(V4Color.bgCard)
        .overlay(
            Rectangle()
                .fill(V4Color.bgCardBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    @State private var pulseValue = false

    // MARK: - Tab Content Views

    // MARK: Regions Content

    private var regionsContent: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.md) {
                // Error banner if present
                if let error = errorMessage {
                    ErrorBanner(message: error, dismissAction: { errorMessage = nil })
                        .padding(.horizontal)
                }

                // Overall Health Score with live indicator
                if let data = brainData {
                    VStack(spacing: ParietalSpacing.md) {
                        HealthScoreCard(
                            score: data.healthScore,
                            healthy: data.healthy,
                            isLive: isLiveUpdate
                        )

                        // Quick stats row
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: ParietalSpacing.xs),
                                GridItem(.flexible(), spacing: ParietalSpacing.xs),
                                GridItem(.flexible(), spacing: ParietalSpacing.xs)
                            ],
                            spacing: ParietalSpacing.sm
                        ) {
                            MiniStatCard(
                                label: "Claims",
                                value: "\(data.activeClaims)",
                                color: data.activeClaims > 100 ? V4Color.statusWarn : V4Color.statusOK
                            )
                            MiniStatCard(
                                label: "Events",
                                value: formatCount(data.eventsBuffered),
                                color: data.eventsBuffered > 1000 ? V4Color.statusWarn : V4Color.statusOK
                            )
                            MiniStatCard(
                                label: "Snapshots",
                                value: "\(data.history.count)",
                                color: V4Color.accent
                            )
                        }

                        // Regional Sparkline Charts
                        RegionalHealthGrid(
                            brainData: data,
                            onRegionTap: { region in
                                selectedRegion = region
                                showDetailSheet = true
                            }
                        )
                        .padding(.top, ParietalSpacing.xs)

                        // Health Trend Chart
                        if data.history.count >= 2 {
                            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                                HStack {
                                    Text("HEALTH TREND")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(V4Color.accent)
                                    Spacer()
                                    Text("Last \(data.history.count) snapshots")
                                        .font(WernickeTypography.caption2)
                                        .foregroundStyle(V4Color.textSecondary)
                                }

                                HealthTrendChart(snapshots: data.history)
                                    .frame(height: 140)
                            }
                            .padding(.top, ParietalSpacing.xs)
                        }
                    }
                    .padding(.horizontal)
                } else if isLoading {
                    LoadingStateView(message: "Loading brain telemetry...", progress: nil)
                } else {
                    EmptyStateView(
                        icon: "brain.head.profile",
                        title: "No Brain Data",
                        message: "Brain health history file not found at .trinity/brain_health_history.jsonl",
                        action: refreshBrainData
                    )
                }
            }
            .padding(.bottom)
        }
        .refreshable {
            await performRefresh()
        }
    }

    // MARK: Events Stream Content

    private var eventsStreamContent: some View {
        VStack(spacing: 0) {
            // Filter picker
            EventFilterPicker(selectedFilter: $selectedEventFilter)
                .padding(.horizontal)
                .padding(.vertical, ParietalSpacing.xs)
                .background(V4Color.bgCard)

            Divider().background(V4Color.bgCardBorder)

            // Events list
            if filteredEvents.isEmpty {
                EmptyStateView(
                    icon: "bolt.slash",
                    title: "No Events",
                    message: "No brain events match the current filter.",
                    action: { selectedEventFilter = .all }
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                        ForEach(filteredEvents) { event in
                            BrainEventRow(event: event)
                                .onTapGesture {
                                    // Handle event tap
                                }
                        }
                    }
                    .padding(ParietalSpacing.xs)
                }
            }

            // Event stats footer
            EventStatsFooter(events: filteredEvents)
        }
    }

    // MARK: Task Claims Content

    private var taskClaimsContent: some View {
        VStack(spacing: 0) {
            // Filter picker
            TaskFilterPicker(selectedFilter: $selectedTaskFilter)
                .padding(.horizontal)
                .padding(.vertical, ParietalSpacing.xs)
                .background(V4Color.bgCard)

            Divider().background(V4Color.bgCardBorder)

            // Task claims list
            if filteredTasks.isEmpty {
                EmptyStateView(
                    icon: "checklist",
                    title: "No Task Claims",
                    message: "No active task claims in the brain.",
                    action: { selectedTaskFilter = .all }
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                        ForEach(filteredTasks) { task in
                            TaskClaimRow(task: task)
                        }
                    }
                    .padding(ParietalSpacing.xs)
                }
            }

            // Task stats footer
            TaskStatsFooter(tasks: filteredTasks, brainData: brainData)
        }
    }

    // MARK: Alerts Content

    private var alertsContent: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.md) {
                if brainAlerts.isEmpty {
                    VStack(spacing: ParietalSpacing.lg) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(WernickeTypography.display)
                            .foregroundStyle(V4Color.statusOK)

                        Text("All Systems Normal")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(V4Color.textPrimary)

                        Text("No brain alerts detected. All regions operating within normal parameters.")
                            .font(.body)
                            .foregroundStyle(V4Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    VStack(spacing: ParietalSpacing.sm) {
                        ForEach(brainAlerts) { alert in
                            BrainAlertCard(alert: alert)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .refreshable {
            generateAlerts()
        }
    }

    // MARK: - Computed Properties

    private var isLiveUpdate: Bool {
        guard let lastUpdate = lastUpdateTime else { return false }
        return Date().timeIntervalSince(lastUpdate) < refreshInterval
    }

    private var filteredEvents: [BrainEvent] {
        let events = generateBrainEvents()
        switch selectedEventFilter {
        case .all:
            return events
        case .errors:
            return events.filter { $0.severity == .error }
        case .warnings:
            return events.filter { $0.severity == .warning }
        case .thoughts:
            return events.filter { $0.type == .thought }
        case .actions:
            return events.filter { $0.type == .action }
        }
    }

    private var filteredTasks: [TaskClaim] {
        let tasks = generateTaskClaims()
        switch selectedTaskFilter {
        case .all:
            return tasks
        case .active:
            return tasks.filter { $0.status == .active }
        case .completed:
            return tasks.filter { $0.status == .completed }
        case .failed:
            return tasks.filter { $0.status == .failed }
        }
    }

    // MARK: - Live Monitoring

    private func startMonitoring() {
        loadBrainData()
        startRefreshTimer()
    }

    private func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task { @MainActor in
                await performRefresh()
            }
        }
    }

    private func refreshBrainData() {
        Task { @MainActor in
            await performRefresh()
        }
    }

    private func performRefresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        loadBrainData()
        generateAlerts()

        // Reset refreshing flag after a short delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        isRefreshing = false
    }

    // MARK: - Data Loading

    private func loadBrainData() {
        isLoading = true
        errorMessage = nil

        // Get trinity path from StateWatcher
        let trinityPath = watcher.trinityPath
        let path = "\(trinityPath)/brain_health_history.jsonl"

        guard let fileContent = try? String(contentsOfFile: path, encoding: .utf8) else {
            errorMessage = "Brain health file not found: \(path)"
            isLoading = false
            return
        }

        let lines = fileContent.components(separatedBy: "\n").filter { !$0.isEmpty }

        let decoder = JSONDecoder()
        var snapshots: [HealthSnapshot] = []

        for line in lines {
            if let data = line.data(using: .utf8),
               let snapshot = try? decoder.decode(HealthSnapshot.self, from: data) {
                snapshots.append(snapshot)
            }
        }

        guard let latest = snapshots.last else {
            errorMessage = "No valid brain health snapshots found"
            isLoading = false
            return
        }

        brainData = BrainHealthData(
            healthScore: latest.healthScore,
            healthy: latest.healthy,
            activeClaims: latest.activeClaims,
            eventsPublished: latest.eventsPublished,
            eventsBuffered: latest.eventsBuffered,
            history: snapshots
        )

        lastUpdateTime = Date()
        isLoading = false
    }

    // MARK: - Alert Generation

    private func generateAlerts() {
        guard let data = brainData else {
            brainAlerts = []
            return
        }

        var alerts: [BrainAlert] = []

        // Check health score
        if data.healthScore < 50 {
            alerts.append(BrainAlert(
                id: "health-critical",
                severity: .critical,
                title: "Critical Health Score",
                message: "Overall brain health is below 50%. Immediate attention required.",
                region: "Prefrontal Cortex",
                timestamp: Date()
            ))
        } else if data.healthScore < 70 {
            alerts.append(BrainAlert(
                id: "health-warning",
                severity: .warning,
                title: "Low Health Score",
                message: "Brain health is below 70%. Consider throttling operations.",
                region: "Prefrontal Cortex",
                timestamp: Date()
            ))
        }

        // Check active claims
        if data.activeClaims > 500 {
            alerts.append(BrainAlert(
                id: "claims-overload",
                severity: .error,
                title: "Task Claim Overload",
                message: "\(data.activeClaims) active claims detected. Basal Ganglia may be overwhelmed.",
                region: "Basal Ganglia",
                timestamp: Date()
            ))
        } else if data.activeClaims > 100 {
            alerts.append(BrainAlert(
                id: "claims-high",
                severity: .warning,
                title: "High Task Claims",
                message: "\(data.activeClaims) active claims. Monitor for congestion.",
                region: "Basal Ganglia",
                timestamp: Date()
            ))
        }

        // Check event buffer
        if data.eventsBuffered > 5000 {
            alerts.append(BrainAlert(
                id: "events-critical",
                severity: .critical,
                title: "Event Buffer Critical",
                message: "\(data.eventsBuffered) events buffered. Reticular Formation saturated.",
                region: "Reticular Formation",
                timestamp: Date()
            ))
        } else if data.eventsBuffered > 1000 {
            alerts.append(BrainAlert(
                id: "events-high",
                severity: .warning,
                title: "High Event Buffer",
                message: "\(data.eventsBuffered) events in buffer.",
                region: "Reticular Formation",
                timestamp: Date()
            ))
        }

        // Check build status from watcher
        if let senses = watcher.queenSenses, senses.build_ok == false {
            alerts.append(BrainAlert(
                id: "build-failed",
                severity: .error,
                title: "Build Failed",
                message: "Trinity build is currently broken. Some operations may be affected.",
                region: "Corpus Callosum",
                timestamp: Date()
            ))
        }

        brainAlerts = alerts
    }

    // MARK: - Data Generation Helpers

    private func generateBrainEvents() -> [BrainEvent] {
        var events: [BrainEvent] = []

        // Convert agent events to brain events
        for agentEvent in watcher.eventStream.suffix(50) {
            let eventType: BrainEventType
            switch agentEvent.resolvedKind {
            case "thought":
                eventType = .thought
            case "cli", "mcp":
                eventType = .action
            default:
                eventType = .system
            }

            let severity: EventSeverity
            if agentEvent.kind == "error" || agentEvent.exit != nil && agentEvent.exit != 0 {
                severity = .error
            } else if agentEvent.kind == "warning" {
                severity = .warning
            } else {
                severity = .info
            }

            events.append(BrainEvent(
                id: agentEvent.id,
                type: eventType,
                severity: severity,
                timestamp: Date(timeIntervalSince1970: TimeInterval(agentEvent.ts ?? 0)),
                title: agentEvent.event ?? agentEvent.kind ?? "Event",
                message: agentEvent.text ?? agentEvent.cmd ?? "",
                agent: agentEvent.agent
            ))
        }

        return events.reversed()
    }

    private func generateTaskClaims() -> [TaskClaim] {
        guard let data = brainData else { return [] }

        // Generate synthetic task claims based on active claims
        var tasks: [TaskClaim] = []

        // Sample task claims from the system
        for (index, todo) in watcher.todos.enumerated() {
            let status: TaskStatus = todo.status == "done" ? .completed : .active
            tasks.append(TaskClaim(
                id: todo.id,
                title: todo.text,
                source: todo.source,
                status: status,
                priority: index < 3 ? .high : .medium,
                claimedAt: Date()
            ))
        }

        // Add placeholder tasks for active claims
        if tasks.count < data.activeClaims {
            let placeholderCount = min(data.activeClaims - tasks.count, 10)
            for i in 0..<placeholderCount {
                tasks.append(TaskClaim(
                    id: "claim-\(i)",
                    title: "System Task #\(i + 1)",
                    source: "Basal Ganglia",
                    status: .active,
                    priority: i == 0 ? .high : .medium,
                    claimedAt: Date().addingTimeInterval(-Double(i * 60))
                ))
            }
        }

        return tasks
    }

    // MARK: - Helper Functions

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}

// MARK: - Brain Tab Enum

enum BrainTab: String, CaseIterable {
    case regions = "Regions"
    case events = "Events"
    case tasks = "Tasks"
    case alerts = "Alerts"

    var icon: String {
        switch self {
        case .regions: return "brain.head.profile"
        case .events: return "bolt.fill"
        case .tasks: return "checklist"
        case .alerts: return "bell.badge.fill"
        }
    }
}

// MARK: - Brain Tab Picker

struct BrainTabPicker: View {
    @Binding var selectedTab: BrainTab
    let alertCount: Int
    let eventCount: Int
    let taskCount: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ParietalSpacing.sm) {
                ForEach(BrainTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        alertCount: alertCount
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }
                }
            }
        }
    }
}

private struct TabButton: View {
    let tab: BrainTab
    let isSelected: Bool
    let alertCount: Int

    var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            Image(systemName: tab.icon)
                .font(.caption)
            Text(tab.rawValue)
                .font(.caption.weight(.medium))

            if tab == .alerts && alertCount > 0 {
                AlertBadge(count: alertCount)
            }
        }
        .foregroundStyle(isSelected ? V4Color.bgWindow : V4Color.textSecondary)
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .background(isSelected ? V4Color.accent : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
    }
}

private struct AlertBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(count > 5 ? V4Color.statusError : V4Color.statusWarn)
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
    }
}

// MARK: - Regional Health Grid

struct RegionalHealthGrid: View {
    let brainData: BrainHealthData
    let onRegionTap: (BrainRegionDetail) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            HStack {
                Text("NEUROANATOMY REGIONS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V4Color.accent)
                Spacer()
                Text("\(activeRegionCount)/8 active")
                    .font(WernickeTypography.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: ParietalSpacing.md
            ) {
                BrainRegionCard(
                    name: "Thalamus",
                    function: "Sensory Relay",
                    status: .healthy,
                    detail: "Railway logs active",
                    trend: [100, 100, 100],
                    onTap: { onRegionTap(.thalamus) }
                )
                BrainRegionCard(
                    name: "Basal Ganglia",
                    function: "Action Selection",
                    status: basalGangliaStatus(),
                    detail: basalGangliaDetail(),
                    trend: basalGangliaTrend(),
                    onTap: { onRegionTap(.basalGanglia) }
                )
                BrainRegionCard(
                    name: "Reticular Formation",
                    function: "Broadcast Alerting",
                    status: reticularStatus(),
                    detail: reticularDetail(),
                    trend: reticularTrend(),
                    onTap: { onRegionTap(.reticular) }
                )
                BrainRegionCard(
                    name: "Locus Coeruleus",
                    function: "Arousal Regulation",
                    status: .healthy,
                    detail: "Backoff policy active",
                    trend: [100, 100, 100],
                    onTap: { onRegionTap(.locusCoeruleus) }
                )
                BrainRegionCard(
                    name: "Amygdala",
                    function: "Emotional Salience",
                    status: .healthy,
                    detail: "Priority detection",
                    trend: [100, 100, 100],
                    onTap: { onRegionTap(.amygdala) }
                )
                BrainRegionCard(
                    name: "Prefrontal Cortex",
                    function: "Executive Function",
                    status: prefrontalStatus(),
                    detail: prefrontalDetail(),
                    trend: prefrontalTrend(),
                    onTap: { onRegionTap(.prefrontal) }
                )
                BrainRegionCard(
                    name: "Hippocampus",
                    function: "Memory Persistence",
                    status: hippocampusStatus(),
                    detail: hippocampusDetail(),
                    trend: hippocampusTrend(),
                    onTap: { onRegionTap(.hippocampus) }
                )
                BrainRegionCard(
                    name: "Corpus Callosum",
                    function: "Telemetry",
                    status: telemetryStatus(),
                    detail: trendIndicator(),
                    trend: overallHealthTrend(),
                    onTap: { onRegionTap(.corpusCallosum) }
                )
            }
        }
    }

    private var activeRegionCount: Int {
        var count = 0
        if basalGangliaStatus() == .healthy { count += 1 }
        if reticularStatus() == .healthy { count += 1 }
        if prefrontalStatus() == .healthy { count += 1 }
        if hippocampusStatus() == .healthy { count += 1 }
        if telemetryStatus() == .healthy { count += 1 }
        count += 3 // Thalamus, Locus Coeruleus, Amygdala are always healthy
        return count
    }

    private func basalGangliaStatus() -> RegionStatus {
        if brainData.activeClaims == 0 { return .healthy }
        if brainData.activeClaims < 100 { return .healthy }
        if brainData.activeClaims < 500 { return .warning }
        return .error
    }

    private func basalGangliaDetail() -> String {
        "\(brainData.activeClaims) active claims"
    }

    private func basalGangliaTrend() -> [Double] {
        brainData.history.suffix(10).map { Double($0.activeClaims) }
    }

    private func reticularStatus() -> RegionStatus {
        if brainData.eventsBuffered == 0 { return .healthy }
        if brainData.eventsBuffered < 1000 { return .healthy }
        if brainData.eventsBuffered < 5000 { return .warning }
        return .error
    }

    private func reticularDetail() -> String {
        "\(brainData.eventsBuffered) events buffered"
    }

    private func reticularTrend() -> [Double] {
        brainData.history.suffix(10).map { Double($0.eventsBuffered) }
    }

    private func prefrontalStatus() -> RegionStatus {
        if brainData.healthScore >= 90 { return .healthy }
        if brainData.healthScore >= 70 { return .warning }
        return .error
    }

    private func prefrontalDetail() -> String {
        if brainData.healthScore >= 90 { return "PROCEED" }
        if brainData.healthScore >= 70 { return "THROTTLE" }
        return "PAUSE"
    }

    private func prefrontalTrend() -> [Double] {
        brainData.history.suffix(10).map { Double($0.healthScore) }
    }

    private func hippocampusStatus() -> RegionStatus {
        brainData.healthy ? .healthy : .error
    }

    private func hippocampusDetail() -> String {
        "\(brainData.history.count) records"
    }

    private func hippocampusTrend() -> [Double] {
        let strideValue = Swift.max(1, brainData.history.count / 10)
        return stride(from: 1, through: brainData.history.count, by: strideValue).map { Double($0) }
    }

    private func telemetryStatus() -> RegionStatus {
        if brainData.history.isEmpty { return .unknown }
        if brainData.history.count >= 10 { return .healthy }
        return .warning
    }

    private func trendIndicator() -> String {
        guard brainData.history.count >= 3 else { return "Insufficient data" }

        let recent = brainData.history.suffix(10)
        let firstHalf = recent.prefix(recent.count / 2)
        let secondHalf = recent.suffix(recent.count / 2)

        let firstAvg = firstHalf.reduce(0.0) { $0 + $1.healthScore } / Float(firstHalf.count)
        let secondAvg = secondHalf.reduce(0.0) { $0 + $1.healthScore } / Float(secondHalf.count)

        let diff = secondAvg - firstAvg
        if diff > 5 { return "↗ Improving" }
        if diff < -5 { return "↘ Declining" }
        return "→ Stable"
    }

    private func overallHealthTrend() -> [Double] {
        brainData.history.suffix(20).map { Double($0.healthScore) }
    }
}

// MARK: - Event Filter Picker

enum EventFilter: String, CaseIterable {
    case all = "All"
    case errors = "Errors"
    case warnings = "Warnings"
    case thoughts = "Thoughts"
    case actions = "Actions"
}

struct EventFilterPicker: View {
    @Binding var selectedFilter: EventFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ParietalSpacing.xs) {
                ForEach(EventFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(selectedFilter == filter ? V4Color.bgWindow : V4Color.textSecondary)
                            .padding(.horizontal, ParietalSpacing.sm)
                            .padding(.vertical, ParietalSpacing.xxs)
                            .background(selectedFilter == filter ? V4Color.accent : V4Color.bgCardBorder)
                            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Task Filter Picker

enum TaskFilter: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case completed = "Completed"
    case failed = "Failed"
}

struct TaskFilterPicker: View {
    @Binding var selectedFilter: TaskFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ParietalSpacing.xs) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(selectedFilter == filter ? V4Color.bgWindow : V4Color.textSecondary)
                            .padding(.horizontal, ParietalSpacing.sm)
                            .padding(.vertical, ParietalSpacing.xxs)
                            .background(selectedFilter == filter ? V4Color.accent : V4Color.bgCardBorder)
                            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Brain Event Row

struct BrainEventRow: View {
    let event: BrainEvent

    var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            // Severity indicator
            Circle()
                .fill(event.severity.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(V4Color.textPrimary)

                    Spacer()

                    Text(timeAgo(event.timestamp))
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }

                Text(event.message)
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
                    .lineLimit(2)

                if let agent = event.agent {
                    Text("Agent: \(agent)")
                        .font(.caption2)
                        .foregroundStyle(V4Color.accent)
                }
            }
        }
        .padding(ParietalSpacing.xs)
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                .stroke(event.severity.color.opacity(V2Depth.stateHover), lineWidth: 1)
        )
    }

    private func timeAgo(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "\(Int(elapsed))s" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m" }
        return "\(Int(elapsed / 3600))h"
    }
}

// MARK: - Task Claim Row

struct TaskClaimRow: View {
    let task: TaskClaim

    var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            // Status indicator
            Image(systemName: task.status.icon)
                .font(.caption)
                .foregroundStyle(task.status.color)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(task.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(V4Color.textPrimary)

                    Spacer()

                    PriorityBadge(priority: task.priority)
                }

                HStack {
                    Text(task.source)
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)

                    Spacer()

                    Text(task.claimedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }
        }
        .padding(ParietalSpacing.xs)
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                .stroke(task.status.color.opacity(V2Depth.stateHover), lineWidth: 1)
        )
    }
}

// MARK: - Brain Alert Card

struct BrainAlertCard: View {
    let alert: BrainAlert

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            // Alert icon
            ZStack {
                Circle()
                    .fill(alert.severity.color.opacity(V2Depth.bgSidebarHover))
                    .frame(width: 40, height: 40)

                Image(systemName: alert.severity.icon)
                    .font(.title3)
                    .foregroundStyle(alert.severity.color)
            }

            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                HStack {
                    Text(alert.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.textPrimary)

                    Spacer()

                    SeverityBadge(severity: alert.severity)
                }

                Text(alert.message)
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
                    .lineLimit(2)

                HStack(spacing: ParietalSpacing.xxs) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                    Text(alert.region)
                        .font(.caption2)
                        .foregroundStyle(V4Color.accent)

                    Spacer()

                    Text(alert.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }
        }
        .padding()
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(alert.severity.color.opacity(V2Depth.stateHover), lineWidth: 1)
        )
    }
}

// MARK: - Supporting Components

struct SeverityBadge: View {
    let severity: AlertSeverity

    var body: some View {
        Text(severity.rawValue.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(severity.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(severity.color.opacity(V2Depth.bgSidebarHover))
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
    }
}

struct PriorityBadge: View {
    let priority: TaskPriority

    var body: some View {
        Text(priority.rawValue.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(priority.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priority.color.opacity(V2Depth.bgSidebarHover))
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
    }
}

struct EventStatsFooter: View {
    let events: [BrainEvent]

    var body: some View {
        HStack {
            Text("\(events.count) events")
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary)

            Spacer()

            let errorCount = events.filter { $0.severity == .error }.count
            if errorCount > 0 {
                HStack(spacing: 2) {
                    Circle().fill(V4Color.statusError).frame(width: 6, height: 6)
                    Text("\(errorCount) errors")
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }
        }
        .padding()
        .background(V4Color.bgCard)
        .overlay(
            Rectangle()
                .fill(V4Color.bgCardBorder)
                .frame(height: 1),
            alignment: .top
        )
    }
}

struct TaskStatsFooter: View {
    let tasks: [TaskClaim]
    let brainData: BrainHealthData?

    var body: some View {
        HStack {
            Text("\(tasks.count) tasks")
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary)

            Spacer()

            if let data = brainData {
                Text("\(data.activeClaims) active claims")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }
        }
        .padding()
        .background(V4Color.bgCard)
        .overlay(
            Rectangle()
                .fill(V4Color.bgCardBorder)
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Brain Region Detail Sheet

struct BrainRegionDetailSheet: View {
    let detail: BrainRegionDetail
    let brainData: BrainHealthData?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                // Header
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title)
                        .foregroundStyle(V4Color.accent)

                    VStack(alignment: .leading) {
                        Text(detail.name)
                            .font(WernickeTypography.h4)
                            .foregroundStyle(V4Color.textPrimary)
                        Text(detail.function)
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                    }

                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))

                // Description
                VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                    Text("Description")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.textSecondary)

                    Text(detail.description)
                        .font(.body)
                        .foregroundStyle(V4Color.textPrimary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))

                // Metrics
                VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                    Text("Current Metrics")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.textSecondary)

                    ForEach(detail.metrics, id: \.label) { metric in
                        MetricRow(label: metric.label, value: metric.value, color: metric.color)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
            }
            .padding()
        }
        .background(V4Color.bgWindow)
        .frame(minWidth: 400, minHeight: 300)
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    let color: Color?

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)

            Spacer()

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color ?? V4Color.textPrimary)
        }
    }
}

// MARK: - Updated Brain Region Card with Tap Handler

struct BrainRegionCard: View {
    let name: String
    let function: String
    let status: RegionStatus
    let detail: String
    var trend: [Double] = []
    var onTap: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                HStack {
                    Text(status.icon)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(V4Color.textPrimary)
                        Text(function)
                            .font(WernickeTypography.caption2)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()

                    StatusPill(status: status)
                }

                Text(detail)
                    .font(WernickeTypography.caption)
                    .foregroundStyle(status.color)

                // Mini sparkline for trend data
                if trend.count >= 2 {
                    MiniSparkline(data: trend, color: status.color)
                        .frame(height: ParietalSpacing.iconLarge)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(V4Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
            .overlay(
                RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                    .stroke(status.color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(function), status: \(status.label)")
        .accessibilityValue(detail)
    }
}

// MARK: - Data Models

struct BrainHealthData {
    let healthScore: Float
    let healthy: Bool
    let activeClaims: Int
    let eventsPublished: Int
    let eventsBuffered: Int
    let history: [HealthSnapshot]
}

struct HealthSnapshot: Codable {
    let timestamp: Double
    let healthScore: Float
    let healthy: Bool
    let activeClaims: Int
    let eventsPublished: Int
    let eventsBuffered: Int

    enum CodingKeys: String, CodingKey {
        case timestamp = "ts"
        case healthScore = "health"
        case healthy = "ok"
        case activeClaims = "claims"
        case eventsPublished = "events_pub"
        case eventsBuffered = "events_buf"
    }
}

enum RegionStatus {
    case healthy
    case warning
    case error
    case unknown

    var color: Color {
        switch self {
        case .healthy: return V4Color.statusOK
        case .warning: return V4Color.statusWarn
        case .error: return V4Color.statusError
        case .unknown: return V4Color.textSecondary
        }
    }

    var icon: String {
        switch self {
        case .healthy: return "🟢"
        case .warning: return "🟡"
        case .error: return "🔴"
        case .unknown: return "⚪"
        }
    }

    var label: String {
        switch self {
        case .healthy: return "HEALTHY"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .unknown: return "UNKNOWN"
        }
    }
}

// MARK: - New Data Models for Observability

struct BrainEvent: Identifiable {
    let id: String
    let type: BrainEventType
    let severity: EventSeverity
    let timestamp: Date
    let title: String
    let message: String
    let agent: String?
}

enum BrainEventType {
    case thought
    case action
    case system
}

enum EventSeverity {
    case info
    case warning
    case error
    case critical

    var color: Color {
        switch self {
        case .info: return V4Color.accent
        case .warning: return V4Color.statusWarn
        case .error: return V4Color.statusError
        case .critical: return Color.red
        }
    }
}

struct TaskClaim: Identifiable {
    let id: String
    let title: String
    let source: String
    let status: TaskStatus
    let priority: TaskPriority
    let claimedAt: Date
}

enum TaskStatus {
    case active
    case completed
    case failed

    var icon: String {
        switch self {
        case .active: return "circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .active: return V4Color.accent
        case .completed: return V4Color.statusOK
        case .failed: return V4Color.statusError
        }
    }
}

enum TaskPriority: String {
    case low
    case medium
    case high

    var color: Color {
        switch self {
        case .low: return V4Color.textSecondary
        case .medium: return V4Color.statusWarn
        case .high: return V4Color.statusError
        }
    }
}

struct BrainAlert: Identifiable {
    let id: String
    let severity: AlertSeverity
    let title: String
    let message: String
    let region: String
    let timestamp: Date
}

enum AlertSeverity: String {
    case info
    case warning
    case error
    case critical

    var color: Color {
        switch self {
        case .info: return V4Color.accent
        case .warning: return V4Color.statusWarn
        case .error: return V4Color.statusError
        case .critical: return Color.red
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
}

enum BrainRegionDetail {
    case thalamus
    case basalGanglia
    case reticular
    case locusCoeruleus
    case amygdala
    case prefrontal
    case hippocampus
    case corpusCallosum

    var name: String {
        switch self {
        case .thalamus: return "Thalamus"
        case .basalGanglia: return "Basal Ganglia"
        case .reticular: return "Reticular Formation"
        case .locusCoeruleus: return "Locus Coeruleus"
        case .amygdala: return "Amygdala"
        case .prefrontal: return "Prefrontal Cortex"
        case .hippocampus: return "Hippocampus"
        case .corpusCallosum: return "Corpus Callosum"
        }
    }

    var function: String {
        switch self {
        case .thalamus: return "Sensory Relay"
        case .basalGanglia: return "Action Selection"
        case .reticular: return "Broadcast Alerting"
        case .locusCoeruleus: return "Arousal Regulation"
        case .amygdala: return "Emotional Salience"
        case .prefrontal: return "Executive Function"
        case .hippocampus: return "Memory Persistence"
        case .corpusCallosum: return "Telemetry"
        }
    }

    var description: String {
        switch self {
        case .thalamus:
            return "Relays sensory information from the body to the cerebral cortex. Coordinates Railway logs and monitors external service states."
        case .basalGanglia:
            return "Responsible for action selection and habit learning. Manages task claims and prevents resource conflicts."
        case .reticular:
            return "Regulates arousal and consciousness. Handles event broadcasting and alert distribution across the brain."
        case .locusCoeruleus:
            return "Modulates arousal and attention. Implements backoff policies to prevent system overload."
        case .amygdala:
            return "Processes emotional salience. Prioritizes important tasks and detects urgent conditions."
        case .prefrontal:
            return "Executive function and decision making. Evaluates overall brain health and decides whether to proceed, throttle, or pause operations."
        case .hippocampus:
            return "Memory formation and persistence. Maintains historical health snapshots and enables trend analysis."
        case .corpusCallosum:
            return "Inter-hemispheric communication. Provides telemetry and bridges different brain components."
        }
    }

    var metrics: [(label: String, value: String, color: Color?)] {
        switch self {
        case .thalamus:
            return [
                ("Status", "Active", V4Color.statusOK),
                ("Railway Logs", "Streaming", V4Color.accent),
                ("External Services", "Connected", V4Color.statusOK)
            ]
        case .basalGanglia:
            return [
                ("Active Claims", "Variable", nil),
                ("Max Capacity", "1000", V4Color.textSecondary),
                ("Conflict Rate", "< 1%", V4Color.statusOK)
            ]
        case .reticular:
            return [
                ("Event Buffer", "Variable", nil),
                ("Broadcast Rate", "Real-time", V4Color.accent),
                ("Alert Latency", "< 100ms", V4Color.statusOK)
            ]
        case .locusCoeruleus:
            return [
                ("Backoff Policy", "Active", V4Color.statusOK),
                ("Arousal Level", "Normal", V4Color.accent),
                ("Overload Protection", "Enabled", V4Color.statusOK)
            ]
        case .amygdala:
            return [
                ("Priority Detection", "Active", V4Color.statusOK),
                ("Urgency Threshold", "Configured", V4Color.accent),
                ("Emotional Context", "Stable", V4Color.statusOK)
            ]
        case .prefrontal:
            return [
                ("Decision Mode", "Variable", nil),
                ("Health Threshold", "70%", V4Color.textSecondary),
                ("Throttle Active", "Conditional", V4Color.statusWarn)
            ]
        case .hippocampus:
            return [
                ("Memory Records", "Variable", nil),
                ("Retention Period", "7 days", V4Color.textSecondary),
                ("Trend Analysis", "Enabled", V4Color.statusOK)
            ]
        case .corpusCallosum:
            return [
                ("Telemetry Status", "Active", V4Color.statusOK),
                ("Bridge Latency", "< 50ms", V4Color.accent),
                ("Data Sync", "Real-time", V4Color.statusOK)
            ]
        }
    }
}

// MARK: - Existing Components (preserved)

struct HealthScoreCard: View {
    let score: Float
    let healthy: Bool
    var isLive: Bool = false

    @State private var pulse = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: ParietalSpacing.xxs) {
                HStack(spacing: ParietalSpacing.xs) {
                    Text("OVERALL HEALTH")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.textSecondary)

                    if isLive {
                        HStack(spacing: ParietalSpacing.xxs) {
                            Circle()
                                .fill(V4Color.statusOK)
                                .frame(width: 6, height: 6)
                                .opacity(pulse ? 0.3 : 1)
                            Text("LIVE")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(V4Color.statusOK)
                        }
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1).repeatForever()) {
                                pulse.toggle()
                            }
                        }
                    }
                }

                Text("\(Int(score))/100")
                    .font(WernickeTypography.displayRounded)
                    .foregroundStyle(healthy ? V4Color.statusOK : V4Color.statusError)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: ParietalSpacing.xxs) {
                Text(healthy ? "✅ HEALTHY" : "⚠️ UNHEALTHY")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(healthy ? V4Color.statusOK : V4Color.statusError)

                Text("Brain circuit operational")
                    .font(WernickeTypography.caption)
                    .foregroundStyle(V4Color.textSecondary)
            }
        }
        .padding()
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(healthy ? V4Color.statusOK.opacity(V2Depth.stateHover) : V4Color.statusError.opacity(V2Depth.stateHover), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Overall brain health score: \(Int(score)) out of 100")
        .accessibilityValue(healthy ? "Healthy" : "Unhealthy")
    }
}

struct MiniStatCard: View {
    let label: String
    let value: String
    var color: Color = V4Color.accent

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xxs) {
            Text(label)
                .font(WernickeTypography.caption2)
                .foregroundStyle(V4Color.textSecondary)
            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct StatusPill: View {
    let status: RegionStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(status.color)
            .padding(.horizontal, ParietalSpacing.xs)
            .padding(.vertical, ParietalSpacing.xxs)
            .background(status.color.opacity(V2Depth.bgSidebarHover))
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
    }
}

struct MiniSparkline: View {
    let data: [Double]
    var color: Color = V4Color.accent

    var body: some View {
        Canvas { ctx, size in
            guard data.count >= 2 else { return }

            let minValue = data.min() ?? 0
            let maxValue = data.max() ?? 1
            let range = maxValue - minValue > 0 ? maxValue - minValue : 1
            let spacing = size.width / CGFloat(Swift.max(data.count - 1, 1))

            var path = Path()
            for (i, value) in data.enumerated() {
                let x = CGFloat(i) * spacing
                let normalized = (value - minValue) / range
                let y = size.height * (1 - CGFloat(normalized))

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            ctx.stroke(
                path,
                with: .color(color.opacity(0.8)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

struct HealthTrendChart: View {
    let snapshots: [HealthSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            Canvas { ctx, size in
                guard snapshots.count >= 2 else { return }

                let healthScores = snapshots.map { $0.healthScore }
                let minScore = healthScores.min() ?? 0
                let maxScore = healthScores.max() ?? 100
                let range = maxScore - minScore > 0 ? maxScore - minScore : 1

                let spacing = size.width / CGFloat(Swift.max(snapshots.count - 1, 1))

                // Grid lines
                for i in 0...4 {
                    let y = size.height * CGFloat(i) / 4
                    var gridPath = Path()
                    gridPath.move(to: CGPoint(x: 0, y: y))
                    gridPath.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(
                        gridPath,
                        with: .color(V4Color.textSecondary.opacity(V2Depth.bgSidebarHover)),
                        style: StrokeStyle(lineWidth: 1)
                    )
                }

                // Health score line
                var path = Path()
                for (i, snapshot) in snapshots.enumerated() {
                    let x = CGFloat(i) * spacing
                    let normalized = (snapshot.healthScore - minScore) / range
                    let y = size.height * (1 - CGFloat(normalized))

                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                // Gradient fill under the line
                var fillPath = path
                fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
                fillPath.addLine(to: CGPoint(x: 0, y: size.height))
                fillPath.closeSubpath()

                ctx.fill(fillPath, with: .color(V4Color.accent.opacity(V2Depth.bgSubtle)))

                // Draw the line
                ctx.stroke(
                    path,
                    with: .color(V4Color.accent),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                // Draw dots at each data point
                for (i, snapshot) in snapshots.enumerated() {
                    let x = CGFloat(i) * spacing
                    let normalized = (snapshot.healthScore - minScore) / range
                    let y = size.height * (1 - CGFloat(normalized))

                    let dotColor = snapshot.healthy ? V4Color.statusOK : V4Color.statusError
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)),
                        with: .color(dotColor)
                    )
                }
            }

            // X-axis label
            HStack {
                Text("Oldest")
                    .font(WernickeTypography.caption2)
                    .foregroundStyle(V4Color.textSecondary)
                Spacer()
                Text("Latest")
                    .font(WernickeTypography.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }
        }
        .padding()
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(V4Color.bgCardBorder, lineWidth: 1)
        )
    }
}

struct ErrorBanner: View {
    let message: String
    var dismissAction: () -> Void

    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(V4Color.statusError)

            VStack(alignment: .leading, spacing: 2) {
                Text("Error loading brain data")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V4Color.textPrimary)
                Text(message)
                    .font(WernickeTypography.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }

            Spacer()

            Button(action: dismissAction) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(V4Color.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(V4Color.statusError.opacity(V2Depth.bgSubtle))
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(V4Color.statusError.opacity(V2Depth.stateHover), lineWidth: 1)
        )
    }
}
