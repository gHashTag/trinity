import Testing
import Foundation
@testable import QueenUILib

@Suite("ThreadStore")
@MainActor
struct ThreadStoreTests {

    // MARK: - Thread Creation

    @Test func newThread_createsAndActivates() {
        let store = ThreadStore()
        let initialCount = store.threads.count

        let thread = store.newThread()

        #expect(store.threads.count == initialCount + 1)
        #expect(store.activeThreadID == thread.id)
        #expect(thread.title == "New Thread")
        #expect(thread.messages.isEmpty)
        #expect(!thread.isPinned)
        #expect(thread.tags.isEmpty)
    }

    // MARK: - Messages

    @Test func appendMessage_addsToThread() {
        let store = ThreadStore()
        let thread = store.newThread()

        let msg = ChatMessage(role: .user, text: "Hello Queen")
        store.appendMessage(msg, to: thread.id)

        let updated = store.threads.first { $0.id == thread.id }!
        #expect(updated.messages.count == 1)
        #expect(updated.messages[0].text == "Hello Queen")
        #expect(updated.messages[0].role == .user)
    }

    // MARK: - Fork

    @Test func forkFromMessage_removesAfter() {
        let store = ThreadStore()
        let thread = store.newThread()

        let msg1 = ChatMessage(role: .user, text: "First")
        let msg2 = ChatMessage(role: .assistant, text: "Response 1")
        let msg3 = ChatMessage(role: .user, text: "Second")
        let msg4 = ChatMessage(role: .assistant, text: "Response 2")
        store.appendMessage(msg1, to: thread.id)
        store.appendMessage(msg2, to: thread.id)
        store.appendMessage(msg3, to: thread.id)
        store.appendMessage(msg4, to: thread.id)

        store.forkFromMessage(msg1.id, newText: "Edited first", in: thread.id)

        let updated = store.threads.first { $0.id == thread.id }!
        #expect(updated.messages.count == 1)
        #expect(updated.messages[0].text == "Edited first")
    }

    // MARK: - Search

    @Test func search_matchesTitleAndContent() {
        let store = ThreadStore()

        // Clean up any pre-existing threads from disk
        for thread in store.threads {
            store.delete(thread)
        }

        let t1 = store.newThread()
        store.rename(t1.id, title: "FPGA synthesis results")
        store.appendMessage(ChatMessage(role: .user, text: "start"), to: t1.id)

        let t2 = store.newThread()
        store.rename(t2.id, title: "Random chat")
        store.appendMessage(ChatMessage(role: .user, text: "Tell me about FPGA timing"), to: t2.id)

        let t3 = store.newThread()
        store.rename(t3.id, title: "Training loss")
        store.appendMessage(ChatMessage(role: .user, text: "PPL is 4.6"), to: t3.id)

        let results = store.search("fpga")
        #expect(results.count == 2)
    }

    @Test func search_emptyQuery_returnsEmpty() {
        let store = ThreadStore()
        _ = store.newThread()
        #expect(store.search("").isEmpty)
    }

    // MARK: - Export

    @Test func exportAsMarkdown_format() {
        let store = ThreadStore()
        let thread = store.newThread()
        store.rename(thread.id, title: "Test Export")
        store.appendMessage(ChatMessage(role: .user, text: "Hello"), to: thread.id)

        let md = store.exportAsMarkdown(thread.id)
        #expect(md != nil)
        #expect(md!.hasPrefix("# Test Export"))
        #expect(md!.contains("**You**"))
        #expect(md!.contains("Hello"))
    }

    @Test func exportAsMarkdown_nonexistentThread_returnsNil() {
        let store = ThreadStore()
        #expect(store.exportAsMarkdown(UUID()) == nil)
    }

    // MARK: - Pin / Sort

    @Test func togglePin_sortsFirst() {
        let store = ThreadStore()
        let t1 = store.newThread()
        store.rename(t1.id, title: "First")
        let t2 = store.newThread()
        store.rename(t2.id, title: "Second")

        #expect(store.sortedThreads.first?.id == t2.id)

        store.togglePin(t1.id)
        #expect(store.sortedThreads.first?.id == t1.id)

        store.togglePin(t1.id)
        #expect(store.sortedThreads.first?.id == t2.id)
    }

    // MARK: - Tags

    @Test func addTag_filterByTag() {
        let store = ThreadStore()
        let thread = store.newThread()

        store.addTag("FPGA", to: thread.id)
        store.addTag("training", to: thread.id)

        let updated = store.threads.first { $0.id == thread.id }!
        #expect(updated.tags.count == 2)
        #expect(updated.tags.contains("fpga"))
        #expect(updated.tags.contains("training"))

        // Duplicate should not increase count
        store.addTag("fpga", to: thread.id)
        let afterDupe = store.threads.first { $0.id == thread.id }!
        #expect(afterDupe.tags.count == 2)

        #expect(store.allTags.contains("fpga"))
    }

    @Test func removeTag() {
        let store = ThreadStore()
        let thread = store.newThread()

        store.addTag("test", to: thread.id)
        #expect(store.threads.first { $0.id == thread.id }!.tags.count == 1)

        store.removeTag("test", from: thread.id)
        #expect(store.threads.first { $0.id == thread.id }!.tags.count == 0)
    }

    // MARK: - Bookmarks

    @Test func toggleBookmark_and_allBookmarks() {
        let store = ThreadStore()
        let thread = store.newThread()
        let msg = ChatMessage(role: .assistant, text: "Important answer")
        store.appendMessage(msg, to: thread.id)

        #expect(store.allBookmarks().isEmpty)

        store.toggleBookmark(msg.id, in: thread.id)
        #expect(store.allBookmarks().count == 1)
        #expect(store.allBookmarks().first?.message.text == "Important answer")

        store.toggleBookmark(msg.id, in: thread.id)
        #expect(store.allBookmarks().isEmpty)
    }

    // MARK: - Auto-summarize

    @Test func autoSummarize_extractsTopics() {
        let store = ThreadStore()
        let thread = store.newThread()
        store.appendMessage(ChatMessage(role: .user, text: "How does VSA binding work?"), to: thread.id)
        store.appendMessage(ChatMessage(role: .assistant, text: "VSA binding uses XOR..."), to: thread.id)

        let summary = store.autoSummarize(thread.id)
        #expect(summary != nil)
        #expect(summary!.contains("How") || summary!.contains("VSA"))
    }

    // MARK: - Delete

    @Test func delete_removesThread() {
        let store = ThreadStore()
        let thread = store.newThread()
        let countBefore = store.threads.count

        store.delete(thread)
        #expect(store.threads.count == countBefore - 1)
    }

    @Test func delete_activeThread_switchesToNext() {
        let store = ThreadStore()
        let t1 = store.newThread()
        let t2 = store.newThread()
        #expect(store.activeThreadID == t2.id)

        store.delete(t2)
        #expect(store.activeThreadID == t1.id)
    }
}
