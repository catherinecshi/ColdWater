import SwiftUI
import Combine

/// SwiftUI view for email/password sign up screen
struct SignUpView: View {
    @StateObject private var viewModel: SignUpViewModel
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    /// Initializes view with application state
    /// Takes AppState, which contains information about currentUser
    init(state: AppState) {
        self._viewModel = StateObject(wrappedValue: SignUpViewModel(state: state))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Sign Up")
                .font(Font(UIConfiguration.titleFont))
                .foregroundColor(Color(UIConfiguration.tintColor))
                .multilineTextAlignment(.center)
            
            // Email TextField
            TextField("E-mail Address", text: $viewModel.email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            // Password TextField
            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.password)
            
            // Confirm Password TextField
            SecureField("Confirm Password", text: $viewModel.passwordConfirmation)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.newPassword)
            
            // Password Mismatch Label
            if !viewModel.passwordsMatch && !viewModel.passwordConfirmation.isEmpty {
                Text("Passwords do not match")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            // Sign Up Button
            Button(action: {
                viewModel.signUp()
            }) {
                Text("Create Account")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        Color(UIConfiguration.tintColor)
                            .opacity(buttonOpacity)
                    )
                    .cornerRadius(8)
            }
            .disabled(!isSignUpButtonEnabled)
        }
        .padding(.horizontal, 20)
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(viewModel.$statusViewModel) { status in
            guard let status = status else { return }
            
            if status.title == "Successful" {
                print("✅ Sign up successful - RootView will automatically transition to HomeView")
                // No manual navigation needed - RootView handles this automatically
            } else {
                alertTitle = status.title
                alertMessage = status.message
                showingAlert = true
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Determines if the sign up button should be enabled
    private var isSignUpButtonEnabled: Bool {
        return viewModel.passwordsMatch || viewModel.passwordConfirmation.isEmpty
    }
    
    /// Determines the opacity of the sign up button
    private var buttonOpacity: Double {
        return isSignUpButtonEnabled ? 1.0 : 0.5
    }
}
