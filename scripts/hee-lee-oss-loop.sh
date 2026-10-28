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

# Release a slot's workspace before submit has run, unless the deed was resumed with an answered question.
release_ws() {
  if [ -n "$resume" ]; then
    echo "keeping $taskId's files: it was resumed with an answered question and its build has not launched; the next run picks it up again"
  else
    rm -rf "$ws"
  fi
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

# The HEE_LEE_OSS_NEXT / HEE_LEE_OSS_SUBMIT lines start their fields with v=1. machine_fields MARKER LINE
# puts the fields after the marker (and after v=1) in MF_REST. A line with no v= is read as version 1 with
# a one-time warning; any other version is refused (return 1, message on stderr naming it).
nov_warned=""
machine_fields() {
  local marker="$1" line rest ver
  line="$(printf '%s' "$2" | tr -d '\r')"
  rest="${line#*"$marker"}"
  rest="${rest#"${rest%%[![:space:]]*}"}"
  case "$rest" in
    v=1|v=1[[:space:]]*)
      rest="${rest#v=1}"; rest="${rest#"${rest%%[![:space:]]*}"}" ;;
    v=*)
      ver="${rest%%[[:space:]]*}"; ver="${ver#v=}"
      echo "loop: the $marker line is version ${ver:-(empty)}, but this script only understands version 1 - update it (re-download hee-lee-oss-loop.sh)." >&2
      MF_REST=""; return 1 ;;
    *)
      case "$nov_warned" in *"|$marker|"*) ;; *)
        echo "loop: the $marker line has no v= field; reading it as version 1 (a newer hee-lee-oss prints v=1)." >&2
        nov_warned="$nov_warned|$marker|" ;;
      esac ;;
  esac
  MF_REST="$rest"
  return 0
}

built=()
held=()
no_change=()

stop_warned=0
i=1
while [ "$i" -le "$COUNT" ]; do
  echo ""
  echo "=== deed $i / $COUNT (agent: $AGENT) ==="

  # A STOP file (written by a submit gate block) halts the loop before it pulls more work.
  # Halt only when the CLI really reports a STOP file; an older CLI without `stop` just warns once.
  stop_rc=0
  stop_out="$("$HLO" stop --status 2>&1)" || stop_rc=$?
  if [ "$stop_rc" -ne 0 ]; then
    if echo "$stop_out" | grep -qi 'unknown command' || ! echo "$stop_out" | grep -q 'STOP'; then
      if [ "$stop_warned" -eq 0 ]; then
        echo "loop: this CLI predates 'hee-lee-oss stop'; update with npm install -g @heeleeoss/cli (held/blocked outcomes cannot be detected until then)" >&2
        stop_warned=1
      fi
    else
      echo "STOP is set - not pulling more work. Run 'hee-lee-oss stop --status' and clear it only after reading why." >&2
      echo "$stop_out" >&2
      break
    fi
  fi

  next_args=(next --lane "$LANE")
  [ -n "$PROJECT" ] && next_args+=(--repo "Hee-Lee-Oss-Projects/$PROJECT")
  [ "$NO_FORK" -eq 1 ] && next_args+=(--no-fork)
  out="$("$HLO" "${next_args[@]}" 2>&1)"

  line="$(printf '%s\n' "$out" | tr -d '\r' | grep -E '^[[:space:]]*HEE_LEE_OSS_NEXT([[:space:]]|$)' | tail -n1)"
  if [ -z "$line" ]; then
    if echo "$out" | grep -qi 'session cap'; then
      echo "Session cap reached. Stopping." >&2
    else
      echo "No more eligible tasks - stopping."
    fi
    break
  fi
  # A version this script does not understand stops the loop visibly rather than guessing at the fields.
  machine_fields HEE_LEE_OSS_NEXT "$line" || break
  fields="$MF_REST"
  taskId="$(echo "$fields" | sed -nE 's/.*(^| )taskId=([^ ]+).*/\2/p')"
  repo="$(echo "$fields" | sed -nE 's/.*(^| )repo=([^ ]+).*/\2/p')"
  ws="$(echo "$fields" | sed -nE 's/.*workspace=(.+) output=.*/\1/p')"
  # resume=question: the deed was resumed after a person answered its question. Until submit has run,
  # releasing it would lose the answer and the work, so its workspace is never removed before then.
  resume="$(echo "$fields" | sed -nE 's/.*(^| )resume=([^ ]+).*/\2/p')"
  if [ -z "$taskId" ] || [ -z "$repo" ] || [ -z "$ws" ]; then
    echo "No more eligible tasks - stopping (the HEE_LEE_OSS_NEXT line could not be read: $line)." >&2
    break
  fi

  plan_json="$("$HLO" dispatch --workspace "$ws" --agent "$AGENT" 2>&1)"
  agentId="$(json_get "$plan_json" agentId)"
  if [ -z "$agentId" ]; then
    echo "dispatch failed for $taskId (agent '$AGENT') - skipping." >&2
    echo "$plan_json" >&2
    release_ws
    i=$((i + 1)); continue
  fi
  acceptance="$(json_get "$plan_json" acceptance)"
  kind="$(json_get "$plan_json" kind)"
  model="$(json_get "$plan_json" model)"

  if [ "$acceptance" = "unusable" ]; then
    echo "held: $taskId - agent '$AGENT' is unusable for this deliverable"
    held+=("$taskId (unusable by $AGENT)")
    release_ws
    i=$((i + 1)); continue
  fi
  if [ "$kind" != "cli" ]; then
    echo "held: $taskId - agent '$AGENT' kind '$kind' is not a CLI this loop can drive"
    held+=("$taskId (kind $kind unsupported here)")
    release_ws
    i=$((i + 1)); continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry run] would build $taskId with $AGENT (model $model, acceptance $acceptance)"
    release_ws
    i=$((i + 1)); continue
  fi

  if [ -n "$resume" ]; then
    # The build is about to launch: the answer is now used. Recorded host-side so the deed is never served
    # and rebuilt again, and from here the normal rules apply (a hold waits for a person).
    consume_out="$("$HLO" question consume "$taskId" 2>&1)" || true
    case "$consume_out" in
      *"resume consumed"*) ;;
      *) echo "warning: could not mark $taskId's answered question as used; a later run may serve it again" >&2 ;;
    esac
    resume=""
  fi
  echo "-> building $taskId (agent: $AGENT, model: $model)"
  invoke_registry_agent "$plan_json" "$BUILD_PROMPT" "$ws" >/dev/null

  submit_out="$("$HLO" submit "$taskId" --repo "$repo" --agent "$AGENT" 2>&1)"
  # submit's last stdout line is HEE_LEE_OSS_SUBMIT v=1 taskId=<id> verdict=<v> [pr=<url>] gates=<...>
  # staging=<dir>. Its verdict is the only thing this loop trusts: a PR URL appearing (or not) in the
  # text says nothing about whether a human is needed. A version other than 1 is an error, not a guess.
  submit_line="$(printf '%s\n' "$submit_out" | tr -d '\r' | grep -E '^[[:space:]]*HEE_LEE_OSS_SUBMIT[[:space:]]' | tail -n1)"
  if [ -n "$submit_line" ]; then
    if machine_fields HEE_LEE_OSS_SUBMIT "$submit_line"; then
      submit_line=" $MF_REST"
    else
      submit_line=""
    fi
  fi
  verdict="$(printf '%s' "$submit_line" | sed -nE 's/.*[[:space:]]verdict=([^ ]+).*/\1/p')"
  pr_url="$(printf '%s' "$submit_line" | sed -nE 's/.*[[:space:]]pr=([^ ]+).*/\1/p')"
  gates="$(printf '%s' "$submit_line" | sed -nE 's/.*[[:space:]]gates=([^ ]+).*/\1/p')"
  hold_reason="$(printf '%s' "$submit_line" | sed -nE 's/.*[[:space:]]reason=([^ ]+).*/\1/p')"
  [ -z "$gates" ] && gates="none"
  if [ -z "$verdict" ]; then
    verdict="error"
    echo "submit for $taskId printed no outcome line - treating it as an error; workspace kept at $ws." >&2
    printf '%s\n' "$submit_out" | tail -n 20 >&2
  fi
  case "$verdict" in
    opened)
      echo "PR: $pr_url"
      built+=("$taskId -> $pr_url")
      rm -rf "$ws"
      ;;
    no-change)
      echo "no changes for $taskId - releasing workspace (already done)."
      no_change+=("$taskId")
      rm -rf "$ws"
      ;;
    stopped)
      echo "agent stopped: $taskId (see result.json); workspace kept at $ws"
      held+=("$taskId (agent stopped)")
      ;;
    hold)
      if [ "$hold_reason" = "question" ]; then
        echo "held: $taskId - the agent asked a question; workspace kept at $ws"
        echo "  answer it: hee-lee-oss answer $taskId --text \"...\"   (the next run resumes it)"
        held+=("$taskId (question)")
        i=$((i + 1)); continue
      fi
      echo "held: $taskId - a submit gate wants a human (gates=$gates); workspace kept at $ws"
      echo "  re-run: hee-lee-oss submit $taskId --repo $repo --agent $AGENT --force   (from a terminal, if the change is right)"
      held+=("$taskId (gate hold: $gates)")
      ;;
    block)
      echo "BLOCKED: $taskId (gates=$gates). A STOP file now halts submit/stage; run 'hee-lee-oss stop --status' and clear it only after reading why."
      held+=("$taskId (blocked: $gates)")
      break
      ;;
    *)
      echo "held: $taskId - submit ended with verdict '$verdict'; workspace kept at $ws"
      held+=("$taskId (submit $verdict)")
      ;;
  esac
  i=$((i + 1))
done

echo ""
echo "=== loop finished ==="
echo "PRs opened (${#built[@]}):"
for b in "${built[@]:-}"; do [ -n "$b" ] && echo "  $b"; done
echo "held - needs a human (${#held[@]}):"
for h in "${held[@]:-}"; do [ -n "$h" ] && echo "  $h"; done
echo "  (held workspaces are kept under ~/Hee-Lee Oss/queue/<id>)"
echo "no changes (${#no_change[@]}):"
for n in "${no_change[@]:-}"; do [ -n "$n" ] && echo "  $n"; done
"$HLO" status
