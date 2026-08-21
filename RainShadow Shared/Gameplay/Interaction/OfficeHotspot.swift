import CoreGraphics

struct OfficeHotspot {
    let id: String
    let name: String
    let hitArea: CGRect
    let approachPoint: CGPoint
    let observation: String
    /// Present when the area region is an exit. Keeping the payload on the
    /// interaction object means click and cursor behaviour use the same record
    /// that authored the hotspot, rather than a scene-level id special case.
    let travel: AreaTravel?
}
