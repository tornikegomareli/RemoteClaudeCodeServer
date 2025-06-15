//
//  RepositorySelector.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct RepositorySelector: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @Binding var selectedRepository: Repository?
    @State private var searchText = ""
    @State private var isRefreshing = false
    
    private var repositories: [Repository] {
        appState.webSocketManager.repositories
    }
    
    private var filteredRepositories: [Repository] {
        if searchText.isEmpty {
            return repositories
        } else {
            return repositories.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) 
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: AppTheme.Spacing.small) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.Colors.secondaryLabel)
                    
                    TextField("Search repositories", text: $searchText)
                        .font(AppTheme.Typography.body)
                }
                .padding(AppTheme.Spacing.small)
                .background(AppTheme.Colors.secondaryBackground)
                .cornerRadius(AppTheme.CornerRadius.small)
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.vertical, AppTheme.Spacing.small)
                
                // Repository list
                if filteredRepositories.isEmpty {
                    emptyStateView
                } else {
                    List(filteredRepositories) { repository in
                        RepositoryRow(
                            repository: repository,
                            isSelected: selectedRepository?.id == repository.id
                        ) {
                            selectRepository(repository)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await refreshRepositories()
                    }
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Select Repository")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button(action: {
                            Task {
                                await refreshRepositories()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Spacer()
            
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(AppTheme.Colors.tertiaryLabel)
            
            Text("No repositories found")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.secondaryLabel)
            
            if !searchText.isEmpty {
                Text("Try adjusting your search")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.tertiaryLabel)
            }
            
            Spacer()
        }
    }
    
    private func selectRepository(_ repository: Repository) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        selectedRepository = repository
        
        // Send selection to server
        appState.webSocketManager.selectRepository(repository)
        
        // Success haptic and dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            dismiss()
        }
    }
    
    private func refreshRepositories() async {
        isRefreshing = true
        
        // Request repository list from server
        appState.webSocketManager.sendCommand("{\"type\": \"list_repos\"}")
        
        // Wait a bit for the response
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        isRefreshing = false
    }
}

/// Repository model
struct Repository: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let customCommands: [SlashCommand]
    
    enum CodingKeys: String, CodingKey {
        case name
        case path
        case customCommands = "custom_commands"
    }
    
    init(name: String, path: String, customCommands: [SlashCommand] = []) {
        self.name = name
        self.path = path
        self.customCommands = customCommands
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.path = try container.decode(String.self, forKey: .path)
        self.customCommands = try container.decodeIfPresent([SlashCommand].self, forKey: .customCommands) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
    }
    
    /// Mock data for previews
    static let mockData = [
        Repository(name: "RemoteClaudeCode", path: "/Users/dev/RemoteClaudeCode"),
        Repository(name: "SwiftUIComponents", path: "/Users/dev/SwiftUIComponents"),
        Repository(name: "MLKitDemo", path: "/Users/dev/Projects/MLKitDemo"),
        Repository(name: "WeatherApp", path: "/Users/dev/iOS/WeatherApp"),
        Repository(name: "TaskManager", path: "/Users/dev/Projects/TaskManager")
    ]
}

#Preview {
    RepositorySelector(selectedRepository: .constant(nil))
        .environmentObject(AppState())
}
