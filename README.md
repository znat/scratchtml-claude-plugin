# scratchtml for Claude Code

A Claude Code plugin for [scratchtml.link](https://scratchtml.link) — review, share and discuss Claude Code plans on ephemeral (24h), sandboxed, commentable links.

## What it does

When you enter plan mode, this plugin shapes the plan as it's authored (HTML mockups, mermaid diagrams, callouts), then routes it through a review loop instead of letting it go straight to approval — for **every** plan, in any permission mode:

```
enter plan mode ──▶ Claude is primed to author HTML mockups / diagrams / callouts
                          │
                          ▼
plan finished ──▶ uploaded to scratchtml ──▶ link opens in your browser
                                                   │
                you leave inline comments ◀────────┘
                          │
              ┌───────────┴───────────┐
        "Iterate"                 "Implement"
   pull comments ──▶ revise   pull comments ──▶ apply
   ──▶ re-upload rev with a   them while building
   "Changes from review"               │
   table ──▶ loop                       ▼
                          approval (built-in dialog, or automatic — see approve_mode)
```

Both menu choices pull your comments — **Iterate** folds them into a plan revision, **Implement** applies them as Claude writes the code. Iterating re-uploads as a new **version** of the *same link* (your comments carry forward and you can diff against the prior version), so you can keep one tab open across rounds.

Plus three commands, usable anytime:

| Command | What it does |
|---|---|
| `/scratchtml:share [path]` | Upload any markdown/document → shareable, commentable 24h link |
| `/scratchtml:get [slug-or-url]` | Pull inline comments, each paired with the text it refers to |
| `/scratchtml:list` | List your uploaded plans (links + expiry) |

## Install

```
/plugin marketplace add znat/scratchtml-claude-plugin
/plugin install scratchtml@scratchtml
/mcp          ← then authenticate "scratchtml" (browser sign-in)
```

Do the `/mcp` sign-in right away — it's what lets the first upload succeed.

## Configuration

All options are prompted at install and editable later via `/plugin`:

| Option | Default | Effect |
|---|---|---|
| `plan_review` | `true` | Prime plan authoring, then intercept plan exit and run the review loop (every plan, across permission modes) |
| `auto_open` | `true` | Open uploaded plans in your browser automatically |
| `approve_mode` | `ask` | `ask`: built-in approval dialog after review. `auto`: reviewed plans are **approved automatically in auto mode** |
| `ui_mockups` | `true` | Encourage Claude to embed inline HTML/CSS mockups for UI sections of plans |
| `diagrams` | `true` | Encourage Claude to use mermaid fences for flows and architecture diagrams |

## Opting out

- **Per moment**: tell Claude "skip the scratchtml review" — the retry of that same plan goes straight through.
- **Per behavior**: flip the options above via `/plugin`.
- **Entirely**: `claude plugin disable scratchtml@scratchtml`.

## Tips

- **Pull comments from the plan dialog**: Claude Code's built-in approval menu can't be customized — if you're looking at it and want your scratchtml comments instead, reject the plan and type *"get my comments from scratchtml"* as the message.
- Signal you're done by returning to Claude and saying so — comments left on the page are fetched on demand, not pushed.

## Limitations

- Hooks are bash scripts (and use `python3`) — on Windows you need Git Bash.
- `auto_open` runs on the machine hosting the session: in remote sessions the browser opens on the host, not your remote device — use the link Claude posts in chat.
- Author-time priming fires on entering plan mode; if it's entered without a hookable signal in some client, the same hints still ship as a backstop in the review step.
