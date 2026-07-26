# Hee-Lee Oss — donated-lane loop scripts

`hee-lee-oss-loop.ps1` (Windows) and `hee-lee-oss-loop.sh` (macOS/Linux) drive the **donated
compute lane**: you run your own coding agent, on your own account, against real open-source
good-deed tasks. The script never runs headless and never authenticates an agent for you — it
just automates the pull → build → PR loop you'd otherwise do by hand.

## Prerequisites

- Node.js (for the CLI and the JSON parsing the `.sh` script uses).
- The `hee-lee-oss` CLI installed and on your PATH: `npm install -g @hee-lee-oss/cli`.
- `git` and `gh` (GitHub CLI), authenticated.
- Whichever coding agent CLI you intend to build with, installed and authenticated on your own
  account/subscription (e.g. `claude`, `gemini`, `codex`, `aider`). The loop does not install or
  log you into any of these.

## Quick start

```powershell
# Windows / PowerShell
./hee-lee-oss-loop.ps1 -Count 5
```

```bash
# macOS / Linux
./hee-lee-oss-loop.sh --count 5
```

Both default to `claude-code`. Pick a different agent with `--agent`/`-Agent`:

```bash
./hee-lee-oss-loop.sh --count 5 --agent gemini-cli
./hee-lee-oss-loop.sh --count 5 --agent codex
```

## Registry-driven agents

Older versions of these scripts hardcoded `claude -p` and told Gemini/other-agent users to edit
the script by hand to swap the binary. That's gone. Both scripts are now thin wrappers over the
`hee-lee-oss` CLI's registry commands:

1. `hee-lee-oss next` picks the next eligible task and prepares a workspace.
2. `hee-lee-oss dispatch --workspace <ws> --agent <id>` resolves, from `adapters/registry.json`,
   everything needed to run that task with agent `<id>`: the concrete model for the task's
   capability tier, the acceptance verdict (can this agent's output auto-merge or does it need a
   human?), and a ready-to-run invocation — the real command, fully-substituted args (including
   the agent's own supervised-permission flags, e.g. claude-code's `--permission-mode
   acceptEdits`, codex's `--ask-for-approval on-request`), and how the prompt is passed in
   (stdin vs. an argument).
3. The script runs exactly that invocation — no agent name, flag, or model string is baked into
   the script itself. Adding a brand-new agent to the registry (or picking a different one at the
   command line) requires **zero script edits**.
4. `hee-lee-oss submit <taskId> --repo <repo> --agent <id>` commits, pushes, and opens the PR,
   recording which agent did the work.

`--agent <registry-id>` accepts any id present in `adapters/registry.json` — run
`hee-lee-oss agents` to list what's currently registered (e.g. `claude-code`, `aider`, `codex`,
`gemini-cli`, `cursor-agent`).

## Secrets and billing safety

The dispatch plan carries `auth.scrubEnv` — the environment variables that must be unset for the
call so it bills to your subscription/account instead of silently switching to metered API
billing on a stray key (e.g. `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`). Both loop
scripts unset those variables only for the duration of the agent call and restore them
immediately after, and they only ever print a non-secret notice that a scrub happened — never a
key's value. Nothing about the loop writes secrets, tokens, or API keys to logs, receipts, or
committed files.

## Options

| Flag (ps1 / sh) | Meaning | Default |
|---|---|---|
| `-Count` / `--count` | Number of deed slots to attempt | 10 |
| `-Agent` / `--agent` | Registry agent id to build with | `claude-code` |
| `-Project` / `--project` | Pin to one project slug instead of auto-rotating | (none) |
| `-Lane` / `--lane` | Task lane to pull from | `donated` |
| `-NoFork` / `--no-fork` | Clone directly instead of forking (needs push access) | off |
| `-DryRun` / `--dry-run` | Show the resolved plan per task without building/submitting | off |

## What this script is not

It is not the full `ignite` loop shipped in the main Hee-Lee Oss repo
(`scripts/hee-lee-oss-ignite.ps1`), which adds combo/fusion multi-agent strategies, a staged
review-lens auto-merge gate, and PR acceptance sweeps. This is the minimal, registry-driven
pull → build → PR loop for the public downloads audience; if you need the fuller pipeline, work
from the main repo directly.
