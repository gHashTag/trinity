import SwiftUI

struct ScreenRouter: View {
    let screen: Screen
    @State private var refreshID = UUID()

    var body: some View {
        QueenOperationalWorkspace(screen: screen) {
            routedContent
                .id(refreshID)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .queenWorkspaceRefresh)
        ) { _ in
            refreshID = UUID()
        }
    }

    @ViewBuilder
    private var routedContent: some View {
        switch screen {
        case .chat:
            ChatScreen()
        case .faculty:
            FacultyScreen()
        case .sevoFarm:
            SEVOFarmScreen()
        case .swarm:
            SwarmScreen()
        case .brainHealth:
            BrainHealthScreen()
        case .sacredMath:
            SacredMathScreen()
        case .arenaLLM:
            ArenaLLMScreen()
        case .arenaCode:
            ArenaCodeScreen()
        case .muMemory:
            MUMemoryScreen()
        case .techTree:
            TechTreeScreen()
        case .oracle:
            OracleScreen()
        case .scholar:
            ScholarScreen()
        case .build:
            BuildScreen()
        case .triTools:
            TriToolsScreen()
        case .issues:
            IssuesScreen()
        case .git:
            GitScreen()
        case .deploy:
            DeployScreen()
        case .bridge:
            BridgeScreen()
        case .telegram:
            TelegramScreen()
        case .keys:
            KeysScreen()
        case .state:
            StateScreen()
        case .files:
            FilesScreen()
        case .todo:
            TodoPanelView()
        case .rainbowBridge:
            RainbowBridgeScreen()
        case .fpga:
            FPGAScreen()
        case .vsa:
            VSAScreen()
        case .pipeline:
            PipelineScreen()
        case .benchmarks:
            BenchmarksScreen()
        case .experience:
            ExperienceScreen()
        case .settings:
            SettingsScreen()
        }
    }
}
