import AlarmKit

/// Custom metadata that contains wake-up specific information for ColdWater alarms
struct CWAlarmMetadata: AlarmMetadata, Equatable, Hashable {
    var title: String
    var wakeUpMethod: WakeUpMethod?
    var stepGoal: Int?
    var location: Location?
    var gracePeriod: TimeInterval?
    var motivationMethod: MotivationMethod?
    var createdAt: Date = Date()
    
    init(
        title: String,
        wakeUpMethod: WakeUpMethod? = nil,
        stepGoal: Int? = nil,
        location: Location? = nil,
        gracePeriod: TimeInterval? = nil,
        motivationMethod: MotivationMethod? = nil
    ) {
        self.title = title
        self.wakeUpMethod = wakeUpMethod
        self.stepGoal = stepGoal
        self.location = location
        self.gracePeriod = gracePeriod
        self.motivationMethod = motivationMethod
    }
    
    static var defaultWakeUpMetadata: Self {
        .init(
            title: "Wake Up",
            wakeUpMethod: .steps,
            stepGoal: 100,
            gracePeriod: 300 // 5 minutes
        )
    }
    
    static func fromUserPreferences(_ preferences: UserPreferences) -> Self {
        .init(
            title: "Wake Up",
            wakeUpMethod: preferences.wakeUpMethod,
            stepGoal: preferences.stepGoal,
            location: preferences.location,
            gracePeriod: preferences.gracePeriod,
            motivationMethod: preferences.motivationMethod
        )
    }
}
