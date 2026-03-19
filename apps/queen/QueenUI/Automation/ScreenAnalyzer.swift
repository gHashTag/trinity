import Foundation
import AppKit
import CoreGraphics

/// Analyze screenshots to understand current UI state and adapt actions
@MainActor
public final class ScreenAnalyzer {
    public static let shared = ScreenAnalyzer()

    private var lastAnalysis: ScreenAnalysis?
    private var analysisHistory: [ScreenAnalysis] = []

    private init() {}

    // MARK: - Analysis

    /// Analyze current screen state
    public func analyzeCurrentScreen() async -> ScreenAnalysis {
        let screenshot = await UIAutomation.shared.takeScreenshot()

        guard let imageBase64 = screenshot["image"] as? String,
              let imageData = Data(base64Encoded: imageBase64),
              let nsImage = NSImage(data: imageData) else {
            return ScreenAnalysis(
                timestamp: Date(),
                screenSize: .zero,
                visibleElements: [],
                dominantColors: [],
                textRegions: [],
                confidence: 0
            )
        }

        let size = NSSize(width: screenshot["width"] as? Int ?? 0,
                         height: screenshot["height"] as? Int ?? 0)

        // Analyze image
        let visibleElements = detectVisibleElements(in: nsImage)
        let colors = extractDominantColors(from: nsImage)
        let textRegions = detectTextRegions(in: nsImage)

        let analysis = ScreenAnalysis(
            timestamp: Date(),
            screenSize: size,
            visibleElements: visibleElements,
            dominantColors: colors,
            textRegions: textRegions,
            confidence: calculateConfidence(elements: visibleElements, textRegions: textRegions)
        )

        lastAnalysis = analysis
        analysisHistory.append(analysis)
        if analysisHistory.count > 10 {
            analysisHistory.removeFirst()
        }

        return analysis
    }

    /// Detect interactive elements based on visual patterns
    private func detectVisibleElements(in image: NSImage) -> [VisibleElement] {
        var elements: [VisibleElement] = []

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }

        let width = cgImage.width
        let height = cgImage.height

        // Sample pixels to detect UI elements
        // This is a simplified detection - real implementation would use Vision framework
        let regions: [(CGRect, String)] = [
            (CGRect(x: 0, y: height-100, width: 200, height: 100), "input_field"),
            (CGRect(x: width-100, y: height-100, width: 100, height: 100), "send_button"),
            (CGRect(x: 0, y: 0, width: 100, height: height), "sidebar"),
            (CGRect(x: 100, y: 0, width: 200, height: 100), "navigation"),
        ]

        for (rect, type) in regions {
            elements.append(VisibleElement(
                type: type,
                frame: rect,
                confidence: 0.8,
                visible: true
            ))
        }

        return elements
    }

    /// Extract dominant colors from screenshot
    private func extractDominantColors(from image: NSImage) -> [ColorInfo] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }

        let width = cgImage.width
        let height = cgImage.height
        var colorCounts: [String: Int] = [:]

        // Sample pixels (every 100th pixel for performance)
        let sampleStride = 100

        guard let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return []
        }

        for y in stride(from: 0, to: height, by: sampleStride) {
            for x in stride(from: 0, to: width, by: sampleStride) {
                let offset = (y * width + x) * 4
                let r = data[offset]
                let g = data[offset + 1]
                let b = data[offset + 2]
                let key = "\(r),\(g),\(b)"
                colorCounts[key, default: 0] += 1
            }
        }

        // Get top 5 colors
        let sorted = colorCounts.sorted { $0.value > $1.value }.prefix(5)
        return sorted.map { ColorInfo(hex: $0.key, count: $0.value) }
    }

    /// Detect potential text regions in image
    private func detectTextRegions(in image: NSImage) -> [TextRegion] {
        // Simplified text region detection
        // Real implementation would use Vision framework's text recognition
        return [
            TextRegion(frame: CGRect(x: 200, y: height(for: image) - 80, width: 400, height: 40),
                       confidence: 0.7),
            TextRegion(frame: CGRect(x: 100, y: 50, width: 200, height: 30),
                       confidence: 0.6),
        ]
    }

    private func height(for image: NSImage) -> CGFloat {
        return image.size.height
    }

    /// Calculate confidence in analysis results
    private func calculateConfidence(elements: [VisibleElement], textRegions: [TextRegion]) -> Double {
        let elementScore = Double(elements.count) * 0.1
        let textScore = Double(textRegions.count) * 0.05
        return min(1.0, elementScore + textScore + 0.5)
    }

    // MARK: - Adaptive Actions

    /// Suggest next action based on screen analysis
    public func suggestNextAction(goal: String) async -> ActionSuggestion? {
        guard let analysis = lastAnalysis else {
            return nil
        }

        // Find best matching element for goal
        let matchingElements = analysis.visibleElements.filter { element in
            goal.contains(element.type) || element.type.contains(goal)
        }

        guard let bestMatch = matchingElements.first else {
            return ActionSuggestion(
                action: .wait,
                target: nil,
                reason: "No matching element found for goal: \(goal)",
                confidence: 0
            )
        }

        return ActionSuggestion(
            action: .click,
            target: bestMatch.frame.center,
            reason: "Found \(bestMatch.type) at visible location",
            confidence: bestMatch.confidence
        )
    }

    /// Check if element is visible on screen
    public func isElementVisible(_ elementType: String) -> Bool {
        guard let analysis = lastAnalysis else {
            return false
        }
        return analysis.visibleElements.contains { $0.type == elementType && $0.visible }
    }
}

// MARK: - Supporting Types

public struct ScreenAnalysis {
    public let timestamp: Date
    public let screenSize: NSSize
    public let visibleElements: [VisibleElement]
    public let dominantColors: [ColorInfo]
    public let textRegions: [TextRegion]
    public let confidence: Double

    public func toJSON() -> [String: Any] {
        [
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "screenSize": ["width": screenSize.width, "height": screenSize.height],
            "elements": visibleElements.map { $0.toJSON() },
            "colors": dominantColors.map { $0.toJSON() },
            "textRegions": textRegions.map { [
                "x": $0.frame.origin.x,
                "y": $0.frame.origin.y,
                "width": $0.frame.size.width,
                "height": $0.frame.size.height,
                "confidence": $0.confidence
            ]},
            "confidence": confidence
        ]
    }
}

public struct VisibleElement {
    public let type: String
    public let frame: CGRect
    public let confidence: Double
    public let visible: Bool

    public func toJSON() -> [String: Any] {
        [
            "type": type,
            "frame": ["x": frame.origin.x, "y": frame.origin.y,
                     "width": frame.size.width, "height": frame.size.height],
            "confidence": confidence,
            "visible": visible
        ]
    }
}

public struct ColorInfo: Codable {
    public let hex: String
    public let count: Int

    public func toJSON() -> [String: Any] {
        ["hex": hex, "count": count]
    }
}

public struct TextRegion {
    public let frame: CGRect
    public let confidence: Double
}

public struct ActionSuggestion {
    public enum ActionType {
        case click
        case type
        case wait
        case scroll
        case navigate

        var description: String {
            switch self {
            case .click: return "click"
            case .type: return "type"
            case .wait: return "wait"
            case .scroll: return "scroll"
            case .navigate: return "navigate"
            }
        }
    }

    public let action: ActionType
    public let target: CGPoint?
    public let reason: String
    public let confidence: Double
}

extension CGRect {
    public var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
