import Foundation
import CoreGraphics

/// Cosmetic debris physics owned by RainShadow, outside the GemRB movement port.
/// Horizontal velocity is in ground units; point.y is projected world space.
/// Height is independent of ground depth. Debris never stamps the search map.
struct BarrelFragmentPose: Codable, Equatable {
    enum Kind: Int, Codable, CaseIterable { case stave, splinter, lid, hoop }
    let kind: Kind
    var point: CGPoint
    var angle: Double
    let scale: Double
    var isValid: Bool {
        point.x.isFinite && point.y.isFinite && angle.isFinite && scale.isFinite && (0.5...1.5).contains(scale)
    }
}

struct BarrelFragmentBody: Equatable {
    var pose: BarrelFragmentPose
    var height: Double
    var velocity: CGPoint
    var liftSpeed: Double
    var spin: Double
    var sleeping = false
    var bounces = 0
    var wallContacts = 0
    var radius: Double {
        switch pose.kind { case .stave: 2.5; case .splinter: 1.5; case .lid: 5; case .hoop: 4 }
    }
    var mass: Double {
        switch pose.kind { case .stave: 1; case .splinter: 0.35; case .lid: 2; case .hoop: 1.5 }
    }
}

struct BarrelDebrisPhysics {
    static let step = 1.0 / 120
    static let maximumSteps = 360
    static let fragmentCount = 14
    private(set) var bodies: [BarrelFragmentBody]
    var settled: Bool { bodies.allSatisfy(\.sleeping) }

    init(barrel: CombatBarrel, explosion: Bool, impactFrom: CGPoint,
         allows: (CGPoint, Double) -> Bool) {
        // A stable cosmetic stream: Swift's randomized Hasher and combat RNG
        // must never influence the fragments or the next attack roll.
        var seed: UInt64 = explosion ? 0xcbf29ce484222325 : 0x84222325cbf29ce4
        for byte in barrel.id.utf8 { seed = (seed ^ UInt64(byte)) &* 0x100000001b3 }
        func random() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(UInt64.max >> 11)
        }
        let kinds: [BarrelFragmentPose.Kind] = [.stave, .stave, .stave, .stave, .stave, .stave,
            .splinter, .splinter, .splinter, .splinter, .lid, .lid, .hoop, .hoop]
        let dx = barrel.position.x - impactFrom.x, dy = (barrel.position.y - impactFrom.y) / 0.75
        let impactAngle = atan2(dy, dx)
        bodies = kinds.enumerated().map { index, kind in
            let radial = Double(index) * 2.399963 + random() * 0.35
            let angle = explosion ? radial : impactAngle + (random() - 0.5) * 2.6
            let speed = explosion ? 65 + random() * 80 : 22 + random() * 32
            let previous = barrel.debris?.indices.contains(index) == true ? barrel.debris![index] : nil
            let point = previous?.point ?? CGPoint(x: barrel.position.x + cos(radial) * 9,
                                                   y: barrel.position.y + sin(radial) * 9 * 0.75)
            var body = BarrelFragmentBody(pose: previous ?? .init(kind: kind, point: point,
                angle: radial, scale: 0.8 + random() * 0.3),
                height: barrel.isBroken ? 0 : (kind == .lid ? 43 : 12 + random() * 22),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                liftSpeed: explosion ? 125 + random() * 95 : 45 + random() * 50,
                spin: (random() - 0.5) * (explosion ? 18 : 10))
            if !allows(body.pose.point, body.radius) { body.pose.point = barrel.position }
            return body
        }
    }

    /// Semi-implicit Euler, fixed 120 Hz; restitution and friction dissipate
    /// energy. Substeps bound wall travel to three ground units to avoid tunneling.
    mutating func advance(allows: (CGPoint, Double) -> Bool) {
        let dt = Self.step
        for i in bodies.indices where !bodies[i].sleeping {
            var body = bodies[i]
            body.liftSpeed -= 520 * dt
            body.height += body.liftSpeed * dt
            if body.height <= 0 {
                body.height = 0
                if body.liftSpeed < -28 {
                    body.liftSpeed *= body.pose.kind == .hoop ? -0.38 : -0.27
                    body.bounces += 1
                    body.velocity.x *= 0.65; body.velocity.y *= 0.65; body.spin *= 0.65
                } else { body.liftSpeed = 0 }
            }
            let grounded = body.height == 0 && body.liftSpeed == 0
            let damping = exp(-(grounded ? 8.0 : 0.35) * dt)
            body.velocity.x *= damping; body.velocity.y *= damping
            body.spin *= exp(-(grounded ? 12.0 : 0.4) * dt)
            let divisions = max(1, Int(ceil(hypot(body.velocity.x, body.velocity.y) * dt / 3)))
            for _ in 0..<divisions {
                let h = dt / Double(divisions)
                let x = CGPoint(x: body.pose.point.x + body.velocity.x * h, y: body.pose.point.y)
                if allows(x, body.radius) { body.pose.point = x }
                else { body.velocity.x *= -0.32; body.spin *= -0.55; body.wallContacts += 1 }
                let y = CGPoint(x: body.pose.point.x, y: body.pose.point.y + body.velocity.y * h * 0.75)
                if allows(y, body.radius) { body.pose.point = y }
                else { body.velocity.y *= -0.32; body.spin *= -0.55; body.wallContacts += 1 }
            }
            body.pose.angle += body.spin * dt
            if grounded && hypot(body.velocity.x, body.velocity.y) < 3 && abs(body.spin) < 0.3 {
                body.sleeping = true; body.velocity = .zero; body.spin = 0
            }
            bodies[i] = body
        }
        // Small circular contact proxies let landed pieces nudge one another.
        // This is cosmetic only: no combat damage or actor forces originate here.
        for i in bodies.indices {
            for j in bodies.indices where j > i {
                guard bodies[i].height < 2, bodies[j].height < 2,
                      !bodies[i].sleeping || !bodies[j].sleeping else { continue }
                let dx = bodies[j].pose.point.x - bodies[i].pose.point.x
                let dy = (bodies[j].pose.point.y - bodies[i].pose.point.y) / 0.75
                let distance = hypot(dx, dy), reach = bodies[i].radius + bodies[j].radius
                guard distance < reach else { continue }
                let nx = distance > 0.001 ? dx / distance : 1
                let ny = distance > 0.001 ? dy / distance : 0
                let relative = (bodies[j].velocity.x - bodies[i].velocity.x) * nx
                    + (bodies[j].velocity.y - bodies[i].velocity.y) * ny
                let invA = 1 / bodies[i].mass, invB = 1 / bodies[j].mass
                if relative < 0 {
                    let impulse = -1.2 * relative / (invA + invB)
                    bodies[i].velocity.x -= impulse * invA * nx; bodies[i].velocity.y -= impulse * invA * ny
                    bodies[j].velocity.x += impulse * invB * nx; bodies[j].velocity.y += impulse * invB * ny
                    bodies[i].sleeping = false; bodies[j].sleeping = false
                }
                let correction = (reach - distance) * 0.5
                for (index, sign) in [(i, -1.0), (j, 1.0)] {
                    let point = CGPoint(x: bodies[index].pose.point.x + sign * nx * correction,
                        y: bodies[index].pose.point.y + sign * ny * correction * 0.75)
                    if allows(point, bodies[index].radius) { bodies[index].pose.point = point }
                }
            }
        }
    }
}

/// Simulate once at action acceptance, save settled poses, then present samples
/// on the paused combat clock. Reload uses the endpoint, never a second blast.
struct BarrelDestruction {
    let samples: [[BarrelFragmentBody]]
    var duration: TimeInterval { Double(samples.count - 1) * BarrelDebrisPhysics.step }
    var finalPoses: [BarrelFragmentPose] { samples.last!.map(\.pose) }
    init(barrel: CombatBarrel, explosion: Bool, impactFrom: CGPoint, searchMap: SearchMap) {
        let allows: (CGPoint, Double) -> Bool = { point, radius in
            Self.allows(point, radius: radius, in: searchMap)
        }
        var physics = BarrelDebrisPhysics(barrel: barrel, explosion: explosion, impactFrom: impactFrom, allows: allows)
        var result = [physics.bodies]
        for _ in 0..<BarrelDebrisPhysics.maximumSteps {
            physics.advance(allows: allows); result.append(physics.bodies)
            if physics.settled { break }
        }
        samples = result
    }
    func sample(at elapsed: TimeInterval) -> [BarrelFragmentBody] {
        // Multiplication/division can put duration one ULP below its last index.
        // Completion must always present the exact endpoint that was saved.
        if elapsed >= duration { return samples.last! }
        if !elapsed.isFinite || elapsed <= 0 { return samples[0] }
        return samples[min(samples.count - 1, Int(elapsed / BarrelDebrisPhysics.step))]
    }
    /// Conservative footprint against raster cells only. Terrain and closed
    /// doors block; actors are ignored, since fragments cannot injure or shove.
    static func allows(_ point: CGPoint, radius: Double, in map: SearchMap) -> Bool {
        let a = map.cell(for: CGPoint(x: point.x - radius, y: point.y - radius * 0.75))
        let b = map.cell(for: CGPoint(x: point.x + radius, y: point.y + radius * 0.75))
        for y in a.row...b.row {
            for x in a.column...b.column {
                if !map.isTerrainPassable(map.flags(at: SearchMapCell(column: x, row: y))) { return false }
            }
        }
        return true
    }
}
