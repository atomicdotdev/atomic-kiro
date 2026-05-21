#!/bin/bash
# Hook: Agent Stop
# Trigger: When the agent completes its turn
# Action: Shell Command
#
# Setup in Kiro:
#   Trigger Type: Agent Stop
#   Action: Shell Command
#   Command: /path/to/atomic-kiro/hooks/agent-stop.sh

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
  SESSION_ID="kiro-$(date +%Y%m%d-%H%M%S)"
fi

# Build JSON payload for the orchestrator
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CWD=$(pwd)

# Pipe JSON to stdin — the orchestrator handles add + record
printf '{"session_id":"%s","cwd":"%s","timestamp":"%s"}' \
  "$SESSION_ID" "$CWD" "$TIMESTAMP" \
  | atomic agent hooks kiro agent-stop 2>/dev/null

# Fallback: if the orchestrator isn't available or fails, do a basic record
if [ $? -ne 0 ]; then
  STATUS=$(atomic status --short 2>/dev/null || echo "")
  if [ -n "$STATUS" ]; then
    atomic add --all 2>/dev/null || true
    atomic record -m "kiro: auto-record from agent turn" 2>/dev/null || true
  fi
fi
