import SwiftUI

struct MotivationMethodView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    
    private func descriptionFor(_ method: MotivationMethod) -> String {
        switch method {
        case .phone:
            return "Your phone will be locked until you complete your wake-up task"
        case .money:
            return "You'll lose money if you don't complete your wake-up task"
        case .noise:
            return "A loud alarm will play until you complete your wake-up task"
        case .none:
            return "Just a gentle reminder with no consequences"
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("How do you want to be motivated?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("Choose what happens if you don't complete your wake-up task")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                ForEach(MotivationMethod.allCases, id: \.self) { method in
                    Button(action: {
                        coordinator.preferences.motivationMethod = method
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(method.rawValue.capitalized)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(descriptionFor(method))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            if coordinator.preferences.motivationMethod == method {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(
                            coordinator.preferences.motivationMethod == method 
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