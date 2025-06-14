//
//  RepositoryService.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import Foundation

class RepositoryService: ObservableObject {
    @Published var repositories: [Repository] = []
    @Published var selectedRepository: Repository?
    
    func updateRepositories(_ repos: [Repository]) {
        repositories = repos
    }
    
    func selectRepository(_ repository: Repository) {
        selectedRepository = repository
    }
    
    func createListReposMessage() -> String? {
        let message = ClientMessage(type: .listRepos, path: nil, text: nil)
        guard let jsonData = try? JSONEncoder().encode(message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
    
    func createSelectRepoMessage(_ repository: Repository) -> String? {
        let message = ClientMessage(type: .selectRepo, path: repository.path, text: nil)
        guard let jsonData = try? JSONEncoder().encode(message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
    
    func createPromptMessage(_ text: String) -> String? {
        let message = ClientMessage(type: .prompt, path: nil, text: text)
        guard let jsonData = try? JSONEncoder().encode(message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
}