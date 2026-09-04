import Foundation
import Testing
@testable import RainShadowCore

/// The replacement model is a coherent orthographic rig, not independent
/// fixed-height stills. Keep each seat chain's scale and projected pivot fixed.
/// Source geometry is measured before rasterization; no per-pose fitting is
/// permitted. Historical V22 tests retain their original contract.
enum VossProjectionContract {
    struct Head {
        let width: Double
        let height: Double
        let x: Double
    }

    static func head(_ frame: IEIndexedSprite.Frame) throws -> Head {
        let samples = frame.indices.enumerated().filter { (76..<88).contains(Int($0.element)) }
        let xs = samples.map { $0.offset % frame.nativeSize.width }
        let ys = samples.map { $0.offset / frame.nativeSize.width }
        let minX = try #require(xs.min()), maxX = try #require(xs.max())
        let minY = try #require(ys.min()), maxY = try #require(ys.max())
        let sx = Double(frame.size.width) / Double(frame.nativeSize.width)
        let sy = Double(frame.size.height) / Double(frame.nativeSize.height)
        return Head(width: Double(maxX - minX + 1) * sx,
                    height: Double(maxY - minY + 1) * sy,
                    x: Double(frame.trimOriginTopLeft.width) + Double(minX + maxX) / 2 * sx)
    }

    static func heads(atlas: String, names: [String]) throws -> [Head]? {
        guard VossAtlasTestAssets.usesProjectionRegistration else { return nil }
        let sprite = try VossAtlasTestAssets.indexedSprite()
        return try names.map { name in
            try head(#require(sprite.frame(atlas: atlas, name: name)))
        }
    }

    struct Entry: Decodable {
        let sourceBbox: [Double]
        let sourceHeadBbox: [Double]
        let sourceReferenceHeight: Double
        let referenceBbox: [Double]?
        let referenceCell: String?
    }
    struct Contract: Decodable { let geometry: [String: Entry] }

    static func validateSeats() throws {
        let staged = VossAtlasTestAssets.atlasRoot.appendingPathComponent("geometry_contract.json")
        let url = FileManager.default.fileExists(atPath: staged.path) ? staged :
            VossAtlasTestAssets.repoRoot.appendingPathComponent("ArtSource/Generated/Characters/Detective/ImportedVossReplacementRuntimeV12/Staging/geometry_contract.json")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let contract = try decoder.decode(Contract.self, from: Data(contentsOf: url))
        let sprite = try VossAtlasTestAssets.indexedSprite()
        let craft = 200.0 / 64
        var count = 0
        for (direction, referenceDirection) in [("ne", "nw"), ("se", "se"), ("n", "n")] {
            let reference = try #require(sprite.frame(atlas: "VossIdle.atlas", name: "voss_standing_idle_\(referenceDirection)_00.png"))
            let referenceHead = try head(reference)
            var idleFrames: [VossAtlasFrame] = []
            var standFrames: [VossAtlasFrame] = []
            var standNative: [IEIndexedSprite.Frame] = []
            var idleNative: [IEIndexedSprite.Frame] = []
            for (group, phases, atlas) in [("seated_idle", 8, "VossSeatedIdle.atlas"), ("stand_up", 12, "VossSeatTransitions.atlas"), ("sit_down", 12, "VossSeatTransitions.atlas")] {
                for phase in 0..<phases {
                    let name = String(format: "voss_%@_%@_%02d.png", group, direction, phase)
                    let key = "\(atlas)/\(name)"
                    let entry = try #require(contract.geometry[key])
                    let refBox = try #require(entry.referenceBbox)
                    #expect(entry.referenceCell == "VossIdle.atlas/voss_standing_idle_\(referenceDirection)_00.png")
                    #expect(entry.sourceReferenceHeight == refBox[3] - refBox[1] + 1)
                    let scale = 200 / entry.sourceReferenceHeight
                    let native = try #require(sprite.frame(atlas: atlas, name: name))
                    let decoded = try VossAtlasFrame(contentsOf: VossAtlasTestAssets.cellURL(atlas: atlas, name: name))
                    let metric = try decoded.metrics()
                    #expect(decoded.width == 512 && decoded.height == 512)
                    #expect(decoded.cornerAlphas == [1, 1, 1, 1])
                    #expect(decoded.alphaValues == Set<UInt8>([0, 1, 255]))
                    for (axis, actual) in [(0, metric.width), (1, metric.height)] {
                        let expected = (entry.sourceBbox[axis + 2] - entry.sourceBbox[axis] + 1) * scale
                        #expect(abs(Double(actual) - expected) <= craft + 1, "\(key): body projection scale changed")
                        let refOrigin = axis == 0 ? reference.trimOriginTopLeft.width : reference.trimOriginTopLeft.height
                        let refSize = axis == 0 ? reference.size.width : reference.size.height
                        let size = axis == 0 ? native.size.width : native.size.height
                        let origin = axis == 0 ? native.trimOriginTopLeft.width : native.trimOriginTopLeft.height
                        let delta = (entry.sourceBbox[axis] + entry.sourceBbox[axis + 2] - refBox[axis] - refBox[axis + 2]) / 2
                        let expectedOrigin = Double(refOrigin) + Double(refSize - 1) / 2 + delta * scale - Double(size - 1) / 2
                        #expect(abs(Double(origin) - expectedOrigin) <= 1, "\(key): source pivot moved")
                    }
                    let h = try head(native)
                    for (axis, actual) in [(0, h.width), (1, h.height)] {
                        let expected = (entry.sourceHeadBbox[axis + 2] - entry.sourceHeadBbox[axis] + 1) * scale
                        #expect(abs(actual - expected) <= craft + 1, "\(key): head source scale changed")
                    }
                    #expect((0.90 * referenceHead.width - craft...1.10 * referenceHead.width + craft).contains(h.width), "\(key): head grew/shrank")
                    if group == "seated_idle" { idleFrames.append(decoded); idleNative.append(native) }
                    if group == "stand_up" { standFrames.append(decoded); standNative.append(native) }
                    if group == "sit_down" {
                        let reverse = standNative[11 - phase]
                        #expect(native.indices == reverse.indices && native.size == reverse.size && native.trimOriginTopLeft == reverse.trimOriginTopLeft)
                    }
                    count += 1
                }
            }
            let end = try #require(standNative.last)
            let start = try #require(standNative.first)
            #expect(end.indices == reference.indices && end.trimOriginTopLeft == reference.trimOriginTopLeft && end.size == reference.size)
            #expect(start.indices == idleNative[0].indices && start.trimOriginTopLeft == idleNative[0].trimOriginTopLeft)
            let neutral = centroid(idleFrames[0])
            for frame in idleFrames {
                let center = centroid(frame)
                #expect(abs(center.0 - neutral.0) <= 2 && abs(center.1 - neutral.1) <= 2)
                #expect(VossAtlasFrame.intersectionOverUnion(idleFrames[0], frame) >= 0.85)
            }
            for (first, second) in zip(standFrames, standFrames.dropFirst()) {
                #expect(try second.metrics().crownY - first.metrics().crownY <= 4)
            }
            #expect(try standFrames[0].metrics().crownY > standFrames[11].metrics().crownY)
        }
        #expect(count == 96)
    }

    private static func centroid(_ frame: VossAtlasFrame) -> (Double, Double) {
        let occupied = frame.opaqueMask.enumerated().filter(\.element).map(\.offset)
        return (Double(occupied.reduce(0) { $0 + $1 % frame.width }) / Double(occupied.count),
                Double(occupied.reduce(0) { $0 + $1 / frame.width }) / Double(occupied.count))
    }
}
