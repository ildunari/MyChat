#!/usr/bin/env bash
set -euo pipefail

# Qdrant MCP Server wrapper for project-scoped memory
# This script ensures Qdrant uses local storage specific to this project

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Set project-specific environment variables
export QDRANT_LOCAL_PATH="$PROJECT_DIR/.qdrant"
export COLLECTION_NAME="$(basename "$PROJECT_DIR")"
export EMBEDDING_MODEL="sentence-transformers/all-MiniLM-L6-v2"

# Debug output (commented out - uncomment for troubleshooting)
# >&2 echo "QDRANT_LOCAL_PATH=$QDRANT_LOCAL_PATH"
# >&2 echo "COLLECTION_NAME=$COLLECTION_NAME"

# Launch the Qdrant MCP server using uvx (stdio transport)
exec uvx mcp-server-qdrant