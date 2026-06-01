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
#
# If KIRO_SESSION_ID is set (by Kiro CLI), use it to detect new sessions.
# A new KIRO_SESSION_ID means a new kiro chat session → new atomic session.
SESSION_FILE=".atomic/kiro_session"
KIRO_SID="${KIRO_SESSION_ID:-}"

if [ -n "$KIRO_SID" ] && [ -f "$SESSION_FILE" ]; then
  STORED_KIRO_SID=$(grep "^KIRO_SID=" "$SESSION_FILE" 2>/dev/null | cut -d= -f2 || true)
  if [ "$KIRO_SID" != "$STORED_KIRO_SID" ]; then
    # New kiro chat session — create a new atomic session
    rm -f "$SESSION_FILE"
  fi
fi

if [ -f "$SESSION_FILE" ]; then
  SESSION_ID=$(head -1 "$SESSION_FILE")
else
  # Use hex timestamp so extract_session_short produces a unique 4-char tag
  HEX=$(printf '%08x' "$(date +%s)")
  SESSION_ID="${HEX}-kiro"
  echo "$SESSION_ID" > "$SESSION_FILE"
  # Store the kiro CLI session ID for comparison on next invocation
  if [ -n "$KIRO_SID" ]; then
    echo "KIRO_SID=$KIRO_SID" >> "$SESSION_FILE"
  fi
fi

# Build JSON payload for the orchestrator
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CWD=$(pwd)
PROMPT="${USER_PROMPT:-}"

# Pipe JSON to stdin — orchestrator handles view creation on first call
printf '{"session_id":"%s","cwd":"%s","timestamp":"%s","model":"kiro","prompt":"%s"}' \
  "$SESSION_ID" "$CWD" "$TIMESTAMP" "$PROMPT" \
  | atomic agent hooks kiro prompt-submit 2>/dev/null || true
