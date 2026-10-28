<#
.SYNOPSIS
  Hee-Lee Oss donated-lane loop: pull the next good-deed task, build it with any registry agent,
  and open a PR. A thin wrapper over the installed `hee-lee-oss` CLI — it never hardcodes a vendor
  binary. `--agent <registry-id>` selects ANY agent listed in adapters/registry.json (claude-code,
  aider, codex, gemini-cli, cursor-agent, ...); the CLI's `dispatch` command resolves that agent's
  real command, model, and permission flags for you. See the "Registry-driven agents" section in
  README.md next to this script for how to add or pick an agent.

  This script never authenticates or installs a coding agent for you — that's on you, same as
  running it yourself. It only shells out to whatever agent CLI the registry says to run, on your
  own subscription/account (the donated compute lane). Every dispatch resolves the supervised
  (ask-before-edit) permission fragment for the chosen agent — this loop never escalates to an
  unattended/auto-approve mode.

.PARAMETER Count
  How many deed slots to attempt before stopping.
.PARAMETER Agent
  Registry agent id to build with (default: claude-code). Run `hee-lee-oss agents` to list what's
  installed/registered. Examples: claude-code, gemini-cli, codex, aider, cursor-agent.
.PARAMETER Project
  Pin to one project repo slug (Hee-Lee-Oss-Projects/<slug>) instead of auto-rotating.
.PARAMETER NoFork
  Clone the target repo directly instead of forking (only if you have push access).
.PARAMETER DryRun
  Show what would run for each deed slot without actually building or submitting anything.

.EXAMPLE
  ./hee-lee-oss-loop.ps1 -Count 5
.EXAMPLE
  ./hee-lee-oss-loop.ps1 -Count 5 -Agent gemini-cli
.EXAMPLE
  ./hee-lee-oss-loop.ps1 -Count 5 -Agent codex -Project tool-atlas
#>
[CmdletBinding()]
param(
    [int]$Count = 10,
    [string]$Agent = 'claude-code',
    [string]$Project,
    [string]$Lane = 'donated',
    [switch]$NoFork,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

# --- Resolve the CLI: prefer the globally installed binary; fall back to a local checkout next to
#     this script (useful when this repo is vendored inside a larger workspace). Never assume a
#     vendor agent binary is installed here -- only the neutral `hee-lee-oss` CLI.
$onPath = [bool](Get-Command hee-lee-oss -ErrorAction SilentlyContinue)
$localBin = Join-Path $PSScriptRoot 'node_modules/.bin/hee-lee-oss'
if (-not $onPath -and -not (Test-Path $localBin)) {
    Write-Error "hee-lee-oss CLI not found on PATH or at $localBin. Install it first: npm install -g @heeleeoss/cli (see README.md)."
    exit 1
}
function Invoke-HeeLeeOss {
    param([Parameter(ValueFromRemainingArguments = $true)] $RestArgs)
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        if ($onPath) { & hee-lee-oss @RestArgs } else { & $localBin @RestArgs }
    } finally { $ErrorActionPreference = $old }
}

$BuildPrompt = 'Read .hee-lee-oss/TASK.md and .hee-lee-oss/CONTEXT.md, then produce the deliverable at the task output path. Work through EVERY acceptance criterion explicitly and satisfy each one - do not stop until all are met. Honor the refusal guardrails in CONTEXT.md - if the task would cause harm, mislead, give unqualified high-stakes advice without review, primarily benefit a for-profit, or violate a license or privacy, STOP and write nothing.'

# Release a slot's workspace before submit has run, unless the deed was resumed with an answered question.
function Remove-SlotWorkspace {
    if ($resumed) {
        Write-Host "keeping $taskId's files: it was resumed with an answered question and its build has not launched; the next run picks it up again" -ForegroundColor Yellow
        return
    }
    Remove-Item -Recurse -Force $ws -ErrorAction SilentlyContinue
}

# --- Generic agent runner: works for ANY registry entry, never hardcodes a vendor binary. The
#     dispatch plan (from `hee-lee-oss dispatch`) carries the resolved command/args/promptChannel
#     plus auth.scrubEnv -- the env vars that must be unset so the call bills to this agent's own
#     subscription/account rather than silently picking up a stray API key. This mirrors (in
#     simplified form) Invoke-Agent in scripts/ignite/HeeLeeOssIgnite.psm1 in the main repo.
function Invoke-RegistryAgent {
    param([pscustomobject]$Dispatch, [string]$Prompt, [string]$WorkingDir)
    $inv = $Dispatch.invocation
    if (-not $inv -or -not $inv.command) {
        throw "agent '$($Dispatch.agentId)' has no CLI invocation (kind: $($Dispatch.kind))"
    }
    $scrub = @()
    if ($Dispatch.auth -and $Dispatch.auth.scrubEnv) { $scrub = @($Dispatch.auth.scrubEnv) }
    $keyEnv = $null
    if ($Dispatch.auth -and $Dispatch.auth.keyEnv) { $keyEnv = "$($Dispatch.auth.keyEnv)" }
    $had = @{}; $saved = @{}
    foreach ($e in $scrub) {
        $had[$e] = Test-Path "Env:$e"
        if ($had[$e]) { $saved[$e] = (Get-Item "Env:$e").Value; Remove-Item "Env:$e" -ErrorAction SilentlyContinue }
    }
    # Never echo the key itself -- just note (once, non-secret) that a scrub happened, so a human
    # watching the loop knows a stray env var would otherwise have flipped billing to API.
    if ($keyEnv -and ($scrub -contains $keyEnv) -and $had[$keyEnv]) {
        Write-Host "loop: scrubbed $keyEnv from the environment for this call ($($Dispatch.agentId) stays on your subscription, not billed to API)" -ForegroundColor Yellow
    }
    Push-Location $WorkingDir
    $prevOut = [Console]::OutputEncoding
    try {
        try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
        $agentArgs = @($inv.args)
        if ($inv.promptChannel -eq 'arg') {
            return (& $inv.command @agentArgs $Prompt 2>&1 | Out-String)
        }
        return ($Prompt | & $inv.command @agentArgs 2>&1 | Out-String)
    } finally {
        try { [Console]::OutputEncoding = $prevOut } catch { }
        Pop-Location
        foreach ($e in $scrub) { if ($had[$e]) { Set-Item "Env:$e" $saved[$e] } }
    }
}

# The HEE_LEE_OSS_NEXT / HEE_LEE_OSS_SUBMIT lines start their fields with v=1. Read-MachineLine returns the
# fields after the marker (and after v=1), or $null when the line is not that marker's; a line with no v=
# is read as version 1 with a one-time warning; any other version comes back as @{ error } naming it.
$noVersionWarned = @{}
function Read-MachineLine {
    param([string]$Marker, [string]$Line)
    $m = [regex]::Match($Line, '^\s*' + [regex]::Escape($Marker) + '(?:\s+(.*))?$')
    if (-not $m.Success) { return $null }
    $body = $m.Groups[1].Value.TrimEnd()
    $v = [regex]::Match($body, '^v=(\S*)(?:\s+(.*))?$')
    if (-not $v.Success) {
        if (-not $noVersionWarned.ContainsKey($Marker)) {
            $noVersionWarned[$Marker] = $true
            Write-Warning "loop: the $Marker line has no v= field; reading it as version 1 (a newer hee-lee-oss prints v=1)."
        }
        return @{ rest = $body }
    }
    if ($v.Groups[1].Value -cne '1') {
        $shown = if ($v.Groups[1].Value) { $v.Groups[1].Value } else { '(empty)' }
        return @{ error = "loop: the $Marker line is version $shown, but this script only understands version 1 - update it (re-download hee-lee-oss-loop.ps1)." }
    }
    return @{ rest = $v.Groups[2].Value }
}

$built = @(); $held = @(); $noChange = @(); $stopWarned = $false

for ($i = 1; $i -le $Count; $i++) {
    Write-Host "`n=== deed $i / $Count (agent: $Agent) ===" -ForegroundColor Cyan

    # A STOP file (written by a submit gate block) halts the loop before it pulls more work.
    $stopOut = (Invoke-HeeLeeOss stop --status 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        # Halt only when the CLI really reports a STOP file; an older CLI without `stop` just warns once.
        if ($stopOut -match 'unknown command' -or $stopOut -cnotmatch 'STOP') {
            if (-not $stopWarned) {
                Write-Warning "loop: this CLI predates 'hee-lee-oss stop'; update with npm install -g @heeleeoss/cli (held/blocked outcomes cannot be detected until then)"
                $stopWarned = $true
            }
        } else {
            Write-Warning "STOP is set - not pulling more work. Run 'hee-lee-oss stop --status' and clear it only after reading why.`n$stopOut"
            break
        }
    }

    $nextArgs = @('next', '--lane', $Lane)
    if ($Project) { $nextArgs += @('--repo', "Hee-Lee-Oss-Projects/$Project") }
    if ($NoFork) { $nextArgs += '--no-fork' }
    $out = (Invoke-HeeLeeOss @nextArgs 2>&1 | Out-String)
    $nextRead = $null
    foreach ($l in ($out -split "`r?`n")) {
        $r = Read-MachineLine -Marker 'HEE_LEE_OSS_NEXT' -Line $l
        if ($r) { $nextRead = $r }
    }
    # A version this script does not understand stops the loop visibly rather than guessing at the fields.
    if ($nextRead -and $nextRead.ContainsKey('error')) { Write-Warning $nextRead.error; break }
    $m = if ($nextRead) { [regex]::Match($nextRead.rest, '^taskId=(\S+) repo=(\S+) workspace=(.+?) output=(\S+)') } else { $null }
    if (-not $m -or -not $m.Success) {
        if ($out -match 'session cap') { Write-Warning 'Session cap reached. Stopping.'; break }
        Write-Host 'No more eligible tasks - stopping.' -ForegroundColor Yellow; break
    }
    $taskId = $m.Groups[1].Value; $repo = $m.Groups[2].Value; $ws = $m.Groups[3].Value.Trim()
    # resume=question: the deed was resumed after a person answered its question. Until submit has run,
    # releasing it would lose the answer and the work, so its workspace is never removed before then.
    $resumed = [regex]::IsMatch($nextRead.rest, '(?:^|\s)resume=\S+')

    # Ask the registry how to run this task with the chosen agent -- resolved model, acceptance
    # verdict, and a ready-to-run invocation. Nothing here knows agent-specific flags; that lives
    # entirely in adapters/registry.json, published alongside this script.
    $planJson = (Invoke-HeeLeeOss dispatch --workspace $ws --agent $Agent 2>&1 | Out-String)
    $d = $null; try { $d = ($planJson | ConvertFrom-Json) } catch { }
    if (-not $d -or -not $d.agentId) {
        Write-Warning "dispatch failed for $taskId (agent '$Agent') - skipping.`n$planJson"
        Remove-SlotWorkspace; continue
    }
    if ($d.acceptance -eq 'unusable') {
        Write-Host "held: $taskId - agent '$Agent' is unusable for this deliverable" -ForegroundColor Yellow
        $held += "$taskId (unusable by $Agent)"
        Remove-SlotWorkspace; continue
    }
    if ($d.kind -ne 'cli') {
        Write-Host "held: $taskId - agent '$Agent' kind '$($d.kind)' is not a CLI this loop can drive" -ForegroundColor Yellow
        $held += "$taskId (kind $($d.kind) unsupported here)"
        Remove-SlotWorkspace; continue
    }

    if ($DryRun) {
        Write-Host "[dry run] would build $taskId with $Agent (model $($d.model), acceptance $($d.acceptance))" -ForegroundColor DarkGray
        Remove-SlotWorkspace; continue
    }

    if ($resumed) {
        # The build is about to launch: the answer is now used. Recorded host-side so the deed is never served
        # and rebuilt again, and from here the normal rules apply (a hold waits for a person).
        $consumeOut = (Invoke-HeeLeeOss question consume $taskId 2>&1 | Out-String)
        if ($consumeOut -notmatch 'resume consumed') { Write-Warning "could not mark $taskId's answered question as used; a later run may serve it again" }
        $resumed = $false
    }
    Write-Host "-> building $taskId (agent: $Agent, model: $($d.model))" -ForegroundColor DarkGray
    Invoke-RegistryAgent -Dispatch $d -Prompt $BuildPrompt -WorkingDir $ws | Out-Null

    $submitOut = (Invoke-HeeLeeOss submit $taskId --repo $repo --agent $Agent 2>&1 | Out-String)
    # submit's last stdout line is HEE_LEE_OSS_SUBMIT v=1 taskId=<id> verdict=<v> [pr=<url>] gates=<...>
    # staging=<dir>. Its verdict is the only thing this loop trusts: a PR URL appearing (or not) in the
    # text says nothing about whether a human is needed. Takes the last such line, CRLF-tolerant. A version
    # other than 1 is an error, not a guess.
    $submitLine = $null
    foreach ($l in ($submitOut -split "`r?`n")) {
        $r = Read-MachineLine -Marker 'HEE_LEE_OSS_SUBMIT' -Line $l
        if (-not $r) { continue }
        if ($r.ContainsKey('error')) { Write-Warning $r.error; $submitLine = $null; continue }
        $submitLine = ' ' + $r.rest
    }
    $verdict = $null; $prUrl = ''; $gates = 'none'; $holdReason = ''
    if ($submitLine) {
        $vm = [regex]::Match($submitLine, '(?:^|\s)verdict=(\S+)')
        if ($vm.Success) { $verdict = $vm.Groups[1].Value }
        $pm = [regex]::Match($submitLine, '(?:^|\s)pr=(\S+)')
        if ($pm.Success) { $prUrl = $pm.Groups[1].Value }
        $gm = [regex]::Match($submitLine, '(?:^|\s)gates=(\S+)')
        if ($gm.Success) { $gates = $gm.Groups[1].Value }
        $rm = [regex]::Match($submitLine, '(?:^|\s)reason=(\S+)')
        if ($rm.Success) { $holdReason = $rm.Groups[1].Value }
    }
    if (-not $verdict) {
        $verdict = 'error'
        Write-Warning "submit for $taskId printed no outcome line - treating it as an error; workspace kept at $ws."
        (($submitOut -split "`r?`n") | Select-Object -Last 20) | ForEach-Object { Write-Host "  $_" }
    }
    if ($verdict -eq 'opened') {
        Write-Host "PR: $prUrl" -ForegroundColor Green
        $built += "$taskId -> $prUrl"
        Remove-Item -Recurse -Force $ws -ErrorAction SilentlyContinue
    } elseif ($verdict -eq 'no-change') {
        Write-Host "no changes for $taskId - releasing workspace (already done)." -ForegroundColor Yellow
        $noChange += $taskId
        Remove-Item -Recurse -Force $ws -ErrorAction SilentlyContinue
    } elseif ($verdict -eq 'stopped') {
        Write-Host "agent stopped: $taskId (see result.json); workspace kept at $ws" -ForegroundColor Yellow
        $held += "$taskId (agent stopped)"
    } elseif ($verdict -eq 'hold' -and $holdReason -eq 'question') {
        Write-Host "held: $taskId - the agent asked a question; workspace kept at $ws" -ForegroundColor Yellow
        Write-Host "  answer it: hee-lee-oss answer $taskId --text `"...`"   (the next run resumes it)"
        $held += "$taskId (question)"
    } elseif ($verdict -eq 'hold') {
        Write-Host "held: $taskId - a submit gate wants a human (gates=$gates); workspace kept at $ws" -ForegroundColor Yellow
        Write-Host "  re-run: hee-lee-oss submit $taskId --repo $repo --agent $Agent --force   (from a terminal, if the change is right)"
        $held += "$taskId (gate hold: $gates)"
    } elseif ($verdict -eq 'block') {
        Write-Host "BLOCKED: $taskId (gates=$gates). A STOP file now halts submit/stage; run 'hee-lee-oss stop --status' and clear it only after reading why." -ForegroundColor Red
        $held += "$taskId (blocked: $gates)"
        break
    } else {
        Write-Host "held: $taskId - submit ended with verdict '$verdict'; workspace kept at $ws" -ForegroundColor Yellow
        $held += "$taskId (submit $verdict)"
    }
}

Write-Host "`n=== loop finished ===" -ForegroundColor Cyan
Write-Host "PRs opened ($($built.Count)):" -ForegroundColor Green; $built | ForEach-Object { Write-Host "  $_" }
Write-Host "held - needs a human ($($held.Count)):" -ForegroundColor Yellow; $held | ForEach-Object { Write-Host "  $_" }
Write-Host "  (held workspaces are kept under ~/Hee-Lee Oss/queue/<id>)"
Write-Host "no changes ($($noChange.Count)):" -ForegroundColor DarkYellow; $noChange | ForEach-Object { Write-Host "  $_" }
Invoke-HeeLeeOss status
