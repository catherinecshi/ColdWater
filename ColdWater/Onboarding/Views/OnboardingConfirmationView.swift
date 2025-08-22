import SwiftUI
import AuthenticationServices

struct OnboardingConfirmationView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @EnvironmentObject var appState: AppState
    @StateObject private var authViewModel = OnboardingAuthViewModel()
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private func gracePeriodText() -> String {
        guard let gracePeriod = coordinator.preferences.gracePeriod else { return "Not set" }
        let minutes = Int(gracePeriod / 60)
        return minutes == 0 ? "No grace period" : "\(minutes) minutes"
    }
    
    private func wakeUpTimeText() -> String {
        let preferences = coordinator.preferences
        
        // Check if everyday time is set
        if let everydayTime = preferences.everydayTime {
            return timeFormatter.string(from: everydayTime)
        }
        
        // Check if weekdays/weekends times are set
        if let weekdaysTime = preferences.weekdaysTime, let weekendsTime = preferences.weekendsTime {
            return "Weekdays: \(timeFormatter.string(from: weekdaysTime)), Weekends: \(timeFormatter.string(from: weekendsTime))"
        } else if let weekdaysTime = preferences.weekdaysTime {
            return "Weekdays: \(timeFormatter.string(from: weekdaysTime))"
        } else if let weekendsTime = preferences.weekendsTime {
            return "Weekends: \(timeFormatter.string(from: weekendsTime))"
        }
        
        // Check individual day settings
        if !preferences.wakeUpTimes.isEmpty {
            let sortedDays = preferences.wakeUpTimes.keys.sorted { day1, day2 in
                let weekdayOrder: [Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
                return weekdayOrder.firstIndex(of: day1)! < weekdayOrder.firstIndex(of: day2)!
            }
            
            let dayTimeStrings = sortedDays.map { day in
                let time = preferences.wakeUpTimes[day]!
                return "\(day.shortName): \(timeFormatter.string(from: time))"
            }
            
            return dayTimeStrings.joined(separator: ", ")
        }
        
        return "Not set"
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Review your alarm")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Settings summary
                        settingsSummaryView
                        
                        Spacer()
                        
                        // Authentication section
                        Text("Save your preferences by logging in")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 16) {
                            // Authentication Buttons
                            VStack(spacing: UIConfiguration.smallPadding) {
                                // Email Sign In Button
                                Button("Sign In with Email") {
                                    coordinator.navigateToSignIn()
                                }
                                .buttonStyle(AuthButtonStyle.secondary)
                                .frame(maxWidth: .infinity)
                                
                                // Email Sign Up Button
                                Button("Sign Up with Email") {
                                    coordinator.navigateToSignUp()
                                }
                                .buttonStyle(AuthButtonStyle.primary)
                                .frame(maxWidth: .infinity)
                                
                                // Google Sign In Button
                                Button("Sign Up with Google") {
                                    authViewModel.signInWithGoogle { user in
                                        if let user = user {
                                            appState.currentUser = user
                                            coordinator.completeOnboarding()
                                        }
                                    }
                                }
                                .buttonStyle(AuthButtonStyle.google)
                                .disabled(authViewModel.isLoading)
                                
                                // Apple Sign In Button
                                CustomAppleSignInButton {
                                    authViewModel.signInWithApple { user in
                                        if let user = user {
                                            appState.currentUser = user
                                            coordinator.completeOnboarding()
                                        }
                                    }
                                }
                                .disabled(authViewModel.isLoading)
                                
                                // Guest Button
                                Button("Continue as Guest") {
                                    authViewModel.continueAsGuest { user in
                                        if let user = user {
                                            appState.currentUser = user
                                            coordinator.completeOnboarding()
                                        }
                                    }
                                }
                                .buttonStyle(AuthButtonStyle.guest)
                                .disabled(authViewModel.isLoading)
                            }
                        }
                    }
                }
            }
            .padding()
                
            // Loading Overlay
            if authViewModel.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: UIConfiguration.primaryColor))
                    .scaleEffect(1.5)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    coordinator.previousStep()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .alert(
            authViewModel.statusViewModel?.title ?? "Error",
            isPresented: $authViewModel.showingAlert
        ) {
            Button("OK") {
                authViewModel.dismissAlert()
            }
        } message: {
            Text(authViewModel.statusViewModel?.message ?? "An error occurred")
        }
    }
    
    private var settingsSummaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(generateSummaryText())
                .font(.body)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
    
    private func generateSummaryText() -> AttributedString {
        let wakeUpTime = wakeUpTimeText()
        let gracePeriodMinutes = gracePeriodMinutesText()
        
        var summaryText = ""
        if gracePeriodMinutes == "no grace period" {
            summaryText = "At "
        } else {
            summaryText = "I will wake up at "
        }
        var attributedString = AttributedString(summaryText)
        
        // Add wake up time in bold
        var boldTime = AttributedString(wakeUpTime)
        boldTime.font = .body.bold()
        attributedString.append(boldTime)
        
        // Add method part
        if coordinator.preferences.wakeUpMethod == .steps {
            let stepGoal = coordinator.preferences.stepGoal ?? 0
            
            if gracePeriodMinutes == "no grace period" {
                attributedString.append(AttributedString(", I will have taken "))
            } else {
                attributedString.append(AttributedString(" and take "))
            }
            
            var boldSteps = AttributedString("\(stepGoal) steps")
            boldSteps.font = .body.bold()
            attributedString.append(boldSteps)
            
        } else if coordinator.preferences.wakeUpMethod == .location {
            var locationName = coordinator.preferences.location?.name ?? "my location"
            if locationName == "Custom Location" {
                locationName = "my location"
            }
            
            if gracePeriodMinutes == "no grace period" {
                attributedString.append(AttributedString(", I will have left "))
            } else {
                attributedString.append(AttributedString(" and leave "))
            }
            
            var boldLocation = AttributedString(locationName)
            boldLocation.font = .body.bold()
            attributedString.append(boldLocation)
        }
        
        // Add grace period
        if gracePeriodMinutes != "no grace period" {
            attributedString.append(AttributedString(" within "))
            
            var boldGracePeriod = AttributedString(gracePeriodMinutes)
            boldGracePeriod.font = .body.bold()
            attributedString.append(boldGracePeriod)
        }
        
        // Add motivation method
        if coordinator.preferences.motivationMethod == .noise {
            attributedString.append(AttributedString(" or my alarm will keep ringing."))
        } else if coordinator.preferences.motivationMethod == .phone {
            attributedString.append(AttributedString(" or my phone will auatomatically call "))
        } else if coordinator.preferences.motivationMethod == .money {
            attributedString.append(AttributedString(" or I will give ___ to charity."))
        } else if coordinator.preferences.motivationMethod == .none {
            attributedString.append(AttributedString("."))
        }
        
        return attributedString
    }
    
    private func gracePeriodMinutesText() -> String {
        guard let gracePeriod = coordinator.preferences.gracePeriod else { return "no time limit" }
        let minutes = Int(gracePeriod / 60)
        return minutes == 0 ? "no grace period" : "\(minutes) minutes"
    }
}

struct PreferenceRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
