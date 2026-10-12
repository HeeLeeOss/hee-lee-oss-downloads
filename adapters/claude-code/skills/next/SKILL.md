---
description: Pull and complete the NEXT Hee-Lee Oss good-deed task in this interactive session, continuing a session started with /hee-lee-oss:start. Use when the user runs /hee-lee-oss:next.
disable-model-invocation: true
---

# /hee-lee-oss:next — do the next deed

Continue an Hee-Lee Oss session with the next task. Same rules as `/hee-lee-oss:start`:

1. **Pre-flight:** refuse if `ANTHROPIC_API_KEY` is set (must stay on subscription).
2. Check the budget guard: run `hee-lee-oss status`. If active claims have reached the configured
   `maxTasksPerSession`, stop and tell the user the session cap is reached.
3. Pick the next task (`hee-lee-oss browse`, or the next from `$ARGUMENTS`).
4. `hee-lee-oss pull --task-file <path> --dry-run`, then `hee-lee-oss pull --task-file <path>`.
5. Do the work in the workspace, honoring the refusal guardrails in `CONTEXT.md`.
6. `hee-lee-oss submit <task-id> --repo <owner>/<repo> --agent claude-code`; share the PR URL.
7. Offer another, or stop gracefully.

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

This skill is for looping through tasks while the user is present. It is interactive — never
headless, never with an API key set.
