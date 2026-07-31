/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    A state used by `SceneLoader` to indicate that the loader is currently downloading on demand resources.
*/
// MARK: Downloading Actions

// TODO: [BackgroundAssets] Migrar de NSBundleResourceRequest (ODR) a BackgroundAssets
// framework (WWDC 2025). Requiere:
//   1. Añadir un target BAAppExtension al proyecto.
//   2. Declarar los tags/level assets en el BAManifest.
//   3. Sustituir esta clase por un observador de BADownloadManager.
// Ref: developer.apple.com/documentation/backgroundassets

import GameplayKit

class SceneLoaderDownloadingResourcesState: GKState {
    // MARK: Properties
    
    unowned let sceneLoader: SceneLoader
    
    /// Optionally progress directly to preparing state when download completes.
    var enterPreparingStateWhenFinished = false
    
    // MARK: Initialization
    @available(*, unavailable, message: "Use init(sceneLoader:) instead.")
    override nonisolated init() {
        fatalError("init() must not be used. Use init(sceneLoader:) instead.")
    }
    
    nonisolated init(sceneLoader: SceneLoader) {
        self.sceneLoader = sceneLoader
        super.init()
    }
    
    // MARK: GKState Life Cycle
    
    nonisolated override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        
        MainActor.assumeIsolated {
            print("➡️ ENTER DownloadingResourcesState")
            // Clear any previous errors, and begin downloading the scene's resources.
            sceneLoader.error = nil
            beginDownloadingScene()
        }
    }
    
    nonisolated override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        switch stateClass {
            case is SceneLoaderDownloadFailedState.Type, is SceneLoaderResourcesAvailableState.Type, is SceneLoaderPreparingResourcesState.Type:
                return true
                
            default:
                return false
        }
    }
    
    // MARK: Downloading Actions
// esto lo modernizamos, pero esta API queda deprecada en breve y se tendra que cambiar el proyecto un poco para meterlo en Apple-Hosted Background Assets presentado en 2025.
    
    /// Downloads the scene into local storage.
    private func beginDownloadingScene() {
        print("⬇️ beginDownloadingScene")
        /*
         Create a new bundle request every time downloading needs to begin
         because `NSBundleResourceRequest`s are single use objects.
         */
        let request = NSBundleResourceRequest(tags: sceneLoader.sceneMetadata.onDemandResourcesTags)
        
        // Hold onto the new resource request.
        sceneLoader.bundleResourceRequest = request
        
        // Begin downloading the on demand resources.
        Task { @MainActor in
            do {
                // Begin downloading the on demand resources.
                try await request.beginAccessingResources()
                
                if self.enterPreparingStateWhenFinished {
                    // If requested, proceed to the preparing state immediately.
                    self.stateMachine!.enter(SceneLoaderPreparingResourcesState.self)
                } else {
                    self.stateMachine!.enter(SceneLoaderResourcesAvailableState.self)
                }
            } catch {
                // Release the resources because we'll need to start a new request.
                request.endAccessingResources()
                
                // Set the error on the sceneLoader.
                self.sceneLoader.error = error
                
                self.stateMachine!.enter(SceneLoaderDownloadFailedState.self)
            }
        }        
    }
}


//        bundleResourceRequest.beginAccessingResources { error in
//
//            // Progress to the next appropriate state from the main queue.
//            DispatchQueue.main.async {
//                if let error = error {
//                    // Release the resources because we'll need to start a new request.
//                    bundleResourceRequest.endAccessingResources()
//
//                    // Set the error on the sceneLoader.
//                    self.sceneLoader.error = error
//
//                    self.stateMachine!.enter(SceneLoaderDownloadFailedState.self)
//                }
//                else if self.enterPreparingStateWhenFinished {
//                    // If requested, proceed to the preparing state immediately.
//                    self.stateMachine!.enter(SceneLoaderPreparingResourcesState.self)
//                }
//                else {
//                    self.stateMachine!.enter(SceneLoaderResourcesAvailableState.self)
//                }
//            }
//        }
