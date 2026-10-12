---
description: Start a Hee-Lee Oss good-deed session — pick a community task, do it in THIS Codex session (on your ChatGPT plan/own account), and open a PR.
argument-hint: "[TASK_FILE=<path>]"
---

# Hee-Lee Oss — start a good deed

Help me complete a community-approved **good deed** using *this* Codex CLI session. Hee-Lee
Oss's donated-compute lane runs on my own account/subscription — this must stay interactive,
human-present, and non-headless.

## 0. Billing & safety pre-flight (do this first, every time)

- **Refuse to proceed if `OPENAI_API_KEY` is set** in the environment. That would bill the
  pay-as-you-go API instead of my subscription/own account. Tell me to unset it and restart
  Codex before continuing.
- Confirm `hee-lee-oss` is installed and configured: run `hee-lee-oss doctor`. If git/gh aren't
  ready, help fix that first.

## 1. Pick a task

- Run `hee-lee-oss browse` to show approved projects.
- Ask me which project/task, or use the task file path I gave in `TASK_FILE=$TASK_FILE` (if I
  didn't supply one, `$TASK_FILE` will be empty — ask before proceeding).

## 2. Prepare the workspace

- Preview first: `hee-lee-oss pull --task-file $TASK_FILE --dry-run`.
- Then prepare it for real: `hee-lee-oss pull --task-file $TASK_FILE`.
- This creates a workspace under `~/Hee-Lee Oss/queue/<task-id>/` with `TASK.md`, `CONTEXT.md`,
  and a claim file. If a claim already exists, it resumes — do not duplicate work.

## 3. Do the work (this is the deed)

- `cd` into the workspace. Read `TASK.md` and `CONTEXT.md` fully before writing anything.
- **Honor the refusal guardrails in `CONTEXT.md`** (see the `AGENTS.md` snippet installed
  alongside this prompt for the full list). If the task would cause harm, mislead, give
  unqualified high-stakes advice without the required review, primarily benefit a for-profit
  entity, or violate a source's license or a person's privacy — **stop and tell me** instead of
  proceeding.
- Produce the deliverable at the task's **Output destination**. Meet every acceptance
  criterion. For non-code deliverables (translation/document/dataset), produce the artifact
  itself.

## 4. Submit

- Run: `hee-lee-oss submit <task-id> --repo <project-owner>/<project-repo> --agent codex`
- This commits, pushes from my fork, opens the PR, and writes a deed receipt.
- Share the PR URL with me.

## 5. Loop or stop

- Ask if I want another task. If yes, use the `/prompts:hee-lee-oss-next` prompt.
- Respect the budget guard — if `hee-lee-oss pull` reports the session cap is reached, stop
  gracefully.

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

Keep me informed at each step. Never run headless (no `codex exec --full-auto` self-invocation
of this flow); never set `OPENAI_API_KEY` for this session.
