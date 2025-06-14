//
//  RepositoryRow.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct RepositoryRow: View {
    let repository: Repository
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isSelected ? "folder.fill" : "folder")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(repository.name)
                        .font(.body)
                        .fontWeight(isSelected ? .medium : .regular)
                        .foregroundColor(isSelected ? .blue : .primary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(
                isSelected ? Color.blue.opacity(0.1) : Color.clear
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}