import SwiftUI

struct GracePeriodView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @State private var selectedMinutes = 5
    
    private let timeOptions = [0, 5, 10, 15, 30, 60]
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Grace Period")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("How much time do you want after waking up before checking your steps or location?")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                ForEach(timeOptions, id: \.self) { minutes in
                    Button(action: {
                        selectedMinutes = minutes
                        coordinator.preferences.gracePeriod = TimeInterval(minutes * 60)
                    }) {
                        HStack {
                            Text(minutes == 0 ? "No grace period" : "\(minutes) minutes")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedMinutes == minutes {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(
                            selectedMinutes == minutes 
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
            coordinator.preferences.gracePeriod = TimeInterval(selectedMinutes * 60)
        }
    }
}