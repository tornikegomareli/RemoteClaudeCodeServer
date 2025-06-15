//
//  SplashView.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var letterOpacities: [Double] = Array(repeating: 0, count: 13) // "ClaudeConnect" has 13 letters
    @State private var scale: CGFloat = 0.95
    let onCompletion: () -> Void
    
    private let appName = "ClaudeConnect"
    
    var body: some View {
        ZStack {
            // Background with subtle gradient
            LinearGradient(
                colors: [
                    Color.white,
                    Color.white.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // App name with letter-by-letter animation
            HStack(spacing: 0) {
                ForEach(Array(appName.enumerated()), id: \.offset) { index, character in
                    Text(String(character))
                        .font(.system(size: 34, weight: .medium, design: .default))
                        .foregroundColor(AppTheme.Colors.label)
                        .opacity(letterOpacities[index])
                        .scaleEffect(scale)
                }
            }
        }
        .onAppear {
            animateSplash()
        }
    }
    
    private func animateSplash() {
        // Scale animation
        withAnimation(AppTheme.Animation.smooth) {
            scale = 1.0
        }
        
        // Letter-by-letter fade in
        for index in 0..<appName.count {
            withAnimation(
                AppTheme.Animation.standard
                    .delay(Double(index) * 0.05)
            ) {
                letterOpacities[index] = 1.0
            }
        }
        
        // Complete after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(AppTheme.Animation.quick) {
                onCompletion()
            }
        }
    }
}

#Preview {
    SplashView(onCompletion: {})
}