# Looping through tasks — running near your limits

The Hee-Lee Oss loop scripts (`hee-lee-oss-loop.ps1` / `hee-lee-oss-loop.sh`) are designed to let you run many good-deed tasks end-to-end in a single session, automatically, without manually managing each one.

This guide explains how to get the most out of a session without blowing past your limits.

---

## How the loop works

Each iteration does four things:

1. **`hee-lee-oss next`** — picks the next eligible task and prepares a workspace (`~/Hee-Lee Oss/queue/<task-id>/`) with `TASK.md`, `CONTEXT.md`, and a claim file
2. **`hee-lee-oss dispatch --workspace <ws> --agent <id>`** — resolves, from `adapters/registry.json`, everything needed to run that task with your chosen agent: the concrete model for the task's capability tier, the acceptance verdict (can this agent's output auto-merge, or does it need a human?), and a ready-to-run invocation (command, args, supervised permission flags, and whether the prompt goes over stdin or as an argument)
3. **The resolved agent invocation runs** in the workspace and produces the deliverable — the script never hardcodes a vendor binary; whichever agent id you passed via `-Agent`/`--agent` is what actually runs
4. **`hee-lee-oss submit`** — stages the working tree through a host-controlled clone (git never runs in the workspace), runs the submit gates, then commits with the repository's convention, pushes from your fork, opens the PR, and writes a deed receipt. When the PR opens, the workspace is deleted (freeing the session-cap slot) and the loop moves to the next task. If a gate **holds** the change (exit 2), the loop keeps that workspace and carries on; if it **blocks** (exit 3), the loop stops. Before each slot it also checks for a `STOP` file.

Each task is a fresh agent invocation. Context is reset between tasks, so you never hit the per-conversation limit regardless of how many deeds you run.

---

## Understanding your limits

### Subscription context window (the main limit)

Each dispatched agent call gets its own context window. Most Hee-Lee Oss tasks are scoped to fit comfortably within a single invocation. The loop handles the reset automatically — when one task finishes, the next starts with a clean slate.

**You do not need to worry about hitting conversation limits.** The loop design prevents it.

### Session cap (your configurable ceiling)

Hee-Lee Oss tracks how many active task claims you hold at once. The default cap is in `~/Hee-Lee Oss/config.yaml`:

```yaml
maxTasksPerSession: 10
```

When the cap is reached, `hee-lee-oss next` stops returning tasks and the loop exits gracefully. Raise this number to run longer sessions:

```yaml
maxTasksPerSession: 100
```

The session cap is a safety rail, not a limit imposed by your subscription. It exists to prevent one session from claiming all available tasks and starving other contributors.

### Rate limits

If you are running many fast tasks (small content tasks resolved to a light-tier model), you may hit your agent's rate limits. Signs: the agent starts returning errors or truncated output. Solutions:

- Reduce `-Count`/`--count` and run multiple shorter sessions
- Add a brief manual pause between sessions
- Switch `-Agent`/`--agent` to a different registry id to spread load across providers/accounts

---

## Choosing your count

| Session goal | Recommended count |
|---|---|
| First try / test setup | `3` with `-DryRun`/`--dry-run` |
| A quick afternoon session | `5–10` |
| An unattended evening run | `20–50` |
| Maximize a full subscription cycle | `100+` (raise `maxTasksPerSession` first) |

The loop stops cleanly when it runs out of tasks, so setting a high count is safe — it just means "run until the queue is empty or you hit this number."

---

## Model selection is automatic

There is no `--model`/`-Model` flag. Every dispatch resolves the concrete model for the task's
capability tier straight from `adapters/registry.json`'s `tierModels` for your chosen agent
(`frontier` / `standard` / `light`), based on the task's `riskTier` and `tokenEstimate`:

| Task characteristics | Tier chosen | Why |
|---|---|---|
| `riskTier: high` OR `tokenEstimate: large` | **frontier** | High-stakes or complex tasks need the most capable model |
| `riskTier: medium` OR `tokenEstimate: medium` | **standard** | Balanced quality and speed |
| `riskTier: low` AND `tokenEstimate: small` | **light** | Fast, cheap, fine for simple content tasks |

This means a session with 50 tasks might resolve the light-tier model for 30 of them, standard for
15, and frontier for 5 — dramatically extending how much you can do on a fixed subscription. You
never pick the model by hand; you only pick the agent:

```powershell
# PowerShell
.\hee-lee-oss-loop.ps1 -Count 50 -Agent claude-code
```

```bash
# bash
bash hee-lee-oss-loop.sh --count 50 --agent claude-code
```

---

## Permissions

There is no `-PermissionMode`/`--permission-mode` flag, and the loop never escalates to an
unattended/auto-approve mode. Every dispatch resolves the **supervised** (ask-before-edit)
permission fragment for the chosen agent straight from `adapters/registry.json`'s
`invocation.permissions.supervised` — e.g. Claude Code's `--permission-mode acceptEdits`, Codex's
`--sandbox workspace-write --ask-for-approval on-request`. This is deliberate: the loop scripts are
the minimal, public, registry-driven pull → build → PR loop, and they are not the place to opt into
`unattended` (auto-approve-everything) permission fragments. If you need that, work from the main
Hee-Lee Oss repo's fuller `ignite` pipeline directly.

Review a few tasks first with `-DryRun`/`--dry-run` to confirm the task types are appropriate
before running a long session.

---

## Targeting a specific project

```powershell
# PowerShell — run 30 deeds on the open coding curriculum
.\hee-lee-oss-loop.ps1 -Project open-coding-curriculum -Count 30 -Agent claude-code
```

```bash
# bash
bash hee-lee-oss-loop.sh --project open-coding-curriculum --count 30 --agent claude-code
```

`-Project`/`--project` pins to one project slug (resolved to `HeeLeeOss/<slug>`)
instead of auto-rotating across the registry. Omit it to let Hee-Lee Oss auto-pick the
highest-priority task across all projects.

You can also pick a task lane with `-Lane`/`--lane` (default `donated`), and pass
`-NoFork`/`--no-fork` to clone the target repo directly instead of forking (only if you have push
access).

---

## Safe testing before a long run

Always test with `-DryRun`/`--dry-run` first. It shows the resolved plan (agent, model, acceptance
verdict) for each task without actually building or submitting anything:

```powershell
.\hee-lee-oss-loop.ps1 -Count 3 -DryRun
```

Check that `~/Hee-Lee Oss/queue/` contains the workspaces and that `TASK.md` looks sensible. Then run for real.

---

## If the loop stops early or holds a task

| Message | Cause | Fix |
|---|---|---|
| `Session cap reached` | `maxTasksPerSession` hit | Raise the cap in `~/Hee-Lee Oss/config.yaml` |
| `No more eligible tasks` | Queue empty for this project/lane | Try without `-Project`/`--project` to pick from the full registry |
| `held: <task> - agent '<id>' is unusable for this deliverable` | The dispatch acceptance verdict for this agent/task pair is `unusable` | Switch `-Agent`/`--agent`, or handle that task manually with a stronger agent |
| `held: <task> - agent '<id>' kind '<kind>' is not a CLI this loop can drive` | The chosen agent isn't a `kind: "cli"` registry entry | Pick a different `-Agent`/`--agent` id — this loop only drives CLI agents |
| `held: <id> - a submit gate wants a human` | A submit gate (sensitive path, odd file shape, a maintainer's `touches` / `doNotTouch`, …) held the change (exit 2). Nothing was pushed; the workspace is kept under `~/Hee-Lee Oss/queue/<id>/` and the loop continues | Read the findings; if the change is right, run the `--force` command the loop prints, from a terminal |
| `BLOCKED: <id>` | A secret or the deed's canary token was found (exit 3). A `STOP` file now halts `submit`, `stage` and unattended runs, and the loop stops | Run `hee-lee-oss stop --status` to see why; remove the secret; clear it with `hee-lee-oss stop --clear` only after reading why |
| The loop stops before the next slot with a STOP notice | A `STOP` file already exists | Same as above: `hee-lee-oss stop --status`, then `--clear` once you've dealt with the cause |
| `no changes for <task-id> - releasing workspace` | The agent produced no diff, or the task was already done | Inspect the workspace before it's cleaned up (or re-run with `-DryRun` first); may need manual review |

The loop scrubs every registry-declared provider key (`auth.scrubEnv` per agent, e.g.
`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`/`GOOGLE_API_KEY`, `MOONSHOT_API_KEY`) for
the duration of each agent call and restores it immediately after — you'll see a one-line,
non-secret notice (`loop: scrubbed <VAR> from the environment for this call ...`) when that
happens; it is not an error and does not stop the loop.

---

## Checking your progress

At any time:

```bash
hee-lee-oss status
```

Shows active claims, completed deeds, and the URLs of PRs you've opened. Each deed also writes a receipt to `~/Hee-Lee Oss/logs/<task-id>.json` with the PR URL, duration, and model used.

---

## Full example: maximize an evening session

```powershell
# PowerShell — 100 deeds, raise the cap first
# 1. Raise the session cap
(Get-Content ~/Hee-Lee Oss/config.yaml) -replace 'maxTasksPerSession: \d+', 'maxTasksPerSession: 200' |
  Set-Content ~/Hee-Lee Oss/config.yaml

# 2. Run
.\hee-lee-oss-loop.ps1 -Count 100 -Agent claude-code
```

```bash
# bash — same thing
sed -i 's/maxTasksPerSession: [0-9]*/maxTasksPerSession: 200/' ~/Hee-Lee Oss/config.yaml
bash hee-lee-oss-loop.sh --count 100 --agent claude-code
```

Leave it running. Come back to a list of PRs.
