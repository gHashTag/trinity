import Testing
import Foundation
@testable import QueenUILib

@Suite("NetworkLog")
struct NetworkLogTests {

    @Test func entry_tokensPerSec() {
        let entry = NetworkLog.Entry(
            ts: 1710000000,
            provider: "Anthropic",
            model: "claude-sonnet-4",
            inputTokens: 500,
            outputTokens: 200,
            ttfbMs: 300,
            totalMs: 2300,  // 2000ms generation
            status: "ok",
            errorMessage: nil
        )

        // 200 tokens / 2.0 seconds = 100 tok/s
        #expect(abs(entry.tokensPerSec - 100.0) < 0.1)
    }

    @Test func entry_tokensPerSec_zeroOutput() {
        let entry = NetworkLog.Entry(
            ts: 1710000000,
            provider: "Anthropic",
            model: "claude-sonnet-4",
            inputTokens: 500,
            outputTokens: 0,
            ttfbMs: 300,
            totalMs: 2300,
            status: "error",
            errorMessage: "timeout"
        )

        #expect(entry.tokensPerSec == 0.0)
    }

    @Test func entry_tokensPerSec_ttfbEqualsTotal() {
        let entry = NetworkLog.Entry(
            ts: 1710000000,
            provider: "z.ai",
            model: "glm-5",
            inputTokens: 100,
            outputTokens: 50,
            ttfbMs: 1000,
            totalMs: 1000,
            status: "ok",
            errorMessage: nil
        )

        #expect(entry.tokensPerSec == 0.0)
    }

    @Test func entry_id_unique() {
        let e1 = NetworkLog.Entry(
            ts: 1710000000, provider: "A", model: "m1",
            inputTokens: 0, outputTokens: 0, ttfbMs: 0, totalMs: 0,
            status: "ok", errorMessage: nil
        )
        let e2 = NetworkLog.Entry(
            ts: 1710000001, provider: "A", model: "m1",
            inputTokens: 0, outputTokens: 0, ttfbMs: 0, totalMs: 0,
            status: "ok", errorMessage: nil
        )

        #expect(e1.id != e2.id)
    }
}
