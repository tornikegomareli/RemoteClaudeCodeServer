//
//  SlashCommand.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import Foundation

struct SlashCommand: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let description: String
    let usage: String?
    let example: String?
    let content: String?  // Full content/prompt for .md commands
}