//
//  ConnectionStatus.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case authenticating
    case authenticated
    case failed(String)
    case reconnecting
    
    var color: Color {
        switch self {
        case .disconnected, .failed: return .red
        case .connecting, .authenticating, .reconnecting: return .orange
        case .authenticated: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .disconnected, .failed: return "wifi.slash"
        case .connecting, .authenticating, .reconnecting: return "wifi.exclamationmark"
        case .authenticated: return "wifi"
        }
    }
    
    var text: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .authenticating: return "Authenticating..."
        case .authenticated: return "Connected"
        case .failed(let reason): return "Failed: \(reason)"
        case .reconnecting: return "Reconnecting..."
        }
    }
}