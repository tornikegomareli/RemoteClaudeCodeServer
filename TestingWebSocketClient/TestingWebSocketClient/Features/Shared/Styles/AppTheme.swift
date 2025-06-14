//
//  AppTheme.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct AppTheme {
    /// Colors
    struct Colors {
        static let primary = Color.blue
        static let secondary = Color.gray
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let tertiaryBackground = Color(.tertiarySystemBackground)
        static let label = Color(.label)
        static let secondaryLabel = Color(.secondaryLabel)
        static let tertiaryLabel = Color(.tertiaryLabel)
        static let separator = Color(.separator)
    }
    
    /// Typography
    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .bold, design: .default)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    }
    
    /// Spacing
    struct Spacing {
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
        static let xxLarge: CGFloat = 48
    }
    
    /// Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20
        static let capsule: CGFloat = 100
    }
    
    /// Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.35)
        static let smooth = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
        static let bouncy = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.6)
    }
    
    /// Shadows
    struct Shadow {
        static let small = ShadowStyle(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        static let medium = ShadowStyle(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        static let large = ShadowStyle(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

/// View modifiers for common styles
extension View {
    func primaryButtonStyle() -> some View {
        self
            .font(AppTheme.Typography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppTheme.Colors.primary)
            .cornerRadius(AppTheme.CornerRadius.capsule)
    }
    
    func secondaryButtonStyle() -> some View {
        self
            .font(AppTheme.Typography.headline)
            .foregroundColor(AppTheme.Colors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(AppTheme.CornerRadius.capsule)
    }
    
    func cardStyle() -> some View {
        self
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(AppTheme.CornerRadius.large)
            .shadow(color: AppTheme.Shadow.small.color, radius: AppTheme.Shadow.small.radius, x: AppTheme.Shadow.small.x, y: AppTheme.Shadow.small.y)
    }
}