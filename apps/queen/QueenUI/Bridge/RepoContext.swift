import Foundation

/// Provides Queen Chat agent with read access to the Trinity repository.
/// Auto-detects repo root via `git rev-parse`, caches file tree, reads files.
@MainActor
class RepoContext: ObservableObject {
    /// Lazy rootPath — avoids Process.waitUntilExit() during SwiftUI graph init
    /// which crashes AttributeGraph with nested runloop
    private var _rootPath: String?
    var rootPath: String {
        if let p = _rootPath { return p }
        let p = Self.detectRepoRoot()
        _rootPath = p
        return p
    }
    private var cachedTree: String?
    private var treeCacheTime: Date?
    private let treeCacheTTL: TimeInterval = 60

    // LRU file cache: up to 32 files, TTL 120s
    private var fileCache: [(path: String, content: String, time: Date)] = []
    private let fileCacheLimit = 32
    private let fileCacheTTL: TimeInterval = 120

    init() {
        // Intentionally lazy — rootPath detected on first use, not during init
    }

    // MARK: - Public API

    /// Returns depth-limited file tree (cached 60s)
    func fileTree(depth: Int = 3) -> String {
        if let cached = cachedTree,
           let cacheTime = treeCacheTime,
           Date().timeIntervalSince(cacheTime) < treeCacheTTL {
            return cached
        }
        let tree = buildFileTree(depth: depth)
        cachedTree = tree
        treeCacheTime = Date()
        return tree
    }

    /// Read a file relative to repo root. Returns nil if not found or too large.
    /// Uses LRU cache (32 files, 120s TTL).
    /// Security: blocks path traversal (../) and symlinks.
    func readFile(_ relativePath: String) -> String? {
        // Check LRU cache
        let now = Date()
        if let idx = fileCache.firstIndex(where: { $0.path == relativePath }) {
            let entry = fileCache[idx]
            if now.timeIntervalSince(entry.time) < fileCacheTTL {
                // Move to end (LRU)
                fileCache.append(fileCache.remove(at: idx))
                return entry.content
            } else {
                fileCache.remove(at: idx)
            }
        }

        let fullPath = (rootPath as NSString).appendingPathComponent(relativePath)

        // Security: resolve symlinks and block path traversal
        let resolvedPath = URL(fileURLWithPath: fullPath).standardized.path
        guard resolvedPath.hasPrefix(rootPath) else { return nil }

        // Security: reject symlinks
        let linkAttrs = try? FileManager.default.attributesOfItem(atPath: resolvedPath)
        guard (linkAttrs?[.type] as? FileAttributeType) != .typeSymbolicLink else { return nil }

        guard FileManager.default.fileExists(atPath: resolvedPath) else { return nil }

        // Skip binary and large files (>100KB)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: resolvedPath),
              let size = attrs[.size] as? Int,
              size < 100_000 else { return nil }

        guard let content = try? String(contentsOfFile: resolvedPath, encoding: .utf8) else { return nil }

        // Add to cache, evict oldest if full
        if fileCache.count >= fileCacheLimit {
            fileCache.removeFirst()
        }
        fileCache.append((path: relativePath, content: content, time: now))

        return content
    }

    /// Recent git commits (oneline format)
    func recentCommits(count: Int = 10) -> [String] {
        let output = shell("git", ["-C", rootPath, "log", "--oneline", "-\(count)"])
        return output.split(separator: "\n").map(String.init)
    }

    /// Search code for a query string (grep -rn, max 20 results)
    func searchCode(_ query: String) -> [SearchResult] {
        let output = shell("git", ["-C", rootPath, "grep", "-n", "--max-count=20", query, "--", "*.zig", "*.swift", "*.md"])
        return output.split(separator: "\n").prefix(20).compactMap { line in
            let str = String(line)
            // Format: file:line:content
            guard let firstColon = str.firstIndex(of: ":") else { return nil }
            let file = String(str[str.startIndex..<firstColon])
            let rest = String(str[str.index(after: firstColon)...])
            guard let secondColon = rest.firstIndex(of: ":") else { return nil }
            let lineNum = Int(rest[rest.startIndex..<secondColon]) ?? 0
            let content = String(rest[rest.index(after: secondColon)...])
            return SearchResult(file: file, line: lineNum, content: content.trimmingCharacters(in: .whitespaces))
        }
    }

    /// Read CLAUDE.md from repo root
    func claudeMD() -> String? {
        readFile("CLAUDE.md")
    }

    /// Detect file paths mentioned in user text (.zig, .swift, .md, .json, .tri, .v)
    func detectPaths(in text: String) -> [String] {
        let pattern = #"(?:^|\s|\")([\w./\-]+\.(?:zig|swift|md|json|tri|v|toml|yaml))\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }

    // MARK: - Private

    private static func detectRepoRoot() -> String {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--show-toplevel"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return path ?? FileManager.default.currentDirectoryPath
    }

    private func buildFileTree(depth: Int) -> String {
        var lines: [String] = []
        let root = URL(fileURLWithPath: rootPath)
        collectTree(at: root, prefix: "", depth: depth, maxDepth: depth, lines: &lines)
        return lines.joined(separator: "\n")
    }

    private let treeMaxEntries = 500

    private func collectTree(at url: URL, prefix: String, depth: Int, maxDepth: Int, lines: inout [String]) {
        guard depth > 0 else { return }
        guard lines.count < treeMaxEntries else { return }  // DoS protection
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }

        let sorted = items.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for item in sorted {
            guard lines.count < treeMaxEntries else { return }
            let name = item.lastPathComponent
            // Skip build artifacts, caches, node_modules
            if ["zig-out", ".zig-cache", "zig-cache", "node_modules", ".git", ".build"].contains(name) { continue }

            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            lines.append("\(prefix)\(isDir ? "\(name)/" : name)")
            if isDir {
                collectTree(at: item, prefix: prefix + "  ", depth: depth - 1, maxDepth: maxDepth, lines: &lines)
            }
        }
    }

    private func shell(_ command: String, _ arguments: [String]) -> String {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/\(command)")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

struct SearchResult {
    let file: String
    let line: Int
    let content: String
}
