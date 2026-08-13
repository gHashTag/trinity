import Foundation

// ===========================================================================
// VERIFICATION - a bee's success is a claim until something executes.
//
// Without this, the Queen's only evidence that a module improved is the bee's
// own final paragraph. That is the model grading its own homework: it is how
// an autonomous loop accumulates confident, plausible, wrong work.
//
// Three outcomes, never two. "Could not check" is its own verdict and must
// never collapse into "passed".
// ===========================================================================

enum HiveVerdict: Equatable {
    case passed(String)
    case failed(String)
    /// No runnable check exists for this realm, or the checker itself broke.
    case unavailable(String)

    var label: String {
        switch self {
        case .passed: return "VERIFIED"
        case .failed: return "BROKE THE BUILD"
        case .unavailable: return "UNVERIFIED"
        }
    }

    var detail: String {
        switch self {
        case .passed(let d), .failed(let d), .unavailable(let d): return d
        }
    }

    /// Only a passing check clears a bee's work. Unavailable does not.
    var isPass: Bool {
        if case .passed = self { return true }
        return false
    }

    /// A failing check is the only verdict that costs the bee an attempt.
    /// An absent checker is the Queen's gap, not the bee's fault.
    var isFail: Bool {
        if case .failed = self { return true }
        return false
    }
}

/// Whether the evidence behind a recorded verdict still applies.
///
/// Four outcomes, not two. A lifecycle state like `review` is a claim unless
/// the evidence behind it is *current*: a verdict recorded on Monday says
/// nothing about a tree that moved on Tuesday, and without the commit there is
/// no way to tell the two apart. That is the same stale-reading failure already
/// fixed for the issues snapshot, left live in the verification record.
enum HiveEvidenceState: Equatable {
    case current
    case stale(measuredAt: String)
    /// A verdict exists but no commit was recorded with it.
    case unrecorded
    case unknown(String)

    var isCurrent: Bool { self == .current }

    var label: String {
        switch self {
        case .current: return "CURRENT"
        case .stale: return "STALE"
        case .unrecorded: return "NO COMMIT RECORDED"
        case .unknown: return "UNKNOWN"
        }
    }
}

struct HiveVerifier {

    let projectRoot: String
    /// Wall-clock ceiling for the whole check.
    var timeout: TimeInterval = 900

    init(projectRoot: String = TrinityRuntimePaths.projectRoot) {
        self.projectRoot = projectRoot
    }

    // MARK: - Entry point

    func verify(task: HiveTask) -> HiveVerdict {
        // A bee isolated in a worktree changed files there. If that worktree
        // cannot be located, falling back to the main checkout would run the
        // checks against a tree the bee never touched and report a green tick
        // for work nobody examined. Refuse instead.
        guard let root = workingRoot(for: task) else {
            return .unavailable(
                "bee ran in worktree `\(task.branch ?? "?")` but no such worktree is registered - "
                    + "verifying the main checkout would grade the wrong tree"
            )
        }

        switch task.realm {
        case HiveModuleFacts.Realm.cockpit.rawValue:
            return verifySwiftPackage(at: "\(root)/apps/queen")
        case HiveModuleFacts.Realm.core.rawValue:
            // `zig build` in this checkout fails before it compiles anything:
            // build.zig.zon pins `.hash = "PLACEHOLDER"` for zig_hdc. Claiming
            // a Zig change is verified would be a lie with a green tick on it.
            return .unavailable(
                "no runnable check for the Zig core - `zig build` fails at build.zig.zon (.hash = \"PLACEHOLDER\")"
            )
        default:
            return .unavailable("no check is defined for realm \(task.realm)")
        }
    }

    // MARK: - Swift package

    func verifySwiftPackage(at packagePath: String) -> HiveVerdict {
        guard FileManager.default.fileExists(atPath: "\(packagePath)/Package.swift") else {
            return .unavailable("no Package.swift at \(packagePath)")
        }
        guard let swift = HiveProcess.resolve("swift", overrideEnvKey: "SWIFT_EXECUTABLE")
            ?? firstExecutable(["/usr/bin/swift"]) else {
            return .unavailable("swift toolchain not found")
        }

        let build = HiveProcess.run(
            executable: swift,
            arguments: ["build"],
            currentDirectory: packagePath,
            timeout: timeout
        )
        if build.timedOut {
            return .unavailable("`swift build` exceeded \(Int(timeout))s - verdict unknown, not assumed")
        }
        // A verdict is only as good as the output it was read from. If the
        // drain was cut short, a pass has no tally behind it and a failure has
        // an empty detail - both of which read as evidence and are not.
        if build.outputTruncated {
            return .unavailable("`swift build` output was not read to the end - verdict unknown, not assumed")
        }
        if build.exitCode != 0 {
            return .failed("`swift build` failed:\n" + Self.tail(build.standardError + build.standardOutput))
        }

        let test = HiveProcess.run(
            executable: swift,
            arguments: ["test"],
            currentDirectory: packagePath,
            timeout: timeout
        )
        if test.timedOut {
            return .unavailable("`swift test` exceeded \(Int(timeout))s - verdict unknown, not assumed")
        }
        if test.outputTruncated {
            return .unavailable("`swift test` output was not read to the end - verdict unknown, not assumed")
        }
        if test.exitCode != 0 {
            return .failed("`swift test` failed:\n" + Self.tail(test.standardOutput + test.standardError))
        }

        let summary = Self.testSummary(test.standardOutput) ?? "build and tests passed"
        return .passed(summary)
    }

    // MARK: - Worktree resolution

    /// A bee isolated in a worktree changed files there, not here. Verifying
    /// the main checkout would grade the wrong tree - green while the bee's
    /// branch is broken.
    /// Returns nil when the task named a worktree that cannot be found -
    /// never the main checkout as a consolation prize.
    func workingRoot(for task: HiveTask) -> String? {
        guard let branch = task.branch else { return projectRoot }
        let result = HiveProcess.run(
            executable: "/usr/bin/git",
            arguments: ["-C", projectRoot, "worktree", "list", "--porcelain"],
            timeout: 30
        )
        guard result.exitCode == 0 else { return nil }
        return Self.worktreePath(named: branch, in: result.standardOutput)
    }

    /// Parses `git worktree list --porcelain`, matching either the branch ref
    /// or the trailing path component against the worktree name.
    static func worktreePath(named name: String, in porcelain: String) -> String? {
        var currentPath: String?
        for line in porcelain.components(separatedBy: "\n") {
            if line.hasPrefix("worktree ") {
                currentPath = String(line.dropFirst("worktree ".count))
                if let currentPath, URL(fileURLWithPath: currentPath).lastPathComponent == name {
                    return currentPath
                }
            } else if line.hasPrefix("branch ") {
                let ref = String(line.dropFirst("branch ".count))
                if ref == "refs/heads/\(name)" || ref.hasSuffix("/\(name)") {
                    return currentPath
                }
            }
        }
        return nil
    }

    // MARK: - Output shaping

    /// Pulls swift-testing's own tally out of the log, so the recorded verdict
    /// is a number the tool printed rather than a sentence we composed.
    static func testSummary(_ output: String) -> String? {
        for line in output.components(separatedBy: "\n").reversed() {
            if line.contains("Test run with") && line.contains("test") {
                return line.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "\u{2714} ", with: "")
            }
        }
        return nil
    }

    // MARK: - Evidence currency

    /// The commit a verdict was measured against.
    func head(at root: String) -> String? {
        let result = HiveProcess.run(
            executable: "/usr/bin/git",
            arguments: ["-C", root, "rev-parse", "HEAD"],
            timeout: 20
        )
        // A partial read of a commit hash is worse than none: it would be
        // recorded as the commit a verdict was measured against and could never
        // match a full hash again.
        guard result.exitCode == 0, !result.outputTruncated else { return nil }
        let head = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return head.isEmpty ? nil : head
    }

    /// Whether a recorded verdict still describes the current tree. The commit
    /// may match, differ, or be unknown on either side. Unknown is never
    /// reported as current.
    static func evidenceState(
        verifiedAt: String?,
        currentHead: String?
    ) -> HiveEvidenceState {
        guard let verifiedAt, !verifiedAt.isEmpty else {
            return .unrecorded
        }
        guard let currentHead, !currentHead.isEmpty else {
            return .unknown("could not read the current commit")
        }
        return verifiedAt == currentHead ? .current : .stale(measuredAt: verifiedAt)
    }

    static func tail(_ text: String, lines: Int = 25) -> String {
        let kept = text
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .suffix(lines)
        return kept.joined(separator: "\n")
    }

    private func firstExecutable(_ paths: [String]) -> String? {
        paths.first(where: FileManager.default.isExecutableFile(atPath:))
    }
}
