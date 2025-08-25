import SwiftUI
import AlarmKit

@available(iOS 26.0, *)
struct TestContentView: View {
    @StateObject private var alarmManager = CWAlarmManager.shared
    @State private var testResults: [String] = []
    @State private var showingResults = false
    @State private var isRunningTests = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    statusSection
                    activeAlarmsSection
                    recentAlarmsSection
                    testActionsSection
                }
                .padding()
            }
            .navigationTitle("Alarm Tests")
            .sheet(isPresented: $showingResults) {
                testResultsSheet
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("ColdWater Alarm Testing")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Test your alarm system functionality")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 16) {
            // Authorization Status
            InfoCard(title: "Authorization Status", 
                    content: authorizationStatusText,
                    color: authorizationStatusColor)
            
            // Loading State
            if alarmManager.isLoading {
                InfoCard(title: "Status", 
                        content: "Loading...",
                        color: .blue)
            }
            
            // Error Display
            if let error = alarmManager.error {
                InfoCard(title: "Error", 
                        content: error.localizedDescription,
                        color: .red)
            }
        }
    }
    
    private var activeAlarmsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Alarms (\(alarmManager.activeAlarms.count))")
                .font(.headline)
            
            if alarmManager.activeAlarms.isEmpty {
                Text("No active alarms")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(alarmManager.activeAlarms, id: \.id) { alarm in
                    AlarmCard(alarm: alarm, onDelete: { deleteAlarm(alarm.id) })
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var recentAlarmsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Alarms (\(alarmManager.recentAlarms.count))")
                .font(.headline)
            
            if alarmManager.recentAlarms.isEmpty {
                Text("No recent alarms")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(alarmManager.recentAlarms, id: \.id) { alarm in
                    AlarmCard(alarm: alarm, isRecent: true, onDelete: { deleteAlarm(alarm.id) })
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var testActionsSection: some View {
        VStack(spacing: 16) {
            Text("Test Actions")
                .font(.headline)
            
            // Basic Test Button
            TestButton(title: "Test Basic Alarm (60s)", color: .blue) {
                await testBasicAlarm()
            }
            
            TestButton(title: "Test Later Alarm (120s)", color: .blue) {
                await testLaterAlarm()
            }
            
            // Widget Log Button
            Button(action: { 
                checkWidgetLogs()
            }) {
                HStack {
                    Image(systemName: "externaldrive.connected.to.line.below")
                    Text("Check Widget Logs")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(12)
            }
            
            // Results Button
            Button(action: { showingResults = true }) {
                HStack {
                    Image(systemName: "doc.text")
                    Text("View Test Results (\(testResults.count))")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary)
                .cornerRadius(12)
            }
            .disabled(testResults.isEmpty)
        }
    }
    
    private var testResultsSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(testResults.enumerated()), id: \.offset) { index, result in
                        Text("\(index + 1). \(result)")
                            .font(.caption)
                            .padding(.vertical, 2)
                    }
                }
                .padding()
            }
            .navigationTitle("Test Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        testResults.removeAll()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        showingResults = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var authorizationStatusText: String {
        switch alarmManager.alarmManager.authorizationState {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        @unknown default: return "Unknown"
        }
    }
    
    private var authorizationStatusColor: Color {
        switch alarmManager.alarmManager.authorizationState {
        case .notDetermined: return .orange
        case .denied: return .red
        case .authorized: return .green
        @unknown default: return .gray
        }
    }
    
    // MARK: - Test Functions
    
    private func testBasicAlarm() async {
        addTestResult("Testing basic alarm scheduling...")
        
        // Artificially create user preferences even if none exist
        var preferences = UserPreferences()
        let now = Date()
        let testTime = now.addingTimeInterval(60) // 60 seconds from now
        preferences.everydayTime = testTime
        
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        addTestResult("Current time: \(formatter.string(from: now))")
        addTestResult("Test alarm time: \(formatter.string(from: testTime))")
        addTestResult("Time difference: \(testTime.timeIntervalSince(now)) seconds")
        
        // Debug the time extraction
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: testTime)
        addTestResult("Extracted components: \(components.hour ?? -1):\(components.minute ?? -1):\(components.second ?? -1)")
        addTestResult("Current timezone: \(calendar.timeZone.identifier)")
        
        do {
            try await alarmManager.createWakeUpAlarm(from: preferences)
            addTestResult("✅ Basic alarm scheduled successfully with artificial preferences")
        } catch {
            addTestResult("❌ Basic alarm failed: \(error.localizedDescription)")
        }
    }
    
    private func testLaterAlarm() async {
        addTestResult("Testing later alarm scheduling...")
        
        // Artificially create user preferences even if none exist
        var preferences = UserPreferences()
        let now = Date()
        let testTime = now.addingTimeInterval(120) // 120 seconds from now
        preferences.everydayTime = testTime
        
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        addTestResult("Current time: \(formatter.string(from: now))")
        addTestResult("Test alarm time: \(formatter.string(from: testTime))")
        addTestResult("Time difference: \(testTime.timeIntervalSince(now)) seconds")
        
        // Debug the time extraction
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: testTime)
        addTestResult("Extracted components: \(components.hour ?? -1):\(components.minute ?? -1):\(components.second ?? -1)")
        addTestResult("Current timezone: \(calendar.timeZone.identifier)")
        
        do {
            try await alarmManager.createWakeUpAlarm(from: preferences)
            addTestResult("✅ Later alarm scheduled successfully with artificial preferences")
        } catch {
            addTestResult("❌ Later alarm failed: \(error.localizedDescription)")
        }
    }
    
    
    private func deleteAlarm(_ id: UUID) {
        do {
            try alarmManager.deleteAlarm(id)
            addTestResult("🗑️ Deleted alarm \(id)")
        } catch {
            addTestResult("❌ Failed to delete alarm: \(error.localizedDescription)")
        }
    }
    
    private func checkWidgetLogs() {
        let defaults = UserDefaults(suiteName: "group.coldwateralarm")
        if let widgetLog = defaults?.string(forKey: "lastWidgetLog") {
            addTestResult("🟡 [WIDGET LOG] \(widgetLog)")
        } else {
            addTestResult("🟡 [WIDGET LOG] No widget logs found")
        }
    }
    
    private func addTestResult(_ result: String) {
        let timestamp = DateFormatter().apply {
            $0.timeStyle = .medium
        }.string(from: Date())
        
        testResults.append("[\(timestamp)] \(result)")
    }
}

// MARK: - Supporting Views

struct InfoCard: View {
    let title: String
    let content: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            Text(content)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

@available(iOS 26.0, *)
struct AlarmCard: View {
    let alarm: CWAlarm
    var isRecent: Bool = false
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(alarm.title)
                    .font(.headline)
                    .foregroundColor(isRecent ? .secondary : .primary)
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("State: \(String(describing: alarm.state))")
                    .font(.caption)
                
                if let method = alarm.wakeUpMethod {
                    Text("Method: \(method.rawValue)")
                        .font(.caption)
                }
                
                if let goal = alarm.stepGoal {
                    Text("Steps: \(goal)")
                        .font(.caption)
                }
                
                if alarm.location != nil {
                    Text("Location: \(alarm.location?.name ?? "Unknown")")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(isRecent ? Color.gray.opacity(0.1) : Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TestButton: View {
    let title: String
    let color: Color
    let action: () async -> Void
    
    @State private var isRunning = false
    
    var body: some View {
        Button(action: {
            Task {
                isRunning = true
                await action()
                isRunning = false
            }
        }) {
            HStack {
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Text(title)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isRunning ? Color.gray : color)
            .cornerRadius(12)
        }
        .disabled(isRunning)
    }
}

// MARK: - Extensions

extension DateFormatter {
    func apply(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}

#Preview {
    if #available(iOS 26.0, *) {
        TestContentView()
    } else {
        Text("iOS 26+ Required")
    }
}
