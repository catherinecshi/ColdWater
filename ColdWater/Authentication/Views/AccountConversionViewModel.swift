import Combine
import Foundation
import UIKit

/// View model for AccountConversionView
class AccountConversionViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var passwordConfirmation: String = ""
    @Published var passwordsMatch: Bool = true
    @Published var statusViewModel: AuthenticationStatus?
    @Published var isLoading: Bool = false
    
    private var cancellableBag = Set<AnyCancellable>()
    private let authManager: AuthenticationManager
    
    /// Initializes model with link to central authentication manager
    init(authManager: AuthenticationManager = .shared) {
        self.authManager = authManager
        setupValidation()
    }
    
    /// Checks if password and confirm password values match
    /// Take values from publishers and checks if they match
    private func setupValidation() {
        // Set up publisher to check if passwords match
        Publishers.CombineLatest($password, $passwordConfirmation)
            .map { password, confirmation in
                // If confirmation is empty, don't show mismatch yet
                if confirmation.isEmpty { return true }
                return password == confirmation
            }
            .assign(to: &$passwordsMatch)
    }
    
    /// Computed property to check if the form is valid
    var isFormValid: Bool {
        return !email.isEmpty &&
               !password.isEmpty &&
               passwordsMatch &&
               password.count >= 6
    }
    
    /// Initializes account conversion process with email/password credentials
    /// Prevents account from being created with certain errors
    /// - if any fields are empty
    /// - if password is less than 6 characters long
    /// - if user is somehow not anonymous
    func convertAccount() {
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
        
        // Check if the user is anonymous
        guard authManager.isAnonymous else {
            statusViewModel = AuthenticationStatus(title: "Error", message: "You're already signed in with an account")
            return
        }
        
        isLoading = true
        
        // Attempt to convert the anonymous account
        authManager.convertAnonymousUserWithEmail(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.statusViewModel = AuthenticationStatus(
                            title: "Account Creation Failed",
                            message: error.localizedDescription
                        )
                    }
                },
                receiveValue: { [weak self] user in
                    self?.isLoading = false
                    if user != nil {
                        self?.statusViewModel = AuthenticationStatus(
                            title: "Successful",
                            message: "Your account has been created successfully"
                        )
                    } else {
                        self?.statusViewModel = AuthenticationStatus(
                            title: "Error",
                            message: "Failed to create account"
                        )
                    }
                }
            )
            .store(in: &cancellableBag)
    }
    
    /// Converts user with google credentials
    /// Takes viewController - view controller the google sign in UI will appear upon
    func convertWithGoogle(presentingViewController: UIViewController) {
        // Check if the user is anonymous
        guard authManager.isAnonymous else {
            statusViewModel = AuthenticationStatus(title: "Error", message: "You're already signed in with an account")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let user = try await authManager.convertAnonymousUserWithGoogle(presentingViewController: presentingViewController)
                await MainActor.run { [weak self] in
                    self?.isLoading = false
                    self?.statusViewModel = AuthenticationStatus(
                        title: "Successful",
                        message: "Your account has been created successfully"
                    )
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isLoading = false
                    self?.statusViewModel = AuthenticationStatus(
                        title: "Google Sign-In Failed",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }
    
    /// Converts user with apple credentials
    /// Takes viewController - view controller the apple sign in UI will appear upon
    func convertWithApple(presentingViewController: UIViewController) {
        // check if user is anonymous
        guard authManager.isAnonymous else {
            statusViewModel = AuthenticationStatus(title: "Error", message: "You're already signed in with an account")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let user = try await authManager.convertAnonymousUserWithApple(presentingViewController: presentingViewController)
                await MainActor.run { [weak self] in
                    self?.isLoading = false
                    self?.statusViewModel = AuthenticationStatus(
                        title: "Successful",
                        message: "Your account has been created successfully"
                    )
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isLoading = false
                    self?.statusViewModel = AuthenticationStatus(
                        title: "Apple Sign-In Failed",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }
    
    /// Clear status message
    func clearStatus() {
        statusViewModel = nil
    }
}
