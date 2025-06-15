use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SlashCommand {
    pub name: String,
    pub description: String,
    pub usage: Option<String>,
    pub example: Option<String>,
    pub content: Option<String>,  // Full content/prompt for .md commands
}

/// Scans a repository for custom slash commands in .claude/commands directory
pub fn scan_custom_commands(repo_path: &Path) -> Vec<SlashCommand> {
    let commands_dir = repo_path.join(".claude").join("commands");
    let mut commands = Vec::new();

    if !commands_dir.exists() || !commands_dir.is_dir() {
        return commands;
    }

    if let Ok(entries) = fs::read_dir(&commands_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            
            if path.is_file() {
                if let Some(extension) = path.extension() {
                    if extension == "md" {
                        // Parse Markdown format commands
                        if let Some(command) = parse_markdown_command(&path) {
                            commands.push(command);
                        }
                    }
                }
            }
        }
    }

    // Sort commands by name
    commands.sort_by(|a, b| a.name.cmp(&b.name));
    commands
}

/// Parses a markdown file as a slash command
fn parse_markdown_command(path: &Path) -> Option<SlashCommand> {
    // Get the filename without extension as the command name
    let file_stem = path.file_stem()?.to_str()?;
    
    // Read the file content as the command description/prompt
    let content = fs::read_to_string(path).ok()?;
    
    // Create the slash command name with "/" prefix
    let command_name = format!("/{}", file_stem.replace('_', "-"));
    
    // Use the first line as description if it's short, otherwise use a generic description
    let lines: Vec<&str> = content.lines().collect();
    let description = if !lines.is_empty() && lines[0].len() < 100 {
        lines[0].to_string()
    } else {
        format!("Custom command: {}", file_stem.replace('_', " "))
    };
    
    Some(SlashCommand {
        name: command_name,
        description,
        usage: None,
        example: None,
        content: Some(content),
    })
}

/// Predefined slash commands that are always available in Claude Code
pub fn get_predefined_commands() -> Vec<SlashCommand> {
    vec![
        SlashCommand {
            name: "/bug".to_string(),
            description: "Report bugs (sends conversation to Anthropic)".to_string(),
            usage: None,
            example: None,
            content: None,
        },
        SlashCommand {
            name: "/clear".to_string(),
            description: "Clear conversation history".to_string(),
            usage: None,
            example: None,
            content: None,
        },
        SlashCommand {
            name: "/compact".to_string(),
            description: "Compact conversation with optional focus instructions".to_string(),
            usage: Some("/compact [instructions]".to_string()),
            example: Some("/compact focus on the authentication logic".to_string()),
            content: None,
        },
        SlashCommand {
            name: "/config".to_string(),
            description: "View/modify configuration".to_string(),
            usage: None,
            example: None,
            content: None,
        },
        SlashCommand {
            name: "/cost".to_string(),
            description: "Show token usage statistics".to_string(),
            usage: None,
            example: None,
            content: None,
        },
        SlashCommand {
            name: "/doctor".to_string(),
            description: "Checks the health of your Claude Code installation".to_string(),
            usage: None,
            example: None,
            content: None,
        },
        SlashCommand {
            name: "/help".to_string(),
            description: "Get usage help".to_string(),
            usage: Some("/help [command]".to_string()),
            example: Some("/help model".to_string()),
            content: None,
        },
        SlashCommand {
            name: "/init".to_string(),
            description: "Initialize project with CLAUDE.md guide".to_string(),
            usage: None,
            example: None,
            content: None,
        },
        SlashCommand {
            name: "/login".to_string(),
            description: "Switch Anthropic accounts".to_string(),
            usage: None,
            example: None,
            content: None,
        },
        SlashCommand {
            name: "/logout".to_string(),
            description: "Sign out from your Anthropic account".to_string(),
            usage: None,
            example: None,
            content: None,
        },
        SlashCommand {
            name: "/memory".to_string(),
            description: "Edit CLAUDE.md memory files".to_string(),
            usage: None,
            example: None,
            content: None,
        },
        SlashCommand {
            name: "/model".to_string(),
            description: "Select or change the AI model".to_string(),
            usage: Some("/model [model-name]".to_string()),
            example: Some("/model claude-3-opus".to_string()),
            content: None,
        },
        SlashCommand {
            name: "/permissions".to_string(),
            description: "View or update permissions".to_string(),
            usage: None,
            example: None,
            content: None,
        },
        SlashCommand {
            name: "/pr_comments".to_string(),
            description: "View pull request comments".to_string(),
            usage: None,
            example: None,
            content: None,
        },
        SlashCommand {
            name: "/review".to_string(),
            description: "Request code review".to_string(),
            usage: None,
            example: None,
            content: None,
        },
        SlashCommand {
            name: "/status".to_string(),
            description: "View account and system statuses".to_string(),
            usage: None,
            example: None,
            content: None,
        },
    ]
}