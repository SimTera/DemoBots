/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    An `SKScene` used to represent and manage the home and end scenes of the game.
*/

import SpriteKit
import GameplayKit

class HomeEndScene: BaseScene {
    // MARK: Properties
    
    /// Returns the background node from the scene.
    override var backgroundNode: SKSpriteNode? {
        return childNode(withName: "backgroundNode") as? SKSpriteNode
    }
    
    /// The screen recorder button for the scene (if it has one).
    var screenRecorderButton: ButtonNode? {
        return backgroundNode?.childNode(withName: ButtonIdentifier.screenRecorderToggle.rawValue) as? ButtonNode
    }
    
    /// The "NEW GAME" button which allows the player to proceed to the first level.
    var proceedButton: ButtonNode? {
        return backgroundNode?.childNode(withName: ButtonIdentifier.proceedToNextScene.rawValue) as? ButtonNode
    }

    /// An array of objects for `SceneLoader` notifications.
    private var sceneLoaderNotificationObservers = [Any]()

    // MARK: Deinitialization
    
    isolated deinit {
        // Deregister for scene loader notifications.
        for observer in sceneLoaderNotificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: Scene Life Cycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        #if os(iOS)
        screenRecorderButton?.isSelected = screenRecordingToggleEnabled
        #else
        screenRecorderButton?.isHidden = true
        #endif
        
        // Enable focus based navigation. 
        focusChangesEnabled = true
        
        registerForNotifications()
        centerCameraOnPoint(point: backgroundNode!.position)
        
        // Begin loading the first level as soon as the view appears (so it's faster when tapped).
        sceneManager.prepareScene(identifier: .level(1))
        
        /*
            [MODIFICADO EN LA MIGRACIÓN]

            El diseño original de DemoBots OCULTA los botones (alpha 0) hasta que
            el Level 1 termina de PRECARGAR sus recursos, y luego los revela con un
            fade-in cuando llega `SceneLoaderDidCompleteNotification`.

            Ese Level 1 usa On-Demand Resources (ODR: tags Level1/GroundBot/Blue).
            En el simulador, sin ODR configurado, esa precarga no completa de forma
            fiable → la notificación no llega → los botones se quedaban invisibles y
            solo se veía el título.

            Para que la Home sea siempre usable, dejamos los botones VISIBLES desde
            el arranque. El nivel se cargará al pulsar "NEW GAME" (`transitionToScene`),
            mostrando una escena de progreso si hace falta.

            TODO: recuperar el comportamiento original de "precargar y revelar" cuando
            se migre ODR a Apple-Hosted Background Assets (ver SceneLoaderDownloadingResourcesState).
        */
        proceedButton?.alpha = 1.0
        proceedButton?.isUserInteractionEnabled = true

        screenRecorderButton?.alpha = 1.0
        screenRecorderButton?.isUserInteractionEnabled = true

        // Código original (revelar tras la precarga), conservado como referencia:
        // if !(levelLoader.stateMachine.currentState is SceneLoaderResourcesReadyState) {
        //     proceedButton?.alpha = 0.0
        //     proceedButton?.isUserInteractionEnabled = false
        //     screenRecorderButton?.alpha = 0.0
        //     screenRecorderButton?.isUserInteractionEnabled = false
        // }
    }
    
    func registerForNotifications() {
        // Only register for notifications if we haven't done so already.
        guard sceneLoaderNotificationObservers.isEmpty else { return }
        
        // Create a closure to pass as a notification handler for when loading completes or fails.
        let handleSceneLoaderNotification: (Notification) -> () = { [unowned self] notification in
            let sceneLoader = notification.object as! SceneLoader
            
            // Show the proceed button if the `sceneLoader` pertains to a `LevelScene`.
            if sceneLoader.sceneMetadata.sceneType is LevelScene.Type {
                // Allow the proceed and screen to be tapped or clicked.
                self.proceedButton?.isUserInteractionEnabled = true
                self.screenRecorderButton?.isUserInteractionEnabled = true

                // Fade in the proceed and screen recorder buttons.
                self.screenRecorderButton?.run(SKAction.fadeIn(withDuration: 1.0))

                // Clear the initial `proceedButton` focus.
                self.proceedButton?.isFocused = false
                self.proceedButton?.run(SKAction.fadeIn(withDuration: 1.0)) {
                    // Indicate that the `proceedButton` is focused.
                    self.resetFocus()
                }
            }
        }
        
        // Register for scene loader notifications.
        let completeNotification = NotificationCenter.default.addObserver(forName: NSNotification.Name.SceneLoaderDidCompleteNotification, object: nil, queue: OperationQueue.main, using: handleSceneLoaderNotification)
        let failNotification = NotificationCenter.default.addObserver(forName: NSNotification.Name.SceneLoaderDidFailNotification, object: nil, queue: OperationQueue.main, using: handleSceneLoaderNotification)
        
        // Keep track of the notifications we are registered to so we can remove them in `deinit`.
        sceneLoaderNotificationObservers += [completeNotification, failNotification]
    }
}
