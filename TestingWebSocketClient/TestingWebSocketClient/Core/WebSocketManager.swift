//
//  WebSocketManager.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI
import Foundation
import Combine
import UIKit

/// WebSocket connection manager
class WebSocketManager: ObservableObject {
    @Published var logs: [LogEntry] = []
    @Published var isConnected = false
    @Published var connectionStatus = ConnectionStatus.disconnected
    @Published var serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
    @Published var authUUID = UserDefaults.standard.string(forKey: "authUUID") ?? ""
    @Published var reconnectionToken = UserDefaults.standard.string(forKey: "reconnectionToken") ?? ""
    @Published var clientId = UserDefaults.standard.string(forKey: "clientId") ?? ""
    @Published var repositories: [Repository] = []
    @Published var availableCommands: [SlashCommand] = []
    @Published var customCommands: [SlashCommand] = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var pingTimer: Timer?
    
    init() {
        // Load stored credentials
        loadStoredCredentials()
        setupNotificationObservers()
        
        // Log loaded credentials for debugging
        addLog(.info, "WebSocketManager initialized", category: .general)
        if !serverURL.isEmpty {
            addLog(.info, "Found stored server URL: \(serverURL)", category: .connection)
        }
        if !reconnectionToken.isEmpty {
            addLog(.info, "Found stored reconnection token", category: .authentication)
        }
    }
    
    private func loadStoredCredentials() {
        // Explicitly load from UserDefaults
        serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        authUUID = UserDefaults.standard.string(forKey: "authUUID") ?? ""
        reconnectionToken = UserDefaults.standard.string(forKey: "reconnectionToken") ?? ""
        clientId = UserDefaults.standard.string(forKey: "clientId") ?? ""
    }
    
    func addLog(_ level: LogEntry.LogLevel, _ message: String, category: LogEntry.LogCategory) {
        let logEntry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            category: category
        )
        logs.append(logEntry)
        
        // Keep only last 500 logs to prevent memory issues
        if logs.count > 500 {
            logs.removeFirst()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        pingTimer?.invalidate()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        // For single-client system, we don't need to maintain connection in background
        // We'll reconnect when coming back to foreground
        // This also saves battery and avoids iOS background limitations
    }
    
    @objc private func appWillEnterForeground() {
        endBackgroundTask()
        stopPingTimer()
        
        // Check if we need to reconnect
        if !reconnectionToken.isEmpty && !serverURL.isEmpty {
            // Only reconnect if we're not already connected or connecting
            switch connectionStatus {
            case .disconnected, .failed:
                addLog(.info, "App returning to foreground - attempting reconnection", category: .connection)
                connect()
            case .authenticated:
                // Already connected, just verify the connection
                addLog(.info, "App returning to foreground - verifying connection", category: .connection)
                testConnection()
            case .connecting, .authenticating, .reconnecting:
                // Already in the process of connecting
                addLog(.info, "App returning to foreground - connection already in progress", category: .connection)
            }
        } else if !authUUID.isEmpty && !serverURL.isEmpty {
            // Have initial auth credentials but no reconnection token
            addLog(.info, "App returning to foreground - attempting initial connection", category: .connection)
            connect()
        }
    }
    
    @objc private func appWillTerminate() {
        disconnect()
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    private func sendPing() {
        guard let webSocketTask = webSocketTask else { return }
        webSocketTask.sendPing { [weak self] error in
            if let error = error {
                print("Ping failed: \(error)")
                DispatchQueue.main.async {
                    self?.handleConnectionLost()
                }
            }
        }
    }
    
    private func testConnection() {
        guard let webSocketTask = webSocketTask else {
            handleConnectionLost()
            return
        }
        
        // Send a ping to test if connection is still alive
        webSocketTask.sendPing { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Connection test failed: \(error)")
                    self?.isConnected = false
                    self?.connectionStatus = .disconnected
                    
                    // If we have reconnection token, try to reconnect
                    if let self = self, !self.reconnectionToken.isEmpty {
                        self.connectionStatus = .reconnecting
                        self.connect()
                    }
                }
            }
        }
    }
    
    private func handleConnectionLost() {
        isConnected = false
        connectionStatus = .disconnected
    }
    
    func saveSettings() {
        UserDefaults.standard.set(serverURL, forKey: "serverURL")
        UserDefaults.standard.set(authUUID, forKey: "authUUID")
        UserDefaults.standard.set(reconnectionToken, forKey: "reconnectionToken")
        UserDefaults.standard.set(clientId, forKey: "clientId")
        UserDefaults.standard.synchronize() // Force synchronization
        
        addLog(.info, "Settings saved to UserDefaults", category: .general)
    }
    
    func clearStoredCredentials() {
        reconnectionToken = ""
        clientId = ""
        authUUID = ""
        serverURL = ""
        saveSettings()
        logs.removeAll()
        repositories.removeAll()
        availableCommands.removeAll()
        customCommands.removeAll()
    }
    
    func connect() {
        addLog(.info, "Connect method called", category: .connection)
        
        guard !serverURL.isEmpty else {
            connectionStatus = .failed("No server URL")
            addLog(.error, "Connection failed: No server URL", category: .connection)
            return
        }
        
        guard let url = URL(string: serverURL) else {
            connectionStatus = .failed("Invalid URL")
            addLog(.error, "Connection failed: Invalid URL", category: .connection)
            return
        }
        
        // Cancel any existing connection first
        if webSocketTask != nil {
            addLog(.info, "Cancelling existing connection", category: .connection)
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
        }
        
        if !reconnectionToken.isEmpty && !clientId.isEmpty {
            connectionStatus = .reconnecting
            addLog(.info, "Reconnecting with token for client: \(clientId)", category: .connection)
        } else {
            connectionStatus = .connecting
            addLog(.info, "Connecting with initial authentication", category: .connection)
        }
        
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.shouldUseExtendedBackgroundIdleMode = true
        configuration.sessionSendsLaunchEvents = true
        
        let session = URLSession(configuration: configuration)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Don't set isConnected until we're authenticated
        connectionStatus = .authenticating
        
        if !reconnectionToken.isEmpty && !clientId.isEmpty {
            sendReconnectionToken(reconnectionToken)
        } else if !authUUID.isEmpty {
            sendAuthMessage(authUUID)
        } else {
            connectionStatus = .failed("No authentication credentials")
            disconnect()
        }
        
        receiveMessage()
    }
    
    func disconnect() {
        stopPingTimer()
        endBackgroundTask()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        connectionStatus = .disconnected
    }
    
    func clearLogs() {
        logs.removeAll()
    }
    
    private func sendAuthMessage(_ uuid: String) {
        guard let webSocketTask = webSocketTask else { return }
        
        let message = URLSessionWebSocketTask.Message.string(uuid)
        webSocketTask.send(message) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.connectionStatus = .failed("Auth error")
                }
            }
        }
    }
    
    private func sendReconnectionToken(_ token: String) {
        guard let webSocketTask = webSocketTask else { return }
        
        let tokenData = ["token": token]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: tokenData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            connectionStatus = .failed("Token serialization error")
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask.send(message) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.connectionStatus = .failed("Token auth error")
                }
            }
        }
    }
    
    func sendCommand(_ text: String) {
        guard let webSocketTask = webSocketTask,
              case .authenticated = connectionStatus else { return }
        
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask.send(message) { [weak self] error in
            if error == nil {
                DispatchQueue.main.async {
                    self?.addLog(.info, "Sent command: \(text)", category: .general)
                }
            } else {
                DispatchQueue.main.async {
                    self?.addLog(.error, "Failed to send command: \(error?.localizedDescription ?? "Unknown error")", category: .general)
                }
            }
        }
    }
    
    func selectRepository(_ repository: Repository) {
        guard let webSocketTask = webSocketTask,
              case .authenticated = connectionStatus else { return }
        
        let messageData: [String: Any] = [
            "type": "select_repo",
            "path": repository.path
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: messageData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask.send(message) { error in
            if error != nil {
                print("Failed to send repository selection")
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    DispatchQueue.main.async {
                        self?.handleTextMessage(text)
                    }
                case .data(let data):
                    print("Received data: \(data)")
                @unknown default:
                    break
                }
                
                self?.receiveMessage()
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.handleConnectionError(error)
                }
            }
        }
    }
    
    private func handleTextMessage(_ text: String) {
        // Try to parse as JSON first
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            // Check for message type
            if let type = json["type"] as? String {
                switch type {
                case "repo_list":
                    handleRepositoryList(json)
                case "repo_selected":
                    handleRepositorySelected(json)
                case "commands_list":
                    handleCommandsList(json)
                case "error":
                    handleErrorMessage(json)
                default:
                    // For other message types, log as general info
                    if let content = json["content"] as? String {
                        addLog(.info, content, category: .general)
                    }
                }
                return
            }
            
            // Handle auth messages (no type field)
            if let status = json["status"] as? String {
                if status == "AUTH_SUCCESS" {
                    isConnected = true
                    connectionStatus = .authenticated
                    
                    if let reconnectionToken = json["reconnection_token"] as? String {
                        self.reconnectionToken = reconnectionToken
                    }
                    if let clientId = json["client_id"] as? String {
                        self.clientId = clientId
                    }
                    saveSettings()
                    
                    addLog(.success, "Authentication successful", category: .authentication)
                    
                    NotificationCenter.default.post(name: .webSocketAuthenticated, object: nil)
                    
                    // Start ping timer after successful authentication
                    startPingTimer()
                }
                return
            }
        }
        
        // Handle plain text messages
        if text == "AUTH_SUCCESS" {
            isConnected = true
            connectionStatus = .authenticated
            addLog(.success, "Authentication successful", category: .authentication)
            NotificationCenter.default.post(name: .webSocketAuthenticated, object: nil)
        } else if text == "AUTH_FAILED" {
            if !reconnectionToken.isEmpty {
                // Server restarted - clear credentials and notify user
                connectionStatus = .failed("Session expired - server restarted")
                clearStoredCredentials()
                addLog(.warning, "Server was restarted. Please scan the QR code again.", category: .connection)
                // Post notification for UI to show connection sheet
                NotificationCenter.default.post(name: .serverRestartDetected, object: nil)
            } else {
                connectionStatus = .failed("Invalid UUID")
            }
            disconnect()
        } else if text == "AUTH_TIMEOUT" {
            if !reconnectionToken.isEmpty {
                // Auth timeout during reconnection - server likely restarted
                connectionStatus = .failed("Reconnection failed")
                clearStoredCredentials()
                addLog(.warning, "Could not reconnect. Server may have restarted.", category: .connection)
                NotificationCenter.default.post(name: .serverRestartDetected, object: nil)
            } else {
                connectionStatus = .failed("Auth timeout")
            }
            disconnect()
        } else {
            addLog(.info, text, category: .general)
        }
    }
    
    private func handleRepositoryList(_ json: [String: Any]) {
        guard let repoArray = json["repositories"] as? [[String: Any]] else { return }
        
        let repos = repoArray.compactMap { repoDict -> Repository? in
            guard let name = repoDict["name"] as? String,
                  let path = repoDict["path"] as? String else { return nil }
            return Repository(name: name, path: path)
        }
        
        repositories = repos
        
        // Log repository list
        if !repos.isEmpty {
            addLog(.success, "Loaded \(repos.count) repositories", category: .repository)
            for repo in repos {
                addLog(.info, "Repository: \(repo.name) at \(repo.path)", category: .repository)
            }
        } else {
            addLog(.warning, "No repositories found", category: .repository)
        }
        
        // Post notification for repository list update
        NotificationCenter.default.post(name: .repositoryListUpdated, object: repos)
    }
    
    private func handleRepositorySelected(_ json: [String: Any]) {
        if let repoData = json["repository"] as? [String: Any],
           let name = repoData["name"] as? String {
            addLog(.success, "Repository selected: \(name)", category: .repository)
        }
    }
    
    private func handleCommandsList(_ json: [String: Any]) {
        // Parse predefined commands
        if let predefinedData = json["predefined_commands"] as? [[String: Any]] {
            let predefined = predefinedData.compactMap { cmdDict -> SlashCommand? in
                guard let data = try? JSONSerialization.data(withJSONObject: cmdDict),
                      let command = try? JSONDecoder().decode(SlashCommand.self, from: data) else { return nil }
                return command
            }
            availableCommands = predefined
        }
        
        // Parse custom commands
        if let customData = json["custom_commands"] as? [[String: Any]] {
            let custom = customData.compactMap { cmdDict -> SlashCommand? in
                guard let data = try? JSONSerialization.data(withJSONObject: cmdDict),
                      let command = try? JSONDecoder().decode(SlashCommand.self, from: data) else { return nil }
                return command
            }
            customCommands = custom
            
            if !custom.isEmpty {
                addLog(.info, "Loaded \(custom.count) custom commands for this repository", category: .repository)
                for cmd in custom {
                    addLog(.info, "Custom command: \(cmd.name) - \(cmd.description)", category: .repository)
                }
            }
        }
        
        // Merge all commands
        availableCommands = availableCommands + customCommands
        
        // Post notification for commands update
        NotificationCenter.default.post(name: .commandsListUpdated, object: availableCommands)
    }
    
    private func handleErrorMessage(_ json: [String: Any]) {
        if let error = json["error"] as? String {
            addLog(.error, "Error: \(error)", category: .general)
        }
    }
    
    private func handleConnectionError(_ error: Error) {
        isConnected = false
        
        if !reconnectionToken.isEmpty {
            // Connection error during reconnection attempt
            connectionStatus = .failed("Cannot reach server")
            // Don't clear credentials immediately - server might just be temporarily unavailable
            addLog(.warning, "Unable to reconnect. Server may be offline. Will retry when server is available.", category: .connection)
            // Only post notification if we've tried multiple times or got specific auth errors
        } else {
            connectionStatus = .failed(error.localizedDescription)
            addLog(.error, "Connection failed: \(error.localizedDescription)", category: .connection)
        }
    }
}

// MARK: - Models

extension WebSocketManager {
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case authenticating
        case authenticated
        case failed(String)
        case reconnecting
        
        var color: Color {
            switch self {
            case .disconnected, .failed: return .red
            case .connecting, .authenticating, .reconnecting: return .orange
            case .authenticated: return .green
            }
        }
        
        var icon: String {
            switch self {
            case .disconnected, .failed: return "wifi.slash"
            case .connecting, .authenticating, .reconnecting: return "wifi.exclamationmark"
            case .authenticated: return "wifi"
            }
        }
        
        var text: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .authenticating: return "Authenticating..."
            case .authenticated: return "Connected"
            case .failed(let reason): return "Failed: \(reason)"
            case .reconnecting: return "Reconnecting..."
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let webSocketAuthenticated = Notification.Name("webSocketAuthenticated")
    static let repositoryListUpdated = Notification.Name("repositoryListUpdated")
    static let serverRestartDetected = Notification.Name("serverRestartDetected")
    static let commandsListUpdated = Notification.Name("commandsListUpdated")
}
