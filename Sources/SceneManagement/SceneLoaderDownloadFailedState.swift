/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    A state used by `SceneLoader` to indicate that the downloading of on demand resources failed.
*/

import GameplayKit

class SceneLoaderDownloadFailedState: GKState {
    // MARK: Properties
    
    unowned let sceneLoader: SceneLoader
    
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
            // Clear the `sceneLoader`'s progress.
            sceneLoader.progress = nil
            
            // Notify any interested objects that the download has failed.
            NotificationCenter.default.post(name: NSNotification.Name.SceneLoaderDidFailNotification, object: sceneLoader)
        }
    }
    
    nonisolated override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is SceneLoaderDownloadingResourcesState.Type
    }
}
