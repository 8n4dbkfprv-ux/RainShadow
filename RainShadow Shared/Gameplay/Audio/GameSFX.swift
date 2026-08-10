import AVFoundation
import SpriteKit

/// One-shot sound effects.
///
/// `RainAudio` covers the two cases that existed before this: a looping ambience
/// bed and a dialogue line. Neither shape fits a footstep — `SKAudioNode` is an
/// AVAudioEngine node, and attaching and tearing one down several times a second
/// is the wrong tool. These are short, frequent, and overlapping-by-accident, so
/// they get pooled `AVAudioPlayer`s instead.
///
/// Channels exist because BG separates them (`SFXChannel::WalkChar`,
/// `WalkMonster`, `Char0`) and because they mix differently: footsteps sit under
/// everything, a bark sits over it.
@MainActor
enum GameSFX {
    enum Channel {
        /// A party member's own footsteps.
        case walkPlayer
        /// Anyone else's.
        case walkOther
        /// Selection / order acknowledgements.
        case voice

        var volume: Float {
            switch self {
            case .walkPlayer: 0.42
            case .walkOther: 0.30
            case .voice: 0.85
            }
        }

        /// How many clips may sound at once on this channel. Footsteps are capped
        /// low so a crowd cannot stack into mush; a bark replaces its predecessor.
        var voices: Int {
            switch self {
            case .walkPlayer: 2
            case .walkOther: 3
            case .voice: 1
            }
        }
    }

    /// Cached decoders, keyed by resource name. A footstep is played hundreds of
    /// times a session and re-reading it off disk each time is pure waste.
    private static var pools: [String: [AVAudioPlayer]] = [:]
    private static var durations: [String: TimeInterval] = [:]

    /// Duration of a clip, which the footstep cadence needs *before* it decides to
    /// play: BG holds the next step off by exactly the length of the current one.
    /// Returns nil when the resource is missing, which is how a missing audio set
    /// stays silent instead of crashing.
    static func duration(of resource: String) -> TimeInterval? {
        if let cached = durations[resource] { return cached }
        guard let player = makePlayer(resource) else { return nil }
        pools[resource, default: []].append(player)
        durations[resource] = player.duration
        return player.duration
    }

    @discardableResult
    static func play(_ resource: String, on channel: Channel) -> TimeInterval? {
        guard let player = availablePlayer(resource, voices: channel.voices) else { return nil }
        player.volume = channel.volume
        player.currentTime = 0
        player.play()
        return player.duration
    }

    /// Drops every cached decoder. Scenes call this on teardown so a long session
    /// moving between districts does not accumulate players for clips it has
    /// stopped using.
    static func flush() {
        for player in pools.values.flatMap({ $0 }) {
            player.stop()
        }
        pools.removeAll()
        durations.removeAll()
    }

    // MARK: - Private

    private static func availablePlayer(_ resource: String, voices: Int) -> AVAudioPlayer? {
        var pool = pools[resource] ?? []
        if let idle = pool.first(where: { !$0.isPlaying }) {
            return idle
        }
        if pool.count < voices, let fresh = makePlayer(resource) {
            pool.append(fresh)
            pools[resource] = pool
            return fresh
        }
        // At the voice cap: steal the oldest rather than dropping the sound, so a
        // continuous walk never goes silent.
        guard !pool.isEmpty else { return nil }
        let stolen = pool.removeFirst()
        pool.append(stolen)
        pools[resource] = pool
        stolen.stop()
        return stolen
    }

    private static func makePlayer(_ resource: String) -> AVAudioPlayer? {
        let name = (resource as NSString).deletingPathExtension
        let ext = (resource as NSString).pathExtension
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: ext.isEmpty ? "m4a" : ext
        ) else {
            return nil
        }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }
}

/// The footstep set for a surface, and the surface an actor is standing on.
///
/// BG resolves this through the search map's *material* channel into
/// `terrain.2da` (`Map::ResolveTerrainSound`). BG:EE itself ships no
/// `terrain.2da` — that is IWD's system — but the distinction between an office
/// floorboard and a wet Harborpoint street is worth more here than strict parity,
/// so the seam is kept and each scene names its own surface.
enum FootstepSurface: String, CaseIterable, Sendable {
    case floorboard
    case wetStone

    var resourcePrefix: String {
        switch self {
        case .floorboard: "sfx_footstep_floorboard"
        case .wetStone: "sfx_footstep_wet_stone"
        }
    }

    /// Variant count baked by `ArtSource/Processing/generate_movement_sfx_v01.py`.
    static let variantCount = 4

    func resource(variant: Int) -> String {
        let index = (abs(variant) % Self.variantCount) + 1
        return String(format: "%@_%02d.m4a", resourcePrefix, index)
    }
}

/// Order acknowledgements and selection lines.
///
/// BG plays these through `Actor::CommandActor` and `Actor::PlaySelectionSound`,
/// gated by the frequency slider. `BarkGate` holds the ladder and the one
/// adaptation a single-detective game needs; this owns the clips and the rolls.
@MainActor
final class MovementBarkPlayer {
    enum Kind {
        case command
        case selection

        var commonResources: [String] {
            switch self {
            case .command:
                (1...4).map { String(format: "vo_voss_command_%02d.m4a", $0) }
            case .selection:
                (1...3).map { String(format: "vo_voss_selection_%02d.m4a", $0) }
            }
        }

        var rareResources: [String] {
            switch self {
            // BG:EE spends BG1's rare-select slots on extra command lines, so only
            // selection carries a rare variant here.
            case .command: []
            case .selection: ["vo_voss_selection_rare_01.m4a"]
            }
        }
    }

    private var commandGate: BarkGate
    private var selectionGate: BarkGate

    /// Defaults follow `Baldur.lua` where they can: commands at BG's shipped
    /// level, selections one step down from BG's because a lone actor is selected
    /// far more often than a party member is.
    init(
        commandFrequency: BarkFrequency = .half,
        selectionFrequency: BarkFrequency = .half
    ) {
        commandGate = BarkGate(frequency: commandFrequency)
        selectionGate = BarkGate(frequency: selectionFrequency)
    }

    /// Call when the actor is (re)acquired — portrait click, dialogue ending. This
    /// is the adaptation `BarkGate` documents: with one always-selected detective,
    /// "selection" has to mean something the player actually does.
    func noteActorSelected() {
        commandGate.noteSelected()
        selectionGate.noteSelected()
    }

    func play(_ kind: Kind, silenced: Bool = false) {
        guard !silenced else { return }
        let roll = Int.random(in: 1...100)
        let rareRoll = Int.random(in: 1...100)
        let outcome: BarkGate.Outcome
        switch kind {
        case .command: outcome = commandGate.resolve(roll: roll, rareRoll: rareRoll)
        case .selection: outcome = selectionGate.resolve(roll: roll, rareRoll: rareRoll)
        }

        let pool: [String]
        switch outcome {
        case .silent:
            return
        case .rare:
            pool = kind.rareResources.isEmpty ? kind.commonResources : kind.rareResources
        case .common:
            pool = kind.commonResources
        }
        guard let resource = pool.randomElement() else { return }
        GameSFX.play(resource, on: .voice)
    }
}
