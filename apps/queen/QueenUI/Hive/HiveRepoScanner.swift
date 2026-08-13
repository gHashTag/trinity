import Foundation

/// Reads the repository and reports what it could measure about each module -
/// and, for every field it could not read, why.
///
/// The scanner never substitutes a zero for a failed reading. A module whose
/// git history could not be read reports `churn30d = nil` plus the reason, and
/// the priority engine drops that weight from the denominator.
struct HiveRepoScanner {

    let projectRoot: String
    /// Source extensions that count toward lines, TODOs and test blocks.
    static let sourceExtensions: Set<String> = ["zig", "swift", "tri", "rs", "t27"]
    /// Files larger than this are counted by line only - no content scan.
    static let maxScannedFileBytes = 2 * 1024 * 1024

    /// Directories that are not this project's source and must not be measured
    /// as if they were. Two separate harms: walking `.build` and `zig-cache`
    /// takes the scan from seconds to over a minute, and counting generated or
    /// vendored code inflates a module's size and TODO density with lines
    /// nobody wrote and no bee should edit.
    static let excludedDirectories: Set<String> = [
        ".build", ".git", ".swiftpm", "zig-cache", "zig-out", "target",
        "vendor", "node_modules", "Pods", "DerivedData", "gen", "generated",
        "_to_delete",
    ]

    /// True when any path component below `base` is an excluded directory.
    /// The walker's `skipDescendants()` handles the common case; this catches
    /// a symlink or a resolved path that re-enters an excluded tree sideways.
    static func isExcluded(_ url: URL, relativeTo base: String) -> Bool {
        let path = url.path
        guard path.hasPrefix(base) else { return false }
        return String(path.dropFirst(base.count))
            .components(separatedBy: "/")
            .contains { excludedDirectories.contains($0) }
    }

    init(projectRoot: String = TrinityRuntimePaths.projectRoot) {
        self.projectRoot = projectRoot
    }

    /// The two halves of her system: the Zig core, and her own cockpit.
    ///
    /// `externalTests` matters: Zig keeps `test "..."` blocks inside the module,
    /// but Swift keeps them in a sibling `Tests/` tree. Counting only in-tree
    /// blocks would report every cockpit module as wholly untested - a true
    /// count producing a false statement.
    private var realmRoots: [(relative: String, realm: HiveModuleFacts.Realm, externalTests: String?)] {
        [
            ("src", .core, nil),
            ("apps/queen/QueenUI", .cockpit, "apps/queen/Tests"),
        ]
    }

    // MARK: - Entry point

    func scan() -> [HiveModuleFacts] {
        let fm = FileManager.default
        let churn = readChurn()
        let issues = readIssueCounts()

        var results: [HiveModuleFacts] = []

        for root in realmRoots {
            let rootPath = "\(projectRoot)/\(root.relative)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: rootPath, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            guard let entries = try? fm.contentsOfDirectory(atPath: rootPath) else { continue }

            let externalTests = root.externalTests.map {
                attributeExternalTests(
                    testsRoot: "\(projectRoot)/\($0)",
                    moduleRoot: rootPath,
                    modulePrefix: root.relative
                )
            }

            for entry in entries.sorted() {
                if entry.hasPrefix(".") { continue }
                let modulePath = "\(rootPath)/\(entry)"
                var entryIsDir: ObjCBool = false
                guard fm.fileExists(atPath: modulePath, isDirectory: &entryIsDir),
                      entryIsDir.boolValue else { continue }

                let moduleKey = "\(root.relative)/\(entry)"
                var facts = HiveModuleFacts(
                    module: moduleKey,
                    path: moduleKey,
                    realm: root.realm
                )

                let content = measureContent(at: modulePath)
                facts.lines = content.lines
                facts.todos = content.todos
                facts.testBlocks = content.testBlocks + (externalTests?[moduleKey] ?? 0)
                if content.lines == 0 {
                    facts.unmeasuredReasons[.sizeRisk] = "no source files under \(moduleKey)"
                    facts.lines = nil
                    facts.todos = nil
                    facts.testBlocks = nil
                    facts.unmeasuredReasons[.todoDensity] = "no source files under \(moduleKey)"
                    facts.unmeasuredReasons[.testGap] = "no source files under \(moduleKey)"
                }

                switch churn {
                case .success(let table):
                    facts.churn30d = table[moduleKey] ?? 0
                case .failure(let why):
                    facts.unmeasuredReasons[.churn] = why
                }

                switch issues {
                case .success(let table):
                    facts.openIssues = table[moduleKey] ?? 0
                case .failure(let why):
                    facts.unmeasuredReasons[.openIssues] = why
                }

                if let status = readCellStatus(at: modulePath) {
                    facts.declaredStatus = status
                } else {
                    facts.unmeasuredReasons[.declaredIncomplete] = "no cell.tri in \(moduleKey)"
                }

                results.append(facts)
            }
        }

        return results
    }

    // MARK: - Content

    struct ContentMeasurement {
        var lines = 0
        var todos = 0
        var testBlocks = 0
    }

    func measureContent(at directory: String) -> ContentMeasurement {
        var out = ContentMeasurement()
        let fm = FileManager.default
        guard let walker = fm.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return out }

        let base = directory.hasSuffix("/") ? directory : directory + "/"
        for case let url as URL in walker {
            if Self.excludedDirectories.contains(url.lastPathComponent) {
                walker.skipDescendants()
                continue
            }
            guard Self.sourceExtensions.contains(url.pathExtension) else { continue }
            guard !Self.isExcluded(url, relativeTo: base) else { continue }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values?.isRegularFile == true else { continue }
            if let size = values?.fileSize, size > Self.maxScannedFileBytes { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }

            let counts = Self.count(in: text)
            out.lines += counts.lines
            out.todos += counts.todos
            out.testBlocks += counts.testBlocks
        }
        return out
    }

    /// Line, marker and test-block counts for one file's text.
    /// Split out so the counting rule is testable without touching disk.
    static func count(in text: String) -> ContentMeasurement {
        var out = ContentMeasurement()
        text.enumerateLines { line, _ in
            out.lines += 1
            if line.contains("TODO") || line.contains("FIXME")
                || line.contains("XXX") || line.contains("HACK") {
                out.todos += 1
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Zig `test "name" {`, Swift `func testX(` / `@Test`.
            if trimmed.hasPrefix("test \"")
                || trimmed.hasPrefix("func test")
                || trimmed.hasPrefix("@Test") {
                out.testBlocks += 1
            }
        }
        return out
    }

    // MARK: - External tests

    /// Attributes test blocks living outside the module tree back to a module.
    ///
    /// A test file is credited to the module whose source-file stems it names
    /// most often, and to exactly one module - so a shared helper cannot
    /// inflate the coverage of everything it touches. When a test file matches
    /// nothing, its blocks are dropped rather than spread around.
    func attributeExternalTests(
        testsRoot: String,
        moduleRoot: String,
        modulePrefix: String
    ) -> [String: Int] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: testsRoot) else { return [:] }

        // stem -> module, e.g. "HiveOrchestrator" -> "apps/queen/QueenUI/Hive".
        // Both sides are symlink-resolved: on macOS a temporary directory is
        // reached as /var/... but enumerated as /private/var/..., and comparing
        // the two raw strings silently yields an empty module name.
        let moduleBase = URL(fileURLWithPath: moduleRoot).resolvingSymlinksInPath()
        var stemOwner: [String: String] = [:]
        if let walker = fm.enumerator(
            at: moduleBase,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            let basePath = moduleBase.path + "/"
            for case let url as URL in walker {
                if Self.excludedDirectories.contains(url.lastPathComponent) {
                    walker.skipDescendants()
                    continue
                }
                guard Self.sourceExtensions.contains(url.pathExtension) else { continue }
                let path = url.resolvingSymlinksInPath().path
                guard path.hasPrefix(basePath) else { continue }
                let relative = String(path.dropFirst(basePath.count))
                let components = relative.components(separatedBy: "/")
                guard components.count > 1, let module = components.first, !module.isEmpty else { continue }
                stemOwner[url.deletingPathExtension().lastPathComponent] = "\(modulePrefix)/\(module)"
            }
        }

        var counts: [String: Int] = [:]
        guard let testWalker = fm.enumerator(
            at: URL(fileURLWithPath: testsRoot),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return counts }

        for case let url as URL in testWalker {
            if Self.excludedDirectories.contains(url.lastPathComponent) {
                testWalker.skipDescendants()
                continue
            }
            guard Self.sourceExtensions.contains(url.pathExtension) else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let blocks = Self.count(in: text).testBlocks
            guard blocks > 0 else { continue }

            // Tokenise the test file once and intersect, rather than running
            // `text.contains(stem)` for every stem. The naive form is
            // stems x files x substring searches over grapheme-aware Swift
            // strings, and on a tree of this size it cost more than the git log
            // and the whole file walk put together. Matching whole tokens is
            // also the more correct rule: a file naming `ChatMessageStore` no
            // longer silently credits `ChatMessage`.
            let tokens = Self.identifiers(in: text)
            var hits: [String: Int] = [:]
            for (stem, module) in stemOwner where tokens.contains(stem) {
                hits[module, default: 0] += 1
            }
            guard let best = hits.max(by: {
                $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key
            }) else { continue }
            counts[best.key, default: 0] += blocks
        }

        return counts
    }

    /// Every identifier-shaped token in a source file, as a set.
    static func identifiers(in text: String) -> Set<String> {
        var tokens = Set<String>()
        var current = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "_" {
                current.append(scalar)
            } else if !current.isEmpty {
                tokens.insert(String(current))
                current = String.UnicodeScalarView()
            }
        }
        if !current.isEmpty { tokens.insert(String(current)) }
        return tokens
    }

    // MARK: - Cell status

    func readCellStatus(at directory: String) -> String? {
        let path = "\(directory)/cell.tri"
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("status:") else { continue }
            return trimmed
                .replacingOccurrences(of: "status:", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        // A cell exists but declares no status - that is a reading, not a gap.
        return "undeclared"
    }

    // MARK: - Churn

    enum Reading<T> {
        case success(T)
        case failure(String)
    }

    /// Commits per module over the last 30 days, from `git log --name-only`.
    /// Returns a reason rather than an empty table when git cannot be read.
    func readChurn() -> Reading<[String: Int]> {
        let result = HiveProcess.run(
            executable: "/usr/bin/git",
            arguments: [
                "-C", projectRoot,
                "log", "--since=30.days", "--name-only", "--pretty=format:%H",
            ],
            timeout: 30
        )
        guard result.exitCode == 0 else {
            let detail = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(detail.isEmpty ? "git log exited \(result.exitCode)" : detail)
        }
        return .success(Self.parseChurn(result.standardOutput, prefixes: realmRoots.map(\.relative)))
    }

    /// One commit counts once per module it touched.
    static func parseChurn(_ log: String, prefixes: [String]) -> [String: Int] {
        var counts: [String: Int] = [:]
        var currentModules = Set<String>()

        func flush() {
            for module in currentModules { counts[module, default: 0] += 1 }
            currentModules.removeAll()
        }

        for line in log.components(separatedBy: "\n") {
            if line.isEmpty { continue }
            // A 40-char hex line starts a new commit.
            if line.count == 40, line.allSatisfy({ $0.isHexDigit }) {
                flush()
                continue
            }
            for prefix in prefixes where line.hasPrefix("\(prefix)/") {
                let remainder = line.dropFirst(prefix.count + 1)
                guard let segment = remainder.components(separatedBy: "/").first,
                      !segment.isEmpty else { continue }
                currentModules.insert("\(prefix)/\(segment)")
            }
        }
        flush()
        return counts
    }

    // MARK: - Issues

    /// A snapshot older than this is not a measurement of today's repository.
    static let maxIssueSnapshotAgeDays = 7

    /// Open issues attributed to a module by title/body mention.
    ///
    /// Absent snapshot is reported as unreadable, never as "no issues" - and a
    /// *stale* snapshot is reported as unreadable too. The file on this machine
    /// was 116 days old and was being scored as a current reading, which is the
    /// exact failure this whole instrument exists to prevent.
    func readIssueCounts(now: Date = Date()) -> Reading<[String: Int]> {
        let path = "\(projectRoot)/.trinity/issues_snapshot.json"
        let fm = FileManager.default
        guard let data = fm.contents(atPath: path) else {
            return .failure("no .trinity/issues_snapshot.json on disk")
        }

        let modified = (try? fm.attributesOfItem(atPath: path)[.modificationDate]) as? Date
        if let modified {
            let ageDays = Int(now.timeIntervalSince(modified) / 86_400)
            if ageDays > Self.maxIssueSnapshotAgeDays {
                return .failure("issues snapshot is \(ageDays) days stale - refresh it before this signal counts")
            }
        } else {
            return .failure("issues snapshot has no modification date - age unknown")
        }

        guard let text = String(data: data, encoding: .utf8) else {
            return .failure("issues_snapshot.json is not utf-8")
        }
        return .success(Self.parseIssueMentions(text, prefixes: realmRoots.map(\.relative)))
    }

    /// Counts how often each module path is named in the snapshot text.
    /// Deliberately crude: it is a weak signal and is labelled as one.
    static func parseIssueMentions(_ text: String, prefixes: [String]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for prefix in prefixes {
            var search = text[...]
            while let range = search.range(of: "\(prefix)/") {
                let rest = search[range.upperBound...]
                let segment = rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
                if !segment.isEmpty {
                    counts["\(prefix)/\(segment)", default: 0] += 1
                }
                search = rest
            }
        }
        return counts
    }
}
