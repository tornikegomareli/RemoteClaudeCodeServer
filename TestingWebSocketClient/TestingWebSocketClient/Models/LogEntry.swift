//
//  LogEntry.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import Foundation
import SwiftUI

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let category: LogCategory
    
    enum LogLevel {
        case info
        case success
        case warning
        case error
        
        var color: Color {
            switch self {
            case .info: return AppTheme.Colors.secondaryLabel
            case .success: return AppTheme.Colors.success
            case .warning: return AppTheme.Colors.warning
            case .error: return AppTheme.Colors.error
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            }
        }
    }
    
    enum LogCategory: String, CaseIterable {
        case connection = "Connection"
        case authentication = "Authentication"
        case repository = "Repository"
        case general = "General"
        
        var icon: String {
            switch self {
            case .connection: return "wifi"
            case .authentication: return "lock"
            case .repository: return "folder"
            case .general: return "square.grid.2x2"
            }
        }
    }
}