import XCTest
import Foundation
@testable import ColdWater

// MARK: - Mock UserDefaults for Testing
class MockUserDefaults: UserDefaults {
    private var storage: [String: Any] = [:]
    
    override func integer(forKey defaultName: String) -> Int {
        return storage[defaultName] as? Int ?? 0
    }
    
    override func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }
    
    override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }
    
    override func set(_ value: Int, forKey defaultName: String) {
        storage[defaultName] = value
    }
    
    func clear() {
        storage.removeAll()
    }
}

// MARK: - Testable HomeViewModel
class TestableHomeViewModel: HomeViewModel {
    private let mockDefaults: MockUserDefaults
    
    init(mockDefaults: MockUserDefaults = MockUserDefaults()) {
        self.mockDefaults = mockDefaults
        super.init()
    }
    
    override func loadWakeUpData() {
        let savedDays = mockDefaults.integer(forKey: "consecutiveDays")
        let savedDate = mockDefaults.object(forKey: "lastWakeUpTime") as? Date
        
        wakeUpData = WakeUpData(
            consecutiveDays: savedDays,
            lastWakeUpTime: savedDate
        )
    }
    
    override func saveWakeUpData() {
        mockDefaults.set(wakeUpData.consecutiveDays, forKey: "consecutiveDays")
        if let lastWakeUp = wakeUpData.lastWakeUpTime {
            mockDefaults.set(lastWakeUp, forKey: "lastWakeUpTime")
        }
    }
}

// MARK: - Unit Tests
class HomeViewModelTests: XCTestCase {
    
    var viewModel: TestableHomeViewModel!
    var mockDefaults: MockUserDefaults!
    
    override func setUp() {
        super.setUp()
        mockDefaults = MockUserDefaults()
        viewModel = TestableHomeViewModel(mockDefaults: mockDefaults)
    }
    
    override func tearDown() {
        mockDefaults.clear()
        viewModel = nil
        mockDefaults = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        // Given: Fresh ViewModel
        
        // When: ViewModel is initialized
        
        // Then: Should have default values
        XCTAssertEqual(viewModel.wakeUpData.consecutiveDays, 0)
        XCTAssertNil(viewModel.wakeUpData.lastWakeUpTime)
        XCTAssertEqual(viewModel.daysString, "0")
        XCTAssertFalse(viewModel.isStreakActive)
    }
    
    // MARK: - Data Persistence Tests
    
    func testLoadWakeUpDataWithNoSavedData() {
        // Given: No saved data
        
        // When: Loading data
        viewModel.loadWakeUpData()
        
        // Then: Should have default values
        XCTAssertEqual(viewModel.wakeUpData.consecutiveDays, 0)
        XCTAssertNil(viewModel.wakeUpData.lastWakeUpTime)
    }
    
    func testLoadWakeUpDataWithSavedData() {
        // Given: Saved data exists
        let savedDays = 5
        let savedDate = Date()
        mockDefaults.set(savedDays, forKey: "consecutiveDays")
        mockDefaults.set(savedDate, forKey: "lastWakeUpTime")
        
        // When: Loading data
        viewModel.loadWakeUpData()
        
        // Then: Should load saved values
        XCTAssertEqual(viewModel.wakeUpData.consecutiveDays, savedDays)
        XCTAssertEqual(viewModel.wakeUpData.lastWakeUpTime, savedDate)
    }
    
    func testSaveWakeUpData() {
        // Given: ViewModel with data
        let testDate = Date()
        viewModel.wakeUpData = WakeUpData(consecutiveDays: 7, lastWakeUpTime: testDate)
        
        // When: Saving data
        viewModel.saveWakeUpData()
        
        // Then: Data should be persisted
        XCTAssertEqual(mockDefaults.integer(forKey: "consecutiveDays"), 7)
        XCTAssertEqual(mockDefaults.object(forKey: "lastWakeUpTime") as? Date, testDate)
    }
    
    // MARK: - Wake Up Recording Tests
    
    func testRecordSuccessfulWakeUp() {
        // Given: Initial state with 0 days
        XCTAssertEqual(viewModel.wakeUpData.consecutiveDays, 0)
        
        // When: Recording successful wake up
        let beforeDate = Date()
        viewModel.recordSuccessfulWakeUp()
        let afterDate = Date()
        
        // Then: Consecutive days should increment and date should be recorded
        XCTAssertEqual(viewModel.wakeUpData.consecutiveDays, 1)
        XCTAssertNotNil(viewModel.wakeUpData.lastWakeUpTime)
        
        // Verify the date is within expected range
        if let recordedDate = viewModel.wakeUpData.lastWakeUpTime {
            XCTAssertTrue(recordedDate >= beforeDate)
            XCTAssertTrue(recordedDate <= afterDate)
        }
    }
    
    func testMultipleSuccessfulWakeUps() {
        // Given: Initial state
        
        // When: Recording multiple wake ups
        viewModel.recordSuccessfulWakeUp()
        viewModel.recordSuccessfulWakeUp()
        viewModel.recordSuccessfulWakeUp()
        
        // Then: Should accumulate correctly
        XCTAssertEqual(viewModel.wakeUpData.consecutiveDays, 3)
    }
    
    func testRecordSuccessfulWakeUpPersistence() {
        // Given: Initial state
        
        // When: Recording successful wake up
        viewModel.recordSuccessfulWakeUp()
        
        // Then: Should be saved to persistent storage
        XCTAssertEqual(mockDefaults.integer(forKey: "consecutiveDays"), 1)
        XCTAssertNotNil(mockDefaults.object(forKey: "lastWakeUpTime"))
    }
    
    // MARK: - Streak Reset Tests
    
    func testResetStreak() {
        // Given: ViewModel with existing streak
        let testDate = Date()
        viewModel.wakeUpData = WakeUpData(consecutiveDays: 10, lastWakeUpTime: testDate)
        
        // When: Resetting streak
        viewModel.resetStreak()
        
        // Then: Consecutive days should be 0, but last wake up time preserved
        XCTAssertEqual(viewModel.wakeUpData.consecutiveDays, 0)
        XCTAssertEqual(viewModel.wakeUpData.lastWakeUpTime, testDate)
    }
    
    func testResetStreakPersistence() {
        // Given: ViewModel with existing streak
        viewModel.wakeUpData = WakeUpData(consecutiveDays: 5, lastWakeUpTime: Date())
        
        // When: Resetting streak
        viewModel.resetStreak()
        
        // Then: Should save reset state
        XCTAssertEqual(mockDefaults.integer(forKey: "consecutiveDays"), 0)
    }
    
    // MARK: - Computed Properties Tests
    
    func testDaysString() {
        // Test various day counts
        let testCases = [0, 1, 7, 15, 100, 999]
        
        for days in testCases {
            // Given: ViewModel with specific day count
            viewModel.wakeUpData = WakeUpData(consecutiveDays: days)
            
            // When: Getting days string
            let result = viewModel.daysString
            
            // Then: Should return correct string representation
            XCTAssertEqual(result, "\(days)", "Failed for \(days) days")
        }
    }
    
    func testIsStreakActiveWithNoLastWakeUp() {
        // Given: No last wake up time
        viewModel.wakeUpData = WakeUpData(consecutiveDays: 5, lastWakeUpTime: nil)
        
        // When: Checking if streak is active
        let isActive = viewModel.isStreakActive
        
        // Then: Should not be active
        XCTAssertFalse(isActive)
    }
    
    func testIsStreakActiveWithTodaysWakeUp() {
        // Given: Wake up time is today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todaysWakeUp = calendar.date(byAdding: .hour, value: 8, to: today)!
        
        viewModel.wakeUpData = WakeUpData(consecutiveDays: 3, lastWakeUpTime: todaysWakeUp)
        
        // When: Checking if streak is active
        let isActive = viewModel.isStreakActive
        
        // Then: Should be active
        XCTAssertTrue(isActive)
    }
    
    func testIsStreakActiveWithYesterdaysWakeUp() {
        // Given: Wake up time is yesterday
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let yesterdaysWakeUp = calendar.startOfDay(for: yesterday)
        
        viewModel.wakeUpData = WakeUpData(consecutiveDays: 3, lastWakeUpTime: yesterdaysWakeUp)
        
        // When: Checking if streak is active
        let isActive = viewModel.isStreakActive
        
        // Then: Should be active
        XCTAssertTrue(isActive)
    }
    
    func testIsStreakActiveWithOldWakeUp() {
        // Given: Wake up time is 3 days ago
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        
        viewModel.wakeUpData = WakeUpData(consecutiveDays: 3, lastWakeUpTime: threeDaysAgo)
        
        // When: Checking if streak is active
        let isActive = viewModel.isStreakActive
        
        // Then: Should not be active
        XCTAssertFalse(isActive)
    }
    
    // MARK: - Edge Cases Tests
    
    func testLargeConsecutiveDays() {
        // Given: Very large number of consecutive days
        let largeDays = 999999
        viewModel.wakeUpData = WakeUpData(consecutiveDays: largeDays)
        
        // When: Getting days string
        let result = viewModel.daysString
        
        // Then: Should handle large numbers correctly
        XCTAssertEqual(result, "\(largeDays)")
    }
    
    func testNegativeConsecutiveDays() {
        // Given: Negative consecutive days (edge case)
        let negativeDays = -5
        viewModel.wakeUpData = WakeUpData(consecutiveDays: negativeDays)
        
        // When: Getting days string
        let result = viewModel.daysString
        
        // Then: Should display the value as is
        XCTAssertEqual(result, "\(negativeDays)")
    }
    
    // MARK: - Performance Tests
    
    func testRecordWakeUpPerformance() {
        measure {
            for _ in 0..<1000 {
                viewModel.recordSuccessfulWakeUp()
            }
        }
    }
    
    func testLoadDataPerformance() {
        // Given: Data in storage
        mockDefaults.set(100, forKey: "consecutiveDays")
        mockDefaults.set(Date(), forKey: "lastWakeUpTime")
        
        measure {
            for _ in 0..<1000 {
                viewModel.loadWakeUpData()
            }
        }
    }
}

// MARK: - Integration Tests
class HomeViewModelIntegrationTests: XCTestCase {
    
    var viewModel: TestableHomeViewModel!
    var mockDefaults: MockUserDefaults!
    
    override func setUp() {
        super.setUp()
        mockDefaults = MockUserDefaults()
        viewModel = TestableHomeViewModel(mockDefaults: mockDefaults)
    }
    
    override func tearDown() {
        mockDefaults.clear()
        viewModel = nil
        mockDefaults = nil
        super.tearDown()
    }
    
    func testCompleteWorkflow() {
        // Test complete user workflow
        
        // 1. Initial load
        viewModel.loadWakeUpData()
        XCTAssertEqual(viewModel.wakeUpData.consecutiveDays, 0)
        
        // 2. Record several successful wake ups
        for i in 1...5 {
            viewModel.recordSuccessfulWakeUp()
            XCTAssertEqual(viewModel.wakeUpData.consecutiveDays, i)
            XCTAssertTrue(viewModel.isStreakActive)
        }
        
        // 3. Reset streak
        viewModel.resetStreak()
        XCTAssertEqual(viewModel.wakeUpData.consecutiveDays, 0)
        
        // 4. Start new streak
        viewModel.recordSuccessfulWakeUp()
        XCTAssertEqual(viewModel.wakeUpData.consecutiveDays, 1)
        XCTAssertTrue(viewModel.isStreakActive)
    }
    
    func testDataPersistenceAcrossViewModelInstances() {
        // Given: First view model with data
        viewModel.recordSuccessfulWakeUp()
        viewModel.recordSuccessfulWakeUp()
        viewModel.recordSuccessfulWakeUp()
        
        // When: Creating new view model instance
        let newViewModel = TestableHomeViewModel(mockDefaults: mockDefaults)
        
        // Then: Should load previous data
        XCTAssertEqual(newViewModel.wakeUpData.consecutiveDays, 3)
        XCTAssertNotNil(newViewModel.wakeUpData.lastWakeUpTime)
    }
}
