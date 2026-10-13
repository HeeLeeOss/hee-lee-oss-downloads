#!/usr/bin/env bash
#
# Hee-Lee Oss donated-lane loop: pull the next good-deed task, build it with any registry agent,
# and open a PR. A thin wrapper over the installed `hee-lee-oss` CLI -- it never hardcodes a
# vendor binary. --agent <registry-id> selects ANY agent listed in adapters/registry.json
# (claude-code, aider, codex, gemini-cli, cursor-agent, ...); the CLI's `dispatch` command
# resolves that agent's real command, model, and permission flags for you. See the
# "Registry-driven agents" section in README.md next to this script for how to add or pick an
# agent.
#
# This script never authenticates or installs a coding agent for you -- that's on you, same as
# running it yourself. It only shells out to whatever agent CLI the registry says to run, on your
# own subscription/account (the donated compute lane). Every dispatch resolves the supervised
# (ask-before-edit) permission fragment for the chosen agent -- this loop never escalates to an
# unattended/auto-approve mode.
#
# Usage:
#   ./hee-lee-oss-loop.sh [--count N] [--agent <registry-id>] [--project <slug>] [--lane donated]
#                         [--no-fork] [--dry-run]
#
# Examples:
#   ./hee-lee-oss-loop.sh --count 5
#   ./hee-lee-oss-loop.sh --count 5 --agent gemini-cli
#   ./hee-lee-oss-loop.sh --count 5 --agent codex --project tool-atlas
#
# Requires: node (for the JSON parsing helper below) and the hee-lee-oss CLI on PATH, or a local
# checkout's node_modules/.bin/hee-lee-oss next to this script.

set -u

COUNT=10
AGENT="claude-code"
PROJECT=""
LANE="donated"
NO_FORK=0
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --count) COUNT="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --lane) LANE="$2"; shift 2 ;;
    --no-fork) NO_FORK=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HLO=""
if command -v hee-lee-oss >/dev/null 2>&1; then
  HLO="hee-lee-oss"
elif [ -x "$SCRIPT_DIR/node_modules/.bin/hee-lee-oss" ]; then
  HLO="$SCRIPT_DIR/node_modules/.bin/hee-lee-oss"
else
  echo "hee-lee-oss CLI not found on PATH or at $SCRIPT_DIR/node_modules/.bin/hee-lee-oss." >&2
  echo "Install it first: npm install -g @heeleeoss/cli (see README.md)." >&2
  exit 1
fi

BUILD_PROMPT='Read .hee-lee-oss/TASK.md and .hee-lee-oss/CONTEXT.md, then produce the deliverable at the task output path. Work through EVERY acceptance criterion explicitly and satisfy each one - do not stop until all are met. Honor the refusal guardrails in CONTEXT.md - if the task would cause harm, mislead, give unqualified high-stakes advice without review, primarily benefit a for-profit, or violate a license or privacy, STOP and write nothing.'

# --- JSON field readers: a single small node helper, since jq is not a universal prerequisite but
#     node already is (the CLI itself is a node binary). Never prints the whole payload -- only the
#     requested field -- so nothing sensitive gets echoed by accident.
json_get() {
  # $1 = json string, $2 = dotted path (e.g. "invocation.command" or "auth.scrubEnv" for an array
  # joined with newlines)
  node -e '
    let raw = "";
    process.stdin.on("data", d => raw += d);
    process.stdin.on("end", () => {
      let v;
      try { v = JSON.parse(raw); } catch { process.exit(0); }
      const path = process.argv[1].split(".");
      for (const k of path) { if (v == null) break; v = v[k]; }
      if (Array.isArray(v)) { for (const x of v) process.stdout.write(String(x) + "\n"); }
      else if (v !== undefined && v !== null) { process.stdout.write(String(v) + "\n"); }
    });
  ' "$2" <<<"$1"
}

# --- Generic agent runner: works for ANY registry entry, never hardcodes a vendor binary. The
#     dispatch plan (from `hee-lee-oss dispatch`) carries the resolved command/args/promptChannel
#     plus auth.scrubEnv -- the env vars that must be unset so the call bills to this agent's own
#     subscription/account rather than silently picking up a stray API key. This mirrors (in
#     simplified form) Invoke-Agent in scripts/ignite/HeeLeeOssIgnite.psm1 in the main repo.
invoke_registry_agent() {
  local dispatch_json="$1" prompt="$2" workdir="$3"
  local command promptchannel key_env
  command="$(json_get "$dispatch_json" invocation.command)"
  promptchannel="$(json_get "$dispatch_json" invocation.promptChannel)"
  key_env="$(json_get "$dispatch_json" auth.keyEnv)"
  if [ -z "$command" ]; then
    echo "agent has no CLI invocation" >&2
    return 1
  fi
  local args=()
  while IFS= read -r a; do [ -n "$a" ] && args+=("$a"); done < <(json_get "$dispatch_json" invocation.args)

  local scrub_vars=()
  while IFS= read -r e; do [ -n "$e" ] && scrub_vars+=("$e"); done < <(json_get "$dispatch_json" auth.scrubEnv)

  # Save + unset scrubbed vars; restore unconditionally on return via a trap-free explicit block.
  local -A saved=() had=()
  for e in "${scrub_vars[@]}"; do
    if [ -n "${!e+x}" ]; then
      had[$e]=1
      saved[$e]="${!e}"
      unset "$e"
    fi
  done
  if [ -n "$key_env" ] && [ -n "${had[$key_env]+x}" ]; then
    echo "loop: scrubbed $key_env from the environment for this call (agent stays on your subscription, not billed to API)" >&2
  fi

  (
    cd "$workdir" || exit 1
    if [ "$promptchannel" = "arg" ]; then
      "$command" "${args[@]}" "$prompt"
    else
      printf '%s' "$prompt" | "$command" "${args[@]}"
    fi
  )
  local rc=$?

  for e in "${scrub_vars[@]}"; do
    if [ -n "${had[$e]+x}" ]; then export "$e=${saved[$e]}"; fi
  done
  return $rc
}

built=()
held=()
no_change=()

i=1
while [ "$i" -le "$COUNT" ]; do
  echo ""
  echo "=== deed $i / $COUNT (agent: $AGENT) ==="

  next_args=(next --lane "$LANE")
  [ -n "$PROJECT" ] && next_args+=(--repo "Hee-Lee-Oss-Projects/$PROJECT")
  [ "$NO_FORK" -eq 1 ] && next_args+=(--no-fork)
  out="$("$HLO" "${next_args[@]}" 2>&1)"

  if ! echo "$out" | grep -qE 'HEE_LEE_OSS_NEXT taskId='; then
    if echo "$out" | grep -qi 'session cap'; then
      echo "Session cap reached. Stopping." >&2
    else
      echo "No more eligible tasks - stopping."
    fi
    break
  fi
  line="$(echo "$out" | grep -E 'HEE_LEE_OSS_NEXT taskId=')"
  taskId="$(echo "$line" | sed -E 's/.*taskId=([^ ]+).*/\1/')"
  repo="$(echo "$line" | sed -E 's/.*repo=([^ ]+).*/\1/')"
  ws="$(echo "$line" | sed -E 's/.*workspace=(.+) output=.*/\1/')"

  plan_json="$("$HLO" dispatch --workspace "$ws" --agent "$AGENT" 2>&1)"
  agentId="$(json_get "$plan_json" agentId)"
  if [ -z "$agentId" ]; then
    echo "dispatch failed for $taskId (agent '$AGENT') - skipping." >&2
    echo "$plan_json" >&2
    rm -rf "$ws"
    i=$((i + 1)); continue
  fi
  acceptance="$(json_get "$plan_json" acceptance)"
  kind="$(json_get "$plan_json" kind)"
  model="$(json_get "$plan_json" model)"

  if [ "$acceptance" = "unusable" ]; then
    echo "held: $taskId - agent '$AGENT' is unusable for this deliverable"
    held+=("$taskId (unusable by $AGENT)")
    rm -rf "$ws"
    i=$((i + 1)); continue
  fi
  if [ "$kind" != "cli" ]; then
    echo "held: $taskId - agent '$AGENT' kind '$kind' is not a CLI this loop can drive"
    held+=("$taskId (kind $kind unsupported here)")
    rm -rf "$ws"
    i=$((i + 1)); continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry run] would build $taskId with $AGENT (model $model, acceptance $acceptance)"
    rm -rf "$ws"
    i=$((i + 1)); continue
  fi

  echo "-> building $taskId (agent: $AGENT, model: $model)"
  invoke_registry_agent "$plan_json" "$BUILD_PROMPT" "$ws" >/dev/null

  submit_out="$("$HLO" submit "$taskId" --repo "$repo" --agent "$AGENT" 2>&1)"
  pr_url="$(echo "$submit_out" | grep -oE 'https://github\.com/[^ ]+/pull/[0-9]+' | head -n1)"
  if [ -z "$pr_url" ]; then
    echo "no changes for $taskId - releasing workspace (already done, or needs a human?)."
    no_change+=("$taskId")
    rm -rf "$ws"
    i=$((i + 1)); continue
  fi
  echo "PR: $pr_url"
  built+=("$taskId -> $pr_url")
  rm -rf "$ws"
  i=$((i + 1))
done

echo ""
echo "=== loop finished ==="
echo "PRs opened (${#built[@]}):"
for b in "${built[@]:-}"; do [ -n "$b" ] && echo "  $b"; done
echo "held - needs a human (${#held[@]}):"
for h in "${held[@]:-}"; do [ -n "$h" ] && echo "  $h"; done
echo "no changes (${#no_change[@]}):"
for n in "${no_change[@]:-}"; do [ -n "$n" ] && echo "  $n"; done
"$HLO" status
