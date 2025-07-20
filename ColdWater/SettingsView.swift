import SwiftUI

/// SwiftUI View for Settings
/// Currently contains buttons for account state management
/// - Permanent Account: Sign out button
/// - Guest Account: Sign out button, Conversion button
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                if viewModel.shouldShowAnonymousButtons {
                    // Anonymous user buttons
                    VStack(spacing: 20) {
                        // Link Account button
                        Button(action: {
                            viewModel.linkAccountTapped()
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                }
                                Text("Link Account")
                                    .font(Font(UIConfiguration.buttonFont))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(UIConfiguration.tintColor))
                            .cornerRadius(8)
                        }
                        .disabled(viewModel.isLoading)
                        
                        // Log Into Another Account button
                        Button(action: {
                            viewModel.logIntoAnotherAccountTapped()
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                }
                                Text("Log Into Another Account")
                                    .font(Font(UIConfiguration.buttonFont))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(UIConfiguration.tintColor))
                            .cornerRadius(8)
                        }
                        .disabled(viewModel.isLoading)
                    }
                } else {
                    // Signed in user button
                    Button(action: {
                        viewModel.signOut()
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            Text("Sign Out")
                                .font(Font(UIConfiguration.buttonFont))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(UIConfiguration.tintColor))
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.isLoading)
                }
                
                // Delete Account button (always visible)
                Button(action: {
                    viewModel.deleteAccountTapped()
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        Text("Delete Account")
                            .font(Font(UIConfiguration.buttonFont))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.red)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isLoading)
                
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
        .sheet(isPresented: $viewModel.showingAccountConversion) {
            AccountConversionView { success in
                if success {
                    viewModel.handleAccountConversionSuccess()
                }
            }
        }
        .alert("Warning!", isPresented: $viewModel.showingSignOutAlert) {
            Button("Link Account", role: .none) {
                viewModel.linkAccountTapped()
            }
            Button("Log Out", role: .destructive) {
                viewModel.signOut()
            }
            Button("Cancel", role: .cancel) {
                viewModel.clearAlerts()
            }
        } message: {
            Text("You'll lose all of your progress with the anonymous account if you log out! You can keep the progress by linking it to an account")
        }
        .alert("Delete Account?", isPresented: $viewModel.showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                viewModel.deleteAccount()
            }
            Button("Cancel", role: .cancel) {
                viewModel.clearAlerts()
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showingErrorAlert) {
            Button("OK") {
                viewModel.clearAlerts()
            }
        } message: {
            Text(viewModel.alertMessage)
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showingSuccessAlert) {
            Button("OK") {
                viewModel.clearAlerts()
            }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

#Preview {
    SettingsView()
}
