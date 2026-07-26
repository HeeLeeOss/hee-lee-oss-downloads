---
name: hee-lee-oss-start
description: Start a Hee-Lee Oss good-deed session — pick a community task, do it in THIS interactive Kimi Code CLI session (on your own Moonshot account), and open a PR. Use when the user runs /skill:hee-lee-oss-start or asks to do a Hee-Lee Oss deed.
---

# /skill:hee-lee-oss-start — run a good deed

Help me complete a community-approved **good deed** using *this* Kimi Code CLI session.
Hee-Lee Oss's donated-compute lane runs on my own account/subscription — this must stay
interactive, human-present, and non-headless.

## 0. Billing & safety pre-flight (do this first, every time)

- **Refuse to proceed if `MOONSHOT_API_KEY` is set** in the environment. That variable is the
  registry's donated-lane scrub target (`adapters/registry.json`'s `kimi` entry,
  `auth.keyEnv`/`auth.scrubEnv`); its presence signals a metered-API path is configured somewhere
  in the ecosystem this session touches (e.g. the `aider` fallback), not my subscription. Tell me
  to unset it and restart before continuing. See `adapters/kimi/AGENTS.md` (the caveat there
  about `config.toml`/`KIMI_API_KEY`) for why this is defense-in-depth rather than a guarantee.
- Confirm `hee-lee-oss` is installed and configured: run `hee-lee-oss doctor`. If git/gh aren't
  ready, help fix that first.

## 1. Pick a task

- Run `hee-lee-oss browse` to show approved projects.
- Ask me which project/task, or use a task file path I gave you directly with `--task-file
  <path>`.

## 2. Prepare the workspace

- Preview first: `hee-lee-oss pull --task-file <path> --dry-run`.
- Then prepare it for real: `hee-lee-oss pull --task-file <path>`.
- This creates a workspace under `~/Hee-Lee Oss/queue/<task-id>/` with `TASK.md`, `CONTEXT.md`,
  and a claim file. If a claim already exists, it resumes — do not duplicate work.

## 3. Do the work (this is the deed)

- `cd` into the workspace. Read `TASK.md` and `CONTEXT.md` fully before writing anything.
- **Honor the refusal guardrails** (see `adapters/kimi/AGENTS.md`, installed alongside this
  skill, for the full list). If the task would cause harm, mislead, give unqualified high-stakes
  advice without the required review, primarily benefit a for-profit entity, or violate a
  source's license or a person's privacy — **stop and tell me** instead of proceeding.
- Produce the deliverable at the task's **Output destination**. Meet every acceptance
  criterion. For non-code deliverables (translation/document/dataset), produce the artifact
  itself.

## 4. Submit

- Run: `hee-lee-oss submit <task-id> --repo <project-owner>/<project-repo> --agent kimi`
- This commits, pushes from my fork, opens the PR, and writes a deed receipt.
- Share the PR URL with me.

## 5. Loop or stop

- Ask if I want another task. If yes, use `/skill:hee-lee-oss-next`.
- Respect the budget guard — if `hee-lee-oss pull` reports the session cap is reached, stop
  gracefully.

Keep me informed at each step. Never run headless (no `kimi --print --afk` self-invocation of
this flow — that mode auto-approves every tool call with no human present); never set
`MOONSHOT_API_KEY` for this session.
