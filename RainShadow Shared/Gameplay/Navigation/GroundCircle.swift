import CoreGraphics
import Foundation

/// `EA` — the alignment-to-the-party axis from `stats.ids`, values as they are
/// in GemRB `includes/ie_stats.h`. The numbers matter: `ShouldDrawCircle` and
/// several script matchers compare against the cutoffs rather than the cases.
enum IEEnmity: Int, Equatable, Sendable {
    case inanimate = 1
    case pc = 2
    case familiar = 3
    case ally = 4
    case controlled = 5
    case charmed = 6
    case controllable = 15
    case goodButRed = 28
    case goodButBlue = 29
    case goodCutoff = 30
    case neutral = 128
    case evilCutoff = 200
    case evilButGreen = 201
    case evilButBlue = 202
    /// `EVILBYCHARM` in the original.
    case charmedPC = 254
    case enemy = 255
}

/// `RGBAColor.h`'s named colours, the ones the circle can be painted.
/// Not a palette in the engine's sense — that is `IEPalette`, the
/// 256-entry `Palette` port used by `IEPaperdollColours`.
enum IENamedColors {
    static let green = HighlightColor(rgba: 0x00FF_00FF)
    static let red = HighlightColor(rgba: 0xFF00_00FF)
    static let blue = HighlightColor(rgba: 0x0000_FFFF)
    static let cyan = HighlightColor(rgba: 0x00FF_FFFF)
    static let yellow = HighlightColor(rgba: 0xFFFF_00FF)
    static let magenta = HighlightColor(rgba: 0xFF00_FFFF)
    static let white = HighlightColor(rgba: 0xFFFF_FFFF)
}

/// Everything `Actor::SetCircleSize` and `Actor::ShouldDrawCircle` read, in one
/// value so the decision can be tested without an actor, a game or a renderer.
///
/// Several fields have no producer in RainShadow yet — there is no death, no
/// invisibility, no hostility and no targeting. They are here because this is a
/// transliteration: the branch that reads them is ported whole, and the day the
/// concept exists it is one assignment away rather than a re-read of the engine.
struct GroundCircleState: Equatable, Sendable {
    /// `CharAnimations::GetCircleSize` — avatars.2da `CIRCLESIZE`. This is the
    /// *drawn* circle, not `personal_space`; see `humanoidCircleSize`.
    var circleSize: Int
    var enmity: IEEnmity
    /// `Actor::IsPC`. Not derivable from `enmity` — a charmed PC is `EA_CHARMEDPC`
    /// and still a PC, which is exactly the case the dim branch has to get right.
    var isPC: Bool
    /// `Selectable::Selected`.
    var isSelected: Bool
    /// `Selectable::Over` — the pointer is inside the ground circle.
    var isOver: Bool
    /// `STATE_PANIC`, or `STATE_BERSERK` with `IE_CHECKFORBERSERK` set.
    var isPanicked: Bool
    /// `Actor::UnselectableTimer`.
    var isUnselectable: Bool
    /// `gc->InDialog() && gc->dialoghandler->IsTarget(this)`.
    var isDialogueTarget: Bool
    /// `Timers.remainingTalkSoundTime`, in milliseconds.
    var remainingTalkSoundTime: Int
    /// `IE_NOCIRCLE`.
    var noCircle: Bool
    /// `STATE_DEAD` or `IF_REALLYDIED`.
    var isDead: Bool
    /// `stateInvisible`. Only hides the circle of an actor past `EA_GOODCUTOFF`.
    var isInvisible: Bool
    /// `ScreenFlags::Cutscene`.
    var isCutscene: Bool
    /// `DF_FREEZE_SCRIPTS` — dialogue or a tactical pause. The engine's comment
    /// is "we always show circle/target on pause".
    var worldIsFrozen: Bool
    /// `Game::IsTargeted` — attacked, cast at or talked to.
    var isTargeted: Bool
    /// The "GUI Feedback Level" dictionary entry. GemRB defaults it to 4 and so
    /// do we; see `GroundCircleResolver.shouldDraw` for what each level buys.
    var guiFeedbackLevel: Int

    init(
        circleSize: Int = GroundCircleResolver.humanoidCircleSize,
        enmity: IEEnmity = .neutral,
        isPC: Bool = false,
        isSelected: Bool = false,
        isOver: Bool = false,
        isPanicked: Bool = false,
        isUnselectable: Bool = false,
        isDialogueTarget: Bool = false,
        remainingTalkSoundTime: Int = 0,
        noCircle: Bool = false,
        isDead: Bool = false,
        isInvisible: Bool = false,
        isCutscene: Bool = false,
        worldIsFrozen: Bool = false,
        isTargeted: Bool = false,
        guiFeedbackLevel: Int = GroundCircleResolver.defaultFeedbackLevel
    ) {
        self.circleSize = circleSize
        self.enmity = enmity
        self.isPC = isPC
        self.isSelected = isSelected
        self.isOver = isOver
        self.isPanicked = isPanicked
        self.isUnselectable = isUnselectable
        self.isDialogueTarget = isDialogueTarget
        self.remainingTalkSoundTime = remainingTalkSoundTime
        self.noCircle = noCircle
        self.isDead = isDead
        self.isInvisible = isInvisible
        self.isCutscene = isCutscene
        self.worldIsFrozen = worldIsFrozen
        self.isTargeted = isTargeted
        self.guiFeedbackLevel = guiFeedbackLevel
    }
}

/// One resolved ground circle: the ellipse `Video::DrawEllipse` would stroke and
/// the colour it would stroke it in.
struct GroundCircle: Equatable {
    var color: HighlightColor
    /// Full width and height, not radii — `Size(baseSize * 8, baseSize * 6)`.
    var size: CGSize
}

/// `Selectable::DrawCircle` plus the two `Actor` functions that feed it
/// (`SetCircleSize`, `ShouldDrawCircle`), as pure functions.
///
/// GemRB comments the colour table on `SetCircleSize` itself:
///
/// > BG2 colours ground circles as follows:
/// > - dark green for unselected party members
/// > - bright green for selected party members
/// > - bright red for enemies
/// > - yellow for panicked actors
/// > - flashing green/white for a party member the mouse is over
/// > - flashing red/white for enemies the mouse is over
/// > - flashing cyan/white for neutrals the mouse is over
/// > - flashing white for speakers
///
/// Three things upstream does are deliberately **not** ported:
///
/// - **PST's BAM ground circles.** `SetCircleSize` also picks two sprites out of
///   `core->GroundCircles[csize][idx]`, loaded from the `GroundCircleBAM1..3` ini
///   keys. Only PST ships those; every other game leaves the array empty and
///   falls through to `DrawEllipse`. We have no BAM pipeline and no PST art, so
///   the sprite branch has nothing to select and the `normalIdx`/`selectedIdx`
///   bookkeeping that exists only to index it is gone with it.
/// - **The underground-ankheg case.** `ShouldDrawCircle` returns false for
///   `IE_ANI_WALK` on an `IE_ANI_TWO_PIECE` animation. There is no such animation
///   type here — the burrowing half is what it is for.
/// - **`GameControl::DrawTargetReticle`.** Destination and waypoint feedback is a
///   separate system that already ships (`ui_move_marker_*`, `ui_waypoint_pip`).
enum GroundCircleResolver {
    /// The drawn circle size of an ordinary humanoid, from avatars.2da's
    /// `CIRCLESIZE` column. BG:EE's per-animation ini states the same number the
    /// other way round, as the resulting x radius:
    ///
    ///     [general]
    ///     move_scale=9        ; = IE_MOVEMENTRATE
    ///     ellipse=16          ; this — CircleSize2Radius(2) * 4 = 16
    ///     personal_space=3    ; the pathing footprint, in search-map cells
    ///
    /// So the drawn ellipse is 32x24: semi-axes of exactly one search cell.
    /// `personal_space` is the *other* field and belongs to navigation; it is
    /// ported separately as `ActorLocomotionPacing.personalSpaceCells` and is
    /// deliberately not this number.
    static let humanoidCircleSize = 2

    /// `core->GetDictionary().Get("GUI Feedback Level", 4)`.
    static let defaultFeedbackLevel = 4

    /// `core->HasFeature(GFFlags::JOURNAL_HAS_SECTIONS)` — the flag BG2 sets and
    /// BG1 does not, which `ShouldDrawCircle` reuses as "this game has one more
    /// feedback level". Our journal has sections, so we are on the BG2 table.
    static let extraFeedbackLevel = 1

    /// `Actor::ShouldDrawCircle`.
    static func shouldDraw(_ state: GroundCircleState) -> Bool {
        if state.noCircle { return false }
        if state.isDead { return false }

        // adjust invisibility for enemies
        if state.enmity.rawValue > IEEnmity.goodCutoff.rawValue && state.isInvisible {
            return false
        }

        // ground circles are not drawn in cutscenes, except for the speaker
        if state.isCutscene && !state.isDialogueTarget { return false }

        // we always show circle/target on pause
        var drawCircle = true
        if state.isDialogueTarget { return true }

        if !state.worldIsFrozen {
            // check marker feedback level
            // bg2 had one level more, treating 5 differently and adding 6
            let extraLevel = extraFeedbackLevel
            let feedback = state.guiFeedbackLevel
            if state.isOver {
                // hovered creature
                drawCircle = feedback >= 1
            } else if state.isSelected {
                // selected creature
                drawCircle = feedback >= 2
            } else if state.isPC {
                // selectable
                drawCircle = feedback >= 3
            } else if state.enmity.rawValue >= IEEnmity.evilCutoff.rawValue && state.isTargeted {
                // hostile
                drawCircle = feedback >= 4
            } else if state.enmity.rawValue >= IEEnmity.evilCutoff.rawValue && extraLevel != 0 {
                // hostile
                drawCircle = feedback >= 5
            } else {
                // all
                drawCircle = feedback >= 5 + extraLevel
            }
        }

        return drawCircle
    }

    /// `Actor::SetCircleSize`'s colour choice, and the radius oscillation it sets
    /// alongside (`Selectable::sizeFactor`).
    static func baseColor(_ state: GroundCircleState) -> (color: HighlightColor, sizeFactor: CGFloat) {
        if state.isUnselectable {
            return (IENamedColors.magenta, 1)
        }
        if state.isPanicked {
            return (IENamedColors.yellow, 1)
        }
        if state.isDialogueTarget || state.remainingTalkSoundTime > 0 {
            var sizeFactor: CGFloat = 1
            if state.remainingTalkSoundTime > 0 {
                // Approximation: pulsating at about 2Hz over a notable radius growth.
                sizeFactor = 1.1
                    + sin(Double(state.remainingTalkSoundTime) * (4 * .pi) / 1000) * 0.1
            }
            return (IENamedColors.white, sizeFactor)
        }

        switch state.enmity {
        case .pc, .familiar, .ally, .controlled, .charmed, .evilButGreen, .goodCutoff:
            return (IENamedColors.green, 1)
        case .evilCutoff:
            return (IENamedColors.yellow, 1)
        case .enemy, .goodButRed, .charmedPC:
            return (IENamedColors.red, 1)
        default:
            return (IENamedColors.cyan, 1)
        }
    }

    /// `Selectable::DrawCircle`, minus the sprite branch. Nil means the engine
    /// would draw nothing at all this frame.
    ///
    /// ```cpp
    /// Color mix;
    /// const Color* col = &selectedColor;
    /// if (Selected && !Over) { /* selected sprite */ }
    /// else if (Over) { mix = GlobalColorCycle.Blend(overColor, selectedColor); col = &mix; }
    /// else if (IsPC()) {
    ///     // only dim base EA colors
    ///     if (*col == ColorGreen || *col == ColorBlue || *col == ColorRed) col = &overColor;
    /// }
    /// auto baseSize = CircleSize2Radius() * sizeFactor;
    /// const Size s(baseSize * 8, baseSize * 6);
    /// ```
    static func appearance(_ state: GroundCircleState, colorCycleStep: Int) -> GroundCircle? {
        guard state.circleSize > 0, shouldDraw(state) else { return nil }

        let (selectedColor, sizeFactor) = baseColor(state)
        let overColor = selectedColor.halved

        var color = selectedColor
        if state.isSelected && !state.isOver {
            // The selected BAM cycle upstream; the colour is unchanged.
        } else if state.isOver {
            color = IEColorCycle.blend(overColor, selectedColor, step: colorCycleStep)
        } else if state.isPC {
            // only dim base EA colors
            if selectedColor == IENamedColors.green
                || selectedColor == IENamedColors.blue
                || selectedColor == IENamedColors.red {
                color = overColor
            }
        }

        // `Size` takes ints, so the float factor truncates here, not at the edge.
        let baseSize = CGFloat(IEGeometry.circleSizeToRadius(state.circleSize)) * sizeFactor
        let size = CGSize(
            width: (baseSize * 8).rounded(.towardZero),
            height: (baseSize * 6).rounded(.towardZero)
        )
        return GroundCircle(color: color, size: size)
    }

    /// `Selectable::IsOverCircle`. Size 0 and 1 test the search cell's bounding
    /// box rather than the ellipse, which is upstream's shortcut and is why a
    /// small creature is a touch easier to click than it looks.
    ///
    /// ```cpp
    /// if (csize < 2) {
    ///     Point d = P - CenterPos;
    ///     if (d.x < -16 || d.x > 16) return false;
    ///     if (d.y < -12 || d.y > 12) return false;
    ///     return true;
    /// }
    /// return P.IsWithinEllipse(csize - 1, CenterPos);
    /// ```
    static func isOverCircle(_ point: CGPoint, center: CGPoint, circleSize: Int) -> Bool {
        if circleSize < 2 {
            let dx = point.x - center.x
            let dy = point.y - center.y
            if dx < -16 || dx > 16 { return false }
            if dy < -12 || dy > 12 { return false }
            return true
        }
        return IEGeometry.isWithinEllipse(point, of: center, radius: circleSize - 1)
    }
}
