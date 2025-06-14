//
//  OnboardingView.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct OnboardingView: View {
    @State private var showConnectionSheet = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: AppTheme.Spacing.xxLarge) {
                Spacer()
                
                // Icon
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(AppTheme.Colors.primary)
                    .symbolEffect(.pulse, value: pulseAnimation)
                
                // Title
                VStack(spacing: AppTheme.Spacing.small) {
                    Text("Welcome to ClaudeConnect")
                        .font(AppTheme.Typography.title)
                        .multilineTextAlignment(.center)
                    
                    Text("Connect to your development machine to start using Claude")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.large)
                }
                
                Spacer()
                
                // Connect button
                PrimaryButton("Connect to your machine") {
                    showConnectionSheet = true
                }
                .padding(.horizontal, AppTheme.Spacing.large)
                .scaleEffect(pulseAnimation ? 1.02 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                    value: pulseAnimation
                )
                
                Spacer()
                    .frame(height: AppTheme.Spacing.xxLarge)
            }
        }
        .sheet(isPresented: $showConnectionSheet) {
            ConnectionSheet()
        }
        .onAppear {
            pulseAnimation = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showConnectionSheet)) { _ in
            showConnectionSheet = true
        }
    }
}

#Preview {
    OnboardingView()
}