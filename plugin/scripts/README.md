# Plan-review hook state machine

The scratchtml plan-review gate is an *emergent* state machine spread across four
hook scripts that coordinate through breadcrumb files in a per-session state dir.
This is the highest-maintenance surface in the plugin — read this before editing
any of the scripts.

## State directory

```
${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/scratchtml-plugin}/plan-review-markers/
```

Files are per-session, keyed by `session_id`. Each script runs `find -mtime +7 -delete`
on entry to garbage-collect stale markers.

## Breadcrumb files (the contract)

| File                  | Written by                          | Read by                         | Meaning |
|-----------------------|-------------------------------------|---------------------------------|---------|
| `<session>.mode`      | `prime.sh` (every UserPromptSubmit) | `prime.sh` (next turn)          | Last-seen `permission_mode`, for edge-detecting the transition *into* plan mode. |
| `<session>.uploaded`  | `open-plan.sh` (after a share)      | `plan-review.sh`                | "A plan was uploaded since the last exit" = reviewed. Consumed (deleted) by the gate. |
| `<session>.denied`    | `plan-review.sh` (on a deny)        | `plan-review.sh`                | Set of plan-content hashes already denied this session. A re-submit of a denied hash with no upload = the user chose to skip review → defer. |
| `<session>.reviewed`  | `plan-review.sh` (on reviewed exit) | `approve-plan.sh`               | Breadcrumb that this exit went through review, so auto-mode may auto-approve. |

## The four hooks

```mermaid
sequenceDiagram
    participant U as UserPromptSubmit
    participant P as PreToolUse(ExitPlanMode)
    participant M as PostToolUse(share_document)
    participant R as PermissionRequest(ExitPlanMode)
    U->>U: prime.sh — edge-detect plan mode via .mode, inject authoring hints
    Note over P: plan-review.sh — the gate
    P->>P: .uploaded present? -> DEFER (reviewed); clear it, drop .reviewed
    P->>P: hash in .denied? -> DEFER (user skipped review)
    P->>P: else -> DENY + record hash, redirect Claude to upload
    M->>M: open-plan.sh — touch .uploaded, open browser, emit post-upload menu
    R->>R: approve-plan.sh — if .reviewed && approve_mode=auto -> setMode auto
```

### `prime.sh` — UserPromptSubmit
Edge-detects the transition *into* plan mode (diffing `.mode`) and injects the
house-style authoring hints (HTML mockups / mermaid / callouts) so the plan is
authored correctly the first time. No-ops on every other turn.

### `plan-review.sh` — PreToolUse on ExitPlanMode (the gate)
Deny-or-**defer**, never force-allow. Fires on *every* ExitPlanMode regardless of
permission mode. Denying redirects Claude to upload for review; deferring (emitting
nothing) lets the normal permission flow proceed so `approve-plan.sh` can still run.

### `open-plan.sh` — PostToolUse on share_document
Marks `.uploaded` (the bit the gate reads), opens the link locally if `auto_open`,
and emits the post-upload Iterate/Implement menu. This is the common path — most
plans are uploaded *before* any ExitPlanMode attempt, so the gate's deny+reason
never runs and this menu is what drives the loop.

### `approve-plan.sh` — PermissionRequest on ExitPlanMode
Auto-mode only. If a `.reviewed` breadcrumb is present, auto-approves the plan and
sets the session to auto mode. Plans that did NOT go through review get the built-in
dialog — a safety gate.

## Invariants / gotchas

- **Defer, don't allow.** `plan-review.sh` must never emit an `allow` decision —
  only `deny` or nothing — or it would bypass the built-in approval dialog.
- **Per-plan, not per-session.** The `.denied` hash set is what makes "skip review"
  work for one specific plan without disabling the gate for the rest of the session.
- **python3 required.** `prime.sh`, `plan-review.sh`, and `open-plan.sh` parse JSON
  and emit `hookSpecificOutput` via `python3`. Each guards on its presence and
  no-ops (exit 0) if it's missing, degrading to "no review" rather than erroring.
- **Tool-name coupling.** The PostToolUse matcher in `hooks/hooks.json` must match
  the deployed MCP tool name exactly (`mcp__plugin_scratchtml_scratchtml__share_document`).
  Renaming the server tool is a breaking change across the matcher, the prompts in
  `../prompts/`, and the skills in `../skills/` simultaneously.
