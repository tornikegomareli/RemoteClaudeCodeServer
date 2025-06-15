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
                        // App became active - WebSocketManager will handle reconnection in appWillEnterForeground
                        appState.webSocketManager.addLog(.info, "Scene became active", category: .general)
                    case .inactive:
                        appState.webSocketManager.addLog(.info, "Scene became inactive", category: .general)
                    case .background:
                        appState.webSocketManager.addLog(.info, "Scene entered background", category: .general)
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
                switch appState.connectionStatus {
                case .authenticated:
                    MainView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                
                case .connecting, .authenticating, .reconnecting:
                    ReconnectingView()
                        .transition(.opacity)
                
                case .disconnected, .failed:
                    OnboardingView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
        }
        .animation(AppTheme.Animation.smooth, value: appState.connectionStatus)
        .onReceive(NotificationCenter.default.publisher(for: .connectionStateChanged)) { _ in
            // Handle connection state changes
        }
    }
}

/// View shown during reconnection attempts
struct ReconnectingView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
            
            VStack(spacing: 8) {
                Text("Reconnecting...")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(statusMessage)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Option to cancel and go to connection setup
            Button(action: {
                appState.webSocketManager.disconnect()
            }) {
                Text("Cancel")
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
    }
    
    private var statusMessage: String {
        switch appState.connectionStatus {
        case .connecting:
            return "Establishing connection to server..."
        case .authenticating:
            return "Authenticating with server..."
        case .reconnecting:
            return "Restoring your previous session..."
        default:
            return "Please wait..."
        }
    }
}

/// App-wide state management
class AppState: ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus: WebSocketManager.ConnectionStatus = .disconnected
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
                self?.connectionStatus = status
                
                switch status {
                case .authenticated:
                    self?.isConnected = true
                case .disconnected, .failed:
                    self?.isConnected = false
                    self?.selectedRepository = nil
                case .connecting, .authenticating, .reconnecting:
                    // Keep isConnected as is during transition states
                    break
                }
            }
            .store(in: &cancellables)
        
        // Observe isConnected changes from WebSocketManager
        webSocketManager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isConnected = connected
            }
            .store(in: &cancellables)
        
        // Listen for authentication success
        NotificationCenter.default.publisher(for: .webSocketAuthenticated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                NotificationCenter.default.post(name: .connectionStateChanged, object: nil)
            }
            .store(in: &cancellables)
        
        // Listen for server restart detection
        NotificationCenter.default.publisher(for: .serverRestartDetected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.selectedRepository = nil
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
            // Attempt to connect after splash screen
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
