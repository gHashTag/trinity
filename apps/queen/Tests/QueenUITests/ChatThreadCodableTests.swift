import Testing
import Foundation
@testable import QueenUILib

@Suite("ChatThread Codable")
struct ChatThreadCodableTests {

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Roundtrip

    @Test func encode_decode_roundtrip() throws {
        var thread = ChatThread(title: "Test Thread")
        thread.isPinned = true
        thread.tags = ["zig", "fpga"]

        var msg = ChatMessage(role: .user, text: "Hello")
        msg.isBookmarked = true
        thread.messages.append(msg)

        let data = try encoder.encode(thread)
        let decoded = try decoder.decode(ChatThread.self, from: data)

        #expect(decoded.id == thread.id)
        #expect(decoded.title == "Test Thread")
        #expect(decoded.isPinned == true)
        #expect(decoded.tags == ["zig", "fpga"])
        #expect(decoded.messages.count == 1)
        #expect(decoded.messages[0].text == "Hello")
        #expect(decoded.messages[0].isBookmarked == true)
    }

    // MARK: - Backward Compatibility

    @Test func decode_oldFormat_noTags() throws {
        let json = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "title": "Legacy Thread",
            "messages": [],
            "createdAt": "2026-03-10T12:00:00Z",
            "updatedAt": "2026-03-10T12:00:00Z"
        }
        """
        let thread = try decoder.decode(ChatThread.self, from: json.data(using: .utf8)!)

        #expect(thread.title == "Legacy Thread")
        #expect(thread.isPinned == false)
        #expect(thread.tags.isEmpty)
    }

    @Test func decode_newFormat_withTags() throws {
        let json = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "title": "Tagged Thread",
            "messages": [],
            "createdAt": "2026-03-10T12:00:00Z",
            "updatedAt": "2026-03-10T12:00:00Z",
            "isPinned": true,
            "tags": ["research", "sacred"]
        }
        """
        let thread = try decoder.decode(ChatThread.self, from: json.data(using: .utf8)!)

        #expect(thread.title == "Tagged Thread")
        #expect(thread.isPinned == true)
        #expect(thread.tags == ["research", "sacred"])
    }

    // MARK: - Message Defaults

    @Test func message_defaults() {
        let msg = ChatMessage(role: .assistant, text: "Hi", modelID: "claude-sonnet-4")

        #expect(msg.role == .assistant)
        #expect(msg.text == "Hi")
        #expect(msg.modelID == "claude-sonnet-4")
        #expect(msg.isLiked == nil)
        #expect(msg.comments == nil)
        #expect(msg.imageURLs == nil)
        #expect(msg.isBookmarked == nil)
    }

    @Test func message_decode_oldFormat() throws {
        let json = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440001",
            "role": "user",
            "text": "old message",
            "timestamp": "2026-03-10T12:00:00Z"
        }
        """
        let msg = try decoder.decode(ChatMessage.self, from: json.data(using: .utf8)!)

        #expect(msg.text == "old message")
        #expect(msg.isBookmarked == nil)
        #expect(msg.comments == nil)
        #expect(msg.imageURLs == nil)
        #expect(msg.modelID == nil)
    }
}
