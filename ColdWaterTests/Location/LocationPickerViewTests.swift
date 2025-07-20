import XCTest
import SwiftUI
import MapKit
import CoreLocation
@testable import ColdWater

@MainActor
final class LocationPickerViewModelTests: XCTestCase {
    var viewModel: LocationPickerViewModel!
    var mockLocationManager: LocationManager!
    var mockLocationProvider: MockLocationProvider!
    
    override func setUp() {
        super.setUp()
        mockLocationProvider = MockLocationProvider()
        mockLocationProvider.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockLocationManager = LocationManager(locationProvider: mockLocationProvider)
        
        viewModel = LocationPickerViewModel(locationManager: mockLocationManager)
    }
    
    override func tearDown() {
        viewModel = nil
        mockLocationManager = nil
        mockLocationProvider = nil
        super.tearDown()
    }
    
    // MARK: - ViewModel Initialization Tests
    
    func testViewModelInitialization() {
        // Given/When
        let viewModel = LocationPickerViewModel(locationManager: mockLocationManager)
        
        // Then
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.region.center.latitude, 37.7749, accuracy: 0.001)
        XCTAssertEqual(viewModel.region.center.longitude, -122.4194, accuracy: 0.001)
        XCTAssertNil(viewModel.selectedCoordinate)
        XCTAssertFalse(viewModel.hasSelectedLocation)
    }
    
    // MARK: - Location Setup Tests
    
    func testSetupInitialLocationWithCurrentLocation() {
        // Given
        let currentLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        mockLocationManager.currentLocation = currentLocation
        
        // When
        viewModel.setupInitialLocation()
        
        // Then
        XCTAssertEqual(viewModel.region.center.latitude, 40.7128, accuracy: 0.001)
        XCTAssertEqual(viewModel.region.center.longitude, -74.0060, accuracy: 0.001)
    }
    
    func testSetupInitialLocationWithoutCurrentLocation() {
        // Given
        mockLocationManager.currentLocation = nil
        
        // When
        viewModel.setupInitialLocation()
        
        // Then
        // Should maintain default San Francisco coordinates
        XCTAssertEqual(viewModel.region.center.latitude, 37.7749, accuracy: 0.001)
        XCTAssertEqual(viewModel.region.center.longitude, -122.4194, accuracy: 0.001)
    }
    
    // MARK: - Map Interaction Tests
    
    func testHandleMapTapUpdatesSelectedCoordinate() {
        // Given
        let mapSize = CGSize(width: 400, height: 300)
        let tapLocation = CGPoint(x: 200, y: 150) // Center of the map
        
        // When
        viewModel.handleMapTap(at: tapLocation, in: mapSize)
        
        // Then
        XCTAssertNotNil(viewModel.selectedCoordinate)
        XCTAssertTrue(viewModel.hasSelectedLocation)
        
        // Tapping the center should give us approximately the center coordinate
        let selectedCoordinate = viewModel.selectedCoordinate!
        XCTAssertEqual(selectedCoordinate.latitude, viewModel.region.center.latitude, accuracy: 0.001)
        XCTAssertEqual(selectedCoordinate.longitude, viewModel.region.center.longitude, accuracy: 0.001)
    }
    
    func testHandleMapTapUpdatesRegion() {
        // Given
        let mapSize = CGSize(width: 400, height: 300)
        let tapLocation = CGPoint(x: 300, y: 100) // Off-center tap
        let originalCenter = viewModel.region.center
        
        // When
        viewModel.handleMapTap(at: tapLocation, in: mapSize)
        
        // Then
        // Region center should be updated to the tapped coordinate
        XCTAssertNotEqual(viewModel.region.center.latitude, originalCenter.latitude)
        XCTAssertNotEqual(viewModel.region.center.longitude, originalCenter.longitude)
        
        // The selected coordinate should match the new region center
        let selectedCoordinate = viewModel.selectedCoordinate!
        XCTAssertEqual(selectedCoordinate.latitude, viewModel.region.center.latitude, accuracy: 0.001)
        XCTAssertEqual(selectedCoordinate.longitude, viewModel.region.center.longitude, accuracy: 0.001)
    }
    
    // MARK: - Coordinate Conversion Tests
    
    func testCoordinateConversionCenterTap() {
        // Given
        let mapSize = CGSize(width: 400, height: 300)
        let centerTap = CGPoint(x: 200, y: 150) // Exact center
        let expectedCenter = viewModel.region.center
        
        // When
        viewModel.handleMapTap(at: centerTap, in: mapSize)
        
        // Then
        let convertedCoordinate = viewModel.selectedCoordinate!
        XCTAssertEqual(convertedCoordinate.latitude, expectedCenter.latitude, accuracy: 0.001)
        XCTAssertEqual(convertedCoordinate.longitude, expectedCenter.longitude, accuracy: 0.001)
    }
    
    func testCoordinateConversionCorners() {
        // Given
        let mapSize = CGSize(width: 400, height: 300)
        let originalRegion = viewModel.region
        
        let testCases: [(CGPoint, String)] = [
            (CGPoint(x: 0, y: 0), "top-left"),
            (CGPoint(x: 400, y: 0), "top-right"),
            (CGPoint(x: 0, y: 300), "bottom-left"),
            (CGPoint(x: 400, y: 300), "bottom-right")
        ]
        
        for (tapLocation, corner) in testCases {
            // Reset region for consistent testing
            viewModel.region = originalRegion
            
            // When
            viewModel.handleMapTap(at: tapLocation, in: mapSize)
            
            // Then
            let coordinate = viewModel.selectedCoordinate!
            XCTAssertTrue(CLLocationCoordinate2DIsValid(coordinate), "Coordinate should be valid for \(corner)")
            
            // Check that coordinates are within reasonable bounds
            XCTAssertGreaterThanOrEqual(coordinate.latitude, -90)
            XCTAssertLessThanOrEqual(coordinate.latitude, 90)
            XCTAssertGreaterThanOrEqual(coordinate.longitude, -180)
            XCTAssertLessThanOrEqual(coordinate.longitude, 180)
        }
    }
    
    func testCoordinateConversionBoundaryCalculations() {
        // Test the mathematical accuracy of coordinate conversion
        
        // Given
        let mapSize = CGSize(width: 400, height: 300)
        let testRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        viewModel.region = testRegion
        
        // Test specific points and their expected coordinates
        let testCases: [(CGPoint, CLLocationCoordinate2D, String)] = [
            // Top-left corner
            (CGPoint(x: 0, y: 0),
             CLLocationCoordinate2D(latitude: 37.7749 + 0.005, longitude: -122.4194 - 0.005),
             "top-left"),
            // Bottom-right corner
            (CGPoint(x: 400, y: 300),
             CLLocationCoordinate2D(latitude: 37.7749 - 0.005, longitude: -122.4194 + 0.005),
             "bottom-right"),
            // Center
            (CGPoint(x: 200, y: 150),
             CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
             "center")
        ]
        
        for (tapLocation, expectedCoordinate, description) in testCases {
            // When
            viewModel.handleMapTap(at: tapLocation, in: mapSize)
            
            // Then
            let actualCoordinate = viewModel.selectedCoordinate!
            XCTAssertEqual(actualCoordinate.latitude, expectedCoordinate.latitude, accuracy: 0.01,
                          "Latitude should match for \(description)")
            XCTAssertEqual(actualCoordinate.longitude, expectedCoordinate.longitude, accuracy: 0.01,
                          "Longitude should match for \(description)")
        }
    }
    
    // MARK: - Annotation Tests
    
    func testAnnotationsWithoutSelectedCoordinate() {
        // Given/When
        let annotations = viewModel.annotations
        
        // Then
        XCTAssertTrue(annotations.isEmpty)
    }
    
    func testAnnotationsWithSelectedCoordinate() {
        // Given
        let testCoordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        viewModel.selectedCoordinate = testCoordinate
        
        // When
        let annotations = viewModel.annotations
        
        // Then
        XCTAssertEqual(annotations.count, 1)
        let annotation = annotations.first!
        XCTAssertEqual(annotation.coordinate.latitude, testCoordinate.latitude, accuracy: 0.001)
        XCTAssertEqual(annotation.coordinate.longitude, testCoordinate.longitude, accuracy: 0.001)
        XCTAssertNotNil(annotation.id)
    }
    
    func testAnnotationsUpdateWhenSelectedCoordinateChanges() {
        // Given
        let coordinate1 = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let coordinate2 = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
        
        // When - First coordinate
        viewModel.selectedCoordinate = coordinate1
        let annotations1 = viewModel.annotations
        
        // When - Second coordinate
        viewModel.selectedCoordinate = coordinate2
        let annotations2 = viewModel.annotations
        
        // When - No coordinate
        viewModel.selectedCoordinate = nil
        let annotations3 = viewModel.annotations
        
        // Then
        XCTAssertEqual(annotations1.count, 1)
        XCTAssertEqual(annotations1.first!.coordinate.latitude, coordinate1.latitude, accuracy: 0.001)
        
        XCTAssertEqual(annotations2.count, 1)
        XCTAssertEqual(annotations2.first!.coordinate.latitude, coordinate2.latitude, accuracy: 0.001)
        
        XCTAssertTrue(annotations3.isEmpty)
    }
    
    // MARK: - Selection Tests
    
    func testSelectCurrentLocationWithValidCoordinate() {
        // Given
        let testCoordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        viewModel.selectedCoordinate = testCoordinate
        var completionCalled = false
        var returnedCoordinate: CLLocationCoordinate2D?
        
        // When
        viewModel.selectCurrentLocation { coordinate in
            completionCalled = true
            returnedCoordinate = coordinate
        }
        
        // Then
        XCTAssertTrue(completionCalled)
        XCTAssertNotNil(returnedCoordinate)
        let unwrappedCoordinate = returnedCoordinate!
        XCTAssertEqual(unwrappedCoordinate.latitude, testCoordinate.latitude, accuracy: 0.001)
        XCTAssertEqual(unwrappedCoordinate.longitude, testCoordinate.longitude, accuracy: 0.001)
    }
    
    func testSelectCurrentLocationWithoutSelectedCoordinate() {
        // Given
        viewModel.selectedCoordinate = nil
        var completionCalled = false
        
        // When
        viewModel.selectCurrentLocation { _ in
            completionCalled = true
        }
        
        // Then
        XCTAssertFalse(completionCalled)
    }
    
    func testSelectCurrentLocationMultipleTimes() {
        // Given
        let testCoordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        viewModel.selectedCoordinate = testCoordinate
        var callCount = 0
        
        // When
        viewModel.selectCurrentLocation { _ in callCount += 1 }
        viewModel.selectCurrentLocation { _ in callCount += 1 }
        viewModel.selectCurrentLocation { _ in callCount += 1 }
        
        // Then
        XCTAssertEqual(callCount, 3)
    }
    
    // MARK: - State Management Tests
    
    func testHasSelectedLocationProperty() {
        // Given/When/Then - Initially false
        XCTAssertFalse(viewModel.hasSelectedLocation)
        
        // When - Set coordinate
        viewModel.selectedCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Then - Should be true
        XCTAssertTrue(viewModel.hasSelectedLocation)
        
        // When - Clear coordinate
        viewModel.selectedCoordinate = nil
        
        // Then - Should be false again
        XCTAssertFalse(viewModel.hasSelectedLocation)
    }
    
    func testRegionSpanPreservation() {
        // Given
        let originalSpan = viewModel.region.span
        let mapSize = CGSize(width: 400, height: 300)
        let tapLocation = CGPoint(x: 200, y: 150)
        
        // When
        viewModel.handleMapTap(at: tapLocation, in: mapSize)
        
        // Then
        // Span should be preserved when updating region center
        XCTAssertEqual(viewModel.region.span.latitudeDelta, originalSpan.latitudeDelta, accuracy: 0.000001)
        XCTAssertEqual(viewModel.region.span.longitudeDelta, originalSpan.longitudeDelta, accuracy: 0.000001)
    }
    
    // MARK: - Performance Tests
    
    func testViewModelCreationPerformance() {
        measure {
            for _ in 0..<100 {
                _ = LocationPickerViewModel(locationManager: mockLocationManager)
            }
        }
    }
    
    func testCoordinateConversionPerformance() {
        measure {
            let mapSize = CGSize(width: 400, height: 300)
            for i in 0..<1000 {
                let tapLocation = CGPoint(x: Double(i % 400), y: Double(i % 300))
                viewModel.handleMapTap(at: tapLocation, in: mapSize)
            }
        }
    }
    
    func testAnnotationGenerationPerformance() {
        // Given
        viewModel.selectedCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        measure {
            for _ in 0..<1000 {
                _ = viewModel.annotations
            }
        }
    }
    
    func testHasSelectedLocationPerformance() {
        measure {
            for i in 0..<1000 {
                if i % 2 == 0 {
                    viewModel.selectedCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                } else {
                    viewModel.selectedCoordinate = nil
                }
                _ = viewModel.hasSelectedLocation
            }
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testCoordinateConversionWithZeroMapSize() {
        // Given
        let mapSize = CGSize(width: 0, height: 0)
        let tapLocation = CGPoint(x: 0, y: 0)
        
        // When
        viewModel.handleMapTap(at: tapLocation, in: mapSize)
        
        // Then
        // Should handle gracefully without crashing
        XCTAssertNotNil(viewModel.selectedCoordinate)
        // The coordinate might not be meaningful, but it shouldn't crash
    }
    
    func testCoordinateConversionWithNegativeTapLocation() {
        // Given
        let mapSize = CGSize(width: 400, height: 300)
        let tapLocation = CGPoint(x: -50, y: -30)
        
        // When
        viewModel.handleMapTap(at: tapLocation, in: mapSize)
        
        // Then
        XCTAssertNotNil(viewModel.selectedCoordinate)
        let coordinate = viewModel.selectedCoordinate!
        XCTAssertTrue(CLLocationCoordinate2DIsValid(coordinate))
    }
    
    func testCoordinateConversionWithExtremelyLargeTapLocation() {
        // Given
        let mapSize = CGSize(width: 400, height: 300)
        let tapLocation = CGPoint(x: 10000, y: 8000)
        
        // When
        viewModel.handleMapTap(at: tapLocation, in: mapSize)
        
        // Then
        XCTAssertNotNil(viewModel.selectedCoordinate)
        let coordinate = viewModel.selectedCoordinate!
        XCTAssertTrue(CLLocationCoordinate2DIsValid(coordinate))
    }
    
    func testCoordinateConversionWithExtremelySmallRegion() {
        // Given
        viewModel.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.000001, longitudeDelta: 0.000001)
        )
        let mapSize = CGSize(width: 400, height: 300)
        let tapLocation = CGPoint(x: 200, y: 150)
        
        // When
        viewModel.handleMapTap(at: tapLocation, in: mapSize)
        
        // Then
        XCTAssertNotNil(viewModel.selectedCoordinate)
        let coordinate = viewModel.selectedCoordinate!
        XCTAssertTrue(CLLocationCoordinate2DIsValid(coordinate))
        // Should be very close to the center due to small span
        XCTAssertEqual(coordinate.latitude, 37.7749, accuracy: 0.001)
        XCTAssertEqual(coordinate.longitude, -122.4194, accuracy: 0.001)
    }
    
    func testCoordinateConversionWithExtremelyLargeRegion() {
        // Given
        viewModel.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
        )
        let mapSize = CGSize(width: 400, height: 300)
        let tapLocation = CGPoint(x: 200, y: 150)
        
        // When
        viewModel.handleMapTap(at: tapLocation, in: mapSize)
        
        // Then
        XCTAssertNotNil(viewModel.selectedCoordinate)
        let coordinate = viewModel.selectedCoordinate!
        XCTAssertTrue(CLLocationCoordinate2DIsValid(coordinate))
    }
    
    // MARK: - Integration Tests
    
    func testCompleteLocationSelectionWorkflow() {
        // Given
        let mapSize = CGSize(width: 400, height: 300)
        let tapLocation = CGPoint(x: 300, y: 100)
        var selectedCoordinate: CLLocationCoordinate2D?
        var completionCalled = false
        
        // When - Simulate user tapping on map
        viewModel.handleMapTap(at: tapLocation, in: mapSize)
        
        // Then - Coordinate should be selected
        XCTAssertTrue(viewModel.hasSelectedLocation)
        XCTAssertNotNil(viewModel.selectedCoordinate)
        XCTAssertEqual(viewModel.annotations.count, 1)
        
        // When - Simulate user pressing "Select" button
        viewModel.selectCurrentLocation { coordinate in
            selectedCoordinate = coordinate
            completionCalled = true
        }
        
        // Then - Completion should be called with the coordinate
        XCTAssertTrue(completionCalled)
        XCTAssertNotNil(selectedCoordinate)
        let unwrappedSelected = selectedCoordinate!
        let viewModelSelected = viewModel.selectedCoordinate!
        XCTAssertEqual(unwrappedSelected.latitude, viewModelSelected.latitude, accuracy: 0.001)
        XCTAssertEqual(unwrappedSelected.longitude, viewModelSelected.longitude, accuracy: 0.001)
    }
    
    func testLocationManagerIntegrationWithSetup() {
        // Given
        let testLocation = CLLocation(latitude: 34.0522, longitude: -118.2437)
        mockLocationManager.currentLocation = testLocation
        
        // When
        viewModel.setupInitialLocation()
        
        // Then
        XCTAssertEqual(viewModel.region.center.latitude, 34.0522, accuracy: 0.001)
        XCTAssertEqual(viewModel.region.center.longitude, -118.2437, accuracy: 0.001)
    }
    
    func testLocationManagerIntegrationWithoutLocation() {
        // Given
        mockLocationManager.currentLocation = nil
        let originalRegion = viewModel.region
        
        // When
        viewModel.setupInitialLocation()
        
        // Then
        // Should keep original region when no current location
        XCTAssertEqual(viewModel.region.center.latitude, originalRegion.center.latitude, accuracy: 0.001)
        XCTAssertEqual(viewModel.region.center.longitude, originalRegion.center.longitude, accuracy: 0.001)
    }
    
    func testMultipleMapTapsWorkflow() {
        // Given
        let mapSize = CGSize(width: 400, height: 300)
        let locations = [
            CGPoint(x: 100, y: 75),
            CGPoint(x: 200, y: 150),
            CGPoint(x: 300, y: 225)
        ]
        var selectedCoordinates: [CLLocationCoordinate2D] = []
        
        // When - Multiple taps
        for location in locations {
            viewModel.handleMapTap(at: location, in: mapSize)
            if let coordinate = viewModel.selectedCoordinate {
                selectedCoordinates.append(coordinate)
            }
        }
        
        // Then
        XCTAssertEqual(selectedCoordinates.count, 3)
        XCTAssertTrue(viewModel.hasSelectedLocation)
        
        // Final selection should be the last tap
        let currentSelected = viewModel.selectedCoordinate!
        let lastSelected = selectedCoordinates.last!
        XCTAssertEqual(currentSelected.latitude, lastSelected.latitude, accuracy: 0.001)
        XCTAssertEqual(currentSelected.longitude, lastSelected.longitude, accuracy: 0.001)
        
        // Should only have one annotation (the latest)
        XCTAssertEqual(viewModel.annotations.count, 1)
    }
}

// MARK: - View Integration Tests

final class LocationPickerViewTests: XCTestCase {
    var mockLocationManager: LocationManager!
    var mockLocationProvider: MockLocationProvider!
    
    override func setUp() {
        super.setUp()
        mockLocationProvider = MockLocationProvider()
        mockLocationProvider.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockLocationManager = LocationManager(locationProvider: mockLocationProvider)
    }
    
    override func tearDown() {
        mockLocationManager = nil
        mockLocationProvider = nil
        super.tearDown()
    }
    
    func testLocationPickerViewInitialization() {
        // Given
        var selectedCoordinate: CLLocationCoordinate2D?
        var cancelCalled = false
        
        // When
        let view = LocationPickerView(
            locationManager: mockLocationManager,
            onLocationSelected: { coordinate in
                selectedCoordinate = coordinate
            },
            onCancel: {
                cancelCalled = true
            }
        )
        
        // Then
        XCTAssertNotNil(view)
        XCTAssertNotNil(view.body)
        XCTAssertNil(selectedCoordinate)
        XCTAssertFalse(cancelCalled)
    }
    
    func testLocationPickerViewCallbackSignatures() {
        // Given
        var selectedCoordinate: CLLocationCoordinate2D?
        var cancelCalled = false
        let expectedCoordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        
        let onLocationSelected: (CLLocationCoordinate2D) -> Void = { coordinate in
            selectedCoordinate = coordinate
        }
        
        let onCancel: () -> Void = {
            cancelCalled = true
        }
        
        // When
        let view = LocationPickerView(
            locationManager: mockLocationManager,
            onLocationSelected: onLocationSelected,
            onCancel: onCancel
        )
        
        // Simulate callbacks
        onLocationSelected(expectedCoordinate)
        onCancel()
        
        // Then
        XCTAssertNotNil(view.body)
        let unwrappedSelected = selectedCoordinate!
        XCTAssertEqual(unwrappedSelected.latitude, expectedCoordinate.latitude, accuracy: 0.001)
        XCTAssertEqual(unwrappedSelected.longitude, expectedCoordinate.longitude, accuracy: 0.001)
        XCTAssertTrue(cancelCalled)
    }
    
    func testLocationPickerViewWithDifferentLocationManagers() {
        // Test that the view works with different location manager configurations
        
        // Given
        let configurations: [(CLLocation?, String)] = [
            (CLLocation(latitude: 37.7749, longitude: -122.4194), "San Francisco"),
            (CLLocation(latitude: 40.7128, longitude: -74.0060), "New York"),
            (nil, "No Location")
        ]
        
        for (location, description) in configurations {
            // Given
            let provider = MockLocationProvider()
            provider.mockLocation = location
            let manager = LocationManager(locationProvider: provider)
            
            // When
            let view = LocationPickerView(
                locationManager: manager,
                onLocationSelected: { _ in },
                onCancel: { }
            )
            
            // Then
            XCTAssertNotNil(view.body, "View should initialize with \(description)")
        }
    }
}

// MARK: - Supporting Types Tests

final class MapAnnotationTests: XCTestCase {
    
    func testMapAnnotationCreation() {
        // Given
        let testCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // When
        let annotation = MapAnnotation(coordinate: testCoordinate)
        
        // Then
        XCTAssertNotNil(annotation.id)
        XCTAssertEqual(annotation.coordinate.latitude, testCoordinate.latitude, accuracy: 0.001)
        XCTAssertEqual(annotation.coordinate.longitude, testCoordinate.longitude, accuracy: 0.001)
    }
    
    func testMapAnnotationUniqueIDs() {
        // Given
        let coordinate1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let coordinate2 = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        
        // When
        let annotation1 = MapAnnotation(coordinate: coordinate1)
        let annotation2 = MapAnnotation(coordinate: coordinate2)
        
        // Then
        XCTAssertNotEqual(annotation1.id, annotation2.id)
    }
    
    func testMapAnnotationIdentifiable() {
        // Test that MapAnnotation properly conforms to Identifiable
        
        // Given
        let coordinates = [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
        ]
        
        // When
        let annotations = coordinates.map { MapAnnotation(coordinate: $0) }
        let uniqueIDs = Set(annotations.map { $0.id })
        
        // Then
        XCTAssertEqual(annotations.count, uniqueIDs.count, "All annotations should have unique IDs")
    }
}

// MARK: - MKMapRect Extension Tests

final class MKMapRectExtensionTests: XCTestCase {
    
    func testMKMapRectFromRegion() {
        // Given
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        // When
        let mapRect = MKMapRect(region: region)
        
        // Then
        XCTAssertTrue(mapRect.size.width > 0)
        XCTAssertTrue(mapRect.size.height > 0)
        XCTAssertFalse(mapRect.isNull)
        XCTAssertFalse(mapRect.isEmpty)
    }
    
    func testMKMapRectWithVariousRegionSizes() {
        // Given
        let testCases: [(MKCoordinateSpan, String)] = [
            (MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001), "small"),
            (MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1), "medium"),
            (MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0), "large"),
            (MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0), "very large")
        ]
        
        for (span, size) in testCases {
            // Given
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: span
            )
            
            // When
            let mapRect = MKMapRect(region: region)
            
            // Then
            XCTAssertTrue(mapRect.size.width > 0, "Width should be positive for \(size) region")
            XCTAssertTrue(mapRect.size.height > 0, "Height should be positive for \(size) region")
            XCTAssertFalse(mapRect.isNull, "Map rect should not be null for \(size) region")
            XCTAssertFalse(mapRect.isEmpty, "Map rect should not be empty for \(size) region")
        }
    }
    
    func testMKMapRectCornerCalculations() {
        // Test that the corner calculations in the extension are correct
        
        // Given
        let center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        let region = MKCoordinateRegion(center: center, span: span)
        
        // Expected corners
        let expectedTopLeft = CLLocationCoordinate2D(
            latitude: center.latitude + (span.latitudeDelta / 2),
            longitude: center.longitude - (span.longitudeDelta / 2)
        )
        let expectedBottomRight = CLLocationCoordinate2D(
            latitude: center.latitude - (span.latitudeDelta / 2),
            longitude: center.longitude + (span.longitudeDelta / 2)
        )
        
        // When
        let mapRect = MKMapRect(region: region)
        
        // Then
        // Convert back to coordinates to verify
        let topLeftPoint = MKMapPoint(expectedTopLeft)
        let bottomRightPoint = MKMapPoint(expectedBottomRight)
        
        XCTAssertEqual(mapRect.minX, min(topLeftPoint.x, bottomRightPoint.x), accuracy: 1.0)
        XCTAssertEqual(mapRect.minY, min(topLeftPoint.y, bottomRightPoint.y), accuracy: 1.0)
        XCTAssertEqual(mapRect.width, abs(topLeftPoint.x - bottomRightPoint.x), accuracy: 1.0)
        XCTAssertEqual(mapRect.height, abs(topLeftPoint.y - bottomRightPoint.y), accuracy: 1.0)
    }
    
    func testMKMapRectWithZeroSpan() {
        // Test edge case with zero span
        
        // Given
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0, longitudeDelta: 0)
        )
        
        // When
        let mapRect = MKMapRect(region: region)
        
        // Then
        // Should handle gracefully, even if not particularly useful
        XCTAssertFalse(mapRect.isNull, "Map rect should not be null even with zero span")
    }
}
