---
name: get
description: Retrieve inline review comments from a scratchtml document. Use when the user asks to get, fetch, or pull their comments/feedback from scratchtml.
---

# Get review comments from scratchtml

Fetch the inline comments left on an uploaded document and act on them.

## Steps

1. Resolve the slug:
   - `$ARGUMENTS` contains a slug or a `usercontent.scratchtml.link/<slug>` URL → use it.
   - No argument → use the most recently uploaded document in this conversation; if none, ask for the link.
2. Call `mcp__plugin_scratchtml_scratchtml__get_feedback` with the slug. Each thread carries a `reply to thread: <id>` line — keep those ids.
3. Present each comment **paired with the exact text it refers to** (quoted), so the user sees what each remark targets.
4. If the comments concern a document or file being worked on in this session, offer to incorporate them.
5. After incorporating a comment (or deciding not to), call `mcp__plugin_scratchtml_scratchtml__reply_to_feedback` with that thread id to tell the reviewer how it was handled (or why not). You can answer several threads in one call. This closes the loop so reviewers see their comments were acted on.

## Revision convention

When incorporating comments into a document, re-upload the revision (filename `<name>-revN.md`) with a top section titled **"## Changes from review"** — a table mapping each comment to its resolution — plus inline *(per review)* markers on edited passages. Relay the new link, then reply to each thread with `reply_to_feedback` (step 5 above).

## Failure handling

If the call fails unauthenticated, tell the user to run `/mcp` and sign in to scratchtml, then retry.

If the scratchtml tools aren't available at all (no such tool / the server isn't connected), the plugin's document server didn't start — Node.js ≥20 is almost certainly not installed. Tell the user to install Node ≥20 (`brew install node`, <https://nodejs.org>, or nvm) and restart Claude Code.
