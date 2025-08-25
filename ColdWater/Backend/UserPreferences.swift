import Foundation
import CoreLocation

enum Weekday: String, CaseIterable, Codable {
    case sunday = "Sunday"
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    
    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
    
    static var weekdays: [Weekday] {
        return [.monday, .tuesday, .wednesday, .thursday, .friday]
    }
    
    static var weekends: [Weekday] {
        return [.saturday, .sunday]
    }
}

enum WakeUpMethod: String, CaseIterable, Codable {
    case steps = "steps"
    case location = "location"
}

enum MotivationMethod: String, CaseIterable, Codable {
    case phone = "phone"
    case money = "money"
    case noise = "noise"
    case none = "none"
}

struct Location: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    let geofenceRadius: Double
    let name: String
    
    var clLocation: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
}

struct UserPreferences: Codable {
    var wakeUpTimes: [Weekday: Date]
    var everydayTime: Date?
    var weekdaysTime: Date?
    var weekendsTime: Date?
    var wakeUpMethod: WakeUpMethod?
    var stepGoal: Int?
    var location: Location?
    var gracePeriod: TimeInterval?
    var motivationMethod: MotivationMethod?
    
    init() {
        self.wakeUpTimes = [:]
        self.everydayTime = nil
        self.weekdaysTime = nil
        self.weekendsTime = nil
        self.wakeUpMethod = nil
        self.stepGoal = nil
        self.location = nil
        self.gracePeriod = nil
        self.motivationMethod = nil
    }
    
    func hasAnyWakeUpTime() -> Bool {
        return everydayTime != nil || weekdaysTime != nil || weekendsTime != nil || !wakeUpTimes.isEmpty
    }
}
