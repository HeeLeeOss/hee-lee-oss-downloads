# Hee-Lee Oss Downloads

Everything you need to run good-deed work against [Hee-Lee Oss projects](https://github.com/HeeLeeOss) using your own AI agent.

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
| `scripts/hee-lee-oss-loop.ps1` | Registry-driven PowerShell loop — runs tasks one after another up to your limit with any registered agent (`-Agent <id>`) |
| `scripts/hee-lee-oss-loop.sh` | Same loop for macOS / Linux (`--agent <id>`) |
| `scripts/README.md` | Full reference for the loop scripts: flags, registry-driven agent model, secrets/billing safety |
| `adapters/registry.json` | Reference copy of the agent registry the loop scripts read (`argsTemplate`, model tiers, permission fragments, auth scrub vars) — the installed `hee-lee-oss` CLI ships its own copy; this one is for browsing/documentation |
| `adapters/claude-code/` | Full Claude Code plugin — `/hee-lee-oss:start`, `/hee-lee-oss:next`, `/hee-lee-oss:status` |
| `adapters/gemini-cli/` | Gemini CLI extension + setup guide |
| `adapters/codex/` | Codex CLI custom prompts + `AGENTS.md` snippet + installer |
| `adapters/kimi/` | Kimi (Moonshot) Code CLI skills + `AGENTS.md` snippet + installer |
| `adapters/cursor/` | Cursor Agent CLI setup guide (registry id: `cursor-agent`) |
| `adapters/copilot/` | GitHub Copilot CLI setup guide |
| `adapters/aider/` | Aider setup guide |
| `docs/getting-started.md` | Step-by-step first-deed walkthrough |
| `docs/looping.md` | How to loop through dozens of tasks in one session |
| `SIGNUP.md` | **For maintainers** — ask for donated capacity by adding one file to your repo |
| `docs/heeleeoss.example.yml` | Annotated needs-manifest template to copy into `.github/heeleeoss.yml` |

<p align="center"><img src="https://raw.githubusercontent.com/HeeLeeOss/.github/main/assets/divider.svg" width="100%" height="6" alt=""/></p>

## 🟢 Maintain a project? Ask for capacity

If you maintain an open project that serves the public good and you're short of hands, you can ask
for donated capacity by adding **one file** to your repository. See **[SIGNUP.md](SIGNUP.md)**.

Merging it is the whole opt-in; deleting it opts you back out. We never send unsolicited work.

<p align="center"><img src="https://raw.githubusercontent.com/HeeLeeOss/.github/main/assets/divider.svg" width="100%" height="6" alt=""/></p>

## 🟠 Quick start

### 1 — Install the Hee-Lee Oss CLI

```bash
npm install -g @heeleeoss/cli
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

**Working a partner repository?** Many tasks land in projects Hee-Lee Oss does not own — ones that
published a needs manifest or labelled an issue `help wanted`. The flow is identical, with three
differences: `hee-lee-oss pull` prints that repo's real base branch and its contribution terms
(CLA / DCO / licence) *before* you start; your work is contributed under **their** licence and
conventions and the PR discloses that it was AI-assisted; and `hee-lee-oss complete` / `reopen` do
not apply — upstream, the pull request being merged or closed is the state.

### 4 — Loop through many deeds automatically

**Windows (PowerShell):**
```powershell
.\scripts\hee-lee-oss-loop.ps1 -Count 20 -Agent claude-code
```

**macOS / Linux (bash):**
```bash
bash scripts/hee-lee-oss-loop.sh --count 20 --agent claude-code
```

Both default to `claude-code` if you omit `-Agent`/`--agent`. Swap in any id from
`adapters/registry.json` — `gemini-cli`, `codex`, `aider`, `kimi`, `cursor-agent`, `copilot` — and
the script resolves that agent's real command, model, and permission flags for you; no script
edits needed. See [`scripts/README.md`](scripts/README.md) for the full registry-driven flag
reference and [`docs/looping.md`](docs/looping.md) for the guide on running near your limits.

<p align="center"><img src="https://raw.githubusercontent.com/HeeLeeOss/.github/main/assets/divider.svg" width="100%" height="6" alt=""/></p>

## 🔴 Donated compute lane

The loop and adapters in this repo use the **donated compute lane**: your own AI subscription, running interactively on your own machine. Hee-Lee Oss never touches your credentials or bills anything beyond what you already pay.

<p align="center">
  <img src="https://raw.githubusercontent.com/HeeLeeOss/.github/main/assets/credits-meter-good.svg" alt="Usage credits: 99% used. Put the capacity to work, for good." width="100%" />
</p>

**Critical rule:** do not set the API key env var for whichever agent you're running (e.g.
`ANTHROPIC_API_KEY` for Claude Code, `OPENAI_API_KEY` for Codex, `GEMINI_API_KEY`/`GOOGLE_API_KEY`
for Gemini CLI, `MOONSHOT_API_KEY` for Kimi) — that would bill the pay-as-you-go API instead of
your subscription. The loop scripts scrub every registry-declared provider key
(`adapters/registry.json`'s `auth.scrubEnv` per agent) for the duration of each agent call and
restore it immediately after, and only ever print a non-secret notice that a scrub happened.

<p align="center"><img src="https://raw.githubusercontent.com/HeeLeeOss/.github/main/assets/divider.svg" width="100%" height="6" alt=""/></p>

## 🟡 Pick your agent

| Agent | Registry id | Setup |
|---|---|---|
| Claude Code | `claude-code` | [`adapters/claude-code/`](adapters/claude-code/) — plugin with guided skills |
| Gemini CLI | `gemini-cli` | [`adapters/gemini-cli/`](adapters/gemini-cli/) — extension with guided commands |
| Codex CLI | `codex` | [`adapters/codex/`](adapters/codex/) — custom prompts + `AGENTS.md` snippet |
| Kimi (Moonshot) | `kimi` | [`adapters/kimi/`](adapters/kimi/) — skills + `AGENTS.md` snippet |
| Cursor Agent CLI | `cursor-agent` | [`adapters/cursor/`](adapters/cursor/) |
| GitHub Copilot CLI | `copilot` | [`adapters/copilot/`](adapters/copilot/) |
| Aider | `aider` | [`adapters/aider/`](adapters/aider/) |

<p align="center"><img src="https://raw.githubusercontent.com/HeeLeeOss/.github/main/assets/divider.svg" width="100%" height="6" alt=""/></p>

## 🟠 More

- [Hee-Lee Oss org](https://github.com/HeeLeeOss) — browse all 128+ project repos
- [Registry](https://github.com/HeeLeeOss/registry) — approved project index
- [Propose a new project](https://github.com/HeeLeeOss/registry/issues)

<p align="center">
  <img src="https://raw.githubusercontent.com/HeeLeeOss/.github/main/assets/footer-banner.svg" alt="Hee-Lee Oss — put the capacity to work." width="100%" />
</p>
