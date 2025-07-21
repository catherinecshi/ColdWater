import SwiftUI

struct OnboardingConfirmationView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    
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
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Confirm your settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Review your preferences before continuing")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            ScrollView {
                VStack(spacing: 16) {
                    // Wake-up time
                    PreferenceRow(
                        title: "Wake-up time",
                        value: wakeUpTimeText()
                    )
                    
                    // Wake-up method
                    PreferenceRow(
                        title: "Wake-up method",
                        value: coordinator.preferences.wakeUpMethod?.rawValue.capitalized ?? "Not set"
                    )
                    
                    // Steps or Location
                    if coordinator.preferences.wakeUpMethod == .steps {
                        PreferenceRow(
                            title: "Step goal",
                            value: coordinator.preferences.stepGoal.map { "\($0) steps" } ?? "Not set"
                        )
                    } else if coordinator.preferences.wakeUpMethod == .location {
                        PreferenceRow(
                            title: "Location",
                            value: coordinator.preferences.location?.name ?? "Not set"
                        )
                        
                        if let location = coordinator.preferences.location {
                            PreferenceRow(
                                title: "Geofence radius",
                                value: "\(Int(location.geofenceRadius)) meters"
                            )
                        }
                    }
                    
                    // Grace period
                    PreferenceRow(
                        title: "Grace period",
                        value: gracePeriodText()
                    )
                    
                    // Motivation method
                    PreferenceRow(
                        title: "Motivation method",
                        value: coordinator.preferences.motivationMethod?.rawValue.capitalized ?? "Not set"
                    )
                }
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    coordinator.completeOnboarding()
                }) {
                    Text("Complete Setup")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    coordinator.previousStep()
                }) {
                    Text("Go Back")
                        .font(.body)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
        }
        .padding()
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
