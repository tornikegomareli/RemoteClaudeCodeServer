//
//  QRScannerView.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI
import CodeScanner

struct QRScannerView: View {
    let completion: (Result<ScanResult, ScanError>) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            CodeScannerView(
                codeTypes: [.qr],
                simulatedData: "a123f0a0-570e-44dd-9b12-79a2809cf60e",
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