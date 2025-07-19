import SwiftUI
import Foundation

// MARK: - Model
struct WakeUpData {
    let consecutiveDays: Int
    let lastWakeUpTime: Date?
    let targetWakeUpTime: Date
    
    init(consecutiveDays: Int = 0, lastWakeUpTime: Date? = nil, targetWakeUpTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()) {
        self.consecutiveDays = consecutiveDays
        self.lastWakeUpTime = lastWakeUpTime
        self.targetWakeUpTime = targetWakeUpTime
    }
}

// MARK: - ViewModel
class HomeViewModel: ObservableObject {
    @Published var wakeUpData: WakeUpData
    
    init() {
        // Initialize with default data
        // In a real app, you'd load this from UserDefaults, Core Data, or other persistence
        self.wakeUpData = WakeUpData(consecutiveDays: 0)
        loadWakeUpData()
    }
    
    // MARK: - Public Methods
    func loadWakeUpData() {
        // Load from persistent storage
        let savedDays = UserDefaults.standard.integer(forKey: "consecutiveDays")
        let savedDate = UserDefaults.standard.object(forKey: "lastWakeUpTime") as? Date
        
        wakeUpData = WakeUpData(
            consecutiveDays: savedDays,
            lastWakeUpTime: savedDate
        )
    }
    
    func saveWakeUpData() {
        UserDefaults.standard.set(wakeUpData.consecutiveDays, forKey: "consecutiveDays")
        if let lastWakeUp = wakeUpData.lastWakeUpTime {
            UserDefaults.standard.set(lastWakeUp, forKey: "lastWakeUpTime")
        }
    }
    
    func recordSuccessfulWakeUp() {
        let newData = WakeUpData(
            consecutiveDays: wakeUpData.consecutiveDays + 1,
            lastWakeUpTime: Date(),
            targetWakeUpTime: wakeUpData.targetWakeUpTime
        )
        wakeUpData = newData
        saveWakeUpData()
    }
    
    func resetStreak() {
        let newData = WakeUpData(
            consecutiveDays: 0,
            lastWakeUpTime: wakeUpData.lastWakeUpTime,
            targetWakeUpTime: wakeUpData.targetWakeUpTime
        )
        wakeUpData = newData
        saveWakeUpData()
    }
    
    // MARK: - Computed Properties
    var daysString: String {
        return "\(wakeUpData.consecutiveDays)"
    }
    
    var isStreakActive: Bool {
        guard let lastWakeUp = wakeUpData.lastWakeUpTime else { return false }
        let calendar = Calendar.current
        return calendar.isDateInYesterday(lastWakeUp) || calendar.isDateInToday(lastWakeUp)
    }
}
