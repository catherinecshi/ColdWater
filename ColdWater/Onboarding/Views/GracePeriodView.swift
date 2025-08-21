import SwiftUI

struct GracePeriodView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @State private var selectedMinutes = 5
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Text(getDescriptionText())
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                // Minutes picker
                VStack(spacing: 12) {
                    Picker("Minutes", selection: $selectedMinutes) {
                        ForEach(0...120, id: \.self) { minute in
                            Text(minute == 0 ? "No delay" : "\(minute) min")
                                .tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .onChange(of: selectedMinutes) { minutes in
                        coordinator.preferences.gracePeriod = TimeInterval(minutes * 60)
                    }
                }
                
                // Optional description for context
                Text(getContextText())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
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
            // Load existing preference or set default
            if let existingGracePeriod = coordinator.preferences.gracePeriod {
                selectedMinutes = Int(existingGracePeriod / 60)
            } else {
                coordinator.preferences.gracePeriod = TimeInterval(selectedMinutes * 60)
            }
        }
    }
    
    private func getDescriptionText() -> String {
        switch coordinator.preferences.wakeUpMethod {
        case .steps:
            return "How long do you need to get ready before checking your step count?"
        case .location:
            return "How long do you need to get ready before checking your location?"
        case .none:
            return "How long do you need to get ready for the morning?"
        }
    }
    
    private func getContextText() -> String {
        let method = coordinator.preferences.wakeUpMethod
        let checkType = method == .steps ? "Step count" : "Location"
        
        if selectedMinutes == 0 {
            return "\(checkType) checked immediately"
        } else {
            return "Gives you \(selectedMinutes) minutes to get ready"
        }
    }
}
