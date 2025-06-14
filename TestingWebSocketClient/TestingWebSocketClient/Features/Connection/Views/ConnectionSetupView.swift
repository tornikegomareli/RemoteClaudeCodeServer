//
//  ConnectionSetupView.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI
import CodeScanner

struct ConnectionSetupView: View {
    let connectionViewModel: ConnectionViewModel
    let authService: AuthenticationService
    
    @Environment(\.dismiss) var dismiss
    @State private var showScanner = false
    @State private var tempServerURL: String = ""
    @State private var tempAuthUUID: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Connect to Server")
                            .font(.largeTitle)
                            .bold()
                        
                        Text("Scan the QR code displayed by the server or enter the connection details manually.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Quick Setup") {
                    Button(action: { showScanner = true }) {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Section("Manual Setup") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("wss://example.ngrok.io/ws", text: $tempServerURL)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Authentication UUID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $tempAuthUUID)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                
                Section {
                    Button(action: connect) {
                        HStack {
                            Spacer()
                            Label("Connect", systemImage: "link")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(tempServerURL.isEmpty || tempAuthUUID.isEmpty)
                }
            }
            .navigationTitle("Connection Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                tempServerURL = authService.serverURL
                tempAuthUUID = authService.authUUID
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView { result in
                    switch result {
                    case .success(let code):
                        handleQRCode(code.string)
                        showScanner = false
                    case .failure(let error):
                        print("Scanning failed: \(error)")
                    }
                }
            }
        }
    }
    
    func handleQRCode(_ qrData: String) {
        let (uuid, url) = authService.parseQRCode(qrData)
        if let uuid = uuid {
            tempAuthUUID = uuid
        }
        if let url = url {
            tempServerURL = url
        }
    }
    
    func connect() {
        connectionViewModel.updateCredentials(serverURL: tempServerURL, authUUID: tempAuthUUID)
        dismiss()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            connectionViewModel.connect()
        }
    }
}