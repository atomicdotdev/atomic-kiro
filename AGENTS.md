# Atomic VCS Agent

You use **Atomic VCS** (not git).

## Environment detection

Check once at session start:

```bash
atomic agent status 2>/dev/null | grep -q "kiro.*hooks installed" && echo "IDE" || echo "CLI"
```

- **IDE (hooks active):** Views and recording are automatic. Skip steps marked `[CLI only]`.
- **CLI:** You must manage views and recording manually. Follow all steps.

## Session model

```
1 session == 1 view → many intents && many turns (atomic record with provenance)
```

A session view is created once at the start of the session and reused for every turn. Each turn creates one intent and one `atomic record`. The view is only inserted back to the parent when the session is fully complete.

## Session start `[CLI only]`

Run this once at the beginning of a new session. Skip if `.atomic/kiro_session` already exists from a previous turn.

```bash
HEX=$(printf '%08x' "$(date +%s)")
SESSION_ID="${HEX}-kiro"
echo "$SESSION_ID" > .atomic/kiro_session
```

The orchestrator creates and switches to a haikunator-named draft view automatically when the first `prompt-submit` fires.

To resume an existing session:

```bash
# .atomic/kiro_session already has the session ID — just continue
cat .atomic/kiro_session
```

## Every prompt is a turn. Every turn follows this sequence.

### 1. Signal turn start `[CLI only]`

```bash
SESSION_ID=$(cat .atomic/kiro_session)
printf '{"session_id":"%s","cwd":"%s","model":"kiro","prompt":"%s"}' \
  "$SESSION_ID" "$(pwd)" "<user prompt summary>" \
  | atomic agent hooks kiro prompt-submit
```

### 2. Create an intent

```bash
atomic vault intent create --title "<short title>"
```

### 3. Define the problem

The user's prompt is usually a **solution** ("build me X"). Reframe it as a **problem statement**.

Ask clarifying questions if the problem is ambiguous. Do not guess — ask.

Once the problem is clear, define:

- **Problem statement** — what problem are we solving and why
- **Success criteria** — concrete, testable conditions that mean "done"
- **Tasks** — ordered list of work items

Write all of this into the intent file. Replace every REPLACE placeholder.

### 3. Execute the tasks

Work through the tasks. Check off tasks as you complete them.

### 4. Update the intent

```bash
atomic vault intent update <ID> --status done
```

### 5. Signal turn end — records with full provenance `[CLI only]`

```bash
SESSION_ID=$(cat .atomic/kiro_session)
printf '{"session_id":"%s","cwd":"%s"}' "$SESSION_ID" "$(pwd)" \
  | atomic agent hooks kiro agent-stop
```

This triggers the orchestrator to run `atomic add -A` and `atomic record` with the full causal decision graph (tool uses, goals, patch proposal) and session envelope. In the IDE this fires automatically via the AgentStop hook.

## Session end `[CLI only]`

Only when the session is fully complete, insert back to the parent view:

```bash
VIEW=$(atomic agent status --json 2>/dev/null | python3 -c "import sys,json; s=json.load(sys.stdin); print(s['sessions'][0]['view_name'])" 2>/dev/null || atomic view list | grep "^\*" | awk '{print $2}')
atomic insert from-view "$VIEW" --to-view dev
atomic view switch dev
rm .atomic/kiro_session
```

## Learning from Redirects

When a user cancels, corrects, or redirects your approach, immediately write a vault memory:

```bash
echo "<what was tried> -> <why it was wrong> -> <what to do instead>" \
  | atomic vault memory write "redirect/<slug>" --type feedback
```

Do this **before** continuing with the corrected approach. At the start of each session, scan `atomic vault memory list` for `redirect/` entries and apply them proactively.

## Rules

- **One intent per turn.** Every prompt gets its own intent.
- **One view per session.** Create the view once at session start; reuse it for every turn.
- **Problem first.** Reframe solution-requests as problems. Ask questions if unclear.
- **Write the intent file before coding.** The plan goes in the file, not just in chat.
- **Use Atomic for code discovery.** Before using grep, find, or similar filesystem search tools, first try the Atomic knowledge graph and content index:
  - Source text: `atomic vault query code "pattern" -t <type>`
  - Structure: `atomic vault query search "term"`
  - Relationships: `atomic vault query neighbors <node_id>`
  - File outline: `atomic vault query entities <path>`
- **Only fall back to grep/find if Atomic query commands fail**, the repository has no content index/KG yet, or you need to inspect files that are not tracked/indexed by Atomic. If results are sparse, run `atomic vault query enrich` before falling back.
- **In the IDE:** Do not run `atomic add`, `atomic record`, or manage views — hooks handle everything.
- **In the CLI:** Always create a draft view at session start, signal turn start/end via `atomic agent hooks kiro`, and insert back to the parent view only when the session is done.
- **Do not run `atomic agent enable`.** The integration is already configured globally.

## Skills

Use these for detailed reference when needed:

- `/atomic-vault` — intent and goal lifecycle, memory operations
- `/code-intelligence` — knowledge graph queries for code exploration
