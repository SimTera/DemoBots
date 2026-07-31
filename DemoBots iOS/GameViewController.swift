//
//  GameViewController.swift
//  DemoBots iOS
//
//  Created by Victor Munera on 24/4/26.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController, SceneManagerDelegate {
    // MARK: Properties

    /// A manager for coordinating scene resources and presentation.
    var sceneManager: SceneManager!

    /// The `GameInput` that provides the player's control input for the game.
    var gameInput: GameInput!

    // MARK: View Life Cycle

    override func loadView() {
        // Provide an `SKView` as this view controller's view (created programmatically, no storyboard).
        self.view = SKView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let skView = self.view as! SKView
        skView.ignoresSiblingOrder = true

        /*
            On iOS the native control input source is an on-screen `TouchControlInputNode`
            with two virtual thumbsticks and a pause area.
        */
        let controlLength = min(
            GameplayConfiguration.TouchControl.minimumControlSize,
            skView.bounds.size.width * GameplayConfiguration.TouchControl.idealRelativeControlSize
        )
        let touchControlInputSize = CGSize(width: controlLength, height: controlLength)
        let touchControlInputNode = TouchControlInputNode(frame: skView.bounds, thumbStickNodeSize: touchControlInputSize)

        // Wire up the game input using the touch control node as the native input source.
        gameInput = GameInput(nativeControlInputSource: touchControlInputNode)

        // Create the scene manager and transition to the home scene to start the game.
        sceneManager = SceneManager(presentingView: skView, gameInput: gameInput)
        sceneManager.delegate = self

        sceneManager.transitionToScene(identifier: .home)
    }

    // MARK: SceneManagerDelegate

    func sceneManager(_ sceneManager: SceneManager, didTransitionTo scene: SKScene) {
        // No additional work is required when a scene is presented.
    }

    // MARK: UIViewController

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
