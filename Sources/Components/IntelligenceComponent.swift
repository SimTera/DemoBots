/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    A `GKComponent` that provides a `GKStateMachine` for entities to use in determining their actions.
*/

import SpriteKit
import GameplayKit

class IntelligenceComponent: GKComponent {
    
    // MARK: Properties
    
    let stateMachine: GKStateMachine
    
    let initialStateClass: AnyClass
    
    // MARK: Initializers
    
    @available(*, unavailable, message: "Use init(states:) instead.")
    override nonisolated init() {
        fatalError("init() must not be used. Use init(states:) instead.")
    }

    init(states: [GKState]) {
        stateMachine = GKStateMachine(states: states)
        let firstState = states.first!
        initialStateClass = type(of: firstState)
        super.init()
    }
    
    required nonisolated init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: GKComponent Life Cycle

    nonisolated override func update(deltaTime seconds: TimeInterval) {
        super.update(deltaTime: seconds)

        MainActor.assumeIsolated {
            stateMachine.update(deltaTime: seconds)
        }
    }
    
    // MARK: Actions
    
    func enterInitialState() {
        stateMachine.enter(initialStateClass)
    }
}
