import SwiftUI

struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var coordinator = OnboardingCoordinator()
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            WelcomeView(state: appState)
                .environmentObject(coordinator)
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .welcome:
                        WelcomeView(state: appState)
                            .environmentObject(coordinator)
                    case .intro:
                        IntroSlideShowView()
                            .environmentObject(coordinator)
                    case .wakeUpTime:
                        WakeUpTimeView()
                            .environmentObject(coordinator)
                    case .wakeUpMethod:
                        WakeUpMethodView()
                            .environmentObject(coordinator)
                    case .stepsConfig:
                        StepsConfigView()
                            .environmentObject(coordinator)
                    case .locationConfig:
                        LocationConfigView()
                            .environmentObject(coordinator)
                    case .gracePeriod:
                        GracePeriodView()
                            .environmentObject(coordinator)
                    case .motivationMethod:
                        MotivationMethodView()
                            .environmentObject(coordinator)
                    case .confirmation:
                        OnboardingConfirmationView()
                            .environmentObject(coordinator)
                    }
                }
                .navigationDestination(for: OnboardingNavigationDestination.self) { destination in
                    switch destination {
                    case .signIn:
                        SignInView(state: appState)
                    case .signUp:
                        SignUpView(state: appState)
                    }
                }
        }
        .onAppear {
            DispatchQueue.main.async {
                coordinator.setAppState(appState)
            }
        }
    }
}
