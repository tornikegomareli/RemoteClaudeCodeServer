//
//  ConnectionStatusBar.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct ConnectionStatusBar: View {
    let connectionStatus: ConnectionStatus
    let isConnected: Bool
    let onDisconnect: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: connectionStatus.icon)
                .foregroundColor(connectionStatus.color)
            
            Text(connectionStatus.text)
                .font(.system(.body, design: .monospaced))
            
            Spacer()
            
            if isConnected {
                Button("Disconnect", action: onDisconnect)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }
}