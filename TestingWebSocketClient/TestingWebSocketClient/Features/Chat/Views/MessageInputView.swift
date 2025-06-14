//
//  MessageInputView.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct MessageInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type a message", text: $messageText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onSend)
            
            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .disabled(messageText.isEmpty)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}