import SwiftUI

/// The Queen's command surface for her own development: what she measured,
/// what she ranked, which bees are working, and what is waiting on review.
struct HiveScreen: View {
    @StateObject private var hive = HiveOrchestrator.shared
    @State private var showPolicy = false
    @State private var manualTitle = ""
    @State private var manualInstruction = ""
    @State private var expandedTarget: String?
    @State private var tick = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                header
                // A loop the state file calls armed, with no clock behind it,
                // says so here rather than looking like health.
                if let advice = hive.loopStatus.advice {
                    blockerBanner(advice)
                }
                if let blocker = hive.blocker {
                    blockerBanner(blocker)
                }
                // A standing invariant is a pre-declared safety claim. When one
                // is broken the loop refuses to dispatch, so the operator needs
                // to read the same sentence the loop refused on.
                ForEach(hive.invariantViolations) { violation in
                    blockerBanner("standing invariant `\(violation.id)`: \(violation.detail)")
                }
                controls
                statsBar
                if showPolicy { policyPanel }
                liveBeesSection
                reviewSection
                prioritySection
                manualSection
                eventLogSection
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
        .onReceive(ticker) { tick = $0 }
        .task {
            if hive.targets.isEmpty { await hive.rescan() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("\u{1F41D}")
                .font(WernickeTypography.size48)
            VStack(alignment: .leading, spacing: 2) {
                Text("HIVE")
                    .font(.title.weight(.bold))
                    .foregroundStyle(V4Color.golden)
                Text(hive.statusLine)
                    .font(.subheadline)
                    .foregroundStyle(V4Color.textSecondary)
                HStack(spacing: ParietalSpacing.sm) {
                    if let last = hive.lastScanAt {
                        Text("scanned \(relative(last))")
                    }
                    // The countdown is shown only when a clock exists. Derived
                    // from the policy flag it kept counting down over a loop
                    // that had no timer at all.
                    if let next = hive.nextCycleAt, hive.loopStatus.isTicking {
                        Text("- next cycle \(countdown(to: next))")
                    }
                }
                .font(WernickeTypography.caption2)
                .foregroundStyle(V4Color.textTertiary)
            }
            Spacer()
            loopBadge
        }
        .padding()
    }

    /// Reads the clock, not the wish.
    ///
    /// `policy.enabled` is persisted and survives a restart; the timer does
    /// not. A badge derived from the policy showed 24/7 ARMED over a loop with
    /// a queue, no bees and no clock, for as long as the operator left it.
    private var loopBadge: some View {
        let status = hive.loopStatus
        let colour: Color = {
            switch status {
            case .ticking: return V4Color.statusOK
            case .resumeRequired: return V4Color.warning
            case .idle: return V4Color.textSecondary
            }
        }()
        return HStack(spacing: ParietalSpacing.xxs) {
            Circle()
                .fill(colour)
                .frame(width: ParietalSpacing.statusDot, height: ParietalSpacing.statusDot)
            Text(status.label)
                .font(WernickeTypography.caption2Bold)
                .foregroundStyle(colour)
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xxs)
        .background(colour.opacity(V4Color.opacity15))
        .clipShape(SwiftUI.Capsule())
    }

    private func blockerBanner(_ text: String) -> some View {
        HStack(spacing: ParietalSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(V4Color.error)
            Text(text)
                .font(WernickeTypography.caption)
                .foregroundStyle(V4Color.textPrimary)
            Spacer()
        }
        .padding()
        .background(V4Color.error.opacity(V4Color.opacity15))
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .padding(.horizontal)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: ParietalSpacing.sm) {
            // Run 24/7 is offered whenever no cycle is scheduled, including the
            // armed-but-not-ticking state a restart leaves behind. Keying this
            // off the policy flag hid the only button that could restore the
            // loop precisely when it was the only button that would work.
            if hive.loopStatus.isTicking {
                pill("\u{23F8}", "Pause loop", V4Color.warning) { hive.pause() }
                pill("\u{1F6D1}", "Stop all bees", V4Color.error) { hive.stopAll() }
            } else {
                pill("\u{25B6}", "Run 24/7", V4Color.statusOK) { hive.start() }
                if hive.policy.enabled {
                    pill("\u{23F8}", "Disarm", V4Color.warning) { hive.pause() }
                }
            }
            pill("\u{1F504}", "Cycle now", V4Color.accent) { hive.runCycleNow() }
            pill("\u{1F510}", "Preflight", V4Color.warning) { Task { await hive.preflight() } }
            pill("\u{1F4CF}", "Rescan", V4Color.purple) { Task { await hive.rescan() } }
            pill("\u{2699}", showPolicy ? "Hide policy" : "Policy", V4Color.textSecondary) {
                withAnimation { showPolicy.toggle() }
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    private func pill(_ icon: String, _ label: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ParietalSpacing.xxs) {
                Text(icon).font(WernickeTypography.caption)
                Text(label).font(WernickeTypography.captionBold)
            }
            .foregroundStyle(V4Color.textPrimary)
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xxs)
            .background(V4Color.surface)
            .clipShape(SwiftUI.Capsule())
            .overlay { SwiftUI.Capsule().stroke(color.opacity(0.64), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats

    private var statsBar: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 6),
            spacing: ParietalSpacing.sm
        ) {
            StatCard(label: "Bees", value: "\(hive.runningCount)", accent: V4Color.golden)
            StatCard(label: "Queued", value: "\(hive.schedulableTasks.count)", accent: V4Color.accent)
            StatCard(label: "Review", value: "\(hive.reviewCount)", accent: V4Color.warning)
            StatCard(label: "Done", value: "\(hive.doneCount)", accent: V4Color.statusOK)
            StatCard(
                label: "Spent today",
                value: String(format: "$%.2f", hive.spentToday),
                accent: hive.spentToday >= hive.policy.dailyBudgetUSD ? V4Color.error : V4Color.purple
            )
            StatCard(
                label: "Fails in a row",
                value: "\(hive.consecutiveFailures)/\(hive.policy.maxConsecutiveFailures)",
                accent: hive.consecutiveFailures > 0 ? V4Color.warning : V4Color.textSecondary
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Policy

    private var policyPanel: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            sectionTitle("GUARDRAILS", color: V4Color.purple)

            VStack(spacing: ParietalSpacing.xs) {
                stepperRow("Concurrent bees", value: hive.policy.maxConcurrentBees, range: 1...8) {
                    var p = hive.policy; p.maxConcurrentBees = $0; hive.updatePolicy(p)
                }
                stepperRow("Cycle interval (min)", value: hive.policy.cycleIntervalSeconds / 60, range: 1...240) {
                    var p = hive.policy; p.cycleIntervalSeconds = $0 * 60; hive.updatePolicy(p)
                }
                stepperRow("Attempts before toxic", value: hive.policy.maxAttemptsPerTask, range: 1...10) {
                    var p = hive.policy; p.maxAttemptsPerTask = $0; hive.updatePolicy(p)
                }
                stepperRow("Bees per hour", value: hive.policy.maxBeesPerHour, range: 1...60) {
                    var p = hive.policy; p.maxBeesPerHour = $0; hive.updatePolicy(p)
                }
                stepperRow("Targets per cycle", value: hive.policy.targetsPerCycle, range: 1...20) {
                    var p = hive.policy; p.targetsPerCycle = $0; hive.updatePolicy(p)
                }
                stepperRow("Bee timeout (min)", value: hive.policy.beeTimeoutSeconds / 60, range: 1...720) {
                    var p = hive.policy; p.beeTimeoutSeconds = $0 * 60; hive.updatePolicy(p)
                }
                stepperRow("Budget per bee ($)", value: Int(hive.policy.maxBudgetUSDPerBee), range: 1...100) {
                    var p = hive.policy; p.maxBudgetUSDPerBee = Double($0); hive.updatePolicy(p)
                }
                stepperRow("Daily ceiling ($)", value: Int(hive.policy.dailyBudgetUSD), range: 1...1000) {
                    var p = hive.policy; p.dailyBudgetUSD = Double($0); hive.updatePolicy(p)
                }
                stepperRow("Fails in a row -> pause", value: hive.policy.maxConsecutiveFailures, range: 1...20) {
                    var p = hive.policy; p.maxConsecutiveFailures = $0; hive.updatePolicy(p)
                }
                stepperRow("Keep transcripts (days)", value: hive.policy.retainTranscriptDays, range: 1...365) {
                    var p = hive.policy; p.retainTranscriptDays = $0; hive.updatePolicy(p)
                }

                toggleRow("Run the project's checks before review", isOn: hive.policy.verifyBeforeReview) {
                    var p = hive.policy; p.verifyBeforeReview = $0; hive.updatePolicy(p)
                }

                toggleRow("Isolate each bee in a git worktree", isOn: hive.policy.useWorktree) {
                    var p = hive.policy; p.useWorktree = $0; hive.updatePolicy(p)
                }
                toggleRow("Open a Queen chat per task", isOn: hive.policy.openChatPerTask) {
                    var p = hive.policy; p.openChatPerTask = $0; hive.updatePolicy(p)
                }
                toggleRow("Allow bees to push", isOn: hive.policy.allowPush) {
                    var p = hive.policy; p.allowPush = $0; hive.updatePolicy(p)
                }

                HStack {
                    Text("Model")
                        .font(WernickeTypography.caption)
                        .foregroundStyle(V4Color.textSecondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { hive.policy.model },
                        set: { var p = hive.policy; p.model = $0; hive.updatePolicy(p) }
                    )) {
                        Text("haiku").tag("haiku")
                        Text("sonnet").tag("sonnet")
                        Text("opus").tag("opus")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: ParietalSpacing.xLargeFrame)
                }

                HStack {
                    Text("Spawned this hour")
                        .font(WernickeTypography.caption)
                        .foregroundStyle(V4Color.textSecondary)
                    Spacer()
                    Text("\(hive.spawnsThisHour) / \(hive.policy.maxBeesPerHour)")
                        .font(WernickeTypography.captionMono)
                        .foregroundStyle(V4Color.textPrimary)
                }
            }
            .padding()
            .background(V4Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
            .overlay {
                RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                    .stroke(V4Color.bgCardBorder, lineWidth: 1)
            }
            .padding(.horizontal)
        }
    }

    private func stepperRow(
        _ label: String,
        value: Int,
        range: ClosedRange<Int>,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        HStack {
            Text(label)
                .font(WernickeTypography.caption)
                .foregroundStyle(V4Color.textSecondary)
            Spacer()
            Text("\(value)")
                .font(WernickeTypography.captionMono)
                .foregroundStyle(V4Color.textPrimary)
            Stepper("") {
                if value < range.upperBound { onChange(value + 1) }
            } onDecrement: {
                if value > range.lowerBound { onChange(value - 1) }
            }
            .labelsHidden()
        }
    }

    private func toggleRow(_ label: String, isOn: Bool, onChange: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { isOn }, set: onChange)) {
            Text(label)
                .font(WernickeTypography.caption)
                .foregroundStyle(V4Color.textSecondary)
        }
        .toggleStyle(.switch)
    }

    // MARK: - Live bees

    private var liveBeesSection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            sectionTitle("LIVE BEES", color: V4Color.golden)

            if hive.bees.isEmpty {
                emptyRow("No bee has been sent out yet.")
            } else {
                ForEach(hive.bees) { bee in
                    beeCard(bee)
                }
            }
        }
    }

    private func beeCard(_ bee: Bee) -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            HStack(spacing: ParietalSpacing.sm) {
                Text("\u{1F41D}").font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(bee.title)
                        .font(WernickeTypography.captionBold)
                        .foregroundStyle(V4Color.textPrimary)
                    Text(bee.module)
                        .font(WernickeTypography.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
                Spacer()
                Text(statusText(bee))
                    .font(WernickeTypography.caption2Bold)
                    .foregroundStyle(statusColor(bee.status))
                    .padding(.horizontal, ParietalSpacing.xs)
                    .padding(.vertical, ParietalSpacing.xxs)
                    .background(statusColor(bee.status).opacity(V4Color.opacity15))
                    .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
                if !bee.status.isTerminal {
                    Button("Stop") { hive.cancel(bee) }
                        .buttonStyle(.plain)
                        .font(WernickeTypography.caption2Bold)
                        .foregroundStyle(V4Color.error)
                }
            }

            Text(bee.lastLine)
                .font(WernickeTypography.caption2)
                .foregroundStyle(V4Color.textSecondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: ParietalSpacing.sm) {
                metric("tools", "\(bee.toolCalls)")
                metric("elapsed", duration(bee.elapsed))
                if let branch = bee.branch { metric("worktree", branch) }
                Spacer()
                Button {
                    copyToPasteboard("claude --resume \(bee.sessionID)")
                } label: {
                    Text("copy resume command")
                        .font(WernickeTypography.caption2)
                        .foregroundStyle(V4Color.accent)
                }
                .buttonStyle(.plain)
                .help("Open this bee's chat in a terminal, with its full history")
            }
        }
        .padding()
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .overlay {
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(statusColor(bee.status).opacity(V2Depth.stateHover), lineWidth: 1)
        }
        .padding(.horizontal)
    }

    // MARK: - Review

    private var reviewSection: some View {
        let waiting = hive.tasks.filter { $0.state == .review }
        return Group {
            if !waiting.isEmpty {
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    sectionTitle("WAITING ON THE QUEEN", color: V4Color.warning)
                    ForEach(waiting) { task in
                        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                            HStack {
                                Text(task.title)
                                    .font(WernickeTypography.captionBold)
                                    .foregroundStyle(V4Color.textPrimary)
                                Spacer()
                                if let branch = task.branch {
                                    Text(branch)
                                        .font(WernickeTypography.caption2)
                                        .foregroundStyle(V4Color.purple)
                                }
                            }
                            verificationBadge(task)
                            if let summary = task.resultSummary {
                                Text(summary)
                                    .font(WernickeTypography.caption2)
                                    .foregroundStyle(V4Color.textSecondary)
                                    .lineLimit(6)
                            }
                            HStack(spacing: ParietalSpacing.sm) {
                                Button("Accept") { hive.accept(task.id) }
                                    .buttonStyle(.plain)
                                    .font(WernickeTypography.caption2Bold)
                                    .foregroundStyle(V4Color.statusOK)
                                Button("Send back") { hive.reject(task.id, why: "rejected on review") }
                                    .buttonStyle(.plain)
                                    .font(WernickeTypography.caption2Bold)
                                    .foregroundStyle(V4Color.error)
                                Spacer()
                                if let cost = task.costUSD {
                                    Text(String(format: "$%.3f", cost))
                                        .font(WernickeTypography.caption2)
                                        .foregroundStyle(V4Color.textTertiary)
                                }
                            }
                        }
                        .padding()
                        .background(V4Color.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                        .overlay {
                            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                                .stroke(V4Color.warning.opacity(V2Depth.stateHover), lineWidth: 1)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    /// Three states, drawn differently. "Unverified" must never look like a
    /// pass - it is the state in which the Queen has no evidence at all.
    @ViewBuilder
    private func verificationBadge(_ task: HiveTask) -> some View {
        let colour: Color = task.verified == true
            ? V4Color.statusOK
            : (task.verified == false ? V4Color.error : V4Color.warning)
        let label = task.verified == true
            ? "VERIFIED"
            : (task.verified == false ? "BROKE THE BUILD" : "UNVERIFIED")

        // A verdict is a reading, and a reading has an age. Without the second
        // badge, a pass recorded days ago is indistinguishable from one
        // recorded just now, and the review list asserts a green tick over a
        // tree that has moved on since.
        let evidence = hive.evidenceState(for: task)
        let evidenceColour: Color = evidence.isCurrent ? V4Color.statusOK : V4Color.warning

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: ParietalSpacing.xs) {
                Text(label)
                    .font(WernickeTypography.tiny8BoldMono)
                    .foregroundStyle(colour)
                    .padding(.horizontal, ParietalSpacing.xs)
                    .padding(.vertical, 1)
                    .background(colour.opacity(V4Color.opacity15))
                    .clipShape(SwiftUI.Capsule())
                if task.verification != nil {
                    Text("EVIDENCE \(evidence.label)")
                        .font(WernickeTypography.tiny8BoldMono)
                        .foregroundStyle(evidenceColour)
                        .padding(.horizontal, ParietalSpacing.xs)
                        .padding(.vertical, 1)
                        .background(evidenceColour.opacity(V4Color.opacity15))
                        .clipShape(SwiftUI.Capsule())
                }
            }
            if let verification = task.verification {
                Text(verification)
                    .font(WernickeTypography.tiny8)
                    .foregroundStyle(V4Color.textTertiary)
                    .lineLimit(4)
            }
        }
    }

    // MARK: - Priorities

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            HStack {
                sectionTitle("WHAT SHE RANKED", color: V4Color.accent)
                Spacer()
                if hive.isScanning {
                    ProgressView().controlSize(.mini).padding(.trailing)
                }
            }

            if hive.targets.isEmpty {
                emptyRow("Nothing scanned yet - press Rescan.")
            } else {
                ForEach(Array(hive.eligibleTargets.prefix(12).enumerated()), id: \.element.id) { index, target in
                    targetRow(index: index, target: target)
                }
                if !hive.policy.skippedModules.isEmpty {
                    skippedList
                }
            }
        }
    }

    private var skippedList: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xxs) {
            Text("RULED OUT BY YOU")
                .font(WernickeTypography.tiny8BoldMono)
                .foregroundStyle(V4Color.textTertiary)
            ForEach(hive.policy.skippedModules.sorted(by: { $0.key < $1.key }), id: \.key) { module, why in
                HStack(spacing: ParietalSpacing.sm) {
                    Text(module)
                        .font(WernickeTypography.tiny8BoldMono)
                        .foregroundStyle(V4Color.textSecondary)
                    Text(why)
                        .font(WernickeTypography.tiny8)
                        .foregroundStyle(V4Color.textTertiary)
                    Spacer()
                    Button("restore") { hive.unskip(module: module) }
                        .buttonStyle(.plain)
                        .font(WernickeTypography.tiny8)
                        .foregroundStyle(V4Color.accent)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .padding(.horizontal)
    }

    private func targetRow(index: Int, target: HiveTarget) -> some View {
        let isExpanded = expandedTarget == target.id
        return VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            HStack(spacing: ParietalSpacing.sm) {
                Text("\(index + 1)")
                    .font(WernickeTypography.caption2BoldMono)
                    .foregroundStyle(V4Color.textTertiary)
                    .frame(width: 24, alignment: .trailing)

                VStack(alignment: .leading, spacing: 1) {
                    Text(target.module)
                        .font(WernickeTypography.captionBold)
                        .foregroundStyle(V4Color.textPrimary)
                    Text(target.reason)
                        .font(WernickeTypography.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(target.realm.rawValue)
                    .font(WernickeTypography.tiny8Medium)
                    .foregroundStyle(target.realm == .cockpit ? V4Color.purple : V4Color.accent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background((target.realm == .cockpit ? V4Color.purple : V4Color.accent).opacity(V2Depth.bgSubtle))
                    .clipShape(SwiftUI.Capsule())

                scoreBar(target)

                Button {
                    withAnimation { expandedTarget = isExpanded ? nil : target.id }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(WernickeTypography.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                signalTable(target)
            }
        }
        .padding()
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .overlay {
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(V4Color.bgCardBorder, lineWidth: 1)
        }
        .padding(.horizontal)
    }

    private func scoreBar(_ target: HiveTarget) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(String(format: "%.2f", target.score))
                .font(WernickeTypography.caption2BoldMono)
                .foregroundStyle(V4Color.golden)
            // Confidence is drawn beside the score, never folded into it: a
            // half-measured module must not read as a confident verdict.
            Text("conf \(Int(target.confidence * 100))%")
                .font(WernickeTypography.tiny8)
                .foregroundStyle(target.confidence >= 0.8 ? V4Color.textTertiary : V4Color.warning)
        }
        .frame(width: 72, alignment: .trailing)
    }

    private func signalTable(_ target: HiveTarget) -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xxs) {
            ForEach(target.signals) { signal in
                signalRow(signal)
            }

            HStack {
                Text(target.path)
                    .font(WernickeTypography.caption2MediumMono)
                    .foregroundStyle(V4Color.purple)
                Spacer()
                // The ranking measures weakness, not worth. This is where the
                // human supplies the judgement the arithmetic cannot.
                Button {
                    hive.skip(module: target.module, why: "operator: not worth a bee")
                } label: {
                    Text("Not worth it")
                        .font(WernickeTypography.caption2Bold)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Rule this module out of the ranking, with the reason recorded in the audit")
                Button {
                    Task { await hive.sendBee(to: target) }
                } label: {
                    Text("\u{1F41D} Send a bee")
                        .font(WernickeTypography.caption2Bold)
                        .foregroundStyle(V4Color.golden)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, ParietalSpacing.xxs)
        }
        .padding(.top, ParietalSpacing.xxs)
    }

    @ViewBuilder
    private func signalRow(_ signal: HiveSignal) -> some View {
        HStack(spacing: ParietalSpacing.sm) {
            Text(signal.kind.label)
                .font(WernickeTypography.caption2)
                .foregroundStyle(V4Color.textSecondary)
                .frame(width: 150, alignment: .leading)

            if let value = signal.raw.value {
                Text(value == value.rounded() ? "\(Int(value))" : String(format: "%.2f", value))
                    .font(WernickeTypography.caption2MediumMono)
                    .foregroundStyle(V4Color.textPrimary)
                normalizedBar(signal.normalized.value ?? 0)
            } else {
                // Printed in full, in warning colour: a signal she could not
                // read must be visible as a gap, not blend in as a low value.
                Text("NOT MEASURED - \(unmeasuredReason(signal.raw))")
                    .font(WernickeTypography.caption2)
                    .foregroundStyle(V4Color.warning)
                Spacer()
            }

            Text(String(format: "w %.2f", signal.kind.weight))
                .font(WernickeTypography.tiny8)
                .foregroundStyle(V4Color.textTertiary)
        }
    }

    private func normalizedBar(_ fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                SwiftUI.Capsule()
                    .fill(V4Color.textSecondary.opacity(V2Depth.bgSubtle))
                SwiftUI.Capsule()
                    .fill(V4Color.accent)
                    .frame(width: max(2, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 4)
    }

    private func unmeasuredReason(_ state: HiveSignalState) -> String {
        if case .unmeasured(let why) = state { return why }
        return "unknown"
    }

    // MARK: - Manual task

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            sectionTitle("SEND A BEE YOURSELF", color: V4Color.purple)

            VStack(spacing: ParietalSpacing.xs) {
                TextField("Task name", text: $manualTitle)
                    .textFieldStyle(.plain)
                    .font(WernickeTypography.caption)
                    .foregroundStyle(V4Color.textPrimary)
                    .padding(ParietalSpacing.xs)
                    .background(V4Color.input)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                TextEditor(text: $manualInstruction)
                    .font(WernickeTypography.captionMono)
                    .frame(height: ParietalSpacing.frameHeightSmall)
                    .scrollContentBackground(.hidden)
                    .padding(ParietalSpacing.xxs)
                    .background(V4Color.input)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Text("Runs with the same guardrails and opens its own chat.")
                        .font(WernickeTypography.caption2)
                        .foregroundStyle(V4Color.textTertiary)
                    Spacer()
                    Button {
                        let title = manualTitle
                        let instruction = manualInstruction
                        manualTitle = ""
                        manualInstruction = ""
                        Task { await hive.spawnManualTask(title: title, instruction: instruction) }
                    } label: {
                        Text("\u{1F41D} Dispatch")
                            .font(WernickeTypography.captionBold)
                            .foregroundStyle(V4Color.golden)
                    }
                    .buttonStyle(.plain)
                    .disabled(manualInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .background(V4Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
            .overlay {
                RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                    .stroke(V4Color.bgCardBorder, lineWidth: 1)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Events

    private var eventLogSection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            sectionTitle("AUDIT", color: V4Color.textSecondary)
            VStack(alignment: .leading, spacing: ParietalSpacing.xxs) {
                if hive.events.isEmpty {
                    Text("nothing recorded yet")
                        .font(WernickeTypography.caption2)
                        .foregroundStyle(V4Color.textTertiary)
                }
                ForEach(hive.events.prefix(25)) { event in
                    HStack(alignment: .top, spacing: ParietalSpacing.sm) {
                        Text(timeOnly(event.timestamp))
                            .font(WernickeTypography.tiny8)
                            .foregroundStyle(V4Color.textTertiary)
                        Text(event.kind)
                            .font(WernickeTypography.tiny8BoldMono)
                            .foregroundStyle(V4Color.accent)
                            .frame(width: 150, alignment: .leading)
                        Text(event.detail)
                            .font(WernickeTypography.tiny8)
                            .foregroundStyle(V4Color.textSecondary)
                            .lineLimit(2)
                        Spacer()
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(V4Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(WernickeTypography.caption2)
            .foregroundStyle(V4Color.textTertiary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(V4Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
            .padding(.horizontal)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(WernickeTypography.tiny8)
                .foregroundStyle(V4Color.textTertiary)
            Text(value)
                .font(WernickeTypography.tiny8BoldMono)
                .foregroundStyle(V4Color.textSecondary)
        }
    }

    private func statusText(_ bee: Bee) -> String {
        bee.status.label
    }

    private func statusColor(_ status: BeeStatus) -> Color {
        switch status {
        case .starting, .working: return V4Color.golden
        case .succeeded: return V4Color.statusOK
        case .failed, .timedOut: return V4Color.error
        case .cancelled: return V4Color.textSecondary
        }
    }

    private func duration(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        return total < 60 ? "\(total)s" : "\(total / 60)m \(total % 60)s"
    }

    private func countdown(to date: Date) -> String {
        duration(date.timeIntervalSince(tick))
    }

    private func relative(_ date: Date) -> String {
        "\(duration(tick.timeIntervalSince(date))) ago"
    }

    private func timeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func copyToPasteboard(_ text: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
