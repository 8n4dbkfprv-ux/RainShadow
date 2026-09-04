import CoreGraphics
import Foundation

/// Pure playback math for ARE-style ambients: radius attenuation, interval
/// jitter, and pool selection. The scene layer owns nodes and audio files.
enum AreaAmbientPlayback {
    /// Linear falloff to silence at `radius`. A missing point or radius is a
    /// global bed and always plays at authored volume.
    static func gain(ambient: AreaAmbient, listener: CGPoint) -> CGFloat {
        guard !ambient.isGlobal, let point = ambient.point, let radius = ambient.radius, radius > 0 else {
            return 1
        }
        let dx = listener.x - point.x
        let dy = listener.y - point.y
        let distance = hypot(dx, dy)
        if distance >= radius { return 0 }
        return max(0, 1 - distance / radius)
    }

    static func volume(ambient: AreaAmbient, listener: CGPoint, clock: GameClock) -> CGFloat {
        guard clock.isActive(ambient.schedule) else { return 0 }
        return ambient.volume * gain(ambient: ambient, listener: listener)
    }

    /// Seconds until the next one-shot. Looping beds do not use this.
    static func nextDelay(ambient: AreaAmbient, roll: CGFloat) -> TimeInterval {
        let base = TimeInterval(ambient.interval ?? 8)
        let deviation = TimeInterval(ambient.intervalDeviation ?? 0)
        let unit = min(max(roll, 0), 1)
        return max(0.05, base + (unit * 2 - 1) * deviation)
    }

    static func pickSound(
        ambient: AreaAmbient,
        sequenceIndex: Int,
        roll: CGFloat
    ) -> (name: String, nextIndex: Int) {
        let pool = ambient.soundPool
        guard !pool.isEmpty else { return (ambient.assetName, 0) }
        switch ambient.selection {
        case .sequential:
            let index = sequenceIndex % pool.count
            return (pool[index], index + 1)
        case .random:
            let unit = min(max(roll, 0), 0.999_999)
            let index = min(pool.count - 1, Int(unit * CGFloat(pool.count)))
            return (pool[index], sequenceIndex)
        }
    }
}
