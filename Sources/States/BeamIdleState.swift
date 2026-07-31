/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The state of the `PlayerBot`'s beam when not in use.
*/

import SpriteKit
import GameplayKit

class BeamIdleState: GKState {
    // MARK: Properties
    
    unowned var beamComponent: BeamComponent
    
    // MARK: Initializers
    
    @available(*, unavailable, message: "Use init(beamComponent:) instead.") //Se añade esto aqui para que no busque el init por defecto
        override nonisolated init() {
            fatalError("init() must not be used. Use init(beamComponent:) instead.")
        }
    nonisolated required init(beamComponent: BeamComponent) {
        self.beamComponent = beamComponent
        super.init()
    }
    
    // MARK: GKState life cycle
    
    nonisolated override func update(deltaTime seconds: TimeInterval) {
        MainActor.assumeIsolated {
            super.update(deltaTime: seconds)
            
            // If the beam has been triggered, enter `BeamFiringState`.
            if beamComponent.isTriggered {
                stateMachine?.enter(BeamFiringState.self)
            }
        }
    }
    
    nonisolated override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is BeamFiringState.Type
    }
}
