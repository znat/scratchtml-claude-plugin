#!/bin/bash
# scratchtml plan-review GATE — PreToolUse hook on ExitPlanMode.
#
# Fires on EVERY ExitPlanMode regardless of permission mode (unlike
# PermissionRequest, which is silent when ExitPlanMode is auto-approved).
# Deny-or-DEFER, never force-allow: denying redirects Claude to upload the plan
# to scratchtml for review; deferring (emitting nothing) lets the normal
# permission flow proceed so PermissionRequest/approve-plan can still run.
#
# Per-PLAN (not per-session), via two bits of session state:
#   .uploaded  — touched by open-plan.sh after each upload_plan ("a plan was
#                uploaded since the last exit" = reviewed)
#   .denied    — set of plan-content hashes already denied this session (a retry
#                of a denied plan with no upload = the user chose to skip review)
#
#   .uploaded present            -> DEFER (reviewed); clear it, drop a .reviewed
#                                   breadcrumb for approve-plan.sh
#   plan hash already in .denied -> DEFER (skip)
#   otherwise                    -> DENY + record the hash
#
# $1 = plan_review (true/false)
# $2 = approve_mode (ask/auto) — selects the post-upload menu text
# $3 = ui_mockups (true/false) — backstop visual hints in the deny message
# $4 = diagrams (true/false)
#
# No jq: session_id via sed, plan hash + JSON via python3.
# Prompt text lives in ../prompts/ — edit there, not here.

[ "${1:-true}" = "true" ] || exit 0

PAYLOAD="$(cat)"
SESSION_ID="$(printf '%s' "$PAYLOAD" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
[ -n "$SESSION_ID" ] || exit 0

STATE_DIR="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/scratchtml-plugin}/plan-review-markers"
mkdir -p "$STATE_DIR"
find "$STATE_DIR" -type f -mtime +7 -delete 2>/dev/null

UPLOADED="$STATE_DIR/$SESSION_ID.uploaded"
DENIED="$STATE_DIR/$SESSION_ID.denied"
REVIEWED="$STATE_DIR/$SESSION_ID.reviewed"

# Reviewed path: an upload happened since the last exit -> let this through.
if [ -f "$UPLOADED" ]; then
  rm -f "$UPLOADED" "$DENIED"
  touch "$REVIEWED"   # breadcrumb for approve-plan.sh (auto mode)
  exit 0
fi

# Stable identity of THIS plan (hash of the ExitPlanMode plan body).
HASH="$(printf '%s' "$PAYLOAD" | python3 -c "
import sys, json, hashlib
try:
    d = json.load(sys.stdin)
    plan = (d.get('tool_input') or {}).get('plan', '') or ''
except Exception:
    plan = ''
print(hashlib.sha256(plan.encode('utf-8')).hexdigest()[:16])
")"

# Skip path: this exact plan was already denied and re-submitted with no upload.
if [ -n "$HASH" ] && grep -qxF "$HASH" "$DENIED" 2>/dev/null; then
  exit 0
fi

# Deny path: record the hash and redirect Claude into the review flow.
[ -n "$HASH" ] && printf '%s\n' "$HASH" >> "$DENIED"
rm -f "$REVIEWED"   # a fresh plan supersedes any stale breadcrumb

PROMPTS="${CLAUDE_PLUGIN_ROOT}/prompts"

if [ "${2:-ask}" = "auto" ]; then
  MENU="$(cat "${PROMPTS}/menu-auto.txt")"
else
  MENU="$(cat "${PROMPTS}/menu-ask.txt")"
fi

VISUAL_HINTS=""
[ "${3:-true}" = "true" ] && VISUAL_HINTS="${VISUAL_HINTS}$(cat "${PROMPTS}/hint-ui-mockups.txt")"
[ "${4:-true}" = "true" ] && VISUAL_HINTS="${VISUAL_HINTS}$(cat "${PROMPTS}/hint-diagrams.txt")"
VISUAL_HINTS="${VISUAL_HINTS}$(cat "${PROMPTS}/hint-callouts.txt")"

python3 -c "
import sys, json
t = open(sys.argv[1]).read().rstrip('\n')
reason = t.replace('{{VISUAL_HINTS}}', sys.argv[2]).replace('{{MENU}}', sys.argv[3])
out = {'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny', 'permissionDecisionReason': reason}}
print(json.dumps(out))
" "${PROMPTS}/reason.txt" "$VISUAL_HINTS" "$MENU"
exit 0
