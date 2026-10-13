# Hee-Lee Oss — Claude Code adapter

A Claude Code **plugin** that runs Hee-Lee Oss good-deed tasks inside an interactive session, on your
subscription (donated-compute lane). It wraps the agent-neutral `@hee-lee-oss/cli` (`pull` / `submit`).

## Install

```text
/plugin marketplace add HeeLeeOss/hee-lee-oss-downloads
/plugin install hee-lee-oss
```

Then make sure the CLI is available and set up:

```bash
npm i -g @hee-lee-oss/cli   # (until published: pnpm -C packages/cli build && npm link)
hee-lee-oss init
hee-lee-oss doctor
```

## Use

- `/hee-lee-oss:start` — pick a task, do it in this session, open a PR.
- `/hee-lee-oss:next` — do the next task (loop while you have capacity).
- `/hee-lee-oss:status` — see active claims and completed deeds.

## Why interactive only

This adapter is **interactive and human-present by design** so it draws from your Pro/Max
subscription. It refuses to run if `ANTHROPIC_API_KEY` is set (that would bill the API). The
autonomous/funded path is a separate component (`@hee-lee-oss/runner`), not this plugin.

## Contents

- `.claude-plugin/plugin.json` — plugin manifest
- `skills/` — `/hee-lee-oss:start`, `/hee-lee-oss:next`, `/hee-lee-oss:status`
- `settings.json` — pre-approved permissions for `hee-lee-oss`, `gh`, and `git`
- `hooks/hooks.json` — session-start reminder
- `eval/` — thin wrapper over the shared conformance harness in [`adapters/_conformance/`](../_conformance/README.md).
  `node adapters/claude-code/eval/run-eval.mjs --plan-only` is the old agent-free dry-run check;
  without the flag it runs the full gate, which invokes `claude` and spends your quota.

## Partner repositories

Many tasks land in a repository Hee-Lee Oss does not own — one that published a needs manifest or
labelled an issue `help wanted`. The flow is identical, but `pull` prints the repo's base branch and
contribution terms (CLA / DCO / licence) first, the work is contributed under **their** licence and
conventions, and the PR discloses that it was AI-assisted. `hee-lee-oss complete` / `reopen` do not
apply upstream. The workspace `CONTEXT.md` carries the full guest rules.
