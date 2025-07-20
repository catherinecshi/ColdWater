import SwiftUI
import Combine
import FirebaseAuth

/// SwiftUI View for Settings
/// Currently contains buttons for account state management
/// - Permanent Account: Sign out button
/// - Guest Account: Sign out button, Conversion button
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // State for sheet presentations and alerts
    @State private var showingAccountConversion = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var cancellableBag: Set<AnyCancellable> = []
    
    // Computed property to check if user is anonymous
    private var isAnonymous: Bool {
        Auth.auth().currentUser?.isAnonymous ?? false
    }
    
    // Closure to handle navigation to welcome (passed from parent)
    let onNavigateToWelcome: () -> Void
    
    init(onNavigateToWelcome: @escaping () -> Void = {}) {
        self.onNavigateToWelcome = onNavigateToWelcome
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                if isAnonymous {
                    // Anonymous user buttons
                    VStack(spacing: 20) {
                        // Link Account button
                        Button(action: {
                            showingAccountConversion = true
                        }) {
                            Text("Link Account")
                                .font(Font(UIConfiguration.buttonFont))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(UIConfiguration.tintColor))
                                .cornerRadius(8)
                        }
                        
                        // Log Into Another Account button
                        Button(action: {
                            showingSignOutAlert = true
                        }) {
                            Text("Log Into Another Account")
                                .font(Font(UIConfiguration.buttonFont))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(UIConfiguration.tintColor))
                                .cornerRadius(8)
                        }
                    }
                } else {
                    // Signed in user button
                    Button(action: {
                        signOut()
                    }) {
                        Text("Sign Out")
                            .font(Font(UIConfiguration.buttonFont))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(UIConfiguration.tintColor))
                            .cornerRadius(8)
                    }
                }
                
                // Delete Account button (always visible)
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Text("Delete Account")
                        .font(Font(UIConfiguration.buttonFont))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAccountConversion) {
            AccountConversionView { success in
                if success {
                    alertTitle = "Account Linked"
                    alertMessage = "Your progress has been saved to your new account!"
                    showingSuccessAlert = true
                }
            }
        }
        .alert("Warning!", isPresented: $showingSignOutAlert) {
            Button("Link Account", role: .none) {
                showingAccountConversion = true
            }
            Button("Log Out", role: .destructive) {
                signOut()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You'll lose all of your progress with the anonymous account if you log out! You can keep the progress by linking it to an account")
        }
        .alert("Delete Account?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .alert(alertTitle, isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert(alertTitle, isPresented: $showingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Private Methods
    
    /// Signs the user out of Firebase and AppState
    /// Shows alert if failure
    private func signOut() {
        authManager.signOut()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [self] completion in
                    switch completion {
                    case .failure(_):
                        alertTitle = "Sign Out Failed"
                        alertMessage = "There was a problem signing out"
                        showingErrorAlert = true
                    case .finished:
                        break
                    }
                },
                receiveValue: { [self] _ in
                    onNavigateToWelcome()
                }
            )
            .store(in: &cancellableBag)
    }
    
    /// Deletes the current user account
    private func deleteAccount() {
        authManager.deleteCurrentAccount()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [self] completion in
                    switch completion {
                    case .failure(let error):
                        alertTitle = "Account Deletion Failed"
                        alertMessage = "There was a problem deleting your account: \(error.localizedDescription)"
                        showingErrorAlert = true
                    case .finished:
                        break
                    }
                },
                receiveValue: { [self] _ in
                    alertTitle = "Account Deleted"
                    alertMessage = "Your account has been successfully deleted."
                    showingSuccessAlert = true
                    
                    // Navigate to welcome after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onNavigateToWelcome()
                    }
                }
            )
            .store(in: &cancellableBag)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
