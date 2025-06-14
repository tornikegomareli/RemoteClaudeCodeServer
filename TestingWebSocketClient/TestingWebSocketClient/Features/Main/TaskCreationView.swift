//
//  TaskCreationView.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct TaskCreationView: View {
    @Environment(\.dismiss) private var dismiss
    let repository: Repository?
    let onSubmit: (String) -> Void
    
    @State private var taskDescription = ""
    @FocusState private var isTextEditorFocused: Bool
    @State private var selectedCommand: SlashCommand?
    @State private var showCommandPicker = false
    
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
                    
                    // Selected command badge
                    if let command = selectedCommand {
                        CommandBadge(command: command) {
                            selectedCommand = nil
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
            .sheet(isPresented: $showCommandPicker) {
                CommandPicker { command in
                    selectedCommand = command
                    showCommandPicker = false
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
                showCommandPicker = true
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
        if text.hasPrefix("/") {
            let command = String(text.dropFirst()).split(separator: " ").first.map(String.init) ?? ""
            if let slashCommand = SlashCommand.allCases.first(where: { $0.rawValue == command }) {
                selectedCommand = slashCommand
                taskDescription = String(text.dropFirst(command.count + 1)).trimmingCharacters(in: .whitespaces)
            }
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
    
    private func submitTask() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        var fullTask = taskDescription
        if let command = selectedCommand {
            fullTask = "/\(command.rawValue) " + fullTask
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

/// Slash command enum
enum SlashCommand: String, CaseIterable, Identifiable {
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

/// Command badge
struct CommandBadge: View {
    let command: SlashCommand
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.xSmall) {
            Image(systemName: command.icon)
            Text("/" + command.rawValue)
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

/// Command picker
struct CommandPicker: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (SlashCommand) -> Void
    
    var body: some View {
        NavigationView {
            List(SlashCommand.allCases) { command in
                Button(action: {
                    onSelect(command)
                }) {
                    HStack(spacing: AppTheme.Spacing.medium) {
                        Image(systemName: command.icon)
                            .font(.system(size: 22))
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                            Text("/" + command.rawValue)
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.label)
                            
                            Text(command.description)
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.secondaryLabel)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, AppTheme.Spacing.xxSmall)
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Slash Commands")
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

#Preview {
    TaskCreationView(repository: Repository.mockData.first) { task in
        print("New task: \(task)")
    }
}
