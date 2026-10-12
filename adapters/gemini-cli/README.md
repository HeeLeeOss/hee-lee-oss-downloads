# Hee-Lee Oss — Gemini CLI adapter

A Gemini CLI **extension** that runs Hee-Lee Oss good-deed tasks inside an interactive session, on
your own Gemini account (donated-compute lane). It wraps the agent-neutral `@hee-lee-oss/cli`
(`pull` / `submit`) exactly like the Claude Code plugin does — the CLI stays the source of truth,
this extension is a thin packaging layer around it.

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

Then make sure the CLI is available and set up, same as any other adapter:

```bash
npm i -g @hee-lee-oss/cli   # (until published: pnpm -C packages/cli build && npm link)
hee-lee-oss init
hee-lee-oss doctor
```

## Use

Inside a Gemini CLI session with the extension active:

- `/hee-lee-oss:start [task-file]` — pick a task, do it in this session, open a PR.
- `/hee-lee-oss:next` — do the next task (loop while you have capacity).
- `/hee-lee-oss:status` — see active claims and completed deeds.

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

## Conformance gate caveat

Per `CLAUDE.md`, "an agent is 'supported' only when the shared conformance gate passes" — see
[`adapters/_conformance/README.md`](../_conformance/README.md). The `gemini-cli` registry entry
in `adapters/registry.json` already exists and the shared harness
(`node adapters/_conformance/run.mjs --agent gemini-cli`) is what actually gates this agent for
the *ignite/dispatch* path (the donated CLI loop and Control Room lanes).

This extension is a separate, thinner surface — a packaging convenience for people who prefer to
drive Hee-Lee Oss from inside an interactive `gemini` session via slash commands instead of typing
`hee-lee-oss` commands by hand. It does not have its own conformance run (there is nothing
extension-specific to invoke; every command here just shells to the CLI verbs the harness already
exercises). Treat this extension as validated when:

1. `node adapters/_conformance/run.mjs --agent gemini-cli` passes (proves `gemini` + the registry
   dispatch produce an acceptable deliverable and a correctly-labeled receipt), and
2. the manifest/commands here are syntactically valid and match the current Gemini CLI extensions
   format (see below) — this repo's tooling checks that mechanically, since `gemini extensions`
   has no offline `--dry-run`/lint subcommand to invoke in CI.

If a future Gemini CLI release changes the extension or command schema, this directory needs a
manual update — it is not covered by the registry-driven conformance gate the way dispatch is.

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

## Partner repositories

Many tasks land in a repository Hee-Lee Oss does not own — one that published a needs manifest or
labelled an issue `help wanted`. The flow is identical, but `pull` prints the repo's base branch and
contribution terms (CLA / DCO / licence) first, the work is contributed under **their** licence and
conventions, and the PR discloses that it was AI-assisted. `hee-lee-oss complete` / `reopen` do not
apply upstream. The workspace `CONTEXT.md` carries the full guest rules.
