#!/bin/bash
# Hook: Prompt Submit
# Trigger: When the user submits a prompt in Kiro
# Action: Shell Command
#
# Setup in Kiro:
#   Trigger Type: Prompt Submit
#   Action: Shell Command
#   Command: /path/to/atomic-kiro/hooks/prompt-submit.sh
#
# Environment:
#   USER_PROMPT - The user's prompt text (provided by Kiro)

set -euo pipefail

# Ensure we're in an atomic repository
if [ ! -d ".atomic" ]; then
  exit 0
fi

# Ensure atomic is available
if ! command -v atomic &>/dev/null; then
  exit 0
fi

# Resolve a stable session ID for this Kiro window.
# We store it in .atomic/kiro_session so all hooks in the same
# workspace share the same session.
SESSION_FILE=".atomic/kiro_session"
if [ -f "$SESSION_FILE" ]; then
  SESSION_ID=$(cat "$SESSION_FILE")
else
  SESSION_ID="kiro-$(date +%Y%m%d-%H%M%S)"
  echo "$SESSION_ID" > "$SESSION_FILE"

  # First prompt in this session — create a draft view
  atomic view create "$SESSION_ID" --draft 2>/dev/null || true
  atomic view switch "$SESSION_ID" 2>/dev/null || true
fi

# Build JSON payload for the orchestrator
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CWD=$(pwd)
PROMPT="${USER_PROMPT:-}"

# Pipe JSON to stdin of the hooks command
printf '{"session_id":"%s","cwd":"%s","timestamp":"%s","prompt":"%s"}' \
  "$SESSION_ID" "$CWD" "$TIMESTAMP" "$PROMPT" \
  | atomic agent hooks kiro prompt-submit 2>/dev/null || true

# Output context for the agent (stdout goes back to Kiro)
echo "Atomic VCS session active. View: $(cat .atomic/current_view 2>/dev/null || echo 'unknown')"
