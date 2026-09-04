import Foundation

/// The Infinity Engine's 24-hour area clock.
///
/// Schedules on actors, ambients and animations are 24-bit masks evaluated
/// with a 30-minute offset (`HourSchedule.isActive(atSecondsAfterMidnight:)`).
/// RainShadow is night-pinned: the clock sits on a fixed night hour so night
/// content is active and day content stays inert until a later pass authors
/// a moving day/night cycle.
struct GameClock: Hashable, Codable, Sendable {
    /// Seconds since 00:00, wrapped to one day.
    var secondsAfterMidnight: Int

    /// 22:00. Bit 22 of the night mask is set (22:00 + 30 min → 22:30).
    static let pinnedNightHour = 22
    static let secondsPerDay = 24 * 60 * 60

    static let pinnedNight = GameClock(
        secondsAfterMidnight: pinnedNightHour * 3600
    )

    init(secondsAfterMidnight: Int) {
        let span = Self.secondsPerDay
        self.secondsAfterMidnight = ((secondsAfterMidnight % span) + span) % span
    }

    var hour: Int { secondsAfterMidnight / 3600 }

    func isActive(_ schedule: HourSchedule) -> Bool {
        schedule.isActive(atSecondsAfterMidnight: secondsAfterMidnight)
    }
}
