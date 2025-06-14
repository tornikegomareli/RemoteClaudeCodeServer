//
//  ConnectionViewModel.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import Foundation
import Observation

@Observable
class ConnectionViewModel {
    var connectionStatus = ConnectionStatus.disconnected
    var isConnected = false
    var showSessionExpiredAlert = false
    
    private let webSocketClient: WebSocketClient
    private let authService: AuthenticationService
    private let messageService: MessageService
    private let repositoryService: RepositoryService
    
    init(webSocketClient: WebSocketClient,
         authService: AuthenticationService,
         messageService: MessageService,
         repositoryService: RepositoryService) {
        self.webSocketClient = webSocketClient
        self.authService = authService
        self.messageService = messageService
        self.repositoryService = repositoryService
        
        setupBindings()
        attemptAutoConnect()
    }
    
    private func setupBindings() {
        // Observe WebSocket client changes
        webSocketClient.delegate = self
    }
    
    private func attemptAutoConnect() {
        guard authService.hasStoredCredentials() else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.connect()
        }
    }
    
    func connect() {
        guard !authService.serverURL.isEmpty else {
            connectionStatus = .failed("No server URL")
            return
        }
        
        guard let url = URL(string: authService.serverURL) else {
            connectionStatus = .failed("Invalid URL")
            return
        }
        
        if authService.shouldUseReconnectionToken() {
            connectionStatus = .reconnecting
        } else {
            connectionStatus = .connecting
        }
        
        webSocketClient.connect(to: url)
        isConnected = true
        connectionStatus = .authenticating
        
        // Send authentication
        if let authMessage = authService.createAuthMessage() {
            webSocketClient.sendText(authMessage) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.connectionStatus = .failed("Auth error: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            connectionStatus = .failed("No authentication credentials")
            disconnect()
        }
    }
    
    func disconnect() {
        webSocketClient.disconnect()
        isConnected = false
        connectionStatus = .disconnected
    }
    
    func updateCredentials(serverURL: String, authUUID: String) {
        authService.serverURL = serverURL
        authService.authUUID = authUUID
        authService.saveCredentials()
    }
}

// MARK: - WebSocketClientDelegate
extension ConnectionViewModel: WebSocketClientDelegate {
    func webSocketClient(_ client: WebSocketClient, didReceive message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleTextMessage(text)
        case .data(let data):
            print("Received data: \(data)")
        @unknown default:
            break
        }
    }
    
    func webSocketClient(_ client: WebSocketClient, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isConnected = false
            
            if self.authService.shouldUseReconnectionToken() {
                self.connectionStatus = .failed("Cannot reach server - it may be offline")
                self.messageService.addMessage("⚠️ Unable to reconnect. Server may be offline or restarted.", isFromServer: true)
            } else {
                self.connectionStatus = .failed(error.localizedDescription)
            }
        }
    }
    
    func webSocketClientDidDisconnect(_ client: WebSocketClient) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = .disconnected
        }
    }
    
    func webSocketClientNeedsReconnection(_ client: WebSocketClient) {
        if authService.hasStoredCredentials() {
            connect()
        }
    }
    
    private func handleTextMessage(_ text: String) {
        DispatchQueue.main.async {
            // Try to parse as JSON auth response
            if let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // Handle auth response
                if let status = json["status"] as? String {
                    self.handleAuthStatus(status, json: json)
                    return
                }
                
                // Handle server message
                if let serverMessage = try? JSONDecoder().decode(ServerMessage.self, from: data) {
                    self.handleServerMessage(serverMessage)
                    return
                }
            }
            
            // Handle plain text messages
            let (status, isAuthMessage) = self.messageService.parseTextMessage(text)
            if isAuthMessage, let status = status {
                self.handleAuthStatus(status, json: nil)
            } else {
                self.messageService.addMessage(text, isFromServer: true)
            }
        }
    }
    
    private func handleAuthStatus(_ status: String, json: [String: Any]?) {
        switch status {
        case "AUTH_SUCCESS":
            connectionStatus = .authenticated
            if let json = json {
                authService.handleAuthResponse(json)
            }
            messageService.addMessage("✅ Authentication successful", isFromServer: true)
            
            // Auto-request repository list after successful auth
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.requestRepositoryList()
            }
            
        case "AUTH_FAILED":
            if authService.shouldUseReconnectionToken() {
                connectionStatus = .failed("Session expired - server may have restarted")
                authService.clearCredentials()
                messageService.addMessage("⚠️ Previous session expired. Please reconnect with QR code.", isFromServer: true)
                showSessionExpiredAlert = true
            } else {
                connectionStatus = .failed("Invalid UUID")
            }
            disconnect()
            
        case "AUTH_TIMEOUT":
            connectionStatus = .failed("Auth timeout")
            disconnect()
            
        default:
            break
        }
    }
    
    private func handleServerMessage(_ message: ServerMessage) {
        // Update repository service
        if case .repoList = message.type, let repos = message.repositories {
            repositoryService.updateRepositories(repos)
        } else if case .repoSelected = message.type, let repo = message.repository {
            repositoryService.selectedRepository = repo
        }
        
        // Add message to chat
        if let text = messageService.handleServerMessage(message) {
            messageService.addMessage(text, isFromServer: true)
        }
    }
    
    private func requestRepositoryList() {
        guard case .authenticated = connectionStatus,
              let message = repositoryService.createListReposMessage() else { return }
        
        webSocketClient.sendText(message) { error in
            if let error = error {
                print("Failed to request repository list: \(error)")
            }
        }
    }
}