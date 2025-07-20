import SwiftUI
import UIKit

/// Centralized UI configuration for consistent styling across the app
struct UIConfiguration {
    
    // MARK: - Colors
    
    /// Primary tint color matching the home screen blue theme
    static let tintColor = UIColor.systemBlue
    
    /// SwiftUI version of tint color
    static let primaryColor = Color.blue
    
    /// Background colors
    static let backgroundColor = UIColor.systemBackground
    static let secondaryBackgroundColor = UIColor.secondarySystemBackground
    
    /// Text colors
    static let primaryTextColor = UIColor.label
    static let secondaryTextColor = UIColor.secondaryLabel
    
    /// Button colors
    static let buttonBackgroundColor = UIColor.systemBlue
    static let buttonTextColor = UIColor.white
    static let secondaryButtonBorderColor = UIColor.systemGray3
    
    // MARK: - Fonts (UIKit)
    
    /// Large title font for app name - matches the bold rounded style from HomeView
    static let titleFont = UIFont.systemFont(ofSize: 32, weight: .bold)
    
    /// Subtitle font for descriptive text
    static let subtitleFont = UIFont.systemFont(ofSize: 18, weight: .medium)
    
    /// Button font for authentication buttons
    static let buttonFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
    
    /// Caption font for small text
    static let captionFont = UIFont.systemFont(ofSize: 15, weight: .regular)
    
    // MARK: - SwiftUI Fonts
    
    /// SwiftUI version of title font
    static let swiftUITitleFont = Font.system(size: 32, weight: .bold, design: .rounded)
    
    /// SwiftUI version of subtitle font
    static let swiftUISubtitleFont = Font.system(size: 18, weight: .medium, design: .default)
    
    /// SwiftUI version of button font
    static let swiftUIButtonFont = Font.system(size: 17, weight: .semibold, design: .default)
    
    /// SwiftUI version of caption font
    static let swiftUICaptionFont = Font.system(size: 15, weight: .regular, design: .default)
    
    // MARK: - Spacing & Layout
    
    static let cornerRadius: CGFloat = 8
    static let buttonHeight: CGFloat = 50
    static let standardPadding: CGFloat = 20
    static let smallPadding: CGFloat = 12
    
    // MARK: - Gradients (matching HomeView style)
    
    /// Background gradient similar to HomeView
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Subtle card background
    static let cardBackground = Color(.secondarySystemBackground)
}

// MARK: - Extensions for easy conversion

extension UIFont {
    /// Convert UIFont to SwiftUI Font
    var swiftUIFont: Font {
        return Font(self)
    }
}

extension UIColor {
    /// Convert UIColor to SwiftUI Color
    var swiftUIColor: Color {
        return Color(self)
    }
}

extension Color {
    /// Convert SwiftUI Color to UIColor
    var uiColor: UIColor {
        return UIColor(self)
    }
}

// MARK: - Button Styles

/// Custom button style for authentication buttons
struct AuthButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    let borderColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(UIConfiguration.swiftUIButtonFont)
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: UIConfiguration.buttonHeight)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: UIConfiguration.cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .cornerRadius(UIConfiguration.cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Predefined Button Styles

extension AuthButtonStyle {
    /// Primary button style (blue background, white text)
    static let primary = AuthButtonStyle(
        backgroundColor: UIConfiguration.primaryColor,
        foregroundColor: .white,
        borderColor: .clear
    )
    
    /// Secondary button style (clear background, dark text, gray border)
    static let secondary = AuthButtonStyle(
        backgroundColor: .clear,
        foregroundColor: .primary,
        borderColor: Color(.systemGray3)
    )
    
    /// Guest button style (clear background, gray text, gray border)
    static let guest = AuthButtonStyle(
        backgroundColor: .clear,
        foregroundColor: .secondary,
        borderColor: Color(.systemGray3)
    )
    
    /// Google button style (white background, dark text, gray border)
    static let google = AuthButtonStyle(
        backgroundColor: .white,
        foregroundColor: .primary,
        borderColor: Color(.systemGray3)
    )
}
