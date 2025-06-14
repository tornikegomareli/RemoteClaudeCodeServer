//
//  WebSocketClient.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import Foundation
import UIKit
import Combine

class WebSocketClient: ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus = ConnectionStatus.disconnected
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var pingTimer: Timer?
    
    /// Delegate for handling received messages
    weak var delegate: WebSocketClientDelegate?
    
    init() {
        setupNotificationObservers()
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
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        startPingTimer()
    }
    
    @objc private func appWillEnterForeground() {
        endBackgroundTask()
        stopPingTimer()
        
        if !isConnected {
            delegate?.webSocketClientNeedsReconnection(self)
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
    
    private func handleConnectionLost() {
        isConnected = false
        connectionStatus = .disconnected
        delegate?.webSocketClientDidDisconnect(self)
    }
    
    func connect(to url: URL) {
        connectionStatus = .connecting
        
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.shouldUseExtendedBackgroundIdleMode = true
        configuration.sessionSendsLaunchEvents = true
        
        let session = URLSession(configuration: configuration)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        isConnected = true
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
    
    func send(_ message: URLSessionWebSocketTask.Message, completion: @escaping (Error?) -> Void) {
        webSocketTask?.send(message, completionHandler: completion)
    }
    
    func sendText(_ text: String, completion: @escaping (Error?) -> Void) {
        let message = URLSessionWebSocketTask.Message.string(text)
        send(message, completion: completion)
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.delegate?.webSocketClient(self, didReceive: message)
                self.receiveMessage()
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.delegate?.webSocketClient(self, didFailWithError: error)
                }
            }
        }
    }
}

/// Protocol for handling WebSocket events
protocol WebSocketClientDelegate: AnyObject {
    func webSocketClient(_ client: WebSocketClient, didReceive message: URLSessionWebSocketTask.Message)
    func webSocketClient(_ client: WebSocketClient, didFailWithError error: Error)
    func webSocketClientDidDisconnect(_ client: WebSocketClient)
    func webSocketClientNeedsReconnection(_ client: WebSocketClient)
}