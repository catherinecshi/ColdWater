import XCTest
import Combine
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
@testable import ColdWater

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
