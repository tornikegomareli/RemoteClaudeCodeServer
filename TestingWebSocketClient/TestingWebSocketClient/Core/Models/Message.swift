//
//  Message.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import Foundation

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isFromServer: Bool
    let timestamp = Date()
}