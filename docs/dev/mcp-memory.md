# MCP Memory with Qdrant

This repository uses Qdrant MCP server for project-scoped vector memory, enabling Claude Code and Codex CLI to store and retrieve contextual information specific to this project.

## Architecture

The system uses:
- **Qdrant**: Local vector database for embeddings storage
- **MCP Server**: Protocol bridge between AI tools and Qdrant
- **Project Isolation**: Each project has its own `.qdrant` directory and collection

## Components

### 1. Local Storage
- **Location**: `.qdrant/` directory in repository root
- **Collection Name**: Automatically set to repository name (NoteChat)
- **Embedding Model**: `sentence-transformers/all-MiniLM-L6-v2`

### 2. Wrapper Script
- **Path**: `.scripts/mcp/qdrant_project.sh`
- **Purpose**: Sets project-specific environment variables
- **Execution**: Uses `uvx` to run Python packages without virtual environments

### 3. MCP Integration

#### Claude Code
- **Server Name**: `qdrant-NoteChat`
- **Configuration**: Stored in `~/.claude.json` (project scope)
- **Available Tools**:
  - `qdrant-store`: Store information with metadata
  - `qdrant-find`: Query stored information by similarity

#### Codex CLI
- **Server Name**: `qdrant_project`
- **Configuration**: Global in `~/.codex/config.toml`
- **Access**: Via `cxe` command from any directory

## Usage

### Claude Code
```
# Store information
Use the qdrant-store tool to save "The main chat view uses SwiftData for persistence"

# Retrieve information
Use the qdrant-find tool to search for "database implementation"
```

### Codex CLI (via cxe)
```bash
# Launch Codex with project memory
cxe

# In Codex, use MCP tools:
# Store: @qdrant-store "API keys are stored in keychain"
# Find: @qdrant-find "security implementation"
```

## Adding to New Projects

### Step 1: Copy Infrastructure
```bash
# From target repository root
mkdir -p .qdrant .scripts/mcp

# Copy wrapper script
cp /Users/kosta/Documents/ProjectsXcode/NoteChat/.scripts/mcp/qdrant_project.sh \
   .scripts/mcp/qdrant_project.sh

# Make executable
chmod +x .scripts/mcp/qdrant_project.sh
```

### Step 2: Configure Codex (if not using global config)
Add to project's Codex config or create project-specific server:
```toml
[mcp_servers.qdrant_project_YOURPROJECT]
command = "/path/to/your/project/.scripts/mcp/qdrant_project.sh"
args = []
env = {}
```

### Step 3: Register in Claude Code
```bash
# From project root
claude mcp add qdrant-$(basename "$PWD") \
  -e QDRANT_LOCAL_PATH="$PWD/.qdrant" \
  -e COLLECTION_NAME="$(basename "$PWD")" \
  -e EMBEDDING_MODEL="sentence-transformers/all-MiniLM-L6-v2" \
  -- uvx mcp-server-qdrant
```

### Step 4: Create Project-Specific Shell Function (Optional)
Add to `~/.zshrc`:
```bash
your_project_cxe() {
    cd /path/to/your/project || return 1
    mkdir -p .qdrant
    if declare -f cx > /dev/null; then
        cx "$@"
    else
        codex "$@"
    fi
}
```

## Migrating to Qdrant Cloud

To switch from local storage to Qdrant Cloud:

### 1. Update Wrapper Script
Edit `.scripts/mcp/qdrant_project.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Qdrant Cloud configuration
export QDRANT_URL="https://your-cluster.qdrant.cloud"
export QDRANT_API_KEY="your-api-key"
export COLLECTION_NAME="$(basename "$PWD")"
export EMBEDDING_MODEL="sentence-transformers/all-MiniLM-L6-v2"

# Remove or comment out local path
# export QDRANT_LOCAL_PATH="$PWD/.qdrant"

exec uvx mcp-server-qdrant
```

### 2. Update Claude Code Registration
```bash
claude mcp remove qdrant-NoteChat
claude mcp add qdrant-NoteChat \
  -e QDRANT_URL="https://your-cluster.qdrant.cloud" \
  -e QDRANT_API_KEY="your-api-key" \
  -e COLLECTION_NAME="$(basename "$PWD")" \
  -e EMBEDDING_MODEL="sentence-transformers/all-MiniLM-L6-v2" \
  -- uvx mcp-server-qdrant
```

## Troubleshooting

### MCP Server Not Found
```bash
# Verify server is registered
claude mcp list | grep qdrant

# For Codex, check config
grep -A3 qdrant_project ~/.codex/config.toml
```

### Permission Denied
```bash
# Ensure wrapper script is executable
chmod +x .scripts/mcp/qdrant_project.sh
```

### Collection Issues
- Collections are automatically created on first store operation
- Collection name matches directory name by default
- Use consistent collection names across Claude Code and Codex

### uvx Not Found
```bash
# Install uv (Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Security Notes

- API keys for cloud usage should be stored in environment variables
- Never commit `.qdrant/` directory (already in .gitignore)
- Cloud API keys should use secure storage (keychain, 1Password CLI, etc.)

## References

- [Qdrant MCP Server](https://github.com/qdrant/mcp-server-qdrant)
- [Claude Code MCP Docs](https://docs.claude.com/en/docs/claude-code/mcp)
- [Codex CLI](https://github.com/openai/codex)
- [uv Documentation](https://docs.astral.sh/uv/)