# Hee-Lee Oss — Kimi (Moonshot) adapter

Registry entry for Moonshot AI's agentic terminal CLI, "Kimi Code CLI" (binary: `kimi`), as a
first-class `kind: "cli"` agent (`adapters/registry.json`, id `kimi`). Support is gated on the
conformance eval (multiagenttasks.md B4) — this README documents intent, the eval is the arbiter
of whether the flag surface below actually works end to end.

## Install

```bash
# see https://github.com/MoonshotAI/kimi-cli for the current install method (npm / curl script)
kimi --version
```

## How the registry entry invokes it

```jsonc
"invocation": {
  "command": "kimi",
  "argsTemplate": ["--print", "--model", "{model}", "{permissions}"],
  "promptChannel": "stdin",
  "permissions": { "unattended": ["--afk"] }
}
```

- `--print` puts Kimi CLI into non-interactive ("print mode"): it reads the prompt, runs to
  completion, and exits — the mode `hee-lee-oss`/ignite need for headless dispatch. The prompt is
  piped over stdin (`echo "<prompt>" | kimi --print ...`), matching `claude-code`'s convention.
- **Important caveat, verified against Kimi's own docs**: `--print` *implicitly enables `--afk`*
  (auto-approve all tool calls, auto-dismiss `AskUserQuestion`). In other words, Kimi CLI has no
  genuine "non-interactive but approval-gated" mode the way `claude-code --permission-mode
  acceptEdits` or `codex --ask-for-approval on-request` do — headless Kimi is unattended-equivalent
  by construction. That's why this entry has **no `permissions.supervised` fragment** (same
  precedent as `cursor-agent`): there is nothing truthful to put there. The `unattended: ["--afk"]`
  fragment is added anyway, explicitly, so the registry records the intent even though `--print`
  already implies it — if a future Kimi release decouples `--print` from auto-approval, this entry
  keeps working without silently degrading to a hang (no human to approve a headless prompt).
- `tierModels` (verified against `platform.kimi.ai` model list, July 2026 — the plan's original
  `kimi-k2` / `kimi-k2-turbo` are **end-of-life as of May 2026**, so this entry uses the current
  generation instead): `frontier: kimi-k3`, `standard: kimi-k2.7-code`, `light:
  kimi-k2.7-code-highspeed` (a same-model, faster-output variant of `kimi-k2.7-code`, not a
  distinct smaller model — flagged here as the weakest-verified tier mapping; re-check at
  conformance time).

## Auth

`auth.keyEnv: "MOONSHOT_API_KEY"`, `auth.scrubEnv: ["MOONSHOT_API_KEY"]`, per the plan
(`planning/multi-agent-expansion.md` Workstream A2 / B1).

**Uncertain / flagged**: Kimi CLI's own config docs describe credentials as configured in
`config.toml` (`KIMI_API_KEY` under `[providers.<name>.env]`), stating provider keys are "not read
automatically from shell environment variables" for the native CLI. `MOONSHOT_API_KEY` is the
Moonshot *platform* API key convention (used directly by the aider fallback below, and by most
OpenAI-compatible/litellm integrations). This entry still declares `MOONSHOT_API_KEY` per the
plan's explicit instruction, since it's the variable that would flip billing to a metered API key
across the ecosystem this agent touches (native CLI + fallback) — but if the native `kimi` binary
turns out not to read it directly, the scrub is still correct (defense in depth: nothing should be
leaking a Moonshot key into a donated-lane subprocess regardless of which path reads it), it's just
not sufficient on its own to force the native CLI onto subscription billing. Confirm at conformance
time and adjust if the native CLI needs a different scrub var (e.g. `KIMI_API_KEY`).

## Fallback path: aider

If the `kimi` binary isn't installed/available (e.g. platform gap, org policy), the `aider` adapter
already supports Moonshot's models today via a provider-prefixed model id, once
`adapters/registry.json`'s aider entry uses provider-prefixed models (Workstream A3):

```bash
aider --model moonshot/kimi-k2 --no-auto-commits --message "<prompt>"
```

This works through aider's/litellm's OpenAI-compatible Moonshot integration and reads
`MOONSHOT_API_KEY` directly. It is a stopgap, not a plugin — no native Kimi skills/config ship here
for the fallback path.

## Status

Not yet conformance-passed. Treat every flag above as "best-documented as of July 2026, unverified
in this repo" until `adapters/_conformance/` (B4) runs a golden task through `computeDispatch` and
the real `kimi` binary and records a passing receipt. Do not mark this agent `trusted: true` in
`adapters/registry.json` until that gate passes.

---

## Native plugin (Workstream C3): start / next / status

A native Kimi Code CLI integration mirroring the Claude Code plugin's three verbs — **start /
next / status** — implemented with Kimi's own customization surface. Every skill is a thin
wrapper that shells to the agent-neutral `hee-lee-oss` CLI (`pull` / `submit` / `status`), exactly
like the Claude Code, Codex, and Gemini CLI adapters — no vendor-specific logic lives outside
`adapters/`, per `CLAUDE.md`.

### Mechanism confirmed (verified live, July 2026)

The plan's placeholder ("agents/config file (confirm mechanism)") is resolved: Kimi Code CLI's
closest native equivalent to Codex's custom-prompts-dir / Gemini CLI's extension-commands is its
**Skills** system, invoked via slash command — **not** the `--agent-file` custom-agent mechanism
(that defines an entirely different agent persona/toolset, not a reusable slash-invoked prompt).

- **Skills** (`moonshotai.github.io/kimi-cli/en/customization/skills.html`): a skill is a
  directory `<name>/SKILL.md` (YAML frontmatter + Markdown body) or a flat `<name>.md` file.
  Invoked as `/skill:<name>` (optionally with trailing free text appended to the prompt); the CLI
  reads `SKILL.md` and sends its content to the agent as a prompt — the same "thin prompt wrapper
  shelling to the CLI" shape as every other adapter here. Skills load from a priority-ordered set
  of directories (**Project > User > Extra > Built-in**), each split into a *brand* group
  (`~/.kimi/skills/`, project `.kimi/skills/`, mutually exclusive with the other brand dirs like
  `.claude/skills/`, `.codex/skills/`) and a *generic* group (`~/.config/agents/skills/`
  — documented as the **recommended** generic path — or `~/.agents/skills/`, and their project
  equivalents `.config/agents/skills/` / `.agents/skills/`). `merge_all_available_skills`
  (default `true`) merges all discovered directories, so installing to the generic user-level path
  works regardless of which brand dirs a given machine also has populated. Extra directories can be
  added via `--skills-dir` / `extra_skill_dirs`. This adapter installs to the generic, user-level
  location by default (`~/.config/agents/skills/`) — global like Codex's `~/.codex/prompts`, not
  scoped to one repo, since Hee-Lee Oss task workspaces are throwaway clones the skills need to be
  available in regardless of which project they contain.
- **`AGENTS.md`** (`kimi.com/help/kimi-code/cli-customization`, `github.com/MoonshotAI/kimi-cli`
  root `AGENTS.md`): project-context file, same name and same "compose, don't replace" spirit as
  Codex's — Kimi loads `AGENTS.md` from the project root and any subdirectory, plus a global
  `~/.kimi/AGENTS.md`; `/init` generates one by scanning the project. Docs did not surface an
  explicit documented size cap or precise root-to-leaf concatenation order equivalent to Codex's
  (unlike Codex's `project_doc_max_bytes`/walk-order, which is spelled out) — **flagged as the
  weakest-verified part of this mechanism, confirm at conformance time**. This adapter follows the
  same pattern as the Codex adapter regardless: append a clearly-marked, idempotent snippet to a
  target repo's `AGENTS.md` rather than replacing the file, since the doc's "any subdirectory,
  auto-loaded" model implies composable fragments are expected, not single ownership.
- **No native non-interactive plugin/skill invocation caveat beyond what's in the main README
  above**: the slash-commands reference (`moonshotai.github.io/kimi-cli/en/reference/slash-
  commands.html`) documents `/skill:<name>` only for interactive sessions; it does not surface a
  `--print`-mode equivalent for pre-invoking a skill headlessly, which is moot here anyway since
  this plugin is donated-lane/interactive-only (see "Why interactive only" below) and the
  registry's `--print` dispatch path (documented in the main README above) is a separate,
  unattended-only mechanism this plugin does not touch.

Sources: [Kimi Help Center — CLI customization](https://www.kimi.com/help/kimi-code/cli-customization),
[Agent Skills](https://moonshotai.github.io/kimi-cli/en/customization/skills.html),
[Agents and Subagents](https://moonshotai.github.io/kimi-cli/en/customization/agents.html),
[Slash Commands reference](https://moonshotai.github.io/kimi-cli/en/reference/slash-commands.html),
[`kimi-cli/AGENTS.md`](https://github.com/MoonshotAI/kimi-cli/blob/main/AGENTS.md).

### Layout

```
adapters/kimi/
├── skills/
│   ├── hee-lee-oss-start/SKILL.md   # /skill:hee-lee-oss-start  — pick + do a task, open a PR
│   ├── hee-lee-oss-next/SKILL.md    # /skill:hee-lee-oss-next   — do the next task in this session
│   └── hee-lee-oss-status/SKILL.md  # /skill:hee-lee-oss-status — show claims + completed deeds
├── agents-md-snippet.md              # Hee-Lee Oss work rules, marker-wrapped, for AGENTS.md
├── install.mjs                       # cross-platform, dependency-free installer (install/uninstall)
└── README.md
```

### Install

```bash
node adapters/kimi/install.mjs
```

This copies the three `skills/<name>/SKILL.md` directories into `$KIMI_SKILLS_DIR` (default
`~/.config/agents/skills/`) and appends the `agents-md-snippet.md` block to `./AGENTS.md` in the
current directory (pass `--repo <path>` for a different target repo). Re-running is a no-op
change in effect: skill files are overwritten with identical content, and the `AGENTS.md` block is
replaced in place rather than appended again (wrapped in `<!-- hee-lee-oss:begin -->` /
`<!-- hee-lee-oss:end -->` markers, which the installer looks for and rewrites between).

Flags:

```
node adapters/kimi/install.mjs [--skills-dir <dir>] [--repo <dir>] [--uninstall] [--dry-run]

  --skills-dir <dir>  Where to install skills (default: $KIMI_SKILLS_DIR or ~/.config/agents/skills)
  --repo <dir>        Target repo whose AGENTS.md gets the snippet (default: cwd)
  --uninstall         Remove the installed skills and strip the marked snippet block
  --dry-run           Print what would happen; touch nothing
```

Then make sure the CLI is available and set up (same as every adapter):

```bash
npm i -g @hee-lee-oss/cli   # (until published: pnpm -C packages/cli build && npm link)
hee-lee-oss init
hee-lee-oss doctor
```

### Uninstall

```bash
node adapters/kimi/install.mjs --uninstall [--skills-dir <dir>] [--repo <dir>]
```

Removes the three skill directories from the skills directory and strips the marker-wrapped block
from `AGENTS.md` (deletes the file only if stripping the block leaves it empty).

### Use

In a Kimi Code CLI session:

- `/skill:hee-lee-oss-start` — pick a task, do it in this session, open a PR.
- `/skill:hee-lee-oss-next` — do the next task (loop while you have capacity).
- `/skill:hee-lee-oss-status` — see active claims and completed deeds.

### Why interactive only

Same posture as every donated-lane adapter: this is interactive and human-present by design so it
draws from your own Kimi/Moonshot account rather than the metered API. The skills instruct the
session to refuse if `MOONSHOT_API_KEY` is set in the environment — matching
`adapters/registry.json`'s `kimi` entry (`auth.keyEnv: "MOONSHOT_API_KEY"`), and per the "Auth"
section above, treated as defense-in-depth even though the native binary's own credential path may
not read that variable directly. The autonomous/funded path is a separate component
(`packages/runner`), not this plugin.

### Conformance-gate caveat

This plugin (skills + `AGENTS.md` snippet + installer) is documentation/tooling around the Kimi
CLI; it does not itself change how `hee-lee-oss` dispatches to `kimi`. That dispatch is already
governed by the `kimi` entry in `adapters/registry.json` and is only "supported" once it passes
`adapters/_conformance/` (`node adapters/_conformance/run.mjs --agent kimi`) per B4. This directory
does not add a second gate — installing these skills does not imply the conformance gate has
passed, and shipping this plugin is not itself proof that `kimi --print` dispatch is correct.

**Unverified-pending-conformance**: the skills mechanism and `AGENTS.md` discovery described above
are the best-documented current mechanism as of July 2026 (see sources), consistent across the
official docs site, the Kimi Help Center, and the `kimi-cli` GitHub repo. What is *not* independently
verified in this repo is that a real `kimi` binary actually resolves `/skill:hee-lee-oss-start` from
`~/.config/agents/skills/` end to end (no local `kimi` install was available to this task) — treat
that specific claim as unverified until B4 conformance runs against the real binary, same caveat as
the flag-surface caveats already in the main README above.

### Contents

- `skills/` — three Kimi Code CLI skills, one per verb, each a thin wrapper telling the session to
  shell to `hee-lee-oss` (same content shape as the Claude Code adapter's `skills/*/SKILL.md` and
  the Codex adapter's `prompts/*.md`).
- `agents-md-snippet.md` — the Hee-Lee Oss work rules (agent-neutral architecture rules + refusal
  guardrails + the `MOONSHOT_API_KEY` donated-lane caveat), adapted from `CLAUDE.md`, marker-wrapped
  for idempotent installation.
- `install.mjs` — Node-only (no dependencies), cross-platform installer/uninstaller.

## Partner repositories

Many tasks land in a repository Hee-Lee Oss does not own — one that published a needs manifest or
labelled an issue `help wanted`. The flow is identical, but `pull` prints the repo's base branch and
contribution terms (CLA / DCO / licence) first, the work is contributed under **their** licence and
conventions, and the PR discloses that it was AI-assisted. `hee-lee-oss complete` / `reopen` do not
apply upstream. The workspace `CONTEXT.md` carries the full guest rules.
