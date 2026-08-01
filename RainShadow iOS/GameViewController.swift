//
//  GameViewController.swift
//  RainShadow iOS
//
//  Created by Laurens van Oorschot on 7/17/26.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let skView = self.view as! SKView
        GameBootstrap.start(in: skView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let skView = view as? SKView, let scene = skView.scene as? BaseGameScene else { return }
        scene.syncSizeFromViewIfNeeded()
        scene.layoutViewport()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
