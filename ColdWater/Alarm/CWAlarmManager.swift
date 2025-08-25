import Foundation
import SwiftUI
import AlarmKit
import ActivityKit
import Combine
import UIKit

// MARK: - Custom Errors
enum CWAlarmError: Error, LocalizedError {
    case notAuthorized
    case unknownAuthState
    case invalidTime
    case noWakeUpTimeConfigured
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Not authorized to access alarms. Please enable in Settings."
        case .unknownAuthState:
            return "Unknown authorization state for alarms."
        case .invalidTime:
            return "Invalid time configuration for alarm."
        case .noWakeUpTimeConfigured:
            return "No wake-up time has been configured."
        }
    }
}

// MARK: - AlarmKit Manager
@available(iOS 26.0, *)
class CWAlarmManager: Resettable, ObservableObject {
    static let shared = CWAlarmManager()
    
    @Published private(set) var activeAlarms: [CWAlarm] = []
    @Published private(set) var recentAlarms: [CWAlarm] = []
    @Published private(set) var isLoading = false
    @Published var showingForegroundAlarm: CWAlarm? = nil
    @Published var error: Error? = nil {
        didSet {
            if error != nil {
                print("CWAlarmManager Error: \(error!)")
                showError = true
            }
        }
    }
    @Published var showError: Bool = false {
        didSet {
            if !showError {
                self.error = nil
            }
        }
    }
    
    // Countdown tracking
    @Published private(set) var countdownTimers: [UUID: TimeInterval] = [:]
    private var countdownUpdateTimers: [UUID: Timer] = [:]
    
    // Configuration
    private let groupId = "group.coldwateralarm"
    private var userDefaults: UserDefaults {
        UserDefaults(suiteName: groupId) ?? UserDefaults.standard
    }
    
    private let activeAlarmsKey = "ColdWater.activeAlarms"
    private let recentAlarmsKey = "ColdWater.recentAlarms"
    
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    // AlarmKit integration
    var alarmManager = AlarmManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Computed properties for different alarm types
    var wakeUpAlarms: [CWAlarm] {
        activeAlarms.filter { $0.isWakeUpAlarm }
    }
    
    var stepBasedAlarms: [CWAlarm] {
        activeAlarms.filter { $0.requiresStepsCheck }
    }
    
    var locationBasedAlarms: [CWAlarm] {
        activeAlarms.filter { $0.requiresLocationCheck }
    }
    
    private init() {
        SingletonRegistry.shared.register(self)
        
        do {
            try initializeLocalAlarms()
            try initializeRemoteAlarms()
        } catch {
            self.error = error
        }
        
        observeAlarms()
        observeAuthorizationUpdates()
    }
    
    func reset() {
        activeAlarms = []
        recentAlarms = []
        isLoading = false
        showingForegroundAlarm = nil
        error = nil
        showError = false
        cancellables.removeAll()
        
        // Clean up countdown timers
        countdownUpdateTimers.values.forEach { $0.invalidate() }
        countdownUpdateTimers.removeAll()
        countdownTimers.removeAll()
    }
    
    // MARK: - Initialization
    
    private func initializeLocalAlarms() throws {
        let activeAlarms: [CWAlarm] = if let data = userDefaults.data(forKey: activeAlarmsKey) {
            try jsonDecoder.decode([CWAlarm].self, from: data)
        } else {
            []
        }
        
        let recentAlarms: [CWAlarm] = if let data = userDefaults.data(forKey: recentAlarmsKey) {
            try jsonDecoder.decode([CWAlarm].self, from: data)
        } else {
            []
        }
        
        self.activeAlarms = activeAlarms
        self.recentAlarms = recentAlarms
    }
    
    private func initializeRemoteAlarms() throws {
        let remoteAlarms: [Alarm] = try alarmManager.alarms
        combineLocalRemoteAlarms(
            localActiveAlarms: self.activeAlarms,
            localRecentAlarms: self.recentAlarms,
            remoteAlarms: remoteAlarms
        )
    }
    
    private func combineLocalRemoteAlarms(
        localActiveAlarms: [CWAlarm],
        localRecentAlarms: [CWAlarm],
        remoteAlarms: [Alarm]
    ) {
        var activeAlarms: [CWAlarm] = []
        var recentAlarms: [CWAlarm] = localRecentAlarms
        
        for var alarm in localActiveAlarms {
            if let remote = remoteAlarms.first(where: { $0.id == alarm.id }) {
                alarm.alarm = remote
                activeAlarms.append(alarm)
            } else {
                // Alarm no longer exists in system, move to recent
                alarm.presentationMode = nil
                recentAlarms.removeAll(where: { $0.id == alarm.id })
                recentAlarms.append(alarm)
            }
        }
        
        // Handle new alarms that appeared in the system
        let localIds = Set(activeAlarms.map(\.id))
        let remoteIds = Set(remoteAlarms.map(\.id))
        let addedIds = remoteIds.subtracting(localIds)
        let addedAlarms = remoteAlarms.filter { addedIds.contains($0.id) }
        
        activeAlarms.append(contentsOf: addedAlarms.map {
            CWAlarm(alarm: $0, metadata: .defaultWakeUpMetadata)
        })
        
        self.activeAlarms = activeAlarms
        self.recentAlarms = recentAlarms
    }
    
    // MARK: - Data Persistence
    
    private func saveActiveAlarms() {
        print("📱 [SAVE] Saving \(activeAlarms.count) active alarms to UserDefaults")
        do {
            let data = try jsonEncoder.encode(activeAlarms)
            userDefaults.set(data, forKey: activeAlarmsKey)
            print("📱 [SAVE] ✅ Successfully saved active alarms")
        } catch {
            print("📱 [SAVE] ❌ Failed to save active alarms: \(error)")
        }
    }
    
    private func saveRecentAlarms() {
        print("📱 [SAVE] Saving \(recentAlarms.count) recent alarms to UserDefaults")
        do {
            let data = try jsonEncoder.encode(recentAlarms)
            userDefaults.set(data, forKey: recentAlarmsKey)
            print("📱 [SAVE] ✅ Successfully saved recent alarms")
        } catch {
            print("📱 [SAVE] ❌ Failed to save recent alarms: \(error)")
        }
    }
    
    // MARK: - Alarm Observation
    
    private func observeAlarms() {
        print("👀 [OBSERVE] Starting alarm observation task")
        Task {
            for await remoteAlarms in alarmManager.alarmUpdates {
                print("👀 [OBSERVE] Received alarm update from AlarmKit: \(remoteAlarms.count) alarms")
                for alarm in remoteAlarms {
                    print("👀 [OBSERVE] - Alarm \(alarm.id): state=\(alarm.state)")
                    
                    // 🔥 Enhanced logging for alarm state changes
                    switch alarm.state {
                    case .alerting:
                        print("🚨🔥 [FIRE] ALARM IS ALERTING! Alarm \(alarm.id) has FIRED!")
                        
                        // Always set the foreground alarm - the view layer will determine if app is active
                        await MainActor.run {
                            print("🚨🔥 [FIRE] Alarm is alerting - setting up for potential foreground display")
                            if let cwAlarm = self.activeAlarms.first(where: { $0.id == alarm.id }) {
                                self.showingForegroundAlarm = cwAlarm
                            }
                        }
                        
                    case .countdown:
                        print("⏲️🔥 [FIRE] Alarm \(alarm.id) entered COUNTDOWN mode!")
                        
                        await MainActor.run {
                            if let cwAlarm = self.activeAlarms.first(where: { $0.id == alarm.id }) {
                                // Start countdown tracking if we have countdown duration
                                if let countdownDuration = alarm.countdownDuration {
                                    self.startCountdownTracking(for: alarm.id, duration: countdownDuration.postAlert ?? TimeInterval(10))
                                }
                            }
                        }
                        
                    case .paused:
                        print("⏸️🔥 [FIRE] Alarm \(alarm.id) is PAUSED!")
                        await MainActor.run {
                            if let cwAlarm = self.activeAlarms.first(where: { $0.id == alarm.id }) {
                                self.showingForegroundAlarm = cwAlarm
                            }
                            // Pause countdown tracking
                            self.pauseCountdownTracking(for: alarm.id)
                        }
                        
                    case .scheduled:
                        print("📅 [OBSERVE] Alarm \(alarm.id) is scheduled (waiting to fire)")
                        await MainActor.run {
                            // Clear foreground alarm if this alarm was dismissed
                            if self.showingForegroundAlarm?.id == alarm.id {
                                self.showingForegroundAlarm = nil
                            }
                            // Stop countdown tracking when alarm is dismissed/stopped
                            self.stopCountdownTracking(for: alarm.id)
                        }
                        
                    @unknown default:
                        print("❓ [OBSERVE] Unknown state for alarm \(alarm.id): \(alarm.state)")
                    }
                }
                await MainActor.run {
                    combineLocalRemoteAlarms(
                        localActiveAlarms: self.activeAlarms,
                        localRecentAlarms: self.recentAlarms,
                        remoteAlarms: remoteAlarms
                    )
                }
            }
        }
    }
    
    private func observeAuthorizationUpdates() {
        Task {
            for await _ in alarmManager.authorizationUpdates {
                try await checkAuthorization()
            }
        }
    }
    
    // MARK: - Public API for Wake-Up Alarms
    
    /// Create a wake-up alarm from user preferences
    @MainActor
    func createWakeUpAlarm(from preferences: UserPreferences) async throws {
        guard preferences.hasAnyWakeUpTime() else {
            throw CWAlarmError.noWakeUpTimeConfigured
        }
        
        let metadata = CWAlarmMetadata.fromUserPreferences(preferences)
        
        // Create alarms for each configured wake-up time
        if let everydayTime = preferences.everydayTime {
            try await addWakeUpAlarm(
                time: everydayTime,
                weekdays: Set(Weekday.allCases),
                metadata: metadata
            )
        }
        
        if let weekdaysTime = preferences.weekdaysTime {
            try await addWakeUpAlarm(
                time: weekdaysTime,
                weekdays: Set(Weekday.weekdays),
                metadata: metadata
            )
        }
        
        if let weekendsTime = preferences.weekendsTime {
            try await addWakeUpAlarm(
                time: weekendsTime,
                weekdays: Set(Weekday.weekends),
                metadata: metadata
            )
        }
        
        // Handle individual day settings
        for (weekday, time) in preferences.wakeUpTimes {
            try await addWakeUpAlarm(
                time: time,
                weekdays: [weekday],
                metadata: metadata
            )
        }
    }
    
    private func addWakeUpAlarm(
        time: Date,
        weekdays: Set<Weekday>,
        metadata: CWAlarmMetadata
    ) async throws {
        let alarmId = UUID()
        let schedule = try createRelativeSchedule(date: time, weekdays: weekdays)
        
        let countdownDuration = createCountdownDuration(metadata: metadata)
        
        try await scheduleAlarm(
            id: alarmId,
            metadata: metadata,
            schedule: schedule,
            countdownDuration: countdownDuration
        )
    }
    
    // MARK: - Core AlarmKit Integration
    
    private func scheduleAlarm(
        id: UUID,
        metadata: CWAlarmMetadata,
        schedule: Alarm.Schedule?,
        countdownDuration: Alarm.CountdownDuration?
    ) async throws {
        try await checkAuthorization()
        
        let presentation = createAlarmPresentation(metadata)
        
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: metadata,
            tintColor: .blue
        )
        
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: countdownDuration,
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopIntent(alarmID: id),
            secondaryIntent: metadata.motivationMethod != .none ? RepeatIntent(alarmID: id) : nil,
            sound: .default
        )
        let alarm = try await alarmManager.schedule(id: id, configuration: configuration)
        
        await MainActor.run {
            activeAlarms.removeAll { $0.id == alarm.id }
            let cwAlarm = CWAlarm(alarm: alarm, metadata: metadata)
            activeAlarms.insert(cwAlarm, at: 0)
            saveActiveAlarms()
            
            // Remove from recent if it was there
            recentAlarms.removeAll { $0.id == id }
            saveRecentAlarms()
        }
    }
    
    private func createRelativeSchedule(date: Date, weekdays: Set<Weekday>) throws -> Alarm.Schedule {
        guard let time = date.time else {
            throw CWAlarmError.invalidTime
        }
        
        // Convert your Weekday enum to Locale.Weekday
        let localeWeekdays = weekdays.compactMap { weekday -> Locale.Weekday? in
            switch weekday {
            case .sunday: return .sunday
            case .monday: return .monday
            case .tuesday: return .tuesday
            case .wednesday: return .wednesday
            case .thursday: return .thursday
            case .friday: return .friday
            case .saturday: return .saturday
            }
        }
        
        let relativeSchedule = Alarm.Schedule.Relative(
            time: time,
            repeats: localeWeekdays.isEmpty ? .never : .weekly(localeWeekdays)
        )
        
        return .relative(relativeSchedule)
    }
    
    private func createCountdownDuration(metadata: CWAlarmMetadata) -> Alarm.CountdownDuration? {
        let gracePeriod = metadata.gracePeriod ?? 0
        
        if gracePeriod == 0 {
            return nil
        }
        
        return .init(preAlert: nil, postAlert: gracePeriod)
    }
    
    private func createAlarmPresentation(_ metadata: CWAlarmMetadata) -> AlarmPresentation {
        let hasGracePeriod = metadata.gracePeriod != nil && metadata.gracePeriod! > 0
        let hasMotivation = metadata.motivationMethod != nil && metadata.motivationMethod != .none
        
        let secondaryBehavior: AlarmPresentation.Alert.SecondaryButtonBehavior? = hasGracePeriod ? .countdown : nil
        let secondaryButton: AlarmButton? = hasMotivation ? .snoozeButton : nil
        
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: metadata.title),
            stopButton: .stopButton,
            secondaryButton: secondaryButton,
            secondaryButtonBehavior: secondaryBehavior
        )
        
        if !hasGracePeriod {
            return AlarmPresentation(alert: alert)
        }
        
        let countdown = AlarmPresentation.Countdown(
            title: "Complete your wake-up task",
            pauseButton: .pauseButton
        )
        
        let paused = AlarmPresentation.Paused(
            title: "Paused - Complete your task",
            resumeButton: .resumeButton
        )
        
        return AlarmPresentation(alert: alert, countdown: countdown, paused: paused)
    }
    
    // MARK: - Alarm Control Methods
    
    func stopAlarm(_ alarmID: UUID) throws {
        if let alarm = activeAlarms.first(where: { $0.id == alarmID }), alarm.isOneShot {
            try alarmManager.cancel(id: alarmID)
        } else {
            try alarmManager.stop(id: alarmID)
        }
    }
    
    func pauseAlarm(_ alarmID: UUID) throws {
        // Check if the alarm supports pausing before attempting to pause
        guard let cwAlarm = activeAlarms.first(where: { $0.id == alarmID }) else {
            print("❌ [PAUSE] Alarm \(alarmID) not found in active alarms")
            throw CWAlarmError.invalidTime
        }
        
        let alarmInstance = cwAlarm.alarm
        
        // Only allow pausing if alarm is in countdown state and has countdown duration
        guard alarmInstance.state == .countdown,
              alarmInstance.countdownDuration != nil else {
            print("❌ [PAUSE] Alarm \(alarmID) cannot be paused - not in countdown state or no countdown duration")
            throw CWAlarmError.invalidTime
        }
        
        try alarmManager.pause(id: alarmID)
        updateAlarmState(alarmID, to: .paused)
    }
    
    func resumeAlarm(_ alarmID: UUID) throws {
        try alarmManager.resume(id: alarmID)
        updateAlarmState(alarmID, to: .countdown)
        resumeCountdownTracking(for: alarmID)
    }
    
    func deleteAlarm(_ alarmID: UUID) throws {
        if activeAlarms.contains(where: { $0.id == alarmID }) {
            try alarmManager.cancel(id: alarmID)
            activeAlarms.removeAll { $0.id == alarmID }
            saveActiveAlarms()
        } else {
            recentAlarms.removeAll { $0.id == alarmID }
            saveRecentAlarms()
        }
    }
    
    private func updateAlarmState(_ alarmID: UUID, to state: Alarm.State) {
        guard let index = activeAlarms.firstIndex(where: { $0.id == alarmID }) else { return }
        var newAlarm = activeAlarms[index].alarm
        newAlarm.state = state
        activeAlarms[index].alarm = newAlarm
        saveActiveAlarms()
    }
    
    // MARK: - Authorization
    private func checkAuthorization() async throws {
        switch alarmManager.authorizationState {
        case .notDetermined:
            let state = try await alarmManager.requestAuthorization()
            if state != .authorized {
                throw CWAlarmError.notAuthorized
            }
        case .denied:
            throw CWAlarmError.notAuthorized
        case .authorized:
            return
        @unknown default:
            throw CWAlarmError.unknownAuthState
        }
    }
}

// MARK: - Timer Functions
@available(iOS 26.0, *)
extension CWAlarmManager {
    
    /// Create a traditional timer that counts down from the specified duration
    @MainActor
    func createTimer(title: String, duration: TimeInterval, metadata: CWAlarmMetadata? = nil) async throws {
        print("⏰ [TIMER] Creating timer: '\(title)' with \(duration)s duration")
        
        let timerMetadata = metadata ?? CWAlarmMetadata(
            title: title,
            wakeUpMethod: .steps,
            stepGoal: 50,
            gracePeriod: nil,
            motivationMethod: .noise
        )
        
        try await scheduleTimer(
            id: UUID(),
            metadata: timerMetadata,
            duration: duration
        )
        
        print("✅ [TIMER] Successfully scheduled timer")
    }
    
    /// Create a timer from existing recent timer (restart functionality)
    @MainActor
    func restartRecentTimer(timerId: UUID) async throws {
        guard let recentTimer = recentAlarms.first(where: { $0.id == timerId }) else {
            throw CWAlarmError.invalidTime
        }
        
        guard let duration = recentTimer.postTimerDuration else {
            throw CWAlarmError.invalidTime
        }
        
        print("🔄 [TIMER] Restarting recent timer: '\(recentTimer.metadata.title)' with \(duration)s")
        
        try await scheduleTimer(
            id: UUID(), // New ID for new timer instance
            metadata: recentTimer.metadata,
            duration: duration
        )
        
        print("✅ [TIMER] Successfully restarted timer")
    }
    
    /// Create a backup timer that starts immediately (for escape prevention)
    @MainActor
    func createBackupTimer(for originalAlarm: CWAlarm, duration: TimeInterval = 10.0) async throws {
        print("⚠️ [BACKUP TIMER] Creating backup timer with \(duration)s duration")
        
        let backupMetadata = CWAlarmMetadata(
            title: "⚠️ BACKUP: " + originalAlarm.metadata.title,
            wakeUpMethod: originalAlarm.metadata.wakeUpMethod,
            stepGoal: originalAlarm.metadata.stepGoal,
            location: originalAlarm.metadata.location,
            gracePeriod: originalAlarm.metadata.gracePeriod,
            motivationMethod: .noise // Force noise for backup
        )
        
        try await scheduleTimer(
            id: UUID(),
            metadata: backupMetadata,
            duration: duration
        )
        
        print("✅ [BACKUP TIMER] Successfully scheduled backup timer")
    }
    
    // MARK: - Core Timer Scheduling
    
    private func scheduleTimer(
        id: UUID,
        metadata: CWAlarmMetadata,
        duration: TimeInterval
    ) async throws {
        try await checkAuthorization()
        
        let presentation = createTimerPresentation(metadata, duration: duration)
        
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: metadata,
            tintColor: .blue
        )
        
        // Use the timer convenience initializer
        let configuration = AlarmManager.AlarmConfiguration.timer(
            duration: duration,
            attributes: attributes,
            stopIntent: StopIntent(alarmID: id),
            secondaryIntent: RepeatIntent(alarmID: id), // Allows restarting the timer
            sound: .default
        )
        
        let alarm = try await alarmManager.schedule(id: id, configuration: configuration)
        
        await MainActor.run {
            activeAlarms.removeAll { $0.id == alarm.id }
            let cwAlarm = CWAlarm(alarm: alarm, metadata: metadata)
            activeAlarms.insert(cwAlarm, at: 0)
            saveActiveAlarms()
            
            // Add to recent timers for restart functionality (if not already there)
            if !recentAlarms.contains(where: { $0.metadata.title == metadata.title && $0.postTimerDuration == duration }) {
                let recentTimer = CWAlarm(alarm: alarm, metadata: metadata, isRecent: true)
                recentAlarms.insert(recentTimer, at: 0)
                saveRecentAlarms()
            }
        }
    }
    
    // MARK: - Timer-Specific Presentation
    
    private func createTimerPresentation(_ metadata: CWAlarmMetadata, duration: TimeInterval) -> AlarmPresentation {
        let hasMotivation = metadata.motivationMethod != nil && metadata.motivationMethod != .none
        
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: metadata.title + " - Timer Complete!"),
            stopButton: .stopButton,
            secondaryButton: hasMotivation ? .repeatButton : nil,
            secondaryButtonBehavior: hasMotivation ? .countdown : nil
        )
        
        // Timer always has countdown state
        let countdown = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: metadata.title + " - \(formatDuration(duration))"),
            pauseButton: .pauseButton
        )
        
        let paused = AlarmPresentation.Paused(
            title: LocalizedStringResource(stringLiteral: metadata.title + " - Paused"),
            resumeButton: .resumeButton
        )
        
        return AlarmPresentation(alert: alert, countdown: countdown, paused: paused)
    }
    
    // MARK: - Computed Properties for Timers
    
    var activeTimers: [CWAlarm] {
        activeAlarms.filter { $0.alarm.schedule == nil && $0.alarm.countdownDuration != nil }
    }
    
    var recentTimers: [CWAlarm] {
        recentAlarms.filter { $0.alarm.schedule == nil && $0.alarm.countdownDuration != nil }
    }
    
    // MARK: - Countdown Management
    
    func getCountdownTimeRemaining(for alarmID: UUID) -> TimeInterval? {
        return countdownTimers[alarmID]
    }
    
    private func startCountdownTracking(for alarmID: UUID, duration: TimeInterval) {
        print("⏲️ [COUNTDOWN] Starting countdown tracking for alarm \(alarmID) with duration \(duration)s")
        
        // Set initial time
        countdownTimers[alarmID] = duration
        
        // Clean up any existing timer for this alarm
        countdownUpdateTimers[alarmID]?.invalidate()
        
        // Start the countdown timer
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if let currentTime = self.countdownTimers[alarmID], currentTime > 0 {
                self.countdownTimers[alarmID] = currentTime - 1
            } else {
                // Time's up, stop tracking
                self.stopCountdownTracking(for: alarmID)
            }
        }
        
        countdownUpdateTimers[alarmID] = timer
    }
    
    private func stopCountdownTracking(for alarmID: UUID) {
        print("⏲️ [COUNTDOWN] Stopping countdown tracking for alarm \(alarmID)")
        
        countdownUpdateTimers[alarmID]?.invalidate()
        countdownUpdateTimers.removeValue(forKey: alarmID)
        countdownTimers.removeValue(forKey: alarmID)
    }
    
    private func pauseCountdownTracking(for alarmID: UUID) {
        print("⏸️ [COUNTDOWN] Pausing countdown tracking for alarm \(alarmID)")
        countdownUpdateTimers[alarmID]?.invalidate()
        countdownUpdateTimers.removeValue(forKey: alarmID)
    }
    
    private func resumeCountdownTracking(for alarmID: UUID) {
        print("▶️ [COUNTDOWN] Resuming countdown tracking for alarm \(alarmID)")
        
        guard let timeRemaining = countdownTimers[alarmID], timeRemaining > 0 else {
            stopCountdownTracking(for: alarmID)
            return
        }
        
        // Start timer again with current remaining time
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if let currentTime = self.countdownTimers[alarmID], currentTime > 0 {
                self.countdownTimers[alarmID] = currentTime - 1
            } else {
                self.stopCountdownTracking(for: alarmID)
            }
        }
        
        countdownUpdateTimers[alarmID] = timer
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Other Type Extensions

@available(iOS 26.0, *)
extension Date {
    var time: Alarm.Schedule.Relative.Time? {
        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: self)
        guard let hour = dateComponents.hour, let minute = dateComponents.minute else { return nil }
        return Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
    }
}
