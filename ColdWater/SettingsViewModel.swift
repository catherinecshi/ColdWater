import SwiftUI
import Combine
import FirebaseAuth

/// View model for SettingsView handling all business logic and state management
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var showingAccountConversion = false
    @Published var showingSignOutAlert = false
    @Published var showingDeleteAlert = false
    @Published var showingErrorAlert = false
    @Published var showingSuccessAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var isLoading = false
    
    // MARK: - Private Properties
    private var cancellableBag: Set<AnyCancellable> = []
    private let authManager: AuthenticationManager
    
    // MARK: - Computed Properties
    var isAnonymous: Bool {
        Auth.auth().currentUser?.isAnonymous ?? false
    }
    
    var shouldShowAnonymousButtons: Bool {
        isAnonymous
    }
    
    var shouldShowSignedInButton: Bool {
        !isAnonymous
    }
    
    // MARK: - Initialization
    init(authManager: AuthenticationManager = .shared) {
        self.authManager = authManager
    }
    
    // MARK: - Public Methods
    
    /// Handles the link account button tap
    func linkAccountTapped() {
        showingAccountConversion = true
    }
    
    /// Handles the log into another account button tap
    func logIntoAnotherAccountTapped() {
        showingSignOutAlert = true
    }
    
    /// Handles successful account conversion
    func handleAccountConversionSuccess() {
        alertTitle = "Account Linked"
        alertMessage = "Your progress has been saved to your new account!"
        showingSuccessAlert = true
    }
    
    /// Handles delete account button tap
    func deleteAccountTapped() {
        showingDeleteAlert = true
    }
    
    /// Signs the user out of Firebase and AppState
    func signOut(onSuccess: @escaping () -> Void) {
        isLoading = true
        
        authManager.signOut()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    switch completion {
                    case .failure(_):
                        self?.showError(title: "Sign Out Failed", message: "There was a problem signing out")
                    case .finished:
                        break
                    }
                },
                receiveValue: { _ in
                    onSuccess()
                }
            )
            .store(in: &cancellableBag)
    }
    
    /// Deletes the current user account
    func deleteAccount(onSuccess: @escaping () -> Void) {
        isLoading = true
        
        authManager.deleteCurrentAccount()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    switch completion {
                    case .failure(let error):
                        self?.showError(
                            title: "Account Deletion Failed",
                            message: "There was a problem deleting your account: \(error.localizedDescription)"
                        )
                    case .finished:
                        break
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.alertTitle = "Account Deleted"
                    self?.alertMessage = "Your account has been successfully deleted."
                    self?.showingSuccessAlert = true
                    
                    // Navigate to welcome after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onSuccess()
                    }
                }
            )
            .store(in: &cancellableBag)
    }
    
    /// Clears all alert states
    func clearAlerts() {
        showingErrorAlert = false
        showingSuccessAlert = false
        showingSignOutAlert = false
        showingDeleteAlert = false
        alertTitle = ""
        alertMessage = ""
    }
    
    // MARK: - Private Methods
    
    private func showError(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingErrorAlert = true
    }
}
