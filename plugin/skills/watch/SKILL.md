---
name: watch
description: Watch a scratchtml document for new comments and engage live — answer questions, push revisions, or acknowledge — showing a "Claude is…" activity indicator to viewers. Use when the user wants Claude to stay on a shared document and respond to feedback in real time. Pairs with /loop for resilience.
---

# Watch a scratchtml document and engage with comments live

Stay on a shared scratchtml document and react to collaborators' comments as they
arrive: answer questions, push a revision from feedback, or just acknowledge —
while showing viewers a live "✦ Claude is …" indicator (like a collaborator
typing). The inbound trigger is a server **long-poll** (`wait_for_comments`), so
this is cheap while idle and instant when a comment lands — no tunnel, no daemon.

## Setup

1. Resolve the document:
   - `$ARGUMENTS` contains a slug or a `usercontent.scratchtml.link/<slug>` URL → use it.
   - No argument → use the most recently uploaded document in this conversation; if none, ask for the link.
2. Identify the **local file** this document was uploaded from (the plan/report/design on disk), if any — you'll need it to push revisions via `upload_document` with `revises:<slug>`.
3. Tell the user you're now watching `<slug>` and how it ends (any of: the doc expires/deletes, ~30 min with no new comments, or they stop you).

## Watch loop

Repeat until a **stop condition** (below) is met:

1. Call `mcp__plugin_scratchtml_scratchtml__wait_for_comments` with the document and the `cursor` from the previous call as `since` (omit `since` on the very first call — it establishes a baseline and returns no backlog). This blocks up to ~25s.
2. **No new comments** → loop again with the returned `cursor`. (Track consecutive empty returns for the idle timeout.)
3. **New comment(s)** → **immediately** `set_activity('thinking', { threadId, note: 'reading your comment on …' })` so viewers get instant, honest feedback that their comment was picked up (don't wait until you've finished deciding). Then, for each comment, decide and act (see *Decision policy*). Always:
   - **Keep the same `threadId` on every `set_activity` while handling one thread's comment** (`thinking` → `drafting` → `replying`), with a fresh `note` each step, so the indicator stays **inside that thread** the whole time and never jumps out to the doc-level top row. e.g. `set_activity('thinking', { threadId, note: 'reading your comment' })` → `set_activity('drafting', { threadId, note: 'revising the … section' })` → `set_activity('replying', { threadId, note: 'writing a reply about …' })`. Only omit `threadId` for genuinely doc-level work (one revision folding in several threads at once).
   - `set_activity('idle')` when finished with the batch.
   - Carry the returned `cursor` forward as `since` so you never see the same comment twice.

**On honesty:** only advertise a state that is actually happening — `thinking` the moment you pick up the comment, `replying`/`drafting` only while you're truly doing it. Never leave a `replying` indicator up when you're not writing.

### Narrate every step — always attach a `note`

Viewers should see your live running status the way they'd watch a collaborator's cursor, not just a bare verb. The `note` **is** the visible status: viewers see it rendered as **"Claude is {note}"**, so it can be richer and more specific than the three states — write it as a short **present-participle phrase** that reads after "is". So **every** `set_activity` call carries a short, honest `note` describing the *specific* micro-action you're on right now — and you **update the note as you move through the work** (each new sub-step is a fresh `set_activity` with the same or shifted state and a new note). The `state` still matters (it drives the indicator's color, dots, and clearing on `idle`), but the words come from the note. Map the actual thing you're doing to a state + note:

| What you're actually doing | `state` | `note` → shows as "Claude is …" |
| --- | --- | --- |
| Just picked up a comment | `thinking` | `reading your comment on auth` |
| Getting oriented in the code | `thinking` | `exploring the design system` |
| Looking something up to answer | `thinking` | `checking how the worker handles retries` |
| Weighing an approach | `thinking` | `considering two ways to scope this` |
| Preparing a revision | `drafting` | `revising the rate-limit section` |
| Writing the reply | `replying` | `writing a reply about the TTL` (scope to `threadId`) |

Rules for the note: a few words (it's clamped to ~120 chars), a **present-participle phrase** that reads after "is" (`exploring the design system`, not `Design system.`), **honest** (it must match what you're truly doing — never narrate a step you aren't on), and **specific** (name the topic/section, not "working…"). Omit the note only if you have nothing specific to say — then the fixed verb ("is thinking") shows as a fallback. A genuinely long single step (a big revision, a slow lookup) is also where the heartbeat lives: re-emit `set_activity` with a **refreshed** note (e.g. `still revising — wiring up the new endpoint`) roughly every ~20s so the indicator stays alive and the status keeps moving. Always finish the batch with `idle`.

**Heartbeat during long work:** the viewer's indicator self-clears after ~40s with no new activity (so a crashed agent doesn't leave a stuck label), and the UI shows a "this can take a moment — keep reviewing & commenting" reassurance after a few seconds. If a single step genuinely runs long (a big revision, a slow reply), **re-emit the current state with a refreshed `note`** (`set_activity` again with the same state/threadId and an updated status line) roughly every ~20s so the indicator stays alive and keeps moving — an honest heartbeat, not a fake one. Always finish with `idle`.

## Decision policy

You react to **every** new human comment, not only `@claude` mentions — `mentionsClaude` is a strong "definitely engage" signal, not a gate. For each comment, in thread context, choose:

- **Answer a question** → `set_activity('replying')`, then `reply_to_feedback` with the thread id and your answer.
- **Actionable change request** → `set_activity('drafting')`, edit the local file, `upload_document` with `revises:<slug>`, then `reply_to_feedback` noting the new revision and how you addressed it.
- **Minor / acknowledgement** ("looks good", "noted") → a short `reply_to_feedback` ("👍 folding that in").
- **Nothing useful to add** (chatter between others, already handled) → skip; don't reply for the sake of it.
- **Proceed / stop signal** — a comment (or a chat message) that clearly means *ship it / implement / go ahead / build it* **or** *stop watching / that's enough* is an **exit**, not a revision request. Acknowledge briefly, then **end the loop** (see *Stop conditions → User proceed/stop*). Don't treat "implement" as a change to fold into the document.

Use judgment and stay concise. Prefer a reply for clarifications; reserve revisions for clear, concrete change requests.

## UI mockups must match the project's design system

When a comment asks to *see* UI (a mockup, "how would it look", a layout), **never invent a look**. Before drafting any mockup:

1. **Find the design system.** Look for the project's tokens and components — e.g. a global stylesheet (`globals.css`, `:root` CSS variables / Tailwind theme), a design-system or UI-kit folder, and the **actual component** the change touches (read its real classes/markup). Reproduce the real tokens (colors, fonts, spacing, radii), the real class/component patterns, and the real layout — not approximations.
2. **Reuse, don't approximate.** Build the mockup from the same primitives the app uses (e.g. the real `.link-row`/`.chip` classes and `--token` values), so it reads as the product, not a generic card. Inline the real tokens/CSS into the standalone mockup so it renders faithfully.
3. **If you can't determine the design system, ask.** If there's no discoverable token source / component to match (or you're unsure which surface owns this UI), **stop and ask the user** where the design system lives or for a reference — do not guess.

This is a hard rule: a mockup in the wrong look-and-feel is worse than no mockup. (For scratchtml specifically: monospace UI, dark theme, tokens in `apps/web/app/globals.css`; match the real component, e.g. the dashboard `.link-row`.)

## Guardrails

- **No self-loop**: `wait_for_comments` already excludes your own (`agent`) replies, so you never react to yourself. Don't treat your own revision as a new event.
- **Idempotency**: act only on comments returned since the last `cursor`; never re-answer a thread you already handled this session.
- **Batch revisions**: if several comments arrive at once, fold them into **one** revision per loop tick rather than one revision per comment.
- **Activity hygiene**: always end a batch with `set_activity('idle')` so the indicator clears even if you decide to skip.

## Stop conditions (so a watch never outlives the document)

End the loop, tell the user why, and stop calling the tools when any of these happen:

1. **Document gone/expired** — `wait_for_comments` returns a "stop watching" / gone result (the doc hit its 24h TTL or was deleted). This is the normal end of a document's life.
2. **Idle timeout** — ~30 minutes (≈ many consecutive empty long-polls) with no new comments. Say: "Stopped watching `<slug>` after 30 min idle — run `/watch <url>` to resume." 
3. **User stop** — the user interrupts (Esc); stop immediately.
4. **User proceed/stop signal** — a clear *implement / ship it / build it* or *stop watching* message (from a doc comment or chat) ends the loop. End it cleanly:
   - **In plan mode** (you started watching right after uploading a plan, replacing the old Iterate/Implement menu): on *implement*, pull `get_feedback`, `reply_to_feedback` on each open thread telling the reviewer how their comment will be handled, then call `ExitPlanMode` and build — honoring the approval mode (`auto` ⇒ it's auto-approved; `ask` ⇒ the normal approval dialog appears). On *stop watching*, just stop and leave the plan as-is.
   - **Otherwise**, acknowledge and stop watching.
5. **Backstop** — if you've been watching for several hours, wind down and offer to resume.

For resilience you can run this under `/loop` (e.g. `/loop /watch <url>`): each `/loop` tick re-enters the watch, and the stop conditions above still apply.

## Revision convention

When a revision incorporates feedback, **edit the document in place** and **reply to the relevant thread** explaining what changed — the reply is the record. Do **not** add a "Changes from review" changelog section (at the top or bottom) and do not leave inline "(per review)" markers; the threaded reply already tells each reviewer how their comment was handled, so a separate changelog just duplicates it and clutters the document.

**Keep it Markdown, keep it visual.** Revisions stay **Markdown** (not a full HTML file) so each version diffs cleanly against the last — only the visual bits are inline HTML/SVG. As you revise, keep taking every opportunity to make the document visual: a ```mermaid diagram for any flow/architecture/sequence, a small inline HTML mockup for any UI (matching the design system — see above), and callouts for risks. If feedback adds a flow or a screen, add the diagram/mockup for it rather than only prose.

## Failure handling

If a scratchtml tool call fails unauthenticated, tell the user to run `/mcp` and sign in to scratchtml, then retry.

If the scratchtml tools aren't available at all (no such tool / server not connected), the plugin's document server didn't start — Node.js ≥20 is almost certainly missing. Tell the user to install Node ≥20 and restart Claude Code.
