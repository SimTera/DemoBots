/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
A subclass of `NSOperation` that maps the different states of an `NSOperation`
        to an explicit `state` enum.
*/

//import Foundation
//
//nonisolated class SceneOperation: Operation, @unchecked Sendable {
//    // MARK: Types
//    
//    /**
//        Using the `@objc` prefix exposes this enum to the ObjC runtime,
//        allowing the use of `dynamic` on the `state` property.
//    */
//    @objc enum State: Int {
//        /// The `Operation` is ready to begin execution.
//        case ready
//        
//        /// The `Operation` is executing.
//        case executing
//        
//        /// The `Operation` has finished executing.
//        case finished
//        
//        /// The `Operation` has been cancelled.
//        case cancelled
//    }
//    
//    // MARK: Properties
//    
//    /// Marking `state` as dynamic allows this property to be key-value observed.
//    dynamic var state = State.ready
//    
//    // MARK: NSOperation
//    
//    override var isExecuting: Bool {
//        return state == .executing
//    }
//    
//    override var isFinished: Bool {
//        return state == .finished
//    }
//    
//    override var isCancelled: Bool {
//        return state == .cancelled
//    }
//    
//    /**
//        Add the "state" key to the key value observable properties of `NSOperation`.
//    */
//    class func keyPathsForValuesAffectingIsReady() -> Set<String> {
//        return ["state"]
//    }
//    
//    class func keyPathsForValuesAffectingIsExecuting() -> Set<String> {
//        return ["state"]
//    }
//    
//    class func keyPathsForValuesAffectingIsFinished() -> Set<String> {
//        return ["state"]
//    }
//    
//    class func keyPathsForValuesAffectingIsCancelled() -> Set<String> {
//        return ["state"]
//    }
//}


import Foundation

nonisolated class SceneOperation: Operation, @unchecked Sendable {
    // MARK: Types
    
    enum State {
        case ready
        case executing
        case finished
        case cancelled
        
        var keyPath: String {
            switch self {
                case .ready:
                    return "isReady"
                    
                case .executing:
                    return "isExecuting"
                    
                case .finished:
                    return "isFinished"
                    
                case .cancelled:
                    return "isCancelled"
            }
        }
    }
    
    // MARK: Properties
    
    private let lock = NSLock()
    
    private var _state: State = .ready
    
    var state: State {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _state
        }
        
        set {
            let oldState = state
            
            willChangeValue(forKey: oldState.keyPath)
            willChangeValue(forKey: newValue.keyPath)
            
            lock.lock()
            _state = newValue
            lock.unlock()
            
            didChangeValue(forKey: oldState.keyPath)
            didChangeValue(forKey: newValue.keyPath)
        }
    }
    
    // MARK: Operation State
    
    override var isReady: Bool {
        return super.isReady && state == .ready
    }
    
    override var isExecuting: Bool {
        return state == .executing
    }
    
    override var isFinished: Bool {
        return state == .finished
    }
    
    override var isCancelled: Bool {
        return state == .cancelled || super.isCancelled
    }
    
    override var isAsynchronous: Bool {
        return true
    }
    
    // MARK: Cancellation
    
    override func cancel() {
        super.cancel()
        
        if state != .finished {
            state = .cancelled
        }
    }
}
