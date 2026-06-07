---
name: list
description: List the user's uploaded scratchtml plans and documents (links + expiry). Use when the user asks what plans/documents they have on scratchtml.
---

# List your scratchtml plans

1. Call `mcp__scratchtml__list_plans`.
2. Present the results as a compact table: title/filename · clickable link · expires.
3. Offer follow-ups: `/scratchtml:get <slug>` to pull comments on any of them, or `/scratchtml:share` to upload something new.

## Failure handling

If the call fails unauthenticated, tell the user to run `/mcp` and sign in to scratchtml, then retry.
