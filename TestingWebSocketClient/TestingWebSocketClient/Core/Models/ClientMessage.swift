//
//  ClientMessage.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import Foundation

enum ClientMessageType: String, Codable {
    case listRepos = "list_repos"
    case selectRepo = "select_repo"
    case prompt = "prompt"
}

struct ClientMessage: Codable {
    let type: ClientMessageType
    let path: String?
    let text: String?
}