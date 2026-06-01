#!/bin/bash
set -euo pipefail

if [ ! -d ".atomic" ]; then
  exit 0
fi

if ! command -v atomic &>/dev/null; then
  exit 0
fi

SESSION_FILE=".atomic/kiro_session"
SESSION_ID=$(cat "$SESSION_FILE" 2>/dev/null || echo "kiro-unknown")

# DEBUG: dump env vars to discover what Kiro passes
env | sort >> /tmp/kiro-post-tool-debug.txt 2>/dev/null || true
echo "---ARGS: $*---" >> /tmp/kiro-post-tool-debug.txt 2>/dev/null || true
echo "========" >> /tmp/kiro-post-tool-debug.txt 2>/dev/null || true

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CWD=$(pwd)
TOOL_NAME="${1:-${TOOL_NAME:-}}"

printf '{"session_id":"%s","cwd":"%s","timestamp":"%s","tool_name":"%s"}' \
  "$SESSION_ID" "$CWD" "$TIMESTAMP" "$TOOL_NAME" \
  | atomic agent hooks kiro post-tool-use 2>/dev/null || true
