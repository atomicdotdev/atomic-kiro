#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"

# 1. Kiro hooks are written directly as project .kiro/hooks/*.kiro.hook files
#    (and .kiro/agents/atomic.json) below. Kiro has no global settings file to
#    merge into, so there is no `atomic agent enable` step. The hooks call
#    `atomic agent hooks kiro <verb>` at runtime, so `atomic` must be on PATH.
if ! command -v atomic &>/dev/null; then
  echo "Warning: 'atomic' not found on PATH. Install Atomic VCS so the hooks work at runtime."
fi

# 2. Symlink skills into ~/.kiro/skills/
SKILLS_TARGET="$HOME/.kiro/skills"
mkdir -p "$SKILLS_TARGET"

linked=0
skipped=0

for skill_dir in "$SCRIPT_DIR"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  name="$(basename "$skill_dir")"
  mkdir -p "$SKILLS_TARGET/$name"
  if [ -f "$skill_dir/SKILL.md" ]; then
    if [ -L "$SKILLS_TARGET/$name/SKILL.md" ] || [ -f "$SKILLS_TARGET/$name/SKILL.md" ]; then
      skipped=$((skipped + 1))
    else
      ln -sf "$skill_dir/SKILL.md" "$SKILLS_TARGET/$name/SKILL.md"
      linked=$((linked + 1))
    fi
  fi
done

echo "  skills: $linked linked, $skipped skipped → ~/.kiro/skills/"

# 3. Symlink steering files into ~/.kiro/steering/
STEERING_TARGET="$HOME/.kiro/steering"
mkdir -p "$STEERING_TARGET"

steering_linked=0
steering_skipped=0

for steering_file in "$SCRIPT_DIR"/steering/*.md; do
  [ -f "$steering_file" ] || continue
  name="$(basename "$steering_file")"
  if [ -L "$STEERING_TARGET/$name" ] || [ -f "$STEERING_TARGET/$name" ]; then
    steering_skipped=$((steering_skipped + 1))
  else
    ln -sf "$steering_file" "$STEERING_TARGET/$name"
    steering_linked=$((steering_linked + 1))
  fi
done

echo "  steering: $steering_linked linked, $steering_skipped skipped → ~/.kiro/steering/"

# 4. Make hook scripts executable
chmod +x "$SCRIPT_DIR"/hooks/*.sh 2>/dev/null || true

# 4. Write .kiro/hooks/ files into the current project directory
HOOKS_DIR="$(pwd)/.kiro/hooks"
mkdir -p "$HOOKS_DIR"

# 5. Write .kiro/agents/atomic.json for CLI usage
AGENTS_DIR="$(pwd)/.kiro/agents"
mkdir -p "$AGENTS_DIR"
cat > "$AGENTS_DIR/atomic.json" <<EOF
{
  "name": "atomic",
  "description": "Default agent with Atomic VCS provenance tracking",
  "prompt": "file://../../AGENTS.md",
  "resources": [
    "skill://$HOME/.kiro/skills/**/SKILL.md"
  ],
  "tools": ["*"],
  "allowedTools": ["read", "write", "shell"],
  "hooks": {
    "userPromptSubmit": [
      {
        "command": "$SCRIPT_DIR/hooks/prompt-submit.sh"
      }
    ],
    "preToolUse": [
      {
        "matcher": "*",
        "command": "$SCRIPT_DIR/hooks/cli-pre-tool-use.sh"
      }
    ],
    "postToolUse": [
      {
        "matcher": "*",
        "command": "$SCRIPT_DIR/hooks/cli-post-tool-use.sh"
      }
    ],
    "stop": [
      {
        "command": "$SCRIPT_DIR/hooks/agent-stop.sh"
      }
    ]
  }
}
EOF
echo "  agent: $AGENTS_DIR/atomic.json"

write_hook() {
  local file="$1" name="$2" when_type="$3" when_extra="$4" script="$5"
  cat > "$HOOKS_DIR/$file" <<EOF
{
  "version": "1.0.0",
  "enabled": true,
  "name": "$name",
  "when": {
    "type": "$when_type"$when_extra
  },
  "then": {
    "type": "runCommand",
    "command": "$SCRIPT_DIR/hooks/$script"
  }
}
EOF
}

TOOL_TYPES=',
    "toolTypes": ["write", "shell", "read"]'

write_hook "atomic-prompt-submit.kiro.hook"  "Atomic Turn Start"          "promptSubmit"      ""           "prompt-submit.sh"
write_hook "atomic-turn-stop.kiro.hook"      "Atomic Turn Stop"           "agentStop"         ""           "agent-stop.sh"
write_hook "atomic-pre-tool-use.kiro.hook"   "Atomic Pre Tool Use"        "preToolUse"        "$TOOL_TYPES" "pre-tool-use.sh"
write_hook "atomic-post-tool-use.kiro.hook"  "Atomic Post Tool Use"       "postToolUse"       "$TOOL_TYPES" "post-tool-use.sh"
write_hook "atomic-post-task.kiro.hook"      "Atomic Post Task Execution" "postTaskExecution" ""           "post-task-execution.sh"

echo "  hooks: 5 hook files → $HOOKS_DIR/"

cat <<EOF

───────────────────────────────────────────────────────────
✓ Installed atomic-kiro
───────────────────────────────────────────────────────────

What was installed:
  • Skills          ${linked} symlinked, ${skipped} left as-is
                    → ~/.kiro/skills/  (/atomic-vault, /atomic-vcs, /code-intelligence, ...)
  • Steering        ${steering_linked} symlinked, ${steering_skipped} left as-is
                    → ~/.kiro/steering/  (atomic-agent.md, always included)
  • Project hooks   5 written
                    → ${HOOKS_DIR}/  (*.kiro.hook — IDE turn/tool/task triggers)
  • Project agent   1 written
                    → ${AGENTS_DIR}/atomic.json  (drives the Kiro CLI session)

Symlinks point back into this checkout:
  ${SCRIPT_DIR}
Keep this directory in place; moving or deleting it breaks the skill/steering links.

Manual steps to finish:
  1. Copy the agent prompt to the project root (Kiro auto-discovers it):
       cp "${SCRIPT_DIR}/AGENTS.md" "${PROJECT_DIR}/"
  2. Ensure the project is an Atomic repo (one-time):
       cd "${PROJECT_DIR}" && atomic init
  3. Recording differs by environment (see AGENTS.md):
       • Kiro IDE — the .kiro/hooks/ triggers fire automatically; hooks record
         each turn with full AI provenance. You never run 'atomic add'/'record'.
       • Kiro CLI — .kiro/agents/atomic.json wires the same hook scripts so the
         agent signals turn start/end and the orchestrator records manually.

Verify:
  • Hooks (global): atomic agent status 2>/dev/null | grep kiro
  • Skills:         ls ~/.kiro/skills/
  • Steering:       ls ~/.kiro/steering/
  • Project hooks:  ls "${HOOKS_DIR}/"
  • Project agent:  cat "${AGENTS_DIR}/atomic.json"

Uninstall:
  ./install.sh is install-only; to remove run:
    node install.js --uninstall
───────────────────────────────────────────────────────────
EOF
