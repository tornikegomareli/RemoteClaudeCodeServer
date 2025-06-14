//
//  ServerMessage.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import Foundation

enum ServerMessageType: String, Codable {
    case repoList = "repo_list"
    case repoSelected = "repo_selected"
    case error = "error"
    case response = "response"
}

struct ServerMessage: Codable {
    let type: ServerMessageType
    let repositories: [Repository]?
    let repository: Repository?
    let message: String?
    let text: String?
}