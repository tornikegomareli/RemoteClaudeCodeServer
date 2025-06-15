//
//  StatusBadge.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct StatusBadge: View {
    let status: Status
    @State private var isAnimating = false
    
    enum Status {
        case connected
        case connecting
        case error
        case idle
        
        var color: Color {
            switch self {
            case .connected: return AppTheme.Colors.success
            case .connecting: return AppTheme.Colors.warning
            case .error: return AppTheme.Colors.error
            case .idle: return AppTheme.Colors.secondary
            }
        }
        
        var icon: String {
            switch self {
            case .connected: return "checkmark.circle.fill"
            case .connecting: return "arrow.triangle.2.circlepath"
            case .error: return "exclamationmark.triangle.fill"
            case .idle: return "moon.fill"
            }
        }
        
        var text: String {
            switch self {
            case .connected: return "Connected"
            case .connecting: return "Connecting"
            case .error: return "Error"
            case .idle: return "Idle"
            }
        }
        
        var shouldAnimate: Bool {
            self == .connecting
        }
    }
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.xxSmall) {
            Image(systemName: status.icon)
                .font(.system(size: 14))
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(
                    status.shouldAnimate ?
                    Animation.linear(duration: 1).repeatForever(autoreverses: false) :
                    .default,
                    value: isAnimating
                )
            
            Text(status.text)
                .font(AppTheme.Typography.caption)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, AppTheme.Spacing.small)
        .padding(.vertical, AppTheme.Spacing.xxSmall)
        .background(status.color.opacity(0.1))
        .cornerRadius(AppTheme.CornerRadius.capsule)
        .onAppear {
            isAnimating = status.shouldAnimate
        }
        .onChange(of: status.shouldAnimate) { _, newValue in
            isAnimating = newValue
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StatusBadge(status: .connected)
        StatusBadge(status: .connecting)
        StatusBadge(status: .error)
        StatusBadge(status: .idle)
    }
    .padding()
}