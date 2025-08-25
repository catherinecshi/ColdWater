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
            if #available(iOS 26.0, *) {
                TestContentView()
                    .environmentObject(appState)
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
            } else {
                RootView()
                    .environmentObject(appState)
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print("🔗 [DEEPLINK] Received URL: \(url)")
        print("🔗 [DEEPLINK] Full URL: \(url.absoluteString)")
        print("🔗 [DEEPLINK] Scheme: \(url.scheme ?? "nil")")
        print("🔗 [DEEPLINK] Host: \(url.host ?? "nil")")
        print("🔗 [DEEPLINK] Path: \(url.path)")
        print("🔗 [DEEPLINK] Path components: \(url.pathComponents)")
        
        guard url.scheme == "coldwater" else {
            print("🔗 [DEEPLINK] ❌ Unknown scheme: \(url.scheme ?? "nil")")
            return
        }
        
        if url.host == "alarm" {
            if let alarmID = url.pathComponents.last, alarmID != "/" {
                print("🔗 [DEEPLINK] ✅ Opening alarm: \(alarmID)")
                // Show an alert to confirm it worked
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        let alert = UIAlertController(title: "Dynamic Island Tap", 
                                                    message: "Successfully opened alarm: \\(alarmID)", 
                                                    preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        window.rootViewController?.present(alert, animated: true)
                    }
                }
            } else {
                print("🔗 [DEEPLINK] ❌ No alarm ID found in path")
            }
        } else {
            print("🔗 [DEEPLINK] ❌ Unknown host: \(url.host ?? "nil")")
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
