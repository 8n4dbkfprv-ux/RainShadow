#if DEBUG
import Foundation
import SpriteKit

/// Opt-in, in-app integration gate. Exercises the *production* library, scene
/// traversal, world-to-native placement and Metal compositor against the
/// independently C++-verified CPU reference. Does not mutate the live scene.
@MainActor
enum IENativeWorldQA {
    static func run(context: GameContext) throws {
        let library = try IEAvatarFrameLibrary(character: "Voss")
        let scene = BaseGameScene(context: context, artSize: CGSize(width: 192, height: 160))
        let unit = OfficeInteriorScale.cameraScaleAt100Percent
        scene.size = CGSize(width: 192, height: 160)
        scene.gameCamera.position = CGPoint(x: 96 * unit, y: 80 * unit)
        scene.gameCamera.setScale(unit)
        for root in scene.nativeWorldRoots { scene.addChild(root) }
        scene.backgroundRoot.zPosition = -100
        let renderer = IENativeWorldRenderer()!
        let backgroundColors = (0..<(192 * 160)).map { i in
            IEColor(UInt8(i % 192), UInt8(i / 192), 97)
        }
        let backgroundBytes = Data(backgroundColors.flatMap { [$0.r, $0.g, $0.b, $0.a] })
        let plate = SKSpriteNode(texture: SKTexture(cgImage: IENativeWorldRenderer.image(backgroundBytes, width: 192, height: 160)!))
        plate.position = scene.gameCamera.position
        plate.size = CGSize(width: 192 * unit, height: 160 * unit)
        plate.texture?.filteringMode = .nearest
        scene.backgroundRoot.addChild(plate)
        let actor = SKNode()
        actor.position = CGPoint(x: 96 * unit, y: 32 * unit)
        scene.depthWorldRoot.addChild(actor)
        let body = IEAvatarNode()
        actor.addChild(body)
        let tint = IEColor(191, 207, 223)
        body.shader = IEBlitShader.make(tint: tint, flags: [.blended, .colorMod])
        var count = 0
        for frame in library.sprite.frames where !frame.isEmpty {
            guard let visual = library.frame(atlas: frame.id.atlas, name: frame.id.name) else {
                preconditionFailure("native QA: missing visual frame")
            }
            body.apply(visual)
            var expected = try IESoftwareBlit.Buffer(width: 192, height: 160,
                                                    pixels: backgroundColors)
            let native = try library.sprite.softwareFrame(for: frame)
            try expected.blit(native, palette: library.sprite.palette.colors, at: .init(x: 96, y: 128),
                              tint: tint, flags: [.blended, .colorMod])
            guard renderer.render(scene: scene) != nil, renderer.lastPixels == Data(expected.rgba) else {
                preconditionFailure("native QA: live adapter mismatch \(frame.id)")
            }
            actor.xScale = -1
            let reflected = try IESoftwareBlit.Frame(width: native.width, height: native.height,
                                                      origin: .init(x: native.width - native.origin.x, y: native.origin.y),
                                                      indices: native.indices)
            var mirrored = try IESoftwareBlit.Buffer(width: 192, height: 160, pixels: backgroundColors)
            try mirrored.blit(reflected, palette: library.sprite.palette.colors, at: .init(x: 96, y: 128),
                              tint: tint, flags: [.blended, .colorMod], mirrorX: true)
            _ = renderer.render(scene: scene)
            precondition(renderer.lastPixels == Data(mirrored.rgba), "native QA: mirrored pivot mismatch")
            actor.xScale = 1
            count += 1
        }
        // World-anchored per-pixel cover, deliberately not the RGBA raw-mask
        // iterator. An asymmetric mask detects y reversal and per-layer drift.
        let frame = library.sprite.frames.first { !$0.isEmpty }!
        body.apply(library.frame(atlas: frame.id.atlas, name: frame.id.name)!)
        var pixels = [UInt8](repeating: 0, count: 192 * 160 * 4)
        for y in 0..<100 { for x in 85..<192 {
            let i = (y * 192 + x) * 4
            pixels[i] = x < 108 ? 128 : 255; pixels[i+1] = 255
        } }
        let mask = AreaWallStencil.Mask(columns: 192, rows: 160,
                                         worldFrame: CGRect(x: 0, y: 0, width: 192 * unit, height: 160 * unit), rgba: pixels)
        let stencil = WallStencilTexture.make(from: mask)!
        _ = renderer.render(scene: scene)
        var expected = renderer.lastPixels!
        for y in 0..<160 { for x in 0..<192 {
            let m = mask.sample(at: CGPoint(x: (CGFloat(x) + 0.5) * unit, y: (159.5 - CGFloat(y)) * unit))
            if m.g > 0 && (m.r > 192 || (x+y) % 2 == 1) {
                let start = (y*192+x)*4
                expected.replaceSubrange(start..<start+4, with: backgroundBytes[start..<start+4])
            }
        } }
        stencil.apply(to: body, in: scene)
        _ = renderer.render(scene: scene)
        precondition(renderer.lastPixels == expected, "native QA: cover orientation/parity mismatch")
        // A foreground object must win even if inserted before the actor.
        scene.backgroundRoot.zPosition = 100
        _ = renderer.render(scene: scene)
        precondition(renderer.lastPixels == backgroundBytes, "native QA: world draw-order mismatch")
        FileHandle.standardError.write(Data("NATIVE_WORLD_QA PASS: \(count) installed Voss frames, exact placement/tint/blending; asymmetric per-pixel cover\n".utf8))
    }
}
#endif
