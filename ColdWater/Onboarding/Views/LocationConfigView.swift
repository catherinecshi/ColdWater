import SwiftUI
import MapKit
import CoreLocation

// MARK: - LocationConfigViewModel with Contextual Permission
@MainActor
class LocationConfigViewModel: NSObject, ObservableObject {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @Published var selectedCoordinate: CLLocationCoordinate2D?
    @Published var selectedLocationName: String?
    @Published var searchResults: [MKMapItem] = []
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var showingLocationPermissionAlert = false
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationAuthorizationStatus = locationManager.authorizationStatus
    }
    
    func setupInitialLocation() {
        // request when in use when first get onto the view
        locationManager.requestWhenInUseAuthorization()
        
        if let currentLocation = locationManager.location {
            updateRegion(center: currentLocation.coordinate)
        }
    }
    
    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func hasLocationPermission() -> Bool {
        return locationAuthorizationStatus == .authorizedWhenInUse || locationAuthorizationStatus == .authorizedAlways
    }
    
    func hasAlwaysPermission() -> Bool {
        return locationAuthorizationStatus == .authorizedAlways
    }
    
    func handleMapTap(at location: CGPoint, in mapSize: CGSize) {
        let coordinate = convertToCoordinate(from: location, in: mapSize)
        selectedCoordinate = coordinate
        selectedLocationName = "Custom Location"
        updateRegion(center: coordinate)
        clearSearchResults()
    }
    
    func searchLocation(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                if let response = response {
                    self?.searchResults = response.mapItems
                } else {
                    self?.searchResults = []
                }
            }
        }
    }
    
    func selectSearchResult(_ mapItem: MKMapItem) {
        selectedCoordinate = mapItem.placemark.coordinate
        selectedLocationName = mapItem.name
        updateRegion(center: mapItem.placemark.coordinate)
        clearSearchResults()
    }
    
    func clearSearchResults() {
        searchResults = []
    }
    
    func updateRegion(center: CLLocationCoordinate2D) {
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

// MARK: - CLLocationManagerDelegate
extension LocationConfigViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.locationAuthorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .denied, .restricted:
                self.showingLocationPermissionAlert = true
                
            default:
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            updateRegion(center: location.coordinate)
        }
    }
}

// MARK: - LocationConfigView with Contextual Permission
struct LocationConfigView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @StateObject private var viewModel = LocationConfigViewModel()
    @State private var searchText = ""
    @State private var selectedRadius: Double = 100
    @State private var showingAlwaysPermissionAlert = false
    
    private let radiusOptions: [Double] = [50, 100, 200, 500, 1000]
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            overlaidMapSection
            Spacer()
            nextButtonSection
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
        .onAppear {
            setupView()
        }
        .onChange(of: selectedRadius) { _ in
            updateLocationWithRadius()
        }
        .onChange(of: viewModel.selectedCoordinate) { _ in
            updateLocationWithRadius()
        }
        .alert("Location Permission Required", isPresented: $viewModel.showingLocationPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This method needs location premissions to work properly")
        }
        .alert("Background Location Access", isPresented: $showingAlwaysPermissionAlert) {
            Button("Allow Always") {
                viewModel.requestAlwaysPermission()
                coordinator.nextStep()
            }
            Button("Keep Current Setting") {
                coordinator.nextStep()
            }
        } message: {
            Text("Choose 'Always' for automatic alarm dismissal when you leave. Otherwise you'll have to open the app each time to turn it off.")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Leave this area to turn off your alarm")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Overlaid Map Section
    private var overlaidMapSection: some View {
        GeometryReader { geometry in
            ZStack {
                // Base Map
                mapContent(geometry: geometry)
                
                // Search Bar (Top)
                VStack {
                    searchBarOverlay
                    Spacer()
                }
                
                // Radius Selector (Right, Vertically Centered)
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        radiusSelectorOverlay
                        Spacer()
                    }
                }
                
                // Selected Location Info (Bottom)
                VStack {
                    Spacer()
                    if viewModel.selectedCoordinate != nil {
                        selectedLocationInfoOverlay
                    }
                }
                
                // Search Results Overlay
                searchResultsOverlay
            }
        }
        .frame(minHeight: 400)
    }
    
    private func mapContent(geometry: GeometryProxy) -> some View {
        ZStack {
            Map(coordinateRegion: $viewModel.region, interactionModes: .all)
                .onTapGesture { location in
                    viewModel.handleMapTap(at: location, in: geometry.size)
                }
            
            // Add annotation as overlay if coordinate exists
            if let coordinate = viewModel.selectedCoordinate {
                GeometryReader { mapGeometry in
                    let position = coordinateToPosition(coordinate, in: mapGeometry.size)
                    ZStack {
                        // Geofence circle
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                            .fill(Color.blue.opacity(0.1))
                            .frame(
                                width: radiusToMapSize(selectedRadius, in: mapGeometry.size),
                                height: radiusToMapSize(selectedRadius, in: mapGeometry.size)
                            )
                        
                        // Center pin
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                    .position(position)
                }
            }
        }
    }
    
    private func coordinateToPosition(_ coordinate: CLLocationCoordinate2D, in mapSize: CGSize) -> CGPoint {
        let latDelta = viewModel.region.span.latitudeDelta
        let lonDelta = viewModel.region.span.longitudeDelta
        
        let x = (coordinate.longitude - viewModel.region.center.longitude + lonDelta/2) / lonDelta * Double(mapSize.width)
        let y = (viewModel.region.center.latitude - coordinate.latitude + latDelta/2) / latDelta * Double(mapSize.height)
        
        return CGPoint(x: x, y: y)
    }
    
    // MARK: - Search Bar Overlay
    private var searchBarOverlay: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search for a location", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit {
                    viewModel.searchLocation(query: searchText)
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    viewModel.clearSearchResults()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color(.systemBackground)
                .opacity(0.95)
        )
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Radius Selector Overlay
    private var radiusSelectorOverlay: some View {
        VStack(spacing: 8) {
            Text("Radius")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 6) {
                ForEach(radiusOptions, id: \.self) { radius in
                    Button(action: {
                        selectedRadius = radius
                        updateLocationWithRadius()
                    }) {
                        VStack(spacing: 2) {
                            Text("\(Int(radius))")
                                .font(.caption)
                                .fontWeight(selectedRadius == radius ? .bold : .regular)
                            
                            Text("m")
                                .font(.caption2)
                        }
                        .foregroundColor(selectedRadius == radius ? .white : .blue)
                        .frame(width: 44, height: 32)
                        .background(
                            selectedRadius == radius
                                ? Color.blue
                                : Color.blue.opacity(0.1)
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            Color(.systemBackground)
                .opacity(0.95)
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.trailing, 16)
    }
    
    // MARK: - Selected Location Info Overlay
    private var selectedLocationInfoOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Selected Location")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let locationName = viewModel.selectedLocationName {
                Text(locationName)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Text("Radius: \(Int(selectedRadius)) meters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            Color(.systemBackground)
                .opacity(0.95)
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Search Results Overlay
    @ViewBuilder
    private var searchResultsOverlay: some View {
        if !viewModel.searchResults.isEmpty {
            VStack {
                Spacer()
                    .frame(height: 60)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.searchResults, id: \.self) { result in
                            Button(action: {
                                viewModel.selectSearchResult(result)
                                searchText = result.name ?? "Selected Location"
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.name ?? "Unknown")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if let subtitle = createSubtitle(for: result) {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.clear)
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 200)
                .background(
                    Color(.systemBackground)
                        .opacity(0.98)
                )
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 16)
                
                Spacer()
            }
        }
    }
    
    private func createSubtitle(for mapItem: MKMapItem) -> String? {
        let placemark = mapItem.placemark
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    // MARK: - Next Button Section
    private var nextButtonSection: some View {
        Button(action: {
            handleNextButtonTap()
        }) {
            Text("Next")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canProceed() ? Color.blue : Color.gray)
                .cornerRadius(12)
        }
        .disabled(!canProceed())
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    // MARK: - Back Button
    private var backButton: some View {
        Button(action: {
            coordinator.previousStep()
        }) {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back")
            }
        }
    }
    
    // MARK: - Helper Methods
    private func canProceed() -> Bool {
        return viewModel.hasLocationPermission() && viewModel.selectedCoordinate != nil && coordinator.canProceed()
    }
    
    private func handleNextButtonTap() {
        // Show alert explaining always permission, then request it
        if viewModel.hasLocationPermission() && !viewModel.hasAlwaysPermission() {
            showingAlwaysPermissionAlert = true
        } else {
            coordinator.nextStep()
        }
    }
    
    private func radiusToMapSize(_ radius: Double, in mapSize: CGSize) -> CGFloat {
        let metersPerPoint = viewModel.region.span.latitudeDelta * 111000 / Double(mapSize.height)
        return CGFloat(radius / metersPerPoint)
    }
    
    private func updateLocationWithRadius() {
        guard let coordinate = viewModel.selectedCoordinate else { return }
        
        let location = Location(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            geofenceRadius: selectedRadius,
            name: viewModel.selectedLocationName ?? "Selected Location"
        )
        
        coordinator.preferences.location = location
    }
    
    private func setupView() {
        viewModel.setupInitialLocation()
        if let existingLocation = coordinator.preferences.location {
            selectedRadius = existingLocation.geofenceRadius
            let coordinate = CLLocationCoordinate2D(
                latitude: existingLocation.latitude,
                longitude: existingLocation.longitude
            )
            viewModel.selectedCoordinate = coordinate
            viewModel.selectedLocationName = existingLocation.name
            viewModel.updateRegion(center: coordinate)
        }
    }
}

// MARK: - Extensions for CLLocationCoordinate2D Equatable conformance
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
