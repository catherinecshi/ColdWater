import Combine
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

/// Corresponding model for SignInView (SwiftUI)
class SignInViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var statusViewModel: AuthenticationStatus?
    @Published var state: any AppStateProtocol
    
    private var cancellableBag = Set<AnyCancellable>()
    private let authManager: AuthenticationServiceProtocol
    
    /// Initiates model with app state and authentication manager
    init(state: any AppStateProtocol, authManager: AuthenticationServiceProtocol = AuthenticationManager.shared) {
        self.state = state
        self.authManager = authManager
    }
    
    /// Initiates authentication process with email/password log-in
    /// Updates publisher with success or failure
    func login() {
        authManager.login(email: email, password: password)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.statusViewModel = AuthenticationStatus(
                        title: "Error",
                        message: error.localizedDescription
                    )
                }
            }, receiveValue: { [weak self] user in
                if let user = user {
                    self?.state.currentUser = user
                    self?.statusViewModel = AuthenticationStatus.logInSuccessStatus
                } else {
                    self?.statusViewModel = AuthenticationStatus.errorStatus
                }
            })
            .store(in: &cancellableBag)
    }
}
