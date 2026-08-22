import CoreGraphics

/// Baldur's Gate-scale office contract. The generated shell, prop sprites and
/// actors have independent display scales but share one authored coordinate map.
enum OfficeInteriorScale {
    static let standingDetectiveSourceHeight: CGFloat = 100
    static let seatedDetectiveSourceHeight: CGFloat = 100
    /// Client atlases use the same 100-unit adult body as the detective (BG:EE
    /// party-member height class — no child-scale or giant-scale adults).
    static let standingClientSourceHeight: CGFloat = 100

    enum ActorDisplay {
        /// Shipped standing frames carry a 200px opaque body on a 512px canvas.
        /// Keep these measured texture values beside the display size so fixed
        /// architecture can reference the detective actually drawn on screen.
        static let textureCanvasSize = CGSize(width: 512, height: 512)
        static let standingOpaqueBodyTextureHeight: CGFloat = 200
        /// Legacy logical actor scale retained for locomotion and furniture contracts.
        static let standingScale: CGFloat = 0.82
        static let seatedScale: CGFloat = 0.82
        /// SpriteKit presentation: integer pixels so scaled frames do not shimmer.
        ///
        /// Anchored to the architecture rather than picked by eye. The shipping plate's
        /// clear entrance opening is 198 plate px → 78.21 world units; a real interior
        /// door is ~1.16× an adult, so the visible body must land near 70 units. 180
        /// yields 200/512 × 180 = 70.3125 and puts the opening at 1.11× the body.
        /// The prior 232 made the body 90.625 — taller than the door it walks through.
        ///
        /// Seated and standing share one size — DeskNE shared-scale atlases keep the
        /// crouch shorter on the 512 canvas, so a larger seated node is unnecessary
        /// and caused a height snap when leaving desk registration.
        static let spriteDisplaySize = CGSize(width: 180, height: 180)
        /// Prior display size, kept only to derive the offsets below. Visual offsets
        /// hand-tuned against the old sprite scale by this factor; world-space and
        /// nav-derived values must not.
        static let previousSpriteDisplayHeight: CGFloat = 232
        static let spriteScale: CGFloat = 1.0
        /// Ratio between the current sprite presentation and the one the seated
        /// offsets and contact shadows below were originally tuned against.
        /// Multiply sprite-derived visual offsets by this; never world geometry.
        static var visualBodyRatio: CGFloat {
            spriteDisplaySize.height / previousSpriteDisplayHeight
        }

        /// Visual-only shift from the walkable chair-side navigation root into
        /// the chair/desk registration. Positive Y reaches from the camera-near
        /// egress stop north into the kneehole (actorStart is deskChair − 30
        /// authored units; 30 × environment ≈ 11.85). Nav-derived, so it does
        /// **not** follow the sprite size.
        static let seatedYOffset: CGFloat = 47.4
        /// Whole-body seat nudge (world space). Stay on the SW / camera-near
        /// kneehole side of the desk ground (desk.y − chair.y ≈ 12–16). Nudges
        /// past ~18 put feet on the visitor / far side of the writing surface.
        /// Pull far enough that baked forearms read over the writing surface.
        /// Scales with the sprite: the lean is measured in body-heights.
        static var seatedDeskNudge: CGPoint { CGPoint(x: 0, y: 16 * visualBodyRatio) }
        /// Extra upper lean toward the desktop past the apron lip.
        static var seatedUpperDeskReach: CGPoint { CGPoint(x: 0, y: 10 * visualBodyRatio) }
    }

    /// Legacy logical body (82 units). Retained only as the locomotion/authoring
    /// unit some tuned constants were expressed in. It carries **no scale
    /// authority** — sizing anything against it while the sprite renders at a
    /// different height is what made Voss taller than his own door. Use
    /// `standingAdultBodyHeight`.
    static let detectiveBodyHeight = standingDetectiveSourceHeight * ActorDisplay.standingScale
    static let seatedDetectiveBodyHeight = seatedDetectiveSourceHeight * ActorDisplay.seatedScale
    /// Actual visible standing Voss body after SpriteKit maps the shipped 512px
    /// texture canvas into the display node. This is the single scale authority:
    /// camera density, door architecture, furniture multiples and city props all
    /// measure against what is actually drawn on screen.
    static let renderedStandingDetectiveBodyHeight =
        ActorDisplay.standingOpaqueBodyTextureHeight
        / ActorDisplay.textureCanvasSize.height
        * ActorDisplay.spriteDisplaySize.height
        * abs(ActorDisplay.spriteScale)
    /// Same adult height as the detective — shared humanoid contract for office play.
    static var clientBodyHeight: CGFloat { renderedStandingDetectiveBodyHeight }
    /// Canonical standing adult used by office furniture body-multiples and city props.
    static var standingAdultBodyHeight: CGFloat { renderedStandingDetectiveBodyHeight }

    /// Shell / coordinate-map scale, loaded into the V11 geometry manifest as
    /// the same 0.395 contract. DefaultPlayZoom independently retains the 9%
    /// actor-to-visible-height presentation; prop relative scales cancel this
    /// factor so furniture remains body-locked when architecture is redrawn.
    static let environment: CGFloat = 0.395

    /// On-screen body ÷ camera-visible height. Matches `DefaultPlayZoom` mid-band
    /// (~9% in the BG:EE area view); must use the rendered body.
    static let playBodyToVisibleHeight: CGFloat = DefaultPlayZoom.targetBodyToVisibleHeight

    /// Presentation scale only; furniture/body proportions stay in world space.
    /// Driven by the rendered sprite height so density matches what players see.
    static var cameraVisibleHeight: CGFloat {
        DefaultPlayZoom.cameraVisibleHeight(
            standingBodyHeight: renderedStandingDetectiveBodyHeight
        )
    }

    /// V3 plate centre and scale-about focus.
    static let layoutFocus = CGPoint(x: 2_048, y: 1_152)

    /// 16:9 area plate. Keep in step with `office_room_plan.ART_W/H`. After the
    /// The V11 registered plate and all full-plate masks stay 4096×2304.
    static let sourceArtOrigin = CGPoint.zero
    static let sourceArtSize = CGSize(width: 4_096, height: 2_304)

    // MARK: - Measured source content heights (opaque bbox of runtime PNGs)
    // Kept here so tests and scene code share one source of truth.

    enum SourceContentHeight {
        static let deskEnsemble: CGFloat = 743
        /// Floor contact → desktop face (includes drawer pedestal).
        static let deskWorkingSurface: CGFloat = 249
        /// Vertical drawer-stack face only (floor contact through top drawer rail, no lamp/desktop clutter).
        static let deskDrawerFace: CGFloat = 240
        static let deskLamp: CGFloat = 250
        static let deskPhone: CGFloat = 142
        static let deskMug: CGFloat = 123
        static let deskAshtray: CGFloat = 73
        static let deskFiles: CGFloat = 178
        static let deskPapers: CGFloat = 240
        static let deskChair: CGFloat = 429
        /// Diagonal opaque length of the V11 reference-registered closed leaf.
        static let doorLeaf: CGFloat = 508
        /// Removed with the V08 open-plan partition.
        static let internalDoorLeafHinge: CGFloat = 0
        static let filingCabinet: CGFloat = 538
        static let visitorArmchair: CGFloat = 421
        static let radiator: CGFloat = 338
        static let coatRack: CGFloat = 558
        static let archiveBox: CGFloat = 297
        static let wastebasket: CGFloat = 241
        static let floorTrash: CGFloat = 173
        static let wornRug: CGFloat = 573
        static let hiddenBottle: CGFloat = 240
        static let framedPhoto: CGFloat = 239
        static let bookshelf: CGFloat = 675
        static let waitingChairB: CGFloat = 241
        static let pencilTray: CGFloat = 70
        static let standingDetective = standingDetectiveSourceHeight
        static let seatedDetective = seatedDetectiveSourceHeight
        /// Legacy single-pane measurement retained for furniture-scale reports;
        /// V11's two casements are fixed plate pixels registered by polygons.
        static let windowGlassOpening: CGFloat = 136
    }

    /// Per-prop scale relative to the V3 shell/coordinate scale. Absolute
    /// targets: standard 0.22, desk chair 0.135, visitor 0.17, desk 0.12,
    /// window overlay 0.35, floor decal 0.18, small props 0.12, pocket 0.10.
    /// Absolute scales below are anchored to real 1930s–40s object heights
    /// normalized to a 1.75 m adult, then carried ~10–15% above strict realism —
    /// BG furniture skews slightly oversized for readability at play zoom.
    /// New absolute for a target body multiple M is `M × standingAdultBodyHeight
    /// / SourceContentHeight`.
    enum PropRelativeScale {
        /// Shared sideboard/partition family. Not a furniture-height reference —
        /// the partition wall slices depend on it, so leave it alone and give
        /// mis-scaled props their own entry below.
        static let standard: CGFloat = 0.22 / environment
        /// Tall bookcase ~2.0 m → 1.30× body (was 0.2238, reading 2.15× / 2.9 m).
        static let bookshelf: CGFloat = 0.1354 / environment
        /// Four-drawer filing cabinet ~1.32 m → 0.90× body. Split off `standard`,
        /// which was rendering it at 1.68× / 2.3 m.
        static let filingCabinet: CGFloat = 0.1176 / environment
        /// Cast-iron radiator ~0.7 m → 0.50× body (was 1.06× / 1.4 m on `standard`).
        static let radiator: CGFloat = 0.1040 / environment
        /// Desk ensemble left at 0.12: with the corrected body the working surface
        /// lands at 0.425× ≈ 0.74 m, which is already a correct desk height.
        static let deskEnsemble: CGFloat = 0.12 / environment
        /// Archive stack on cabinet A — ~0.47× body.
        static let archiveStack: CGFloat = 0.1121 / environment
        /// Empty desk chair, back ~1.2 m → 0.70× body; matches the seated-bake
        /// seat height. Do not exceed ~0.13 absolute or it clips the pedestals.
        static let deskChair: CGFloat = 0.1147 / environment
        /// Client-side leather armchair ~1.3 m → 0.75× body.
        static let visitorArmchair: CGFloat = 0.1253 / environment
        /// Waiting-room set, kept internally consistent with chair B.
        static let waitingChair: CGFloat = 0.1784 / environment
        /// Waiting chair B art is shorter; absolute keeps it ~0.64× body.
        static let waitingChairB: CGFloat = 0.1867 / environment
        static let waitingTable: CGFloat = 0.1861 / environment
        /// Standing fan: tall enough that its head and base stay readable.
        static let standingFan: CGFloat = 0.1618 / environment
        /// Entrance rack ~1.8 m → 1.05× body, subordinate to the door beside it.
        static let coatRack: CGFloat = 0.1323 / environment
        /// Wastebasket ~0.5 m → 0.28× body. Split off `smallProp`, which shares a
        /// value with the safe, umbrella stand and archive boxes.
        static let wastebasket: CGFloat = 0.0817 / environment
        /// Covers the complete outer recess after the straightening counter-warp.
        static let window: CGFloat = 0.35 / environment
        /// Independent height fit for the unblinded glass-and-frame insert.
        static let windowVertical: CGFloat = 0.32 / environment
        static let floorDecal: CGFloat = 0.22 / environment
        static let smallProp: CGFloat = 0.12 / environment
        static let pocketProp: CGFloat = 0.10 / environment
        /// Sideboard bottle — ~0.24× body, below generic pocket.
        static let hiddenBottle: CGFloat = 0.0703 / environment
        /// Full-plate overlays sized against the shell art (no extra relative inflate).
        static let plateOverlay: CGFloat = 1.0 / environment
        /// Exterior edge sprite fitted to the small sliver in the V12 reference.
        /// This is independent of the larger baked doorway/collision aperture.
        static var entranceDoorLeaf: CGFloat {
            OfficeNavigationLayout.Architecture.entranceLeafDisplayScale / environment
        }
    }

    // MARK: - BG acceptance bands (multiples of detective body)

    enum Band {
        static let standingBody: ClosedRange<CGFloat> = 66...74
        /// The V12 authority is the small, nearly edge-on diagonal sliver in the
        /// concept, not the baked doorway height. Preserve its visual diagonal
        /// against actor scale without inflating it to the environment scale.
        static let door: ClosedRange<CGFloat> = 1.90...2.10
        static let deskWorkingSurface: ClosedRange<CGFloat> = 0.32...0.50
        /// Drawer pedestal face: roughly knee-to-hip furniture.
        static let deskDrawerFace: ClosedRange<CGFloat> = 0.30...0.48
        static let deskLamp: ClosedRange<CGFloat> = 0.35...0.65
        static let deskPhone: ClosedRange<CGFloat> = 0.20...0.35
        static let deskMug: ClosedRange<CGFloat> = 0.15...0.30
        static let deskAshtray: ClosedRange<CGFloat> = 0.08...0.18
        static let deskFiles: ClosedRange<CGFloat> = 0.20...0.40
        static let deskPapers: ClosedRange<CGFloat> = 0.25...0.50
        /// Desk kneehole side chair (not a tall visitor armchair).
        static let chair: ClosedRange<CGFloat> = 0.55...0.78
        /// Client-side leather armchairs — taller seat back than the desk chair.
        static let visitorArmchair: ClosedRange<CGFloat> = 0.68...0.90
        /// Four-drawer filing cabinet, ~1.3 m of steel. Was folded in with the
        /// bookcase under one 1.10–1.90 band, which let it reach 2.3 m.
        static let cabinet: ClosedRange<CGFloat> = 0.80...1.05
        /// Tall bookcase — the only office prop that legitimately overtops an adult.
        static let bookcase: ClosedRange<CGFloat> = 1.15...1.45
        static let radiator: ClosedRange<CGFloat> = 0.40...0.62
        static let wastebasket: ClosedRange<CGFloat> = 0.22...0.36
        static let coatRack: ClosedRange<CGFloat> = 0.95...1.15
        /// Complete painted steel-casement opening.
        static let windowGlass: ClosedRange<CGFloat> = 0.50...0.90
        /// One of the six registered panes in a three-column by two-row window.
        static let windowPane: ClosedRange<CGFloat> = 0.22...0.32
    }

    // MARK: - Mapping

    static func mapPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: layoutFocus.x + (point.x - layoutFocus.x) * environment,
            y: layoutFocus.y + (point.y - layoutFocus.y) * environment
        )
    }

    /// Inverse of `mapPoint`, for QA that reports scene nodes in authored pixels.
    static func unmapPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: layoutFocus.x + (point.x - layoutFocus.x) / environment,
            y: layoutFocus.y + (point.y - layoutFocus.y) / environment
        )
    }

    static func mapSize(_ size: CGSize) -> CGSize {
        CGSize(width: size.width * environment, height: size.height * environment)
    }

    static func mapRect(_ rect: CGRect) -> CGRect {
        let origin = mapPoint(rect.origin)
        return CGRect(
            x: origin.x,
            y: origin.y,
            width: rect.width * environment,
            height: rect.height * environment
        )
    }

    /// World-unit height of opaque content after environment and relative prop scale.
    static func effectiveHeight(contentHeight: CGFloat, relativeScale: CGFloat = 1) -> CGFloat {
        contentHeight * environment * relativeScale
    }

    /// Furniture height as a multiple of the standing adult **as drawn on screen**.
    /// Previously divided by the logical 82-unit body while the sprite rendered at
    /// 90.625, so every prop read ~9.5% short against the character.
    static func bodyMultiple(contentHeight: CGFloat, relativeScale: CGFloat = 1) -> CGFloat {
        effectiveHeight(contentHeight: contentHeight, relativeScale: relativeScale)
            / standingAdultBodyHeight
    }

    /// Desk ensemble world display scale (environment × desk-relative).
    static var deskDisplayScale: CGFloat {
        environment * PropRelativeScale.deskEnsemble
    }

    static var standardPropDisplayScale: CGFloat {
        environment * PropRelativeScale.standard
    }

    static var bookshelfDisplayScale: CGFloat {
        environment * PropRelativeScale.bookshelf
    }

    /// Filing cabinets and their floor shadow (previously on `standard`).
    static var filingCabinetDisplayScale: CGFloat {
        environment * PropRelativeScale.filingCabinet
    }

    static var radiatorDisplayScale: CGFloat {
        environment * PropRelativeScale.radiator
    }

    static var wastebasketDisplayScale: CGFloat {
        environment * PropRelativeScale.wastebasket
    }

    static var archiveStackDisplayScale: CGFloat {
        environment * PropRelativeScale.archiveStack
    }

    static var seatingPropDisplayScale: CGFloat {
        environment * PropRelativeScale.deskChair
    }

    static var visitorArmchairDisplayScale: CGFloat {
        environment * PropRelativeScale.visitorArmchair
    }

    static var waitingChairDisplayScale: CGFloat {
        environment * PropRelativeScale.waitingChair
    }

    static var waitingChairBDisplayScale: CGFloat {
        environment * PropRelativeScale.waitingChairB
    }

    static var waitingTableDisplayScale: CGFloat {
        environment * PropRelativeScale.waitingTable
    }

    static var hiddenBottleDisplayScale: CGFloat {
        environment * PropRelativeScale.hiddenBottle
    }

    static var standingFanDisplayScale: CGFloat {
        environment * PropRelativeScale.standingFan
    }

    static var coatRackDisplayScale: CGFloat {
        environment * PropRelativeScale.coatRack
    }

    static var windowDisplayScale: CGFloat {
        environment * PropRelativeScale.window
    }

    static var windowVerticalDisplayScale: CGFloat {
        environment * PropRelativeScale.windowVertical
    }

    static var floorDecalDisplayScale: CGFloat {
        environment * PropRelativeScale.floorDecal
    }

    /// Archive boxes, wastebasket, and floor trash — knee-high clutter, not furniture.
    static var smallPropDisplayScale: CGFloat {
        environment * PropRelativeScale.smallProp
    }

    /// Pocket-scale props tucked under the desk (e.g. hidden bottle).
    static var pocketPropDisplayScale: CGFloat {
        environment * PropRelativeScale.pocketProp
    }

    /// Alias kept for call sites that mean floor scrap clutter.
    static var clutterDisplayScale: CGFloat { smallPropDisplayScale }

    /// Display scale so a runtime texture matches shell world size 1:1 with art pixels.
    static var plateOverlayDisplayScale: CGFloat {
        environment * PropRelativeScale.plateOverlay
    }

    static var scaledArtSize: CGSize { mapSize(sourceArtSize) }

    static var shellOrigin: CGPoint { mapPoint(sourceArtOrigin) }

    /// World-space extent of the painted plate. The shell is centred on
    /// `layoutFocus`, not anchored at the origin, so camera clamping needs the
    /// rect rather than the size.
    static var worldBounds: CGRect {
        CGRect(origin: shellOrigin, size: scaledArtSize)
    }

    /// Opaque extent of the painted room inside the suite plate, measured from
    /// V11 `office_1950s_plate_v11.png` (art px x 639…3354, y 104…2109 top-down;
    /// the room is letterboxed on the 4096×2304 canvas and all pixels
    /// outside its immutable architecture mask are baked black).
    ///
    /// Camera clamping uses this, not `worldBounds`: the plate rect would let a
    /// followed camera swing out over the empty margin.
    static let paintedRoomSourceRect = CGRect(x: 639, y: 194, width: 2_716, height: 2_006)

    static var paintedRoomBounds: CGRect { mapRect(paintedRoomSourceRect) }
}
