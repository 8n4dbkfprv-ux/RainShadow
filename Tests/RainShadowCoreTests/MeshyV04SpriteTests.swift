import Foundation
import Testing
@testable import RainShadowCore

struct MeshyV04SpriteTests {
    @Test func approvedCandidatePreservesNativePixelsAndTranslucentShadows() throws {
        let url = VossAtlasTestAssets.repoRoot.appendingPathComponent("ArtSource/Generated/Characters/Detective/MeshySep06V04/Staging/IEAvatar/Voss/avatar-v02.json")
        let sprite = try IEIndexedSprite(contentsOf: url, tables: IEGradientTables.load())
        #expect(sprite.frames.count == 248)
        #expect(sprite.hasEmbeddedShadow)
        #expect(sprite.compatibilityDisplaySize == .init(x: 163.125, y: 163.125))
        var alternate = sprite.colors
        alternate[5] = 42
        var shadows = 0
        for frame in sprite.frames {
            let rgba = sprite.rgba(for: frame)
            let recolored = sprite.rgba(for: frame, colors: alternate)
            #expect(rgba.count == frame.indices.count * 4)
            for (offset, index) in frame.indices.enumerated() {
                let alpha: UInt8 = index == 0 ? 0 : index == 1 ? 128 : 255
                #expect(rgba[offset * 4 + 3] == alpha)
                #expect(recolored[offset * 4 + 3] == alpha)
                if index == 1 { shadows += 1 }
            }
            if frame.id.atlas == "VossIdle.atlas" || frame.id.atlas == "VossWalk.atlas" {
                let rows = frame.indices.enumerated().compactMap { offset, index in
                    index >= 4 && index < 88 ? offset / frame.nativeSize.width : nil
                }
                #expect((try #require(rows.max())) - (try #require(rows.min())) + 1 == 58)
            }
        }
        #expect(shadows > 0)
    }
}
