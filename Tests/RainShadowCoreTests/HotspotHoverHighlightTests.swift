import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import RainShadowCore

struct HotspotHoverHighlightTests {
    private let desk = HotspotHoverHighlight.Target(
        id: "office.desk",
        hitArea: CGRect(x: 100, y: 200, width: 200, height: 150)
    )
    private let window = HotspotHoverHighlight.Target(
        id: "office.window",
        hitArea: CGRect(x: 0, y: 400, width: 80, height: 120)
    )
    /// Nested inside desk; first-list-wins matches click hit-test order.
    private let phone = HotspotHoverHighlight.Target(
        id: "office.phone",
        hitArea: CGRect(x: 250, y: 280, width: 60, height: 40)
    )

    private var targets: [HotspotHoverHighlight.Target] {
        [desk, window, phone]
    }

    @Test func selectedIDMatchesFirstHitAreaContainingPoint() {
        #expect(
            HotspotHoverHighlight.selectedID(at: CGPoint(x: 150, y: 250), among: targets)
                == "office.desk"
        )
        #expect(
            HotspotHoverHighlight.selectedID(at: CGPoint(x: 40, y: 450), among: targets)
                == "office.window"
        )
        #expect(
            HotspotHoverHighlight.selectedID(at: CGPoint(x: 280, y: 300), among: targets)
                == "office.desk"
        )
        #expect(
            HotspotHoverHighlight.selectedID(at: CGPoint(x: 280, y: 300), among: [phone, desk])
                == "office.phone"
        )
        #expect(
            HotspotHoverHighlight.selectedID(at: CGPoint(x: 10, y: 10), among: targets) == nil
        )
    }

    @Test func presentationAppliesImageOneCyanOutlineAndTealWashWhenSelected() {
        // Drive the same presentation entry the scene uses for pointer-move.
        let presentation = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 150, y: 250),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(presentation.isVisible)
        #expect(presentation.hotspotID == "office.desk")
        #expect(presentation.usesSpriteTint)
        #expect(presentation.outlineEnabled)
        #expect(presentation.isImageOneSelectionLook)

        // Pure-cyan silhouette edge: high G and B, very low R (~#00FFFF).
        #expect(HotspotHoverHighlight.outlineRedBand.contains(presentation.outlineRed))
        #expect(HotspotHoverHighlight.outlineGreenBand.contains(presentation.outlineGreen))
        #expect(HotspotHoverHighlight.outlineBlueBand.contains(presentation.outlineBlue))
        #expect(presentation.outlineRed < 0.15)
        #expect(presentation.outlineGreen >= 0.85)
        #expect(presentation.outlineBlue >= 0.85)
        #expect(HotspotHoverHighlight.outlineWidthBand.contains(presentation.outlineWidth))
        #expect(presentation.outlineWidth == HotspotHoverHighlight.outlineWidth)
        #expect(presentation.outlineWidth > 0)

        // Translucent teal/cyan body wash (non-zero blend so art still reads).
        #expect(HotspotHoverHighlight.washRedBand.contains(presentation.washRed))
        #expect(HotspotHoverHighlight.washGreenBand.contains(presentation.washGreen))
        #expect(HotspotHoverHighlight.washBlueBand.contains(presentation.washBlue))
        #expect(
            HotspotHoverHighlight.selectedBlendBand.contains(presentation.colorBlendFactor)
        )
        #expect(
            presentation.colorBlendFactor == HotspotHoverHighlight.selectedColorBlendFactor
        )
        #expect(presentation.colorBlendFactor > 0)
        #expect(presentation.colorBlendFactor < 1)
    }

    @Test func presentationClearsOutlineAndWashOnMiss() {
        let presentation = HotspotHoverHighlight.presentation(
            at: CGPoint(x: -50, y: -50),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(!presentation.isVisible)
        #expect(presentation.hotspotID == nil)
        #expect(presentation.isClearedSelection)
        #expect(presentation.isClearedSpriteTint)
        #expect(!presentation.outlineEnabled)
        #expect(!presentation.isImageOneSelectionLook)
        #expect(
            presentation.colorBlendFactor == HotspotHoverHighlight.clearedColorBlendFactor
        )
    }

    @Test func presentationClearsWhenWorldInteractionBlocked() {
        let presentation = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 150, y: 250),
            among: targets,
            worldInteractionBlocked: true
        )
        #expect(!presentation.isVisible)
        #expect(presentation.hotspotID == nil)
        #expect(presentation.isClearedSelection)
        #expect(!presentation.outlineEnabled)
        #expect(
            presentation.colorBlendFactor == HotspotHoverHighlight.clearedColorBlendFactor
        )

        let noPoint = HotspotHoverHighlight.presentation(
            at: nil,
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(noPoint.isClearedSelection)
        #expect(!noPoint.outlineEnabled)
    }

    @Test func updateWithHitThenMissTogglesOutlineAndWash() {
        let hit = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 40, y: 450),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(hit.isVisible)
        #expect(hit.hotspotID == "office.window")
        #expect(hit.isImageOneSelectionLook)
        #expect(hit.outlineEnabled)
        #expect(hit.usesSpriteTint)
        #expect(hit.colorBlendFactor > 0)

        let miss = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 999, y: 999),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(!miss.isVisible)
        #expect(miss.isClearedSelection)
        #expect(!miss.outlineEnabled)
        #expect(miss.colorBlendFactor == 0)
    }

    @Test func officeAuthoredHotspotsSelectViaShippedLayoutRects() {
        let targets = HotspotHoverHighlight.targets(
            from: OfficeNavigationLayout.authoredHotspots.map {
                (id: $0.id, hitArea: OfficeInteriorScale.mapRect($0.hitArea))
            }
        )
        #expect(targets.count >= 4)
        guard let desk = targets.first(where: { $0.id == "office.desk" }),
              let window = targets.first(where: { $0.id == "office.window" }),
              let door = targets.first(where: { $0.id == "office.door" }) else {
            #expect(Bool(false), "Expected desk/window/door hotspots")
            return
        }

        let deskMid = CGPoint(x: desk.hitArea.midX, y: desk.hitArea.midY)
        #expect(HotspotHoverHighlight.selectedID(at: deskMid, among: targets) == "office.desk")

        let windowMid = CGPoint(x: window.hitArea.midX, y: window.hitArea.midY)
        #expect(HotspotHoverHighlight.selectedID(at: windowMid, among: targets) == "office.window")

        let doorMid = CGPoint(x: door.hitArea.midX, y: door.hitArea.midY)
        #expect(HotspotHoverHighlight.selectedID(at: doorMid, among: targets) == "office.door")

        for point in [deskMid, windowMid, doorMid] {
            let shown = HotspotHoverHighlight.presentation(
                at: point,
                among: targets,
                worldInteractionBlocked: false
            )
            #expect(shown.isVisible)
            #expect(shown.isImageOneSelectionLook)
            #expect(shown.outlineEnabled)
            #expect(shown.colorBlendFactor > 0)
            let blocked = HotspotHoverHighlight.presentation(
                at: point,
                among: targets,
                worldInteractionBlocked: true
            )
            #expect(blocked.isClearedSelection)
            #expect(!blocked.outlineEnabled)
        }
    }

    @Test func sceneWiresWashAndCyanEdgeOverlayNotRectChrome() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sceneURL = root.appendingPathComponent(
            "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift"
        )
        let source = try String(contentsOf: sceneURL, encoding: .utf8)
        #expect(source.contains("updateHotspotHoverHighlight(at:"))
        #expect(source.contains("HotspotHoverHighlight.presentation("))
        #expect(source.contains("clearHotspotHoverHighlight()"))
        #expect(source.contains("hotspotHoverSprites"))
        #expect(source.contains("registerHoverSprite"))
        // Scene: teal wash + CPU cyan edge overlay (not SKShader solid fill).
        #expect(source.contains("applyHoverWashAndEdgeOverlay"))
        #expect(source.contains("makeCyanEdgeOverlayPremultipliedRGBA")
            || source.contains("cyanEdgeTexture"))
        #expect(source.contains("edgeOverlayNodeName")
            || source.contains("hoverCyanEdgeOverlay"))
        #expect(source.contains("colorBlendFactor"))
        #expect(source.contains("presentation.washRed")
            || source.contains("washRed"))
        // Must not use the broken SKShader path or offset slabs.
        #expect(!source.contains("SKShader(source:"))
        #expect(!source.contains(".shader ="))
        #expect(!source.contains("silhouetteOutlineLocalOffsets("))
        #expect(!source.contains("let hotspotHoverOutline"))
        #expect(!source.contains("configureHotspotHoverOutline"))
    }

    @Test func everyOfficeHotspotHasARegisteredHighlightSprite() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sceneURL = root.appendingPathComponent(
            "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift"
        )
        let source = try String(contentsOf: sceneURL, encoding: .utf8)

        // The baked shell window is mirrored as an exact transparent prop for highlighting.
        #expect(!source.contains("registerHoverSprite(radiator, for: \"office.window\")"))
        #expect(source.contains("registerHoverSprite(window, for: \"office.window\")"))
        #expect(source.contains("office_window"))

        #expect(source.contains("registerHoverSprite(officeDoor, for: \"office.door\")"))
        #expect(source.contains("fixture.name = textureName"))
        #expect(source.contains("\"office.files\""))
        #expect(source.contains("\"office.phone\""))

        // All visible desk-only layers wash together so the selection covers the full desk.
        #expect(source.contains("registerHoverSprite(deskBare, for: \"office.desk\")"))
        #expect(source.contains("registerHoverSprite(deskActorOccluder, for: \"office.desk\")"))
        #expect(source.contains("registerHoverSprite(deskFrontOccluder, for: \"office.desk\")"))
        #expect(source.contains("office_desk_bare"))

        // Chair and desk-top props remain independent and never inherit desk selection.
        #expect(!source.contains("registerHoverSprite(chair, for: \"office.desk\")"))
        let lines = source.components(separatedBy: .newlines)
        for line in lines where line.contains("registerHoverSprite") {
            #expect(
                !(line.contains("chair") && line.contains("office.desk")),
                "Chair must not be desk-hover-registered: \(line)"
            )
            for prop in ["papers", "files", "lamp", "phone", "mug", "ashtray"] {
                #expect(
                    !(line.contains(prop) && line.contains("office.desk")),
                    "Desk-top prop must not be desk-hover-registered: \(line)"
                )
            }
        }
    }

    @Test func extractedWindowPropHasTransparentSilhouetteAndReadableInterior() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let windowURL = root.appendingPathComponent(
            "RainShadow Shared/Resources/Art/Props/Office/office_window.png"
        )
        let (rgba, width, height) = try loadStraightRGBA(from: windowURL)
        #expect(width == 304)
        #expect(height == 422)

        var clearPixels = 0
        var opaquePixels = 0
        for index in stride(from: 3, to: rgba.count, by: 4) {
            if rgba[index] == 0 { clearPixels += 1 }
            if rgba[index] == 255 { opaquePixels += 1 }
        }
        #expect(clearPixels > 40_000)
        #expect(opaquePixels > 40_000)
        #expect(rgba[3] == 0)

        let presentation = HotspotHoverHighlight.selectedPresentationTemplate
        let stats = HotspotHoverHighlight.evaluateHighlightStats(
            rgba: rgba,
            width: width,
            height: height,
            spriteScaleX: OfficeInteriorScale.environment,
            spriteScaleY: OfficeInteriorScale.environment,
            presentation: presentation,
            sampleStride: 1
        )
        #expect(stats.allEdgesAreCyan)
        #expect(stats.allWashesNotPureCyan)
        #expect(stats.washCount > stats.edgeCount)
    }

    @Test func selectedConstantsMatchImageOneCyanEdgeAndTealWash() {
        #expect(HotspotHoverHighlight.outlineRed <= 0.15)
        #expect(HotspotHoverHighlight.outlineGreen >= 0.85)
        #expect(HotspotHoverHighlight.outlineBlue >= 0.85)
        #expect(HotspotHoverHighlight.outlineWidth > 0)
        #expect(HotspotHoverHighlight.washGreen > HotspotHoverHighlight.washRed)
        #expect(HotspotHoverHighlight.washBlue > HotspotHoverHighlight.washRed)
        #expect(HotspotHoverHighlight.selectedColorBlendFactor > 0)
        #expect(HotspotHoverHighlight.selectedColorBlendFactor < 1)
        #expect(HotspotHoverHighlight.clearedColorBlendFactor == 0)
        #expect(HotspotHoverHighlight.edgeOverlayNodeName == "hoverCyanEdgeOverlay")
        #expect(HotspotHoverHighlight.outlineMaxTexels <= 4)
    }

    @Test func outlineUVThicknessCompensatesOfficePropScalesAndCapsTexels() {
        let presentation = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 150, y: 250),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(presentation.isImageOneSelectionLook)
        let worldW = presentation.outlineWidth
        #expect(worldW == HotspotHoverHighlight.outlineWidth)

        let deskTextureSize = CGSize(width: 932, height: 780)
        let envScale = OfficeInteriorScale.environment
        let deskScale = OfficeInteriorScale.deskDisplayScale
        #expect(envScale > 0 && envScale < 1)
        #expect(deskScale > 0 && deskScale < 1)

        for scale in [envScale, deskScale, CGFloat(1.0)] {
            let uv = HotspotHoverHighlight.outlineUVThickness(
                worldWidth: worldW,
                spriteSize: deskTextureSize,
                scaleX: scale,
                scaleY: scale
            )
            #expect(uv.x > 0 && uv.y > 0)
            let maxUVX = HotspotHoverHighlight.outlineMaxTexels / deskTextureSize.width
            let maxUVY = HotspotHoverHighlight.outlineMaxTexels / deskTextureSize.height
            #expect(uv.x <= maxUVX + 0.0001)
            #expect(uv.y <= maxUVY + 0.0001)
            let worldSpriteW = deskTextureSize.width * scale
            #expect(uv.x * worldSpriteW <= worldW + 0.001)

            let steps = HotspotHoverHighlight.outlineTexelSteps(
                worldWidth: worldW,
                pixelWidth: 932,
                pixelHeight: 780,
                scaleX: scale,
                scaleY: scale
            )
            #expect(steps.x >= 1 && steps.y >= 1)
            #expect(steps.x <= Int(HotspotHoverHighlight.outlineMaxTexels.rounded()))
            #expect(steps.y <= Int(HotspotHoverHighlight.outlineMaxTexels.rounded()))
        }

        let local = HotspotHoverHighlight.localOutlineOffset(
            worldWidth: worldW,
            scaleX: deskScale,
            scaleY: deskScale
        )
        #expect(local.x > worldW)
        #expect(abs(local.x * deskScale - worldW) < 0.001)
    }

    @Test func cpuHighlightOnDeskBareIsThinRimAndWashInterior() throws {
        // Drive the real shipped evaluator on the real office_desk_bare art.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let deskURL = root.appendingPathComponent(
            "RainShadow Shared/Resources/Art/Props/Office/office_desk_bare.png"
        )
        let (rgba, width, height) = try loadStraightRGBA(from: deskURL)
        #expect(width == 932)
        #expect(height == 780)

        let presentation = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 150, y: 250),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(presentation.isImageOneSelectionLook)

        let deskScale = OfficeInteriorScale.deskDisplayScale
        let stats = HotspotHoverHighlight.evaluateHighlightStats(
            rgba: rgba,
            width: width,
            height: height,
            spriteScaleX: deskScale,
            spriteScaleY: deskScale,
            presentation: presentation,
            sampleStride: 2
        )

        #expect(stats.opaqueCount > 1000)
        #expect(stats.allPremultiplied)
        #expect(stats.allEdgesAreCyan)
        #expect(stats.allWashesNotPureCyan)
        // Thin rim: most opaque samples are body wash, not cyan edge (rejects solid-fill).
        #expect(stats.washFractionOfOpaque > 0.70)
        #expect(stats.edgeFractionOfOpaque > 0.005)
        #expect(stats.edgeFractionOfOpaque < 0.35)
        #expect(stats.washCount > stats.edgeCount)

        // Overlay alone: rim is a small fraction of all pixels — never a solid cyan fill.
        let overlay = HotspotHoverHighlight.evaluateEdgeOverlayStats(
            sourceRGBA: rgba,
            width: width,
            height: height,
            spriteScaleX: deskScale,
            spriteScaleY: deskScale,
            presentation: presentation,
            sampleStride: 2
        )
        #expect(overlay.rimPixels > 50)
        #expect(overlay.clearPixels > overlay.rimPixels)
        #expect(overlay.rimFraction < 0.20)
        #expect(overlay.allRimPremulCyan)
    }

    @Test func cpuHighlightSyntheticSquareHasThinRimAndWashInterior() throws {
        // Larger synthetic so texel-capped rim leaves a clear wash interior.
        let w = 64
        let h = 64
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        for y in 8..<56 {
            for x in 8..<56 {
                let i = (y * w + x) * 4
                rgba[i] = 80
                rgba[i + 1] = 50
                rgba[i + 2] = 30
                rgba[i + 3] = 255
            }
        }
        let presentation = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 150, y: 250),
            among: targets,
            worldInteractionBlocked: false
        )
        let stats = HotspotHoverHighlight.evaluateHighlightStats(
            rgba: rgba,
            width: w,
            height: h,
            spriteScaleX: 1,
            spriteScaleY: 1,
            presentation: presentation,
            sampleStride: 1
        )
        #expect(stats.edgeCount > 0)
        #expect(stats.washCount > 0)
        #expect(stats.washFractionOfOpaque > 0.55)
        #expect(stats.edgeFractionOfOpaque < 0.45)
        #expect(stats.allPremultiplied)
        #expect(stats.allEdgesAreCyan)
        #expect(stats.allWashesNotPureCyan)

        var alphas = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) { alphas[i] = rgba[i * 4 + 3] }
        let uv = HotspotHoverHighlight.outlineUVThickness(
            worldWidth: presentation.outlineWidth,
            spriteSize: CGSize(width: w, height: h),
            scaleX: 1,
            scaleY: 1
        )
        let step = max(1, Int((uv.x * CGFloat(w)).rounded()))
        let interior = HotspotHoverHighlight.evaluateHighlightPixel(
            alphas: alphas,
            rgba: rgba,
            width: w,
            height: h,
            x: 32,
            y: 32,
            stepX: step,
            stepY: step,
            presentation: presentation
        )
        #expect(interior.kind == .bodyWash)
        #expect(interior.isPremultiplied)
        #expect(interior.isWashDominatedNotCyan)

        let edge = HotspotHoverHighlight.evaluateHighlightPixel(
            alphas: alphas,
            rgba: rgba,
            width: w,
            height: h,
            x: 8,
            y: 32,
            stepX: step,
            stepY: step,
            presentation: presentation
        )
        #expect(edge.kind == .cyanEdge)
        #expect(edge.isPremultiplied)
        #expect(edge.isCyanEdgeColor)
    }

    // MARK: - PNG load (straight RGBA for CPU evaluator)

    private func loadStraightRGBA(from url: URL) throws -> (rgba: [UInt8], width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let width = image.width
        let height = image.height
        var premul = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &premul,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        // Convert premul → straight so evaluateHighlightPixel matches the documented path.
        var straight = [UInt8](repeating: 0, count: premul.count)
        for i in stride(from: 0, to: premul.count, by: 4) {
            let a = premul[i + 3]
            straight[i + 3] = a
            if a == 0 {
                straight[i] = 0
                straight[i + 1] = 0
                straight[i + 2] = 0
            } else if a == 255 {
                straight[i] = premul[i]
                straight[i + 1] = premul[i + 1]
                straight[i + 2] = premul[i + 2]
            } else {
                let fa = CGFloat(a)
                straight[i] = UInt8(min(255, (CGFloat(premul[i]) * 255.0 / fa).rounded()))
                straight[i + 1] = UInt8(min(255, (CGFloat(premul[i + 1]) * 255.0 / fa).rounded()))
                straight[i + 2] = UInt8(min(255, (CGFloat(premul[i + 2]) * 255.0 / fa).rounded()))
            }
        }
        return (straight, width, height)
    }
}
