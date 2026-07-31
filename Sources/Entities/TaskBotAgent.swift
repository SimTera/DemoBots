/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    A simple subclass of `GKAgent2D` used by `TaskBot`s.
*/

import GameplayKit

class TaskBotAgent: GKAgent2D {
    override nonisolated init() {
        super.init()
    }

    required nonisolated init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
