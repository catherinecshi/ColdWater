import SwiftUI
import Combine

/// SwiftUI view for email/password sign in screen
struct SignInView: View {
    @StateObject private var viewModel: SignInViewModel
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    /// Initializes view with application state
    /// Takes AppState, which contains information about currentUser
    init(state: any AppStateProtocol) {
        self._viewModel = StateObject(wrappedValue: SignInViewModel(state: state))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Sign In")
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
            
            // Login Button
            Button(action: {
                viewModel.login()
            }) {
                Text("Log In")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIConfiguration.tintColor))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(viewModel.$statusViewModel) { status in
            guard let status = status else { return }
            
            if status.title == "Successful" {
                print("✅ Sign in successful - RootView will automatically transition to HomeView")
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
}
