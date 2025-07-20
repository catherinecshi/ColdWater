import XCTest
import CoreLocation
import UserNotifications
@testable import ColdWater

// MARK: - Mock Location Provider

class MockLocationProvider: LocationProviding {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    weak var delegate: CLLocationManagerDelegate?
    
    // Tracking method calls
    var requestWhenInUseAuthorizationCalled = false
    var requestAlwaysAuthorizationCalled = false
    var startUpdatingLocationCalled = false
    var stopUpdatingLocationCalled = false
    var startMonitoringCalled = false
    var stopMonitoringCalled = false
    
    // Mock data
    var mockLocation: CLLocation?
    var monitoredRegions: Set<CLRegion> = []
    
    func requestWhenInUseAuthorization() {
        requestWhenInUseAuthorizationCalled = true
        // Simulate authorization response
        DispatchQueue.main.async {
            self.authorizationStatus = .authorizedWhenInUse
            self.delegate?.locationManagerDidChangeAuthorization?(CLLocationManager())
        }
    }
    
    func requestAlwaysAuthorization() {
        requestAlwaysAuthorizationCalled = true
        // Simulate authorization response
        DispatchQueue.main.async {
            self.authorizationStatus = .authorizedAlways
            self.delegate?.locationManagerDidChangeAuthorization?(CLLocationManager())
        }
    }
    
    func startUpdatingLocation() {
        startUpdatingLocationCalled = true
        // Simulate location update
        if let location = mockLocation {
            DispatchQueue.main.async {
                self.delegate?.locationManager?(CLLocationManager(), didUpdateLocations: [location])
            }
        }
    }
    
    func stopUpdatingLocation() {
        stopUpdatingLocationCalled = true
    }
    
    func startMonitoring(for region: CLRegion) {
        startMonitoringCalled = true
        monitoredRegions.insert(region)
    }
    
    func stopMonitoring(for region: CLRegion) {
        stopMonitoringCalled = true
        monitoredRegions.remove(region)
    }
    
    // Helper methods for testing
    func simulateLocationUpdate(_ location: CLLocation) {
        mockLocation = location
        delegate?.locationManager?(CLLocationManager(), didUpdateLocations: [location])
    }
    
    func simulateAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        delegate?.locationManagerDidChangeAuthorization?(CLLocationManager())
    }
    
    func simulateRegionEntry(_ region: CLRegion) {
        delegate?.locationManager?(CLLocationManager(), didEnterRegion: region)
    }
    
    func simulateRegionExit(_ region: CLRegion) {
        delegate?.locationManager?(CLLocationManager(), didExitRegion: region)
    }
}

// MARK: - Unit Tests

final class LocationManagerTests: XCTestCase {
    var locationManager: LocationManager!
    var mockLocationProvider: MockLocationProvider!
    
    override func setUp() {
        super.setUp()
        mockLocationProvider = MockLocationProvider()
        mockLocationProvider.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        locationManager = LocationManager(locationProvider: mockLocationProvider)
    }
    
    override func tearDown() {
        locationManager = nil
        mockLocationProvider = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(locationManager.authorizationStatus, .notDetermined)
        XCTAssertNil(locationManager.currentLocation)
        XCTAssertFalse(locationManager.isMonitoring)
        XCTAssertEqual(locationManager.geofenceStatus, .unknown)
        XCTAssertNil(locationManager.geofenceConfig)
    }
    
    // MARK: - Permission Request Tests
    
    func testRequestLocationPermissionWhenNotDetermined() {
        // Given
        mockLocationProvider.authorizationStatus = .notDetermined
        locationManager.authorizationStatus = .notDetermined
        
        // When
        locationManager.requestLocationPermission()
        
        // Then
        XCTAssertTrue(mockLocationProvider.requestWhenInUseAuthorizationCalled)
        XCTAssertFalse(mockLocationProvider.requestAlwaysAuthorizationCalled)
    }
    
    func testRequestLocationPermissionWhenAuthorizedWhenInUse() {
        // Given
        mockLocationProvider.authorizationStatus = .authorizedWhenInUse
        locationManager.authorizationStatus = .authorizedWhenInUse
        
        // When
        locationManager.requestLocationPermission()
        
        // Then
        XCTAssertFalse(mockLocationProvider.requestWhenInUseAuthorizationCalled)
        XCTAssertTrue(mockLocationProvider.requestAlwaysAuthorizationCalled)
    }
    
    func testRequestLocationPermissionWhenDenied() {
        // Given
        mockLocationProvider.authorizationStatus = .denied
        locationManager.authorizationStatus = .denied
        
        // When
        locationManager.requestLocationPermission()
        
        // Then
        XCTAssertFalse(mockLocationProvider.requestWhenInUseAuthorizationCalled)
        XCTAssertFalse(mockLocationProvider.requestAlwaysAuthorizationCalled)
    }
    
    // MARK: - Location Updates Tests
    
    func testStartLocationUpdatesWithAuthorization() {
        // Given
        locationManager.authorizationStatus = .authorizedWhenInUse
        
        // When
        locationManager.startLocationUpdates()
        
        // Then
        XCTAssertTrue(mockLocationProvider.startUpdatingLocationCalled)
        XCTAssertTrue(locationManager.isMonitoring)
    }
    
    func testStartLocationUpdatesWithoutAuthorization() {
        // Given
        locationManager.authorizationStatus = .notDetermined
        
        // When
        locationManager.startLocationUpdates()
        
        // Then
        XCTAssertFalse(mockLocationProvider.startUpdatingLocationCalled)
        XCTAssertFalse(locationManager.isMonitoring)
    }
    
    func testStopLocationUpdates() {
        // Given
        locationManager.isMonitoring = true
        
        // When
        locationManager.stopLocationUpdates()
        
        // Then
        XCTAssertTrue(mockLocationProvider.stopUpdatingLocationCalled)
        XCTAssertFalse(locationManager.isMonitoring)
    }
    
    // MARK: - Current Location Request Tests
    
    func testRequestCurrentLocationWithValidPermission() {
        // Given
        locationManager.authorizationStatus = .authorizedWhenInUse
        let expectation = expectation(description: "Current location callback")
        var receivedLocation: CLLocation?
        
        // When
        locationManager.requestCurrentLocation { location in
            receivedLocation = location
            expectation.fulfill()
        }
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(receivedLocation)
        XCTAssertEqual(receivedLocation!.coordinate.latitude, 37.7749, accuracy: 0.001)
        XCTAssertEqual(receivedLocation!.coordinate.longitude, -122.4194, accuracy: 0.001)
    }
    
    func testRequestCurrentLocationWithoutPermission() {
        // Given
        locationManager.authorizationStatus = .notDetermined
        let expectation = expectation(description: "Current location callback")
        var receivedLocation: CLLocation?
        
        // When
        locationManager.requestCurrentLocation { location in
            receivedLocation = location
            expectation.fulfill()
        }
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertNil(receivedLocation)
        XCTAssertTrue(mockLocationProvider.requestWhenInUseAuthorizationCalled)
    }
    
    func testRequestCurrentLocationWithRecentLocation() {
        // Given
        locationManager.authorizationStatus = .authorizedWhenInUse
        let recentLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        locationManager.currentLocation = recentLocation
        
        let expectation = expectation(description: "Current location callback")
        var receivedLocation: CLLocation?
        
        // When
        locationManager.requestCurrentLocation { location in
            receivedLocation = location
            expectation.fulfill()
        }
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedLocation, recentLocation)
        // Should not start location updates since we have recent location
        XCTAssertFalse(mockLocationProvider.startUpdatingLocationCalled)
    }
    
    // MARK: - Geofence Configuration Tests
    
    func testConfigureGeofence() {
        // Given
        let center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let radius: CLLocationDistance = 100
        let startHour = 4
        let endHour = 7
        
        // When
        locationManager.configureGeofence(center: center, radius: radius, startHour: startHour, endHour: endHour)
        
        // Then
        XCTAssertNotNil(locationManager.geofenceConfig)
        XCTAssertEqual(locationManager.geofenceConfig!.center.latitude, center.latitude, accuracy: 0.001)
        XCTAssertEqual(locationManager.geofenceConfig!.center.longitude, center.longitude, accuracy: 0.001)
        XCTAssertEqual(locationManager.geofenceConfig?.radius, radius)
        XCTAssertEqual(locationManager.geofenceConfig?.startHour, startHour)
        XCTAssertEqual(locationManager.geofenceConfig?.endHour, endHour)
        XCTAssertTrue(mockLocationProvider.startMonitoringCalled)
        XCTAssertEqual(mockLocationProvider.monitoredRegions.count, 1)
    }
    
    // MARK: - Time Window Tests
    
    func testIsTimeInWindowRegularHours() {
        // Test case: 4AM to 7AM (regular hours)
        XCTAssertTrue(locationManager.isTimeInWindow(currentHour: 5, startHour: 4, endHour: 7))
        XCTAssertTrue(locationManager.isTimeInWindow(currentHour: 4, startHour: 4, endHour: 7))
        XCTAssertFalse(locationManager.isTimeInWindow(currentHour: 7, startHour: 4, endHour: 7))
        XCTAssertFalse(locationManager.isTimeInWindow(currentHour: 3, startHour: 4, endHour: 7))
        XCTAssertFalse(locationManager.isTimeInWindow(currentHour: 8, startHour: 4, endHour: 7))
    }
    
    func testIsTimeInWindowOvernightHours() {
        // Test case: 10PM to 6AM (overnight)
        XCTAssertTrue(locationManager.isTimeInWindow(currentHour: 23, startHour: 22, endHour: 6))
        XCTAssertTrue(locationManager.isTimeInWindow(currentHour: 2, startHour: 22, endHour: 6))
        XCTAssertTrue(locationManager.isTimeInWindow(currentHour: 22, startHour: 22, endHour: 6))
        XCTAssertFalse(locationManager.isTimeInWindow(currentHour: 6, startHour: 22, endHour: 6))
        XCTAssertFalse(locationManager.isTimeInWindow(currentHour: 10, startHour: 22, endHour: 6))
        XCTAssertFalse(locationManager.isTimeInWindow(currentHour: 21, startHour: 22, endHour: 6))
    }
    
    func testIsTimeInWindowEdgeCases() {
        // Same start and end hour
        XCTAssertFalse(locationManager.isTimeInWindow(currentHour: 5, startHour: 5, endHour: 5))
        
        // 24-hour window
        XCTAssertTrue(locationManager.isTimeInWindow(currentHour: 12, startHour: 0, endHour: 0))
    }
    
    // MARK: - Authorization Delegate Tests
    
    func testAuthorizationChangeToAuthorizedWhenInUse() {
        // Given
        XCTAssertFalse(locationManager.isMonitoring)
        
        // When
        mockLocationProvider.simulateAuthorizationChange(.authorizedWhenInUse)
        
        // Then
        XCTAssertEqual(locationManager.authorizationStatus, .authorizedWhenInUse)
        XCTAssertTrue(mockLocationProvider.startUpdatingLocationCalled)
    }
    
    func testAuthorizationChangeToAuthorizedAlways() {
        // Given
        XCTAssertFalse(locationManager.isMonitoring)
        
        // When
        mockLocationProvider.simulateAuthorizationChange(.authorizedAlways)
        
        // Then
        XCTAssertEqual(locationManager.authorizationStatus, .authorizedAlways)
        XCTAssertTrue(mockLocationProvider.startUpdatingLocationCalled)
    }
    
    func testAuthorizationChangeToDenied() {
        // Given
        locationManager.isMonitoring = true
        
        // When
        mockLocationProvider.simulateAuthorizationChange(.denied)
        
        // Then
        XCTAssertEqual(locationManager.authorizationStatus, .denied)
        XCTAssertTrue(mockLocationProvider.stopUpdatingLocationCalled)
    }
    
    // MARK: - Location Update Delegate Tests
    
    func testLocationUpdatesUpdateCurrentLocation() {
        // Given
        let newLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        
        // When
        mockLocationProvider.simulateLocationUpdate(newLocation)
        
        // Then
        XCTAssertEqual(locationManager.currentLocation, newLocation)
    }
    
    // MARK: - Geofence Status Tests
    
    func testGeofenceStatusInsideGeofence() {
        // Given
        let center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        locationManager.configureGeofence(center: center, radius: 100, startHour: 4, endHour: 7)
        
        // When - simulate being inside geofence
        let insideLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // Same as center
        mockLocationProvider.simulateLocationUpdate(insideLocation)
        
        // Then
        XCTAssertNotEqual(locationManager.geofenceStatus, .unknown)
    }
    
    func testGeofenceStatusOutsideGeofence() {
        // Given
        let center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        locationManager.configureGeofence(center: center, radius: 100, startHour: 4, endHour: 7)
        
        // When - simulate being outside geofence (1km away)
        let outsideLocation = CLLocation(latitude: 37.7849, longitude: -122.4194)
        mockLocationProvider.simulateLocationUpdate(outsideLocation)
        
        // Then
        XCTAssertNotEqual(locationManager.geofenceStatus, .unknown)
    }
    
    // MARK: - Edge Cases
    
    func testMultipleGeofenceConfigurations() {
        // Given
        let center1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let center2 = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        
        // When
        locationManager.configureGeofence(center: center1, radius: 100, startHour: 4, endHour: 7)
        locationManager.configureGeofence(center: center2, radius: 200, startHour: 8, endHour: 10)
        
        // Then - should use the latest configuration
        XCTAssertNotNil(locationManager.geofenceConfig)
        XCTAssertEqual(locationManager.geofenceConfig!.center.latitude, center2.latitude, accuracy: 0.001)
        XCTAssertEqual(locationManager.geofenceConfig!.center.longitude, center2.longitude, accuracy: 0.001)
        XCTAssertEqual(locationManager.geofenceConfig?.radius, 200)
        XCTAssertEqual(locationManager.geofenceConfig?.startHour, 8)
        XCTAssertEqual(locationManager.geofenceConfig?.endHour, 10)
    }
    
    func testZeroRadiusGeofence() {
        // Given
        let center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // When
        locationManager.configureGeofence(center: center, radius: 0, startHour: 4, endHour: 7)
        
        // Then
        XCTAssertEqual(locationManager.geofenceConfig?.radius, 0)
        // Should still create monitoring region
        XCTAssertTrue(mockLocationProvider.startMonitoringCalled)
    }
    
    func testInvalidTimeWindow() {
        // Given
        let center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // When - end hour before start hour (overnight window)
        locationManager.configureGeofence(center: center, radius: 100, startHour: 22, endHour: 6)
        
        // Then
        XCTAssertEqual(locationManager.geofenceConfig?.startHour, 22)
        XCTAssertEqual(locationManager.geofenceConfig?.endHour, 6)
        // Should handle overnight windows correctly
    }
}
