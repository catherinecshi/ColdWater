import Combine
import Foundation

/// Corresponding model for SignUpViewController
class SignUpViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var passwordConfirmation: String = ""
    @Published var statusViewModel: AuthenticationStatus?
    @Published var state: AppState
    
    @Published private(set) var passwordsMatch: Bool = true
    
    private var cancellableBag = Set<AnyCancellable>()
    private let authManager: AuthenticationManager
    
    /// Initiates model with app state and authentication manager
    init(state: AppState, authManager: AuthenticationManager = .shared) {
        self.state = state
        self.authManager = authManager
        setupValidation()
    }
    
    /// Checks if password and confirm password values match
    /// Take values from publishers in view controller and checks if they match
    private func setupValidation() {
        // Monitor both password fields for real-time validation
        Publishers.CombineLatest($password, $passwordConfirmation)
            .map { password, confirmation in
                // Only validate when user has entered something in confirmation field
                return password == confirmation || confirmation.isEmpty
            }
            .assign(to: \.passwordsMatch, on: self)
            .store(in: &cancellableBag)
    }
    
    /// Initiates authentication process with email/password sign up
    /// Checks if the password and confirm password values match
    /// Other basic checks like
    /// - non-empty text fields
    /// - password being over 6 characters
    /// Updates publisher with success or failure
    func signUp() {
        print("📱 ViewModel: Attempting sign up with email: \(email)")
        
        // Basic validation
        guard !email.isEmpty else {
            statusViewModel = AuthenticationStatus(title: "Error", message: "Please enter your email address")
            return
        }
        
        guard !password.isEmpty else {
            statusViewModel = AuthenticationStatus(title: "Error", message: "Please enter a password")
            return
        }
        
        guard passwordsMatch else {
            statusViewModel = AuthenticationStatus(title: "Error", message: "Passwords do not match")
            return
        }
        
        guard password.count >= 6 else {
            statusViewModel = AuthenticationStatus(title: "Error", message: "Password must be at least 6 characters")
            return
        }
        
        print("📱 ViewModel: Validation passed, calling authManager.signUp")
        authManager.signUp(email: email, password: password)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    print("❌ ViewModel: Received error completion: \(error.localizedDescription)")
                    self?.statusViewModel = AuthenticationStatus(
                        title: "Error",
                        message: error.localizedDescription
                    )
                } else {
                    print("✅ ViewModel: Sign up operation completed successfully")
                }
            }, receiveValue: { [weak self] user in
                if let user = user {
                    print("✅ ViewModel: Received user after sign up: \(user.id), email: \(user.email ?? "no email")")
                    self?.state.currentUser = user
                    self?.statusViewModel = AuthenticationStatus.signUpSuccessStatus
                } else {
                    print("❌ ViewModel: Received nil user")
                    self?.statusViewModel = AuthenticationStatus.errorStatus
                }
            })
            .store(in: &cancellableBag)
    }
}
