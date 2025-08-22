import SwiftUI
import FirebaseCore
import GoogleSignIn
import Combine

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct ColdWaterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

/// Root view that handles authentication state and navigation
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var authManager = AuthenticationManager.shared
    
    var body: some View {
        Group {
            if authManager.isUserAuthenticated && appState.hasCompletedOnboarding {
                HomeView()
                    .environmentObject(appState)
            } else {
                OnboardingContainerView()
                    .environmentObject(appState)
            }
        }
        .onReceive(authManager.$currentUser) { user in
            // Update app state when authentication changes
            appState.currentUser = user
        }
        .onAppear {
            // Initialize app state with current user if already logged in
            appState.currentUser = authManager.currentUser
            
            // Sign out authenticated users who haven't completed onboarding - this shouldn't be possible
            if authManager.isUserAuthenticated && !appState.hasCompletedOnboarding {
                _ = authManager.signOut()
            }
        }
    }
}
