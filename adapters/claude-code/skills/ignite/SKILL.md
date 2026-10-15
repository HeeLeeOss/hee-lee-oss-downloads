---
description: Process donated-lane deed tasks back-to-back on your subscription, auto-merging only low-risk work that passes an independent review-gate. Use when the user runs /hee-lee-oss:ignite [count] [project].
disable-model-invocation: true
---

# /hee-lee-oss:ignite — one-liner deed runner

Run the ignite engine, which processes good-deed tasks on the user's **subscription** (never the
metered API — the engine scrubs `ANTHROPIC_API_KEY` from every agent invocation automatically).

## Parse the arguments

Interpret the user's arguments as `[count] [project]` — both optional:

- the first bare integer → `-Count` (default **10**)
- the next bare word → `-Project` (a repo name under `HeeLeeOss`; omit to auto-pick the
  highest-priority work across the registry)

## Run it

Invoke the engine and stream its output:

```bash
pwsh -NoProfile -File scripts/hee-lee-oss-ignite.ps1 -Count <count> [-Project <project>]
```

## What it does (per task)

`hee-lee-oss next` → needs-human risk gate → build with the user's agent (subscription) →
`hee-lee-oss submit` (opens the PR) → for **low-risk** tasks only, an **independent `claude -p`
review-gate** judges the PR diff against the acceptance criteria and guardrails:

- **PASS** → merge (squash). If the repo has CI, only when checks are green; if it has no CI, merge
  and apply the `agent-verified-no-ci` label so it stays auditable.
- **FAIL** → leave the PR open for the user.

Model floor: **low-risk** → sonnet (haiku only for small tasks); **medium-risk** → **opus**.

**Medium-risk** tasks *are built* (on opus) and left as a PR for the user to review — never
auto-merged. **High-risk** tasks are held for expert review (never built).

It stops when the count is reached, the queue is empty, the session cap is hit, or a task needs a
human, then prints three lists: **merged**, **awaiting your review**, and **held (needs a human)**.
