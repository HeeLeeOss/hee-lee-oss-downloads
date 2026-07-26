# Hee-Lee Oss — Gemini CLI adapter

A Gemini CLI **extension** that runs Hee-Lee Oss good-deed tasks inside an interactive session, on
your own Gemini account (donated-compute lane). It wraps the agent-neutral `@hee-lee-oss/cli`
(`pull` / `submit`) exactly like the Claude Code plugin does — the CLI stays the source of truth,
this extension is a thin packaging layer around it.

## Setup

```bash
npm install -g @hee-lee-oss/cli
hee-lee-oss init && hee-lee-oss doctor
```

Make sure `gemini` is installed and authenticated:

```bash
gemini --version
```

## Contents

- `gemini-extension/gemini-extension.json` — extension manifest (`name`, `version`,
  `description`, `contextFileName`)
- `gemini-extension/GEMINI.md` — context file loaded into every session where the extension is
  active: the donated-lane billing/safety pre-flight and the refusal guardrails from the
  project's `CLAUDE.md`, adapted for Gemini CLI (not reinvented — same rules, same acceptance
  bar)
- `gemini-extension/commands/hee-lee-oss/{start,next,status}.toml` — the three verbs, mirroring
  the Claude Code plugin's `/hee-lee-oss:start`, `/hee-lee-oss:next`, `/hee-lee-oss:status`
  skills. Each command is a thin prompt that shells to the `hee-lee-oss` CLI; none of them
  reimplement task selection, workspace prep, or PR/receipt logic.

## Install

Requires [Gemini CLI](https://github.com/google-gemini/gemini-cli) with the extensions feature
(`gemini extensions --help`) and the `hee-lee-oss` CLI available on `PATH`.

```bash
# from a local clone of this repo
gemini extensions install ./adapters/gemini-cli/gemini-extension

# or, once this repo/extension is published, from GitHub directly:
gemini extensions install https://github.com/HeeLeeOss/hee-lee-oss-downloads --ref main
```

`gemini extensions install` **copies** the extension into `~/.gemini/extensions/hee-lee-oss/` —
it does not symlink. After pulling changes to this repo, re-run install (or
`gemini extensions update hee-lee-oss`) to pick them up.

## Use

Inside a Gemini CLI session with the extension active:

- `/hee-lee-oss:start [task-file]` — pick a task, do it in this session, open a PR.
- `/hee-lee-oss:next` — do the next task (loop while you have capacity).
- `/hee-lee-oss:status` — see active claims and completed deeds.

## Run a single deed manually (without the extension)

```bash
# 1. Browse and pick a task
hee-lee-oss browse

# 2. Pull the workspace
hee-lee-oss pull --task-file <path/to/task.json>

# 3. Run Gemini in the workspace
cd ~/Hee-Lee Oss/queue/<task-id>
gemini "Read .hee-lee-oss/TASK.md and .hee-lee-oss/CONTEXT.md, then produce the deliverable at the output path. Meet every acceptance criterion."

# 4. Submit
hee-lee-oss submit <task-id> --repo <owner>/<repo> --agent gemini-cli
```

## Loop through many tasks

Older versions of the loop scripts hardcoded `claude -p` and told Gemini/other-agent users to edit
the script by hand to swap the binary. That's gone. Use `--agent gemini-cli` and the registry
resolves everything (model, permission flags, invocation) for you — no script edits needed:

```powershell
./scripts/hee-lee-oss-loop.ps1 -Count 20 -Agent gemini-cli
```

```bash
bash scripts/hee-lee-oss-loop.sh --count 20 --agent gemini-cli
```

See [`../../scripts/README.md`](../../scripts/README.md) for the full registry-driven loop
reference, and [`../../docs/getting-started.md`](../../docs/getting-started.md) /
[`../../docs/looping.md`](../../docs/looping.md) for the broader walkthroughs.

## Uninstall

```bash
gemini extensions uninstall hee-lee-oss
```

## Why interactive only

This adapter is **interactive and human-present by design** so it draws from your own Gemini
account rather than the metered API. The `GEMINI.md` context tells the model to refuse if
`GEMINI_API_KEY` or `GOOGLE_API_KEY` is set in the environment (either would silently redirect
billing to the pay-as-you-go API). The autonomous/funded path is a separate component
(`@hee-lee-oss/runner`), not this extension, and this extension never invokes it.

## Format reference (verified against current docs, 2026-07)

- Extension manifest schema, `contextFileName` fallback to `GEMINI.md`, `commands/` directory
  layout (including namespacing, e.g. `commands/hee-lee-oss/start.toml` → `/hee-lee-oss:start`):
  [Extension reference](https://google-gemini.github.io/gemini-cli/docs/extensions/index.html),
  [Extension reference (mirror)](https://geminicli.com/docs/extensions/reference/)
- Custom command TOML fields (`description`, `prompt`) and the `{{args}}` placeholder:
  [Custom commands](https://google-gemini.github.io/gemini-cli/docs/cli/custom-commands.html)
- Install/uninstall flags (`--ref`, `--auto-update`, `--pre-release`, `--consent`,
  `--skip-settings`), and that install copies rather than symlinks:
  [Extension reference](https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions/reference.md)
