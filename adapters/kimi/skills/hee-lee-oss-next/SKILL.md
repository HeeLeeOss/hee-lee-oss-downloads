---
name: hee-lee-oss-next
description: Pull and complete the NEXT Hee-Lee Oss good-deed task in this interactive Kimi Code CLI session, continuing a session started with /skill:hee-lee-oss-start.
---

# /skill:hee-lee-oss-next — do the next deed

Continue a Hee-Lee Oss session with the next task. Same rules as `/skill:hee-lee-oss-start`:

1. **Pre-flight:** refuse if `MOONSHOT_API_KEY` is set (must stay on my own account/subscription
   — see `adapters/kimi/AGENTS.md` for why).
2. Check the budget guard: run `hee-lee-oss status`. If active claims have reached the
   configured `maxTasksPerSession`, stop and tell me the session cap is reached.
3. Pick the next task (`hee-lee-oss browse`, or a task file path I give you directly).
4. `hee-lee-oss pull --task-file <path> --dry-run`, then `hee-lee-oss pull --task-file
   <path>`.
5. Do the work in the workspace, honoring the refusal guardrails in `adapters/kimi/AGENTS.md`
   (and repeated in the workspace's `CONTEXT.md`).
6. `hee-lee-oss submit <task-id> --repo <owner>/<repo> --agent kimi`; share the PR URL.
7. Offer another, or stop gracefully.

This skill is for looping through tasks while I am present. It is interactive — never headless,
never with `MOONSHOT_API_KEY` set.
