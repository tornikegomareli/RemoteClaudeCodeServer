//
//  ConnectionSheet.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI
import CodeScanner
import Combine

struct ConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var selectedMode = ConnectionMode.manual
    @State private var serverURL = ""
    @State private var authUUID = ""
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showScanner = false
    
    enum ConnectionMode: String, CaseIterable {
        case manual = "Manual"
        case qr = "QR Code"
        
        var icon: String {
            switch self {
            case .manual: return "keyboard"
            case .qr: return "qrcode.viewfinder"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .padding(.top, AppTheme.Spacing.xSmall)
                    .padding(.bottom, AppTheme.Spacing.medium)
                
                // Title
                Text("Connect to Server")
                    .font(AppTheme.Typography.title2)
                    .padding(.bottom, AppTheme.Spacing.large)
                
                // Connection mode picker
                Picker("Connection Mode", selection: $selectedMode) {
                    ForEach(ConnectionMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.bottom, AppTheme.Spacing.large)
                
                // Content based on mode
                if selectedMode == .manual {
                    manualEntryView
                } else {
                    qrScanView
                }
                
                Spacer()
            }
            .background(AppTheme.Colors.background)
            .navigationBarHidden(true)
            .alert("Connection Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showScanner) {
            ScannerView { result in
                handleScanResult(result)
            }
        }
    }
    
    private var manualEntryView: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            // Quick connect section
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Recent Connections")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.secondaryLabel)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.small) {
                        ForEach(RecentConnection.mockData) { connection in
                            RecentConnectionCard(connection: connection) {
                                serverURL = connection.url
                                authUUID = connection.uuid
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            
            Divider()
                .padding(.vertical, AppTheme.Spacing.small)
            
            // Manual entry fields
            VStack(spacing: AppTheme.Spacing.medium) {
                FloatingTextField(
                    placeholder: "Server URL",
                    text: $serverURL,
                    icon: "link"
                )
                
                FloatingTextField(
                    placeholder: "Authentication UUID",
                    text: $authUUID,
                    icon: "key"
                )
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            
            // Connect button
            PrimaryButton("Connect", isLoading: isConnecting) {
                connect()
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.top, AppTheme.Spacing.large)
        }
    }
    
    private var qrScanView: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            // QR illustration
            Image(systemName: "qrcode")
                .font(.system(size: 120, weight: .ultraLight))
                .foregroundColor(AppTheme.Colors.primary)
                .padding(.vertical, AppTheme.Spacing.large)
            
            Text("Scan the QR code displayed on your development machine")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.large)
            
            PrimaryButton("Open Scanner") {
                showScanner = true
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
        }
    }
    
    private func connect() {
        guard !serverURL.isEmpty && !authUUID.isEmpty else {
            errorMessage = "Please fill in all fields"
            showError = true
            return
        }
        
        isConnecting = true
        
        // Connect using WebSocketManager
        appState.connect(serverURL: serverURL, authUUID: authUUID)
        
        // Monitor connection status
        let cancellable = appState.webSocketManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak appState] status in
                switch status {
                case .authenticated:
                    isConnecting = false
                    // Success haptic
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.success)
                    dismiss()
                case .failed(let reason):
                    isConnecting = false
                    errorMessage = reason
                    showError = true
                    // Error haptic
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.error)
                default:
                    break
                }
            }
        
        // Cancel subscription after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            cancellable.cancel()
            if isConnecting {
                isConnecting = false
                errorMessage = "Connection timeout"
                showError = true
            }
        }
    }
    
    private func handleScanResult(_ result: Result<ScanResult, ScanError>) {
        switch result {
        case .success(let scanResult):
            // Parse QR code data
            if let data = scanResult.string.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let url = json["url"] as? String,
               let uuid = json["uuid"] as? String {
                serverURL = url
                authUUID = uuid
                showScanner = false
                selectedMode = .manual // Switch to manual to show filled fields
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

/// Floating label text field
struct FloatingTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: icon)
                .foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.secondaryLabel)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                if !text.isEmpty || isFocused {
                    Text(placeholder)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.secondaryLabel)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                TextField(text.isEmpty && !isFocused ? placeholder : "", text: $text)
                    .focused($isFocused)
                    .font(AppTheme.Typography.body)
            }
        }
        .padding(AppTheme.Spacing.medium)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(isFocused ? AppTheme.Colors.primary : Color.clear, lineWidth: 2)
        )
        .animation(AppTheme.Animation.quick, value: isFocused)
    }
}

/// Recent connection card
struct RecentConnectionCard: View {
    let connection: RecentConnection
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                Text(connection.name)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.label)
                
                Text(connection.url)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.secondaryLabel)
                    .lineLimit(1)
            }
            .padding(AppTheme.Spacing.medium)
            .frame(width: 200)
            .background(AppTheme.Colors.tertiaryBackground)
            .cornerRadius(AppTheme.CornerRadius.medium)
        }
    }
}

/// Recent connection model
struct RecentConnection: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let uuid: String
    
    static let mockData = [
        RecentConnection(name: "Local Development", url: "ws://localhost:9001", uuid: "abc123"),
        RecentConnection(name: "Remote Server", url: "wss://dev.ngrok.io", uuid: "def456")
    ]
}

/// Scanner view wrapper
struct ScannerView: View {
    let completion: (Result<ScanResult, ScanError>) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            CodeScannerView(
                codeTypes: [.qr],
                simulatedData: "{\"url\":\"wss://example.ngrok.io/ws\",\"uuid\":\"test-uuid-123\"}",
                completion: completion
            )
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ConnectionSheet()
}