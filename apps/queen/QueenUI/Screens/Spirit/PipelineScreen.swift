import SwiftUI

struct PipelineScreen: View {
    @State private var pipelineState: PipelineState?
    @State private var selectedStep: WorkflowDAG.DAGStep?
    @State private var selectedPipeline = "golden-chain"
    @State private var eventMetrics: PipelineMetrics = .empty

    struct PipelineState: Codable {
        let last_link: Int?
        let task: String?
        let status: String?
        let timestamp: Int?
        let total_links: Int?
    }

    struct PipelineMetrics {
        let totalRuns: Int
        let avgDurationSec: Int
        let successRate: Int
        static let empty = PipelineMetrics(totalRuns: 0, avgDurationSec: 0, successRate: 0)
    }

    private let pipelines = [
        ("golden-chain", "Golden Chain v5.1", "28-link full pipeline"),
        ("doctor-full", "Doctor Full", "Scan + mark + heal + report"),
        ("train-cycle", "Train Cycle", "Config → deploy → monitor → record"),
        ("deploy-full", "Deploy Full", "Build → test → push → verify"),
        ("research-deep", "Research Deep", "Search → analyze → summarize"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                // Header
                HStack {
                    Text("\u{26D3}")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("PIPELINE")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                        Text("Workflow DAG Visualizer")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                    ActionButton(icon: "\u{25B6}", label: "Run", color: V4Color.accent,
                                 action: "pipeline_run", params: ["pipeline": selectedPipeline])
                }
                .padding()

                // DAG Canvas
                dagSection

                // Selected step detail
                if let step = selectedStep {
                    stepDetailCard(step)
                        .padding(.horizontal)
                        .transition(.opacity)
                }

                // Pipeline List
                pipelineListSection

                // Metrics sidebar
                metricsSection
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
        .onAppear { loadData() }
    }

    // MARK: - DAG Canvas

    private var dagSection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            HStack {
                Text("GOLDEN CHAIN DAG")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V4Color.golden)
                Spacer()
                if let state = pipelineState {
                    Text("\(state.last_link ?? 0)/\(state.total_links ?? 28)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(V4Color.accent)
                    Text(state.status ?? "idle")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(statusColor(state.status))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor(state.status).opacity(V2Depth.bgSidebarHover))
                        .clipShape(SwiftUI.Capsule())
                }
            }
            .padding(.horizontal)

            WorkflowDAG(steps: buildDAGSteps()) { step in
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedStep = selectedStep?.id == step.id ? nil : step
                }
            }
            .frame(height: 220)
            .padding(.horizontal)
            .background(V4Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
            .overlay(
                RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                    .stroke(V4Color.bgCardBorder, lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }

    private func stepDetailCard(_ step: WorkflowDAG.DAGStep) -> some View {
        HStack(spacing: ParietalSpacing.md) {
            Circle()
                .fill(step.status.color)
                .frame(width: ParietalSpacing.mediumBadge, height: ParietalSpacing.badgeHeight)

            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                Text(step.label)
                    .font(.headline)
                    .foregroundStyle(V4Color.textPrimary)
                Text("Phase: \(step.phase)")
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
                if let dur = step.duration {
                    Text("Duration: \(dur)")
                        .font(.caption)
                        .foregroundStyle(V4Color.accent)
                }
                if let err = step.error {
                    Text("Error: \(err)")
                        .font(.caption)
                        .foregroundStyle(V4Color.statusError)
                }
            }

            Spacer()

            Button {
                withAnimation { selectedStep = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(V4Color.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(V4Color.bgCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Pipeline List

    private var pipelineListSection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            Text("AVAILABLE PIPELINES")
                .font(.caption.weight(.bold))
                .foregroundStyle(V4Color.purple)
                .padding(.horizontal)

            ForEach(pipelines, id: \.0) { id, name, desc in
                let isSelected = selectedPipeline == id

                Button {
                    selectedPipeline = id
                } label: {
                    HStack(spacing: ParietalSpacing.md) {
                        Circle()
                            .fill(isSelected ? V4Color.accent : V4Color.bgCardBorder)
                            .frame(width: ParietalSpacing.tinyIndicator, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.headline)
                                .foregroundStyle(isSelected ? V4Color.textPrimary : V4Color.textSecondary)
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(V4Color.textSecondary)
                        }
                        Spacer()

                        if isSelected {
                            ActionButton(icon: "\u{25B6}", label: "Run", color: V4Color.accent,
                                         action: "pipeline_run", params: ["pipeline": id])
                        }
                    }
                    .padding()
                    .background(isSelected ? V4Color.accent.opacity(0.05) : V4Color.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                    .overlay(
                        RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                            .stroke(isSelected ? V4Color.accent.opacity(V2Depth.stateHover) : V4Color.bgCardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            Text("PIPELINE METRICS")
                .font(.caption.weight(.bold))
                .foregroundStyle(V4Color.accent)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.sm) {
                StatCard(
                    label: "Total Runs",
                    value: "\(eventMetrics.totalRuns)",
                    accent: V4Color.accent
                )
                StatCard(
                    label: "Avg Duration",
                    value: eventMetrics.avgDurationSec > 0 ? "\(eventMetrics.avgDurationSec)s" : "N/A",
                    accent: V4Color.golden
                )
                StatCard(
                    label: "Success Rate",
                    value: eventMetrics.totalRuns > 0 ? "\(eventMetrics.successRate)%" : "N/A",
                    accent: V4Color.statusOK
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Data

    private func loadData() {
        loadPipeline()
        loadMetrics()
    }

    private func loadPipeline() {
        let path = "\(FileManager.default.currentDirectoryPath)/.trinity/pipeline_state.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
        pipelineState = try? JSONDecoder().decode(PipelineState.self, from: data)
    }

    private func loadMetrics() {
        let path = "\(FileManager.default.currentDirectoryPath)/.trinity/event_log.jsonl"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }

        var pipelineEvents = 0
        var successEvents = 0
        var totalDuration = 0

        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            if let kind = json["kind"] as? String, kind.contains("pipeline") {
                pipelineEvents += 1
                if let status = json["status"] as? String, status == "done" {
                    successEvents += 1
                }
                if let ms = json["ms"] as? Int {
                    totalDuration += ms / 1000
                }
            }
        }

        eventMetrics = PipelineMetrics(
            totalRuns: pipelineEvents,
            avgDurationSec: pipelineEvents > 0 ? totalDuration / pipelineEvents : 0,
            successRate: pipelineEvents > 0 ? (successEvents * 100) / pipelineEvents : 0
        )
    }

    private func buildDAGSteps() -> [WorkflowDAG.DAGStep] {
        let phases: [(range: String, name: String, links: [String])] = [
            ("1-5", "PLAN", ["Decompose", "Require", "Architect", "Validate", "Enrich"]),
            ("6-10", "SPEC", ["Write .tri", "Parse", "Validate", "Optimize", "Finalize"]),
            ("11-15", "CODE", ["Generate", "Compile", "Format", "Lint", "Link"]),
            ("16-20", "TEST", ["Unit", "Integration", "E2E", "Coverage", "Report"]),
            ("21-24", "REVIEW", ["Self-review", "Oracle", "Fix", "Approve"]),
            ("25-28", "SHIP", ["Commit", "PR", "Deploy", "Notify"]),
        ]

        let currentLink = pipelineState?.last_link ?? 0
        let pipelineStatus = pipelineState?.status ?? "idle"
        var linkIndex = 1
        var dagSteps: [WorkflowDAG.DAGStep] = []

        for phase in phases {
            for link in phase.links {
                let status: WorkflowDAG.DAGStep.StepStatus
                if pipelineStatus == "idle" {
                    status = .pending
                } else if linkIndex < currentLink {
                    status = .done
                } else if linkIndex == currentLink {
                    status = pipelineStatus == "failed" ? .failed : .running
                } else {
                    status = .pending
                }

                dagSteps.append(WorkflowDAG.DAGStep(
                    id: "\(linkIndex)",
                    label: link,
                    phase: phase.name,
                    status: status,
                    duration: nil,
                    error: linkIndex == currentLink && pipelineStatus == "failed" ? "Step failed" : nil
                ))
                linkIndex += 1
            }
        }

        return dagSteps
    }

    private func statusColor(_ status: String?) -> Color {
        switch status {
        case "running": return V4Color.golden
        case "done": return V4Color.statusOK
        case "failed": return V4Color.statusError
        default: return V4Color.textSecondary
        }
    }
}
