//
//  ChatView.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct ChatView: View {
    @State private var connectionViewModel: ConnectionViewModel
    @State private var chatViewModel: ChatViewModel
    @State private var repositoryViewModel: RepositoryViewModel
    private let authService: AuthenticationService
    
    @State private var showConnectionView = false
    @State private var showSessionExpiredAlert = false
    
    init() {
        let container = DependencyContainer.shared
        self._connectionViewModel = State(initialValue: container.connectionViewModel)
        self._chatViewModel = State(initialValue: container.chatViewModel)
        self._repositoryViewModel = State(initialValue: container.repositoryViewModel)
        self.authService = container.authenticationService
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Connection Status Bar
                    ConnectionStatusBar(
                        connectionStatus: connectionViewModel.connectionStatus,
                        isConnected: connectionViewModel.isConnected,
                        onDisconnect: connectionViewModel.disconnect
                    )
                    .onTapGesture {
                        showConnectionView = true
                    }
                    
                    // Messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(chatViewModel.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding()
                        }
                        .onChange(of: chatViewModel.messages.count) { oldValue, newValue in
                            if let lastMessage = chatViewModel.messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Input Area
                    if connectionViewModel.connectionStatus == .authenticated {
                        MessageInputView(
                            messageText: $chatViewModel.messageText,
                            onSend: chatViewModel.sendPrompt
                        )
                    }
                }
                
                // Side Menu
                SideMenuView(
                    repositoryViewModel: repositoryViewModel,
                    isShowing: $repositoryViewModel.showSideMenu
                )
            }
            .navigationTitle("RemoteClaudeCode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if connectionViewModel.connectionStatus == .authenticated {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                repositoryViewModel.showSideMenu.toggle()
                            }
                        }) {
                            Image(systemName: "line.horizontal.3")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showConnectionView = true }) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(connectionViewModel.connectionStatus.color)
                    }
                }
            }
            .sheet(isPresented: $showConnectionView) {
                ConnectionSetupView(
                    connectionViewModel: connectionViewModel,
                    authService: authService
                )
            }
            .alert("Session Expired", isPresented: $showSessionExpiredAlert) {
                Button("OK") {
                    showConnectionView = true
                }
            } message: {
                Text("Your previous session has expired. The server may have restarted. Please scan the QR code again to reconnect.")
            }
            .onChange(of: connectionViewModel.showSessionExpiredAlert) { _, newValue in
                showSessionExpiredAlert = newValue
            }
        }
    }
}

