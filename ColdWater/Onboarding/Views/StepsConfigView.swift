import SwiftUI
import HealthKit

struct StepsConfigView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var selectedSteps = 100
    @State private var showingHealthKitAlert = false
    @State private var showingPermissionAlert = false
    
    private let stepOptions = [50, 100, 200, 500, 1000, 5000]
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("How many steps?")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Select how many steps you want to take to wake up")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Add current step count display
                if healthKitManager.isAuthorized {
                    Text("Today's steps: \(healthKitManager.stepCount)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Add HealthKit integration button
            if !healthKitManager.isAuthorized {
                Button(action: {
                    Task {
                        print("🔘 Connect button pressed - requesting authorization")
                        await healthKitManager.requestHealthKitAuthorization()
                        
                        print("🔄 Re-checking permission after connect button...")
                        // Check permission after requesting
                        let hasPermission = await healthKitManager.checkStepPermissionIndirectly()
                        print("🔍 Connect button permission result: \(hasPermission)")
                        
                        if !hasPermission {
                            showingPermissionAlert = true
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "heart.circle")
                        Text("Connect to Health App")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Your existing step selection UI
            VStack(spacing: 16) {
                ForEach(stepOptions, id: \.self) { steps in
                    Button(action: {
                        selectedSteps = steps
                        coordinator.preferences.stepGoal = steps
                    }) {
                        HStack {
                            Text("\(steps) steps")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedSteps == steps {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(
                            selectedSteps == steps
                                ? Color.blue.opacity(0.1)
                                : Color(.systemGray6)
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
            
            Button(action: {
                coordinator.nextStep()
            }) {
                Text("Next")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background((coordinator.canProceed() && healthKitManager.isAuthorized) ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!coordinator.canProceed() || !healthKitManager.isAuthorized)
            .padding(.horizontal)
        }
        .padding()
        .navigationBarBackButtonHidden(true)
        .alert("Health Data Access Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To continue, please enable step data access in Settings > Privacy & Security > Health > ColdWater")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    coordinator.previousStep()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .onAppear {
            coordinator.preferences.stepGoal = selectedSteps
            
            Task {
                print("📱 StepsConfigView onAppear - starting permission flow")
                
                // Check permission indirectly first
                let hasPermission = await healthKitManager.checkStepPermissionIndirectly()
                print("🔍 Initial permission check result: \(hasPermission)")
                
                if !hasPermission {
                    print("📝 Requesting HealthKit authorization...")
                    // Request authorization if we don't have permission
                    await healthKitManager.requestHealthKitAuthorization()
                    
                    print("🔄 Re-checking permission after authorization request...")
                    // Check again after requesting
                    let hasPermissionAfterRequest = await healthKitManager.checkStepPermissionIndirectly()
                    print("🔍 Permission check after request: \(hasPermissionAfterRequest)")
                }
                
                // Fetch step count if we have permission
                if healthKitManager.isAuthorized {
                    print("✅ Fetching step count - permission confirmed")
                    await healthKitManager.fetchStepCount()
                } else {
                    print("❌ Not fetching step count - no permission")
                }
            }
        }
    }
}
