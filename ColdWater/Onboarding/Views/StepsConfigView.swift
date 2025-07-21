import SwiftUI
import HealthKit

struct StepsConfigView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var selectedSteps = 100
    @State private var showingHealthKitAlert = false
    
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
                        await healthKitManager.requestHealthKitAuthorization()
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
                    .background(coordinator.canProceed() ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!coordinator.canProceed())
            .padding(.horizontal)
        }
        .padding()
        .navigationBarBackButtonHidden(true)
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
            if healthKitManager.isAuthorized {
                Task {
                    await healthKitManager.fetchStepCount()
                }
            }
        }
    }
}
