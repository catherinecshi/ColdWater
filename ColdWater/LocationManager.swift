import Foundation
import CoreLocation
import UserNotifications

// MARK: - Protocols for Dependency Injection

protocol LocationProviding {
    var authorizationStatus: CLAuthorizationStatus { get }
    var delegate: CLLocationManagerDelegate? { get set }
    
    func requestWhenInUseAuthorization()
    func requestAlwaysAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
    func startMonitoring(for region: CLRegion)
    func stopMonitoring(for region: CLRegion)
}

// MARK: - CLLocationManager Extension

extension CLLocationManager: LocationProviding {
    // CLLocationManager already implements all required methods and properties
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject {
    private var locationProvider: LocationProviding
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isMonitoring = false
    @Published var geofenceStatus: GeofenceStatus = .unknown
    
    var onStatusChanged: (() -> Void)?
    
    struct GeofenceConfig {
        let center: CLLocationCoordinate2D
        let radius: CLLocationDistance
        let startHour: Int // 24-hour format
        let endHour: Int   // 24-hour format
        let identifier: String
    }
    
    enum GeofenceStatus {
        case unknown
        case insideGeofence
        case outsideGeofence
        case outsideGeofenceInTimeWindow
        case insideGeofenceInTimeWindow
    }
    
    @Published var geofenceConfig: GeofenceConfig?
    
    // Dependency injection constructor for testing
    init(locationProvider: LocationProviding = CLLocationManager()) {
        self.locationProvider = locationProvider
        super.init()
        
        // Set delegate more explicitly
        if let clLocationManager = locationProvider as? CLLocationManager {
            clLocationManager.delegate = self
            clLocationManager.desiredAccuracy = kCLLocationAccuracyBest
            print("✅ Delegate set directly on CLLocationManager")
        } else {
            self.locationProvider.delegate = self
            print("⚠️ Delegate set through protocol")
        }
        
        authorizationStatus = locationProvider.authorizationStatus
        requestNotificationPermission()
    }
    
    // Keep the original initializer for convenience
    override convenience init() {
        self.init(locationProvider: CLLocationManager())
    }
    
    private var authorizationStatusDescription: String {
        switch authorizationStatus {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }
    
    func requestLocationPermission() {
        print("🔍 Current authorization status: \(authorizationStatusDescription) (raw: \(authorizationStatus.rawValue))")
        
        switch authorizationStatus {
        case .notDetermined:
            print("📱 Requesting when-in-use authorization...")
            locationProvider.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            print("📱 Requesting always authorization...")
            locationProvider.requestAlwaysAuthorization()
        case .denied, .restricted:
            print("❌ Location access denied. User must enable in Settings.")
        default:
            print("ℹ️ Authorization status: \(authorizationStatusDescription) - no action needed")
            break
        }
        
        // Check if delegate is properly set
        if let clLocationManager = locationProvider as? CLLocationManager {
            print("🔗 Delegate is set: \(clLocationManager.delegate != nil)")
            print("🔗 Delegate is self: \(clLocationManager.delegate === self)")
        }
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            print("Location permission not granted")
            return
        }
        
        print("starting locaiton updates")
        locationProvider.startUpdatingLocation()
        isMonitoring = true
        
        DispatchQueue.main.async {
            self.onStatusChanged?()
        }
    }
    
    private var currentLocationCallback: ((CLLocation?) -> Void)?
    
    func requestCurrentLocation(completion: @escaping (CLLocation?) -> Void) {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            requestLocationPermission()
            completion(nil)
            return
        }
        
        // If we already have a recent location, use it
        if let location = currentLocation,
           location.timestamp.timeIntervalSinceNow > -60 { // Less than 60 seconds old
            completion(location)
            return
        }
        
        // Otherwise, request a fresh location
        currentLocationCallback = completion
        if !isMonitoring {
            startLocationUpdates()
        }
    }
    
    func stopLocationUpdates() {
        locationProvider.stopUpdatingLocation()
        isMonitoring = false
        
        DispatchQueue.main.async {
            self.onStatusChanged?()
        }
    }
    
    func configureGeofence(center: CLLocationCoordinate2D, radius: CLLocationDistance, startHour: Int, endHour: Int) {
        let config = GeofenceConfig(
            center: center,
            radius: radius,
            startHour: startHour,
            endHour: endHour,
            identifier: "MainGeofence"
        )
        
        geofenceConfig = config
        setupGeofenceMonitoring(config: config)
    }
    
    private func setupGeofenceMonitoring(config: GeofenceConfig) {
        let region = CLCircularRegion(
            center: config.center,
            radius: config.radius,
            identifier: config.identifier
        )
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        locationProvider.startMonitoring(for: region)
    }
    
    internal func checkGeofenceStatus() {
        print("checking geofence status")
        guard let config = geofenceConfig,
              let location = currentLocation else { return }
        
        let geofenceCenter = CLLocation(latitude: config.center.latitude, longitude: config.center.longitude)
        let distance = location.distance(from: geofenceCenter)
        let isInside = distance <= config.radius
        
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        let isInTimeWindow = isTimeInWindow(currentHour: currentHour, startHour: config.startHour, endHour: config.endHour)
        
        let newStatus: GeofenceStatus
        if isInside {
            print("inside: \(isInTimeWindow)")
            newStatus = isInTimeWindow ? .insideGeofenceInTimeWindow : .insideGeofence
        } else {
            newStatus = isInTimeWindow ? .outsideGeofenceInTimeWindow : .outsideGeofence
        }
        
        if newStatus != geofenceStatus {
            print("status has been updated")
            geofenceStatus = newStatus
            handleGeofenceStatusChange(newStatus)
            
            // CALL THE CALLBACK when geofence status changes
            DispatchQueue.main.async {
                self.onStatusChanged?()
            }
        }
    }
    
    internal func isTimeInWindow(currentHour: Int, startHour: Int, endHour: Int) -> Bool {
        // Handle 24-hour window case (when start and end are the same)
        if startHour == 0 && endHour == 0 {
            return true
        }
        
        // other cases where start and end hours are the same represent no time window
        if startHour == endHour {
            return false
        }
        
        if startHour < endHour {
            return currentHour >= startHour && currentHour < endHour
        } else {
            // overnight window (22 to 6)
            return currentHour >= startHour || currentHour < endHour
        }
    }
    
    private func handleGeofenceStatusChange(_ status: GeofenceStatus) {
        switch status {
        case .outsideGeofenceInTimeWindow:
            sendNotification(title: "Geofence Alert", body: "You are outside the geofence during the monitoring window!")
        case .insideGeofenceInTimeWindow:
            sendNotification(title: "Geofence Alert", body: "You are inside the geofence during the monitoring window.")
        default:
            break
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        checkGeofenceStatus()
        
        print("location updated")
        
        // Call the callback if we're waiting for current location
        if let callback = currentLocationCallback {
            callback(location)
            currentLocationCallback = nil
        }
    }
    
    // Use the new non-deprecated delegate method
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("🎯 locationManagerDidChangeAuthorization called!")
        print("🧵 Is main thread: \(Thread.isMainThread)")
        
        let oldStatus = authorizationStatus
        let newStatus = locationProvider.authorizationStatus
        
        print("📊 Old (raw: \(oldStatus.rawValue))")
        print("📊 New (raw: \(newStatus.rawValue))")
        
        // Update the published property
        authorizationStatus = newStatus
        
        print("📊 Published status updated to: \(authorizationStatusDescription) (raw: \(authorizationStatus.rawValue))")
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Authorization granted, starting location updates...")
            startLocationUpdates()
        case .denied, .restricted:
            print("❌ Authorization denied/restricted, stopping location updates...")
            stopLocationUpdates()
        case .notDetermined:
            print("❓ Authorization still not determined")
            break
        default:
            print("❓ Unknown authorization status")
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Entered region: \(region.identifier)")
        checkGeofenceStatus()
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Exited region: \(region.identifier)")
        checkGeofenceStatus()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
}
