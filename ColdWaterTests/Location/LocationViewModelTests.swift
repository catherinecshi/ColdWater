import XCTest
import SwiftUI
import CoreLocation
import Combine
@testable import ColdWater

// MARK: - ContentViewViewModel Tests
@MainActor
final class ContentViewViewModelTests: XCTestCase {
    var viewModel: LocationViewModel!
    var mockLocationProvider: MockLocationProvider!
    var locationManager: LocationManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockLocationProvider = MockLocationProvider()
        mockLocationProvider.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        locationManager = LocationManager(locationProvider: mockLocationProvider)
        viewModel = LocationViewModel(locationManager: locationManager)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        viewModel = nil
        locationManager = nil
        mockLocationProvider = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testViewModelInitialization() {
        // Given/When
        let viewModel = LocationViewModel(locationManager: locationManager)
        
        // Then
        XCTAssertEqual(viewModel.latitude, "")
        XCTAssertEqual(viewModel.longitude, "")
        XCTAssertEqual(viewModel.radius, "100")
        XCTAssertEqual(viewModel.startHour, 4)
        XCTAssertEqual(viewModel.endHour, 7)
        XCTAssertFalse(viewModel.showingLocationPicker)
    }
    
    // MARK: - Authorization Status Tests
    
    func testAuthorizationStatusText() {
        let testCases: [(CLAuthorizationStatus, String)] = [
            (.notDetermined, "Not Determined"),
            (.denied, "Denied"),
            (.restricted, "Restricted"),
            (.authorizedWhenInUse, "When In Use"),
            (.authorizedAlways, "Always")
        ]
        
        for (status, expectedText) in testCases {
            // Given
            mockLocationProvider.authorizationStatus = status
            mockLocationProvider.simulateAuthorizationChange(status)
            
            // When
            let statusText = viewModel.authorizationStatusText
            
            // Then
            XCTAssertEqual(statusText, expectedText, "Failed for status: \(status)")
        }
    }
    
    func testAuthorizationStatusColor() {
        let testCases: [(CLAuthorizationStatus, Color)] = [
            (.authorizedAlways, .green),
            (.authorizedWhenInUse, .orange),
            (.notDetermined, .red),
            (.denied, .red),
            (.restricted, .red)
        ]
        
        for (status, expectedColor) in testCases {
            // Given
            mockLocationProvider.authorizationStatus = status
            mockLocationProvider.simulateAuthorizationChange(status)
            
            // When
            let statusColor = viewModel.authorizationStatusColor
            
            // Then
            XCTAssertEqual(statusColor, expectedColor, "Failed for status: \(status)")
        }
    }
    
    // MARK: - Geofence Status Tests
    
    func testGeofenceStatusText() {
        let testCases: [(LocationManager.GeofenceStatus, String)] = [
            (.unknown, "Unknown"),
            (.insideGeofence, "Inside Geofence"),
            (.outsideGeofence, "Outside Geofence"),
            (.outsideGeofenceInTimeWindow, "Outside (Time Window)"),
            (.insideGeofenceInTimeWindow, "Inside (Time Window)")
        ]
        
        for (status, expectedText) in testCases {
            // Given - We need to use reflection or wait for the locationManager to publish updates
            // Since geofenceStatus is @Published, we can wait for changes
            let expectation = XCTestExpectation(description: "Geofence status updated")
            
            locationManager.$geofenceStatus
                .dropFirst()
                .sink { updatedStatus in
                    if updatedStatus == status {
                        expectation.fulfill()
                    }
                }
                .store(in: &cancellables)
            
            // Manually set the status for testing (this is a limitation of the current design)
            locationManager.geofenceStatus = status
            
            // When
            let statusText = viewModel.geofenceStatusText
            
            // Then
            XCTAssertEqual(statusText, expectedText, "Failed for status: \(status)")
        }
    }
    
    func testGeofenceStatusColor() {
        let testCases: [(LocationManager.GeofenceStatus, Color)] = [
            (.outsideGeofenceInTimeWindow, .green),
            (.insideGeofenceInTimeWindow, .red),
            (.outsideGeofence, .blue),
            (.insideGeofence, .blue),
            (.unknown, .gray)
        ]
        
        for (status, expectedColor) in testCases {
            // Given
            locationManager.geofenceStatus = status
            
            // When
            let statusColor = viewModel.geofenceStatusColor
            
            // Then
            XCTAssertEqual(statusColor, expectedColor, "Failed for status: \(status)")
        }
    }
    
    // MARK: - Can Start Monitoring Tests
    
    func testCanStartMonitoringWithValidInputsAndPermission() {
        // Given
        mockLocationProvider.authorizationStatus = .authorizedWhenInUse
        mockLocationProvider.simulateAuthorizationChange(.authorizedWhenInUse)
        viewModel.latitude = "37.7749"
        viewModel.longitude = "-122.4194"
        viewModel.radius = "100"
        
        // When
        let canStart = viewModel.canStartMonitoring
        
        // Then
        XCTAssertTrue(canStart)
    }
    
    func testCanStartMonitoringWithAlwaysPermission() {
        // Given
        mockLocationProvider.authorizationStatus = .authorizedAlways
        mockLocationProvider.simulateAuthorizationChange(.authorizedAlways)
        viewModel.latitude = "37.7749"
        viewModel.longitude = "-122.4194"
        viewModel.radius = "100"
        
        // When
        let canStart = viewModel.canStartMonitoring
        
        // Then
        XCTAssertTrue(canStart)
    }
    
    func testCannotStartMonitoringWithoutPermission() {
        let unauthorizedStatuses: [CLAuthorizationStatus] = [.notDetermined, .denied, .restricted]
        
        for status in unauthorizedStatuses {
            // Given
            mockLocationProvider.authorizationStatus = status
            mockLocationProvider.simulateAuthorizationChange(status)
            viewModel.latitude = "37.7749"
            viewModel.longitude = "-122.4194"
            viewModel.radius = "100"
            
            // When
            let canStart = viewModel.canStartMonitoring
            
            // Then
            XCTAssertFalse(canStart, "Should not start monitoring for status: \(status)")
        }
    }
    
    func testCannotStartMonitoringWithEmptyFields() {
        let testCases: [(String, String, String)] = [
            ("", "-122.4194", "100"), // Empty latitude
            ("37.7749", "", "100"), // Empty longitude
            ("37.7749", "-122.4194", ""), // Empty radius
            ("", "", ""), // All empty
        ]
        
        for (lat, lng, radius) in testCases {
            // Given
            mockLocationProvider.authorizationStatus = .authorizedWhenInUse
            mockLocationProvider.simulateAuthorizationChange(.authorizedWhenInUse)
            viewModel.latitude = lat
            viewModel.longitude = lng
            viewModel.radius = radius
            
            // When
            let canStart = viewModel.canStartMonitoring
            
            // Then
            XCTAssertFalse(canStart, "Should not start monitoring with lat=\(lat), lng=\(lng), radius=\(radius)")
        }
    }
    
    func testCannotStartMonitoringWithInvalidValues() {
        let testCases: [(String, String, String)] = [
            ("invalid", "-122.4194", "100"), // Invalid latitude
            ("37.7749", "invalid", "100"), // Invalid longitude
            ("37.7749", "-122.4194", "invalid"), // Invalid radius
        ]
        
        for (lat, lng, radius) in testCases {
            // Given
            mockLocationProvider.authorizationStatus = .authorizedWhenInUse
            mockLocationProvider.simulateAuthorizationChange(.authorizedWhenInUse)
            viewModel.latitude = lat
            viewModel.longitude = lng
            viewModel.radius = radius
            
            // When
            let canStart = viewModel.canStartMonitoring
            
            // Then
            XCTAssertFalse(canStart, "Should not start monitoring with lat=\(lat), lng=\(lng), radius=\(radius)")
        }
    }
    
    // MARK: - Action Tests
    
    func testRequestLocationPermissionFromNotDetermined() {
        // Given
        mockLocationProvider.authorizationStatus = .notDetermined
        mockLocationProvider.simulateAuthorizationChange(.notDetermined)
        XCTAssertFalse(mockLocationProvider.requestWhenInUseAuthorizationCalled)
        
        // When
        viewModel.requestLocationPermission()
        
        // Then
        XCTAssertTrue(mockLocationProvider.requestWhenInUseAuthorizationCalled)
        XCTAssertFalse(mockLocationProvider.requestAlwaysAuthorizationCalled)
    }
    
    func testRequestLocationPermissionFromWhenInUse() {
        // Given
        mockLocationProvider.authorizationStatus = .authorizedWhenInUse
        mockLocationProvider.simulateAuthorizationChange(.authorizedWhenInUse)
        XCTAssertFalse(mockLocationProvider.requestAlwaysAuthorizationCalled)
        
        // When
        viewModel.requestLocationPermission()
        
        // Then
        XCTAssertTrue(mockLocationProvider.requestAlwaysAuthorizationCalled)
        XCTAssertFalse(mockLocationProvider.requestWhenInUseAuthorizationCalled)
    }
    
    func testUseCurrentLocationSuccess() async {
        // Given
        let expectedLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        mockLocationProvider.mockLocation = expectedLocation
        mockLocationProvider.authorizationStatus = .authorizedWhenInUse
        mockLocationProvider.simulateAuthorizationChange(.authorizedWhenInUse)
        
        let expectation = XCTestExpectation(description: "Location updated")
        
        // Subscribe to changes
        viewModel.$latitude
            .combineLatest(viewModel.$longitude)
            .dropFirst() // Skip initial empty values
            .sink { lat, lng in
                if !lat.isEmpty && !lng.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        viewModel.useCurrentLocation()
        
        // Simulate the location update that would normally come from the delegate
        mockLocationProvider.simulateLocationUpdate(expectedLocation)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(viewModel.latitude, "40.7128")
        XCTAssertEqual(viewModel.longitude, "-74.006")
    }
    
    func testUseCurrentLocationWithoutPermission() {
        // Given
        mockLocationProvider.authorizationStatus = .denied
        mockLocationProvider.simulateAuthorizationChange(.denied)
        let initialLatitude = viewModel.latitude
        let initialLongitude = viewModel.longitude
        
        // When
        viewModel.useCurrentLocation()
        
        // Then
        XCTAssertEqual(viewModel.latitude, initialLatitude) // Should remain unchanged
        XCTAssertEqual(viewModel.longitude, initialLongitude) // Should remain unchanged
    }
    
    func testStartGeofenceMonitoringWithValidInput() {
        // Given
        viewModel.latitude = "37.7749"
        viewModel.longitude = "-122.4194"
        viewModel.radius = "100"
        viewModel.startHour = 6
        viewModel.endHour = 9
        
        // When
        viewModel.startGeofenceMonitoring()
        
        // Then
        XCTAssertTrue(mockLocationProvider.startMonitoringCalled)
        
        let configRaw = viewModel.geofenceConfig
        XCTAssertNotNil(configRaw)
        
        guard let config = configRaw else {
            XCTFail("Geofence config should not be nil")
            return
        }
        
        XCTAssertEqual(config.center.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(config.center.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(config.radius, 100.0)
        XCTAssertEqual(config.startHour, 6)
        XCTAssertEqual(config.endHour, 9)
        XCTAssertEqual(config.identifier, "MainGeofence")
    }
    
    func testStartGeofenceMonitoringWithInvalidInput() {
        // Given
        viewModel.latitude = "invalid"
        viewModel.longitude = "-122.4194"
        viewModel.radius = "100"
        
        // When
        viewModel.startGeofenceMonitoring()
        
        // Then
        XCTAssertFalse(mockLocationProvider.startMonitoringCalled)
        XCTAssertNil(viewModel.geofenceConfig)
    }
    
    func testStopMonitoring() {
        // Given
        XCTAssertFalse(mockLocationProvider.stopUpdatingLocationCalled)
        
        // When
        viewModel.stopMonitoring()
        
        // Then
        XCTAssertTrue(mockLocationProvider.stopUpdatingLocationCalled)
    }
    
    // MARK: - State Change Tests
    
    func testLatitudeStateChange() async {
        // Given
        let expectation = XCTestExpectation(description: "Latitude changed")
        let newLatitude = "40.7128"
        
        viewModel.$latitude
            .dropFirst() // Skip initial value
            .sink { latitude in
                if latitude == newLatitude {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        viewModel.latitude = newLatitude
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(viewModel.latitude, newLatitude)
    }
    
    func testLongitudeStateChange() async {
        // Given
        let expectation = XCTestExpectation(description: "Longitude changed")
        let newLongitude = "-74.0060"
        
        viewModel.$longitude
            .dropFirst() // Skip initial value
            .sink { longitude in
                if longitude == newLongitude {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        viewModel.longitude = newLongitude
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(viewModel.longitude, newLongitude)
    }
    
    func testRadiusStateChange() async {
        // Given
        let expectation = XCTestExpectation(description: "Radius changed")
        let newRadius = "200"
        
        viewModel.$radius
            .dropFirst() // Skip initial value
            .sink { radius in
                if radius == newRadius {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        viewModel.radius = newRadius
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(viewModel.radius, newRadius)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflow() async {
        // Given - Initial state
        XCTAssertEqual(viewModel.latitude, "")
        XCTAssertEqual(viewModel.longitude, "")
        XCTAssertFalse(viewModel.canStartMonitoring)
        
        // When - Request permission
        mockLocationProvider.authorizationStatus = .notDetermined
        viewModel.requestLocationPermission()
        
        // Then - Permission requested
        XCTAssertTrue(mockLocationProvider.requestWhenInUseAuthorizationCalled)
        
        // When - Authorization granted (simulated)
        mockLocationProvider.simulateAuthorizationChange(.authorizedWhenInUse)
        
        // Then - Should start location updates
        XCTAssertTrue(mockLocationProvider.startUpdatingLocationCalled)
        
        // When - Get current location
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockLocationProvider.mockLocation = testLocation
        
        let locationExpectation = XCTestExpectation(description: "Location coordinates updated")
        
        viewModel.$latitude
            .combineLatest(viewModel.$longitude)
            .dropFirst()
            .sink { lat, lng in
                if !lat.isEmpty && !lng.isEmpty {
                    locationExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.useCurrentLocation()
        mockLocationProvider.simulateLocationUpdate(testLocation)
        
        await fulfillment(of: [locationExpectation], timeout: 1.0)
        
        // Then - Location coordinates should be set
        XCTAssertEqual(viewModel.latitude, "37.7749")
        XCTAssertEqual(viewModel.longitude, "-122.4194")
        XCTAssertTrue(viewModel.canStartMonitoring)
        
        // When - Start geofence monitoring
        viewModel.startGeofenceMonitoring()
        
        // Then - Geofence should be configured
        XCTAssertTrue(mockLocationProvider.startMonitoringCalled)
        XCTAssertNotNil(viewModel.geofenceConfig)
        
        // When - Stop monitoring
        viewModel.stopMonitoring()
        
        // Then - Monitoring should be stopped
        XCTAssertTrue(mockLocationProvider.stopUpdatingLocationCalled)
    }
    
    // MARK: - Property Access Tests
    
    func testIsMonitoringProperty() {
        // Given
        XCTAssertFalse(viewModel.isMonitoring)
        
        // When
        mockLocationProvider.authorizationStatus = .authorizedWhenInUse
        mockLocationProvider.simulateAuthorizationChange(.authorizedWhenInUse)
        
        // Then
        XCTAssertTrue(viewModel.isMonitoring) // LocationManager starts monitoring when authorized
    }
    
    func testCurrentLocationProperty() {
        // Given
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        XCTAssertNil(viewModel.currentLocation)
        
        // When
        mockLocationProvider.simulateLocationUpdate(testLocation)
        
        // Then
        XCTAssertEqual(viewModel.currentLocation, testLocation)
    }
    
    // MARK: - Performance Tests
    
    func testViewModelCreationPerformance() {
        measure {
            for _ in 0..<100 {
                let provider = MockLocationProvider()
                let manager = LocationManager(locationProvider: provider)
                let viewModel = LocationViewModel(locationManager: manager)
                _ = viewModel.canStartMonitoring // Force computation
            }
        }
    }
    
    func testCanStartMonitoringPerformance() {
        // Given
        mockLocationProvider.authorizationStatus = .authorizedWhenInUse
        mockLocationProvider.simulateAuthorizationChange(.authorizedWhenInUse)
        viewModel.latitude = "37.7749"
        viewModel.longitude = "-122.4194"
        viewModel.radius = "100"
        
        measure {
            for _ in 0..<1000 {
                _ = viewModel.canStartMonitoring
            }
        }
    }
}
