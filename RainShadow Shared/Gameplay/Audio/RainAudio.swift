import SpriteKit

@MainActor
enum RainAudio {
    private static let voiceOverNodeName = "audio.voiceOver"

    static func loopingAmbience(fileNamed fileName: String, volume: Float) -> SKAudioNode {
        let node = SKAudioNode(fileNamed: fileName)
        node.autoplayLooped = true
        node.isPositional = false
        node.run(.sequence([
            .changeVolume(to: 0, duration: 0),
            .wait(forDuration: 0.08),
            .changeVolume(to: volume, duration: 1.4)
        ]))
        return node
    }

    /// Plays a one-shot dialogue voice-over, stopping any prior VO on the same parent.
    ///
    /// `SKAudioNode` only autoplays when `autoplayLooped` is true. For a one-shot
    /// line we leave looping off and explicitly run `SKAction.play()` after attach.
    static func playVoiceOver(fileNamed fileName: String, volume: Float = 0.92, on parent: SKNode) {
        stopVoiceOver(on: parent)
        let node = SKAudioNode(fileNamed: fileName)
        node.name = voiceOverNodeName
        node.autoplayLooped = false
        node.isPositional = false
        parent.addChild(node)
        // Must play explicitly: autoplayLooped=false does not start on addChild.
        node.run(.group([
            .changeVolume(to: volume, duration: 0),
            .play()
        ]))
    }

    static func stopVoiceOver(on parent: SKNode) {
        if let existing = parent.childNode(withName: voiceOverNodeName) {
            existing.run(.stop())
            existing.removeFromParent()
        }
    }
}
