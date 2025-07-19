import SwiftUI
import MapKit

// MARK: - ViewModel
@MainActor
class LocationPickerViewModel: ObservableObject {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @Published var selectedCoordinate: CLLocationCoordinate2D?
    
    @ObservedObject private var locationManager: LocationManager
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }
    
    // MARK: - Computed Properties
    var annotations: [MapAnnotation] {
        if let coordinate = selectedCoordinate {
            return [MapAnnotation(coordinate: coordinate)]
        }
        return []
    }
    
    var hasSelectedLocation: Bool {
        return selectedCoordinate != nil
    }
    
    // MARK: - Actions
    func setupInitialLocation() {
        if let currentLocation = locationManager.currentLocation {
            updateRegion(center: currentLocation.coordinate)
        }
    }
    
    func handleMapTap(at location: CGPoint, in mapSize: CGSize) {
        let coordinate = convertToCoordinate(from: location, in: mapSize)
        selectedCoordinate = coordinate
        updateRegion(center: coordinate)
    }
    
    func selectCurrentLocation(completion: (CLLocationCoordinate2D) -> Void) {
        guard let coordinate = selectedCoordinate else { return }
        completion(coordinate)
    }
    
    // MARK: - Private Helpers
    private func updateRegion(center: CLLocationCoordinate2D) {
        let newRegion = MKCoordinateRegion(
            center: center,
            span: region.span
        )
        
        region = newRegion
    }
    
    private func convertToCoordinate(from location: CGPoint, in mapSize: CGSize) -> CLLocationCoordinate2D {
        let x = location.x / mapSize.width
        let y = location.y / mapSize.height
        
        let longitudeDelta = region.span.longitudeDelta
        let latitudeDelta = region.span.latitudeDelta
        
        let longitude = region.center.longitude - (longitudeDelta / 2) + (longitudeDelta * Double(x))
        let latitude = region.center.latitude + (latitudeDelta / 2) - (latitudeDelta * Double(y))
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Supporting Types
struct MapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

extension MKMapRect {
    init(region: MKCoordinateRegion) {
        let topLeft = CLLocationCoordinate2D(
            latitude: region.center.latitude + (region.span.latitudeDelta / 2),
            longitude: region.center.longitude - (region.span.longitudeDelta / 2)
        )
        let bottomRight = CLLocationCoordinate2D(
            latitude: region.center.latitude - (region.span.latitudeDelta / 2),
            longitude: region.center.longitude + (region.span.longitudeDelta / 2)
        )
        
        let topLeftMapPoint = MKMapPoint(topLeft)
        let bottomRightMapPoint = MKMapPoint(bottomRight)
        
        self.init(
            x: min(topLeftMapPoint.x, bottomRightMapPoint.x),
            y: min(topLeftMapPoint.y, bottomRightMapPoint.y),
            width: abs(topLeftMapPoint.x - bottomRightMapPoint.x),
            height: abs(topLeftMapPoint.y - bottomRightMapPoint.y)
        )
    }
}
