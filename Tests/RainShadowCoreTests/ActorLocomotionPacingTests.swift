import Foundation
import Testing
@testable import RainShadowCore

struct ActorLocomotionPacingTests {
    /// The gait, taken after `NormalizeDeltas` rounds each axis up.
    ///
    /// The arithmetic gives 6.79 units a tick, but the engine ceils, so the real
    /// stride is 7 — 105 units a second. Deriving from the un-rounded figure
    /// describes a pace the game never walks, which is what the old
    /// body-heights-per-second derivation did.
    @Test func walkSpeedIsTheEnginesRoundedStride() {
        // Rebuild the engine's arithmetic independently rather than pinning a
        // magic ratio: `STEP_RADIUS * (StepTime / walkScale)` per tick, where
        // `walkScale = 1500 / IE_MOVEMENTRATE`.
        let walkScale = 1500 / ActorLocomotionPacing.infinityEngineHumanoidMoveScale
        let unrounded = ActorLocomotionPacing.stepRadius
            * (ActorLocomotionPacing.infinityEngineStepTime / walkScale)
        #expect(abs(unrounded - 6.792) < 0.001)

        #expect(ActorLocomotionPacing.horizontalStepPerTick == 7)
        #expect(ActorLocomotionPacing.walkSpeed == 105)
        #expect(ActorLocomotionPacing.walkSpeedBand.contains(ActorLocomotionPacing.walkSpeed))
        #expect(ActorLocomotionPacing.infinityEngineHumanoidMoveScale == 9)
    }

    /// A step is what the actor takes, so the pace figures must agree with it.
    @Test func walkSpeedAgreesWithWhatNormalizeDeltasEmits() {
        var dx: CGFloat = 1_000
        var dy: CGFloat = 0
        PathFinder.normalizeDeltas(&dx, &dy, factor: ActorLocomotionPacing.stepFactor)
        #expect(dx == ActorLocomotionPacing.horizontalStepPerTick)
        #expect(
            ActorLocomotionPacing.walkSpeed
                == dx * ActorLocomotionPacing.logicTicksPerSecond
        )
    }

    @Test func logicTickMatchesInfinityEngineRate() {
        // `defaultTicksPerSec = 15`. Movement and the walk cycle share this tick,
        // which is why an authored frame is exactly one step.
        #expect(LogicTickClock.ticksPerSecond == 15)
        #expect(abs(LogicTickClock.tickDuration - 1.0 / 15.0) < 0.000001)
        #expect(ActorLocomotionPacing.walkCycleSecondsPerFrame == LogicTickClock.tickDuration)
    }

    /// `NormalizeDeltas` multiplies the vertical component by 0.75 — the 16×12
    /// search-cell aspect — and *then* ceils both axes.
    ///
    /// The rounding is why the effective ratio a player sees is 6/7, about
    /// 0.857, rather than 0.75: north-south travel is slower than east-west, but
    /// by less than the constant suggests.
    @Test func verticalTravelIsForeshortenedThenRounded() {
        #expect(ActorLocomotionPacing.verticalProjectionScale == 0.75)
        #expect(
            ActorLocomotionPacing.verticalProjectionScale
                == SearchMap.defaultCellSize.height / SearchMap.defaultCellSize.width
        )

        var dx: CGFloat = 0
        var dy: CGFloat = 1_000
        PathFinder.normalizeDeltas(&dx, &dy, factor: ActorLocomotionPacing.stepFactor)
        #expect(dy == 6)
        #expect(ActorLocomotionPacing.verticalStepPerTick == 6)

        let effectiveRatio = ActorLocomotionPacing.verticalStepPerTick
            / ActorLocomotionPacing.horizontalStepPerTick
        #expect(effectiveRatio > ActorLocomotionPacing.verticalProjectionScale)
        #expect(abs(effectiveRatio - 6.0 / 7.0) < 0.0001)
    }

    /// Walking north really is slower than walking east, by the ratio above.
    @Test func aNorthwardWalkTakesMoreTicksThanAnEastwardOneOfTheSameLength() {
        func ticksToCover(_ delta: CGPoint) -> Int {
            let map = MovableTestSupport.openMap()
            let start = CGPoint(x: 160, y: 120)
            var walker = MovableTestSupport.movable(on: map, at: start)
            walker.walkTo(CGPoint(x: start.x + delta.x, y: start.y + delta.y), ticks: 1)
            var ticks = 0
            for tick in 2...500 where walker.isMoving {
                walker.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: tick)
                ticks += 1
            }
            return ticks
        }

        let east = ticksToCover(CGPoint(x: 168, y: 0))
        let north = ticksToCover(CGPoint(x: 0, y: 168))
        #expect(east > 0 && north > 0)
        #expect(north > east)
    }

    @Test func walkCycleDurationMatchesBGParityGait() {
        let frame = ActorLocomotionPacing.walkCycleSecondsPerFrame
        let cycle = frame * TimeInterval(ActorLocomotionPacing.walkFramesPerCycle)
        #expect(ActorLocomotionPacing.walkCycleSecondsPerFrameBand.contains(frame))
        #expect(ActorLocomotionPacing.walkCycleDurationBand.contains(cycle))
        #expect(ActorLocomotionPacing.walkFramesPerCycle == 8)
    }

    /// One authored frame per logic tick, as in the engine: creature animations
    /// advance a frame each time `DoStep` emits a displacement, which is why a
    /// walk cycle cannot drift against the distance travelled.
    @Test func aWalkCycleCoversAFixedDistanceRatherThanAFixedFractionOfABody() {
        let cycleDuration = ActorLocomotionPacing.walkCycleSecondsPerFrame
            * TimeInterval(ActorLocomotionPacing.walkFramesPerCycle)
        let distancePerCycle = ActorLocomotionPacing.walkSpeed * CGFloat(cycleDuration)
        // Eight ticks at seven units each.
        #expect(distancePerCycle == 56)
        #expect(
            distancePerCycle
                == ActorLocomotionPacing.horizontalStepPerTick
                    * CGFloat(ActorLocomotionPacing.walkFramesPerCycle)
        )
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

        #expect(detective.contains("Movable"))
        #expect(detective.contains("movable.doStep"))
        #expect(detective.contains("func updateLocomotion"))
        #expect(detective.contains("ActorLocomotionPacing.maximumFrameDelta"))
        #expect(detective.contains("ActorLocomotionPacing.standUpSecondsPerFrame"))
        // Facing while walking is the path node's stored orientation, assigned
        // by `DoStep` — never re-derived from velocity, so there is no look-ahead
        // vector and no hysteresis band any more.
        #expect(detective.contains("setWalkFacing(movable.orientation)"))
        #expect(!detective.contains("lookAheadVector"))
        #expect(detective.contains("var isDeskRegistered"))

        // Movement and the walk cycle both run on the engine's fixed logic tick.
        // The per-frame accumulator is gone precisely so they cannot drift apart:
        // one tick is one step and one authored frame.
        #expect(detective.contains("LogicTickClock"))
        #expect(detective.contains("tickClock.drain"))
        #expect(detective.contains("LogicTickClock.tickDuration"))
        #expect(detective.contains("func advanceWalkFrame"))
        #expect(!detective.contains("walkFrameAccumulator"))
        #expect(!detective.contains("advanceWalkAnimation"))

        // Gradual turn-in-place while standing (`NewOrientation` + `GetNextFace`),
        // and the backoff wait when a blocker cannot be bumped.
        #expect(detective.contains("pendingFacing"))
        #expect(detective.contains("func turnToFace"))
        #expect(detective.contains("stepped(toward:"))
        #expect(detective.contains("func beginMovementBackoff"))
        // Seat clips are selected as one complete directional set. Sit-down is
        // the exact reverse, and the endpoint goes through the facing-aware idle
        // path without mirroring the approved NE desk master.
        #expect(detective.contains("enum SeatVisualDirection"))
        #expect(detective.contains("case .northEast: .northWest"))
        #expect(detective.contains("completeSeatFrameSequence"))
        #expect(detective.contains("let seatAnimations = Self.loadSeatAnimationFrames(library: indexedLibrary)"))
        #expect(detective.contains("self.facing = self.seatVisualDirection.facing"))
        #expect(detective.contains("self.applyStandingIdleTexture()"))
        #expect(detective.contains("let sitDownFrames = Array(standUpFrames.reversed())"))
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
        // The waypoint queue moved out of both scenes into `MovementOrderQueue`,
        // where it is unit-tested directly by `MovementOrderQueueTests` rather
        // than asserted as source text. These greps stay because they pin the
        // *engine* behaviours to a file — an accidental revert to `route`, or a
        // lost replan budget, still fails here — but the queue's own suite is
        // now the primary guard.
        let movement = try String(
            contentsOf: root.appendingPathComponent(
                "RainShadow Shared/Gameplay/Navigation/MovementOrderQueue.swift"
            ),
            encoding: .utf8
        )

        #expect(office.contains("detective.isDeskRegistered"))
        // The desk chair moved out of the scene's code and into the office's
        // record, so the assertion moved with it — see
        // `AreaPropTests.theDeskChairIsAWorldPropStandingWhereTheSeatIs`. It is
        // load-bearing rather than decoration: Voss's seated and transition
        // atlases are chairless, so the world prop is the only chair there is
        // and it has to be drawn in every actor state.
        #expect(!office.contains("deskChairProp"))
        #expect(!office.contains("shouldHideEmptyDeskChair"))

        // A refused order stays refused: a floor click that lands on impassable
        // ground is turned down at the click layer (`IE_CURSOR_BLOCKED`) rather
        // than relocated. `FindPath` *will* move a blocked goal, which is right
        // for a scripted approach and wrong for a tap on a wall.
        #expect(movement.contains("isOrderableFloor"))
        #expect(!movement.contains("navigation.route(from:"))
        #expect(!office.contains("navigation.route(from:"))
        // Plan around actors first, bump only when nothing clear exists. Both
        // decisions live inside `Movable` now, where the engine keeps them:
        // `WalkTo` passes PF_ACTORS_ARE_BLOCKING, `DoStep` probes along its own
        // heading and either bumps or backs off.
        let movable = try String(
            contentsOf: root.appendingPathComponent(
                "RainShadow Shared/Gameplay/Navigation/Movable.swift"
            ),
            encoding: .utf8
        )
        #expect(movable.contains("actorsAreBlocking"))
        #expect(movable.contains("collisionLookahead") || movable.contains("lookahead"))
        #expect(movable.contains("func backoff()"))
        #expect(movable.contains("func bumpAway()"))
        #expect(movable.contains("func bumpBack()"))
        #expect(office.contains("beginMovementBackoff") || detective.contains("beginMovementBackoff"))
        // Conversations turn participants gradually, as `GSUtils` does — and Voss
        // is on his feet by then, via the empty-route seat egress. Both moved onto
        // the cutscene adapter when the office cutscenes became authored cue lists.
        let adapters = try String(
            contentsOf: root.appendingPathComponent(
                "RainShadow Shared/Gameplay/Actors/CutsceneActorAdapters.swift"
            ),
            encoding: .utf8
        )
        #expect(adapters.contains("turnToFace"))
        #expect(adapters.contains("walk(path: Path(), completion: completion)"))

        // Replan budget: `Actor::NewPath` abandons past MAX_PATH_TRIES instead of
        // grinding a search forever, and a fresh order resets the count. The
        // counter is `pathTries` on the actor, where the engine keeps it — the
        // old `recordCongestion` pair counted failed *steps*, which is a
        // different axis and had no engine counterpart.
        #expect(movement.contains("hasExhaustedPathTries"))
        #expect(movement.contains("resetPathTries"))
        #expect(movable.contains("MAX_PATH_TRIES"))

        // Arrow / WASD keys drive the viewport, never the actor.
        #expect(!office.contains("moveDetective(to: candidate)"))

        // Pace reaches the actor as `walkScale` — the quantity `DoStep` divides
        // `StepTime` by — not as a scalar speed. A scalar cannot express a
        // `NormalizeDeltas` step, which is rounded up per axis.
        #expect(detective.contains("movementProfile.walkScale"))
        #expect(!detective.contains("movementProfile.walkSpeed"))
        #expect(!detective.contains("ActorLocomotionPacing.walkSpeed"))

        // Pace comes from the actor's own BG:EE `move_scale` profile, which
        // resolves through the same five engine constants ActorLocomotionPacing
        // documents — never from a number typed in at the call site.
        #expect(client.contains("movementProfile.walkScale"))
        #expect(!client.contains("movementProfile.walkSpeed"))
        #expect(!client.contains("ActorLocomotionPacing.walkSpeed"))
        #expect(client.contains("ActorLocomotionPacing.walkCycleSecondsPerFrame"))
        #expect(client.contains("prefix: \"lila_departure_ne\""))
        #expect(client.contains("prefix: \"lila_departure_nw\""))
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

    /// `Movable::AddWayPoint` semantics.
    ///
    /// This used to loop over both scene files asserting they implemented the
    /// queue identically, because they each carried their own copy and "neither
    /// may drift". There is one copy now, in `MovementOrderQueue`, so drift is
    /// impossible by construction and the behaviours are asserted directly by
    /// `MovementOrderQueueTests` — appending from the last goal, dropping an
    /// empty leg, and wiping the queue on a plain order.
    ///
    /// What is left here is the part behaviour cannot see: that both scenes
    /// still draw a reticle on *both* the replace and the append path, which is
    /// `DrawTargetReticles` marking every queued waypoint and always the
    /// destination.
    @Test func bothScenesPipTheReplaceAndTheAppendPath() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        for relativePath in [
            "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift",
            "RainShadow Shared/Scenes/CityDistrict/CityDistrictScene.swift"
        ] {
            let scene = try String(
                contentsOf: root.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            // Both order paths route through one helper now, because the pips
            // are a pure function of the live path: `AddWayPoint` marks the node
            // it extends from and `DoStep` clears the mark on arrival, so there
            // is no separate queue that can drift out of step with the route.
            let pips = scene.components(separatedBy: "refreshWaypointPips(destination:").count - 1
            #expect(pips >= 2, "\(relativePath) pips \(pips) of the two order paths")
            #expect(scene.contains("for waypoint in detective.pendingWaypoints"))
            #expect(scene.contains("clearWaypointPips()"))
        }
    }

    @Test func viewportImplementsTheInfinityEngineCameraModel() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let base = try String(
            contentsOf: root.appendingPathComponent(
                "RainShadow Shared/Core/Scene/BaseGameScene.swift"
            ),
            encoding: .utf8
        )

        // The viewport is a first-class thing the player owns, not a tether to
        // the actor: it scrolls, detaches, and is re-centred deliberately.
        #expect(base.contains("enum CameraMode"))
        #expect(base.contains("case following"))
        #expect(base.contains("case free"))
        #expect(base.contains("func detachCamera"))
        #expect(base.contains("func followCamera"))
        #expect(base.contains("func updateCamera"))

        // BG:EE `MoveViewportTo(p, center: true)` — the double-click recentre.
        #expect(base.contains("func recenterCamera"))
        // `OnMouseDrag` GEM_MB_MIDDLE, and the touch two-finger equivalent.
        #expect(base.contains("func panCamera"))
        #expect(base.contains("override func otherMouseDragged"))
        #expect(base.contains("twoFingerAnchor"))
        // `OnGlobalMouseMove` edge scrolling and `ApplyKeyScrolling`.
        #expect(base.contains("func edgeScrollVector"))
        #expect(base.contains("func applyKeyScrolling"))
        #expect(base.contains("override func keyUp"))
        // Double-click is plumbed through the pointer event, not re-derived.
        #expect(base.contains("isDoubleClick: event.clickCount == 2"))

        // Directional keys report whether an overlay consumed them; anything left
        // over scrolls the viewport rather than moving the actor.
        #expect(base.contains("func handleDirectionalInput(_ direction: CGVector) -> Bool"))

        // BG:EE zoom. The wheel reports consumption the same way the direction
        // keys do, so an open overlay keeps it and anything left over zooms.
        #expect(base.contains("func handleScrollInput(_ deltaY: CGFloat) -> Bool"))
        #expect(base.contains("func setZoomStep"))
        #expect(base.contains("func applyViewportScrollGesture"))
        // `SetScalePercent(100, true)` on a middle click that did not pan.
        #expect(base.contains("override func otherMouseUp"))
        #expect(base.contains("func resetZoom"))
        // GemRB `Zoom Lock`: the same event pans instead of zooming.
        #expect(base.contains("zoomLockEnabled"))
        // Trackpad pinch on macOS, two-finger pinch on iOS.
        #expect(base.contains("override func magnify"))
        #expect(base.contains("twoFingerSpread"))
        // `MoveViewportTo`'s clamp, and the live scale rather than the 100% base
        // driving the viewport size it is given.
        #expect(base.contains("AreaViewport.clampedCenter"))
        #expect(base.contains("height: playVisibleHeight"))
        #expect(base.contains("viewDelta.dx * playCameraScale"))
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
        // Structural facing check on the authored material plane (not path bins
        // or RGB guesses). NW rear-¾ peeks face on the viewer's LEFT; true NE
        // peeks face on the RIGHT.
        // Eastbound post-door travel must use NE cells that are not a west profile.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sprite = try DepartureSpriteFacing.indexedLila(repoRoot: root)
        var neFaces: [DepartureFaceSide] = []
        var nwFaces: [DepartureFaceSide] = []
        for index in 0..<ActorLocomotionPacing.walkFramesPerCycle {
            let neName = String(format: "lila_departure_ne_%02d.png", index)
            let nwName = String(format: "lila_departure_nw_%02d.png", index)
            let neFrame = try #require(sprite.frame(atlas: "LilaArrival.atlas", name: neName))
            let nwFrame = try #require(sprite.frame(atlas: "LilaArrival.atlas", name: nwName))
            let neSide = DepartureSpriteFacing.faceSide(of: neFrame)
            let nwSide = DepartureSpriteFacing.faceSide(of: nwFrame)
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

    @Test func clientIndexedWardrobeKeepsTheAuthoredDressAndCoatMaterials() throws {
        // The indexed plane is the wardrobe authority. Arrival wears the dress
        // in LEATHER; the approved departure art adds the long coat in ARMOR.
        // Requiring those categorical slots is stronger than estimating a
        // green-minus-red band from the rendered PNG: a palette change cannot
        // disguise a different material, and chroma-key RGB cannot enter a byte
        // plane that contains only authored IE indices.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sprite = try DepartureSpriteFacing.indexedLila(repoRoot: root)
        #expect(sprite.colors == [22, 5, 253, 233, 193, 219, 234])

        for index in 0..<9 {
            let name = String(format: "lila_arrival_sw_%02d.png", index)
            let frame = try #require(sprite.frame(atlas: "LilaArrival.atlas", name: name))
            let leatherShare = DepartureSpriteFacing.materialShare(.leather, in: frame)
            #expect(leatherShare >= 0.55, "\(name) dress LEATHER share is \(leatherShare)")
            #expect(!frame.indices.contains(UInt8(IEPalette.shadowIndex)))
        }

        var neArmorShares: [Double] = []
        var nwArmorShares: [Double] = []
        for index in 0..<ActorLocomotionPacing.walkFramesPerCycle {
            let neName = String(format: "lila_departure_ne_%02d.png", index)
            let nwName = String(format: "lila_departure_nw_%02d.png", index)
            let neFrame = try #require(sprite.frame(atlas: "LilaArrival.atlas", name: neName))
            let nwFrame = try #require(sprite.frame(atlas: "LilaArrival.atlas", name: nwName))
            let neArmor = DepartureSpriteFacing.materialShare(.armor, in: neFrame)
            let nwArmor = DepartureSpriteFacing.materialShare(.armor, in: nwFrame)
            #expect(neArmor >= 0.70, "\(neName) coat ARMOR share is \(neArmor)")
            #expect(nwArmor >= 0.70, "\(nwName) coat ARMOR share is \(nwArmor)")
            #expect(!neFrame.indices.contains(UInt8(IEPalette.shadowIndex)))
            #expect(!nwFrame.indices.contains(UInt8(IEPalette.shadowIndex)))
            neArmorShares.append(neArmor)
            nwArmorShares.append(nwArmor)
        }

        let neMean = neArmorShares.reduce(0, +) / Double(neArmorShares.count)
        let nwMean = nwArmorShares.reduce(0, +) / Double(nwArmorShares.count)
        #expect(abs(neMean - nwMean) < 0.05,
                "NE coat share \(neMean) must stay near NW \(nwMean)")
    }
}

/// Viewer-left vs viewer-right face peek for rear three-quarter walk cells.
enum DepartureFaceSide: Equatable, CustomStringConvertible {
    case left
    case right
    var description: String { self == .left ? "L" : "R" }
}

/// Exact index-plane analysis of shipped departure cells (structural art contract).
enum DepartureSpriteFacing {
    static func indexedLila(repoRoot: URL) throws -> IEIndexedSprite {
        let manifest = repoRoot
            .appendingPathComponent("RainShadow Shared/Resources/Art/IE/Avatars", isDirectory: true)
            .appendingPathComponent("Lila", isDirectory: true)
            .appendingPathComponent(IEIndexedSprite.manifestFileName, isDirectory: false)
        return try IEIndexedSprite(contentsOf: manifest, tables: IEGradientTables.load())
    }

    /// Authored SKIN centroid in the upper half relative to the body centroid.
    static func faceSide(of frame: IEIndexedSprite.Frame) -> DepartureFaceSide? {
        var bodyX = 0.0
        var bodyN = 0.0
        var faceX = 0.0
        var faceN = 0.0
        // The stored plane is native since bundle v02; `size` is what it is
        // rendered to, and indexing the plane with it walks off the end.
        let midY = frame.nativeSize.height / 2

        for y in 0..<frame.nativeSize.height {
            for x in 0..<frame.nativeSize.width {
                let index = frame.index(x: x, yFromTop: y)
                guard index != UInt8(IEPalette.colorKeyIndex) else { continue }
                bodyX += Double(x)
                bodyN += 1
                if y < midY, materialSlot(for: index) == .skin {
                    faceX += Double(x)
                    faceN += 1
                }
            }
        }
        guard bodyN > 20, faceN >= 3 else { return nil }
        let bodyCX = bodyX / bodyN
        let faceCX = faceX / faceN
        return faceCX < bodyCX ? .left : .right
    }

    static func materialShare(
        _ material: IEMaterialSlot,
        in frame: IEIndexedSprite.Frame
    ) -> Double {
        let body = frame.indices.filter { $0 != UInt8(IEPalette.colorKeyIndex) }
        guard !body.isEmpty else { return 0 }
        let count = body.count { materialSlot(for: $0) == material }
        return Double(count) / Double(body.count)
    }

    private static func materialSlot(for index: UInt8) -> IEMaterialSlot? {
        let raw = Int(index) - 0x04
        guard raw >= 0 else { return nil }
        return IEMaterialSlot(rawValue: raw / IEPaperdollColours.numCols)
    }
}
