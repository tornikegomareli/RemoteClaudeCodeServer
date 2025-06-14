//
//  MessageBubble.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if !message.isFromServer {
                Spacer()
            }
            
            VStack(alignment: message.isFromServer ? .leading : .trailing, spacing: 4) {
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        message.isFromServer 
                            ? Color(UIColor.secondarySystemBackground) 
                            : Color.blue
                    )
                    .foregroundColor(message.isFromServer ? .primary : .white)
                    .cornerRadius(18)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.isFromServer ? .leading : .trailing)
            
            if message.isFromServer {
                Spacer()
            }
        }
    }
}