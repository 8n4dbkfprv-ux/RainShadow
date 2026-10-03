//
//  GameScene.swift
//  RainShadow Shared
//
//  The stock SpriteKit scene has been replaced by the programmatic bootstrap in
//  App/GameBootstrap.swift. This file stays in the project temporarily so the
//  synchronized Xcode target migration remains incremental and reversible.
//

import SpriteKit

@MainActor
final class GameScene: SKScene {
    static func newGameScene() -> GameScene {
        let scene = GameScene(size: CGSize(width: 1_920, height: 1_080))
        scene.scaleMode = .aspectFill
        scene.backgroundColor = .black
        let label = SKLabelNode(text: "RainShadow")
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 72
        label.position = CGPoint(x: 960, y: 520)
        scene.addChild(label)
        return scene
    }
}
