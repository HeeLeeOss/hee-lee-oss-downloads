# Getting started with Hee-Lee Oss

This guide walks you through your first good deed from zero to merged PR.

---

## What you need

- **An AI agent** — Claude Code (recommended), Gemini CLI, Cursor, Copilot, Aider, or Codex
- **Node.js 18+** and **npm**
- **Git** and the **GitHub CLI** (`gh`)
- A GitHub account

---

## Step 1 — Install the Hee-Lee Oss CLI

```bash
npm install -g @hee-lee-oss/cli
```

Run the first-time setup:

```bash
hee-lee-oss init
```

This creates `~/Hee-Lee Oss/` (your work directory) and stores your GitHub identity. Then verify everything is ready:

```bash
hee-lee-oss doctor
```

Fix any issues it reports before continuing.

---

## Step 2 — Connect your agent

Pick the adapter for your agent and follow its setup guide:

- **Claude Code** — [`adapters/claude-code/`](../adapters/claude-code/) (recommended — deepest integration)
- **Gemini CLI** — [`adapters/gemini-cli/`](../adapters/gemini-cli/)
- **Codex CLI** — [`adapters/codex/`](../adapters/codex/)
- **Kimi (Moonshot)** — [`adapters/kimi/`](../adapters/kimi/)
- **Cursor Agent CLI** — [`adapters/cursor/`](../adapters/cursor/)
- **GitHub Copilot** — [`adapters/copilot/`](../adapters/copilot/)
- **Aider** — [`adapters/aider/`](../adapters/aider/)

---

## Step 3 — Browse open projects

```bash
hee-lee-oss browse
```

You'll see a list of approved projects with their priority, open-task count, domain, and tags.

Look for:
- **`good-first-deed`** — scoped and well-documented; good for your first contribution
- **`verified-need`** — a named beneficiary is waiting for this output

---

## Step 4 — Pull a task

```bash
hee-lee-oss pull --task-file <path/to/task.json>
```

This creates a workspace at `~/Hee-Lee Oss/queue/<task-id>/` containing:

| File | What it is |
|---|---|
| `.hee-lee-oss/TASK.md` | What to build, acceptance criteria, output destination |
| `.hee-lee-oss/CONTEXT.md` | Background, guardrails, and refusal rules |
| `.hee-lee-oss/task.json` | Machine-readable task metadata |

Read `TASK.md` and `CONTEXT.md` before starting. The context file includes refusal guardrails — if the task would cause harm, mislead anyone, or require expertise you don't have, stop and flag it instead of proceeding.

---

## Step 5 — Do the deed

Open your agent in the workspace directory and let it do the work.

**Claude Code users:**
```
/hee-lee-oss:start
```
The skill handles everything from here — it reads the task, does the work, and opens the PR.

**All other agents:** open the workspace folder in your agent and give it this prompt:

> Read `.hee-lee-oss/TASK.md` and `.hee-lee-oss/CONTEXT.md`, then produce the deliverable at the task's output path. Meet every acceptance criterion. Honor the guardrails in CONTEXT.md — if the task would cause harm, mislead, or give unqualified high-stakes advice, stop and write nothing.

---

## Step 6 — Submit

```bash
hee-lee-oss submit <task-id> --repo <owner>/<repo>
```

This:
1. Commits the deliverable with a DCO sign-off
2. Pushes from your fork of the project repo
3. Opens a pull request
4. Writes a deed receipt to `~/Hee-Lee Oss/logs/<task-id>.json`

You'll see the PR URL in the output. That's your contribution.

---

## Step 7 — Do more

Check your progress:

```bash
hee-lee-oss status
```

For your next deed, run `hee-lee-oss browse` again or use the loop scripts to run many tasks automatically:

```powershell
# PowerShell
.\scripts\hee-lee-oss-loop.ps1 -Count 10 -Agent claude-code
```

```bash
# bash
bash scripts/hee-lee-oss-loop.sh --count 10 --agent claude-code
```

Swap `-Agent`/`--agent` for any id in `adapters/registry.json` (`gemini-cli`, `codex`, `kimi`,
`aider`, `cursor-agent`, `copilot`) to run the loop with a different agent — no script edits
needed. See [`docs/looping.md`](looping.md) for the full guide on running near your subscription
limits.

---

## Participate in governance

After your first **merged** PR you can vote on new project proposals. Comment `/vote for` or `/vote against` on any open proposal in the [registry](https://github.com/HeeLeeOss/registry/issues).

Have an idea for a good deed? [Open a proposal](https://github.com/HeeLeeOss/registry/issues/new).
