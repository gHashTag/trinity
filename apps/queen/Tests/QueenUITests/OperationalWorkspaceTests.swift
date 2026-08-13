import Foundation
import Testing
@testable import QueenUILib

@Suite("Queen operational workspaces")
struct OperationalWorkspaceTests {
    @Test func allMenuRoutesAreUniqueAndCatalogued() {
        let routes = (0..<27).map(Screen.screenForBlock)

        #expect(Set(routes).count == 27)
        #expect(routes.allSatisfy { QueenWorkspaceCatalog.descriptor(for: $0) != nil })
        #expect(QueenWorkspaceCatalog.operationalScreens.count == 27)
    }

    @Test func glassProfileMatchesTriosChatAndModels() {
        let profile = QueenGlassTheme.shared

        #expect(profile.rootBlackOpacity == 0.60)
        #expect(profile.surfaceBlackOpacity == 0.46)
        #expect(profile.elevatedBlackOpacity == 0.58)
        #expect(profile.contentBlackOpacity == 0.14)
        #expect(profile.borderWhiteOpacity == 0.14)
        #expect(profile.mutedTextWhiteOpacity == 0.62)
        #expect(profile.dimTextWhiteOpacity == 0.43)
        #expect(!profile.usesOpaqueContentFill)
    }

    @Test func actionCatalogCoversEveryScreenAction() {
        let expected = Set([
            "build",
            "cell_create",
            "farm_evolve",
            "farm_kill_idle",
            "git_commit",
            "git_push",
            "issues_refresh",
            "keys_test",
            "pipeline_run",
            "queen_approve",
            "queen_deny",
            "queue_clear",
            "redeploy",
            "scholar_research",
            "swarm_decompose",
            "telegram_check",
            "telegram_test",
            // Hive actions run in-process rather than via the Zig runtime.
            "hive_start",
            "hive_pause",
            "hive_stop_all",
            "hive_cycle",
            "hive_rescan",
        ])

        #expect(Set(QueenActionCatalog.all.map(\.id)) == expected)
        #expect(
            QueenActionCatalog.definition(for: "hive_start")?.handling == .hive
        )
        #expect(
            QueenActionCatalog.definition(for: "hive_start")?.risk
                == .requiresConfirmation
        )
        #expect(
            QueenActionCatalog.definition(for: "hive_stop_all")?.risk
                == .requiresConfirmation
        )
        #expect(
            QueenActionCatalog.definition(for: "farm_kill_idle")?.risk
                == .requiresConfirmation
        )
        #expect(
            QueenActionCatalog.definition(for: "git_push")?.risk
                == .requiresConfirmation
        )
        #expect(
            QueenActionCatalog.definition(for: "issues_refresh")?.risk
                == .safe
        )
    }

    @Test func actionPayloadUsesCompactRoundTripJSON() throws {
        let envelope = QueenActionEnvelope(
            timestamp: 123,
            action: "swarm_decompose",
            params: ["task": "Audit every workspace"]
        )

        let data = try QueenActionCodec.encode([envelope])
        let text = try #require(String(data: data, encoding: .utf8))
        let decoded = try QueenActionCodec.decode(data)

        #expect(text.contains("\"action\":\"swarm_decompose\""))
        #expect(!text.contains("\"action\" :"))
        #expect(decoded == [envelope])
    }

    @Test func triToolsExposeExecutableCommandsWithExplicitRisk() {
        let commands = TriToolCommandCatalog.commands
        let expected = Set([
            "status",
            "diff",
            "log",
            "info",
            "pipeline-status",
            "verify",
        ])

        #expect(Set(commands.map(\.id)) == expected)
        #expect(commands.allSatisfy { !$0.arguments.isEmpty })
        #expect(
            commands.first { $0.id == "status" }?.requiresConfirmation
                == false
        )
        #expect(
            commands.first { $0.id == "verify" }?.requiresConfirmation
                == true
        )
    }

    @Test func triToolOutputRemovesTerminalControlSequences() {
        let raw = "\u{001B}[38;2;0;229;153mclean\u{001B}[0m\r\n"

        #expect(TriToolOutputSanitizer.clean(raw) == "clean\n")
    }
}
