import SwiftUI

enum TimeSelection {
    case everyday
    case weekdays
    case weekends
    case individual(Weekday)
}

struct WakeUpTimeView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @State private var selectedTab: TimeSelection = .everyday
    @State private var currentTime = Date()
    
    // Default time (7:00 AM)
    private var defaultTime: Date {
        let calendar = Calendar.current
        let components = DateComponents(hour: 7, minute: 0)
        return calendar.date(from: components) ?? Date()
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("When do you want to wake up?")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Select days and set wake-up times")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 20) {
                // Top tabs: Everyday, Weekdays, Weekends
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        TabButton(
                            title: "Everyday",
                            isSelected: isSelected(.everyday),
                            hasTime: coordinator.preferences.everydayTime != nil,
                            action: { selectTab(.everyday) }
                        )
                        
                        TabButton(
                            title: "Weekdays",
                            isSelected: isSelected(.weekdays),
                            hasTime: coordinator.preferences.weekdaysTime != nil,
                            action: { selectTab(.weekdays) }
                        )
                        
                        TabButton(
                            title: "Weekends",
                            isSelected: isSelected(.weekends),
                            hasTime: coordinator.preferences.weekendsTime != nil,
                            action: { selectTab(.weekends) }
                        )
                    }
                }
                
                // Bottom tabs: Individual days
                VStack(spacing: 12) {
                    HStack(spacing: 4) {
                        ForEach(Weekday.allCases, id: \.self) { day in
                            TabButton(
                                title: day.shortName,
                                isSelected: isSelected(.individual(day)),
                                hasTime: coordinator.preferences.wakeUpTimes[day] != nil,
                                action: { selectTab(.individual(day)) }
                            )
                        }
                    }
                }
                
                // Time picker and controls
                VStack(spacing: 16) {
                    DatePicker(
                        selection: $currentTime,
                        displayedComponents: .hourAndMinute
                    ) {
                        // Empty label
                    }
                    .datePickerStyle(.wheel)
                    .onChange(of: currentTime) { newTime in
                        saveTimeForCurrentTab(newTime)
                    }
                    
                    // Cancel button
                    Button(action: {
                        cancelCurrentSelection()
                    }) {
                        Text("Clear Time")
                            .font(.body)
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                coordinator.nextStep()
            }) {
                Text("Next")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(coordinator.canProceed() ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!coordinator.canProceed())
            .padding(.horizontal)
        }
        .padding()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            loadInitialState()
        }
    }
    
    private func isSelected(_ selection: TimeSelection) -> Bool {
        switch (selectedTab, selection) {
        case (.everyday, .everyday), (.weekdays, .weekdays), (.weekends, .weekends):
            return true
        case (.individual(let day1), .individual(let day2)):
            return day1 == day2
        default:
            return false
        }
    }
    
    private func selectTab(_ selection: TimeSelection) {
        selectedTab = selection
        
        // Load existing time or default to 7 AM
        switch selection {
        case .everyday:
            currentTime = coordinator.preferences.everydayTime ?? defaultTime
        case .weekdays:
            currentTime = coordinator.preferences.weekdaysTime ?? defaultTime
        case .weekends:
            currentTime = coordinator.preferences.weekendsTime ?? defaultTime
        case .individual(let day):
            currentTime = coordinator.preferences.wakeUpTimes[day] ?? defaultTime
        }
    }
    
    private func saveTimeForCurrentTab(_ time: Date) {
        switch selectedTab {
        case .everyday:
            // Everyday nullifies everything else
            coordinator.preferences.everydayTime = time
            coordinator.preferences.weekdaysTime = nil
            coordinator.preferences.weekendsTime = nil
            coordinator.preferences.wakeUpTimes.removeAll()
            
        case .weekdays:
            // Weekdays nullifies everyday and individual weekdays
            coordinator.preferences.weekdaysTime = time
            coordinator.preferences.everydayTime = nil
            // Remove individual weekday times
            for day in Weekday.weekdays {
                coordinator.preferences.wakeUpTimes.removeValue(forKey: day)
            }
            
        case .weekends:
            // Weekends nullifies everyday and individual weekends
            coordinator.preferences.weekendsTime = time
            coordinator.preferences.everydayTime = nil
            // Remove individual weekend times
            for day in Weekday.weekends {
                coordinator.preferences.wakeUpTimes.removeValue(forKey: day)
            }
            
        case .individual(let day):
            // Individual day nullifies conflicting group selections
            coordinator.preferences.wakeUpTimes[day] = time
            coordinator.preferences.everydayTime = nil
            
            if Weekday.weekdays.contains(day) {
                coordinator.preferences.weekdaysTime = nil
            }
            if Weekday.weekends.contains(day) {
                coordinator.preferences.weekendsTime = nil
            }
        }
    }
    
    private func cancelCurrentSelection() {
        switch selectedTab {
        case .everyday:
            coordinator.preferences.everydayTime = nil
        case .weekdays:
            coordinator.preferences.weekdaysTime = nil
        case .weekends:
            coordinator.preferences.weekendsTime = nil
        case .individual(let day):
            coordinator.preferences.wakeUpTimes.removeValue(forKey: day)
        }
        
        // Reset to default time
        currentTime = defaultTime
    }
    
    private func loadInitialState() {
        // Start with everyday tab if no selection exists
        if coordinator.preferences.hasAnyWakeUpTime() {
            // Find the first active selection
            if coordinator.preferences.everydayTime != nil {
                selectTab(.everyday)
            } else if coordinator.preferences.weekdaysTime != nil {
                selectTab(.weekdays)
            } else if coordinator.preferences.weekendsTime != nil {
                selectTab(.weekends)
            } else if let firstDay = coordinator.preferences.wakeUpTimes.keys.first {
                selectTab(.individual(firstDay))
            }
        } else {
            selectTab(.everyday)
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let hasTime: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : (hasTime ? .blue : .gray))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            Color.blue
                        } else if hasTime {
                            Color.blue.opacity(0.8)
                        } else {
                            Color.gray.opacity(0.2)
                        }
                    }
                )
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}