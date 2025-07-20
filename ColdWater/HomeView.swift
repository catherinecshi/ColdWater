import SwiftUI

// MARK: - View
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    // Main content
                    VStack(spacing: 8) {
                        // Large number
                        Text(viewModel.daysString)
                            .font(.system(size: 120, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .animation(.spring(), value: viewModel.wakeUpData.consecutiveDays)
                        
                        // "days" text
                        Text("days")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        // "waking up on time" text
                        Text("waking up on time")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    // Optional: Add streak status indicator
                    if viewModel.wakeUpData.consecutiveDays > 0 {
                        HStack {
                            Image(systemName: viewModel.isStreakActive ? "flame.fill" : "flame")
                                .foregroundColor(viewModel.isStreakActive ? .orange : .gray)
                            Text(viewModel.isStreakActive ? "Streak active!" : "Keep it going!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView {
                // reset app's authentication state
                showingSettings = false
            }
        }
    }
}

// MARK: - Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
