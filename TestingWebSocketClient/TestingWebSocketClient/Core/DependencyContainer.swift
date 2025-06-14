//
//  DependencyContainer.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import Foundation

class DependencyContainer {
    static let shared = DependencyContainer()
    
    lazy var webSocketClient = WebSocketClient()
    lazy var authenticationService = AuthenticationService()
    lazy var messageService = MessageService()
    lazy var repositoryService = RepositoryService()
    
    lazy var connectionViewModel = ConnectionViewModel(
        webSocketClient: webSocketClient,
        authService: authenticationService,
        messageService: messageService,
        repositoryService: repositoryService
    )
    
    lazy var chatViewModel = ChatViewModel(
        webSocketClient: webSocketClient,
        messageService: messageService,
        repositoryService: repositoryService,
        connectionViewModel: connectionViewModel
    )
    
    lazy var repositoryViewModel = RepositoryViewModel(
        webSocketClient: webSocketClient,
        repositoryService: repositoryService,
        messageService: messageService,
        connectionViewModel: connectionViewModel
    )
    
    private init() {}
}