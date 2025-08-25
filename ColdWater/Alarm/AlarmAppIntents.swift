import AppIntents
import AlarmKit

@available(iOS 26.0, *)
struct StopIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else {
            throw CWAlarmError.invalidTime
        }
        Task { @MainActor in
            do {
                try CWAlarmManager.shared.stopAlarm(id)
            } catch {
                print("🔴 [INTENT] ❌ StopAlarm failed: \(error)")
            }
        }
        return .result()
    }
    
    static var title: LocalizedStringResource = "Stop"
    static var description = IntentDescription("Stop wake-up alarm")
    
    @Parameter(title: "alarmID")
    var alarmID: String
    
    init(alarmID: UUID) {
        self.alarmID = alarmID.uuidString
    }
    
    init() {
        self.alarmID = ""
    }
}

@available(iOS 26.0, *)
struct PauseIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else {
            throw CWAlarmError.invalidTime
        }
        Task { @MainActor in
            do {
                try CWAlarmManager.shared.pauseAlarm(id)
            } catch {
                print("⏸️ [INTENT] ❌ PauseAlarm failed: \(error)")
            }
        }
        return .result()
    }
    
    static var title: LocalizedStringResource = "Pause"
    static var description = IntentDescription("Pause wake-up task countdown")
    
    @Parameter(title: "alarmID")
    var alarmID: String
    
    init(alarmID: UUID) {
        self.alarmID = alarmID.uuidString
    }
    
    init() {
        self.alarmID = ""
    }
}

@available(iOS 26.0, *)
struct RepeatIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else {
            throw CWAlarmError.invalidTime
        }
        Task { @MainActor in
            do {
                try CWAlarmManager.shared.alarmManager.countdown(id: id)
            } catch {
                print("🔄 [INTENT] ❌ Countdown/Snooze failed: \(error)")
            }
        }
        return .result()
    }
    
    static var title: LocalizedStringResource = "Snooze"
    static var description = IntentDescription("Snooze wake-up alarm")
    
    @Parameter(title: "alarmID")
    var alarmID: String
    
    init(alarmID: UUID) {
        self.alarmID = alarmID.uuidString
    }
    
    init() {
        self.alarmID = ""
    }
}

@available(iOS 26.0, *)
struct ResumeIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else {
            throw CWAlarmError.invalidTime
        }
        Task { @MainActor in
            do {
                try CWAlarmManager.shared.resumeAlarm(id)
            } catch {
                print("▶️ [INTENT] ❌ ResumeAlarm failed: \(error)")
            }
        }
        return .result()
    }

    static var title: LocalizedStringResource = "Resume"
    static var description = IntentDescription("Resume wake-up task countdown")

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: UUID) {
        self.alarmID = alarmID.uuidString
    }

    init() {
        self.alarmID = ""
    }
}

