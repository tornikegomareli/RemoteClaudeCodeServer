//
//  ClaudeConnectApp.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI
import Combine

@main
struct ClaudeConnectApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            AppContentView()
                .environmentObject(appState)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        // App became active
                        if !appState.isConnected && 
                           !appState.webSocketManager.reconnectionToken.isEmpty {
                            appState.webSocketManager.addLog(.info, "App became active, checking connection", category: .general)
                            appState.webSocketManager.connect()
                        }
                    case .inactive:
                        appState.webSocketManager.addLog(.info, "App became inactive", category: .general)
                    case .background:
                        appState.webSocketManager.addLog(.info, "App entered background", category: .general)
                    @unknown default:
                        break
                    }
                }
        }
    }
}

/// Main content view that manages app flow
struct AppContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    withAnimation(AppTheme.Animation.standard) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
            } else {
                if appState.isConnected {
                    MainView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    OnboardingView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
        }
        .animation(AppTheme.Animation.smooth, value: appState.isConnected)
        .onReceive(NotificationCenter.default.publisher(for: .connectionStateChanged)) { _ in
            // Handle connection state changes
        }
    }
}

/// App-wide state management
class AppState: ObservableObject {
    @Published var isConnected = false
    @Published var selectedRepository: Repository?
    @Published var webSocketManager = WebSocketManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupWebSocketObservers()
        checkStoredConnection()
    }
    
    private func setupWebSocketObservers() {
        // Observe WebSocket connection status
        webSocketManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .authenticated:
                    self?.isConnected = true
                case .disconnected, .failed:
                    self?.isConnected = false
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Listen for authentication success
        NotificationCenter.default.publisher(for: .webSocketAuthenticated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isConnected = true
                NotificationCenter.default.post(name: .connectionStateChanged, object: nil)
            }
            .store(in: &cancellables)
        
        // Listen for server restart detection
        NotificationCenter.default.publisher(for: .serverRestartDetected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isConnected = false
                NotificationCenter.default.post(name: .connectionStateChanged, object: nil)
                NotificationCenter.default.post(name: .showConnectionSheet, object: nil)
            }
            .store(in: &cancellables)
    }
    
    private func checkStoredConnection() {
        // Check if we have stored credentials and attempt auto-connect
        if !webSocketManager.serverURL.isEmpty && 
           (!webSocketManager.reconnectionToken.isEmpty || !webSocketManager.authUUID.isEmpty) {
            webSocketManager.addLog(.info, "Attempting auto-reconnect with stored credentials", category: .connection)
            // Attempt to connect after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.webSocketManager.connect()
            }
        } else {
            webSocketManager.addLog(.info, "No stored credentials found for auto-reconnect", category: .connection)
        }
    }
    
    func connect(serverURL: String, authUUID: String) {
        webSocketManager.serverURL = serverURL
        webSocketManager.authUUID = authUUID
        webSocketManager.saveSettings()
        webSocketManager.connect()
    }
    
    func disconnect() {
        webSocketManager.disconnect()
        selectedRepository = nil
        
        // Post notification
        NotificationCenter.default.post(name: .connectionStateChanged, object: nil)
    }
}


/// Notification names
extension Notification.Name {
    static let connectionStateChanged = Notification.Name("connectionStateChanged")
    static let showConnectionSheet = Notification.Name("showConnectionSheet")
}

#Preview {
    AppContentView()
        .environmentObject(AppState())
}
