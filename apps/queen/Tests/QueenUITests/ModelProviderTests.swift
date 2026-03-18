import Testing
import Foundation
@testable import QueenUILib

@Suite("ModelProvider")
struct ModelProviderTests {

    @Test func allModels_notEmpty() {
        #expect(!AIModel.allModels.isEmpty)
    }

    @Test func allModels_uniqueIDs() {
        let ids = AIModel.allModels.map(\.id)
        #expect(ids.count == Set(ids).count, "Model IDs must be unique")
    }

    @Test func isImageModel() {
        let imageModel = AIModel.allModels.first { $0.id == "grok-2-image" }
        #expect(imageModel != nil)
        #expect(imageModel!.isImageModel)

        let textModel = AIModel.allModels.first { $0.id == "claude-sonnet-4-20250514" }
        #expect(textModel != nil)
        #expect(!textModel!.isImageModel)
    }

    @Test func provider_allCases() {
        #expect(AIProvider.allCases.count == 4)
        #expect(AIProvider.allCases.contains(.anthropic))
        #expect(AIProvider.allCases.contains(.zai))
        #expect(AIProvider.allCases.contains(.perplexity))
        #expect(AIProvider.allCases.contains(.xai))
    }

    @Test func provider_rawValues() {
        #expect(AIProvider.anthropic.rawValue == "Anthropic")
        #expect(AIProvider.zai.rawValue == "z.ai")
        #expect(AIProvider.perplexity.rawValue == "Perplexity")
        #expect(AIProvider.xai.rawValue == "xAI")
    }

    @Test func chatMode_allCases() {
        #expect(ChatMode.allCases.count == 5)
    }

    @Test func chatMode_icons() {
        #expect(!ChatMode.search.icon.isEmpty)
        #expect(!ChatMode.trinity.icon.isEmpty)
        #expect(!ChatMode.reason.icon.isEmpty)
        #expect(!ChatMode.compare.icon.isEmpty)
        #expect(!ChatMode.image.icon.isEmpty)
    }

    @Test func chatMode_systemSuffix() {
        #expect(ChatMode.trinity.systemSuffix.isEmpty)
        #expect(ChatMode.search.systemSuffix.contains("search"))
        #expect(ChatMode.reason.systemSuffix.contains("step"))
    }
}
