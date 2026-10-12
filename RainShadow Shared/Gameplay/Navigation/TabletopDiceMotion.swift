import Foundation
import simd

/// Cosmetic fixed-step rigid-piece motion. No combat state or random source.
/// Gravity/restitution drive the throw; a short guided settle presents the
/// already-resolved face. A cocked visual retries the same receipt, never a roll.
struct TabletopDiceMotion {
    private(set) var position: SIMD3<Float>
    private(set) var orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    private var velocity: SIMD3<Float>
    private var elapsed: Double = 0
    private var accumulator: Double = 0
    private var settleOrientation: simd_quatf?
    private var settlePosition: SIMD3<Float>?
    private(set) var contacts = 0
    private(set) var finished = false
    private(set) var retries = 0
    let targetOrientation: simd_quatf
    let restingHeight: Float
    let lane: Float
    private var spin: Float
    private let collisionVertices: [SIMD3<Float>]
    static let step = 1.0 / 120.0

    init(faceNormal: SIMD3<Float>, faceUp: SIMD3<Float>? = nil, restingHeight: Float, index: Int, count: Int, collisionVertices: [SIMD3<Float>] = []) {
        lane = (Float(index) - Float(count - 1) / 2) * 2.7
        self.restingHeight = restingHeight
        self.collisionVertices = collisionVertices
        targetOrientation = Self.readableOrientation(normal: faceNormal, up: faceUp)
        position = SIMD3<Float>(lane - 3.8, 4.2 + Float(index % 2) * 0.3, 0.6)
        velocity = SIMD3<Float>(6.5, -1, -1.4)
        spin = 9 + Float(index % 3)
    }

    static func readableOrientation(normal: SIMD3<Float>, up: SIMD3<Float>? = nil) -> simd_quatf {
        let aligned = simd_quatf(from: simd_normalize(normal), to: SIMD3<Float>(0, 1, 0))
        guard let up else { return aligned }
        let heading = aligned.act(up)
        return simd_quatf(angle: atan2(heading.x, -heading.z), axis: SIMD3<Float>(0, 1, 0)) * aligned
    }

    mutating func advance(delta: Double) {
        guard delta.isFinite, delta > 0, !finished else { return }
        accumulator += min(delta, 0.3)
        while accumulator >= Self.step && !finished {
            accumulator -= Self.step
            elapsed += Self.step
            let dt = Float(Self.step)
            if elapsed < 1.05 {
                velocity.y -= 22 * dt
                position += velocity * dt
                orientation = simd_normalize(simd_quatf(angle: spin * dt, axis: simd_normalize(SIMD3<Float>(1, 0.7, 0.4))) * orientation)
                let floor = supportHeight
                if position.y < floor {
                    position.y = floor
                    if velocity.y < -0.65 { contacts += 1 }
                    velocity.y = abs(velocity.y) * 0.42
                    velocity.x *= 0.72; velocity.z *= 0.72
                    spin *= 0.82
                }
                if abs(position.z) > 1.5 { position.z = min(1.5, max(-1.5, position.z)); velocity.z *= -0.5; contacts += 1 }
            } else {
                if settleOrientation == nil { settleOrientation = orientation; settlePosition = position }
                let t = Float(min(1, (elapsed - 1.05) / 0.4))
                let smooth = t * t * (3 - 2 * t)
                orientation = simd_slerp(settleOrientation!, targetOrientation, smooth)
                position = simd_mix(settlePosition!, SIMD3<Float>(lane, restingHeight, 0), SIMD3<Float>(repeating: smooth))
                if !collisionVertices.isEmpty { position.y = max(position.y, supportHeight) }
                if t >= 1 { finished = true }
            }
        }
    }

    private var supportHeight: Float {
        guard !collisionVertices.isEmpty else { return finished ? restingHeight : 1.05 }
        return -(collisionVertices.map { orientation.act($0).y }.min() ?? -restingHeight)
    }

    mutating func retryCocked() {
        guard retries < 1 else { settle(); return }
        retries += 1; elapsed = 0; accumulator = 0; finished = false
        position = SIMD3<Float>(lane, 3, 0); velocity = SIMD3<Float>(0.5, -1, 0.4)
        settleOrientation = nil; settlePosition = nil
    }

    mutating func settle() {
        orientation = targetOrientation; position = SIMD3<Float>(lane, restingHeight, 0); finished = true
    }

    static func upperFace(normals: [SIMD3<Float>], orientation: simd_quatf) -> Int? {
        let heights = normals.map { orientation.act($0).y }
        guard let best = heights.indices.max(by: { heights[$0] < heights[$1] }), heights[best] > 0.985 else { return nil }
        return best
    }
}
