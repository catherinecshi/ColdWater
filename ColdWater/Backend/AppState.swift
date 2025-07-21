/// Stores reference to current user that is maintained through a session
import SwiftUI
import Combine

protocol AppStateProtocol: ObservableObject {
    var currentUser: CWUser? { get set }
    var currentUserPublisher: Published<CWUser?>.Publisher { get }
    var hasCompletedOnboarding: Bool { get set }
    var userPreferences: UserPreferences? { get set }
}

class AppState: AppStateProtocol {
    static let shared = AppState()
    
    @Published var currentUser: CWUser?
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @Published var userPreferences: UserPreferences?
    
    var currentUserPublisher: Published<CWUser?>.Publisher {
        $currentUser
    }
}
