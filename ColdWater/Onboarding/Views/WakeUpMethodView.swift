import SwiftUI

struct WakeUpMethodView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("How do you want to check whether you've woken up?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                ForEach(WakeUpMethod.allCases, id: \.self) { method in
                    Button(action: {
                        coordinator.preferences.wakeUpMethod = method
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(method.rawValue.capitalized)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(method == .steps ? "Count steps after waking up" : "Move to a different location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if coordinator.preferences.wakeUpMethod == method {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(
                            coordinator.preferences.wakeUpMethod == method 
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
    }
}
