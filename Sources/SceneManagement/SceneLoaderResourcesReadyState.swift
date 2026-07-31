/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    A state used by `SceneLoader` to indicate that all of the resources for the scene are loaded into memory and ready for use. This is the final state in the `SceneLoader`'s state machine.
*/

import GameplayKit

class SceneLoaderResourcesReadyState: GKState {
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
            print("✅ ENTER ResourcesReadyState")
            // Clear the `sceneLoader`'s progress as loading is complete.
            sceneLoader.progress = nil

            // Notify to any interested objects that the download has completed.
            NotificationCenter.default.post(name: NSNotification.Name.SceneLoaderDidCompleteNotification, object: sceneLoader)
        }
    }
    
    nonisolated override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        switch stateClass {
            case is SceneLoaderResourcesAvailableState.Type, is SceneLoaderInitialState.Type:
                return true
            
            default:
                return false
        }
    }

    nonisolated override func willExit(to nextState: GKState) {
        super.willExit(to: nextState)
        
        MainActor.assumeIsolated {
            /*
                Presenting the scene is a one shot operation. Clear the scene when
                exiting the ready state.
            */
            sceneLoader.scene = nil
        }
    }
}
