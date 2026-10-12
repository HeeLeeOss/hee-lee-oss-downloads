# Hee-Lee Oss — GitHub Copilot CLI adapter

Registry entry for GitHub's agentic terminal CLI (binary: `copilot`, npm package `@github/copilot`)
as a first-class `kind: "cli"` agent (`adapters/registry.json`, id `copilot`). Support is gated on
the conformance eval (multiagenttasks.md B4) — this README documents intent, the eval is the
arbiter of whether the flag surface below actually works end to end.

## Install

```bash
npm install -g @github/copilot   # requires Node 22+
copilot --version
# authenticate with an existing GitHub Copilot subscription (Pro/Pro+/Business/Enterprise)
```

## How the registry entry invokes it

```jsonc
"invocation": {
  "command": "copilot",
  "argsTemplate": ["--model", "{model}", "{permissions}", "-p"],
  "promptChannel": "arg",
  "permissions": { "unattended": ["--allow-all-tools", "--no-ask-user"] }
}
```

- `-p` (a.k.a. `--prompt`) runs Copilot CLI non-interactively: it takes the prompt as its next
  argument, executes, and exits. `-p` is placed **last** in the template (same reasoning as
  `gemini-cli`'s entry) so the dispatcher's arg-mode prompt append lands immediately after it as
  `-p`'s value, not swallowed by an earlier flag.
- There is **no `permissions.supervised` fragment** (same precedent as `cursor-agent`): Copilot
  CLI's default tool-approval behavior is interactive (asks in the terminal), which has no
  meaningful analog when spawned headlessly with no attached TTY — there's nothing to approve
  against. `unattended: ["--allow-all-tools", "--no-ask-user"]` is the documented combination for
  running fully non-interactively: `--allow-all-tools` skips the per-tool approval prompt,
  `--no-ask-user` stops the agent from pausing to ask a clarifying question it can never receive an
  answer to. GitHub's own docs warn against `--allow-all-tools` outside a sandboxed context —
  this is exactly why it only appears in the opt-in `unattended` fragment, never the default.
- `tierModels`: **model choice is subscription-plan-dependent** (Free/Pro/Pro+/Business/Enterprise
  each expose a different model list), so — like `cursor-agent` — this entry uses a single model
  string at all three tiers rather than a real tier ladder: `claude-sonnet-4.5` (Copilot CLI's
  documented default as of mid-2026). **Flagged as the weakest-verified field**: GitHub ships model
  updates frequently (e.g. Claude Sonnet 5 went GA for Copilot on 2026-06-30) and a plan without
  access to the declared model will error or silently substitute — operators should override
  `tierModels` to match their actual plan/entitlement, and the conformance eval should assert the
  configured model is actually reachable before trusting this entry.

## Auth

**Verified, declared only what's confirmed**: GitHub Copilot CLI reads a token in this
precedence order: `COPILOT_GITHUB_TOKEN` > `GH_TOKEN` > `GITHUB_TOKEN`. All three authenticate
*identity* (which GitHub account/Copilot subscription is billed) — none of them is an equivalent
to `ANTHROPIC_API_KEY`/`OPENAI_API_KEY`/`GEMINI_API_KEY`/`MOONSHOT_API_KEY` (a key that silently
flips a *subscription* agent onto *metered per-token API billing*). Copilot CLI billing runs
through the Copilot subscription regardless of which of those three tokens supplies the GitHub
identity, so there is no known "flip to metered billing" var to scrub yet.

Per the task instruction: declare only what's verified. This entry ships `auth.scrubEnv: []` and
no `auth.keyEnv`. If GitHub later exposes billing outside the Copilot subscription (e.g. an
Anthropic-style pay-per-token API key), add `keyEnv` then.

## Fallback path

No plugin or native config ships in this directory yet (Workstream C notes Copilot's native
mechanism as a repo/user instructions file, not yet built here). Until then, use the universal CLI
flow:

```bash
hee-lee-oss pull --task-file <task.json>
# do the work with Copilot in the workspace folder
hee-lee-oss submit <task-id> --repo <owner>/<repo> --agent copilot
```

## Status

Not yet conformance-passed. Treat every flag above as "best-documented as of July 2026, unverified
in this repo" until `adapters/_conformance/` (B4) runs a golden task through `computeDispatch` and
the real `copilot` binary and records a passing receipt. Do not mark this agent `trusted: true` in
`adapters/registry.json` until that gate passes.

## Partner repositories

Many tasks land in a repository Hee-Lee Oss does not own — one that published a needs manifest or
labelled an issue `help wanted`. The flow is identical, but `pull` prints the repo's base branch and
contribution terms (CLA / DCO / licence) first, the work is contributed under **their** licence and
conventions, and the PR discloses that it was AI-assisted. `hee-lee-oss complete` / `reopen` do not
apply upstream. The workspace `CONTEXT.md` carries the full guest rules.
