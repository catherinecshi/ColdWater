import SwiftUI

enum OnboardingStep: CaseIterable {
    case wakeUpTime
    case wakeUpMethod
    case stepsConfig
    case locationConfig
    case gracePeriod
    case motivationMethod
    case confirmation
}

class OnboardingCoordinator: ObservableObject {
    @Published var currentStep: OnboardingStep = .wakeUpTime
    @Published var preferences = UserPreferences()
    @Published var navigationPath = NavigationPath()
    
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    func nextStep() {
        switch currentStep {
        case .wakeUpTime:
            currentStep = .wakeUpMethod
            navigationPath.append(currentStep)
        case .wakeUpMethod:
            if preferences.wakeUpMethod == .steps {
                currentStep = .stepsConfig
            } else {
                currentStep = .locationConfig
            }
            navigationPath.append(currentStep)
        case .stepsConfig:
            currentStep = .gracePeriod
            navigationPath.append(currentStep)
        case .locationConfig:
            currentStep = .gracePeriod
            navigationPath.append(currentStep)
        case .gracePeriod:
            currentStep = .motivationMethod
            navigationPath.append(currentStep)
        case .motivationMethod:
            currentStep = .confirmation
            navigationPath.append(currentStep)
        case .confirmation:
            break
        }
    }
    
    func previousStep() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
            
            switch currentStep {
            case .wakeUpTime:
                break
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
        }
    }
    
    func canProceed() -> Bool {
        switch currentStep {
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
        appState.userPreferences = preferences
        appState.hasCompletedOnboarding = true
    }
}