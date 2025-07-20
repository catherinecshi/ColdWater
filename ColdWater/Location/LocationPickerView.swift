import SwiftUI
import MapKit
import CoreLocation

// MARK: - LocationPickerView with Container/Presentation Pattern
struct LocationPickerView: View {
    @StateObject private var viewModel: LocationPickerViewModel
    let onLocationSelected: (CLLocationCoordinate2D) -> Void
    let onCancel: () -> Void
    
    init(
        locationManager: LocationManager,
        onLocationSelected: @escaping (CLLocationCoordinate2D) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: LocationPickerViewModel(locationManager: locationManager))
        self.onLocationSelected = onLocationSelected
        self.onCancel = onCancel
    }
    
    var body: some View {
        LocationPickerPresentation(
            viewModel: viewModel,
            onLocationSelected: onLocationSelected,
            onCancel: onCancel
        )
    }
}

// MARK: - Presentation View (UI Only)
struct LocationPickerPresentation: View {
    @ObservedObject var viewModel: LocationPickerViewModel
    let onLocationSelected: (CLLocationCoordinate2D) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                GeometryReader { geometry in
                    Map(coordinateRegion: $viewModel.region, annotationItems: viewModel.annotations) { annotation in
                        MapPin(coordinate: annotation.coordinate, tint: .red)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                viewModel.handleMapTap(at: value.location, in: geometry.size)
                            }
                    )
                }
                .frame(minHeight: 300)
                
                if let coordinate = viewModel.selectedCoordinate {
                    selectedLocationInfo(coordinate: coordinate)
                }
                
                Spacer()
            }
            .navigationTitle("Pick Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select") {
                        viewModel.selectCurrentLocation(completion: onLocationSelected)
                    }
                    .disabled(!viewModel.hasSelectedLocation)
                }
            }
        }
        .onAppear {
            viewModel.setupInitialLocation()
        }
    }
    
    private func selectedLocationInfo(coordinate: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Location:")
                .font(.headline)
            Text("Latitude: \(coordinate.latitude, specifier: "%.6f")")
                .font(.caption)
                .monospaced()
            Text("Longitude: \(coordinate.longitude, specifier: "%.6f")")
                .font(.caption)
                .monospaced()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}
