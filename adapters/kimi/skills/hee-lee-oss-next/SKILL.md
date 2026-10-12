---
name: hee-lee-oss-next
description: Pull and complete the NEXT Hee-Lee Oss good-deed task in this interactive Kimi Code CLI session, continuing a session started with /skill:hee-lee-oss-start.
---

# /skill:hee-lee-oss-next — do the next deed

Continue a Hee-Lee Oss session with the next task. Same rules as `/skill:hee-lee-oss-start`:

1. **Pre-flight:** refuse if `MOONSHOT_API_KEY` is set (must stay on my own account/subscription
   — see `adapters/kimi/AGENTS.md` for why).
2. Check the budget guard: run `hee-lee-oss status`. If active claims have reached the
   configured `maxTasksPerSession`, stop and tell me the session cap is reached.
3. Pick the next task (`hee-lee-oss browse`, or a task file path I give you directly).
4. `hee-lee-oss pull --task-file <path> --dry-run`, then `hee-lee-oss pull --task-file
   <path>`.
5. Do the work in the workspace, honoring the refusal guardrails in `adapters/kimi/AGENTS.md`
   (and repeated in the workspace's `CONTEXT.md`).
6. `hee-lee-oss submit <task-id> --repo <owner>/<repo> --agent kimi`; share the PR URL.
7. Offer another, or stop gracefully.

This skill is for looping through tasks while I am present. It is interactive — never headless,
never with `MOONSHOT_API_KEY` set.

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
