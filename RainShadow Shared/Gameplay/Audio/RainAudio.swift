import SpriteKit

@MainActor
enum RainAudio {
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
}
