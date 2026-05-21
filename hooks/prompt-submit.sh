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
# Stored in .atomic/kiro_session so all hooks share the same session.
# The orchestrator owns view creation — we just provide a stable session ID.
SESSION_FILE=".atomic/kiro_session"
if [ -f "$SESSION_FILE" ]; then
  SESSION_ID=$(cat "$SESSION_FILE")
else
  # Use hex timestamp so extract_session_short produces a unique 4-char tag
  # e.g. "a3f2b1c4-kiro" → tag "a3f2"
  HEX=$(printf '%08x' "$(date +%s)")
  SESSION_ID="${HEX}-kiro"
  echo "$SESSION_ID" > "$SESSION_FILE"
fi

# Build JSON payload for the orchestrator
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CWD=$(pwd)
PROMPT="${USER_PROMPT:-}"

# Pipe JSON to stdin — orchestrator handles view creation on first call
printf '{"session_id":"%s","cwd":"%s","timestamp":"%s","model":"kiro","prompt":"%s"}' \
  "$SESSION_ID" "$CWD" "$TIMESTAMP" "$PROMPT" \
  | atomic agent hooks kiro prompt-submit 2>/dev/null || true
