# Hee-Lee Oss — Claude Code adapter

A Claude Code **plugin** that runs Hee-Lee Oss good-deed tasks inside an interactive session, on your
subscription (donated-compute lane). It wraps the agent-neutral `@heeleeoss/cli` (`pull` / `submit`).

## Install

```text
/plugin marketplace add HeeLeeOss/hee-lee-oss-downloads
/plugin install hee-lee-oss --marketplace HeeLeeOss/hee-lee-oss-downloads
```

Then make sure the CLI is available and set up:

```bash
npm i -g @heeleeoss/cli
hee-lee-oss init
hee-lee-oss doctor
```

## Use

- `/hee-lee-oss:start` — pick a task, do it in this session, open a PR.
- `/hee-lee-oss:next` — do the next task (loop while you have capacity).
- `/hee-lee-oss:work` — loop through several tasks in this session, picking each with `hee-lee-oss next`.
- `/hee-lee-oss:ignite` — process tasks back-to-back, auto-merging only low-risk work that passes an independent review gate.
- `/hee-lee-oss:triage` — triage a partner's labelled issues and draft one gated comment for you to approve.
- `/hee-lee-oss:status` — see active claims and completed deeds.

## Why interactive only

This adapter is **interactive and human-present by design** so it draws from your Pro/Max
subscription. It refuses to run if `ANTHROPIC_API_KEY` is set (that would bill the API). The
autonomous/funded path is a separate component (`@heeleeoss/runner`), not this plugin.

## Contents

- `.claude-plugin/plugin.json` — plugin manifest
- `skills/` — `start`, `next`, `work`, `ignite`, `triage`, `status`
- `hooks/hooks.json` — session-start reminder
- `eval/` — thin wrapper over the shared conformance harness in [`adapters/_conformance/`](../_conformance/README.md).
  `node adapters/claude-code/eval/run-eval.mjs --plan-only` is the old agent-free dry-run check;
  without the flag it runs the full gate, which invokes `claude` and spends your quota.

## What this plugin runs, fetches and sends

The plugin itself contains only skills (instructions to Claude), a session-start reminder hook that
prints one line, and a permissions file. It has no servers, no bundled code and no network calls of
its own. When you invoke a skill, Claude runs these commands in your session:

- **`hee-lee-oss`** (the separately installed `@heeleeoss/cli`) — `init`, `doctor`, `browse`,
  `triage`, `partners`, `pull`, `next`, `status`, `submit`, `complete`, `reopen`.
  - `browse` and `next` download the project registry (a JSON file, by default
    `raw.githubusercontent.com/HeeLeeOss/registry`, configurable as `registryUrl`) with a plain
    HTTPS request. `pull` does not contact the registry: it works from a local task file.
  - `pull` uses `gh`/`git` against GitHub only: it forks and clones the target repository, reads
    the repo's default branch, license, `CONTRIBUTING`/`LICENSE` files and the upstream issue's
    state (assignees, labels, linked pull requests) to check the work is still wanted and free. It
    also reads local files (the task file, the partner registry and the triage skip list).
  - `submit` re-checks the upstream issue, pushes your branch to your fork and opens a pull request.
  - Deed receipts are written to a local Hee-Lee Oss working directory and are not uploaded.
- **`git`** — checkout, add, commit, push, status, rev-parse, in the task workspace.
- **`gh`** (GitHub CLI) — `gh repo fork`, `gh pr create`, `gh api user` and read-only `gh api` /
  `gh pr diff` lookups, using the GitHub account you are already signed in to.

Data leaves your machine only to GitHub (your fork, the pull request and its comments, plus the
read-only lookups above) and, when you run `browse` or `next`, in a download request to the registry
host (GitHub's `raw.githubusercontent.com`), which sends no data of yours. Nothing is sent to Anthropic or any other service by the
plugin, and it never reads or transmits your AI account credentials, `ANTHROPIC_API_KEY` or
GitHub tokens — the skills only *refuse to run* if `ANTHROPIC_API_KEY` is set. Every pull request is
disclosed as AI-assisted. See [PRIVACY.md](https://github.com/jdev1977/hee-lee-oss/blob/main/PRIVACY.md) for the project's data handling.

The plugin pre-approves nothing: Claude Code asks for your permission before running each of these
commands, according to your own permission settings.

## Partner repositories

Many tasks land in a repository Hee-Lee Oss does not own — one that published a needs manifest or
labelled an issue `help wanted`. The flow is identical, but `pull` prints the repo's base branch and
contribution terms (CLA / DCO / licence) first, the work is contributed under **their** licence and
conventions, and the PR discloses that it was AI-assisted. `hee-lee-oss complete` / `reopen` do not
apply upstream. The workspace `CONTEXT.md` carries the full guest rules.
