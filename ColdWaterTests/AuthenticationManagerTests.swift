import XCTest
import Combine
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
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

// MARK: - Mock Implementations

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

// MARK: - Testable Authentication Manager

/// Testable version of AuthenticationManager with dependency injection
class TestableAuthenticationManager: AuthenticationServiceProtocol, ObservableObject {
    @Published private(set) var currentUser: CWUser?
    @Published private(set) var isLoading: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let mockAuth: MockFirebaseAuth
    
    var isUserAuthenticated: Bool {
        return mockAuth.currentUser != nil
    }
    
    var isAnonymous: Bool {
        return mockAuth.currentUser?.isAnonymous ?? false
    }
    
    init(mockAuth: MockFirebaseAuth) {
        self.mockAuth = mockAuth
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        _ = mockAuth.addStateDidChangeListener { [weak self] (_, firebaseUser) in
            guard let self = self else { return }
            
            if let firebaseUser = firebaseUser {
                let loginType = self.determineLoginType(from: firebaseUser)
                let user = CWUser(
                    id: firebaseUser.uid,
                    email: firebaseUser.email,
                    loginType: loginType,
                    isAnonymous: firebaseUser.isAnonymous
                )
                self.currentUser = user
            } else {
                self.currentUser = nil
            }
        }
    }
    
    private func determineLoginType(from firebaseUser: FirebaseUserProtocol) -> CWUser.LoginType {
        if firebaseUser.isAnonymous {
            return .guest
        }
        
        if !firebaseUser.providerData.isEmpty {
            let providerId = firebaseUser.providerData[0].providerID
            switch providerId {
            case "google.com":
                return .google
            case "password":
                return .email
            default:
                return .guest
            }
        }
        
        return .guest
    }
    
    func login(email: String, password: String) -> Future<CWUser?, Error> {
        isLoading = true
        return Future { [weak self] promise in
            self?.mockAuth.signIn(withEmail: email, password: password) { (result, error) in
                self?.isLoading = false
                
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let result = result else {
                    promise(.failure(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"])))
                    return
                }
                
                let user = CWUser(
                    id: result.user.uid,
                    email: result.user.email,
                    loginType: CWUser.LoginType.email,
                    isAnonymous: false
                )
                promise(.success(user))
            }
        }
    }
    
    func signUp(email: String, password: String) -> Future<CWUser?, Error> {
        isLoading = true
        return Future { [weak self] promise in
            self?.mockAuth.createUser(withEmail: email, password: password) { (result, error) in
                self?.isLoading = false
                
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let result = result else {
                    promise(.failure(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"])))
                    return
                }
                
                let user = CWUser(
                    id: result.user.uid,
                    email: result.user.email,
                    loginType: CWUser.LoginType.email,
                    isAnonymous: false
                )
                promise(.success(user))
            }
        }
    }
    
    func signInAnonymously() -> Future<CWUser?, Error> {
        isLoading = true
        return Future { [weak self] promise in
            self?.mockAuth.signInAnonymously { (result, error) in
                self?.isLoading = false
                
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let result = result else {
                    promise(.failure(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"])))
                    return
                }
                
                let user = CWUser(
                    id: result.user.uid,
                    email: result.user.email,
                    loginType: CWUser.LoginType.guest,
                    isAnonymous: true
                )
                promise(.success(user))
            }
        }
    }
    
    func signOut() -> Future<Void, Error> {
        return Future { [weak self] promise in
            do {
                try self?.mockAuth.signOut()
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
    }
    
    // Simplified implementations for methods not directly testable without more complex mocking
    func googleSignIn(presentingViewController: UIViewController) -> Future<CWUser?, Error> {
        return Future { promise in
            promise(.failure(NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google Sign In not implemented in tests"])))
        }
    }
    
    func appleSignIn(presentingViewController: UIViewController) -> Future<CWUser?, Error> {
        return Future { promise in
            promise(.failure(NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Sign In not implemented in tests"])))
        }
    }
    
    func convertAnonymousUserWithEmail(email: String, password: String) -> Future<CWUser?, Error> {
        return Future { promise in
            promise(.failure(NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Convert anonymous not implemented in tests"])))
        }
    }
    
    func convertAnonymousUserWithGoogle(presentingViewController: UIViewController) async throws -> CWUser {
        throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Convert anonymous Google not implemented in tests"])
    }
    
    func deleteCurrentAccount() -> Future<Void, Error> {
        return Future { promise in
            promise(.failure(NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Delete account not implemented in tests"])))
        }
    }
}

// MARK: - Unit Tests

class AuthenticationManagerTests: XCTestCase {
    
    var sut: TestableAuthenticationManager!
    var mockAuth: MockFirebaseAuth!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockAuth = MockFirebaseAuth()
        sut = TestableAuthenticationManager(mockAuth: mockAuth)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        sut = nil
        mockAuth = nil
        cancellables = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Authentication State Tests
    
    func test_isUserAuthenticated_WhenNoCurrentUser_ReturnsFalse() {
        // Arrange
        mockAuth.mockCurrentUser = nil
        
        // Act & Assert
        XCTAssertFalse(sut.isUserAuthenticated)
    }
    
    func test_isUserAuthenticated_WhenCurrentUserExists_ReturnsTrue() {
        // Arrange
        let mockUser = MockFirebaseUser(uid: "test_uid", email: "test@example.com")
        mockAuth.mockCurrentUser = mockUser
        
        // Act & Assert
        XCTAssertTrue(sut.isUserAuthenticated)
    }
    
    func test_isAnonymous_WhenUserIsAnonymous_ReturnsTrue() {
        // Arrange
        let mockUser = MockFirebaseUser(uid: "test_uid", email: nil, isAnonymous: true)
        mockAuth.mockCurrentUser = mockUser
        
        // Act & Assert
        XCTAssertTrue(sut.isAnonymous)
    }
    
    func test_isAnonymous_WhenUserIsNotAnonymous_ReturnsFalse() {
        // Arrange
        let mockUser = MockFirebaseUser(uid: "test_uid", email: "test@example.com", isAnonymous: false)
        mockAuth.mockCurrentUser = mockUser
        
        // Act & Assert
        XCTAssertFalse(sut.isAnonymous)
    }
    
    // MARK: - Login Tests
    
    func test_login_WithValidCredentials_ReturnsSuccessUser() {
        // Arrange
        let expectation = XCTestExpectation(description: "Login should succeed")
        let testEmail = "test@example.com"
        let testPassword = "password123"
        var resultUser: CWUser?
        var resultError: Error?
        
        // Act
        sut.login(email: testEmail, password: testPassword)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        resultError = error
                    }
                    expectation.fulfill()
                },
                receiveValue: { user in
                    resultUser = user
                }
            )
            .store(in: &cancellables)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(resultError)
        XCTAssertNotNil(resultUser)
        XCTAssertEqual(resultUser?.email, testEmail)
        XCTAssertEqual(resultUser?.loginType, .email)
        XCTAssertFalse(resultUser?.isAnonymous ?? true)
    }
    
    func test_login_WithInvalidCredentials_ReturnsError() {
        // Arrange
        let expectation = XCTestExpectation(description: "Login should fail")
        mockAuth.shouldFailNextOperation = true
        mockAuth.mockError = NSError(domain: "AuthError", code: 17009, userInfo: [NSLocalizedDescriptionKey: "Invalid email/password"])
        
        var resultUser: CWUser?
        var resultError: Error?
        
        // Act
        sut.login(email: "invalid@example.com", password: "wrongpassword")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        resultError = error
                    }
                    expectation.fulfill()
                },
                receiveValue: { user in
                    resultUser = user
                }
            )
            .store(in: &cancellables)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(resultError)
        XCTAssertNil(resultUser)
    }
    
    func test_login_SetsIsLoadingToTrueDuringOperation() {
        // Arrange
        let expectation = XCTestExpectation(description: "Loading state should be updated")
        
        // Act
        XCTAssertFalse(sut.isLoading) // Initially false
        
        sut.login(email: "test@example.com", password: "password")
            .sink(
                receiveCompletion: { _ in
                    expectation.fulfill()
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Assert
        XCTAssertTrue(sut.isLoading) // Should be true during operation
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(sut.isLoading) // Should be false after completion
    }
    
    // MARK: - Sign Up Tests
    
    func test_signUp_WithValidCredentials_ReturnsSuccessUser() {
        // Arrange
        let expectation = XCTestExpectation(description: "Sign up should succeed")
        let testEmail = "newuser@example.com"
        let testPassword = "newpassword123"
        var resultUser: CWUser?
        var resultError: Error?
        
        // Act
        sut.signUp(email: testEmail, password: testPassword)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        resultError = error
                    }
                    expectation.fulfill()
                },
                receiveValue: { user in
                    resultUser = user
                }
            )
            .store(in: &cancellables)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(resultError)
        XCTAssertNotNil(resultUser)
        XCTAssertEqual(resultUser?.email, testEmail)
        XCTAssertEqual(resultUser?.loginType, .email)
        XCTAssertFalse(resultUser?.isAnonymous ?? true)
    }
    
    func test_signUp_WithExistingEmail_ReturnsError() {
        // Arrange
        let expectation = XCTestExpectation(description: "Sign up should fail")
        mockAuth.shouldFailNextOperation = true
        mockAuth.mockError = NSError(domain: "AuthError", code: 17007, userInfo: [NSLocalizedDescriptionKey: "Email already in use"])
        
        var resultUser: CWUser?
        var resultError: Error?
        
        // Act
        sut.signUp(email: "existing@example.com", password: "password123")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        resultError = error
                    }
                    expectation.fulfill()
                },
                receiveValue: { user in
                    resultUser = user
                }
            )
            .store(in: &cancellables)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(resultError)
        XCTAssertNil(resultUser)
    }
    
    // MARK: - Anonymous Sign In Tests
    
    func test_signInAnonymously_ReturnsAnonymousUser() {
        // Arrange
        let expectation = XCTestExpectation(description: "Anonymous sign in should succeed")
        var resultUser: CWUser?
        var resultError: Error?
        
        // Act
        sut.signInAnonymously()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        resultError = error
                    }
                    expectation.fulfill()
                },
                receiveValue: { user in
                    resultUser = user
                }
            )
            .store(in: &cancellables)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(resultError)
        XCTAssertNotNil(resultUser)
        XCTAssertEqual(resultUser?.loginType, .guest)
        XCTAssertTrue(resultUser?.isAnonymous ?? false)
        XCTAssertNil(resultUser?.email)
    }
    
    func test_signInAnonymously_WhenFails_ReturnsError() {
        // Arrange
        let expectation = XCTestExpectation(description: "Anonymous sign in should fail")
        mockAuth.shouldFailNextOperation = true
        mockAuth.mockError = NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Anonymous sign in failed"])
        
        var resultUser: CWUser?
        var resultError: Error?
        
        // Act
        sut.signInAnonymously()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        resultError = error
                    }
                    expectation.fulfill()
                },
                receiveValue: { user in
                    resultUser = user
                }
            )
            .store(in: &cancellables)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(resultError)
        XCTAssertNil(resultUser)
    }
    
    // MARK: - Sign Out Tests
    
    func test_signOut_WhenSuccessful_CompletesWithoutError() {
        // Arrange
        let expectation = XCTestExpectation(description: "Sign out should succeed")
        let mockUser = MockFirebaseUser(uid: "test_uid", email: "test@example.com")
        mockAuth.mockCurrentUser = mockUser
        
        var resultError: Error?
        
        // Act
        sut.signOut()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        resultError = error
                    }
                    expectation.fulfill()
                },
                receiveValue: { }
            )
            .store(in: &cancellables)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(resultError)
        XCTAssertNil(mockAuth.mockCurrentUser)
    }
    
    func test_signOut_WhenFails_ReturnsError() {
        // Arrange
        let expectation = XCTestExpectation(description: "Sign out should fail")
        mockAuth.shouldThrowOnSignOut = true
        
        var resultError: Error?
        
        // Act
        sut.signOut()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        resultError = error
                    }
                    expectation.fulfill()
                },
                receiveValue: { }
            )
            .store(in: &cancellables)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(resultError)
    }
    
    // MARK: - Auth State Change Tests
    
    func test_authStateChange_WhenUserSignsIn_UpdatesCurrentUser() {
        // Arrange
        let expectation = XCTestExpectation(description: "Current user should be updated")
        let mockUser = MockFirebaseUser(uid: "new_user_uid", email: "newuser@example.com", isAnonymous: false)
        
        // Monitor currentUser changes
        sut.$currentUser
            .dropFirst() // Skip initial nil value
            .sink { user in
                if user != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Act
        mockAuth.simulateStateChange(user: mockUser)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(sut.currentUser)
        XCTAssertEqual(sut.currentUser?.id, "new_user_uid")
        XCTAssertEqual(sut.currentUser?.email, "newuser@example.com")
    }
    
    func test_authStateChange_WhenUserSignsOut_ClearsCurrentUser() {
        // Arrange
        let expectation = XCTestExpectation(description: "Current user should be cleared")
        let mockUser = MockFirebaseUser(uid: "test_uid", email: "test@example.com")
        
        // First set a user
        mockAuth.simulateStateChange(user: mockUser)
        XCTAssertNotNil(sut.currentUser)
        
        // Monitor currentUser changes for sign out
        sut.$currentUser
            .dropFirst() // Skip the initial state
            .sink { user in
                if user == nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Act - simulate sign out
        mockAuth.simulateStateChange(user: nil)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(sut.currentUser)
    }
    
    // MARK: - Login Type Determination Tests
    
    func test_determineLoginType_WithGoogleProvider_ReturnsGoogle() {
        // Arrange
        let expectation = XCTestExpectation(description: "Google login type should be determined")
        let googleProvider = MockUserInfo(providerID: "google.com")
        let mockUser = MockFirebaseUser(uid: "google_uid", email: "user@gmail.com", isAnonymous: false, providerData: [googleProvider])
        
        sut.$currentUser
            .dropFirst()
            .sink { user in
                if user?.loginType == .google {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Act
        mockAuth.simulateStateChange(user: mockUser)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(sut.currentUser?.loginType, .google)
    }
    
    func test_determineLoginType_WithPasswordProvider_ReturnsEmail() {
        // Arrange
        let expectation = XCTestExpectation(description: "Email login type should be determined")
        let passwordProvider = MockUserInfo(providerID: "password")
        let mockUser = MockFirebaseUser(uid: "email_uid", email: "user@example.com", isAnonymous: false, providerData: [passwordProvider])
        
        sut.$currentUser
            .dropFirst()
            .sink { user in
                if user?.loginType == .email {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Act
        mockAuth.simulateStateChange(user: mockUser)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(sut.currentUser?.loginType, .email)
    }
    
    func test_determineLoginType_WithAnonymousUser_ReturnsGuest() {
        // Arrange
        let expectation = XCTestExpectation(description: "Guest login type should be determined")
        let mockUser = MockFirebaseUser(uid: "anon_uid", email: nil, isAnonymous: true)
        
        sut.$currentUser
            .dropFirst()
            .sink { user in
                if user?.loginType == .guest {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Act
        mockAuth.simulateStateChange(user: mockUser)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(sut.currentUser?.loginType, .guest)
    }
    
    // MARK: - Edge Cases and Error Handling Tests
    
    func test_login_WithEmptyEmail_HandlesGracefully() {
        // Arrange
        let expectation = XCTestExpectation(description: "Empty email should be handled")
        mockAuth.shouldFailNextOperation = true
        mockAuth.mockError = NSError(domain: "AuthError", code: 17008, userInfo: [NSLocalizedDescriptionKey: "Invalid email"])
        
        var resultError: Error?
        
        // Act
        sut.login(email: "", password: "password123")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        resultError = error
                    }
                    expectation.fulfill()
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(resultError)
    }
    
    func test_signUp_WithWeakPassword_ReturnsError() {
        // Arrange
        let expectation = XCTestExpectation(description: "Weak password should be rejected")
        mockAuth.shouldFailNextOperation = true
        mockAuth.mockError = NSError(domain: "AuthError", code: 17026, userInfo: [NSLocalizedDescriptionKey: "Password is too weak"])
        
        var resultError: Error?
        
        // Act
        sut.signUp(email: "test@example.com", password: "123")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        resultError = error
                    }
                    expectation.fulfill()
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(resultError)
    }
    
    // MARK: - Performance Tests
    
    func test_loginPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Login performance test")
            
            sut.login(email: "test@example.com", password: "password123")
                .sink(
                    receiveCompletion: { _ in expectation.fulfill() },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
}

// MARK: - Test Helper Methods

extension AuthenticationManagerTests {
    
    /// Helper method to create a mock user for testing
    private func createMockUser(uid: String = "test_uid",
                               email: String? = "test@example.com",
                               isAnonymous: Bool = false,
                               loginType: CWUser.LoginType = .email) -> CWUser {
        return CWUser(id: uid, email: email, loginType: loginType, isAnonymous: isAnonymous)
    }
    
    /// Helper method to wait for async operations
    private func waitForAsyncOperation(timeout: TimeInterval = 1.0,
                                     operation: () -> Void) {
        let expectation = XCTestExpectation(description: "Async operation")
        operation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
    }
}
