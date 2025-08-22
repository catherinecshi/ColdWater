import SwiftUI
import Combine

enum OnboardingStep: CaseIterable {
    case welcome
    case intro
    case wakeUpTime
    case wakeUpMethod
    case stepsConfig
    case locationConfig
    case gracePeriod
    case motivationMethod
    case confirmation
}

enum OnboardingNavigationDestination: Hashable {
    case signIn
    case signUp
}

class OnboardingCoordinator: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var preferences = UserPreferences()
    @Published var navigationPath = NavigationPath()
    
    private var appState: AppState?
    private let authManager: any AuthenticationServiceProtocol
    
    var isUserAuthenticated: Bool {
        return authManager.isUserAuthenticated
    }
    
    init(authManager: any AuthenticationServiceProtocol = AuthenticationManager.shared) {
        self.authManager = authManager
    }
    
    func setAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    func nextStep() {
        let oldStep = currentStep
        
        switch currentStep {
        case .welcome:
            currentStep = .intro
        case .intro:
            currentStep = .wakeUpTime
        case .wakeUpTime:
            currentStep = .wakeUpMethod
        case .wakeUpMethod:
            if preferences.wakeUpMethod == .steps {
                currentStep = .stepsConfig
            } else {
                currentStep = .locationConfig
            }
        case .stepsConfig:
            currentStep = .gracePeriod
        case .locationConfig:
            currentStep = .gracePeriod
        case .gracePeriod:
            currentStep = .motivationMethod
        case .motivationMethod:
            currentStep = .confirmation
        case .confirmation:
            return
        }
        
        // Rebuild navigation path from intro to current step
        rebuildNavigationPath()
    }
    
    private func rebuildNavigationPath() {
        navigationPath = NavigationPath()
        
        // Only add steps that should be in the navigation stack
        // The root view (welcome) is shown by default, so we build path from intro onward
        if currentStep == .welcome {
            // No navigation needed, we're at the root
            return
        }
        
        // Build the path step by step to reach current step
        var steps: [OnboardingStep] = []
        
        // Always go through these steps in order
        if currentStep != .welcome {
            steps.append(.intro)
        }
        if ![.welcome, .intro].contains(currentStep) {
            steps.append(.wakeUpTime)
        }
        if ![.welcome, .intro, .wakeUpTime].contains(currentStep) {
            steps.append(.wakeUpMethod)
        }
        if ![.welcome, .intro, .wakeUpTime, .wakeUpMethod].contains(currentStep) {
            // Add either steps or location config based on preference
            if preferences.wakeUpMethod == .steps {
                steps.append(.stepsConfig)
            } else {
                steps.append(.locationConfig)
            }
        }
        if ![.welcome, .intro, .wakeUpTime, .wakeUpMethod, .stepsConfig, .locationConfig].contains(currentStep) {
            steps.append(.gracePeriod)
        }
        if ![.welcome, .intro, .wakeUpTime, .wakeUpMethod, .stepsConfig, .locationConfig, .gracePeriod].contains(currentStep) {
            steps.append(.motivationMethod)
        }
        if currentStep == .confirmation {
            steps.append(.confirmation)
        }
        
        for step in steps {
            navigationPath.append(step)
        }
    }
    
    func previousStep() {
        let oldStep = currentStep
        
        switch currentStep {
        case .welcome:
            break // Can't go back from welcome
        case .intro:
            currentStep = .welcome
        case .wakeUpTime:
            currentStep = .intro
        case .wakeUpMethod:
            currentStep = .wakeUpTime
        case .stepsConfig:
            currentStep = .wakeUpMethod
        case .locationConfig:
            currentStep = .wakeUpMethod
        case .gracePeriod:
            currentStep = preferences.wakeUpMethod == .steps ? .stepsConfig : .locationConfig
        case .motivationMethod:
            currentStep = .gracePeriod
        case .confirmation:
            currentStep = .motivationMethod
        }
        
        // Rebuild navigation path to match new current step
        rebuildNavigationPath()
    }
    
    func canProceed() -> Bool {
        switch currentStep {
        case .welcome:
            return true
        case .intro:
            return true
        case .wakeUpTime:
            return preferences.hasAnyWakeUpTime()
        case .wakeUpMethod:
            return preferences.wakeUpMethod != nil
        case .stepsConfig:
            return preferences.stepGoal != nil
        case .locationConfig:
            return preferences.location != nil
        case .gracePeriod:
            return preferences.gracePeriod != nil
        case .motivationMethod:
            return preferences.motivationMethod != nil
        case .confirmation:
            return true
        }
    }
    
    func completeOnboarding() {
        guard let appState = appState else {
            print("OnboardingCoordinator: AppState not set!")
            return
        }
        appState.userPreferences = preferences
        appState.hasCompletedOnboarding = true
        print("OnboardingCoordinator: hasCompletedOnboarding set to \(appState.hasCompletedOnboarding)")
    }
    
    func shouldShowAuthenticationFlow() -> Bool {
        return !isUserAuthenticated
    }
    
    func navigateToSignIn() {
        navigationPath.append(OnboardingNavigationDestination.signIn)
    }
    
    func navigateToSignUp() {
        navigationPath.append(OnboardingNavigationDestination.signUp)
    }
}
