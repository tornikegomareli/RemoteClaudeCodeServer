//
//  LogsView.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct LogsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: LogEntry.LogCategory?
    @State private var searchText = ""
    
    private var logs: [LogEntry] {
        appState.webSocketManager.logs
    }
    
    private var filteredLogs: [LogEntry] {
        logs.filter { log in
            let matchesCategory = selectedCategory == nil || log.category == selectedCategory
            let matchesSearch = searchText.isEmpty || log.message.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }.reversed() // Show newest first
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category filter
                categoryFilter
                
                // Search bar
                searchBar
                
                // Logs list
                if filteredLogs.isEmpty {
                    emptyState
                } else {
                    logsList
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("System Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: clearLogs) {
                        Image(systemName: "trash")
                            .foregroundColor(AppTheme.Colors.error)
                    }
                    .disabled(logs.isEmpty)
                }
            }
        }
    }
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.small) {
                // All categories
                CategoryChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )
                
                // Individual categories
                ForEach(LogEntry.LogCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.vertical, AppTheme.Spacing.small)
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.Colors.secondaryLabel)
            
            TextField("Search logs", text: $searchText)
                .font(AppTheme.Typography.body)
        }
        .padding(AppTheme.Spacing.small)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.CornerRadius.small)
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.bottom, AppTheme.Spacing.small)
    }
    
    private var logsList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.small) {
                ForEach(filteredLogs) { log in
                    LogRow(log: log)
                        .padding(.horizontal, AppTheme.Spacing.medium)
                }
            }
            .padding(.vertical, AppTheme.Spacing.small)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Spacer()
            
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(AppTheme.Colors.tertiaryLabel)
            
            Text("No logs found")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.secondaryLabel)
            
            if !searchText.isEmpty || selectedCategory != nil {
                Text("Try adjusting your filters")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.tertiaryLabel)
            }
            
            Spacer()
        }
    }
    
    private func clearLogs() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        appState.webSocketManager.clearLogs()
    }
}

/// Category filter chip
struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.xxSmall) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(AppTheme.Typography.caption)
            }
            .foregroundColor(isSelected ? .white : AppTheme.Colors.label)
            .padding(.horizontal, AppTheme.Spacing.small)
            .padding(.vertical, AppTheme.Spacing.xxSmall)
            .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.secondaryBackground)
            .cornerRadius(AppTheme.CornerRadius.capsule)
        }
    }
}

/// Individual log row
struct LogRow: View {
    let log: LogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.small) {
                // Level icon
                Image(systemName: log.level.icon)
                    .foregroundColor(log.level.color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                    // Header
                    HStack {
                        Text(log.category.rawValue)
                            .font(AppTheme.Typography.caption2)
                            .foregroundColor(AppTheme.Colors.secondaryLabel)
                        
                        Spacer()
                        
                        Text(log.timestamp, style: .time)
                            .font(AppTheme.Typography.caption2)
                            .foregroundColor(AppTheme.Colors.tertiaryLabel)
                    }
                    
                    // Message
                    Text(log.message)
                        .font(AppTheme.Typography.callout)
                        .foregroundColor(AppTheme.Colors.label)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(AppTheme.Animation.quick) {
                    isExpanded.toggle()
                }
            }
        }
        .padding(AppTheme.Spacing.small)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

#Preview {
    LogsView()
        .environmentObject(AppState())
}