<!-- hee-lee-oss:begin -->
## Hee-Lee Oss work rules

This repo may receive contributions from Codex sessions doing Hee-Lee Oss "good deed" tasks
(donated-compute lane, run on the contributor's own account/subscription — never headless,
never metered). Any agent working on a Hee-Lee Oss task in this repo follows these rules,
carried over from the platform's `CLAUDE.md`:

### What Hee-Lee Oss is

A platform that turns spare AI capacity into open-source good deeds, in two lanes: **donated
compute** (the human runs their own agent interactively on their own account) and **funded
escrow** (metered API execution against donor funds, with a public cost ledger). Success is
measured as **outcomes delivered to real beneficiaries**, not tasks merged.

### Architecture rules

- The agent-neutral core (`packages/cli`, `packages/core`, `packages/schema`) must contain no
  vendor/agent-specific logic. Anything tool-specific lives in `adapters/`.
- The CLI never invokes or authenticates a coding agent and never runs headless. It prepares a
  task workspace and opens PRs; the human runs their agent. (Donated lane.)
- The funded lane runs only via `packages/runner` on an API key, always with a hard per-task
  budget cap. It must never exceed the task's escrow.
- Never write secrets, tokens, or API keys into logs, receipts, or committed files.

### Quality bar ("done")

Delivered, not merged: acceptance criteria met + CI green + human approval (+ expert sign-off
for high-stakes `risk-tier`) + the output actually shipped/handed to the beneficiary.

### Refusal guardrails (donated compute must never be steered to harm)

Refuse to perform, and flag, any task that:

- Produces malware, exploits, surveillance tooling, or aids unauthorized access.
- Targets, harasses, deceives, or discriminates against people, or generates disinformation.
- Provides unqualified high-stakes advice (medical, legal, financial, safety) **without** the
  required `risk-tier` expert review.
- Primarily benefits a for-profit entity rather than the public.
- Violates a source's license or a person's privacy (esp. public-data projects: verify the
  dataset license permits reuse/derivatives and record provenance).

When in doubt, stop and surface the concern rather than proceeding.

### Engineering conventions

- TypeScript, ESM, pnpm workspaces. `pnpm build && pnpm test && pnpm lint` must pass.
- Sign off commits (`git commit -s`) per the DCO.
- Add a changeset for user-facing changes.
<!-- hee-lee-oss:end -->
