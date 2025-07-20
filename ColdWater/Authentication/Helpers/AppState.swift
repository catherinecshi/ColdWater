/// Stores reference to current user that is maintained through a session
import SwiftUI
import Combine

protocol AppStateProtocol: ObservableObject {
    var currentUser: CWUser? { get set }
    var currentUserPublisher: Published<CWUser?>.Publisher { get }
}

class AppState: AppStateProtocol {
    static let shared = AppState()
    
    @Published var currentUser: CWUser?
    
    var currentUserPublisher: Published<CWUser?>.Publisher {
        $currentUser
    }
}
