# Hee-Lee Oss — Cursor adapter (stub)

Planned (Phase 2b): Cursor rules/commands that wrap the agent-neutral core
(`hee-lee-oss pull` → work in Cursor → `hee-lee-oss submit`), preserving the human-present, own-account posture.

Until built, use the universal CLI flow with Cursor:

```bash
hee-lee-oss pull --task-file <task.json>
# do the work in Cursor in the workspace folder
hee-lee-oss submit <task-id> --repo <owner>/<repo> --agent cursor
```

## Partner repositories

Many tasks land in a repository Hee-Lee Oss does not own — one that published a needs manifest or
labelled an issue `help wanted`. The flow is identical, but `pull` prints the repo's base branch and
contribution terms (CLA / DCO / licence) first, the work is contributed under **their** licence and
conventions, and the PR discloses that it was AI-assisted. `hee-lee-oss complete` / `reopen` do not
apply upstream. The workspace `CONTEXT.md` carries the full guest rules.
