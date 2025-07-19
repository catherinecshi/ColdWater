import SwiftUI
import CoreLocation

@MainActor
class ContentViewViewModel: ObservableObject {
    @Published var latitude: String = ""
    @Published var longitude: String = ""
    @Published var radius: String = "100"
    @Published var startHour: Int = 4
    @Published var endHour: Int = 7
    @Published var showingLocationPicker = false
    
    private var locationManager: LocationManager
    
    init(locationManager: LocationManager = LocationManager()) {
        self.locationManager = locationManager
        
        // setup callback
        self.locationManager.onStatusChanged = { [weak self] in
            print(" received call back from locationmanager")
            DispatchQueue.main.async {
                print("View model - triggering UI update")
                self?.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Computed Properties
    var authorizationStatusText: String {
        switch locationManager.authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .authorizedWhenInUse: return "When In Use"
        case .authorizedAlways: return "Always"
        @unknown default: return "Unknown"
        }
    }
    
    var authorizationStatusColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedAlways: return .green
        case .authorizedWhenInUse: return .orange
        default: return .red
        }
    }
    
    var geofenceStatusText: String {
        switch locationManager.geofenceStatus {
        case .unknown: return "Unknown"
        case .insideGeofence: return "Inside Geofence"
        case .outsideGeofence: return "Outside Geofence"
        case .outsideGeofenceInTimeWindow: return "Outside (Time Window)"
        case .insideGeofenceInTimeWindow: return "Inside (Time Window)"
        }
    }
    
    var geofenceStatusColor: Color {
        switch locationManager.geofenceStatus {
        case .outsideGeofenceInTimeWindow: return .green
        case .insideGeofenceInTimeWindow: return .red
        case .outsideGeofence: return .blue
        case .insideGeofence: return .blue
        case .unknown: return .gray
        }
    }
    
    var canStartMonitoring: Bool {
        return (locationManager.authorizationStatus == .authorizedAlways ||
                locationManager.authorizationStatus == .authorizedWhenInUse) &&
               !latitude.isEmpty &&
               !longitude.isEmpty &&
               !radius.isEmpty &&
               Double(latitude) != nil &&
               Double(longitude) != nil &&
               Double(radius) != nil
    }
    
    var isMonitoring: Bool {
        return locationManager.isMonitoring
    }
    
    var currentLocation: CLLocation? {
        return locationManager.currentLocation
    }
    
    var geofenceConfig: LocationManager.GeofenceConfig? {
        return locationManager.geofenceConfig
    }
    
    var exposedLocationManager: LocationManager {
        return locationManager
    }
    
    // MARK: - Actions
    func requestLocationPermission() {
        locationManager.requestLocationPermission()
    }
    
    func useCurrentLocation() {
        locationManager.requestCurrentLocation { [weak self] location in
            DispatchQueue.main.async {
                guard let self = self, let location = location else { return }
                self.latitude = String(location.coordinate.latitude)
                self.longitude = String(location.coordinate.longitude)
            }
        }
    }
    
    func startGeofenceMonitoring() {
        guard let lat = Double(latitude),
              let lng = Double(longitude),
              let radiusValue = Double(radius) else {
            return
        }
        
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        locationManager.configureGeofence(
            center: center,
            radius: radiusValue,
            startHour: startHour,
            endHour: endHour
        )
    }
    
    func stopMonitoring() {
        locationManager.stopLocationUpdates()
    }
    
    func handleLocationSelected(_ coordinate: CLLocationCoordinate2D) {
        latitude = String(coordinate.latitude)
        longitude = String(coordinate.longitude)
        showingLocationPicker = false
    }
}
