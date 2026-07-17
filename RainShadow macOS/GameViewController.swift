//
//  GameViewController.swift
//  RainShadow macOS
//
//  Created by Laurens van Oorschot on 7/17/26.
//

import Cocoa
import SpriteKit

class GameViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let skView = self.view as! SKView
        GameBootstrap.start(in: skView)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.acceptsMouseMovedEvents = true
        view.window?.makeFirstResponder(view)
    }
}
