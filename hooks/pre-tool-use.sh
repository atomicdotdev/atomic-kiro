#!/bin/bash
# Hook: Pre Tool Use
# Trigger: Before the agent invokes a tool
# Action: Shell Command
#
# Setup in Kiro:
#   Trigger Type: Pre Tool Use
#   Tool Name: write, shell, read
#   Action: Shell Command
#   Command: /path/to/atomic-kiro/hooks/pre-tool-use.sh

set -euo pipefail

if [ ! -d ".atomic" ]; then
  exit 0
fi

if ! command -v atomic &>/dev/null; then
  exit 0
fi

SESSION_FILE=".atomic/kiro_session"
SESSION_ID=$(cat "$SESSION_FILE" 2>/dev/null || echo "kiro-unknown")

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CWD=$(pwd)
# Tool name passed as $1 from the hook command (e.g. "hooks/pre-tool-use.sh write")
TOOL_NAME="${1:-${TOOL_NAME:-}}"

printf '{"session_id":"%s","cwd":"%s","timestamp":"%s","tool_name":"%s"}' \
  "$SESSION_ID" "$CWD" "$TIMESTAMP" "$TOOL_NAME" \
  | atomic agent hooks kiro pre-tool-use 2>/dev/null || true
