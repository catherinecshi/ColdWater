import SwiftUI
import Combine
import AuthenticationServices

class OnboardingAuthViewModel: ObservableObject {
    @Published var statusViewModel: AuthenticationStatus?
    @Published var isLoading: Bool = false
    @Published var showingAlert: Bool = false
    
    private var cancellableBag = Set<AnyCancellable>()
    private let authManager: any AuthenticationServiceProtocol
    
    init(authManager: any AuthenticationServiceProtocol = AuthenticationManager.shared) {
        self.authManager = authManager
        
        authManager.isLoadingPublisher
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
            }
            .store(in: &cancellableBag)
    }
    
    func continueAsGuest(completion: @escaping (CWUser?) -> Void) {
        authManager.signInAnonymously()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completionResult in
                    if case .failure(let error) = completionResult {
                        self?.handleAuthError(
                            title: "Guest Sign-In Failed",
                            message: error.localizedDescription
                        )
                        completion(nil)
                    }
                },
                receiveValue: { [weak self] user in
                    if let user = user {
                        self?.statusViewModel = AuthenticationStatus.logInSuccessStatus
                        completion(user)
                    } else {
                        self?.handleAuthError(
                            title: "Error",
                            message: "Failed to sign in as guest"
                        )
                        completion(nil)
                    }
                }
            )
            .store(in: &cancellableBag)
    }
    
    func signInWithGoogle(completion: @escaping (CWUser?) -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            handleAuthError(title: "Error", message: "Unable to present sign-in")
            completion(nil)
            return
        }
        
        let presentingViewController = rootViewController.presentedViewController ?? rootViewController
        
        authManager.googleSignIn(presentingViewController: presentingViewController)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completionResult in
                if case .failure(let error) = completionResult {
                    self?.handleAuthError(
                        title: "Google Sign-In Failed",
                        message: error.localizedDescription
                    )
                    completion(nil)
                }
            }, receiveValue: { [weak self] user in
                if let user = user {
                    self?.statusViewModel = AuthenticationStatus.logInSuccessStatus
                    completion(user)
                } else {
                    self?.handleAuthError(
                        title: "Error",
                        message: "Google sign-in failed"
                    )
                    completion(nil)
                }
            })
            .store(in: &cancellableBag)
    }
    
    func signInWithApple(completion: @escaping (CWUser?) -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            handleAuthError(title: "Error", message: "Unable to present sign-in")
            completion(nil)
            return
        }
        
        let presentingViewController = rootViewController.presentedViewController ?? rootViewController
        
        authManager.appleSignIn(presentingViewController: presentingViewController)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completionResult in
                if case .failure(let error) = completionResult {
                    self?.handleAuthError(
                        title: "Apple Sign-In Failed",
                        message: error.localizedDescription
                    )
                    completion(nil)
                }
            }, receiveValue: { [weak self] user in
                if let user = user {
                    self?.statusViewModel = AuthenticationStatus.logInSuccessStatus
                    completion(user)
                } else {
                    self?.handleAuthError(
                        title: "Error",
                        message: "Apple sign-in failed"
                    )
                    completion(nil)
                }
            })
            .store(in: &cancellableBag)
    }
    
    private func handleAuthError(title: String, message: String) {
        statusViewModel = AuthenticationStatus(title: title, message: message)
        showingAlert = true
    }
    
    func dismissAlert() {
        showingAlert = false
        statusViewModel = nil
    }
}