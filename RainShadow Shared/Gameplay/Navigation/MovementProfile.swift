import CoreGraphics
import Foundation

/// One actor's walk rate, expressed the way the Infinity Engine expresses it.
///
/// BG:EE stores speed per *animation*, not per creature, in the animation's own
/// INI. Extracted from `CHAAnim.bif`, every human class animation reads:
///
///     // 6100.ini — CHMF fighter_male_human
///     [general]
///     move_scale=9        ; = IE_MOVEMENTRATE
///
/// `EXTSPEED.2da` overrides it per animation ID across a **5–10** band — the
/// half-ogre at 7, the 0x7400 family at 10 — and no character animation appears
/// in that table, so player characters take the default 9. Higher is faster.
///
/// The *Adventurer's Guide* is explicit that BG has one constant human walk rate
/// (p. 43: "There is one constant movement rate in Baldur's Gate"), so this type
/// is a data spine for creatures that genuinely differ, not licence to vary the
/// detective. Both shipped actors are `humanoid`.
struct MovementProfile: Equatable, Sendable {
    /// Legal `move_scale` range observed in BG:EE's `EXTSPEED.2da`.
    static let engineMoveScaleRange: ClosedRange<CGFloat> = 5...10

    /// BG:EE `IE_MOVEMENTRATE` / `move_scale`.
    var moveScale: CGFloat

    /// Encumbrance band. BG divides the movement *rate* by this factor
    /// (`Actor::CalculateSpeedFromRate`: `movementRate /= encumbranceFactor`),
    /// which is why the bands are integer divisors rather than free multipliers.
    var encumbrance: Encumbrance

    /// Multipliers applied to the rate, e.g. Haste. BG implements Haste as an
    /// effect on `IE_MOVEMENTRATE`, so it belongs here and not on the final
    /// speed — same number either way, but the rate is where the engine puts it.
    var rateMultiplier: CGFloat

    init(
        moveScale: CGFloat = ActorLocomotionPacing.infinityEngineHumanoidMoveScale,
        encumbrance: Encumbrance = .unencumbered,
        rateMultiplier: CGFloat = 1
    ) {
        precondition(moveScale > 0)
        precondition(rateMultiplier >= 0)
        self.moveScale = moveScale
        self.encumbrance = encumbrance
        self.rateMultiplier = rateMultiplier
    }

    /// An ordinary adult on foot — the only profile RainShadow currently ships.
    static let humanoid = MovementProfile()

    /// Encumbrance bands from the *Adventurer's Guide* (p. 43): over the weight
    /// allowed by Strength, "movement speed is halved"; carrying more than 10%
    /// over "prevents them from moving altogether".
    ///
    /// Inactive until inventory weight exists — nothing constructs anything but
    /// `.unencumbered` today.
    enum Encumbrance: Equatable, Sendable {
        case unencumbered
        /// Over the Strength weight limit, up to 110%.
        case overloaded
        /// Above 110% of the limit.
        case immobile

        var rateDivisor: CGFloat? {
            switch self {
            case .unencumbered: 1
            case .overloaded: 2
            case .immobile: nil
            }
        }
    }

    // MARK: - Derived

    /// `move_scale` after encumbrance and multipliers. `nil` means immobile.
    var effectiveMoveScale: CGFloat? {
        guard let divisor = encumbrance.rateDivisor else { return nil }
        let scaled = moveScale * rateMultiplier / divisor
        return scaled > 0 ? scaled : nil
    }

    /// `1500 / rate` in milliseconds — `Actor::CalculateSpeedFromRate`. Larger is
    /// slower, as in the engine.
    var walkScale: CGFloat? {
        effectiveMoveScale.map { 1500 / $0 }
    }

    /// Horizontal world units per second, after `NormalizeDeltas` rounds the
    /// step up. Zero when immobile, which `Movable.doStep` treats as "no
    /// movement" — the engine's own zero-speed branch.
    ///
    /// Reporting only. What the actor actually walks is one `normalizeDeltas`
    /// step per tick against `walkScale`; a profile with a different rate is
    /// felt through that, not through this number.
    var walkSpeed: CGFloat {
        guard let walkScale else { return 0 }
        let stepFactor = ActorLocomotionPacing.infinityEngineStepTime / walkScale
        let step = (ActorLocomotionPacing.stepRadius * stepFactor).rounded(.up)
        return step * ActorLocomotionPacing.logicTicksPerSecond
    }

    var isImmobile: Bool { effectiveMoveScale == nil }

    /// Haste, as BG applies it: double the rate.
    ///
    /// Worth knowing before using it — because movement and the walk cycle share
    /// one 15 Hz tick, a rate multiplier makes the feet slide. That is not a bug
    /// here; it is what BG does too.
    func hastened(_ multiplier: CGFloat = 2) -> MovementProfile {
        var copy = self
        copy.rateMultiplier *= multiplier
        return copy
    }

    func encumbered(_ band: Encumbrance) -> MovementProfile {
        var copy = self
        copy.encumbrance = band
        return copy
    }
}
