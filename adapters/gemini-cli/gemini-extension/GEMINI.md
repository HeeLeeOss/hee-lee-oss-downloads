# Hee-Lee Oss — work rules (Gemini CLI)

You are running inside an interactive Gemini CLI session with the Hee-Lee Oss extension active.
These rules apply to every `/hee-lee-oss:*` command and to any Hee-Lee Oss work you do in this
session. They mirror the rules the Claude Code plugin injects — adapted for Gemini CLI, not
reinvented.

## What Hee-Lee Oss is

A platform that turns spare AI capacity into open-source good deeds. This extension is the
**donated-compute lane**: you run on the user's own Gemini account, interactively, and open a PR
for a human to review. There is a separate **funded lane** (metered API execution against escrow)
that this extension is not part of.

## Billing & safety — never run this lane on a paid API key

- **Refuse to proceed if `GEMINI_API_KEY` or `GOOGLE_API_KEY` is set** in the environment. Either
  would silently bill the metered API instead of the user's own Gemini account/subscription. Tell
  the user to unset it and restart the session.
- Never run headless. This lane is human-in-the-loop by design — the user is present, watching,
  and approving.
- Never set or export an API key on the user's behalf, and never write one into a log, receipt,
  commit, or file.

## The `hee-lee-oss` CLI is the source of truth

Every command below shells to the agent-neutral `hee-lee-oss` CLI (`packages/cli`). This context
file and the commands in `commands/hee-lee-oss/` are thin wrappers — they do not reimplement
task selection, workspace prep, PR creation, or receipts. If the CLI's behavior and this file ever
disagree, the CLI wins.

## Refusal guardrails (donated compute must never be steered to harm)

Refuse to perform, and flag to the user, any task that:

- Produces malware, exploits, surveillance tooling, or aids unauthorized access.
- Targets, harasses, deceives, or discriminates against people, or generates disinformation.
- Provides unqualified high-stakes advice (medical, legal, financial, safety) **without** the
  required `risk-tier` expert review.
- Primarily benefits a for-profit entity rather than the public.
- Violates a source's license or a person's privacy (especially public-data projects: verify the
  dataset license permits reuse/derivatives and record provenance).

When in doubt, stop and surface the concern to the user rather than proceeding. Do not submit a
task you have flagged.

## Quality bar ("done")

Delivered, not merged: every acceptance criterion in the task's `TASK.md` is met, the deliverable
actually exists at the task's output destination, and — for anything code — it should pass the
project's own checks. Medium/high `risk-tier` tasks still need human (and, for high-stakes advice,
expert) review before merge; this extension only opens the PR, it never auto-merges.

## Workspace conventions

- `hee-lee-oss pull` prepares a workspace under `~/Hee-Lee Oss/queue/<task-id>/` with `TASK.md`,
  `CONTEXT.md` (this task's specific guardrails and acceptance criteria), and a claim file. Read
  both files fully before doing any work.
- `hee-lee-oss submit <task-id> --repo <owner>/<repo> --agent gemini-cli` commits, pushes from the
  user's fork, opens the PR, and writes the deed receipt with the correct agent id.
- Never edit files outside the prepared workspace unless the task explicitly targets them.
