# Hee-Lee Oss — Aider adapter

A registry entry for Paul Gauthier's agentic terminal CLI (binary: `aider`) as a first-class `kind: "cli"` agent (`adapters/registry.json`, id `aider`). Support is gated on the conformance eval (multiagenttasks.md B4) — this README documents intent, the eval is the arbiter of whether the flag surface below actually works end to end.

## Install

Aider can be installed via pip (recommended, most up-to-date) or npm:

```bash
# via pip
pip install aider-chat
# or: npm install -g aider-chat

aider --version
```

See https://aider.chat/install.html for the latest installation methods and platform-specific guidance.

## How the registry entry invokes it

```jsonc
"invocation": {
  "command": "aider",
  "argsTemplate": ["--model", "{model}", "{permissions}", "--no-auto-commits", "--message"],
  "promptChannel": "arg",
  "permissions": {
    "supervised": ["--yes"],
    "unattended": ["--yes-always"]
  }
}
```

- `--message` (arg prompt mode) takes the task prompt as its final argument, executes, and exits — the mode `hee-lee-oss`/ignite need for headless dispatch.
- `--no-auto-commits` disables Aider's default auto-commit behavior so the submitted PR reflects a deliberate, reviewable changeset.
- Permission fragments: `supervised: ["--yes"]` auto-approves file edits interactively (default lane); `unattended: ["--yes-always"]` skips all approval prompts (opt-in, trusted content tasks only).

## How ignite drives it

```bash
hee-lee-oss dispatch --workspace <ws> --agent aider  # resolves model + invocation
hee-lee-oss next --lane donated --agent aider        # picks a task
# ignite spawns: aider --model anthropic/claude-sonnet-4-5 --yes --no-auto-commits --message "<prompt>"
hee-lee-oss submit <task-id> --agent aider           # open a PR
```

Or manually use the universal CLI flow:

```bash
hee-lee-oss pull --task-file <task.json>
aider --model anthropic/claude-sonnet-4-5 --yes --no-auto-commits --message "<prompt>"  # in workspace
hee-lee-oss submit <task-id> --repo <owner>/<repo> --agent aider
```

## Auth & billing

Aider is provider-agnostic and reads API keys via litellm conventions. This entry declares `auth.scrubEnv: ["ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY"]` to defend against all major coding-model providers (aider can bill via any of them). On the donated lane, scrubbing ensures your subscription credentials never leak into Aider's subprocess; the provider is configured outside the task (e.g. in your `.env` or Aider's own config file). Model names are provider-prefixed (`anthropic/claude-*`, `openai/gpt-*`, etc.) to route to the right backend.

## Model tiers

Provider-prefixed model ids per tier (Anthropic models shown; adjust the provider prefix for your billing):

- **frontier**: `anthropic/claude-opus-4-8`
- **standard**: `anthropic/claude-sonnet-4-5`
- **light**: `anthropic/claude-haiku-4-5`

## Status

Not yet conformance-passed. Treat every flag above as "best-documented as of July 2026, unverified in this repo" until `adapters/_conformance/` (B4) runs a golden task through `computeDispatch` and the real `aider` binary and records a passing receipt. Do not mark this agent `trusted: true` in `adapters/registry.json` until that gate passes.
