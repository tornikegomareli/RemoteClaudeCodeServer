//
//  MessageService.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import Foundation

class MessageService: ObservableObject {
    @Published var messages: [Message] = []
    
    func addMessage(_ text: String, isFromServer: Bool) {
        let message = Message(text: text, isFromServer: isFromServer)
        messages.append(message)
    }
    
    func clearMessages() {
        messages.removeAll()
    }
    
    func handleServerMessage(_ message: ServerMessage) -> String? {
        switch message.type {
        case .repoList:
            if let repos = message.repositories {
                return "📋 Received \(repos.count) repositories"
            }
        case .repoSelected:
            if let repo = message.repository {
                return "✅ Selected repository: \(repo.name)"
            }
        case .error:
            if let errorMessage = message.message {
                return "❌ Error: \(errorMessage)"
            }
        case .response:
            if let text = message.text {
                return text
            }
        }
        return nil
    }
    
    func parseTextMessage(_ text: String) -> (status: String?, isAuthMessage: Bool) {
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? String {
            return (status, true)
        }
        
        // Check for plain text auth messages
        if text == "AUTH_SUCCESS" || text == "AUTH_FAILED" || text == "AUTH_TIMEOUT" {
            return (text, true)
        }
        
        return (nil, false)
    }
}