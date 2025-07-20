import XCTest
import Combine
@testable import ColdWater

@MainActor
class SignUpViewTests: XCTestCase {
    
    // MARK: - Properties
    private var viewModel: SignUpViewModel!
    private var mockAppState: MockAppState!
    private var mockAuth: MockFirebaseAuth!
    private var testableAuthManager: TestableAuthenticationManager!
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        mockAuth = MockFirebaseAuth()
        testableAuthManager = TestableAuthenticationManager(mockAuth: mockAuth)
        mockAppState = MockAppState()
        cancellables = Set<AnyCancellable>()
        
        viewModel = SignUpViewModel(
            state: mockAppState,
            authManager: testableAuthManager
        )
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        cancellables = nil
        viewModel = nil
        mockAppState = nil
        testableAuthManager = nil
        mockAuth = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    func testInitialization() {
        // Given & When - initialization happens in setUp()
        
        // Then
        XCTAssertEqual(viewModel.email, "", "Email should be empty on initialization")
        XCTAssertEqual(viewModel.password, "", "Password should be empty on initialization")
        XCTAssertEqual(viewModel.passwordConfirmation, "", "Password confirmation should be empty on initialization")
        XCTAssertNil(viewModel.statusViewModel, "Status should be nil on initialization")
        XCTAssertTrue(viewModel.passwordsMatch, "Passwords should match initially (both empty)")
        XCTAssertNotNil(viewModel.state, "State should not be nil")
        XCTAssertIdentical(viewModel.state as? MockAppState, mockAppState, "State should be the injected mock")
    }
    
    // MARK: - Property Binding Tests
    func testEmailPropertyBinding() {
        // Given
        let testEmail = "test@example.com"
        
        // When
        viewModel.email = testEmail
        
        // Then
        XCTAssertEqual(viewModel.email, testEmail, "Email property should be correctly set")
    }
    
    func testPasswordPropertyBinding() {
        // Given
        let testPassword = "testPassword123"
        
        // When
        viewModel.password = testPassword
        
        // Then
        XCTAssertEqual(viewModel.password, testPassword, "Password property should be correctly set")
    }
    
    func testPasswordConfirmationPropertyBinding() {
        // Given
        let testPasswordConfirmation = "testPassword123"
        
        // When
        viewModel.passwordConfirmation = testPasswordConfirmation
        
        // Then
        XCTAssertEqual(viewModel.passwordConfirmation, testPasswordConfirmation, "Password confirmation property should be correctly set")
    }
    
    // MARK: - Password Validation Tests
    func testPasswordsMatchLogic() {
        // Test the actual business logic without async complexity
        
        // When both empty - should match
        viewModel.password = ""
        viewModel.passwordConfirmation = ""
        // Give time for Combine to process
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertTrue(viewModel.passwordsMatch, "Empty passwords should match")
        
        // When confirmation is empty - should match
        viewModel.password = "password123"
        viewModel.passwordConfirmation = ""
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertTrue(viewModel.passwordsMatch, "Should match when confirmation is empty")
        
        // When identical - should match
        viewModel.passwordConfirmation = "password123"
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertTrue(viewModel.passwordsMatch, "Identical passwords should match")
        
        // When different - should not match
        viewModel.passwordConfirmation = "differentPassword"
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertFalse(viewModel.passwordsMatch, "Different passwords should not match")
    }
    
    // MARK: - Input Validation Tests
    func testSignUpFailsWithEmptyEmail() {
        // Given
        let expectation = expectation(description: "Should fail with empty email")
        
        viewModel.email = ""
        viewModel.password = "password123"
        viewModel.passwordConfirmation = "password123"
        
        // When
        viewModel.$statusViewModel
            .dropFirst()
            .sink { status in
                XCTAssertNotNil(status, "Status should not be nil")
                XCTAssertEqual(status?.title, "Error", "Should be error status")
                XCTAssertEqual(status?.message, "Please enter your email address", "Should show email error message")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.signUp()
        
        // Then
        waitForExpectations(timeout: 1.0)
    }
    
    func testSignUpFailsWithEmptyPassword() {
        // Given
        let expectation = expectation(description: "Should fail with empty password")
        
        viewModel.email = "test@example.com"
        viewModel.password = ""
        viewModel.passwordConfirmation = ""
        
        // When
        viewModel.$statusViewModel
            .dropFirst()
            .sink { status in
                XCTAssertNotNil(status, "Status should not be nil")
                XCTAssertEqual(status?.title, "Error", "Should be error status")
                XCTAssertEqual(status?.message, "Please enter a password", "Should show password error message")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.signUp()
        
        // Then
        waitForExpectations(timeout: 1.0)
    }
    
    func testSignUpFailsWithPasswordMismatch() {
        // Given
        let expectation = expectation(description: "Should fail with password mismatch")
        
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        viewModel.passwordConfirmation = "differentPassword"
        
        // Wait for validation to process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // When
            self.viewModel.$statusViewModel
                .dropFirst()
                .sink { status in
                    XCTAssertNotNil(status, "Status should not be nil")
                    XCTAssertEqual(status?.title, "Error", "Should be error status")
                    XCTAssertEqual(status?.message, "Passwords do not match", "Should show password mismatch error")
                    expectation.fulfill()
                }
                .store(in: &self.cancellables)
            
            self.viewModel.signUp()
        }
        
        // Then
        waitForExpectations(timeout: 2.0)
    }
    
    func testSignUpFailsWithShortPassword() {
        // Given
        let expectation = expectation(description: "Should fail with short password")
        
        viewModel.email = "test@example.com"
        viewModel.password = "123"
        viewModel.passwordConfirmation = "123"
        
        // When
        viewModel.$statusViewModel
            .dropFirst()
            .sink { status in
                XCTAssertNotNil(status, "Status should not be nil")
                XCTAssertEqual(status?.title, "Error", "Should be error status")
                XCTAssertEqual(status?.message, "Password must be at least 6 characters", "Should show password length error")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.signUp()
        
        // Then
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - Successful Sign Up Tests
    func testSignUpSuccess() {
        // Given
        let testEmail = "test@example.com"
        let testPassword = "validPassword123"
        let expectation = expectation(description: "Sign up should succeed")
        
        viewModel.email = testEmail
        viewModel.password = testPassword
        viewModel.passwordConfirmation = testPassword
        
        var receivedStatus: AuthenticationStatus?
        
        // When
        viewModel.$statusViewModel
            .dropFirst()
            .sink { status in
                receivedStatus = status
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.signUp()
        
        // Then
        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "Should not timeout")
            XCTAssertNotNil(receivedStatus, "Should receive status update")
            XCTAssertEqual(receivedStatus?.title, "Successful", "Should receive success status")
            
            // Verify app state was updated
            XCTAssertNotNil(self.mockAppState.currentUser, "Current user should be set in app state")
            XCTAssertEqual(self.mockAppState.currentUser?.email, testEmail, "User email should match")
            XCTAssertEqual(self.mockAppState.currentUser?.loginType, .email, "Login type should be email")
            XCTAssertFalse(self.mockAppState.currentUser?.isAnonymous ?? true, "User should not be anonymous")
        }
    }
    
    func testSignUpSuccessUpdatesAppState() {
        // Given
        let testEmail = "user@example.com"
        let testPassword = "password123"
        let expectation = expectation(description: "App state should be updated")
        
        viewModel.email = testEmail
        viewModel.password = testPassword
        viewModel.passwordConfirmation = testPassword
        
        // Track app state changes
        mockAppState.$currentUser
            .dropFirst() // Skip initial nil
            .sink { user in
                if user != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        viewModel.signUp()
        
        // Then
        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "Should not timeout")
            
            let user = self.mockAppState.currentUser
            XCTAssertNotNil(user, "User should be set")
            XCTAssertEqual(user?.email, testEmail, "User email should match input")
            XCTAssertEqual(user?.loginType, .email, "Login type should be email")
            XCTAssertFalse(user?.isAnonymous ?? true, "User should not be anonymous")
            
            // Verify history tracking
            XCTAssertEqual(self.mockAppState.userChangeHistory.count, 2, "Should have initial nil + new user")
            XCTAssertNotNil(self.mockAppState.userChangeHistory.last!, "Last change should be the new user")
        }
    }
    
    // MARK: - Failed Sign Up Tests
    func testSignUpFailureWithExistingEmail() {
        // Given
        let testEmail = "existing@example.com"
        let testPassword = "password123"
        let expectedError = NSError(domain: "MockAuthError", code: 17007, userInfo: [NSLocalizedDescriptionKey: "The email address is already in use by another account."])
        let expectation = expectation(description: "Sign up should fail with existing email")
        
        viewModel.email = testEmail
        viewModel.password = testPassword
        viewModel.passwordConfirmation = testPassword
        
        // Configure mock to fail
        mockAuth.shouldFailNextOperation = true
        mockAuth.mockError = expectedError
        
        var receivedStatus: AuthenticationStatus?
        
        // When
        viewModel.$statusViewModel
            .dropFirst()
            .sink { status in
                receivedStatus = status
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.signUp()
        
        // Then
        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "Should not timeout")
            XCTAssertNotNil(receivedStatus, "Should receive status update")
            XCTAssertEqual(receivedStatus?.title, "Error", "Should receive error status")
            XCTAssertEqual(receivedStatus?.message, expectedError.localizedDescription, "Error message should match")
            
            // Verify app state was not updated
            XCTAssertNil(self.mockAppState.currentUser, "Current user should remain nil on failure")
        }
    }
    
    func testSignUpFailureWithNetworkError() {
        // Given
        let networkError = NSError(domain: "NetworkError", code: -1009, userInfo: [NSLocalizedDescriptionKey: "Network connection lost"])
        let expectation = expectation(description: "Sign up should fail with network error")
        
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        viewModel.passwordConfirmation = "password123"
        
        mockAuth.shouldFailNextOperation = true
        mockAuth.mockError = networkError
        
        var receivedStatus: AuthenticationStatus?
        
        // When
        viewModel.$statusViewModel
            .dropFirst()
            .sink { status in
                receivedStatus = status
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.signUp()
        
        // Then
        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "Should not timeout")
            XCTAssertNotNil(receivedStatus, "Should receive status update")
            XCTAssertEqual(receivedStatus?.title, "Error", "Should receive error status")
            XCTAssertEqual(receivedStatus?.message, networkError.localizedDescription, "Should show network error message")
        }
    }
    
    // MARK: - Loading State Tests
    func testLoadingStateManagement() {
        // Given
        let expectation = expectation(description: "Loading state should be managed correctly")
        expectation.expectedFulfillmentCount = 3 // initial false -> true -> false
        
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        viewModel.passwordConfirmation = "password123"
        
        var loadingStates: [Bool] = []
        
        // When
        testableAuthManager.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.signUp()
        
        // Then
        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "Should not timeout")
            XCTAssertEqual(loadingStates.count, 3, "Should have three loading state changes")
            XCTAssertFalse(loadingStates[0], "Should start with not loading")
            XCTAssertTrue(loadingStates[1], "Should be loading during operation")
            XCTAssertFalse(loadingStates[2], "Should end with not loading")
        }
    }
    
    // MARK: - Publisher Testing
    func testStatusViewModelPublisher() {
        // Given
        let expectation = expectation(description: "Status publisher should emit values")
        var publishedStatuses: [AuthenticationStatus?] = []
        
        // When
        viewModel.$statusViewModel
            .sink { status in
                publishedStatuses.append(status)
                if publishedStatuses.count == 2 { // nil + success status
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        viewModel.passwordConfirmation = "password123"
        viewModel.signUp()
        
        // Then
        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "Should not timeout")
            XCTAssertEqual(publishedStatuses.count, 2, "Should publish initial nil + success status")
            XCTAssertNil(publishedStatuses[0], "First value should be nil")
            XCTAssertNotNil(publishedStatuses[1], "Second value should be status")
            XCTAssertEqual(publishedStatuses[1]?.title, "Successful", "Should be success status")
        }
    }
    
    // MARK: - Edge Cases
    func testValidationOrderPrecedence() {
        // Given - Test that email validation comes before password validation
        let expectation = expectation(description: "Email validation should come first")
        
        viewModel.email = "" // Empty email
        viewModel.password = "123" // Short password
        viewModel.passwordConfirmation = "456" // Mismatched password
        
        // When
        viewModel.$statusViewModel
            .dropFirst()
            .sink { status in
                XCTAssertEqual(status?.message, "Please enter your email address", "Should show email error first")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.signUp()
        
        // Then
        waitForExpectations(timeout: 1.0)
    }
}
