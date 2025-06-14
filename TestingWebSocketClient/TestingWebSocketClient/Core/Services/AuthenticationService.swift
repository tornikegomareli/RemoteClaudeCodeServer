//
//  AuthenticationService.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import Foundation

class AuthenticationService: ObservableObject {
    @Published var authUUID = UserDefaults.standard.string(forKey: "authUUID") ?? ""
    @Published var reconnectionToken = UserDefaults.standard.string(forKey: "reconnectionToken") ?? ""
    @Published var clientId = UserDefaults.standard.string(forKey: "clientId") ?? ""
    @Published var serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
    
    func saveCredentials() {
        UserDefaults.standard.set(serverURL, forKey: "serverURL")
        UserDefaults.standard.set(authUUID, forKey: "authUUID")
        UserDefaults.standard.set(reconnectionToken, forKey: "reconnectionToken")
        UserDefaults.standard.set(clientId, forKey: "clientId")
    }
    
    func clearCredentials() {
        reconnectionToken = ""
        clientId = ""
        authUUID = ""
        serverURL = ""
        saveCredentials()
    }
    
    func hasStoredCredentials() -> Bool {
        return !serverURL.isEmpty && (!reconnectionToken.isEmpty || !authUUID.isEmpty)
    }
    
    func shouldUseReconnectionToken() -> Bool {
        return !reconnectionToken.isEmpty && !clientId.isEmpty
    }
    
    func createAuthMessage() -> String? {
        if shouldUseReconnectionToken() {
            let tokenData = ["token": reconnectionToken]
            guard let jsonData = try? JSONSerialization.data(withJSONObject: tokenData),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return nil
            }
            return jsonString
        } else if !authUUID.isEmpty {
            return authUUID
        }
        return nil
    }
    
    func handleAuthResponse(_ json: [String: Any]) {
        if let status = json["status"] as? String, status == "AUTH_SUCCESS" {
            if let token = json["reconnection_token"] as? String {
                reconnectionToken = token
            }
            if let id = json["client_id"] as? String {
                clientId = id
            }
            saveCredentials()
        }
    }
    
    func parseQRCode(_ qrData: String) -> (uuid: String?, url: String?) {
        if let data = qrData.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let uuid = json["uuid"] as? String
            let url = json["url"] as? String
            return (uuid, url)
        } else {
            // Fallback: treat as plain UUID
            return (qrData, nil)
        }
    }
}