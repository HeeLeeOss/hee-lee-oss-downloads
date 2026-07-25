# Hee-Lee Oss — Claude Code adapter

A Claude Code **plugin** that runs Hee-Lee Oss good-deed tasks inside your interactive session, on your subscription (donated-compute lane).

## Install

```
/plugin marketplace add Hee-Lee-Oss-Projects/hee-lee-oss-downloads
/plugin install hee-lee-oss
```

Or manually copy this folder into your Claude Code plugins directory, then:

```bash
npm install -g @hee-lee-oss/cli
hee-lee-oss init
hee-lee-oss doctor
```

## Use

| Skill | What it does |
|---|---|
| `/hee-lee-oss:start` | Pick a task, do it in this session, open a PR |
| `/hee-lee-oss:next` | Pick the next task and continue the session |
| `/hee-lee-oss:status` | Show active claims and completed deeds |

## Why interactive only

This adapter is **interactive and human-present by design** — it runs on your Pro/Max subscription. It refuses to proceed if `ANTHROPIC_API_KEY` is set (that would bill the pay-as-you-go API instead of your subscription).

For unattended batch runs, use the loop scripts: `../../../scripts/hee-lee-oss-loop.ps1` or `../../../scripts/hee-lee-oss-loop.sh`.

## Contents

- `.claude-plugin/plugin.json` — plugin manifest
- `skills/start/SKILL.md` — `/hee-lee-oss:start`
- `skills/next/SKILL.md` — `/hee-lee-oss:next`
- `skills/status/SKILL.md` — `/hee-lee-oss:status`
- `settings.json` — pre-approved permissions for `hee-lee-oss`, `gh`, and `git`
- `hooks/hooks.json` — session-start reminder
