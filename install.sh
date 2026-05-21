#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. Install hooks via atomic CLI (if supported)
if command -v atomic &>/dev/null; then
  echo "Installing hooks..."
  atomic agent enable --agent kiro --global 2>/dev/null || {
    echo "  hooks: atomic agent hooks for kiro not yet supported — configure manually in Kiro IDE"
  }
else
  echo "Warning: 'atomic' not found on PATH. Install Atomic VCS first."
  echo "  Hooks will not be active until you run: atomic agent enable --agent kiro --global"
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

echo ""
echo "✓ Installed atomic-kiro"
echo "  Skills:   ~/.kiro/skills/"
echo "  Steering: ~/.kiro/steering/"
echo "  Hooks:    $SCRIPT_DIR/hooks/"
echo ""
echo "  Copy AGENTS.md into your project root for base Atomic context:"
echo "    cp $SCRIPT_DIR/AGENTS.md /path/to/your/project/"
echo ""
echo "  Configure hooks in Kiro IDE (Agent Steering & Skills panel):"
echo "    Prompt Submit  → Shell Command: $SCRIPT_DIR/hooks/prompt-submit.sh"
echo "    Agent Stop     → Shell Command: $SCRIPT_DIR/hooks/agent-stop.sh"
echo "    Pre Tool Use   → Shell Command: $SCRIPT_DIR/hooks/pre-tool-use.sh"
echo "    Post Tool Use  → Shell Command: $SCRIPT_DIR/hooks/post-tool-use.sh"
echo "    Post Task Exec → Shell Command: $SCRIPT_DIR/hooks/post-task-execution.sh"
