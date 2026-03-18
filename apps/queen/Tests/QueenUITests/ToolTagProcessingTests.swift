import Testing
import Foundation
@testable import QueenUILib

@Suite("Tool Tag Processing")
struct ToolTagProcessingTests {

    @Test func parseReadTag() {
        let text = "Let me check the file [READ:src/vsa.zig] for you."
        let pattern = #"\[READ:(?:file://)?([^\]]+)\]"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        #expect(matches.count == 1)
        let r = Range(matches[0].range(at: 1), in: text)!
        #expect(String(text[r]) == "src/vsa.zig")
    }

    @Test func parseReadTag_fileURL() {
        let text = "[READ:file:///Users/test/src/main.zig]"
        let pattern = #"\[READ:(?:file://)?([^\]]+)\]"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        #expect(matches.count == 1)
        let r = Range(matches[0].range(at: 1), in: text)!
        #expect(String(text[r]) == "/Users/test/src/main.zig")
    }

    @Test func parseRunTag() {
        let text = "Running [RUN:tri git status] now"
        let pattern = #"\[RUN:(tri [^\]]+)\]"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        #expect(matches.count == 1)
        let r = Range(matches[0].range(at: 1), in: text)!
        #expect(String(text[r]) == "tri git status")
    }

    @Test func parseGrepTag() {
        let text = "Searching [GREP:fn bind] in codebase"
        let pattern = #"\[GREP:([^\]]+)\]"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        #expect(matches.count == 1)
        let r = Range(matches[0].range(at: 1), in: text)!
        #expect(String(text[r]) == "fn bind")
    }

    @Test func multipleTagsInOneResponse() {
        let text = "I'll check [READ:src/vsa.zig] and run [RUN:tri test] then search [GREP:cosineSimilarity]"

        let readRegex = try! NSRegularExpression(pattern: #"\[READ:(?:file://)?([^\]]+)\]"#)
        let runRegex = try! NSRegularExpression(pattern: #"\[RUN:(tri [^\]]+)\]"#)
        let grepRegex = try! NSRegularExpression(pattern: #"\[GREP:([^\]]+)\]"#)

        let range = NSRange(text.startIndex..., in: text)

        #expect(readRegex.matches(in: text, range: range).count == 1)
        #expect(runRegex.matches(in: text, range: range).count == 1)
        #expect(grepRegex.matches(in: text, range: range).count == 1)
    }

    @Test func blockDestructiveCommands() {
        let blocked = ["push", "delete", "kill", "deploy", "redeploy", "cloud spawn"]

        let destructive = [
            "tri git push origin main",
            "tri cloud delete service-123",
            "tri cloud kill 42",
            "tri deploy production",
            "tri cloud redeploy abc",
            "tri cloud spawn 99",
        ]

        for cmd in destructive {
            let isBlocked = blocked.contains { cmd.contains($0) }
            #expect(isBlocked, "Command '\(cmd)' should be blocked")
        }

        let safe = ["tri git status", "tri test", "tri issue list", "tri faculty"]
        for cmd in safe {
            let isBlocked = blocked.contains { cmd.contains($0) }
            #expect(!isBlocked, "Command '\(cmd)' should NOT be blocked")
        }
    }
}
