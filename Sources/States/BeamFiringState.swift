/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The state representing the `PlayerBot`'s beam when it is being fired at a `TaskBot`.
*/

import SpriteKit
import GameplayKit

class BeamFiringState: GKState {
    // MARK: Properties
    
    unowned var beamComponent: BeamComponent

    /// The `TaskBot` currently being targeted by the beam.
    var target: TaskBot?
    
    /// The amount of time the beam has been in its "firing" state.
    var elapsedTime: TimeInterval = 0.0

    /// The `PlayerBot` associated with the `BeamComponent`'s `entity`.
    
    var playerBot: PlayerBot {
        guard let playerBot = beamComponent.entity as? PlayerBot else { fatalError("A BeamFiringState's beamComponent must be associated with a PlayerBot.") }
        return playerBot
    }
    
    /// The `RenderComponent` associated with the `BeamComponent`'s `entity`.
   
    var renderComponent: RenderComponent {
        guard let renderComponent = beamComponent.entity?.component(ofType: RenderComponent.self) else { fatalError("A BeamFiringState's entity must have a RenderComponent.") }
        return renderComponent
    }

    // MARK: Initializers
    @available(*, unavailable, message: "Use init(beamComponent:) instead.")
    override nonisolated init() {
            fatalError("init() no debe ser usado. Usa init(beamComponent:) en su lugar.")
        }
    
    nonisolated init(beamComponent: BeamComponent) {
        self.beamComponent = beamComponent
        super.init()
    }
    
    // MARK: GKState life cycle
    
    nonisolated override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        
        MainActor.assumeIsolated {
            
            // Reset the "amount of time firing" tracker when we enter the "firing" state.
            elapsedTime = 0.0
            
            // Add the `BeamNode` to the scene if it hasn't already been added.
            
            if beamComponent.beamNode.parent == nil {
                // `playerBot` is a computed property. Declare a local version so we don't compute it multiple times.
                let playerBot = self.playerBot
                
                /*
                 The `BeamComponent`'s `BeamNode` is added to the scene at the `.AboveCharacter` level.
                 This ensures it appears above the `PlayerBot` and all `TaskBot`s in the scene.
                 */
                guard let scene = renderComponent.node.scene as? LevelScene else { fatalError("The RenderComponent's node must be in a scene.") }
                
                /*
                 Subtract 1 from the beam node's `zPosition` to make sure the beam appears above all
                 characters, but below other elements added to the `AboveCharacters` node.
                 */
                beamComponent.beamNode.zPosition = -1.0
                
                let aboveCharactersNode = scene.worldLayerNodes[.aboveCharacters]!
                aboveCharactersNode.addChild(beamComponent.beamNode)
                
                // Constrain the `BeamNode` to the antenna position on the `PlayerBot`'s node.
                let xRange = SKRange(constantValue: playerBot.antennaOffset.x)
                let yRange = SKRange(constantValue: playerBot.antennaOffset.y)
                
                let constraint = SKConstraint.positionX(xRange, y: yRange)
                constraint.referenceNode = renderComponent.node
                
                beamComponent.beamNode.constraints = [constraint]
            }
            
            
            updateBeamNode(withDeltaTime: 0.0)
        }
    }
    
    nonisolated override func update(deltaTime seconds: TimeInterval) {
        MainActor.assumeIsolated {
        super.update(deltaTime: seconds)
        
        // Update the "amount of time firing" tracker.
        elapsedTime += seconds

        if elapsedTime >= GameplayConfiguration.Beam.maximumFireDuration {
            /**
                The player has been firing the beam for too long. Enter the `BeamCoolingState`
                to disable firing until the beam has had time to cool down.
            */
            stateMachine?.enter(BeamCoolingState.self)
        }
        else if !beamComponent.isTriggered {
            // The beam is no longer being fired. Enter the `BeamIdleState`.
            stateMachine?.enter(BeamIdleState.self)
        }
        else {
            
                updateBeamNode(withDeltaTime: seconds)
            }
        }
    }
    
    nonisolated override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        switch stateClass {
            case is BeamIdleState.Type, is BeamCoolingState.Type:
                return true
                
            default:
                return false
        }
    }
    
    nonisolated override func willExit(to nextState: GKState) { //Esto es un parche pq se tendria que refactorizar el Beam en general a un enum
        let shouldShowIdle = nextState is BeamIdleState
        let shouldShowCooling = nextState is BeamCoolingState
        super.willExit(to: nextState)
        
        MainActor.assumeIsolated {
            
            // Clear the current target.
            target = nil
            
            // Update the beam component with the next state.
            if shouldShowIdle {
                beamComponent.beamNode.update(
                    withBeamState: BeamIdleState(beamComponent: beamComponent),
                    source: beamComponent.playerBot
                )
            } else if shouldShowCooling {
                beamComponent.beamNode.update(
                    withBeamState: BeamCoolingState(beamComponent: beamComponent),
                    source: beamComponent.playerBot
                )
            }
            //            beamComponent.beamNode.update(withBeamState: nextState, source: beamComponent.playerBot)
        }
    }
    
    // MARK: Convenience
    @MainActor
    func updateBeamNode(withDeltaTime seconds: TimeInterval) {
        // Find an appropriate target for the beam.
        target = beamComponent.findTargetInBeamArc(withCurrentTarget: target)
        
        // If the beam has a target with a charge component, drain charge from it.
        if let chargeComponent = target?.component(ofType: ChargeComponent.self) {
            let chargeToLose = GameplayConfiguration.Beam.chargeLossPerSecond * seconds
            chargeComponent.loseCharge(chargeToLose: chargeToLose)
        }
        
        // Update the appearance, position, size and orientation of the `BeamNode`.
        beamComponent.beamNode.update(withBeamState: self, source: playerBot, target: target)
        
        // If the current target has been turned good, deactivate the beam and move to the idle state.
        if let currentTarget = target, currentTarget.isGood {
            beamComponent.isTriggered = false
            stateMachine?.enter(BeamIdleState.self)
        }
    }
    
}
