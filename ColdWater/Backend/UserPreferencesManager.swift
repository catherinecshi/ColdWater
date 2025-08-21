import Foundation
import Combine

/// Manager for handling user preferences with Supabase backend and local caching
class UserPreferencesManager: Resettable, ObservableObject {
    static let shared = UserPreferencesManager()
    
    @Published private(set) var preferences = UserPreferences()
    @Published private(set) var isLoading = false
    @Published private(set) var hasUnsavedChanges = false
    
    private let supabaseService = SupabaseService.shared
    private var cancellables = Set<AnyCancellable>()
    private var realTimeSubscription: Task<Void, Never>?
    
    private init() {
        SingletonRegistry.shared.register(self)
        setupSubscriptions()
    }
    
    func reset() {
        preferences = UserPreferences()
        isLoading = false
        hasUnsavedChanges = false
        cancellables.removeAll()
        realTimeSubscription?.cancel()
        realTimeSubscription = nil
    }
    
    // MARK: - Setup
    
    private func setupSubscriptions() {
        // Load preferences when Supabase connects
        supabaseService.$isConnected
            .filter { $0 }
            .first()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadPreferences()
                    self?.startRealTimeSubscription()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Operations
    
    /// Load user preferences (currently using local storage since user_preferences table doesn't exist yet)
    @MainActor
    func loadPreferences() async {
        isLoading = true
        
        // TODO: Implement Supabase integration when user_preferences table is created
        // For now, use local storage
        loadFromUserDefaults()
        
        print("✅ UserPreferencesManager: Preferences loaded from local storage")
        hasUnsavedChanges = false
        isLoading = false
    }
    
    private func loadFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: "user_preferences"),
           let decodedPreferences = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            preferences = decodedPreferences
        }
    }
    
    /// Save current preferences (currently using local storage since user_preferences table doesn't exist yet)
    @MainActor
    func savePreferences() async {
        isLoading = true
        
        // TODO: Implement Supabase integration when user_preferences table is created
        // For now, use local storage
        saveToUserDefaults()
        
        print("✅ UserPreferencesManager: Preferences saved to local storage")
        hasUnsavedChanges = false
        isLoading = false
    }
    
    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "user_preferences")
        }
    }
    
    /// Auto-save preferences with debouncing
    private func autoSave() {
        hasUnsavedChanges = true
        
        // Debounce auto-save by 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await savePreferences()
        }
    }
    
    // MARK: - Real-time Subscription
    
    private func startRealTimeSubscription() {
        // TODO: Implement real-time subscription when user_preferences table is created
        print("ℹ️ UserPreferencesManager: Real-time subscription disabled (using local storage)")
    }
    
    // MARK: - Preference Updates
    
    /// Update wake up time for a specific weekday
    func setWakeUpTime(_ time: Date, for weekday: Weekday) {
        preferences.wakeUpTimes[weekday] = time
        autoSave()
    }
    
    /// Remove wake up time for a specific weekday
    func removeWakeUpTime(for weekday: Weekday) {
        preferences.wakeUpTimes.removeValue(forKey: weekday)
        autoSave()
    }
    
    /// Set everyday wake up time
    func setEverydayTime(_ time: Date?) {
        preferences.everydayTime = time
        autoSave()
    }
    
    /// Set weekdays wake up time
    func setWeekdaysTime(_ time: Date?) {
        preferences.weekdaysTime = time
        autoSave()
    }
    
    /// Set weekends wake up time
    func setWeekendsTime(_ time: Date?) {
        preferences.weekendsTime = time
        autoSave()
    }
    
    /// Set wake up method
    func setWakeUpMethod(_ method: WakeUpMethod?) {
        preferences.wakeUpMethod = method
        autoSave()
    }
    
    /// Set step goal
    func setStepGoal(_ goal: Int?) {
        preferences.stepGoal = goal
        autoSave()
    }
    
    /// Set location
    func setLocation(_ location: Location?) {
        preferences.location = location
        autoSave()
    }
    
    /// Set grace period
    func setGracePeriod(_ period: TimeInterval?) {
        preferences.gracePeriod = period
        autoSave()
    }
    
    /// Set motivation method
    func setMotivationMethod(_ method: MotivationMethod?) {
        preferences.motivationMethod = method
        autoSave()
    }
    
    // MARK: - Convenience Getters
    
    /// Get wake up time for today
    func getTodaysWakeUpTime() -> Date? {
        let today = Calendar.current.component(.weekday, from: Date())
        let weekday = weekdayFromCalendarWeekday(today)
        
        // Priority: specific day > everyday > weekdays/weekends
        if let specificTime = preferences.wakeUpTimes[weekday] {
            return specificTime
        } else if let everydayTime = preferences.everydayTime {
            return everydayTime
        } else if Weekday.weekdays.contains(weekday), let weekdaysTime = preferences.weekdaysTime {
            return weekdaysTime
        } else if Weekday.weekends.contains(weekday), let weekendsTime = preferences.weekendsTime {
            return weekendsTime
        }
        
        return nil
    }
    
    /// Check if any wake up time is configured
    func hasAnyWakeUpTime() -> Bool {
        return preferences.hasAnyWakeUpTime()
    }
    
    // MARK: - Helpers
    
    private func weekdayFromCalendarWeekday(_ calendarWeekday: Int) -> Weekday {
        switch calendarWeekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .monday
        }
    }
}