import Foundation
import AppKit
import CoreGraphics

/// Autonomous UI exploration agent — maps interface, discovers elements, builds comprehensive model
@MainActor
public final class UIExplorer {
    public static let shared = UIExplorer()

    private var explorationMap: UIElementMap = .init()
    private var isExploring = false
    private var explorationHistory: [ExplorationSession] = []
    private var currentSession: ExplorationSession?
    private var clickHistory: [ClickRecord] = []
    private let maxClickHistory = 1000

    // Exploration parameters
    private var explorationMode: ExplorationMode = .systematic
    private var explorationDepth: Int = 0
    private let maxDepth = 50
    private var visitedRegions: Set<String> = []
    private var discoveredScreens: Set<String> = []

    private init() {}

    // MARK: - Exploration Modes

    public enum ExplorationMode {
        case systematic      // Grid-based exhaustive search
        case random          // Random exploration
        case focused         // Focus on interactive areas
        case adaptive        // Learn from discoveries
    }

    // MARK: - Main Exploration

    /// Start autonomous exploration session
    public func startExploration(mode: ExplorationMode = .adaptive, duration: TimeInterval? = nil) async -> ExplorationResult {
        guard !isExploring else {
            return ExplorationResult(
                success: false,
                elementsDiscovered: 0,
                areasMapped: 0,
                screensDiscovered: 0,
                duration: 0,
                error: "Already exploring"
            )
        }

        isExploring = true
        explorationMode = mode
        let startTime = Date()

        NSLog("[UIExplorer] Starting \(mode) exploration")

        // Create new session
        currentSession = ExplorationSession(
            id: UUID().uuidString,
            startTime: startTime,
            mode: mode,
            discoveredElements: [],
            clickTrail: []
        )

        // Reset for new exploration
        explorationDepth = 0
        visitedRegions.removeAll()
        discoveredScreens.removeAll()

        // Run exploration loop
        await runExplorationLoop(duration: duration)

        // Finalize session
        let duration = Date().timeIntervalSince(startTime)
        let result = finalizeSession(duration: duration)

        isExploring = false

        NSLog("[UIExplorer] Exploration complete: \(result.elementsDiscovered) elements, \(result.areasMapped) areas")

        return result
    }

    private func runExplorationLoop(duration: TimeInterval?) async {
        let endTime = duration.map { Date().addingTimeInterval($0) }

        while explorationDepth < maxDepth {
            // Check timeout
            if let end = endTime, Date() >= end {
                NSLog("[UIExplorer] Exploration duration limit reached")
                break
            }

            // Check if we should stop (no new discoveries)
            if explorationDepth > 10 && hasRecentlyDiscoveredNewElement == false {
                NSLog("[UIExplorer] No new discoveries, ending exploration")
                break
            }

            // Perform next exploration step
            await performExplorationStep()

            explorationDepth += 1

            // Small delay between actions (human-like)
            let delay = HumanBehaviorModel.randomDelay(mean: 300, stdDev: 100)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    private var hasRecentlyDiscoveredNewElement: Bool {
        guard let session = currentSession else { return false }
        let recentCount = session.discoveredElements.filter {
            Date().timeIntervalSince($0.discoveredAt) < 5.0
        }.count
        return recentCount > 0
    }

    private func performExplorationStep() async {
        switch explorationMode {
        case .systematic:
            await systematicExplorationStep()
        case .random:
            await randomExplorationStep()
        case .focused:
            await focusedExplorationStep()
        case .adaptive:
            await adaptiveExplorationStep()
        }
    }

    // MARK: - Exploration Strategies

    private func systematicExplorationStep() async {
        // Divide screen into grid, visit each cell
        let gridSize: CGFloat = 100
        let screen = NSScreen.main?.frame ?? .zero

        let col = explorationDepth % Int(ceil(screen.width / gridSize))
        let row = explorationDepth / Int(ceil(screen.width / gridSize))

        let x = CGFloat(col) * gridSize + gridSize / 2
        let y = CGFloat(row) * gridSize + gridSize / 2

        guard x < screen.width && y < screen.height else { return }

        await probePoint(x: x, y: y, context: "systematic_grid")
    }

    private func randomExplorationStep() async {
        let screen = NSScreen.main?.frame ?? .zero
        let x = CGFloat.random(in: 0..<screen.width)
        let y = CGFloat.random(in: 0..<screen.height)

        await probePoint(x: x, y: y, context: "random")
    }

    private func focusedExplorationStep() async {
        // Focus on areas with known interactive elements
        let hotspots = getInteractiveHotspots()

        if let hotspot = hotspots.randomElement() {
            // Add jitter to hotspot
            let jitter = HumanBehaviorModel.jitteredPoint(x: hotspot.x, y: hotspot.y, amount: 30)
            await probePoint(x: jitter.x, y: jitter.y, context: "focused_hotspot")
        } else {
            // Fallback to center screen
            let screen = NSScreen.main?.frame ?? .zero
            await probePoint(x: screen.width / 2, y: screen.height / 2, context: "focused_fallback")
        }
    }

    private func adaptiveExplorationStep() async {
        // Switch strategies based on discoveries
        let discoveryRate = Double(explorationMap.elements.count) / Double(max(explorationDepth, 1))

        if discoveryRate < 0.1 {
            // Low discovery rate → try systematic
            await systematicExplorationStep()
        } else if discoveryRate < 0.3 {
            // Medium rate → try focused
            await focusedExplorationStep()
        } else {
            // High rate → try random near discoveries
            await randomExplorationStep()
        }
    }

    // MARK: - Probing & Discovery

    private func probePoint(x: CGFloat, y: CGFloat, context: String) async {
        // Take screenshot before click
        let beforeScreenshot = await UIAutomation.shared.takeScreenshot()

        // Perform click
        let clickResult = await UIAutomation.shared.click(element: nil, x: x, y: y)

        // Record click
        let record = ClickRecord(
            x: x,
            y: y,
            timestamp: Date(),
            context: context,
            success: clickResult["success"] as? Bool ?? false
        )
        clickHistory.append(record)
        if clickHistory.count > maxClickHistory {
            clickHistory.removeFirst()
        }

        // Analyze result
        await analyzeClickResult(record: record, beforeScreenshot: beforeScreenshot)

        // Record region as visited
        let regionKey = "\(Int(x / 50))x\(Int(y / 50))"
        visitedRegions.insert(regionKey)
    }

    private func analyzeClickResult(record: ClickRecord, beforeScreenshot: [String: Any]) async {
        // Check if this revealed new elements
        let currentAnalysis = await ScreenAnalyzer.shared.analyzeCurrentScreen()

        for element in currentAnalysis.visibleElements {
            let elementKey = "\(element.type)_\(Int(element.frame.origin.x))_\(Int(element.frame.origin.y))"

            // Check if this is a new element
            if !explorationMap.elements.contains(where: { $0.key == elementKey }) {
                let discovered = UIElementInfo(
                    key: elementKey,
                    type: element.type,
                    frame: element.frame,
                    confidence: element.confidence,
                    discoveredAt: Date(),
                    discoveredBy: record.context
                )

                explorationMap.elements.append(discovered)
                currentSession?.discoveredElements.append(discovered)

                NSLog("[UIExplorer] Discovered: \(element.type) at \(element.frame.origin)")
            }
        }
    }

    // MARK: - Screen Discovery

    /// Explore all available screens by navigation
    public func discoverAllScreens() async -> [String] {
        let knownScreens = ["sevo", "oracle", "arena", "faculty", "settings", "chat"]

        for screen in knownScreens {
            let result = await UIAutomation.shared.navigate(to: screen)
            if result["success"] as? Bool == true {
                discoveredScreens.insert(screen)

                // Wait and analyze
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

                let analysis = await ScreenAnalyzer.shared.analyzeCurrentScreen()
                for element in analysis.visibleElements {
                    let elementKey = "\(screen)_\(element.type)_\(Int(element.frame.origin.x))"
                    let info = UIElementInfo(
                        key: elementKey,
                        type: element.type,
                        frame: element.frame,
                        confidence: element.confidence,
                        discoveredAt: Date(),
                        discoveredBy: "screen_discovery_\(screen)"
                    )
                    explorationMap.elements.append(info)
                }
            }
        }

        // Return to main screen
        _ = await UIAutomation.shared.navigate(to: "chat")

        return Array(discoveredScreens)
    }

    // MARK: - Hotspot Detection

    private func getInteractiveHotspots() -> [CGPoint] {
        var hotspots: [CGPoint] = []

        // Known element positions
        let knownPositions: [(String, CGFloat, CGFloat)] = [
            ("chat.input", 200, 80),
            ("chat.send", 200, 100),
            ("sidebar.settings", 100, 150),
            ("nav.sevo", 100, 200),
            ("nav.oracle", 100, 250),
            ("nav.arena", 100, 350),
        ]

        for (_, x, y) in knownPositions {
            hotspots.append(CGPoint(x: x, y: y))
        }

        // Add frequently clicked areas from history
        let frequentAreas = getFrequentlyClickedAreas(threshold: 3)
        hotspots.append(contentsOf: frequentAreas)

        return hotspots
    }

    private func getFrequentlyClickedAreas(threshold: Int) -> [CGPoint] {
        let recent = clickHistory.suffix(100)
        var areaCounts: [String: (Int, CGFloat, CGFloat)] = [:]

        for click in recent {
            let key = "\(Int(click.x / 30))x\(Int(click.y / 30))"
            if let (count, x, y) = areaCounts[key] {
                areaCounts[key] = (count + 1, (x + click.x) / 2, (y + click.y) / 2)
            } else {
                areaCounts[key] = (1, click.x, click.y)
            }
        }

        return areaCounts.compactMap { key, value in
            value.0 >= threshold ? CGPoint(x: value.1, y: value.2) : nil
        }
    }

    // MARK: - Map Building

    private func finalizeSession(duration: TimeInterval) -> ExplorationResult {
        // Build area coverage
        let screen = NSScreen.main?.frame ?? .zero
        let totalCells = Int(ceil(screen.width / 50)) * Int(ceil(screen.height / 50))
        let coverage = Double(visitedRegions.count) / Double(totalCells)

        // Calculate unique elements
        let uniqueElements = Set(explorationMap.elements.map { $0.type })

        let result = ExplorationResult(
            success: true,
            elementsDiscovered: explorationMap.elements.count,
            areasMapped: visitedRegions.count,
            screensDiscovered: discoveredScreens.count,
            duration: duration,
            coverage: coverage,
            uniqueElementTypes: uniqueElements.count,
            map: explorationMap
        )

        // Save session
        if var session = currentSession {
            session.endTime = Date()
            session.duration = duration
            session.result = result
            explorationHistory.append(session)
        }

        return result
    }

    // MARK: - Public Access

    public func getExplorationMap() -> UIElementMap {
        return explorationMap
    }

    public func getElementMapJSON() -> [String: Any] {
        return [
            "elements": explorationMap.elements.map { $0.toJSON() },
            "areasMapped": visitedRegions.count,
            "screensDiscovered": Array(discoveredScreens),
            "lastUpdated": ISO8601DateFormatter().string(from: Date())
        ]
    }

    public func getClickHeatmap() -> [[String: Any]] {
        let screen = NSScreen.main?.frame ?? .zero
        var bins: [String: Int] = [:]
        let binSize: CGFloat = 50

        for click in clickHistory {
            let binX = Int(click.x / binSize)
            let binY = Int(click.y / binSize)
            let key = "\(binX)x\(binY)"
            bins[key, default: 0] += 1
        }

        return bins.map { key, count in
            let parts = key.split(separator: "x").compactMap { Int($0) }
            return [
                "x": parts[0] * Int(binSize),
                "y": parts[1] * Int(binSize),
                "intensity": count
            ]
        }
    }

    public func exportExplorationReport() -> String {
        let map = explorationMap
        var report = "# UI Exploration Report\n\n"
        report += "Generated: \(ISO8601DateFormatter().string(from: Date()))\n"
        report += "Total Elements: \(map.elements.count)\n"
        report += "Unique Types: \(Set(map.elements.map { $0.type }).count)\n"
        report += "Areas Mapped: \(visitedRegions.count)\n"
        report += "Screens Discovered: \(discoveredScreens.count)\n\n"

        report += "## Discovered Elements\n\n"
        let grouped = Dictionary(grouping: map.elements) { $0.type }
        for (type, elements) in grouped.sorted(by: { $0.key < $1.key }) {
            report += "### \(type) (\(elements.count))\n"
            for elem in elements.prefix(5) {
                report += "- \(elem.frame) confidence: \(String(format: "%.2f", elem.confidence))\n"
            }
            if elements.count > 5 {
                report += "- ... and \(elements.count - 5) more\n"
            }
            report += "\n"
        }

        return report
    }

    // MARK: - Smart Click Suggestions

    public func suggestNextClick(goal: ExplorationGoal) -> CGPoint? {
        switch goal {
        case .discoverNew:
            // Suggest unvisited region
            let screen = NSScreen.main?.frame ?? .zero
            for y in stride(from: 0, to: screen.height, by: 50) {
                for x in stride(from: 0, to: screen.width, by: 50) {
                    let key = "\(Int(x / 50))x\(Int(y / 50))"
                    if !visitedRegions.contains(key) {
                        return CGPoint(x: x + 25, y: y + 25)
                    }
                }
            }
            return nil

        case .exploreHotspots:
            return getInteractiveHotspots().randomElement()

        case .verifyElements:
            // Re-visit known elements to verify they still exist
            return explorationMap.elements.randomElement()?.frame.center
        }
    }
}

// MARK: - Supporting Types

public struct UIElementMap {
    public var elements: [UIElementInfo] = []
    public var lastUpdated: Date = Date()
}

public struct UIElementInfo {
    public let key: String
    public let type: String
    public let frame: CGRect
    public let confidence: Double
    public let discoveredAt: Date
    public let discoveredBy: String

    public func toJSON() -> [String: Any] {
        [
            "key": key,
            "type": type,
            "frame": [
                "x": frame.origin.x,
                "y": frame.origin.y,
                "width": frame.size.width,
                "height": frame.size.height
            ],
            "confidence": confidence,
            "discoveredAt": ISO8601DateFormatter().string(from: discoveredAt),
            "discoveredBy": discoveredBy
        ]
    }
}

public struct ExplorationResult {
    public let success: Bool
    public let elementsDiscovered: Int
    public let areasMapped: Int
    public let screensDiscovered: Int
    public let duration: TimeInterval
    public var coverage: Double = 0
    public var uniqueElementTypes: Int = 0
    public var map: UIElementMap?
    public var error: String?

    public func toJSON() -> [String: Any] {
        var result: [String: Any] = [
            "success": success,
            "elementsDiscovered": elementsDiscovered,
            "areasMapped": areasMapped,
            "screensDiscovered": screensDiscovered,
            "duration": duration,
            "coverage": coverage,
            "uniqueElementTypes": uniqueElementTypes
        ]
        if let error = error {
            result["error"] = error
        }
        return result
    }
}

public struct ExplorationSession {
    public let id: String
    public let startTime: Date
    public var endTime: Date?
    public var duration: TimeInterval = 0
    public let mode: UIExplorer.ExplorationMode
    public var discoveredElements: [UIElementInfo]
    public var clickTrail: [ClickRecord]
    public var result: ExplorationResult?
}

public struct ClickRecord {
    public let x: CGFloat
    public let y: CGFloat
    public let timestamp: Date
    public let context: String
    public let success: Bool
}

public enum ExplorationGoal {
    case discoverNew
    case exploreHotspots
    case verifyElements
}
