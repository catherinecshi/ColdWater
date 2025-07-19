import SwiftUI
import CoreLocation

// MARK: - ContentView with Container/Presentation Pattern
struct ContentView: View {
    @StateObject private var viewModel: ContentViewViewModel
    
    init(locationManager: LocationManager = LocationManager()) {
        _viewModel = StateObject(wrappedValue: ContentViewViewModel(locationManager: locationManager))
    }
    
    var body: some View {
        ContentViewPresentation(viewModel: viewModel)
    }
}

// MARK: - Presentation View (UI Only)
struct ContentViewPresentation: View {
    @ObservedObject var viewModel: ContentViewViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    locationSection
                    geofenceConfigSection
                    timeWindowSection
                    monitoringStatusSection
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("ColdWater Geofence")
        }
        .sheet(isPresented: $viewModel.showingLocationPicker) {
            LocationPickerView(
                locationManager: viewModel.exposedLocationManager,
                onLocationSelected: { coordinate in
                    viewModel.handleLocationSelected(coordinate)
                },
                onCancel: {
                    viewModel.showingLocationPicker = false
                }
            )
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "location.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Geofence Monitor")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Monitor if you're outside a specific area during a time window")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Location Setup", systemImage: "location")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Latitude")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter latitude", text: $viewModel.latitude)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
                
                VStack(alignment: .leading) {
                    Text("Longitude")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter longitude", text: $viewModel.longitude)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
            }
            
            Button("Use Current Location") {
                viewModel.useCurrentLocation()
            }
            .buttonStyle(.bordered)
            
            Button("Pick on Map") {
                viewModel.showingLocationPicker = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var geofenceConfigSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Geofence Settings", systemImage: "circle.dotted")
                .font(.headline)
            
            VStack(alignment: .leading) {
                Text("Radius (meters)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Radius in meters", text: $viewModel.radius)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var timeWindowSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Time Window", systemImage: "clock")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Start Hour")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Start Hour", selection: $viewModel.startHour) {
                        ForEach(0..<24) { hour in
                            Text("\(hour):00")
                                .tag(hour)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 100)
                }
                
                VStack(alignment: .leading) {
                    Text("End Hour")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("End Hour", selection: $viewModel.endHour) {
                        ForEach(0..<24) { hour in
                            Text("\(hour):00")
                                .tag(hour)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 100)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var monitoringStatusSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Status", systemImage: "info.circle")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Location Permission:")
                    Spacer()
                    Text(viewModel.authorizationStatusText)
                        .foregroundColor(viewModel.authorizationStatusColor)
                }
                
                HStack {
                    Text("Monitoring:")
                    Spacer()
                    Text(viewModel.isMonitoring ? "Active" : "Inactive")
                        .foregroundColor(viewModel.isMonitoring ? .green : .red)
                }
                
                HStack {
                    Text("Geofence Status:")
                    Spacer()
                    Text(viewModel.geofenceStatusText)
                        .foregroundColor(viewModel.geofenceStatusColor)
                }
                
                if let location = viewModel.currentLocation {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Location:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Lat: \(location.coordinate.latitude, specifier: "%.6f")")
                            .font(.caption)
                            .monospaced()
                        Text("Lng: \(location.coordinate.longitude, specifier: "%.6f")")
                            .font(.caption)
                            .monospaced()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button("Request Location Permission") {
                viewModel.requestLocationPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Button("Start Geofence Monitoring") {
                viewModel.startGeofenceMonitoring()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canStartMonitoring)
            
            if viewModel.isMonitoring {
                Button("Stop Monitoring") {
                    viewModel.stopMonitoring()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }
}

#Preview {
    ContentView()
}
