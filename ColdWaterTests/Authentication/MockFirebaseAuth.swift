import Combine
import FirebaseAuth
@testable import ColdWater

// MARK: - Protocol Definitions

/// Protocol for Firebase User functionality we need to test
protocol FirebaseUserProtocol {
    var uid: String { get }
    var email: String? { get }
    var isAnonymous: Bool { get }
    var providerData: [UserInfo] { get }
}

/// Protocol for Firebase AuthDataResult functionality
protocol FirebaseAuthDataResultProtocol {
    var user: FirebaseUserProtocol { get }
}

/// Protocol for Firebase Auth functionality we need to test
protocol FirebaseAuthProtocol {
    var currentUser: FirebaseUserProtocol? { get }
    func createUser(withEmail email: String, password: String, completion: @escaping (FirebaseAuthDataResultProtocol?, Error?) -> Void)
    func signIn(withEmail email: String, password: String, completion: @escaping (FirebaseAuthDataResultProtocol?, Error?) -> Void)
    func signInAnonymously(completion: @escaping (FirebaseAuthDataResultProtocol?, Error?) -> Void)
    func signIn(with credential: AuthCredential, completion: @escaping (FirebaseAuthDataResultProtocol?, Error?) -> Void)
    func signOut() throws
    func addStateDidChangeListener(_ listener: @escaping (Auth, FirebaseUserProtocol?) -> Void) -> AuthStateDidChangeListenerHandle
}

// MARK: - Mock Objects

/// Mock Firebase User for testing
class MockFirebaseUser: FirebaseUserProtocol {
    let uid: String
    let email: String?
    let isAnonymous: Bool
    let providerData: [UserInfo]
    
    init(uid: String, email: String? = nil, isAnonymous: Bool = false, providerData: [UserInfo] = []) {
        self.uid = uid
        self.email = email
        self.isAnonymous = isAnonymous
        self.providerData = providerData
    }
}

/// Mock provider data for testing login types
class MockUserInfo: NSObject, UserInfo {
    let mockProviderID: String
    
    var providerID: String { mockProviderID }
    var uid: String { "mock_uid" }
    var displayName: String? { nil }
    var photoURL: URL? { nil }
    var email: String? { nil }
    var phoneNumber: String? { nil }
    
    init(providerID: String) {
        self.mockProviderID = providerID
    }
}

/// Mock AuthDataResult for testing
class MockFirebaseAuthDataResult: FirebaseAuthDataResultProtocol {
    let user: FirebaseUserProtocol
    
    init(user: FirebaseUserProtocol) {
        self.user = user
    }
}

/// Mock Firebase Auth implementation
class MockFirebaseAuth: FirebaseAuthProtocol {
    var mockCurrentUser: FirebaseUserProtocol?
    var shouldFailNextOperation = false
    var shouldThrowOnSignOut = false
    var mockError: Error?
    var stateChangeListeners: [(Auth, FirebaseUserProtocol?) -> Void] = []
    
    var currentUser: FirebaseUserProtocol? {
        return mockCurrentUser
    }
    
    func createUser(withEmail email: String, password: String, completion: @escaping (FirebaseAuthDataResultProtocol?, Error?) -> Void) {
        DispatchQueue.main.async {
            if self.shouldFailNextOperation {
                completion(nil, self.mockError ?? NSError(domain: "MockAuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock error"]))
                self.shouldFailNextOperation = false
                return
            }
            
            let mockUser = MockFirebaseUser(uid: "mock_uid_\(email)", email: email, isAnonymous: false)
            let mockResult = MockFirebaseAuthDataResult(user: mockUser)
            self.mockCurrentUser = mockUser
            completion(mockResult, nil)
        }
    }
    
    func signIn(withEmail email: String, password: String, completion: @escaping (FirebaseAuthDataResultProtocol?, Error?) -> Void) {
        DispatchQueue.main.async {
            if self.shouldFailNextOperation {
                completion(nil, self.mockError ?? NSError(domain: "MockAuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock error"]))
                self.shouldFailNextOperation = false
                return
            }
            
            let mockUser = MockFirebaseUser(uid: "mock_uid_\(email)", email: email, isAnonymous: false)
            let mockResult = MockFirebaseAuthDataResult(user: mockUser)
            self.mockCurrentUser = mockUser
            completion(mockResult, nil)
        }
    }
    
    func signInAnonymously(completion: @escaping (FirebaseAuthDataResultProtocol?, Error?) -> Void) {
        DispatchQueue.main.async {
            if self.shouldFailNextOperation {
                completion(nil, self.mockError ?? NSError(domain: "MockAuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock error"]))
                self.shouldFailNextOperation = false
                return
            }
            
            let mockUser = MockFirebaseUser(uid: "anonymous_uid", email: nil, isAnonymous: true)
            let mockResult = MockFirebaseAuthDataResult(user: mockUser)
            self.mockCurrentUser = mockUser
            completion(mockResult, nil)
        }
    }
    
    func signIn(with credential: AuthCredential, completion: @escaping (FirebaseAuthDataResultProtocol?, Error?) -> Void) {
        DispatchQueue.main.async {
            if self.shouldFailNextOperation {
                completion(nil, self.mockError ?? NSError(domain: "MockAuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock error"]))
                self.shouldFailNextOperation = false
                return
            }
            
            let providerData = [MockUserInfo(providerID: "google.com")]
            let mockUser = MockFirebaseUser(uid: "google_uid", email: "user@gmail.com", isAnonymous: false, providerData: providerData)
            let mockResult = MockFirebaseAuthDataResult(user: mockUser)
            self.mockCurrentUser = mockUser
            completion(mockResult, nil)
        }
    }
    
    func signOut() throws {
        if shouldThrowOnSignOut {
            throw NSError(domain: "MockAuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sign out failed"])
        }
        let previousUser = mockCurrentUser
        mockCurrentUser = nil
        
        // Notify state change listeners
        stateChangeListeners.forEach { listener in
            listener(Auth.auth(), nil)
        }
    }
    
    func addStateDidChangeListener(_ listener: @escaping (Auth, FirebaseUserProtocol?) -> Void) -> AuthStateDidChangeListenerHandle {
        stateChangeListeners.append(listener)
        return NSObject() // Return a dummy handle
    }
    
    func simulateStateChange(user: FirebaseUserProtocol?) {
        mockCurrentUser = user
        stateChangeListeners.forEach { listener in
            listener(Auth.auth(), user)
        }
    }
}

// MARK: - Mock AppState

/// Mock AppState for testing WelcomeViewModel
class MockAppState: AppStateProtocol {
    @Published var currentUser: CWUser?
    
    /// Track state changes for testing
    private(set) var userChangeHistory: [CWUser?] = []
    
    var currentUserPublisher: Published<CWUser?>.Publisher {
        $currentUser
    }
    
    init(currentUser: CWUser? = nil) {
        self.currentUser = currentUser
        
        // Track all user changes
        $currentUser
            .sink { [weak self] user in
                self?.userChangeHistory.append(user)
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    /// Reset tracking history
    func resetHistory() {
        userChangeHistory.removeAll()
    }
}

// MARK: - Authentication Status Test Helpers

extension AuthenticationStatus {
    static let testSuccessStatus = AuthenticationStatus(title: "Successful", message: "Authentication successful")
    static let testErrorStatus = AuthenticationStatus(title: "Error", message: "Test error")
}
