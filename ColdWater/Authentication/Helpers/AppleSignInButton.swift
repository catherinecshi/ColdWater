import SwiftUI
import AuthenticationServices

/// Custom Apple Sign-In button that integrates with our view model and matches app styling
struct CustomAppleSignInButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text("Sign In with Apple")
                    .font(UIConfiguration.swiftUIButtonFont)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: UIConfiguration.buttonHeight)
            .background(Color.black)
            .cornerRadius(UIConfiguration.cornerRadius)
        }
        .buttonStyle(PlainButtonStyle()) // Prevents default button styling
    }
}

/// Alternative implementation using UIViewRepresentable if you prefer the native Apple button
struct AppleSignInButtonRepresentable: UIViewRepresentable {
    let action: () -> Void
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    class Coordinator: NSObject {
        let action: () -> Void
        
        init(action: @escaping () -> Void) {
            self.action = action
        }
        
        @objc func buttonTapped() {
            action()
        }
    }
}
