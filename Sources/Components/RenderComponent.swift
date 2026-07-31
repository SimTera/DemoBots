/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    A `GKComponent` that provides an `SKNode` for an entity. This enables it to be represented in the SpriteKit world.
*/

import SpriteKit
import GameplayKit

class RenderComponent: GKComponent {
    // MARK: Properties
    
    // The `RenderComponent` vends a node allowing an entity to be rendered in a scene.
    let node: SKNode

    // MARK: Initializers

    override nonisolated init() {
        node = MainActor.assumeIsolated { SKNode() }
        super.init()
    }

    required nonisolated init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: GKComponent
    
    nonisolated override func didAddToEntity() {
        node.entity = entity
    }
    
    nonisolated override func willRemoveFromEntity() {
        node.entity = nil
    }
}
