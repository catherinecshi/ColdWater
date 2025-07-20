/// Stores reference to current user that is maintained through a session
import SwiftUI
import Combine

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var currentUser: CWUser?
}
