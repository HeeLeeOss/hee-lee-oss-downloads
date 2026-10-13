---
description: Loop through several Hee-Lee Oss good-deed tasks in THIS interactive session — for each, auto-pick the next task with `hee-lee-oss next`, do it here, and open a PR. No browsing or cd-ing. Use when the user runs /hee-lee-oss:work (optionally with a count and/or repo).
disable-model-invocation: true
---

# /hee-lee-oss:work — do a batch of good deeds

Loop good-deed work end-to-end without the user picking tasks or changing directories. This is the
**donated lane** — it runs on the user's **subscription**, so it must stay interactive.

## Pre-flight (first iteration only)
- **Refuse if `ANTHROPIC_API_KEY` is set.** That would bill the API instead of the subscription.
  Tell the user to unset it and restart.
- Run `hee-lee-oss doctor`; if git/gh/config aren't ready, help fix that first.

## Parse `$ARGUMENTS`
- An optional **count** (integer, default `3`) — how many deeds to attempt.
- An optional **repo** (`owner/name`). If omitted, `hee-lee-oss next` auto-picks the highest-priority
  project from the registry.
- Note whether the user can push directly (owns the repo) → use `--no-fork`; otherwise omit it so
  Hee-Lee Oss forks first.

## Loop (repeat up to `count` times)
1. **Select + prepare:** run `hee-lee-oss next [--repo <repo>] [--no-fork]`. It picks the next eligible
   task (open, not already claimed or in progress) and prepares its workspace, printing a line:
   `HEE_LEE_OSS_NEXT taskId=<id> repo=<owner/name> workspace=<path> output=<dest>`.
   - If it prints "no more eligible tasks", **stop** — the queue is drained.
   - If it reports the session cap is reached, **stop** gracefully.
2. **Do the deed:** read `<workspace>/.hee-lee-oss/TASK.md` and `.hee-lee-oss/CONTEXT.md` fully. Produce the
   deliverable at the task's output destination, meeting every acceptance criterion. Work inside the
   printed `workspace` path — no need to guess or cd around.
   - **Honor the refusal guardrails in `CONTEXT.md`.** If the task would cause harm, mislead, give
     unqualified high-stakes advice without the required review, primarily benefit a for-profit, or
     violate a license or privacy — **stop, flag it to the user, and skip the task** (do not submit
     a bad deed). For medium/high `risk-tier` tasks, note that expert review is required before merge.
3. **Submit:** `hee-lee-oss submit <taskId> --repo <repo> [--no-fork] --agent claude-code`. Share the PR URL.
4. **Free the claim:** so the `maxTasksPerSession` cap keeps letting you pull, either delete the
   workspace directory or tell the user to. Then continue to the next iteration.

## If the task lands in a repo we do not own

`hee-lee-oss pull` prints `base branch:` and, for external tasks, the repository's **contribution
terms** (CLA / DCO / licence / enterprise carve-outs). Read them out to the user before starting —
a CLA is the contributor's decision to make knowingly.

The workspace `CONTEXT.md` carries the full guest rules. The short version:

- Read their `CONTRIBUTING.md` and PR template first and **follow their conventions, not ours**.
- **Their licence governs.** Never add Hee-Lee Oss branding, badges, or licence headers upstream.
- **Smallest diff that satisfies the task.** No drive-by refactors, reformatting, or dependency bumps.
- Run their tests and make them pass; never disable a test to get green.
- The PR discloses AI assistance and links the upstream issue — do not remove that.
- **Never write their issue as `owner/repo#number`** in commit messages or anything else landing in
  a public repo — GitHub auto-links it into their tracker. Use the URL, or prose. A bare `#123`
  inside a PR against their own repo is fine.
- `hee-lee-oss complete` / `reopen` do **not** apply upstream; the PR being merged or closed is the
  state. Do not run them against a repo outside the projects org.
- If the task turns out to be wrong for that repo (already fixed, superseded, unwanted), **stop and
  say so**. Not opening a PR is a good outcome.

## Finish
Report a short summary: how many deeds completed, their PR URLs, and anything skipped/flagged.
Never run headless; never set an API key. For a fully hands-off, metered run on an API key, that's
the **funded** lane (`hee-lee-oss-runner`), not this skill.
