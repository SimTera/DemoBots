/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    A subclass of `Operation` that manages the loading of a `BaseScene`.
            
*/

import Foundation
import SpriteKit

//class LoadSceneOperation: SceneOperation, ProgressReporting, @unchecked Sendable {
//    // MARK: Properties
//    
//    /// The metadata for the scene to load.
//    let sceneMetadata: SceneMetadata
//    
//    /// The scene this operation is responsible for loading. Set after completion.
//    var scene: BaseScene?
//    
//    /// Progress used to report on the status of this operation.
//    let progress: Progress
//    
//    // MARK: Initialization
//    
//    init(sceneMetadata: SceneMetadata) {
//        self.sceneMetadata = sceneMetadata
//        
//        progress = Progress(totalUnitCount: 1)
//        super.init()
//    }
//    
//    // MARK: NSOperation
//    
//    override func start() {
//        // If the operation is cancelled there's nothing to do.
//        guard !isCancelled else { return }
//        
//        if progress.isCancelled {
//            // Ensure the operation is marked as `cancelled`.
//            cancel()
//            return
//        }
//        
//        // Mark the operation as executing.
//        state = .executing
//        
//        /*
//            SpriteKit scenes must be created and configured on the main thread.
//            This operation runs on a background queue, so hop synchronously to
//            the main actor to load the scene and set up its camera.
//        */
//        let loadedScene = DispatchQueue.main.sync {
//            MainActor.assumeIsolated { () -> BaseScene in
//                // Load the scene into memory using `SKNode(fileNamed:)`.
//                let scene = sceneMetadata.sceneType.init(fileNamed: sceneMetadata.fileName)!
//
//                /*
//                    [AÑADIDO EN LA MIGRACIÓN] Ajuste de escala de la escena.
//
//                    El `GameViewController` de la plantilla de Xcode fijaba el
//                    `scaleMode` antes de presentar; al sustituirlo por el `SceneManager`
//                    real esa línea se perdió y la escena salía a tamaño nativo.
//
//                    Usamos `.resizeFill`: la escena adopta el tamaño real de la vista,
//                    así `size` en `BaseScene.updateCameraScale()` refleja el dispositivo
//                    concreto. El encaje "que se vea todo" lo hace la cámara con
//                    aspect-fit (ver `updateCameraScale`), de modo que en cualquier
//                    iPhone/iPad se vea toda el área de diseño con márgenes si sobra.
//
//                    TODO: valorar mover esto a `SceneManager.presentScene` o al `.sks`.
//                */
//                scene.scaleMode = .resizeFill
//
//                // Set up the scene's camera and native size.
//                scene.createCamera()
//
//                return scene
//            }
//        }
//        self.scene = loadedScene
//        
//        // Update the progress object's completed unit count.
//        progress.completedUnitCount = 1
//        
//        state = .finished
//    }
//}


class LoadSceneOperation: SceneOperation, ProgressReporting, @unchecked Sendable {
    // MARK: Properties
    
    /// The metadata for the scene to load.
    let sceneMetadata: SceneMetadata
    
    /// The scene this operation is responsible for loading. Set after completion.
    var scene: BaseScene?
    
    /// Progress used to report on the status of this operation.
    let progress: Progress
    
    // MARK: Initialization
    
    init(sceneMetadata: SceneMetadata) {
        self.sceneMetadata = sceneMetadata
        self.progress = Progress(totalUnitCount: 1)
        super.init()
    }
    
    // MARK: NSOperation
    
    override nonisolated func start() {
        print("🎬 LoadSceneOperation START:", sceneMetadata.fileName)
        
        // If the operation is cancelled there's nothing to do.
        guard !isCancelled else {
            print("⚠️ LoadSceneOperation CANCELLED BEFORE START:", sceneMetadata.fileName)
            finish()
            return
        }
        
        if progress.isCancelled {
            print("⚠️ LoadSceneOperation PROGRESS CANCELLED:", sceneMetadata.fileName)
            cancel()
            finish()
            return
        }
        
        // Mark the operation as executing.
        state = .executing
        
        /*
            SpriteKit scenes must be created and configured on the main thread.
            This operation itself runs on an OperationQueue, so we hop synchronously
            to the main queue to keep the Operation lifecycle ordered.
        */
        let loadedScene: BaseScene? = {
            if Thread.isMainThread {
                return MainActor.assumeIsolated {
                    loadSceneOnMainActor()
                }
            } else {
                return DispatchQueue.main.sync {
                    MainActor.assumeIsolated {
                        loadSceneOnMainActor()
                    }
                }
            }
        }()
        
        guard let loadedScene else {
            print("❌ LoadSceneOperation FAILED TO LOAD:", sceneMetadata.fileName)
            finish()
            return
        }
        
        self.scene = loadedScene
        
        print("✅ LoadSceneOperation LOADED:", sceneMetadata.fileName)
        
        finish()
    }
    
    @MainActor
    private func loadSceneOnMainActor() -> BaseScene? {
        // Load the scene into memory using `SKNode(fileNamed:)`.
        guard let scene = sceneMetadata.sceneType.init(fileNamed: sceneMetadata.fileName) else {
            return nil
        }
        
        /*
            [AÑADIDO EN LA MIGRACIÓN] Ajuste de escala de la escena.

            Usamos `.resizeFill`: la escena adopta el tamaño real de la vista,
            así `size` en `BaseScene.updateCameraScale()` refleja el dispositivo
            concreto. El encaje "que se vea todo" lo hace la cámara con aspect-fit.
        */
        scene.scaleMode = .resizeFill
        
        // Set up the scene's camera and native size.
        scene.createCamera()
        
        return scene
    }
    
    nonisolated func finish() {
        print("✅ LoadSceneOperation FINISH:", sceneMetadata.fileName)
        progress.completedUnitCount = 1
        state = .finished
    }
}
