import SwiftUI
import MapKit
import CoreLocation

struct LocationConfigView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @StateObject private var viewModel = LocationConfigViewModel()
    @State private var searchText = ""
    @State private var selectedRadius: Double = 100
    
    private let radiusOptions: [Double] = [50, 100, 200, 500, 1000]
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            searchBarSection
            mapWithRadiusSection
            selectedLocationInfoSection
            Spacer()
            nextButtonSection
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
        }
        .onAppear {
            setupView()
        }
        .onChange(of: selectedRadius) { _ in
            updateLocationWithRadius()
        }
        .onChange(of: viewModel.selectedCoordinate) { _ in
            updateLocationWithRadius()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Select Location")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose where you need to be after waking up")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Search Bar Section
    private var searchBarSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search for a location", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit {
                    viewModel.searchLocation(query: searchText)
                }
            
            if !searchText.isEmpty {
                clearSearchButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var clearSearchButton: some View {
        Button(action: {
            searchText = ""
            viewModel.clearSearchResults()
        }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Map with Radius Section
    private var mapWithRadiusSection: some View {
        HStack(spacing: 0) {
            mapView
            radiusSelectorSidebar
        }
        .frame(minHeight: 300)
    }
    
    private var mapView: some View {
        GeometryReader { geometry in
            ZStack {
                mapContent(geometry: geometry)
                searchResultsOverlay
            }
        }
    }
    
    private func mapContent(geometry: GeometryProxy) -> some View {
        ZStack {
            Map(coordinateRegion: $viewModel.region)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            viewModel.handleMapTap(at: value.location, in: geometry.size)
                        }
                )
            
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
    
    @ViewBuilder
    private var searchResultsOverlay: some View {
        if !viewModel.searchResults.isEmpty {
            VStack {
                searchResultsList
                Spacer()
            }
        }
    }
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.searchResults, id: \.self) { result in
                    searchResultRow(result)
                }
            }
            .padding()
        }
        .frame(maxHeight: 200)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
        .padding()
    }
    
    private func searchResultRow(_ result: MKMapItem) -> some View {
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
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
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
    
    // MARK: - Radius Selector Sidebar
    private var radiusSelectorSidebar: some View {
        VStack(spacing: 12) {
            Text("Radius")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
            ForEach(radiusOptions, id: \.self) { radius in
                radiusButton(for: radius)
            }
            
            Spacer()
        }
        .padding(.vertical)
        .padding(.trailing)
        .frame(width: 70)
    }
    
    private func radiusButton(for radius: Double) -> some View {
        Button(action: {
            selectedRadius = radius
            updateLocationWithRadius()
        }) {
            VStack(spacing: 4) {
                Text("\(Int(radius))")
                    .font(.caption)
                    .fontWeight(selectedRadius == radius ? .bold : .regular)
                
                Text("m")
                    .font(.caption2)
            }
            .foregroundColor(selectedRadius == radius ? .white : .blue)
            .frame(width: 50, height: 40)
            .background(
                selectedRadius == radius
                    ? Color.blue
                    : Color.blue.opacity(0.1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Selected Location Info Section
    @ViewBuilder
    private var selectedLocationInfoSection: some View {
        if let coordinate = viewModel.selectedCoordinate {
            VStack(alignment: .leading, spacing: 8) {
                Text("Selected Location")
                    .font(.headline)
                
                if let locationName = viewModel.selectedLocationName {
                    Text(locationName)
                        .font(.body)
                }
                
                Text("Radius: \(Int(selectedRadius)) meters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Next Button Section
    private var nextButtonSection: some View {
        Button(action: {
            coordinator.nextStep()
        }) {
            Text("Next")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(coordinator.canProceed() ? Color.blue : Color.gray)
                .cornerRadius(12)
        }
        .disabled(!coordinator.canProceed())
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
    private func radiusToMapSize(_ radius: Double, in mapSize: CGSize) -> CGFloat {
        // Approximate conversion from meters to map display size
        // This is a rough calculation and may need adjustment
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

// MARK: - LocationConfigViewModel
@MainActor
class LocationConfigViewModel: ObservableObject {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @Published var selectedCoordinate: CLLocationCoordinate2D?
    @Published var selectedLocationName: String?
    @Published var searchResults: [MKMapItem] = []
    
    private let locationManager = CLLocationManager()
    
    func setupInitialLocation() {
        locationManager.requestWhenInUseAuthorization()
        
        if let currentLocation = locationManager.location {
            updateRegion(center: currentLocation.coordinate)
        }
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

// MARK: - Extensions for MKMapItem Hashable conformance
extension MKMapItem: Hashable {
    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(placemark.coordinate.latitude)
        hasher.combine(placemark.coordinate.longitude)
        hasher.combine(name)
        return hasher.finalize()
    }
    
    public static func == (lhs: MKMapItem, rhs: MKMapItem) -> Bool {
        return lhs.placemark.coordinate.latitude == rhs.placemark.coordinate.latitude &&
               lhs.placemark.coordinate.longitude == rhs.placemark.coordinate.longitude &&
               lhs.name == rhs.name
    }
}

// MARK: - Extensions for CLLocationCoordinate2D Equatable conformance
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
