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
    case commandsList = "commands_list"
}

struct ServerMessage: Codable {
    let type: ServerMessageType
    let repositories: [Repository]?
    let repository: Repository?
    let message: String?
    let text: String?
    let predefinedCommands: [SlashCommand]?
    let customCommands: [SlashCommand]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case repositories
        case repository
        case message
        case text
        case predefinedCommands = "predefined_commands"
        case customCommands = "custom_commands"
    }
}