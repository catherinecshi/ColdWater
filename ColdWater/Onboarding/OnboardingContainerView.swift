import SwiftUI

struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var coordinator: OnboardingCoordinator
    
    init() {
        let appStateInstance = AppState.shared
        self._coordinator = StateObject(wrappedValue: OnboardingCoordinator(appState: appStateInstance))
    }
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            WakeUpTimeView()
                .environmentObject(coordinator)
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
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
        }
    }
}