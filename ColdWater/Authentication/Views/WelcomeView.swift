import SwiftUI
import AuthenticationServices

/// SwiftUI Welcome Screen for unauthenticated users
struct WelcomeView: View {
    @StateObject private var viewModel: WelcomeViewModel
    
    init(state: AppState) {
        self._viewModel = StateObject(wrappedValue: WelcomeViewModel(state: state))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient matching HomeView style
                UIConfiguration.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    // Logo
                    Image("ColdWaterIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .foregroundColor(UIConfiguration.primaryColor)
                    
                    // Title
                    Text("Cold Water")
                        .font(UIConfiguration.swiftUITitleFont)
                        .foregroundColor(UIConfiguration.primaryColor)
                        .multilineTextAlignment(.center)
                    
                    // Subtitle
                    Text("The alarm that makes you get up")
                        .font(UIConfiguration.swiftUISubtitleFont)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, UIConfiguration.standardPadding)
                    
                    Spacer()
                    
                    // Authentication Buttons
                    VStack(spacing: UIConfiguration.smallPadding) {
                        // Email Sign In Button
                        NavigationLink(value: NavigationDestination.signIn) {
                            Text("Sign In with Email")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AuthButtonStyle.secondary)
                        
                        // Email Sign Up Button
                        NavigationLink(value: NavigationDestination.signUp) {
                            Text("Sign Up with Email")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AuthButtonStyle.primary)
                        
                        // Google Sign In Button
                        Button("Sign In with Google") {
                            viewModel.signInWithGoogle()
                        }
                        .buttonStyle(AuthButtonStyle.google)
                        .disabled(viewModel.isLoading)
                        
                        // Apple Sign In Button
                        CustomAppleSignInButton {
                            viewModel.signInWithApple()
                        }
                        .disabled(viewModel.isLoading)
                        
                        // Guest Button
                        Button("Continue as Guest") {
                            viewModel.continueAsGuest()
                        }
                        .buttonStyle(AuthButtonStyle.guest)
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.horizontal, UIConfiguration.standardPadding)
                    
                    Spacer()
                }
                
                // Loading Overlay
                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: UIConfiguration.primaryColor))
                        .scaleEffect(1.5)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .signIn:
                    SignInView(state: viewModel.state)
                case .signUp:
                    SignUpView(state: viewModel.state)
                }
            }
        }
        .alert(
            viewModel.statusViewModel?.title ?? "Error",
            isPresented: $viewModel.showingAlert
        ) {
            Button("OK") {
                viewModel.dismissAlert()
            }
        } message: {
            Text(viewModel.statusViewModel?.message ?? "An error occurred")
        }
        .onChange(of: viewModel.statusViewModel) { oldValue, newValue in
            if let status = newValue, status.title == "Successful" {
                // Navigate to main app - this should be handled by your app's root coordinator
                // You might want to set a state that your main app view observes
                print("Authentication successful - should navigate to main app")
            }
        }
    }
}

// MARK: - Navigation Destinations
enum NavigationDestination: Hashable {
    case signIn
    case signUp
}

// MARK: - Preview
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(state: AppState())
    }
}
