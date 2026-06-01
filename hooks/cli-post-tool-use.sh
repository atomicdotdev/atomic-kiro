#!/bin/bash
# CLI Hook: Post Tool Use
# Receives full JSON on stdin from Kiro CLI with tool_name, tool_input, tool_response
set -euo pipefail

if [ ! -d ".atomic" ]; then exit 0; fi
command -v atomic &>/dev/null || exit 0

SESSION_ID=$(cat .atomic/kiro_session 2>/dev/null || echo "kiro-unknown")

# Read the full JSON from stdin (Kiro CLI sends tool_name + tool_input + tool_response)
INPUT=$(cat)

# Inject session_id into the JSON and forward to orchestrator
echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
data['session_id'] = '$SESSION_ID'
json.dump(data, sys.stdout)
" | atomic agent hooks kiro post-tool-use 2>/dev/null || true
