import SwiftUI
import AuthenticationServices

/// SwiftUI view for anonymous user trying to link a permanent account login type
/// Currently handles linking with email/password logintype, google sign in, and apple sign in
struct AccountConversionView: View {
    @StateObject private var viewModel = AccountConversionViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showAlert = false
    @State private var currentAlert: AuthenticationStatus?
    
    let onConversionComplete: (Bool) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Logo
                    Image("AppIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(Color(UIConfiguration.tintColor))
                        .padding(.top, 40)
                    
                    // Title and subtitle
                    VStack(spacing: 10) {
                        Text("Create Your Account")
                            .font(Font(UIConfiguration.titleFont))
                            .foregroundColor(Color(UIConfiguration.tintColor))
                        
                        Text("Save your progress")
                            .font(Font(UIConfiguration.subtitleFont))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    
                    // Email and password form
                    VStack(spacing: 15) {
                        // Email field
                        TextField("E-mail Address", text: $viewModel.email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                        
                        // Password field
                        SecureField("Password", text: $viewModel.password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.newPassword)
                        
                        // Confirm password field
                        SecureField("Confirm Password", text: $viewModel.passwordConfirmation)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.newPassword)
                        
                        // Password mismatch warning
                        if !viewModel.passwordsMatch && !viewModel.passwordConfirmation.isEmpty {
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        // Create account button
                        Button(action: {
                            viewModel.convertAccount()
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                }
                                Text("Create Account")
                                    .font(Font(UIConfiguration.buttonFont))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                Color(UIConfiguration.tintColor)
                                    .opacity(viewModel.isFormValid && !viewModel.isLoading ? 1.0 : 0.5)
                            )
                            .cornerRadius(8)
                        }
                        .disabled(!viewModel.isFormValid || viewModel.isLoading)
                    }
                    .padding(.horizontal, 20)
                    
                    // Social sign-in buttons
                    VStack(spacing: 10) {
                        // Google Sign In button
                        Button(action: {
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first,
                               let rootViewController = window.rootViewController {
                                viewModel.convertWithGoogle(presentingViewController: rootViewController)
                            }
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.black)
                                }
                                Text("Sign In with Google")
                                    .font(Font(UIConfiguration.buttonFont))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                            .cornerRadius(8)
                        }
                        .disabled(viewModel.isLoading)
                        
                        // Apple Sign In button
                        SignInWithAppleButton(.signIn) { request in
                            // Apple Sign In request configuration if needed
                        } onCompletion: { result in
                            // Handle the result through the view model
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first,
                               let rootViewController = window.rootViewController {
                                viewModel.convertWithApple(presentingViewController: rootViewController)
                            }
                        }
                        .frame(height: 50)
                        .cornerRadius(8)
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("")
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
        .onChange(of: viewModel.statusViewModel) { status in
            if let status = status {
                currentAlert = status
                showAlert = true
            }
        }
        .alert("", isPresented: $showAlert, presenting: currentAlert) { status in
            Button("OK") {
                if status.title == "Successful" {
                    onConversionComplete(true)
                    dismiss()
                }
                viewModel.clearStatus()
            }
        } message: { status in
            VStack {
                Text(status.title)
                    .font(.headline)
                Text(status.message)
            }
        }
    }
}

#Preview {
    AccountConversionView { success in
        print("Conversion completed: \(success)")
    }
}
