---
description: Start an Hee-Lee Oss good-deed session — pick a community task, do it in THIS interactive Claude Code session (on your subscription), and open a PR. Use when the user runs /hee-lee-oss:start or asks to do an Hee-Lee Oss deed.
disable-model-invocation: true
---

# /hee-lee-oss:start — run a good deed

You will help the user complete a community-approved **good deed** using *this* interactive
Claude Code session. Hee-Lee Oss's donated-compute lane runs on the user's **subscription** — so this
must stay interactive.

## 0. Billing & safety pre-flight (do this first, every time)
- **Refuse to proceed if `ANTHROPIC_API_KEY` is set** in the environment. That would bill the
  pay-as-you-go API instead of the user's subscription. Tell the user to unset it and restart.
- Confirm `hee-lee-oss` is installed: run `hee-lee-oss doctor`. If git/gh aren't ready, help fix that first.

## 1. Pick a task
- Run `hee-lee-oss browse` to show approved projects.
- Ask the user which project/task, or accept a task file path from `$ARGUMENTS`.
- If the user passes a task file, use `--task-file <path>`.

## 2. Prepare the workspace
- Preview first: `hee-lee-oss pull --task-file <path> --dry-run`.
- Then prepare it for real: `hee-lee-oss pull --task-file <path>`.
- This creates a workspace under `~/Hee-Lee Oss/queue/<task-id>/` with `TASK.md`, `CONTEXT.md`, and a
  claim file. If a claim already exists, it resumes — do not duplicate work.

## 3. Do the work (this is the deed)
- `cd` into the workspace. Read `TASK.md` and `CONTEXT.md` fully.
- **Honor the refusal guardrails in `CONTEXT.md`.** If the task would cause harm, mislead, give
  unqualified high-stakes advice without the required review, or primarily benefit a for-profit —
  **stop and tell the user** instead of proceeding.
- Produce the deliverable at the task's **Output destination**. Meet every acceptance criterion.
  For non-code deliverables (translation/document/dataset), produce the artifact itself.

## 4. Submit
- Run: `hee-lee-oss submit <task-id> --repo <project-owner>/<project-repo> --agent claude-code`
- This commits, pushes from the user's fork, opens the PR, and writes a deed receipt.
- Share the PR URL with the user.

## 5. Loop or stop
- Ask if they want another task. If yes, use `/hee-lee-oss:next`.
- Respect the budget guard — if `hee-lee-oss pull` reports the session cap is reached, stop gracefully.

## If the task lands in a repo we do not own

`hee-lee-oss pull` prints `base branch:` and, for external tasks, the repository's contribution
terms (CLA / DCO / licence / enterprise carve-outs). Surface those before starting — a CLA is a
decision to make knowingly. `CONTEXT.md` carries the full guest rules; in short:

- Read their `CONTRIBUTING.md` and PR template first and **follow their conventions, not ours**.
- **Their licence governs.** Never add Hee-Lee Oss branding, badges, or licence headers upstream.
- **Smallest diff that satisfies the task** — no drive-by refactors, reformatting, or dep bumps.
- Run their tests and make them pass; never disable a test to get green.
- The PR discloses AI assistance and links the upstream issue — do not remove that.
- **Never write their issue as `owner/repo#number`** in commit messages or anything else landing in
  a public repo — GitHub auto-links it into their tracker. Use the URL, or prose. A bare `#123`
  inside a PR against their own repo is fine.
- `hee-lee-oss complete` / `reopen` do **not** apply upstream; merged or closed there is the state.
- If the task is wrong for that repo (already fixed, superseded, unwanted), **stop and say so**.
  Not opening a PR is a good outcome.

Keep the user informed at each step. Never run headless; never set an API key.
