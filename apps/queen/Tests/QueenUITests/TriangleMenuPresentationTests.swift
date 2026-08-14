import Testing
@testable import QueenUILib

@Suite("Queen 999 menu presentation")
struct TriangleMenuPresentationTests {
    @Test func menuUsesUniformIdlePetalsWithoutRealmLabels() {
        #expect(TriangleLogo.rawBlocks.count == 27)
        #expect(TriangleMenuPresentation.showsRealmLabels == false)
        #expect(TriangleMenuPresentation.specialAnimatedPetal == nil)
        #expect(TriangleMenuPresentation.normalPetalOpacity > 0)
        #expect(TriangleMenuPresentation.normalPetalOpacity < 1)
    }

    @Test func embeddedSurfaceRevealsHostGlass() {
        #expect(QueenSurfaceStyle.hostGlass.usesTransparentBackground)
        #expect(!QueenSurfaceStyle.canonical.usesTransparentBackground)
    }
}
