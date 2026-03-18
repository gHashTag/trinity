import Foundation

/// Bridge to Trinity CLI (tri) — spawn commands, parse output, stream errors
@MainActor
public class TriBridge {
    public static let shared = TriBridge()

    private init() {}

    /// Execute tri command and return output
    public func execute(_ command: String) async throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/tri")
        task.arguments = command.components(separatedBy: " ")

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
