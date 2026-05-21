#!/bin/bash
# Hook: Post Tool Use
# Trigger: After the agent has invoked a tool
# Action: Shell Command
#
# Setup in Kiro:
#   Trigger Type: Post Tool Use
#   Tool Name: write, shell
#   Action: Shell Command
#   Command: /path/to/atomic-kiro/hooks/post-tool-use.sh

set -euo pipefail

# Ensure we're in an atomic repository
if [ ! -d ".atomic" ]; then
  exit 0
fi

# Ensure atomic is available
if ! command -v atomic &>/dev/null; then
  exit 0
fi

# Read the session ID (created by prompt-submit.sh)
SESSION_FILE=".atomic/kiro_session"
if [ -f "$SESSION_FILE" ]; then
  SESSION_ID=$(cat "$SESSION_FILE")
else
  SESSION_ID="kiro-unknown"
fi

# Build JSON payload for the orchestrator
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CWD=$(pwd)

# Pipe JSON to stdin of the hooks command
printf '{"session_id":"%s","cwd":"%s","timestamp":"%s"}' \
  "$SESSION_ID" "$CWD" "$TIMESTAMP" \
  | atomic agent hooks kiro post-tool-use 2>/dev/null || true
