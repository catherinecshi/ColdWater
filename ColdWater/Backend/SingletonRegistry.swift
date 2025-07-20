import UIKit

protocol Resettable {
    func reset()
}

/// This is for keeping track for all singletons, for functions such as logging out where singletons have to be deallocated
class SingletonRegistry {
    static let shared = SingletonRegistry()
    
    private var resettables: [Resettable] = []
    
    // register singleton that can be reset
    func register(_ resettable: Resettable) {
        resettables.append(resettable)
    }
    
    // reset all registered singletons
    func resetAll() {
        for resettable in resettables {
            resettable.reset()
        }
    }
}
