# Hee-Lee Oss — OpenAI Codex CLI adapter

A native Codex CLI integration mirroring the Claude Code plugin's three verbs — **start / next /
status** — implemented with Codex's own customization surface instead of a plugin system (Codex
CLI has no plugin/marketplace mechanism; its customization surface is custom prompts +
`AGENTS.md`). Every prompt is a thin wrapper that shells to the agent-neutral `hee-lee-oss` CLI
(`pull` / `submit` / `status`), exactly like the Claude Code adapter — no vendor-specific logic
lives outside `adapters/`, per `CLAUDE.md`.

## Docs verified against (July 2026)

OpenAI moved Codex's narrative docs out of the `openai/codex` repo; each `docs/*.md` file there is
now a redirect stub pointing at `developers.openai.com/codex/...` (which itself redirects to
`learn.chatgpt.com/docs/...`). Verified live, not assumed from the repo's stub files:

- **Custom prompts** — `learn.chatgpt.com/docs/custom-prompts`: prompt files live in
  `~/.codex/prompts/` (Codex's local home directory; overridable via `$CODEX_HOME`), **top-level
  `.md` files only** (subdirectories are ignored). Optional YAML front matter: `description`
  (shown in the slash-command menu) and `argument-hint`. Placeholder syntax: `$1`–`$9`
  (positional), `$ARGUMENTS` (everything), named placeholders as uppercase `$VAR` supplied via
  `KEY=value` args, and `$$` for a literal `$`. Invoked via the `/` slash-command menu as
  `/prompts:<filename-without-extension>`.
  - **Caveat surfaced by the docs themselves: custom prompts are deprecated** in favor of
    "skills" (`~/.codex/skills`, richer, shareable, can be invoked implicitly). This adapter still
    ships custom prompts because the task explicitly scoped this mechanism and it remains
    functional; if/when Codex removes it, the natural next step is porting these three files into
    skill form (same content, different packaging) — tracked as follow-up, not done here.
- **`AGENTS.md`** — `learn.chatgpt.com/docs/agent-configuration/agents-md`: Codex discovers
  `~/.codex/AGENTS.override.md` / `~/.codex/AGENTS.md` (global), then walks the project tree from
  repo root to cwd checking the same override/standard/fallback names at each level, and
  **concatenates** everything root-down (closer-to-cwd files win because they appear later).
  Bounded by `project_doc_max_bytes` (32 KiB default, configurable). This is why the installer
  *appends* a clearly-marked snippet to a repo's `AGENTS.md` rather than replacing the whole file —
  the merge model expects composable fragments, not a single owner per file.
- **Non-interactive (`exec`) mode** — `learn.chatgpt.com/docs/non-interactive-mode` /
  `docs.onlinetool.cc/codex/docs/exec.html`: `codex exec` streams progress to stderr and prints
  only the final message to stdout; `--full-auto` is a deprecated compatibility alias for
  `--sandbox workspace-write` (still auto-approves); `on-request` approval is silently downgraded
  to `never` in exec mode (no TTY to prompt). This matches, and explains, `adapters/registry.json`'s
  existing `codex` entry (`argsTemplate: ["exec", "--model", "{model}", "{permissions}"]`,
  `permissions.supervised: ["--sandbox", "workspace-write", "--ask-for-approval", "on-request"]`) —
  **not changed here**, this adapter only consumes it.

## Layout

```
adapters/codex/
├── prompts/
│   ├── hee-lee-oss-start.md    # /prompts:hee-lee-oss-start  — pick + do a task, open a PR
│   ├── hee-lee-oss-next.md     # /prompts:hee-lee-oss-next   — do the next task in this session
│   └── hee-lee-oss-status.md   # /prompts:hee-lee-oss-status — show claims + completed deeds
├── agents-md-snippet.md         # Hee-Lee Oss work rules, marker-wrapped, for AGENTS.md
├── install.mjs                  # cross-platform, dependency-free installer (install/uninstall)
└── README.md
```

## Install

```bash
node adapters/codex/install.mjs
```

This copies the three prompt files into `$CODEX_HOME/prompts` (default `~/.codex/prompts`) and
appends the `agents-md-snippet.md` block to `./AGENTS.md` in the current directory (pass
`--repo <path>` for a different target repo). Re-running is a no-op change in effect: prompt files
are overwritten with identical content, and the `AGENTS.md` block is replaced in place rather than
appended again (it's wrapped in `<!-- hee-lee-oss:begin -->` / `<!-- hee-lee-oss:end -->` markers,
which the installer looks for and rewrites between).

Flags:

```
node adapters/codex/install.mjs [--codex-home <dir>] [--repo <dir>] [--uninstall] [--dry-run]

  --codex-home <dir>  Where to install prompts (default: $CODEX_HOME or ~/.codex)
  --repo <dir>         Target repo whose AGENTS.md gets the snippet (default: cwd)
  --uninstall          Remove the installed prompts and strip the marked snippet block
  --dry-run            Print what would happen; touch nothing
```

Then make sure the CLI is available and set up (same as every adapter):

```bash
npm i -g @hee-lee-oss/cli   # (until published: pnpm -C packages/cli build && npm link)
hee-lee-oss init
hee-lee-oss doctor
```

## Uninstall

```bash
node adapters/codex/install.mjs --uninstall [--codex-home <dir>] [--repo <dir>]
```

Removes the three prompt files from the prompts directory and strips the marker-wrapped block
from `AGENTS.md` (deletes the file only if stripping the block leaves it empty).

## Use

In a Codex CLI session, type `/` to open the slash-command menu:

- `/prompts:hee-lee-oss-start` — pick a task, do it in this session, open a PR.
- `/prompts:hee-lee-oss-next` — do the next task (loop while you have capacity).
- `/prompts:hee-lee-oss-status` — see active claims and completed deeds.

## Why interactive only

Same posture as every donated-lane adapter: this is interactive and human-present by design so it
draws from your Codex/ChatGPT plan. The prompts instruct the session to refuse if
`OPENAI_API_KEY` is set in the environment (that would bill the metered API instead) — matching
`adapters/registry.json`'s `codex` entry, whose `auth.keyEnv` is `OPENAI_API_KEY`. The
autonomous/funded path is a separate component (`packages/runner`), not this adapter.

## Conformance-gate caveat

This adapter (prompts + `AGENTS.md` snippet + installer) is documentation/tooling around the
Codex CLI; it does not itself change how `hee-lee-oss` dispatches to `codex`. That dispatch is
already governed by the `codex` entry in `adapters/registry.json` and is only "supported" once it
passes `adapters/_conformance/` (`node adapters/_conformance/run.mjs --agent codex`) on Windows
**and** macOS/Linux (see `adapters/_conformance/README.md`). This directory does not add a second
gate or a second golden task — installing these prompts does not imply the conformance gate has
passed, and shipping this adapter is not itself proof that `codex exec` dispatch is correct.
Treat the flag surface cited above as "best-documented as of July 2026, verified against Codex's
current docs" — re-confirm at conformance time if Codex's CLI surface has moved again.

## Contents

- `prompts/` — three Codex custom prompts, one per verb, each a thin wrapper telling the session
  to shell to `hee-lee-oss` (same content shape as the Claude Code adapter's `skills/*/SKILL.md`).
- `agents-md-snippet.md` — the Hee-Lee Oss work rules (agent-neutral architecture rules + refusal
  guardrails), adapted from `CLAUDE.md`, marker-wrapped for idempotent installation.
- `install.mjs` — Node-only (no dependencies), cross-platform installer/uninstaller.
