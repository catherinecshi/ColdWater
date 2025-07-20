import XCTest
import Combine
@testable import ColdWater

@MainActor
class AccountConversionViewModelTests: XCTestCase {
    
    // MARK: - Properties
    private var viewModel: AccountConversionViewModel!
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        viewModel = AccountConversionViewModel()
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        cancellables = nil
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    func testInitialization() {
        // Given & When - initialization happens in setUp()
        
        // Then
        XCTAssertEqual(viewModel.email, "", "Email should be empty on initialization")
        XCTAssertEqual(viewModel.password, "", "Password should be empty on initialization")
        XCTAssertEqual(viewModel.passwordConfirmation, "", "Password confirmation should be empty on initialization")
        XCTAssertTrue(viewModel.passwordsMatch, "Passwords should match initially (both empty)")
        XCTAssertNil(viewModel.statusViewModel, "Status should be nil on initialization")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading on initialization")
        XCTAssertFalse(viewModel.isFormValid, "Form should not be valid initially")
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
        // Test the password matching validation logic
        
        // When both empty - should match
        viewModel.password = ""
        viewModel.passwordConfirmation = ""
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
    
    // MARK: - Form Validation Tests
    func testIsFormValidWhenAllFieldsEmpty() {
        // Given & When
        viewModel.email = ""
        viewModel.password = ""
        viewModel.passwordConfirmation = ""
        
        // Then
        XCTAssertFalse(viewModel.isFormValid, "Form should not be valid when all fields are empty")
    }
    
    func testIsFormValidWithOnlyEmail() {
        // Given & When
        viewModel.email = "test@example.com"
        viewModel.password = ""
        viewModel.passwordConfirmation = ""
        
        // Then
        XCTAssertFalse(viewModel.isFormValid, "Form should not be valid with only email")
    }
    
    func testIsFormValidWithShortPassword() {
        // Given & When
        viewModel.email = "test@example.com"
        viewModel.password = "123"
        viewModel.passwordConfirmation = "123"
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // Then
        XCTAssertFalse(viewModel.isFormValid, "Form should not be valid with short password")
    }
    
    func testIsFormValidWithMismatchedPasswords() {
        // Given & When
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        viewModel.passwordConfirmation = "different123"
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // Then
        XCTAssertFalse(viewModel.isFormValid, "Form should not be valid with mismatched passwords")
    }
    
    func testIsFormValidWithValidInputs() {
        // Given & When
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        viewModel.passwordConfirmation = "password123"
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // Then
        XCTAssertTrue(viewModel.isFormValid, "Form should be valid with all valid inputs")
    }
    
    // MARK: - Input Validation Tests (Guard Clauses)
    func testConvertAccountFailsWithEmptyEmail() {
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
        
        viewModel.convertAccount()
        
        // Then
        waitForExpectations(timeout: 1.0)
    }
    
    func testConvertAccountFailsWithEmptyPassword() {
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
        
        viewModel.convertAccount()
        
        // Then
        waitForExpectations(timeout: 1.0)
    }
    
    func testConvertAccountFailsWithPasswordMismatch() {
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
            
            self.viewModel.convertAccount()
        }
        
        // Then
        waitForExpectations(timeout: 2.0)
    }
    
    func testConvertAccountFailsWithShortPassword() {
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
        
        viewModel.convertAccount()
        
        // Then
        waitForExpectations(timeout: 1.0)
    }
    
    // Note: Testing the "You're already signed in with an account" case would require mocking
    // AuthenticationManager.isAnonymous, which is complex due to the direct dependency.
    // This would be better tested with integration tests or by refactoring to use a protocol.
    
    // MARK: - Status Management Tests
    func testClearStatus() {
        // Given
        viewModel.statusViewModel = AuthenticationStatus(title: "Test", message: "Test message")
        
        // When
        viewModel.clearStatus()
        
        // Then
        XCTAssertNil(viewModel.statusViewModel, "Status should be nil after clearing")
    }
    
    func testStatusViewModelPublisher() {
        // Given
        let expectation = expectation(description: "Status publisher should emit values")
        var publishedStatuses: [AuthenticationStatus?] = []
        
        // When
        viewModel.$statusViewModel
            .sink { status in
                publishedStatuses.append(status)
                if publishedStatuses.count == 2 { // nil + error status
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger an error by calling convertAccount with empty email
        viewModel.convertAccount()
        
        // Then
        waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error, "Should not timeout")
            XCTAssertEqual(publishedStatuses.count, 2, "Should publish initial nil + error status")
            XCTAssertNil(publishedStatuses[0], "First value should be nil")
            XCTAssertNotNil(publishedStatuses[1], "Second value should be status")
            XCTAssertEqual(publishedStatuses[1]?.title, "Error", "Should be error status")
        }
    }
    
    // MARK: - Loading State Tests
    func testIsLoadingInitialState() {
        // Given & When - initialization happens in setUp()
        
        // Then
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
    }
    
    func testIsLoadingPropertyBinding() {
        // Given & When
        viewModel.isLoading = true
        
        // Then
        XCTAssertTrue(viewModel.isLoading, "Loading state should be correctly set")
        
        // When
        viewModel.isLoading = false
        
        // Then
        XCTAssertFalse(viewModel.isLoading, "Loading state should be correctly updated")
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
        
        viewModel.convertAccount()
        
        // Then
        waitForExpectations(timeout: 1.0)
    }
    
    func testFormValidationWithEmptyConfirmation() {
        // Given - Test that form is valid even when confirmation is empty (as per the matching logic)
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        viewModel.passwordConfirmation = ""
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // Then
        XCTAssertTrue(viewModel.passwordsMatch, "Passwords should match when confirmation is empty")
        XCTAssertTrue(viewModel.isFormValid, "Form should be valid when confirmation is empty but other fields are valid")
    }
    
    // MARK: - Publisher Behavior Tests
    func testIsLoadingPublisher() {
        // Given
        let expectation = expectation(description: "Loading publisher should emit values")
        var loadingStates: [Bool] = []
        
        // When
        viewModel.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count == 2 { // false + true
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.isLoading = true
        
        // Then
        waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error, "Should not timeout")
            XCTAssertEqual(loadingStates.count, 2, "Should have two loading state changes")
            XCTAssertFalse(loadingStates[0], "Should start with not loading")
            XCTAssertTrue(loadingStates[1], "Should be loading after update")
        }
    }
}
