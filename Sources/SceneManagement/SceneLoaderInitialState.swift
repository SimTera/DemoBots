/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The initial state of a `SceneLoader`. Determines which state should be entered at the beginning of the scene loading process.
*/

import GameplayKit

class SceneLoaderInitialState: GKState {
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
        MainActor.assumeIsolated {
            #if os(iOS) || os(tvOS)
            // Move the `stateMachine` to the available state if no on-demand resources are required.
            if !sceneLoader.sceneMetadata.requiresOnDemandResources {
                stateMachine!.enter(SceneLoaderResourcesAvailableState.self)
            }
            #elseif os(OSX)
            // On OS X the resources will always be in local storage available for download.
            _ = stateMachine!.enter(SceneLoaderResourcesAvailableState.self)
            #endif
        }
    }
    
    nonisolated override func isValidNextState(_  stateClass: AnyClass) -> Bool {
        #if os(iOS) || os(tvOS)
        if stateClass is SceneLoaderDownloadingResourcesState.Type {
            return true
        }
        #endif
        
        return stateClass is SceneLoaderResourcesAvailableState.Type
    }
}
