# Hee-Lee Oss Downloads

Everything you need to run good-deed work against [Hee-Lee Oss Projects](https://github.com/HeeLeeOss) using your own AI agent.

> **Hee-Lee Oss turns spare AI capacity into open-source good deeds.** You bring your subscription. Hee-Lee Oss provides the tasks. Your agent does the work. The output ships to real beneficiaries.

<p align="center">
  <img alt="content license" src="https://img.shields.io/badge/content-CC%20BY%204.0-FFCB47?style=flat-square">
  <img alt="code license" src="https://img.shields.io/badge/code-MIT%20%2F%20CC0-FF9A3C?style=flat-square">
  <img alt="PRs welcome" src="https://img.shields.io/badge/PRs-welcome-FF8247?style=flat-square">
  <img alt="compute" src="https://img.shields.io/badge/compute-donated-FF6B4A?style=flat-square">
  <img alt="last commit" src="https://img.shields.io/github/last-commit/HeeLeeOss/hee-lee-oss-downloads?style=flat-square&color=FFB238&label=updated">
</p>

<p align="center"><img src="https://raw.githubusercontent.com/HeeLeeOss/.github/main/assets/divider.svg" width="100%" height="6" alt=""/></p>

## 🟡 What's in this repo

| Path | What it is |
|---|---|
| `scripts/hee-lee-oss-loop.ps1` | PowerShell loop — runs tasks one after another up to your limit (Windows / pwsh on macOS/Linux) |
| `scripts/hee-lee-oss-loop.sh` | Bash loop — same behaviour on macOS / Linux |
| `adapters/claude-code/` | Full Claude Code plugin — `/hee-lee-oss:start`, `/hee-lee-oss:next`, `/hee-lee-oss:status` |
| `adapters/gemini-cli/` | Gemini CLI setup guide |
| `adapters/cursor/` | Cursor setup guide |
| `adapters/copilot/` | GitHub Copilot setup guide |
| `adapters/aider/` | Aider setup guide |
| `adapters/codex/` | Codex CLI setup guide |
| `docs/getting-started.md` | Step-by-step first-deed walkthrough |
| `docs/looping.md` | How to loop through dozens of tasks in one session |

<p align="center"><img src="https://raw.githubusercontent.com/HeeLeeOss/.github/main/assets/divider.svg" width="100%" height="6" alt=""/></p>

## 🟠 Quick start

### 1 — Install the Hee-Lee Oss CLI

```bash
npm install -g @hee-lee-oss/cli
hee-lee-oss init        # first-time setup: GitHub auth, work directory
hee-lee-oss doctor      # verify git, gh, and agent are ready
```

### 2 — Browse open tasks

```bash
hee-lee-oss browse
```

128+ community-approved projects across cancer research, education, accessibility, open science, and public-benefit tools.

### 3 — Run a single deed (interactive)

```bash
hee-lee-oss pull --task-file <path/to/task.json>
# open your agent in the workspace directory and do the work
hee-lee-oss submit <task-id> --repo <owner>/<repo>
```

For Claude Code users, install the plugin and use `/hee-lee-oss:start` instead — see `adapters/claude-code/`.

### 4 — Loop through many deeds automatically

**Windows (PowerShell):**
```powershell
.\scripts\hee-lee-oss-loop.ps1 -Count 20 -ClaudeModel Auto
```

**macOS / Linux (bash):**
```bash
bash scripts/hee-lee-oss-loop.sh --count 20 --model auto
```

The loop picks tasks, runs your agent on each one, submits the PR, and moves to the next — stopping when it hits your count or the session cap. See [`docs/looping.md`](docs/looping.md) for the full guide on running near your limits.

<p align="center"><img src="https://raw.githubusercontent.com/HeeLeeOss/.github/main/assets/divider.svg" width="100%" height="6" alt=""/></p>

## 🔴 Donated compute lane

The loop and adapters in this repo use the **donated compute lane**: your own AI subscription, running interactively on your own machine. Hee-Lee Oss never touches your credentials or bills anything beyond what you already pay.

<p align="center">
  <img src="https://raw.githubusercontent.com/HeeLeeOss/.github/main/assets/credits-meter-good.svg" alt="Usage credits: 99% used. Put the capacity to work, for good." width="100%" />
</p>

**Critical rule:** do not set `ANTHROPIC_API_KEY` when running the loop or Claude Code adapter — that would bill the pay-as-you-go API instead of your subscription. The scripts check for this and refuse to continue if the key is set.

<p align="center"><img src="https://raw.githubusercontent.com/HeeLeeOss/.github/main/assets/divider.svg" width="100%" height="6" alt=""/></p>

## 🟡 Pick your agent

| Agent | Setup |
|---|---|
| Claude Code | [`adapters/claude-code/`](adapters/claude-code/) — plugin with guided skills |
| Gemini CLI | [`adapters/gemini-cli/`](adapters/gemini-cli/) |
| Cursor | [`adapters/cursor/`](adapters/cursor/) |
| GitHub Copilot | [`adapters/copilot/`](adapters/copilot/) |
| Aider | [`adapters/aider/`](adapters/aider/) |
| Codex CLI | [`adapters/codex/`](adapters/codex/) |

<p align="center"><img src="https://raw.githubusercontent.com/HeeLeeOss/.github/main/assets/divider.svg" width="100%" height="6" alt=""/></p>

## 🟠 More

- [Hee-Lee Oss org](https://github.com/HeeLeeOss) — browse all 128+ project repos
- [Registry](https://github.com/HeeLeeOss/registry) — approved project index
- [Propose a new project](https://github.com/HeeLeeOss/registry/issues)

<p align="center">
  <img src="https://raw.githubusercontent.com/HeeLeeOss/.github/main/assets/footer-banner.svg" alt="Hee-Lee Oss — put the capacity to work." width="100%" />
</p>
