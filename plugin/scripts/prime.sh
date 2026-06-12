#!/bin/bash
# scratchtml author-time priming — UserPromptSubmit hook.
#
# When the session is in plan mode AND just transitioned into it (edge-detected
# by diffing the per-session last-seen permission_mode), inject house-style
# authoring hints (HTML mockups / mermaid diagrams / callouts) into context via
# additionalContext — so the plan is authored correctly the first time, BEFORE
# ExitPlanMode. Catches both manual (shift+tab) and tool-initiated plan mode,
# because UserPromptSubmit is the first event after either.
#
# $1 = plan_review (true/false) — whole-feature toggle
# $2 = ui_mockups (true/false)
# $3 = diagrams (true/false)
#
# No jq: fields parsed with sed, JSON emitted via python3 json.dumps.
# Prompt text lives in ../prompts/ — edit there, not here.

[ "${1:-true}" = "true" ] || exit 0

# python3 emits the JSON below; without it the hook can only no-op (exit 0).
command -v python3 >/dev/null 2>&1 || { echo "scratchtml: python3 not found on PATH — plan-review hooks need it (see plugin README)." >&2; exit 0; }

PAYLOAD="$(cat)"
SESSION_ID="$(printf '%s' "$PAYLOAD" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
[ -n "$SESSION_ID" ] || exit 0
MODE="$(printf '%s' "$PAYLOAD" | sed -n 's/.*"permission_mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"

STATE_DIR="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/scratchtml-plugin}/plan-review-markers"
mkdir -p "$STATE_DIR"
find "$STATE_DIR" -type f -mtime +7 -delete 2>/dev/null

MODEFILE="$STATE_DIR/$SESSION_ID.mode"
LAST="$(cat "$MODEFILE" 2>/dev/null)"
printf '%s' "$MODE" > "$MODEFILE"

# Only prime on the transition INTO plan mode (edge), not every plan-mode turn.
[ "$MODE" = "plan" ] || exit 0
[ "$LAST" != "plan" ] || exit 0

PROMPTS="${CLAUDE_PLUGIN_ROOT}/prompts"

VISUAL_HINTS=""
[ "${2:-true}" = "true" ] && VISUAL_HINTS="${VISUAL_HINTS}$(cat "${PROMPTS}/hint-ui-mockups.txt")"
[ "${3:-true}" = "true" ] && VISUAL_HINTS="${VISUAL_HINTS}$(cat "${PROMPTS}/hint-diagrams.txt")"
VISUAL_HINTS="${VISUAL_HINTS}$(cat "${PROMPTS}/hint-callouts.txt")"

python3 -c "
import sys, json
t = open(sys.argv[1]).read().rstrip('\n')
ctx = t.replace('{{VISUAL_HINTS}}', sys.argv[2])
out = {'hookSpecificOutput': {'hookEventName': 'UserPromptSubmit', 'additionalContext': ctx}}
print(json.dumps(out))
" "${PROMPTS}/prime.txt" "$VISUAL_HINTS"
exit 0
