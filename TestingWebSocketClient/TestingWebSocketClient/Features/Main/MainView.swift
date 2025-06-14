//
//  MainView.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var showRepositorySelector = false
    @State private var showNewTaskView = false
    @State private var showLogsView = false
    
    private var statusColor: Color {
        switch appState.webSocketManager.connectionStatus {
        case .authenticated: return AppTheme.Colors.success
        case .connecting, .authenticating, .reconnecting: return AppTheme.Colors.warning
        case .disconnected, .failed: return AppTheme.Colors.error
        }
    }
    
    private var statusText: String {
        switch appState.webSocketManager.connectionStatus {
        case .authenticated: return "Connected"
        case .connecting: return "Connecting..."
        case .authenticating: return "Authenticating..."
        case .reconnecting: return "Reconnecting..."
        case .disconnected: return "Disconnected"
        case .failed: return "Failed"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                // Main content
                VStack(spacing: AppTheme.Spacing.large) {
                    // Repository info card
                    repositoryCard
                    
                    // Action buttons
                    actionButtons
                    
                    Spacer()
                }
                .padding(AppTheme.Spacing.medium)
                
                // Floating new task button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        newTaskButton
                            .padding(.trailing, AppTheme.Spacing.medium)
                            .padding(.bottom, AppTheme.Spacing.large)
                    }
                }
            }
            .navigationTitle("ClaudeConnect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    connectionStatusView
                }
            }
            .sheet(isPresented: $showRepositorySelector) {
                RepositorySelector(selectedRepository: $appState.selectedRepository)
            }
            .sheet(isPresented: $showNewTaskView) {
                TaskCreationView(repository: appState.selectedRepository) { task in
                    // Send command through WebSocket
                    appState.webSocketManager.sendCommand(task)
                }
            }
            .sheet(isPresented: $showLogsView) {
                LogsView()
            }
        }
    }
    
    private var repositoryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("Repository")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.label)
                
                Spacer()
                
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    showRepositorySelector = true
                }) {
                    Text("Change")
                        .font(AppTheme.Typography.callout)
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            if let repo = appState.selectedRepository {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                    Text(repo.name)
                        .font(AppTheme.Typography.title3)
                        .foregroundColor(AppTheme.Colors.label)
                    
                    Text(repo.path)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.secondaryLabel)
                        .lineLimit(1)
                }
            } else {
                Text("No repository selected")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.secondaryLabel)
            }
        }
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
    }
    
    private var actionButtons: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            // Logs button
            ActionButton(
                title: "System Logs",
                subtitle: "\(appState.webSocketManager.logs.count) entries",
                icon: "doc.text.magnifyingglass",
                color: AppTheme.Colors.secondaryLabel
            ) {
                showLogsView = true
            }
        }
    }
    
    private var connectionStatusView: some View {
        Menu {
            if appState.isConnected {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    appState.disconnect()
                }) {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
                .foregroundColor(.red)
            }
            
            Button(action: {
                showLogsView = true
            }) {
                Label("View Logs", systemImage: "doc.text.magnifyingglass")
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.xSmall) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(statusText)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.secondaryLabel)
            }
            .padding(.horizontal, AppTheme.Spacing.small)
            .padding(.vertical, AppTheme.Spacing.xxSmall)
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(AppTheme.CornerRadius.capsule)
        }
    }
    
    private var newTaskButton: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            showNewTaskView = true
        }) {
            HStack(spacing: AppTheme.Spacing.small) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                Text("New Task")
                    .font(AppTheme.Typography.headline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.vertical, AppTheme.Spacing.medium)
            .background(AppTheme.Colors.primary)
            .cornerRadius(AppTheme.CornerRadius.capsule)
            .shadow(
                color: AppTheme.Shadow.medium.color,
                radius: AppTheme.Shadow.medium.radius,
                x: AppTheme.Shadow.medium.x,
                y: AppTheme.Shadow.medium.y
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Action button component
struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: AppTheme.Spacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                    Text(title)
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.label)
                    
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.secondaryLabel)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.tertiaryLabel)
            }
            .padding(AppTheme.Spacing.medium)
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(AppTheme.CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Scale button style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AppTheme.Animation.quick, value: configuration.isPressed)
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
}