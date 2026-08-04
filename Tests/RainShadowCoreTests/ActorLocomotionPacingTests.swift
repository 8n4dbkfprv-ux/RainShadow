import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import RainShadowCore

struct ActorLocomotionPacingTests {
    @Test func walkSpeedUsesNormalizedHumanoidBaseline() {
        let speed = ActorLocomotionPacing.walkSpeed
        // BG:EE parity (~2.25 heights/s) sits just under the retired 270 u/s
        // detective default while remaining well above the slow 120 u/s amble.
        #expect(speed < ActorLocomotionPacing.legacyDetectiveWalkSpeed)
        #expect(speed > 180)
        #expect(ActorLocomotionPacing.walkSpeedBand.contains(speed))
        #expect(ActorLocomotionPacing.infinityEngineHumanoidMoveScale == 9)
    }

    @Test func walkCycleDurationMatchesBGParityGait() {
        // Faster on-screen pace shortens the cycle while stride length stays
        // near one body (~86 units); frame density remains eight cells.
        let frame = ActorLocomotionPacing.walkCycleSecondsPerFrame
        let cycle = frame * TimeInterval(ActorLocomotionPacing.walkFramesPerCycle)
        let legacyDetectiveCycle = ActorLocomotionPacing.legacyDetectiveWalkFrameDuration * 4
        #expect(cycle < legacyDetectiveCycle)
        #expect(ActorLocomotionPacing.walkCycleSecondsPerFrameBand.contains(frame))
        #expect(ActorLocomotionPacing.walkCycleDurationBand.contains(cycle))
        #expect(ActorLocomotionPacing.walkFramesPerCycle == 8)
    }

    @Test func pathDurationUsesOneConstantMovementRate() {
        let distance: CGFloat = 400
        let shipped = ActorLocomotionPacing.pathDuration(distance: distance)
        let legacyDetective = TimeInterval(distance / ActorLocomotionPacing.legacyDetectiveWalkSpeed)
        // 225 u/s is still slightly slower than the retired 270 u/s default.
        #expect(shipped > legacyDetective)
        #expect(abs(shipped - TimeInterval(distance / ActorLocomotionPacing.walkSpeed)) < 0.0001)
    }

    @Test func walkCycleTravelsApproximatelyOneBodyLength() {
        let cycleDuration = ActorLocomotionPacing.walkCycleSecondsPerFrame
            * TimeInterval(ActorLocomotionPacing.walkFramesPerCycle)
        let distancePerCycle = ActorLocomotionPacing.walkSpeed * CGFloat(cycleDuration)
        #expect((75 as CGFloat)...(110 as CGFloat) ~= distancePerCycle)
    }

    @Test func pathDurationUsesWalkSpeedEntryPoint() {
        // Drive the real helper actors call for SKAction.move durations.
        let samples: [CGFloat] = [50, 120, 270, 500]
        for distance in samples {
            let duration = ActorLocomotionPacing.pathDuration(distance: distance)
            #expect(duration >= ActorLocomotionPacing.minimumSegmentDuration)
            #expect(duration >= TimeInterval(distance / ActorLocomotionPacing.walkSpeed) - 0.0001)
            #expect(abs(duration - max(
                ActorLocomotionPacing.minimumSegmentDuration,
                TimeInterval(distance / ActorLocomotionPacing.walkSpeed)
            )) < 0.0001)
        }
    }

    @Test func shortSegmentsClampToMinimumDuration() {
        let tiny = ActorLocomotionPacing.pathDuration(distance: 0.5)
        #expect(tiny == ActorLocomotionPacing.minimumSegmentDuration)
    }

    @Test func standUpFrameDurationSupportsUnhurriedEgress() {
        #expect(ActorLocomotionPacing.standUpSecondsPerFrame > 0.1)
        #expect(ActorLocomotionPacing.standUpSecondsPerFrame < 0.2)
        let twelveFrameStandUp = ActorLocomotionPacing.standUpSecondsPerFrame * 12
        #expect(twelveFrameStandUp > 1.2)
        #expect(twelveFrameStandUp < 2.5)
    }

    @Test func actorsWireDeltaLocomotionAndShippedPacingConstants() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let detective = try String(
            contentsOf: root.appendingPathComponent(
                "RainShadow Shared/Gameplay/Actors/DetectiveActorNode.swift"
            ),
            encoding: .utf8
        )
        let client = try String(
            contentsOf: root.appendingPathComponent(
                "RainShadow Shared/Gameplay/Actors/ClientActorNode.swift"
            ),
            encoding: .utf8
        )

        #expect(detective.contains("RouteFollower"))
        #expect(detective.contains("routeFollower.advance"))
        #expect(detective.contains("func updateLocomotion"))
        #expect(detective.contains("ActorLocomotionPacing.maximumFrameDelta"))
        #expect(detective.contains("ActorLocomotionPacing.walkCycleSecondsPerFrame"))
        #expect(detective.contains("ActorLocomotionPacing.standUpSecondsPerFrame"))
        #expect(detective.contains("lookAheadVector"))
        #expect(detective.contains("facingLookAheadDistance"))
        #expect(detective.contains("var isDeskRegistered"))
        // Seat clips are selected as one complete NE-or-SE set. Sit-down is the
        // exact reverse, and the endpoint goes through the facing-aware idle path.
        #expect(detective.contains("enum SeatVisualDirection"))
        #expect(detective.contains("completeSeatTextureSequence"))
        #expect(detective.contains("let seatAnimations = Self.loadSeatAnimationTextures()"))
        #expect(detective.contains("self.facing = self.seatVisualDirection.facing"))
        #expect(detective.contains("self.applyStandingIdleTexture()"))
        #expect(detective.contains("let sitDownTextures = Array(standUpTextures.reversed())"))
        #expect(!detective.contains("seatTransitionFrameIndex"))
        #expect(!detective.contains("shouldHideEmptyDeskChair"))
        #expect(!detective.contains("standUpEmptyChairHandoffFrame"))
        #expect(!detective.contains("animateSeatTransition"))
        #expect(!detective.contains("voss_standing_idle_se_00"))
        #expect(!detective.contains("body.yScale = seatedIdleTextures.isEmpty"))
        #expect(detective.contains("seatedUpperLocalZ"))
        #expect(!detective.contains("actions.append(.move(to:"))
        #expect(!detective.contains("withKey: \"actorPath\""))
        #expect(!detective.contains("withKey: \"walkCycle\""))
        #expect(!detective.contains("distance / 270"))
        #expect(!detective.contains("timePerFrame: 0.14"))

        let office = try String(
            contentsOf: root.appendingPathComponent(
                "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift"
            ),
            encoding: .utf8
        )
        #expect(office.contains("detective.isDeskRegistered"))
        #expect(office.contains("emptyDeskChairWorldPosition"))
        #expect(office.contains("The world prop is the sole chair owner"))
        #expect(office.contains("meaningfullyShorter"))
        #expect(office.contains("isRouteBlocked"))
        #expect(!office.contains("deskChairProp"))
        #expect(!office.contains("shouldHideEmptyDeskChair"))

        #expect(client.contains("ActorLocomotionPacing.pathDuration"))
        #expect(client.contains("ActorLocomotionPacing.walkCycleSecondsPerFrame"))
        #expect(client.contains("lila_departure_ne_"))
        #expect(client.contains("lila_departure_nw_"))
        #expect(client.contains("ClientDepartureFacing.bin"))
        #expect(client.contains("startDepartureWalkCycle"))
        // Door handoff: heading-matched strips with a short crossfade (no moonwalk hold).
        #expect(client.contains("stripHandoffDuration"))
        #expect(client.contains("bodyHandoff"))
        #expect(client.contains("crossfade:"))
        // Phase-continuous strip swap at the internal door (no mid-stride restart).
        #expect(client.contains("texturesStartingAtPhase"))
        #expect(client.contains("departureWalkPhaseOrigin"))
        #expect(!client.contains("easternHandoffMaxAngle"))
        #expect(!client.contains("currentDepartureWalkFrame"))
        #expect(!client.contains("distance / 82"))
        #expect(!client.contains("timePerFrame: 0.15"))
        // Handbag/light contract: never mirror the client body for eastern bins.
        #expect(!client.contains("body.xScale = -"))
    }

    @Test func clientDepartureAtlasCellsExistAndNECycleIsNotPingPongReversed() throws {
        // Shipped NE strip must keep eight distinct cells so post-door playback
        // cannot reverse mid-cycle (the haywire reverse-gait after the door).
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let atlas = root.appendingPathComponent(
            "RainShadow Shared/Resources/Art/Atlases/LilaArrival.atlas"
        )
        var neCells: [Data] = []
        var nwCells: [Data] = []
        for index in 0..<ActorLocomotionPacing.walkFramesPerCycle {
            let ne = atlas.appendingPathComponent(String(format: "lila_departure_ne_%02d.png", index))
            let nw = atlas.appendingPathComponent(String(format: "lila_departure_nw_%02d.png", index))
            #expect(FileManager.default.fileExists(atPath: ne.path), "Missing \(ne.lastPathComponent)")
            #expect(FileManager.default.fileExists(atPath: nw.path), "Missing \(nw.lastPathComponent)")
            neCells.append(try Data(contentsOf: ne))
            nwCells.append(try Data(contentsOf: nw))
        }
        #expect(Set(neCells).count == ActorLocomotionPacing.walkFramesPerCycle,
                "NE departure cells must all be unique (no 00==07 / 01==06 reverse cycle)")
        #expect(Set(nwCells).count == ActorLocomotionPacing.walkFramesPerCycle,
                "NW departure cells must all be unique")
        // Explicit reverse-pair forbid that matched the pre-fix haywire strip.
        #expect(neCells[0] != neCells[7])
        #expect(neCells[1] != neCells[6])
    }

    @Test func clientDepartureNEAtlasFacesEastNotWestProfile() throws {
        // Structural facing check on shipped atlas cells (not path bins alone).
        // NW rear-¾ peeks face on the viewer's LEFT; true NE peeks face on the RIGHT.
        // Eastbound post-door travel must use NE cells that are not a west profile.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let atlas = root.appendingPathComponent(
            "RainShadow Shared/Resources/Art/Atlases/LilaArrival.atlas"
        )
        var neFaces: [DepartureFaceSide] = []
        var nwFaces: [DepartureFaceSide] = []
        for index in 0..<ActorLocomotionPacing.walkFramesPerCycle {
            let neURL = atlas.appendingPathComponent(String(format: "lila_departure_ne_%02d.png", index))
            let nwURL = atlas.appendingPathComponent(String(format: "lila_departure_nw_%02d.png", index))
            let neSide = try DepartureSpriteFacing.faceSide(ofPNG: neURL)
            let nwSide = try DepartureSpriteFacing.faceSide(ofPNG: nwURL)
            #expect(neSide != nil, "NE \(index) must have a readable face peek")
            #expect(nwSide != nil, "NW \(index) must have a readable face peek")
            if let neSide { neFaces.append(neSide) }
            if let nwSide { nwFaces.append(nwSide) }
        }
        #expect(neFaces.count == ActorLocomotionPacing.walkFramesPerCycle)
        #expect(nwFaces.count == ActorLocomotionPacing.walkFramesPerCycle)
        // Consistent facing across the whole cycle (no mid-cycle west↔east flip).
        #expect(neFaces.allSatisfy { $0 == .right },
                "NE departure cells must all face east/NE (face peek right); got \(neFaces)")
        #expect(nwFaces.allSatisfy { $0 == .left },
                "NW departure cells must all face west/NW (face peek left); got \(nwFaces)")
        // Explicit NE ≠ NW silhouette contract (would catch west art labeled as NE).
        #expect(Set(neFaces) != Set(nwFaces))
        #expect(neFaces != nwFaces)
    }

    @Test func clientDepartureNECoatMatchesNWEmeraldNotChromaGreen() throws {
        // Post-door NE cells must keep the deep emerald coat, not chroma-key green
        // cast left by flip/bag-restore pipelines (user-visible "very green" bug).
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let atlas = root.appendingPathComponent(
            "RainShadow Shared/Resources/Art/Atlases/LilaArrival.atlas"
        )
        var neCoatDeltas: [Double] = []
        var nwCoatDeltas: [Double] = []
        for index in 0..<ActorLocomotionPacing.walkFramesPerCycle {
            let neURL = atlas.appendingPathComponent(String(format: "lila_departure_ne_%02d.png", index))
            let nwURL = atlas.appendingPathComponent(String(format: "lila_departure_nw_%02d.png", index))
            let neDelta = try DepartureSpriteFacing.coatGreenMinusRed(ofPNG: neURL)
            let nwDelta = try DepartureSpriteFacing.coatGreenMinusRed(ofPNG: nwURL)
            #expect(neDelta != nil, "NE \(index) must have readable coat pixels")
            #expect(nwDelta != nil, "NW \(index) must have readable coat pixels")
            if let neDelta { neCoatDeltas.append(neDelta) }
            if let nwDelta { nwCoatDeltas.append(nwDelta) }
        }
        let neMean = neCoatDeltas.reduce(0, +) / Double(neCoatDeltas.count)
        let nwMean = nwCoatDeltas.reduce(0, +) / Double(nwCoatDeltas.count)
        // Chroma-green bug sat near +18; clean emerald matches NW near +12.
        #expect(neMean < 16.0, "NE coat too green (G-R=\(neMean)); chroma spill?")
        #expect(abs(neMean - nwMean) < 4.0,
                "NE coat G-R \(neMean) must stay near NW \(nwMean)")
        // No near-pure #00ff00 opaque pixels in NE cells.
        for index in 0..<ActorLocomotionPacing.walkFramesPerCycle {
            let neURL = atlas.appendingPathComponent(String(format: "lila_departure_ne_%02d.png", index))
            let pure = try DepartureSpriteFacing.pureChromaGreenPixelCount(ofPNG: neURL)
            #expect(pure == 0, "NE \(index) has \(pure) pure chroma-green pixels")
        }
    }
}

/// Viewer-left vs viewer-right face peek for rear three-quarter walk cells.
enum DepartureFaceSide: Equatable, CustomStringConvertible {
    case left
    case right
    var description: String { self == .left ? "L" : "R" }
}

/// Pixel analysis of shipped departure atlas PNGs (structural art contract).
enum DepartureSpriteFacing {
    private static func rgbaPixels(ofPNG url: URL) throws -> (pixels: [UInt8], width: Int, height: Int, bytesPerRow: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (pixels, width, height, bytesPerRow)
    }

    /// Skin-tone centroid in the upper half relative to the opaque body centroid.
    static func faceSide(ofPNG url: URL) throws -> DepartureFaceSide? {
        let (pixels, width, height, bytesPerRow) = try rgbaPixels(ofPNG: url)

        var bodyX = 0.0
        var bodyN = 0.0
        var skinX = 0.0
        var skinN = 0.0
        let midY = height / 2

        for y in 0..<height {
            for x in 0..<width {
                let i = y * bytesPerRow + x * 4
                let r = pixels[i]
                let g = pixels[i + 1]
                let b = pixels[i + 2]
                let a = pixels[i + 3]
                guard a > 30 else { continue }
                bodyX += Double(x)
                bodyN += 1
                // Upper-half skin / face tones (rear three-quarter cheek peek).
                if y < midY,
                   r > 115, g > 65, g < 200, b > 35,
                   Int(r) + 5 > Int(g) {
                    skinX += Double(x)
                    skinN += 1
                }
            }
        }
        guard bodyN > 20, skinN >= 3 else { return nil }
        let bodyCX = bodyX / bodyN
        let skinCX = skinX / skinN
        return skinCX < bodyCX ? .left : .right
    }

    /// Mean (G − R) over emerald coat pixels — chroma green sits much higher than NW.
    static func coatGreenMinusRed(ofPNG url: URL) throws -> Double? {
        let (pixels, width, height, bytesPerRow) = try rgbaPixels(ofPNG: url)
        var sum = 0.0
        var count = 0.0
        for y in 0..<height {
            for x in 0..<width {
                let i = y * bytesPerRow + x * 4
                let r = Int(pixels[i])
                let g = Int(pixels[i + 1])
                let b = Int(pixels[i + 2])
                let a = Int(pixels[i + 3])
                // Coat: green-dominant mid tones (excludes skin, bag, pure chroma).
                guard a > 80, g > 30, g < 160, g > r, g > b else { continue }
                sum += Double(g - r)
                count += 1
            }
        }
        guard count > 30 else { return nil }
        return sum / count
    }

    /// Count near-pure #00ff00 opaque pixels (processing leak).
    static func pureChromaGreenPixelCount(ofPNG url: URL) throws -> Int {
        let (pixels, width, height, bytesPerRow) = try rgbaPixels(ofPNG: url)
        var count = 0
        for y in 0..<height {
            for x in 0..<width {
                let i = y * bytesPerRow + x * 4
                let r = Int(pixels[i])
                let g = Int(pixels[i + 1])
                let b = Int(pixels[i + 2])
                let a = Int(pixels[i + 3])
                if a > 40, g > 150, g > r + 40, g > b + 40 {
                    count += 1
                }
            }
        }
        return count
    }
}
