import Foundation

/// Resolves the canonical Trinity repository for standalone and embedded hosts.
/// Standalone Queen defaults to its working directory. Embedded hosts configure
/// an explicit root and never need to change the process-wide working directory.
public enum TrinityRuntimePaths {
    private static let lock = NSLock()
    private static var rootOverride: String?

    public static func configure(projectRoot: String) {
        let normalized = URL(fileURLWithPath: projectRoot)
            .standardizedFileURL
            .path
        lock.lock()
        rootOverride = normalized
        lock.unlock()
    }

    public static var projectRoot: String {
        lock.lock()
        let configured = rootOverride
        lock.unlock()
        if let configured { return configured }

        if let environmentRoot = ProcessInfo.processInfo.environment["TRINITY_ROOT"],
           !environmentRoot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: environmentRoot).standardizedFileURL.path
        }

        return FileManager.default.currentDirectoryPath
    }

    public static var stateRoot: String {
        URL(fileURLWithPath: projectRoot)
            .appendingPathComponent(".trinity", isDirectory: true)
            .path
    }

    public static var triExecutable: String {
        if let configured = ProcessInfo.processInfo.environment["TRI_EXECUTABLE"],
           FileManager.default.isExecutableFile(atPath: configured) {
            return configured
        }

        let candidates = [
            "zig-out/bin/tri",
            "release/v2.0.0/test-install/tri",
            "release/v2.0.0/bin/tri",
        ].map {
            URL(fileURLWithPath: projectRoot)
                .appendingPathComponent($0)
                .path
        } + [
            "/opt/homebrew/bin/tri",
            "/usr/local/bin/tri",
        ]

        if let executable = candidates.first(
            where: FileManager.default.isExecutableFile(atPath:)
        ) {
            return executable
        }

        return candidates[0]
    }
}
