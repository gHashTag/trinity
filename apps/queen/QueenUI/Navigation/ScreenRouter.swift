import SwiftUI

struct ScreenRouter: View {
    let screen: Screen

    var body: some View {
        switch screen {
        case .chat:
            ChatScreen()
        case .faculty:
            FacultyScreen()
        case .sevoFarm:
            SEVOFarmScreen()
        case .swarm:
            SwarmScreen()
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

struct ComingSoonScreen: View {
    let screen: Screen

    var body: some View {
        VStack(spacing: 24) {
            Text(screen.icon)
                .font(.system(size: 64))
            Text(screen.rawValue)
                .font(.title.weight(.bold))
                .foregroundStyle(TrinityTheme.textPrimary)
            Text("Coming Soon")
                .font(.title3)
                .foregroundStyle(TrinityTheme.textMuted)
            Text("Kingdom: \(screen.kingdom.rawValue)")
                .font(.caption)
                .foregroundStyle(TrinityTheme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TrinityTheme.bgWindow)
    }
}
