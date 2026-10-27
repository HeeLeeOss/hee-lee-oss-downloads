# Hee-Lee Oss — donated-lane loop scripts

`hee-lee-oss-loop.ps1` (Windows) and `hee-lee-oss-loop.sh` (macOS/Linux) drive the **donated
compute lane**: you run your own coding agent, on your own account, against real open-source
good-deed tasks. The script never runs headless and never authenticates an agent for you — it
just automates the pull → build → PR loop you'd otherwise do by hand.

## Prerequisites

- Node.js (for the CLI and the JSON parsing the `.sh` script uses).
- The `hee-lee-oss` CLI installed and on your PATH: `npm install -g @heeleeoss/cli`.
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
4. `hee-lee-oss submit <taskId> --repo <repo> --agent <id>` copies your change into a clean
   staging clone, runs the submit gates there, and only then commits, pushes, and opens the PR,
   recording which agent did the work. It ends with one `HEE_LEE_OSS_SUBMIT ... verdict=<v>` line,
   and the loop acts on that verdict:
   - **opened** (exit 0): the PR is up; the loop prints it and releases the workspace.
   - **no-change** (exit 0): nothing to submit; the loop releases the workspace.
   - **hold** (exit 2): a gate wants a human. Nothing was pushed and the workspace is kept. If the
     change is right, re-run `hee-lee-oss submit <taskId> --repo <repo> --agent <id> --force` from a
     terminal.
   - **block** (exit 3): a gate blocked it and a `STOP` file now halts `submit`/`stage`. The loop
     stops. Run `hee-lee-oss stop --status` to see why, and `hee-lee-oss stop --clear` only after
     reading it.
   - **stopped**: your agent reported it should not continue (see `.hee-lee-oss/result.json`); the
     workspace is kept.

   Before each deed the loop also checks `hee-lee-oss stop --status` and does not pull more work
   while a `STOP` file is set. An older CLI without `stop` only gets a one-time warning; update it
   (`npm install -g @heeleeoss/cli`) so held and blocked outcomes can be detected.

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

| Flag (ps1 / sh)          | Meaning                                                     | Default       |
| ------------------------ | ----------------------------------------------------------- | ------------- |
| `-Count` / `--count`     | Number of deed slots to attempt                             | 10            |
| `-Agent` / `--agent`     | Registry agent id to build with                             | `claude-code` |
| `-Project` / `--project` | Pin to one project slug instead of auto-rotating            | (none)        |
| `-Lane` / `--lane`       | Task lane to pull from                                      | `donated`     |
| `-NoFork` / `--no-fork`  | Clone directly instead of forking (needs push access)       | off           |
| `-DryRun` / `--dry-run`  | Show the resolved plan per task without building/submitting | off           |

## If the loop holds or stops

Held workspaces are kept under `~/Hee-Lee Oss/queue/<id>`; the loop never deletes them.

| The loop prints                                                                  | What it means                                                                 | What to do                                                                                                                                                                 |
| -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `held: <id> - a submit gate wants a human (gates=<...>); workspace kept at <ws>` | A submit gate (exit 2) wants a person to look. Nothing was pushed.            | Read the gates, inspect the workspace, and if the change is right run the printed `re-run: hee-lee-oss submit <id> --repo <repo> --agent <agent> --force` from a terminal. |
| `BLOCKED: <id> (gates=<...>). A STOP file now halts submit/stage; ...`           | A gate blocked the change (exit 3) and wrote the `STOP` file. The loop stops. | Run `hee-lee-oss stop --status` to read why; run `hee-lee-oss stop --clear` only after you have.                                                                           |
| `agent stopped: <id> (see result.json); workspace kept at <ws>`                  | Your agent decided not to continue and said so in `.hee-lee-oss/result.json`. | Read `result.json` in the workspace; fix or discard the task by hand.                                                                                                      |

## What this script is not

It is not the full `ignite` loop shipped in the main Hee-Lee Oss repo
(`scripts/hee-lee-oss-ignite.ps1`), which adds combo/fusion multi-agent strategies, a staged
review-lens auto-merge gate, and PR acceptance sweeps. This is the minimal, registry-driven
pull → build → PR loop for the public downloads audience; if you need the fuller pipeline, work
from the main repo directly.
