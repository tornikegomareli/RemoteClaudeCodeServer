//
//  LoadingIndicator.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct LoadingIndicator: View {
    @State private var isAnimating = false
    let size: CGFloat
    
    init(size: CGFloat = 60) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 3)
                .opacity(0.3)
                .foregroundColor(AppTheme.Colors.primary)
            
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .foregroundColor(AppTheme.Colors.primary)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
        .frame(width: size, height: size)
        .onAppear {
            isAnimating = true
        }
    }
}

struct LoadingOverlay: View {
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: AppTheme.Spacing.medium) {
                LoadingIndicator()
                
                if let message = message {
                    Text(message)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.label)
                }
            }
            .padding(AppTheme.Spacing.xLarge)
            .background(AppTheme.Colors.background)
            .cornerRadius(AppTheme.CornerRadius.large)
            .shadow(
                color: AppTheme.Shadow.large.color,
                radius: AppTheme.Shadow.large.radius,
                x: AppTheme.Shadow.large.x,
                y: AppTheme.Shadow.large.y
            )
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        LoadingIndicator()
        LoadingIndicator(size: 40)
        LoadingOverlay(message: "Connecting...")
    }
}