import SwiftUI

// MARK: - Modern Color System for AI CardNews App
struct AppColors {
    
    // MARK: - Primary AI-inspired Gradient Colors
    static let primaryStart = Color(hex: "#6366f1")  // Indigo - AI/Tech feeling
    static let primaryEnd = Color(hex: "#8b5cf6")    // Purple - Creative feeling
    
    // MARK: - Accent Colors for Premium Feel
    static let accent = Color(hex: "#f59e0b")        // Amber - Premium highlight
    static let success = Color(hex: "#10b981")       // Emerald - Success states
    static let warning = Color(hex: "#f97316")       // Orange - Warning/Alert
    static let error = Color(hex: "#ef4444")         // Red - Error states
    
    // MARK: - Glassmorphism Support
    static let glassBackground = Color.white.opacity(0.1)
    static let glassBorder = Color.white.opacity(0.2)
    static let glassBackgroundDark = Color.black.opacity(0.1)
    static let glassBorderDark = Color.white.opacity(0.1)
    
    // MARK: - Background Gradients
    static let backgroundLight = Color(hex: "#f8fafc")   // Very light gray
    static let backgroundDark = Color(hex: "#0f0f23")    // Deep dark blue
    
    // MARK: - Text Colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textOnPrimary = Color.white
    
    // MARK: - Card Colors
    static let cardBackground = Color(.systemBackground)
    static let cardBorder = Color(.systemGray5)
}

// MARK: - Gradient Definitions
struct AppGradients {
    
    // MARK: - Primary Gradients
    static let primary = LinearGradient(
        colors: [AppColors.primaryStart, AppColors.primaryEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let primaryHorizontal = LinearGradient(
        colors: [AppColors.primaryStart, AppColors.primaryEnd],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Background Gradients
    static let backgroundLight = LinearGradient(
        colors: [
            AppColors.backgroundLight,
            Color.white,
            AppColors.primaryStart.opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let backgroundDark = LinearGradient(
        colors: [
            AppColors.backgroundDark,
            Color.black,
            AppColors.primaryEnd.opacity(0.1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Card Gradients (Glassmorphism)
    static let glassCard = LinearGradient(
        colors: [
            AppColors.glassBackground,
            AppColors.glassBackground.opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let glassCardDark = LinearGradient(
        colors: [
            AppColors.glassBackgroundDark,
            AppColors.glassBackgroundDark.opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Button Gradients
    static let button = LinearGradient(
        colors: [AppColors.primaryStart, AppColors.primaryEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let buttonAccent = LinearGradient(
        colors: [AppColors.accent, AppColors.warning],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let buttonSuccess = LinearGradient(
        colors: [AppColors.success, AppColors.success.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Disabled State
    static let disabled = LinearGradient(
        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Glassmorphism Effect Modifier
struct GlassmorphismEffect: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        colorScheme == .dark ? 
                        AppGradients.glassCardDark : 
                        AppGradients.glassCard
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        colorScheme == .dark ? 
                        AppColors.glassBorderDark : 
                        AppColors.glassBorder, 
                        lineWidth: 1
                    )
            )
            .shadow(
                color: AppColors.primaryStart.opacity(0.1),
                radius: 10,
                x: 0,
                y: 5
            )
    }
}

// MARK: - Premium Button Style
struct PremiumButtonStyle: ButtonStyle {
    let gradient: LinearGradient
    let isDisabled: Bool
    
    init(gradient: LinearGradient = AppGradients.primary, isDisabled: Bool = false) {
        self.gradient = gradient
        self.isDisabled = isDisabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDisabled ? AppGradients.disabled : gradient)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(
                color: isDisabled ? Color.clear : AppColors.primaryStart.opacity(0.3),
                radius: configuration.isPressed ? 2 : 8,
                x: 0,
                y: configuration.isPressed ? 1 : 4
            )
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - View Extensions for Easy Use
extension View {
    func glassmorphism() -> some View {
        modifier(GlassmorphismEffect())
    }
    
    func premiumButton(
        gradient: LinearGradient = AppGradients.primary,
        isDisabled: Bool = false
    ) -> some View {
        buttonStyle(PremiumButtonStyle(gradient: gradient, isDisabled: isDisabled))
    }
}
