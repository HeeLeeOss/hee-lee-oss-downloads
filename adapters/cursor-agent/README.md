# Hee-Lee Oss — Cursor Agent adapter

A registry entry for Cursor's agentic terminal CLI (binary: `cursor-agent`) as a first-class `kind: "cli"` agent (`adapters/registry.json`, id `cursor-agent`). Support is gated on the conformance eval (multiagenttasks.md B4) — this README documents intent, the eval is the arbiter of whether the flag surface below actually works end to end.

## Install

Cursor Agent CLI ships as part of Cursor (the editor). Verify it's in your PATH:

```bash
cursor-agent --version
```

If not found, install Cursor from https://www.cursor.com, then verify the binary is available in your shell.

## How the registry entry invokes it

```jsonc
"invocation": {
  "command": "cursor-agent",
  "argsTemplate": ["-p", "--model", "{model}", "{permissions}"],
  "promptChannel": "arg",
  "permissions": { "unattended": ["--force"] }
}
```

- `-p` (prompt mode) runs Cursor Agent non-interactively: reads the prompt as an argument, executes, and exits — the mode `hee-lee-oss`/ignite need for headless dispatch.
- There is **no `permissions.supervised` fragment** (same precedent as `copilot`): Cursor Agent has no documented approval-gating mode for non-interactive runs. The `unattended: ["--force"]` fragment is the only mode available and is reserved as opt-in, never a default.

## How ignite drives it

```bash
hee-lee-oss dispatch --workspace <ws> --agent cursor-agent  # resolves model + invocation
hee-lee-oss next --lane donated --agent cursor-agent        # picks a task
# ignite spawns: cursor-agent -p --model sonnet --force "<prompt>"
hee-lee-oss submit <task-id> --agent cursor-agent           # open a PR
```

Or manually use the universal CLI flow:

```bash
hee-lee-oss pull --task-file <task.json>
cursor-agent -p --model sonnet --force "<prompt>"  # in the workspace folder
hee-lee-oss submit <task-id> --repo <owner>/<repo> --agent cursor-agent
```

## Auth

Cursor Agent reads authentication from your Cursor editor session — no separate API key or env var is needed for authenticated use. There are no known secrets that would silently flip billing outside the Cursor subscription, so `auth.scrubEnv: []` (empty).

## Model tier limitation

Cursor Agent's model choice is subscription-plan-dependent (Free/Pro tiers expose different models). This entry uses a single model `sonnet` at all three tiers rather than a real tier ladder, as the strongest-available model accessible across all Cursor plans. Operators should override `tierModels` to match their actual subscription entitlement if needed.

## Status

Not yet conformance-passed. Treat every flag above as "best-documented as of July 2026, unverified in this repo" until `adapters/_conformance/` (B4) runs a golden task through `computeDispatch` and the real `cursor-agent` binary and records a passing receipt. Do not mark this agent `trusted: true` in `adapters/registry.json` until that gate passes.

## Partner repositories

Many tasks land in a repository Hee-Lee Oss does not own — one that published a needs manifest or
labelled an issue `help wanted`. The flow is identical, but `pull` prints the repo's base branch and
contribution terms (CLA / DCO / licence) first, the work is contributed under **their** licence and
conventions, and the PR discloses that it was AI-assisted. `hee-lee-oss complete` / `reopen` do not
apply upstream. The workspace `CONTEXT.md` carries the full guest rules.
