import SwiftUI

// MARK: - Settings View (Placeholder)
struct SettingsView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Settings options would go here
                VStack(spacing: 16) {
                    Button("Reset Streak") {
                        viewModel.resetStreak()
                    }
                    .foregroundColor(.red)
                    
                    Button("Test: Add Day") {
                        viewModel.recordSuccessfulWakeUp()
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
