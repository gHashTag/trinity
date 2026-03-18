import Foundation
import AppKit

/// Behavioral analytics aggregation for UX insights
@MainActor
public final class BehaviorAnalytics {
    public static let shared = BehaviorAnalytics()

    private var sessionStart: Date = Date()
    private var clickEvents: [ClickEventData] = []
    private var navigationEvents: [NavigationEventData] = []
    private var typingEvents: [TypingEventData] = []
    private var rageClicks: [RageClickEventData] = []
    private var dwellTimes: [DwellTimeData] = []

    private init() {}

    // MARK: - Event Tracking

    public func recordClick(at position: CGPoint, element: String? = nil, success: Bool) {
        let event = ClickEventData(
            timestamp: Date(),
            x: position.x,
            y: position.y,
            element: element,
            success: success
        )
        clickEvents.append(event)
    }

    public func recordNavigation(to screen: String, duration: TimeInterval) {
        let event = NavigationEventData(
            timestamp: Date(),
            screen: screen,
            duration: duration
        )
        navigationEvents.append(event)
    }

    public func recordTyping(element: String, text: String, duration: TimeInterval, errors: Int = 0) {
        let event = TypingEventData(
            timestamp: Date(),
            element: element,
            textLength: text.count,
            duration: duration,
            errors: errors
        )
        typingEvents.append(event)
    }

    public func recordRageClick(location: String, count: Int, timeSpan: TimeInterval) {
        let event = RageClickEventData(
            timestamp: Date(),
            location: location,
            count: count,
            timeSpan: timeSpan
        )
        rageClicks.append(event)
    }

    public func recordDwellTime(on element: String, duration: TimeInterval) {
        let data = DwellTimeData(
            timestamp: Date(),
            element: element,
            duration: duration
        )
        dwellTimes.append(data)
    }

    // MARK: - Report Generation

    public func generateReport() -> AnalyticsReport {
        let now = Date()
        let sessionDuration = now.timeIntervalSince(sessionStart)

        return AnalyticsReport(
            sessionStart: sessionStart,
            sessionDuration: sessionDuration,
            clickMetrics: analyzeClicks(),
            navigationMetrics: analyzeNavigation(),
            typingMetrics: analyzeTyping(),
            rageClickMetrics: analyzeRageClicks(),
            dwellMetrics: analyzeDwellTimes(),
            uxScore: calculateUXScore(),
            recommendations: generateRecommendations()
        )
    }

    // MARK: - Analysis

    private func analyzeClicks() -> ClickMetrics {
        let totalClicks = clickEvents.count
        let successfulClicks = clickEvents.filter { $0.success }.count
        let successRate = totalClicks > 0 ? Double(successfulClicks) / Double(totalClicks) : 0

        // Calculate click heatmap
        var heatmap: [String: Int] = [:]
        let gridSize: CGFloat = 50
        for event in clickEvents {
            let gridX = Int(event.x / gridSize) * Int(gridSize)
            let gridY = Int(event.y / gridSize) * Int(gridSize)
            let key = "\(gridX)x\(gridY)"
            heatmap[key, default: 0] += 1
        }

        // Find most clicked areas
        let topAreas = heatmap.sorted { $0.value > $1.value }.prefix(5)

        return ClickMetrics(
            totalClicks: totalClicks,
            successRate: successRate,
            heatmap: heatmap,
            topAreas: topAreas.map { ["x": $0.key, "count": $0.value] }
        )
    }

    private func analyzeNavigation() -> NavigationMetrics {
        let totalNavigations = navigationEvents.count
        let avgDuration = navigationEvents.isEmpty ? 0 :
            navigationEvents.reduce(0.0) { $0 + $1.duration } / Double(navigationEvents.count)

        // Count destinations
        var destinationCounts: [String: Int] = [:]
        for event in navigationEvents {
            destinationCounts[event.screen, default: 0] += 1
        }

        let mostVisited = destinationCounts.sorted { $0.value > $1.value }.first

        return NavigationMetrics(
            totalNavigations: totalNavigations,
            averageDuration: avgDuration,
            destinationCounts: destinationCounts,
            mostVisited: mostVisited?.key ?? "none"
        )
    }

    private func analyzeTyping() -> TypingMetrics {
        let totalEvents = typingEvents.count
        let totalChars = typingEvents.reduce(0) { $0 + $1.textLength }
        let totalErrors = typingEvents.reduce(0) { $0 + $1.errors }
        let totalDuration = typingEvents.reduce(0.0) { $0 + $1.duration }

        let avgTypingSpeed = totalDuration > 0 ? Double(totalChars) / totalDuration : 0
        let errorRate = totalChars > 0 ? Double(totalErrors) / Double(totalChars) : 0

        return TypingMetrics(
            totalEvents: totalEvents,
            totalCharacters: totalChars,
            averageTypingSpeed: avgTypingSpeed,
            errorRate: errorRate
        )
    }

    private func analyzeRageClicks() -> RageClickMetrics {
        let totalRageClicks = rageClicks.count
        let avgClickCount = rageClicks.isEmpty ? 0 :
            Double(rageClicks.reduce(0) { $0 + $1.count }) / Double(rageClicks.count)
        let avgTimeSpan = rageClicks.isEmpty ? 0 :
            rageClicks.reduce(0.0) { $0 + $1.timeSpan } / Double(rageClicks.count)

        // Find problematic areas
        let problemAreas = rageClicks.map { $0.location }

        return RageClickMetrics(
            totalRageClicks: totalRageClicks,
            averageClickCount: avgClickCount,
            averageTimeSpan: avgTimeSpan,
            problemAreas: problemAreas
        )
    }

    private func analyzeDwellTimes() -> DwellMetrics {
        let totalDwells = dwellTimes.count
        let avgDwellTime = dwellTimes.isEmpty ? 0 :
            dwellTimes.reduce(0.0) { $0 + $1.duration } / Double(dwellTimes.count)

        // Categorize dwell times
        var elementDwells: [String: [TimeInterval]] = [:]
        for dwell in dwellTimes {
            elementDwells[dwell.element, default: []].append(dwell.duration)
        }

        var avgByElement: [String: Double] = [:]
        for (element, times) in elementDwells {
            avgByElement[element] = times.reduce(0, +) / Double(times.count)
        }

        // Find hesitation patterns (long dwell times > 2s)
        let hesitations = dwellTimes.filter { $0.duration > 2.0 }

        return DwellMetrics(
            totalDwells: totalDwells,
            averageDwellTime: avgDwellTime,
            averageByElement: avgByElement,
            hesitationCount: hesitations.count
        )
    }

    private func calculateUXScore() -> Double {
        var score = 100.0

        // Penalize rage clicks
        score -= Double(rageClicks.count) * 10

        // Penalize low click success rate
        let clickSuccessRate = clickEvents.isEmpty ? 1.0 :
            Double(clickEvents.filter { $0.success }.count) / Double(clickEvents.count)
        score *= clickSuccessRate

        // Penalize high error rate in typing
        let totalChars = typingEvents.reduce(0) { $0 + $1.textLength }
        let totalErrors = typingEvents.reduce(0) { $0 + $1.errors }
        let errorRate = totalChars > 0 ? Double(totalErrors) / Double(totalChars) : 0
        score -= errorRate * 20

        // Bonus for fast navigation
        let avgNavDuration = navigationEvents.isEmpty ? 0 :
            navigationEvents.reduce(0.0) { $0 + $1.duration } / Double(navigationEvents.count)
        if avgNavDuration < 1.0 {
            score += 5
        }

        return max(0, min(100, score))
    }

    private func generateRecommendations() -> [Recommendation] {
        var recommendations: [Recommendation] = []

        // Rage click recommendations
        if rageClicks.count > 0 {
            recommendations.append(Recommendation(
                type: "critical",
                title: "Address Frustration Points",
                description: "\(rageClicks.count) rage click event(s) detected. Review button placements and response times.",
                priority: .high
            ))
        }

        // Click success rate
        let clickSuccessRate = clickEvents.isEmpty ? 1.0 :
            Double(clickEvents.filter { $0.success }.count) / Double(clickEvents.count)
        if clickSuccessRate < 0.9 {
            recommendations.append(Recommendation(
                type: "improvement",
                title: "Improve Click Target Accuracy",
                description: String(format: "Click success rate is %.1f%%. Consider increasing button sizes or improving hit detection.", clickSuccessRate * 100),
                priority: .medium
            ))
        }

        // Typing error rate
        let totalChars = typingEvents.reduce(0) { $0 + $1.textLength }
        let totalErrors = typingEvents.reduce(0) { $0 + $1.errors }
        let errorRate = totalChars > 0 ? Double(totalErrors) / Double(totalChars) : 0
        if errorRate > 0.05 {
            recommendations.append(Recommendation(
                type: "usability",
                title: "Reduce Input Errors",
                description: String(format: "Typing error rate is %.1f%%. Consider adding input validation or clearer labels.", errorRate * 100),
                priority: .low
            ))
        }

        // Hesitation patterns
        let hesitations = dwellTimes.filter { $0.duration > 2.0 }
        if hesitations.count > 3 {
            recommendations.append(Recommendation(
                type: "usability",
                title: "Reduce User Hesitation",
                description: "\(hesitations.count) instances of long dwell times detected. Consider simplifying the UI flow.",
                priority: .medium
            ))
        }

        return recommendations
    }

    // MARK: - Session Management

    public func resetSession() {
        sessionStart = Date()
        clickEvents.removeAll()
        navigationEvents.removeAll()
        typingEvents.removeAll()
        rageClicks.removeAll()
        dwellTimes.removeAll()
    }
}

// MARK: - Supporting Types

public struct AnalyticsReport {
    public let sessionStart: Date
    public let sessionDuration: TimeInterval
    public let clickMetrics: ClickMetrics
    public let navigationMetrics: NavigationMetrics
    public let typingMetrics: TypingMetrics
    public let rageClickMetrics: RageClickMetrics
    public let dwellMetrics: DwellMetrics
    public let uxScore: Double
    public let recommendations: [Recommendation]

    public func toJSON() -> [String: Any] {
        [
            "sessionStart": ISO8601DateFormatter().string(from: sessionStart),
            "sessionDuration": sessionDuration,
            "clickMetrics": clickMetrics.toJSON(),
            "navigationMetrics": navigationMetrics.toJSON(),
            "typingMetrics": typingMetrics.toJSON(),
            "rageClickMetrics": rageClickMetrics.toJSON(),
            "dwellMetrics": dwellMetrics.toJSON(),
            "uxScore": uxScore,
            "recommendations": recommendations.map { $0.toJSON() }
        ]
    }
}

public struct ClickEventData {
    public let timestamp: Date
    public let x: CGFloat
    public let y: CGFloat
    public let element: String?
    public let success: Bool
}

public struct ClickMetrics {
    public let totalClicks: Int
    public let successRate: Double
    public let heatmap: [String: Int]
    public let topAreas: [[String: Any]]

    func toJSON() -> [String: Any] {
        [
            "totalClicks": totalClicks,
            "successRate": successRate,
            "heatmap": heatmap,
            "topAreas": topAreas
        ]
    }
}

public struct NavigationEventData {
    public let timestamp: Date
    public let screen: String
    public let duration: TimeInterval
}

public struct NavigationMetrics {
    public let totalNavigations: Int
    public let averageDuration: TimeInterval
    public let destinationCounts: [String: Int]
    public let mostVisited: String

    func toJSON() -> [String: Any] {
        [
            "totalNavigations": totalNavigations,
            "averageDuration": averageDuration,
            "destinationCounts": destinationCounts,
            "mostVisited": mostVisited
        ]
    }
}

public struct TypingEventData {
    public let timestamp: Date
    public let element: String
    public let textLength: Int
    public let duration: TimeInterval
    public let errors: Int
}

public struct TypingMetrics {
    public let totalEvents: Int
    public let totalCharacters: Int
    public let averageTypingSpeed: Double // chars per second
    public let errorRate: Double

    func toJSON() -> [String: Any] {
        [
            "totalEvents": totalEvents,
            "totalCharacters": totalCharacters,
            "averageTypingSpeed": averageTypingSpeed,
            "errorRate": errorRate
        ]
    }
}

public struct RageClickEventData {
    public let timestamp: Date
    public let location: String
    public let count: Int
    public let timeSpan: TimeInterval
}

public struct RageClickMetrics {
    public let totalRageClicks: Int
    public let averageClickCount: Double
    public let averageTimeSpan: TimeInterval
    public let problemAreas: [String]

    func toJSON() -> [String: Any] {
        [
            "totalRageClicks": totalRageClicks,
            "averageClickCount": averageClickCount,
            "averageTimeSpan": averageTimeSpan,
            "problemAreas": problemAreas
        ]
    }
}

public struct DwellTimeData {
    public let timestamp: Date
    public let element: String
    public let duration: TimeInterval
}

public struct DwellMetrics {
    public let totalDwells: Int
    public let averageDwellTime: TimeInterval
    public let averageByElement: [String: Double]
    public let hesitationCount: Int

    func toJSON() -> [String: Any] {
        [
            "totalDwells": totalDwells,
            "averageDwellTime": averageDwellTime,
            "averageByElement": averageByElement,
            "hesitationCount": hesitationCount
        ]
    }
}

public struct Recommendation {
    public enum Priority {
        case high, medium, low
    }

    public let type: String
    public let title: String
    public let description: String
    public let priority: Priority

    func toJSON() -> [String: Any] {
        [
            "type": type,
            "title": title,
            "description": description,
            "priority": String(describing: priority)
        ]
    }
}
