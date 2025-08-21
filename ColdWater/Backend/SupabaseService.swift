import Foundation
import Supabase
import FirebaseAuth
import Combine

// Resolve User ambiguity
typealias FirebaseUser = FirebaseAuth.User

/// Service for managing Supabase database operations with Firebase authentication
class SupabaseService: Resettable, ObservableObject {
    static let shared = SupabaseService()
    
    private var client: SupabaseClient?
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var isConnected = false
    @Published private(set) var isLoading = false
    
    private init() {
        SingletonRegistry.shared.register(self)
        setupClient()
        observeAuthState()
    }
    
    /// Reset service state when user signs out
    func reset() {
        isConnected = false
        isLoading = false
        cancellables.removeAll()
        // Note: Don't recreate client here, just reset auth state
    }
    
    // MARK: - Setup
    
    private func setupClient() {
        // TODO: Replace with your Supabase project URL and anon key
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlqd3RrbHdnc21wY3RhZW9udGZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTg3MTMsImV4cCI6MjA3MDkzNDcxM30.xNrYkx43lzcux3Xw8PTZRmsYeXN6ea8L4ITNNVEXBoE"
        guard let url = URL(string: "https://yjwtklwgsmpctaeontfx.supabase.co") else {
            print("❌ SupabaseService: Invalid Supabase configuration")
            return
        }
        
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
        
        print("✅ SupabaseService: Client initialized")
    }
    
    private func observeAuthState() {
        // Listen to Firebase auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            Task { @MainActor in
                if let user = user {
                    await self?.authenticateWithFirebase(user: user)
                } else {
                    self?.isConnected = false
                }
            }
        }
    }
    
    // MARK: - Authentication
    
    @MainActor
    private func authenticateWithFirebase(user: FirebaseUser) async {
        isLoading = true
        
        do {
            // Get Firebase ID token
            let idToken = try await user.getIDToken()
            
            // For now, just set a custom header or use the token directly
            // The exact implementation depends on your Supabase setup
            // You might need to configure this in your database RLS policies
            
            // Set the auth token for subsequent requests
            // This is a simplified approach - you may need to customize based on your setup
            
            isConnected = true
            print("✅ SupabaseService: Ready to use with Firebase token")
            print("Firebase UID: \(user.uid)")
            
        } catch {
            print("❌ SupabaseService: Authentication setup failed: \(error)")
            isConnected = false
        }
        
        isLoading = false
    }
    
    // MARK: - Todos Operations (for testing Supabase integration)
    
    /// Test database connectivity using existing todos table
    func testDatabaseConnection() async throws {
        guard let client = client else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            print("🔍 SupabaseService: Testing database connection with todos table...")
            
            // Try to fetch from todos table to verify connection
            let _: [Todo] = try await client
                .from("todos")
                .select()
                .limit(1)
                .execute()
                .value
            
            print("✅ SupabaseService: Database connection verified")
        } catch {
            print("❌ SupabaseService: Database test failed: \(error)")
            throw SupabaseError.networkError(error)
        }
    }
    
    /// Fetch all todos from Supabase
    func fetchTodos() async throws -> [Todo] {
        guard let client = client else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            print("🔍 SupabaseService: Fetching todos...")
            
            let todos: [Todo] = try await client
                .from("todos")
                .select()
                .order("id")
                .execute()
                .value
            
            print("✅ SupabaseService: Fetched \(todos.count) todos")
            return todos
            
        } catch {
            print("❌ SupabaseService: Fetch todos error: \(error)")
            throw SupabaseError.networkError(error)
        }
    }
    
    /// Create a new todo
    func createTodo(title: String) async throws -> Todo {
        guard let client = client else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            print("🔍 SupabaseService: Creating todo with title: \(title)")
            
            let newTodo = TodoInsert(title: title)
            
            let response: [Todo] = try await client
                .from("todos")
                .insert(newTodo)
                .select()
                .execute()
                .value
            
            guard let todo = response.first else {
                throw SupabaseError.decodingError(NSError(domain: "TodoCreation", code: -1))
            }
            
            print("✅ SupabaseService: Created todo with ID: \(todo.id)")
            return todo
            
        } catch {
            print("❌ SupabaseService: Create todo error: \(error)")
            throw SupabaseError.networkError(error)
        }
    }
    
    /// Update an existing todo
    func updateTodo(id: Int, title: String) async throws {
        guard let client = client else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            print("🔍 SupabaseService: Updating todo \(id) with title: \(title)")
            
            let update = TodoUpdate(title: title)
            
            try await client
                .from("todos")
                .update(update)
                .eq("id", value: id)
                .execute()
            
            print("✅ SupabaseService: Updated todo \(id)")
            
        } catch {
            print("❌ SupabaseService: Update todo error: \(error)")
            throw SupabaseError.networkError(error)
        }
    }
    
    /// Delete a todo
    func deleteTodo(id: Int) async throws {
        guard let client = client else {
            throw SupabaseError.notAuthenticated
        }
        
        do {
            print("🔍 SupabaseService: Deleting todo \(id)")
            
            try await client
                .from("todos")
                .delete()
                .eq("id", value: id)
                .execute()
            
            print("✅ SupabaseService: Deleted todo \(id)")
            
        } catch {
            print("❌ SupabaseService: Delete todo error: \(error)")
            throw SupabaseError.networkError(error)
        }
    }
    
    // MARK: - Real-time Subscriptions
    
    /// Subscribe to user preferences changes
    func subscribeToUserPreferences() -> AsyncStream<UserPreferences> {
        guard let client = client,
              let firebaseUser = Auth.auth().currentUser else {
            return AsyncStream { _ in }
        }
        
        return AsyncStream { continuation in
            // For now, return empty stream - we'll implement real-time later
            // The real-time API may vary depending on Supabase SDK version
            continuation.finish()
        }
    }
}

// MARK: - Database Models

/// Database row structure for user_preferences table
struct UserPreferencesRow: Codable {
    let firebaseUid: String
    let wakeUpTimes: [String: String]? // JSON encoded weekday -> time
    let everydayTime: String?
    let weekdaysTime: String?
    let weekendsTime: String?
    let wakeUpMethod: String?
    let stepGoal: Int?
    let locationLatitude: Double?
    let locationLongitude: Double?
    let locationRadius: Double?
    let locationName: String?
    let gracePeriod: Double?
    let motivationMethod: String?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case firebaseUid = "firebase_uid"
        case wakeUpTimes = "wake_up_times"
        case everydayTime = "everyday_time"
        case weekdaysTime = "weekdays_time"
        case weekendsTime = "weekends_time"
        case wakeUpMethod = "wake_up_method"
        case stepGoal = "step_goal"
        case locationLatitude = "location_latitude"
        case locationLongitude = "location_longitude"
        case locationRadius = "location_radius"
        case locationName = "location_name"
        case gracePeriod = "grace_period"
        case motivationMethod = "motivation_method"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(firebaseUid: String, preferences: UserPreferences) {
        self.firebaseUid = firebaseUid
        
        // Convert wake up times to JSON-serializable format
        var wakeUpTimesDict: [String: String] = [:]
        let formatter = ISO8601DateFormatter()
        for (weekday, date) in preferences.wakeUpTimes {
            wakeUpTimesDict[weekday.rawValue] = formatter.string(from: date)
        }
        self.wakeUpTimes = wakeUpTimesDict.isEmpty ? nil : wakeUpTimesDict
        
        self.everydayTime = preferences.everydayTime.map { formatter.string(from: $0) }
        self.weekdaysTime = preferences.weekdaysTime.map { formatter.string(from: $0) }
        self.weekendsTime = preferences.weekendsTime.map { formatter.string(from: $0) }
        self.wakeUpMethod = preferences.wakeUpMethod?.rawValue
        self.stepGoal = preferences.stepGoal
        self.locationLatitude = preferences.location?.latitude
        self.locationLongitude = preferences.location?.longitude
        self.locationRadius = preferences.location?.geofenceRadius
        self.locationName = preferences.location?.name
        self.gracePeriod = preferences.gracePeriod
        self.motivationMethod = preferences.motivationMethod?.rawValue
        self.createdAt = nil // Will be set by database
        self.updatedAt = nil // Will be set by database
    }
    
    func toUserPreferences() -> UserPreferences {
        var preferences = UserPreferences()
        let formatter = ISO8601DateFormatter()
        
        // Convert wake up times back to Date objects
        if let wakeUpTimesDict = wakeUpTimes {
            for (weekdayString, timeString) in wakeUpTimesDict {
                if let weekday = Weekday(rawValue: weekdayString),
                   let date = formatter.date(from: timeString) {
                    preferences.wakeUpTimes[weekday] = date
                }
            }
        }
        
        preferences.everydayTime = everydayTime.flatMap { formatter.date(from: $0) }
        preferences.weekdaysTime = weekdaysTime.flatMap { formatter.date(from: $0) }
        preferences.weekendsTime = weekendsTime.flatMap { formatter.date(from: $0) }
        preferences.wakeUpMethod = wakeUpMethod.flatMap { WakeUpMethod(rawValue: $0) }
        preferences.stepGoal = stepGoal
        
        if let lat = locationLatitude,
           let lng = locationLongitude,
           let radius = locationRadius,
           let name = locationName {
            preferences.location = Location(
                latitude: lat,
                longitude: lng,
                geofenceRadius: radius,
                name: name
            )
        }
        
        preferences.gracePeriod = gracePeriod
        preferences.motivationMethod = motivationMethod.flatMap { MotivationMethod(rawValue: $0) }
        
        return preferences
    }
}

// MARK: - Errors

enum SupabaseError: Error, LocalizedError {
    case notAuthenticated
    case invalidConfiguration
    case networkError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated with Firebase"
        case .invalidConfiguration:
            return "Invalid Supabase configuration"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data decoding error: \(error.localizedDescription)"
        }
    }
}
