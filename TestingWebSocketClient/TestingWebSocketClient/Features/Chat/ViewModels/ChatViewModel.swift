//
//  ChatViewModel.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import Foundation
import Observation

@Observable
class ChatViewModel {
    var messageText = ""
    
    private let webSocketClient: WebSocketClient
    private let messageService: MessageService
    private let repositoryService: RepositoryService
    private let connectionViewModel: ConnectionViewModel
    
    var messages: [Message] {
        messageService.messages
    }
    
    var canSendMessage: Bool {
        connectionViewModel.connectionStatus == .authenticated && 
        repositoryService.selectedRepository != nil
    }
    
    init(webSocketClient: WebSocketClient,
         messageService: MessageService,
         repositoryService: RepositoryService,
         connectionViewModel: ConnectionViewModel) {
        self.webSocketClient = webSocketClient
        self.messageService = messageService
        self.repositoryService = repositoryService
        self.connectionViewModel = connectionViewModel
    }
    
    func sendPrompt() {
        guard !messageText.isEmpty else { return }
        
        guard canSendMessage else {
            messageService.addMessage("⚠️ Please select a repository first", isFromServer: true)
            return
        }
        
        guard let message = repositoryService.createPromptMessage(messageText) else { return }
        
        webSocketClient.sendText(message) { [weak self] error in
            guard let self = self else { return }
            
            if error == nil {
                DispatchQueue.main.async {
                    self.messageService.addMessage(self.messageText, isFromServer: false)
                    self.messageText = ""
                }
            }
        }
    }
}
