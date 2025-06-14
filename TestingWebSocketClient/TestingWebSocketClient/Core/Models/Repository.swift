//
//  Repository.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import Foundation

struct Repository: Codable, Identifiable, Equatable {
    let name: String
    let path: String
    
    var id: String { path }
}