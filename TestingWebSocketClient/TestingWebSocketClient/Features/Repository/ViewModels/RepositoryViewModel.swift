//
//  RepositoryViewModel.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import Foundation
import Observation

@Observable
class RepositoryViewModel {
    var showSideMenu = false
    
    private let webSocketClient: WebSocketClient
    private let repositoryService: RepositoryService
    private let messageService: MessageService
    private let connectionViewModel: ConnectionViewModel
    
    var repositories: [Repository] {
        repositoryService.repositories
    }
    
    var selectedRepository: Repository? {
        repositoryService.selectedRepository
    }
    
    init(webSocketClient: WebSocketClient,
         repositoryService: RepositoryService,
         messageService: MessageService,
         connectionViewModel: ConnectionViewModel) {
        self.webSocketClient = webSocketClient
        self.repositoryService = repositoryService
        self.messageService = messageService
        self.connectionViewModel = connectionViewModel
    }
    
    func selectRepository(_ repository: Repository) {
        guard connectionViewModel.connectionStatus == .authenticated else { return }
        
        repositoryService.selectRepository(repository)
        
        guard let message = repositoryService.createSelectRepoMessage(repository) else { return }
        
        webSocketClient.sendText(message) { [weak self] error in
            if error == nil {
                DispatchQueue.main.async {
                    self?.messageService.addMessage("📂 Selected repository: \(repository.name)", isFromServer: true)
                    self?.showSideMenu = false
                }
            }
        }
    }
    
    func refreshRepositories() {
        guard connectionViewModel.connectionStatus == .authenticated else { return }
        
        guard let message = repositoryService.createListReposMessage() else { return }
        
        webSocketClient.sendText(message) { error in
            if let error = error {
                print("Failed to request repository list: \(error)")
            }
        }
    }
}