import Foundation
import AppKit
import CoreGraphics

/// Human-like timing and variability models for realistic UI testing
public struct HumanBehaviorModel {
    // MARK: - Timing Models

    /// Gaussian-distributed delay (mean in ms, std dev in ms)
    public static func randomDelay(mean: Double, stdDev: Double) -> TimeInterval {
        let μ = mean / 1000.0 // Convert to seconds
        let σ = stdDev / 1000.0
        // Box-Muller transform for Gaussian distribution
        let u1 = Double.random(in: 0...1)
        let u2 = Double.random(in: 0...1)
        let z0 = sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
        let gaussian = μ + σ * z0
        return max(0.05, gaussian) // Minimum 50ms
    }

    /// Reading time based on text length (average 200ms per word + base time)
    public static func readingTime(for text: String) -> TimeInterval {
        let wordCount = Double(text.split(separator: " ").count)
        return 0.5 + (wordCount * 0.2) // Base 500ms + 200ms per word
    }

    /// Decision time before action (simulating thought process)
    public static func decisionTime(complexity: ActionComplexity) -> TimeInterval {
        switch complexity {
        case .simple: return randomDelay(mean: 200, stdDev: 50)
        case .medium: return randomDelay(mean: 500, stdDev: 150)
        case .complex: return randomDelay(mean: 1200, stdDev: 400)
        }
    }

    // MARK: - Click Variability

    /// Add human-like jitter to click coordinates (±10-20px)
    public static func jitteredPoint(x: CGFloat, y: CGFloat, amount: CGFloat = 15) -> CGPoint {
        let jitterX = CGFloat.random(in: -amount...amount)
        let jitterY = CGFloat.random(in: -amount...amount)
        return CGPoint(x: x + jitterX, y: y + jitterY)
    }

    /// Simulate Fitts' Law movement time
    /// MT = a + b * log2(D/W + 1)
    /// D = distance to target, W = width of target
    public static func fittsMovementTime(from: CGPoint, to: CGPoint, targetWidth: CGFloat = 50) -> TimeInterval {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let distance = sqrt(dx * dx + dy * dy)
        let index = Darwin.log2(distance / targetWidth + 1)
        // Constants from Fitts' Law studies (in seconds)
        let a: Double = 0.05  // Base time
        let b: Double = 0.10  // Slope
        return max(0.05, a + b * index)
    }

    // MARK: - Typing Variability

    /// Realistic typing with variable speed and mistakes
    public static func typingTime(for text: String, proficiency: TypingProficiency = .average) -> TimeInterval {
        let baseTime: TimeInterval
        let variance: TimeInterval

        switch proficiency {
        case .novice:
            baseTime = 0.3 // 300ms per character
            variance = 0.15
        case .average:
            baseTime = 0.15 // 150ms per character
            variance = 0.05
        case .expert:
            baseTime = 0.08 // 80ms per character
            variance = 0.02
        }

        let randomFactor = Double.random(in: (1 - variance/baseTime)...(1 + variance/baseTime))
        return Double(text.count) * baseTime * randomFactor
    }

    /// Probability of making a typo (decreases with proficiency)
    public static func typoProbability(proficiency: TypingProficiency) -> Double {
        switch proficiency {
        case .novice: return 0.05 // 5% error rate
        case .average: return 0.02 // 2% error rate
        case .expert: return 0.005 // 0.5% error rate
        }
    }

    /// Simulate correction pause after typo
    public static func correctionPause() -> TimeInterval {
        randomDelay(mean: 800, stdDev: 300)
    }

    // MARK: - Scroll Behavior

    /// Realistic scroll distance and speed
    public static func scrollDistance(targetDistance: CGFloat) -> CGFloat {
        // Humans typically scroll in chunks, not precisely
        let chunkSize: CGFloat = 150
        let chunks = Int(targetDistance / chunkSize)
        let remainder = targetDistance.truncatingRemainder(dividingBy: chunkSize)
        // 70% chance to scroll remainder if > 50px
        return CGFloat(chunks) * chunkSize + (remainder > 50 ? (Double.random(in: 0...1) < 0.7 ? remainder : 0) : 0)
    }

    // MARK: - Gaze Simulation

    /// Simulate gaze fixation duration
    public static func gazeFixation(contentType: GazeContentType) -> TimeInterval {
        switch contentType {
        case .text: return randomDelay(mean: 300, stdDev: 100)
        case .image: return randomDelay(mean: 400, stdDev: 150)
        case .button: return randomDelay(mean: 200, stdDev: 50)
        case .form: return randomDelay(mean: 250, stdDev: 75)
        case .navigation: return randomDelay(mean: 150, stdDev: 50)
        }
    }

    // MARK: - Rage Detection

    /// Detect potential "rage click" pattern
    public static func isRageClick(clickHistory: [ClickEvent]) -> Bool {
        guard clickHistory.count >= 3 else { return false }

        let now = Date()
        let recentClicks = clickHistory.filter { now.timeIntervalSince($0.timestamp) < 2.0 }

        // Check for 3+ clicks in same area within 2 seconds
        guard recentClicks.count >= 3 else { return false }

        // Check if clicks are spatially clustered (within 50px)
        let avgX = recentClicks.map { $0.x }.reduce(0, +) / CGFloat(recentClicks.count)
        let avgY = recentClicks.map { $0.y }.reduce(0, +) / CGFloat(recentClicks.count)

        let allClustered = recentClicks.allSatisfy {
            abs($0.x - avgX) < 50 && abs($0.y - avgY) < 50
        }

        return allClustered
    }
}

// MARK: - Supporting Types

public enum ActionComplexity {
    case simple    // Click button, simple navigation
    case medium    // Form input, menu selection
    case complex   // Multi-step workflow, configuration
}

public enum TypingProficiency {
    case novice
    case average
    case expert
}

public enum GazeContentType {
    case text
    case image
    case button
    case form
    case navigation
}

public struct ClickEvent {
    public let timestamp: Date
    public let x: CGFloat
    public let y: CGFloat

    public init(timestamp: Date, x: CGFloat, y: CGFloat) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
    }
}

private func log2(_ x: CGFloat) -> Double {
    Darwin.log(x) / Darwin.log(2)
}
