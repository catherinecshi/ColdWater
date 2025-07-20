import SwiftUI
import Combine
import AuthenticationServices

/// View model for WelcomeView (SwiftUI)
class WelcomeViewModel: ObservableObject {
    @Published var state: AppState
    @Published var statusViewModel: AuthenticationStatus?
    @Published var isLoading: Bool = false
    @Published var showingAlert: Bool = false
    
    private var cancellableBag = Set<AnyCancellable>()
    private let authManager: AuthenticationManager
    
    /// Initializes with app state and authentication manager
    init(state: AppState, authManager: AuthenticationManager = .shared) {
        self.state = state
        self.authManager = authManager
        
        // Observe loading state from auth manager
        authManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellableBag)
    }
    
    /// Anonymous authentication for guest log-in
    /// Updates publisher with success or failure
    func continueAsGuest() {
        authManager.signInAnonymously()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleAuthError(
                            title: "Guest Sign-In Failed",
                            message: error.localizedDescription
                        )
                    }
                },
                receiveValue: { [weak self] user in
                    if let user = user {
                        self?.state.currentUser = user
                        self?.statusViewModel = AuthenticationStatus.logInSuccessStatus
                    } else {
                        self?.handleAuthError(
                            title: "Error",
                            message: "Failed to sign in as guest"
                        )
                    }
                }
            )
            .store(in: &cancellableBag)
    }
    
    /// Initiates Google Sign-In authentication flow
    func signInWithGoogle() {
        // Get the root view controller for presentation
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            handleAuthError(title: "Error", message: "Unable to present sign-in")
            return
        }
        
        let presentingViewController = rootViewController.presentedViewController ?? rootViewController
        
        authManager.googleSignIn(presentingViewController: presentingViewController)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleAuthError(
                        title: "Google Sign-In Failed",
                        message: error.localizedDescription
                    )
                }
            }, receiveValue: { [weak self] user in
                if let user = user {
                    self?.state.currentUser = user
                    self?.statusViewModel = AuthenticationStatus.logInSuccessStatus
                } else {
                    self?.handleAuthError(
                        title: "Error",
                        message: "Google sign-in failed"
                    )
                }
            })
            .store(in: &cancellableBag)
    }
    
    /// Initiates Apple Sign-In authentication flow
    func signInWithApple() {
        // Get the root view controller for presentation
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            handleAuthError(title: "Error", message: "Unable to present sign-in")
            return
        }
        
        let presentingViewController = rootViewController.presentedViewController ?? rootViewController
        
        authManager.appleSignIn(presentingViewController: presentingViewController)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleAuthError(
                        title: "Apple Sign-In Failed",
                        message: error.localizedDescription
                    )
                }
            }, receiveValue: { [weak self] user in
                if let user = user {
                    self?.state.currentUser = user
                    self?.statusViewModel = AuthenticationStatus.logInSuccessStatus
                } else {
                    self?.handleAuthError(
                        title: "Error",
                        message: "Apple sign-in failed"
                    )
                }
            })
            .store(in: &cancellableBag)
    }
    
    /// Helper method to handle authentication errors
    private func handleAuthError(title: String, message: String) {
        statusViewModel = AuthenticationStatus(title: title, message: message)
        showingAlert = true
    }
    
    /// Dismiss the current alert
    func dismissAlert() {
        showingAlert = false
        statusViewModel = nil
    }
}
