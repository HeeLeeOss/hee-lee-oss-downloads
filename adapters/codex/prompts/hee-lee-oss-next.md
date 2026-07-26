---
description: Pull and complete the NEXT Hee-Lee Oss good-deed task in this interactive Codex session, continuing a session started with /prompts:hee-lee-oss-start.
argument-hint: "[TASK_FILE=<path>]"
---

# Hee-Lee Oss — do the next deed

Continue a Hee-Lee Oss session with the next task. Same rules as `/prompts:hee-lee-oss-start`:

1. **Pre-flight:** refuse if `OPENAI_API_KEY` is set (must stay on my subscription/own
   account).
2. Check the budget guard: run `hee-lee-oss status`. If active claims have reached the
   configured `maxTasksPerSession`, stop and tell me the session cap is reached.
3. Pick the next task (`hee-lee-oss browse`, or the file at `TASK_FILE=$TASK_FILE` if I gave
   one).
4. `hee-lee-oss pull --task-file $TASK_FILE --dry-run`, then `hee-lee-oss pull --task-file
   $TASK_FILE`.
5. Do the work in the workspace, honoring the refusal guardrails carried in the installed
   `AGENTS.md` snippet (and repeated in the workspace's `CONTEXT.md`).
6. `hee-lee-oss submit <task-id> --repo <owner>/<repo> --agent codex`; share the PR URL.
7. Offer another, or stop gracefully.

This prompt is for looping through tasks while I am present. It is interactive — never
headless, never with `OPENAI_API_KEY` set.
