//
//  ContentView.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI
import Foundation
import Combine
import CodeScanner
import UIKit

// WebSocket Manager
class WebSocketManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isConnected = false
    @Published var connectionStatus = ConnectionStatus.disconnected
    @Published var serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
    @Published var authUUID = UserDefaults.standard.string(forKey: "authUUID") ?? ""
    @Published var reconnectionToken = UserDefaults.standard.string(forKey: "reconnectionToken") ?? ""
    @Published var clientId = UserDefaults.standard.string(forKey: "clientId") ?? ""
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var pingTimer: Timer?
    
    init() {
        setupNotificationObservers()
        attemptAutoConnect()
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
        // Start background task to keep connection alive
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Start ping timer to keep connection alive
        startPingTimer()
    }
    
    @objc private func appWillEnterForeground() {
        // End background task
        endBackgroundTask()
        
        // Stop ping timer
        stopPingTimer()
        
        // Check connection status and reconnect if needed
        if !isConnected && !reconnectionToken.isEmpty {
            connect()
        }
    }
    
    @objc private func appWillTerminate() {
        // Gracefully disconnect
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
                // Connection might be dead, try to reconnect
                DispatchQueue.main.async {
                    self?.handleConnectionLost()
                }
            }
        }
    }
    
    private func handleConnectionLost() {
        isConnected = false
        connectionStatus = .disconnected
        // Will automatically reconnect when app comes to foreground
    }
    
    private func attemptAutoConnect() {
        // Check if we have stored credentials
        guard !serverURL.isEmpty,
              (!reconnectionToken.isEmpty || !authUUID.isEmpty) else {
            return
        }
        
        // Attempt to connect on startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.connect()
        }
    }
    
    private func clearStoredCredentials() {
        reconnectionToken = ""
        clientId = ""
        authUUID = ""
        serverURL = ""
        saveSettings()
        messages.removeAll()
    }
    
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
    
    struct Message: Identifiable {
        let id = UUID()
        let text: String
        let isFromServer: Bool
        let timestamp = Date()
    }
    
    func saveSettings() {
        UserDefaults.standard.set(serverURL, forKey: "serverURL")
        UserDefaults.standard.set(authUUID, forKey: "authUUID")
        UserDefaults.standard.set(reconnectionToken, forKey: "reconnectionToken")
        UserDefaults.standard.set(clientId, forKey: "clientId")
    }
    
    func connect() {
        guard !serverURL.isEmpty else {
            connectionStatus = .failed("No server URL")
            return
        }
        
        guard let url = URL(string: serverURL) else {
            connectionStatus = .failed("Invalid URL")
            return
        }
        
        // Set appropriate status based on whether we're reconnecting
        if !reconnectionToken.isEmpty && !clientId.isEmpty {
            connectionStatus = .reconnecting
        } else {
            connectionStatus = .connecting
        }
        
        // Configure session for background support
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.shouldUseExtendedBackgroundIdleMode = true
        configuration.sessionSendsLaunchEvents = true
        
        let session = URLSession(configuration: configuration)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        isConnected = true
        connectionStatus = .authenticating
        
        // Try reconnection token first if available
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
    
    func sendMessage(_ text: String) {
        guard let webSocketTask = webSocketTask, 
              case .authenticated = connectionStatus else { return }
        
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask.send(message) { [weak self] error in
            if error == nil {
                DispatchQueue.main.async {
                    self?.messages.append(Message(text: text, isFromServer: false))
                }
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
                        // Try to parse as JSON first
                        if let data = text.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let status = json["status"] as? String {
                            
                            if status == "AUTH_SUCCESS" {
                                self?.connectionStatus = .authenticated
                                
                                // Extract and save reconnection token and client ID
                                if let reconnectionToken = json["reconnection_token"] as? String {
                                    self?.reconnectionToken = reconnectionToken
                                }
                                if let clientId = json["client_id"] as? String {
                                    self?.clientId = clientId
                                }
                                self?.saveSettings()
                                
                                self?.messages.append(Message(
                                    text: "✅ Authentication successful", 
                                    isFromServer: true
                                ))
                            }
                        } else if text == "AUTH_SUCCESS" {
                            // Backward compatibility for plain text response
                            self?.connectionStatus = .authenticated
                            self?.messages.append(Message(
                                text: "✅ Authentication successful", 
                                isFromServer: true
                            ))
                        } else if text == "AUTH_FAILED" {
                            // Check if we were using reconnection token
                            if !(self?.reconnectionToken.isEmpty ?? true) {
                                self?.connectionStatus = .failed("Session expired - server may have restarted")
                                self?.clearStoredCredentials()
                                self?.messages.append(Message(
                                    text: "⚠️ Previous session expired. Please reconnect with QR code.",
                                    isFromServer: true
                                ))
                            } else {
                                self?.connectionStatus = .failed("Invalid UUID")
                            }
                            self?.disconnect()
                        } else if text == "AUTH_TIMEOUT" {
                            self?.connectionStatus = .failed("Auth timeout")
                            self?.disconnect()
                        } else {
                            self?.messages.append(Message(text: text, isFromServer: true))
                        }
                    }
                case .data(let data):
                    print("Received data: \(data)")
                @unknown default:
                    break
                }
                
                self?.receiveMessage()
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.isConnected = false
                    
                    // Check if this was a reconnection attempt
                    if !(self?.reconnectionToken.isEmpty ?? true) {
                        // Network error during reconnection - might be server down
                        self?.connectionStatus = .failed("Cannot reach server - it may be offline")
                        self?.messages.append(Message(
                            text: "⚠️ Unable to reconnect. Server may be offline or restarted.",
                            isFromServer: true
                        ))
                        // Don't clear credentials on network error - let user retry
                    } else {
                        self?.connectionStatus = .failed(error.localizedDescription)
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var webSocketManager = WebSocketManager()
    @State private var messageText = ""
    @State private var showConnectionView = false
    @State private var showSessionExpiredAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection Status Bar
                ConnectionStatusBar(manager: webSocketManager)
                    .onTapGesture {
                        showConnectionView = true
                    }
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(webSocketManager.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: webSocketManager.messages.count) { oldValue, newValue in
                        if let lastMessage = webSocketManager.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input Area
                if case .authenticated = webSocketManager.connectionStatus {
                    MessageInputView(messageText: $messageText) {
                        if !messageText.isEmpty {
                            webSocketManager.sendMessage(messageText)
                            messageText = ""
                        }
                    }
                }
            }
            .navigationTitle("RemoteClaudeCode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showConnectionView = true }) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(webSocketManager.connectionStatus.color)
                    }
                }
            }
            .sheet(isPresented: $showConnectionView) {
                ConnectionSetupView(manager: webSocketManager)
            }
            .alert("Session Expired", isPresented: $showSessionExpiredAlert) {
                Button("OK") {
                    showConnectionView = true
                }
            } message: {
                Text("Your previous session has expired. The server may have restarted. Please scan the QR code again to reconnect.")
            }
            .onReceive(webSocketManager.$connectionStatus) { status in
                if case .failed(let reason) = status,
                   reason.contains("Session expired") {
                    showSessionExpiredAlert = true
                }
            }
        }
    }
}

struct ConnectionStatusBar: View {
    @ObservedObject var manager: WebSocketManager
    
    var body: some View {
        HStack {
            Image(systemName: manager.connectionStatus.icon)
                .foregroundColor(manager.connectionStatus.color)
            
            Text(manager.connectionStatus.text)
                .font(.system(.body, design: .monospaced))
            
            Spacer()
            
            if manager.isConnected {
                Button("Disconnect") {
                    manager.disconnect()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }
}

struct ConnectionSetupView: View {
    @ObservedObject var manager: WebSocketManager
    @Environment(\.dismiss) var dismiss
    @State private var showScanner = false
    @State private var tempServerURL: String = ""
    @State private var tempAuthUUID: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Connect to Server")
                            .font(.largeTitle)
                            .bold()
                        
                        Text("Scan the QR code displayed by the server or enter the connection details manually.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Quick Setup") {
                    Button(action: { showScanner = true }) {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Section("Manual Setup") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("wss://example.ngrok.io/ws", text: $tempServerURL)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Authentication UUID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $tempAuthUUID)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                
                Section {
                    Button(action: connect) {
                        HStack {
                            Spacer()
                            Label("Connect", systemImage: "link")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(tempServerURL.isEmpty || tempAuthUUID.isEmpty)
                }
            }
            .navigationTitle("Connection Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                tempServerURL = manager.serverURL
                tempAuthUUID = manager.authUUID
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView { result in
                    switch result {
                    case .success(let code):
                        handleQRCode(code.string)
                        showScanner = false
                    case .failure(let error):
                        print("Scanning failed: \(error)")
                    }
                }
            }
        }
    }
    
    func handleQRCode(_ qrData: String) {
        // Try to parse as JSON first
        if let data = qrData.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Extract UUID from JSON
            if let uuid = json["uuid"] as? String {
                tempAuthUUID = uuid
            }
            // Extract URL and ensure it's a WebSocket URL
            if let url = json["url"] as? String {
                // URL from server already has wss:// and /ws
                tempServerURL = url
            }
        } else {
            // Fallback: treat as plain UUID for backward compatibility
            tempAuthUUID = qrData
        }
    }
    
    func connect() {
        manager.serverURL = tempServerURL
        manager.authUUID = tempAuthUUID
        manager.saveSettings()
        dismiss()
        
        // Auto-connect after saving
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            manager.connect()
        }
    }
}

struct QRScannerView: View {
    let completion: (Result<ScanResult, ScanError>) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            CodeScannerView(
                codeTypes: [.qr],
                simulatedData: "a123f0a0-570e-44dd-9b12-79a2809cf60e",
                completion: completion
            )
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: WebSocketManager.Message
    
    var body: some View {
        HStack {
            if !message.isFromServer {
                Spacer()
            }
            
            VStack(alignment: message.isFromServer ? .leading : .trailing, spacing: 4) {
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        message.isFromServer 
                            ? Color(UIColor.secondarySystemBackground) 
                            : Color.blue
                    )
                    .foregroundColor(message.isFromServer ? .primary : .white)
                    .cornerRadius(18)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.isFromServer ? .leading : .trailing)
            
            if message.isFromServer {
                Spacer()
            }
        }
    }
}

struct MessageInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type a message", text: $messageText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onSend)
            
            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .disabled(messageText.isEmpty)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    ContentView()
}