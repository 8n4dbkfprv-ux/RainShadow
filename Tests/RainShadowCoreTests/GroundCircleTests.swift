import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// `Selectable::DrawCircle`, `Actor::SetCircleSize` and `Actor::ShouldDrawCircle`,
/// held to the engine's own numbers.
struct GroundCircleTests {
    private func state(
        enmity: IEEnmity = .neutral,
        isPC: Bool = false,
        isSelected: Bool = false,
        isOver: Bool = false,
        feedback: Int = GroundCircleResolver.defaultFeedbackLevel
    ) -> GroundCircleState {
        GroundCircleState(
            enmity: enmity,
            isPC: isPC,
            isSelected: isSelected,
            isOver: isOver,
            guiFeedbackLevel: feedback
        )
    }

    // MARK: - Size

    /// `CircleSize2Radius`: size 1 is the floored special case, and from 2 up the
    /// radius is `(size - 1) * 4` — "still need to multiply by 4 or 3 to get full
    /// pixel radii", as the engine's comment puts it.
    @Test func circleSizeToRadiusMatchesTheEngineTable() {
        #expect(IEGeometry.circleSizeToRadius(1) == 3)
        #expect(IEGeometry.circleSizeToRadius(2) == 4)
        #expect(IEGeometry.circleSizeToRadius(3) == 8)
        #expect(IEGeometry.circleSizeToRadius(4) == 12)
    }

    /// A humanoid's circle is one search cell either side of its feet. This is the
    /// number BG:EE's animation ini states as `ellipse=16`, reached the other way.
    @Test func aHumanoidsEllipseIsOneSearchCellInEveryDirection() throws {
        let circle = try #require(
            GroundCircleResolver.appearance(
                state(enmity: .pc, isPC: true, isSelected: true),
                colorCycleStep: 0
            )
        )
        #expect(circle.size == CGSize(width: 32, height: 24))
        #expect(GroundCircleResolver.humanoidCircleSize == 2)
    }

    /// `sizeFactor` is the talk-sound pulse, and it truncates where `Size(int, int)`
    /// does — not at the drawing edge.
    ///
    /// The feedback level is raised because a talk sound is not itself a reason to
    /// draw: `ShouldDrawCircle` only forces a circle for the *dialogue* target, so a
    /// barking neutral at the default level pulses a circle nobody sees.
    @Test func aTalkingActorsCircleGrowsAndTruncatesLikeSize() throws {
        var talking = state(enmity: .neutral, feedback: 6)
        talking.remainingTalkSoundTime = 125 // sin(pi/2) = 1, so the factor peaks at 1.2
        let circle = try #require(GroundCircleResolver.appearance(talking, colorCycleStep: 0))
        #expect(circle.color == IENamedColors.white)
        // 4 * 1.2 = 4.8 -> 38.4 x 28.8, truncated
        #expect(circle.size == CGSize(width: 38, height: 28))
    }

    // MARK: - IsOverCircle

    /// Below size 2 the engine tests the search cell's bounding box, not the
    /// ellipse. A corner of that box is inside; the same offset on an ellipse is not.
    @Test func smallCirclesHitTestAsABoxAndLargerOnesAsAnEllipse() {
        let centre = CGPoint.zero
        #expect(GroundCircleResolver.isOverCircle(CGPoint(x: 16, y: 12), center: centre, circleSize: 1))
        #expect(!GroundCircleResolver.isOverCircle(CGPoint(x: 17, y: 0), center: centre, circleSize: 1))
        #expect(!GroundCircleResolver.isOverCircle(CGPoint(x: 0, y: 13), center: centre, circleSize: 1))

        // circleSize 2 -> IsWithinEllipse(1), semi-axes 16 x 12
        #expect(GroundCircleResolver.isOverCircle(CGPoint(x: 16, y: 0), center: centre, circleSize: 2))
        #expect(GroundCircleResolver.isOverCircle(CGPoint(x: 0, y: 12), center: centre, circleSize: 2))
        #expect(!GroundCircleResolver.isOverCircle(CGPoint(x: 16, y: 12), center: centre, circleSize: 2))
        #expect(!GroundCircleResolver.isOverCircle(CGPoint(x: 17, y: 0), center: centre, circleSize: 2))
    }

    /// The ellipse is symmetric in y, so our y-up world and the engine's y-down one
    /// answer identically — the port never has to flip a sign here.
    @Test func theEllipseIsSymmetricInBothAxes() {
        for point in [CGPoint(x: 11, y: 8), CGPoint(x: -11, y: 8), CGPoint(x: 11, y: -8), CGPoint(x: -11, y: -8)] {
            #expect(IEGeometry.isWithinEllipse(point, of: .zero, radius: 1))
        }
    }

    // MARK: - Colour

    @Test func theEnmityTableIsTheEngines() {
        let green: [IEEnmity] = [.pc, .familiar, .ally, .controlled, .charmed, .evilButGreen, .goodCutoff]
        for enmity in green {
            #expect(GroundCircleResolver.baseColor(state(enmity: enmity)).color == IENamedColors.green)
        }
        for enmity in [IEEnmity.enemy, .goodButRed, .charmedPC] {
            #expect(GroundCircleResolver.baseColor(state(enmity: enmity)).color == IENamedColors.red)
        }
        #expect(GroundCircleResolver.baseColor(state(enmity: .evilCutoff)).color == IENamedColors.yellow)
        // Everything the switch does not name falls through to cyan, neutrals included.
        #expect(GroundCircleResolver.baseColor(state(enmity: .neutral)).color == IENamedColors.cyan)
        #expect(GroundCircleResolver.baseColor(state(enmity: .inanimate)).color == IENamedColors.cyan)
    }

    @Test func stateOverridesOutrankAlignment() {
        var panicked = state(enmity: .pc, isPC: true)
        panicked.isPanicked = true
        #expect(GroundCircleResolver.baseColor(panicked).color == IENamedColors.yellow)

        var unselectable = panicked
        unselectable.isUnselectable = true
        #expect(GroundCircleResolver.baseColor(unselectable).color == IENamedColors.magenta)

        var speaker = state(enmity: .enemy)
        speaker.isDialogueTarget = true
        #expect(GroundCircleResolver.baseColor(speaker).color == IENamedColors.white)
    }

    /// "only dim base EA colors" — an unselected, unhovered PC gets each channel
    /// halved, which is the dark green BG2 draws for the rest of the party.
    @Test func anUnselectedPartyMembersCircleIsDimmed() throws {
        let dimmed = try #require(
            GroundCircleResolver.appearance(state(enmity: .pc, isPC: true), colorCycleStep: 0)
        )
        #expect(dimmed.color == HighlightColor(rgba: 0x007F_00FF))

        let selected = try #require(
            GroundCircleResolver.appearance(
                state(enmity: .pc, isPC: true, isSelected: true),
                colorCycleStep: 0
            )
        )
        #expect(selected.color == IENamedColors.green)
    }

    /// The dim applies only to green, blue and red. A panicked PC is yellow and
    /// stays at full intensity, which is the point of the colour comparison.
    @Test func onlyBaseAlignmentColoursAreDimmed() throws {
        var panicked = state(enmity: .pc, isPC: true)
        panicked.isPanicked = true
        let circle = try #require(GroundCircleResolver.appearance(panicked, colorCycleStep: 0))
        #expect(circle.color == IENamedColors.yellow)
    }

    /// A neutral NPC is never dimmed — the branch is gated on `IsPC`.
    @Test func neutralsAreNotDimmed() throws {
        var neutral = state(enmity: .neutral, feedback: 6)
        neutral.isSelected = false
        let circle = try #require(GroundCircleResolver.appearance(neutral, colorCycleStep: 0))
        #expect(circle.color == IENamedColors.cyan)
    }

    /// Hover blends the dim colour toward the bright one on the shared cycle. Step 0
    /// is the far end (the full colour) and step 8 the near one, per `Blend`.
    @Test func hoverBlendsBetweenTheDimAndFullColour() throws {
        let hovered = state(enmity: .pc, isPC: true, isOver: true)
        let atFull = try #require(GroundCircleResolver.appearance(hovered, colorCycleStep: 0))
        #expect(atFull.color == IENamedColors.green)

        let atDim = try #require(GroundCircleResolver.appearance(hovered, colorCycleStep: 8))
        #expect(atDim.color == HighlightColor(rgba: 0x007F_00FF))

        let midway = try #require(GroundCircleResolver.appearance(hovered, colorCycleStep: 4))
        // (0x7f * 4 + 0xff * 4) >> 3 = 0xbf
        #expect(midway.color == HighlightColor(rgba: 0x00BF_00FF))
    }

    // MARK: - Colour cycle

    /// `ColorCycleSteps[(time >> 7) & 7]` — one step per 128 ms, and not a triangle
    /// wave: the sequence rests at 0 and overshoots to 8.
    @Test func theColourCycleWalksTheEnginesTable() {
        let observed = (0..<8).map { IEColorCycle.step(atMilliseconds: UInt64($0) * 128) }
        #expect(observed == [6, 4, 2, 0, 2, 4, 6, 8])
        // It wraps after 1024 ms, and holds each step for the full 128 ms.
        #expect(IEColorCycle.step(atMilliseconds: 1024) == 6)
        #expect(IEColorCycle.step(atMilliseconds: 127) == 6)
        #expect(IEColorCycle.step(atMilliseconds: 128) == 4)
    }

    @Test func blendTakesAlphaFromTheFirstColourOnly() {
        let opaque = HighlightColor(rgba: 0x0000_00FF)
        let clear = HighlightColor(rgba: 0xFFFF_FF00)
        #expect(IEColorCycle.blend(opaque, clear, step: 4).alpha == 1)
        #expect(IEColorCycle.blend(clear, opaque, step: 4).alpha == 0)
    }

    // MARK: - ShouldDrawCircle

    /// At GemRB's default feedback level of 4, only hovered, selected and PC actors
    /// are circled. A plain neutral needs 6 on the BG2 table.
    @Test func theDefaultFeedbackLevelCirclesTheParty() {
        #expect(GroundCircleResolver.shouldDraw(state(enmity: .pc, isPC: true, isSelected: true)))
        #expect(GroundCircleResolver.shouldDraw(state(enmity: .pc, isPC: true)))
        #expect(GroundCircleResolver.shouldDraw(state(enmity: .neutral, isOver: true)))
        #expect(!GroundCircleResolver.shouldDraw(state(enmity: .neutral)))
        #expect(GroundCircleResolver.shouldDraw(state(enmity: .neutral, feedback: 6)))
    }

    @Test func hostilesNeedALevelOfTheirOwn() {
        var hostile = state(enmity: .enemy)
        #expect(!GroundCircleResolver.shouldDraw(hostile))
        hostile.isTargeted = true
        #expect(GroundCircleResolver.shouldDraw(hostile))
        hostile.isTargeted = false
        hostile.guiFeedbackLevel = 5
        #expect(GroundCircleResolver.shouldDraw(hostile))
    }

    /// "we always show circle/target on pause" — the whole feedback block is skipped
    /// when scripts are frozen.
    @Test func aFrozenWorldCirclesEveryone() {
        var frozen = state(enmity: .neutral)
        frozen.worldIsFrozen = true
        #expect(GroundCircleResolver.shouldDraw(frozen))
    }

    @Test func cutscenesCircleTheSpeakerAndNoOneElse() {
        var extra = state(enmity: .pc, isPC: true, isSelected: true)
        extra.isCutscene = true
        #expect(!GroundCircleResolver.shouldDraw(extra))

        var speaker = extra
        speaker.isDialogueTarget = true
        #expect(GroundCircleResolver.shouldDraw(speaker))
    }

    @Test func theHardSuppressionsWinOutright() {
        var dead = state(enmity: .pc, isPC: true, isSelected: true)
        dead.isDead = true
        #expect(!GroundCircleResolver.shouldDraw(dead))

        var suppressed = state(enmity: .pc, isPC: true, isSelected: true)
        suppressed.noCircle = true
        #expect(!GroundCircleResolver.shouldDraw(suppressed))

        // Invisibility only hides a circle past EA_GOODCUTOFF, so a hidden PC keeps hers.
        var invisiblePC = state(enmity: .pc, isPC: true, isSelected: true)
        invisiblePC.isInvisible = true
        #expect(GroundCircleResolver.shouldDraw(invisiblePC))

        var invisibleFoe = state(enmity: .enemy)
        invisibleFoe.isInvisible = true
        invisibleFoe.guiFeedbackLevel = 6
        #expect(!GroundCircleResolver.shouldDraw(invisibleFoe))
    }

    /// A circle size of 0 is the engine's "no circle at all" — bird animations use it,
    /// and it is the same flag that lets them ignore the search map.
    @Test func circleSizeZeroDrawsNothing() {
        var bird = state(enmity: .pc, isPC: true, isSelected: true)
        bird.circleSize = 0
        #expect(GroundCircleResolver.appearance(bird, colorCycleStep: 0) == nil)
    }
}
