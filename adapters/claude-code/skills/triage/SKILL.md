---
description: Triage a partner's labelled issues in THIS interactive session — sweep, research one with commit evidence, judge it, and draft one gated comment for the user to approve. Use when the user runs /hee-lee-oss:triage (optionally with a repo, or a repo and issue number).
disable-model-invocation: true
---

# /hee-lee-oss:triage — tell a project what is already done

A triage deed is one sentence in someone else's tracker, backed by a commit they can check. It is
only worth posting when it is **true, invited, and not already said**. The tool gathers evidence;
**you judge it**; the user approves every comment.

## 0. Pre-flight

- **Refuse if `ANTHROPIC_API_KEY` is set** (donated lane — must stay on the subscription).
- Run `hee-lee-oss doctor`.
- Parse `$ARGUMENTS`: nothing (ask which partner), `<owner/repo>`, or `<owner/repo> <issue>`.

## 1. Health first

`hee-lee-oss partners check --repo <repo>` (report-only; never add `--write` unless the user asks).
If it proposes a **pause** (opt-out or licence), STOP and tell the user — the invitation we work
under has been withdrawn. Mention any notes (our merged PRs not yet recorded, review comments
waiting on us).

## 2. Pick an issue

- With an issue number: go to step 3.
- Otherwise: `hee-lee-oss triage scan --repo <repo>`. Show the user the ranked table. The outcomes
  are **suggestions**. Let the user pick; recommend the top `obsolete` / `superseded` /
  `already-merged` / `resolved` row if there is one. (`--json` emits `{partial, failed, results}`; a partial run exits
  1 — say so, the table is incomplete.)

## 3. Research

`hee-lee-oss triage research --repo <repo> --issue <n> --out triage-<n>.json`

## 4. Judge — this is the deed

Read the issue in full, the dossier, **and the actual diffs** (`gh api repos/<repo>/commits/<sha>`
or `gh pr diff <url>`). Answer every checklist item the tool printed, in your own words, to the user.

- `never-present` claims are not evidence of anything being fixed. Explain them; do not post.
- A merged PR that _mentions_ the issue is not proof it _resolved_ it. Read what it changed. Pull
  request evidence only counts when its `change` is "merged".
- A removed file may have moved. Search for its headings before calling it `obsolete`.
- "Not resolved", "only partly", and "not sure" are valid, good endings. Say so and stop. For
  `still-valid`, offer: `hee-lee-oss triage task --finding triage-<n>.json --project <id>`
  (the project id is a lowercase slug; the command never overwrites an existing task).

Only if the evidence holds, add to the dossier JSON. For a `still-valid` issue the judgment is
required too: write `"outcome": "still-valid"` with real `judgedBy`/`judgedAt` and a `verifiedBy` saying
what you checked, _then_ run `triage task` (it refuses without it). That posts nothing.

```json
"judgment": {
  "outcome": "obsolete",
  "evidenceIds": ["e1"],
  "verifiedBy": "what you actually read — which diff, which file at which sha",
  "doubts": "anything you are unsure of, or omit",
  "judgedBy": "claude-code",
  "judgedAt": "<ISO-8601 now>"
}
```

`judgedAt` must be a valid ISO-8601 timestamp and `judgedBy` non-empty, or the gate refuses.

## 5. Draft

`hee-lee-oss triage --finding triage-<n>.json` — prints the exact comment, or the reasons it is
refused. Show the user the comment **and** the evidence behind it.

## 6. Post — only on an explicit yes for this comment

Ask the user for an explicit yes to this specific comment. Silence, or a yes to an earlier comment,
is not a yes. Then run `hee-lee-oss triage --finding triage-<n>.json --post`. Approval of one comment
never carries to the next. Report the comment URL and what was recorded (partner registry, receipt).

## Rules that bind here

- One comment per issue, ever. Never comment on someone else's pull request.
- Never triage a security-sensitive issue in public.
- Never write another project's issue as `owner/repo#number` outside their own tracker.
- Posting re-checks live state and refuses on any change since research (title, labels, body, a new
  resolution comment, a security label) and whenever any pull request is open against the issue. Research again; don't force.
- `pull`, `submit` and `next` refuse partners whose consent was withdrawn (`--partners <registry>`).
