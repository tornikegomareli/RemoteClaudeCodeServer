## CLI usage and controls

Learn how to use Claude Code from the command line, including CLI commands, flags, and slash commands.

### Getting started

Claude Code provides two main ways to interact:

*   **Interactive mode:** Run `claude` to start a REPL session.
*   **One-shot mode:** Use `claude -p "query"` for quick commands.

### CLI commands

| Command | Description | Example |
|---|---|---|
| `claude` | Start interactive REPL | `claude` |
| `claude "query"` | Start REPL with initial prompt | `claude "explain this project"` |
| `claude -p "query"` | Run one-off query, then exit | `claude -p "explain this project"` |
| `cat file | claude -p "query"` | Process piped content | `cat logs.txt | claude -p "analyze these errors"` |
| `claude -c` | Continue most recent conversation | `claude -c` |
| `claude -p` | Continue in print mode | `claude -p "query"` |
| `claude -"<session-id>"` | Resume session by ID | `claude -"<abc123>"` |


### CLI flags

Customize Claude Code's behavior with these command-line flags:

| Flag | Description | Example |
|---|---|---|
| `-allowedTools` | A list of tools that should be allowed without prompting the user for permission, in addition to settings.json files | `"Bash(git log:*)" "Bash(git diff:*)" "Write"` |
| `-disallowedTools` | A list of tools that should be disallowed without prompting the user for permission, in addition to settings.json files | `"Bash(git log:*)" "Bash(git diff:*)" "Write"` |
| `--print` | Print response without interactive mode (see SDK documentation) | `claude -p "query"` |
| `--output-format` | Specify output format for print mode (options: text, json, stream-json) | `claude -p "query" --output-format json` |
| `--verbose` | Enable verbose logging | `claude --verbose` |
| `-x-turns` | Limit the number of agentic turns in non-interactive mode | `claude -x-turns 3` |
| `-model` | Sets the model for the current session with an alias for the latest model | `claude -model claude-sonnet-4-20258514` |
| `-permission-prompt-tool` | Specify an MCP tool to handle permission prompts in non-interactive mode | `claude --permission-prompt-tool nop_auth tool` |
| `-continue` | Load the most recent conversation in the current directory | `claude --continue` |
| `-dangerously-skip-permissions` | Skip permission prompts (use with caution) | `claude --dangerously-skip-permissions` |


### Slash commands

Control Claude's behavior during an interactive session:

| Command | Purpose |
|---|---|
| `/bug` | Report bugs |
| `/clear` | Clear conversation history |
| `/compact [instructions]` | Compact conversation |
| `/config` | View/modify configuration |
| `/cost` | Show token usage statistics |
| `/doctor` | Checks the health of your Claude Code installation |
| `/help` | Get usage help |
| `/init` | Initialize project |
| `/Login` | Switch Anthropic accounts |
| `/Logout` | Sign out from your Anthropic account |
| `/memory` | Edit CLAUDE.md memory files |
| `/model` | Select or change the Al model |
| `/pr_comments` | View pull request comments |
| `/review` | Request code review |
| `/status` | View account and system statuses |
| `/terminal-setup` | Install Shift+Enter key binding |
| `/vin` | Enter vim mode |


### Special shortcuts

Quick memory with #: Add memories instantly by starting your input with #. Always use descriptive variable names.

### Line breaks in terminal

Enter multiline commands using:

*   Quick escape: Type `\` followed by Enter
*   Keyboard shortcut: Option+Enter (or Shift+Enter if configured)
