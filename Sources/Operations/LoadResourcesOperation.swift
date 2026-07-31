/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    A subclass of `Operation` that manages the loading of a `ResourceLoadableType`'s resources.
            
*/
import Foundation

class LoadResourcesOperation: SceneOperation, ProgressReporting, @unchecked Sendable {
    // MARK: Properties
    
    /// A class that conforms to the `ResourceLoadableType` protocol.
    let loadableType: ResourceLoadableType.Type
    
    let progress: Progress
    
    // MARK: Initialization
    
    init(loadableType: ResourceLoadableType.Type) {
        self.loadableType = loadableType
        
        progress = Progress(totalUnitCount: 1)
        super.init()
    }
    
    // MARK: NSOperation
    
    override  func start() {
        // If the operation is cancelled there's nothing to do.
        print("🚀 LoadResourcesOperation START:", loadableType)
        
            guard !isCancelled else {
                print("⚠️ LoadResourcesOperation CANCELLED BEFORE START:", loadableType)
                finish()
                return }
            if progress.isCancelled {
                print("⚠️ LoadResourcesOperation PROGRESS CANCELLED:", loadableType)
                // Ensure the operation is marked as `cancelled`.
                cancel()
                finish()
                return
            }
            
            // Avoid reloading the resources if they are already available.
            guard loadableType.resourcesNeedLoading else {
                print("✅ LoadResourcesOperation NO NEED TO LOAD:", loadableType)
                finish()
                return
            }
            
            // Mark the operation as executing.
            state = .executing
        print("📦 LoadResourcesOperation LOADING:", loadableType)
            // Begin loading the resources.
            loadableType.loadResources() { [unowned self] in
                print("✅ LoadResourcesOperation FINISH:", self.loadableType)
                // Mark the operation as complete once the resources are loaded.
                self.finish()
            }
        
    }
    
    func finish() {
        print("✅ LoadResourcesOperation FINISH:", loadableType)
        progress.completedUnitCount = 1
        state = .finished
    }
}
