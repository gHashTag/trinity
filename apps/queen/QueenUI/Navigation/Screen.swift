import Foundation

enum Kingdom: String, CaseIterable, Identifiable, Codable {
    case brain = "Brain"
    case body = "Body"
    case spirit = "Spirit"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .brain: return "🏰"
        case .body: return "🏗"
        case .spirit: return "🌈"
        }
    }
}

enum Screen: String, CaseIterable, Identifiable, Codable {
    // Brain (10)
    case chat = "Queen Chat"
    case sevoFarm = "SEVO Farm"
    case arenaLLM = "Arena LLM"
    case arenaCode = "Arena Code"
    case faculty = "Faculty Board"
    case oracle = "Oracle"
    case muMemory = "MU Memory"
    case scholar = "Scholar"
    case swarm = "Swarm"
    case brainHealth = "Brain Health"

    // Body (9)
    case build = "Build"
    case triTools = "Tri Tools"
    case issues = "Issues"
    case git = "Git"
    case deploy = "Deploy"
    case bridge = "Bridge"
    case telegram = "Telegram"
    case keys = "Keys"
    case state = "State"
    case files = "Files"

    // Spirit (9)
    case rainbowBridge = "Rainbow Bridge"
    case sacredMath = "Sacred Math"
    case techTree = "Tech Tree"
    case fpga = "FPGA"
    case vsa = "VSA"
    case pipeline = "Pipeline"
    case benchmarks = "Benchmarks"
    case experience = "Experience"
    case settings = "Settings"

    var id: String { rawValue }

    var kingdom: Kingdom {
        switch self {
        case .chat, .sevoFarm, .arenaLLM, .arenaCode, .faculty, .oracle, .muMemory, .scholar, .swarm, .brainHealth:
            return .brain
        case .build, .triTools, .issues, .git, .deploy, .bridge, .telegram, .keys, .state, .files:
            return .body
        case .rainbowBridge, .sacredMath, .techTree, .fpga, .vsa, .pipeline, .benchmarks, .experience, .settings:
            return .spirit
        }
    }

    var icon: String {
        switch self {
        case .chat: return "👑"
        case .sevoFarm: return "🧬"
        case .arenaLLM: return "⚔️"
        case .arenaCode: return "💻"
        case .faculty: return "🎓"
        case .oracle: return "🔮"
        case .muMemory: return "🧠"
        case .scholar: return "📚"
        case .swarm: return "🐝"
        case .brainHealth: return "🩺"
        case .build: return "🔨"
        case .triTools: return "🛠️"
        case .issues: return "📋"
        case .git: return "🌿"
        case .deploy: return "🚀"
        case .bridge: return "🌉"
        case .telegram: return "💬"
        case .keys: return "🔑"
        case .state: return "📊"
        case .files: return "📁"
        case .rainbowBridge: return "🌈"
        case .sacredMath: return "🔢"
        case .techTree: return "🌳"
        case .fpga: return "⚡"
        case .vsa: return "🔷"
        case .pipeline: return "⛓"
        case .benchmarks: return "📈"
        case .experience: return "💎"
        case .settings: return "⚙️"
        }
    }

    static func screens(for kingdom: Kingdom) -> [Screen] {
        Screen.allCases.filter { $0.kingdom == kingdom }
    }

    /// Map block index (0-26) from 27-petal triangle to Screen
    /// Block 0-8 = RAZUM/Brain, 9-17 = MATERIYA/Body, 18-26 = DUKH/Spirit
    static func screenForBlock(_ idx: Int) -> Screen {
        let mapping: [Screen] = [
            // RAZUM (0-8)
            .chat, .sevoFarm, .arenaLLM, .arenaCode, .faculty,
            .oracle, .muMemory, .scholar, .swarm,
            // MATERIYA (9-17)
            .build, .triTools, .issues, .git, .deploy,
            .bridge, .telegram, .keys, .state,
            // DUKH (18-26)
            .files, .rainbowBridge, .sacredMath, .techTree, .fpga,
            .vsa, .pipeline, .benchmarks, .settings,
        ]
        guard idx >= 0, idx < mapping.count else { return .chat }
        return mapping[idx]
    }
}
