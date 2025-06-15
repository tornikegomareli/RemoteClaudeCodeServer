//
//  TaskCreationView.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct TaskCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    let repository: Repository?
    let onSubmit: (String) -> Void
    
    @State private var taskDescription = ""
    @FocusState private var isTextEditorFocused: Bool
    @State private var selectedPrompt: QuickPrompt?
    @State private var showPromptPicker = false
    @State private var showSlashCommands = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Repository indicator
                if let repo = repository {
                    HStack(spacing: AppTheme.Spacing.xSmall) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                        Text(repo.name)
                            .font(AppTheme.Typography.callout)
                            .foregroundColor(AppTheme.Colors.label)
                        Spacer()
                    }
                    .padding(AppTheme.Spacing.medium)
                    .background(AppTheme.Colors.primary.opacity(0.1))
                }
                
                // Task input
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    Text("What would you like Claude to do?")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.label)
                        .padding(.horizontal, AppTheme.Spacing.medium)
                        .padding(.top, AppTheme.Spacing.medium)
                    
                    TextEditor(text: $taskDescription)
                        .font(AppTheme.Typography.body)
                        .padding(AppTheme.Spacing.small)
                        .scrollContentBackground(.hidden)
                        .background(AppTheme.Colors.secondaryBackground)
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .frame(minHeight: 150)
                        .padding(.horizontal, AppTheme.Spacing.medium)
                        .focused($isTextEditorFocused)
                        .onChange(of: taskDescription) { _, newValue in
                            checkForSlashCommand(newValue)
                        }
                    
                    // Selected prompt badge
                    if let prompt = selectedPrompt {
                        PromptBadge(prompt: prompt) {
                            selectedPrompt = nil
                        }
                        .padding(.horizontal, AppTheme.Spacing.medium)
                    }
                    
                    // Quick actions
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.Spacing.small) {
                            ForEach(QuickAction.allCases) { action in
                                QuickActionChip(action: action) {
                                    insertQuickAction(action)
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.medium)
                    }
                    .padding(.vertical, AppTheme.Spacing.small)
                }
                
                Spacer()
                
                // Keyboard toolbar
                if isTextEditorFocused {
                    keyboardToolbar
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        submitTask()
                    }
                    .disabled(taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showPromptPicker) {
                PromptPicker { prompt in
                    selectedPrompt = prompt
                    showPromptPicker = false
                }
            }
            .sheet(isPresented: $showSlashCommands) {
                SlashCommandsView(availableCommands: appState.webSocketManager.availableCommands) { command in
                    insertSlashCommand(command)
                    showSlashCommands = false
                }
            }
            .onAppear {
                isTextEditorFocused = true
            }
        }
    }
    
    private var keyboardToolbar: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Button(action: {
                showSlashCommands = true
            }) {
                Label("Commands", systemImage: "slash.circle")
                    .font(AppTheme.Typography.callout)
            }
            
            Spacer()
            
            Button("Done") {
                isTextEditorFocused = false
            }
            .font(AppTheme.Typography.callout)
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, AppTheme.Spacing.small)
        .background(AppTheme.Colors.secondaryBackground)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(AppTheme.Colors.separator),
            alignment: .top
        )
    }
    
    private func checkForSlashCommand(_ text: String) {
        if text.hasPrefix("/") && showSlashCommands == false {
            // Show slash commands picker when user types "/"
            showSlashCommands = true
        }
    }
    
    private func insertQuickAction(_ action: QuickAction) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        if !taskDescription.isEmpty && !taskDescription.hasSuffix(" ") {
            taskDescription += " "
        }
        taskDescription += action.text
    }
    
    private func insertSlashCommand(_ command: SlashCommand) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        // Replace text up to current position with the command
        if taskDescription.hasPrefix("/") {
            taskDescription = command.name + " "
        } else {
            taskDescription = command.name + " " + taskDescription
        }
    }
    
    private func submitTask() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        var fullTask = taskDescription
        if let prompt = selectedPrompt {
            fullTask = prompt.description + ": " + fullTask
        }
        
        onSubmit(fullTask)
        dismiss()
    }
}

/// Quick action enum
enum QuickAction: String, CaseIterable, Identifiable {
    case fix = "Fix"
    case refactor = "Refactor"
    case test = "Add tests"
    case document = "Document"
    case optimize = "Optimize"
    
    var id: String { rawValue }
    
    var text: String {
        switch self {
        case .fix: return "fix the"
        case .refactor: return "refactor"
        case .test: return "add tests for"
        case .document: return "add documentation to"
        case .optimize: return "optimize"
        }
    }
    
    var icon: String {
        switch self {
        case .fix: return "wrench"
        case .refactor: return "arrow.triangle.2.circlepath"
        case .test: return "checkmark.shield"
        case .document: return "doc.text"
        case .optimize: return "bolt"
        }
    }
}

/// Quick action chip
struct QuickActionChip: View {
    let action: QuickAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Label(action.rawValue, systemImage: action.icon)
                .font(AppTheme.Typography.callout)
                .foregroundColor(AppTheme.Colors.primary)
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.vertical, AppTheme.Spacing.small)
                .background(AppTheme.Colors.primary.opacity(0.1))
                .cornerRadius(AppTheme.CornerRadius.capsule)
        }
    }
}

/// Quick prompt enum
enum QuickPrompt: String, CaseIterable, Identifiable {
    case explain = "explain"
    case fix = "fix"
    case test = "test"
    case refactor = "refactor"
    case review = "review"
    case document = "document"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .explain: return "Explain how this code works"
        case .fix: return "Fix issues in the code"
        case .test: return "Write tests for the code"
        case .refactor: return "Refactor and improve code quality"
        case .review: return "Review code for best practices"
        case .document: return "Add documentation and comments"
        }
    }
    
    var icon: String {
        switch self {
        case .explain: return "questionmark.circle"
        case .fix: return "wrench"
        case .test: return "checkmark.shield"
        case .refactor: return "arrow.triangle.2.circlepath"
        case .review: return "eye"
        case .document: return "doc.text"
        }
    }
}

/// Prompt badge
struct PromptBadge: View {
    let prompt: QuickPrompt
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.xSmall) {
            Image(systemName: prompt.icon)
            Text(prompt.rawValue.capitalized)
                .font(AppTheme.Typography.callout)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppTheme.Colors.secondaryLabel)
            }
        }
        .foregroundColor(AppTheme.Colors.primary)
        .padding(.horizontal, AppTheme.Spacing.small)
        .padding(.vertical, AppTheme.Spacing.xxSmall)
        .background(AppTheme.Colors.primary.opacity(0.1))
        .cornerRadius(AppTheme.CornerRadius.capsule)
    }
}

/// Prompt picker
struct PromptPicker: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (QuickPrompt) -> Void
    
    var body: some View {
        NavigationView {
            List(QuickPrompt.allCases) { prompt in
                Button(action: {
                    onSelect(prompt)
                }) {
                    HStack(spacing: AppTheme.Spacing.medium) {
                        Image(systemName: prompt.icon)
                            .font(.system(size: 22))
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                            Text(prompt.rawValue.capitalized)
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.label)
                            
                            Text(prompt.description)
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.secondaryLabel)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, AppTheme.Spacing.xxSmall)
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Quick Prompts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Slash commands view
struct SlashCommandsView: View {
    @Environment(\.dismiss) private var dismiss
    let availableCommands: [SlashCommand]
    let onSelect: (SlashCommand) -> Void
    
    var body: some View {
        NavigationView {
            if availableCommands.isEmpty {
                VStack(spacing: AppTheme.Spacing.large) {
                    Image(systemName: "slash.circle")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(AppTheme.Colors.tertiaryLabel)
                    
                    Text("No commands available")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.secondaryLabel)
                    
                    Text("Select a repository to see available commands")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.tertiaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.Colors.background)
            } else {
                List(availableCommands) { command in
                    Button(action: {
                        onSelect(command)
                    }) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                            Text(command.name)
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.label)
                            
                            Text(command.description)
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.secondaryLabel)
                            
                            if let usage = command.usage {
                                Text("Usage: \(usage)")
                                    .font(AppTheme.Typography.caption2)
                                    .foregroundColor(AppTheme.Colors.tertiaryLabel)
                            }
                        }
                        .padding(.vertical, AppTheme.Spacing.xxSmall)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Slash Commands")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    TaskCreationView(repository: Repository.mockData.first) { task in
        print("New task: \(task)")
    }
    .environmentObject(AppState())
}
