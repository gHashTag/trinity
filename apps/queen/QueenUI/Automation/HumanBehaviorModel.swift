import Foundation
import AppKit
import CoreGraphics

/// Human-like timing and variability models for realistic UI testing
public struct HumanBehaviorModel {
    // MARK: - Session State

    private static var accumulatedTypingErrors: Int = 0
    private static var totalKeystrokes: Int = 0

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

    /// Generate realistic typing with natural pauses and potential typos
    public static func realisticTypingSequence(for text: String, proficiency: TypingProficiency) -> [TypingAction] {
        var actions: [TypingAction] = []
        let chunks = text.split(separator: " ").map { String($0) }

        for (index, chunk) in chunks.enumerated() {
            // Type the chunk
            actions.append(.type(chunk))

            // Add inter-word delay based on proficiency
            let wordDelay: TimeInterval
            switch proficiency {
            case .novice: wordDelay = randomDelay(mean: 400, stdDev: 150)
            case .average: wordDelay = randomDelay(mean: 200, stdDev: 80)
            case .expert: wordDelay = randomDelay(mean: 100, stdDev: 40)
            }
            actions.append(.pause(wordDelay))

            // Chance of typo for longer words
            if chunk.count > 5 && Double.random(in: 0...1) < typoProbability(proficiency: proficiency) {
                let typoIndex = Int.random(in: 0..<chunk.count)
                let typoChar = chunk[chunk.index(chunk.startIndex, offsetBy: typoIndex)]
                let wrongChar = randomTypoSubstitute(for: typoChar)

                // Type wrong character
                actions.append(.type(String(wrongChar)))
                actions.append(.pause(correctionPause()))

                // Delete and correct
                actions.append(.delete(1))
                actions.append(.pause(randomDelay(mean: 150, stdDev: 50)))
            }

            // Pause at sentence boundaries
            if chunk.hasSuffix(".") || chunk.hasSuffix("?") || chunk.hasSuffix("!") {
                actions.append(.pause(randomDelay(mean: 600, stdDev: 200)))
            }

            // Mid-sentence comma pause
            if chunk.hasSuffix(",") {
                actions.append(.pause(randomDelay(mean: 300, stdDev: 100)))
            }
        }

        return actions
    }

    /// Generate a realistic typo substitute character
    private static func randomTypoSubstitute(for char: Character) -> Character {
        let nearbyKeys: [Character: [Character]] = [
            "a": ["s", "q", "z", "w"],
            "s": ["a", "d", "w", "x", "z", "e"],
            "d": ["s", "f", "e", "r", "c", "x"],
            "f": ["d", "g", "r", "t", "v", "c"],
            "j": ["h", "k", "u", "i", "m", "n"],
            "k": ["j", "l", "i", "o", "m", ","],
            "l": ["k", ";", "o", "p", ".", "."],
            "e": ["w", "r", "s", "d", "3", "4"],
            "r": ["e", "t", "d", "f", "4", "5"],
            "t": ["r", "y", "f", "g", "5", "6"],
            "i": ["u", "o", "j", "k", "8", "9"],
            "o": ["i", "p", "k", "l", "9", "0"],
        ]
        return nearbyKeys[char]?.randomElement() ?? char
    }

    /// Adaptive reading speed based on content complexity
    public static func adaptiveReadingTime(for text: String, contentType: ReadingContentType) -> TimeInterval {
        let baseTime = readingTime(for: text)
        let complexityMultiplier: Double

        switch contentType {
        case .simple: complexityMultiplier = 0.8
        case .technical: complexityMultiplier = 1.5
        case .dense: complexityMultiplier = 2.0
        case .mixed: complexityMultiplier = 1.0
        }

        return baseTime * complexityMultiplier
    }

    /// Dwell time before action (hesitation based on perceived complexity)
    public static func dwellTimeBeforeAction(complexity: ActionComplexity, confidence: Double = 0.8) -> TimeInterval {
        let baseDecision = decisionTime(complexity: complexity)
        let hesitationFactor = 1.0 + (1.0 - confidence) * 2.0
        return baseDecision * hesitationFactor
    }

    /// Post-action verification time (checking if action succeeded)
    public static func verificationTime(for actionType: String) -> TimeInterval {
        switch actionType {
        case "click": return randomDelay(mean: 300, stdDev: 100)
        case "navigate": return randomDelay(mean: 500, stdDev: 150)
        case "type": return randomDelay(mean: 400, stdDev: 120)
        case "submit": return randomDelay(mean: 800, stdDev: 250)
        default: return randomDelay(mean: 300, stdDev: 100)
        }
    }

    /// Fatigue simulation - actions get slower over time
    public static func fatigueMultiplier(stepsCompleted: Int, maxSteps: Int) -> Double {
        let fatigueRatio = Double(stepsCompleted) / Double(maxSteps)
        return 1.0 + (fatigueRatio * 0.5) // Up to 50% slower
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

// MARK: - Supporting Types

/// Individual typing action in a sequence
public enum TypingAction {
    case type(String)
    case pause(TimeInterval)
    case delete(Int)
}

/// Content complexity for adaptive reading
public enum ReadingContentType {
    case simple      // Plain text, short sentences
    case technical   // Code, formulas, terminology
    case dense       // Academic, complex structures
    case mixed       // Combination
}

/// Extended persona with more behavioral parameters
public struct EnhancedPersona {
    public let name: String
    public let proficiency: TypingProficiency
    public let readingSpeed: ReadingSpeed
    public let decisionSpeed: DecisionSpeed
    public let errorRate: ErrorRate
    public let patience: TimeInterval
    public let explorationTendency: Double // 0 = focused, 1 = exploratory

    public init(
        name: String,
        proficiency: TypingProficiency,
        readingSpeed: ReadingSpeed = .average,
        decisionSpeed: DecisionSpeed = .normal,
        errorRate: ErrorRate = .normal,
        patience: TimeInterval = 30,
        explorationTendency: Double = 0.5
    ) {
        self.name = name
        self.proficiency = proficiency
        self.readingSpeed = readingSpeed
        self.decisionSpeed = decisionSpeed
        self.errorRate = errorRate
        self.patience = patience
        self.explorationTendency = explorationTendency
    }

    // Predefined personas
    public static let carefulNovice = EnhancedPersona(
        name: "Careful Novice",
        proficiency: .novice,
        readingSpeed: .slow,
        decisionSpeed: .cautious,
        errorRate: .high,
        patience: 60,
        explorationTendency: 0.8
    )

    public static let powerUser = EnhancedPersona(
        name: "Power User",
        proficiency: .expert,
        readingSpeed: .fast,
        decisionSpeed: .fast,
        errorRate: .low,
        patience: 10,
        explorationTendency: 0.2
    )

    public static let elderlyUser = EnhancedPersona(
        name: "Elderly User",
        proficiency: .novice,
        readingSpeed: .slow,
        decisionSpeed: .cautious,
        errorRate: .high,
        patience: 90,
        explorationTendency: 0.3
    )

    public static let distractedUser = EnhancedPersona(
        name: "Distracted User",
        proficiency: .average,
        readingSpeed: .average,
        decisionSpeed: .fast,
        errorRate: .high,
        patience: 15,
        explorationTendency: 0.7
    )
}

public enum ReadingSpeed {
    case slow    // 1.5x normal reading time
    case average // normal
    case fast    // 0.7x normal
}

public enum DecisionSpeed {
    case fast      // Quick decisions
    case normal    // Average
    case cautious  // Deliberate
}

public enum ErrorRate {
    case low    // 0.5% typos
    case normal // 2% typos
    case high   // 5% typos
}
