import SwiftUI
import AuthenticationServices

/// SwiftUI Welcome Screen for unauthenticated users
struct WelcomeView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    let state: AppState
    
    init(state: AppState) {
        self.state = state
    }
    
    var body: some View {
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
                    Text("The alarm that forces you to get up")
                        .font(UIConfiguration.swiftUISubtitleFont)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, UIConfiguration.standardPadding)
                    
                    Spacer()
                    
                    // Onboarding Button
                    Button("See how it works") {
                        coordinator.nextStep()
                    }
                    .buttonStyle(AuthButtonStyle.primary)
                    .padding(.horizontal, UIConfiguration.standardPadding)
                    
                    Spacer()
                }
            }
    }
}


// MARK: - Preview
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(state: AppState())
            .environmentObject(OnboardingCoordinator())
    }
}
