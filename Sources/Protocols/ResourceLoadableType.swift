/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    A protocol representing a type that loads resources into memory and keeps them around for future use. Classes adopt this protocol to indicate that they can preload SpriteKit textures and other resources in advance of when they will be needed, to improve performance when those resources are accessed.
*/

// [MIGRATION]: [CONCURRENCY] nonisolated para que los métodos estáticos
// puedan llamarse desde hilos de fondo (OperationQueue)
/// A type capable of loading and managing static resources.
protocol ResourceLoadableType: AnyObject {
    /// Indicates that static resources need to be loaded.
    nonisolated static var resourcesNeedLoading: Bool { get }
    
    /// Loads static resources into memory.
    nonisolated static func loadResources(withCompletionHandler completionHandler: @escaping () -> ())
    
    /// Releases any static resources that can be loaded again later.
    nonisolated static func purgeResources()
}
